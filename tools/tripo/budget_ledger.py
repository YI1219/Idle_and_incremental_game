"""Fail-closed, flock-serialized Tripo credit reservations. No network access.

Every reservation consumes its full quote permanently, including uncertain clicks.
There is deliberately no automatic refund or retry operation.
"""
from __future__ import annotations

import fcntl
import json
import os
import tempfile
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

MAX_AUTHORIZED_CREDITS = 15000
STATES = {'reserved', 'confirmed', 'ambiguous'}


class BudgetError(RuntimeError):
    pass


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def positive_int(value, name):
    if type(value) is not int or value <= 0:
        raise BudgetError(f'{name} must be a positive integer, got {value!r}')
    return value


def atomic_json(path: Path, data: Any) -> None:
    """Atomic replacement with durable content and directory metadata."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f'.{path.name}.', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        sync_directory(path.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def sync_directory(path):
    descriptor = os.open(str(path), os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


class BudgetLedger:
    def __init__(self, path: Path, limit: int = MAX_AUTHORIZED_CREDITS):
        positive_int(limit, 'limit')
        if limit > MAX_AUTHORIZED_CREDITS:
            raise BudgetError(f'limit exceeds authorized {MAX_AUTHORIZED_CREDITS} credits')
        self.path = Path(path).expanduser().resolve()
        self.limit = limit
        self.lock_path = self.path.with_name(self.path.name + '.lock')

    @contextmanager
    def locked(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        # Separate stable inode: replacing the JSON never invalidates this lock.
        with self.lock_path.open('a+') as lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(lock.fileno(), fcntl.LOCK_UN)

    def _read(self):
        if not self.path.exists():
            return {'version': 1, 'limit': self.limit, 'reservations': []}
        try:
            data = json.loads(self.path.read_text(encoding='utf-8'))
            if data['version'] != 1 or data['limit'] != self.limit or not isinstance(data['reservations'], list):
                raise BudgetError('invalid ledger schema or changed limit; refusing to spend')
            ids, jobs, hashes, destinations = set(), set(), set(), set()
            for entry in data['reservations']:
                positive_int(entry['quoted_cost'], 'stored quoted_cost')
                if entry['state'] not in STATES:
                    raise BudgetError('unknown reservation state')
                for key, seen in [('reservation_id', ids), ('job_id', jobs), ('input_hash', hashes), ('destination', destinations)]:
                    value = entry[key]
                    if not isinstance(value, str) or not value or value in seen:
                        raise BudgetError(f'invalid or duplicate ledger {key}')
                    seen.add(value)
            if sum(entry['quoted_cost'] for entry in data['reservations']) > self.limit:
                raise BudgetError('ledger already exceeds budget; refusing to spend')
            return data
        except (ValueError, KeyError, TypeError, OSError) as exc:
            raise BudgetError(f'unreadable ledger: {self.path}: {exc}') from exc

    def snapshot(self):
        with self.locked():
            data = self._read()
            data['committed_credits'] = sum(e['quoted_cost'] for e in data['reservations'])
            data['remaining_credits'] = self.limit - data['committed_credits']
            return data

    def _check(self, data, job_id, input_hash, attempt_path, destination):
        for name, value in [('job_id', job_id), ('input_hash', input_hash)]:
            if not isinstance(value, str) or not value.strip():
                raise BudgetError(f'{name} must be nonempty')
        if destination.exists() or destination.is_symlink():
            raise BudgetError(f'original exists; no resubmission: {destination}')
        if attempt_path.exists() or attempt_path.is_symlink():
            raise BudgetError(f'generation attempt exists; recover download separately: {attempt_path}')
        for entry in data['reservations']:
            if entry['job_id'] == job_id or entry['input_hash'] == input_hash or entry['destination'] == str(destination):
                raise BudgetError(f'job/input/output already reserved ({entry["state"]}); no resubmission: {job_id}')

    def check(self, job_id, input_hash, attempt_path, destination):
        with self.locked():
            self._check(self._read(), job_id, input_hash, Path(attempt_path).resolve(), Path(destination).resolve())

    def reserve(self, job_id: str, input_hash: str, quoted_cost: int,
                attempt_path: Path, destination: Path, **metadata):
        positive_int(quoted_cost, 'quoted_cost')
        attempt_path, destination = Path(attempt_path).resolve(), Path(destination).resolve()
        with self.locked():
            data = self._read()
            self._check(data, job_id, input_hash, attempt_path, destination)
            committed = sum(e['quoted_cost'] for e in data['reservations'])
            if committed + quoted_cost > self.limit:
                raise BudgetError(f'quote {quoted_cost} exceeds remaining {self.limit - committed}; no click')
            entry = {'reservation_id': uuid.uuid4().hex, 'job_id': job_id,
                     'input_hash': input_hash, 'quoted_cost': quoted_cost,
                     'state': 'reserved', 'reserved_at': now(),
                     'attempt_path': str(attempt_path), 'destination': str(destination),
                     'metadata': metadata}
            data['reservations'].append(entry)
            # Ledger first: a crash between these two writes still blocks resubmission.
            atomic_json(self.path, data)
            attempt_path.parent.mkdir(parents=True, exist_ok=True)
            try:
                with attempt_path.open('x', encoding='utf-8') as stream:
                    json.dump(entry, stream, ensure_ascii=False, indent=2)
                    stream.flush()
                    os.fsync(stream.fileno())
                sync_directory(attempt_path.parent)
            except Exception as exc:
                entry.update(state='ambiguous', error=f'attempt marker write failed: {exc}')
                atomic_json(self.path, data)
                raise BudgetError('reservation retained; attempt marker failed; no click') from exc
            return dict(entry)

    def mark(self, reservation_id: str, state: str, **details):
        if state not in STATES:
            raise BudgetError(f'invalid reservation state: {state}')
        with self.locked():
            data = self._read()
            entry = next((e for e in data['reservations'] if e['reservation_id'] == reservation_id), None)
            if entry is None:
                raise BudgetError('unknown reservation')
            entry.update(state=state, updated_at=now())
            entry.setdefault('updates', []).append({'state': state, 'at': now(), **details})
            atomic_json(self.path, data)
            # Preserve the exclusively-created marker identity, append current state.
            atomic_json(Path(entry['attempt_path']), entry)
            return dict(entry)
