#!/usr/bin/env python3
"""Sequential HQ geometry-only jobs with one durable budget. Default: browser dry-run.

List format: {"jobs": ["relative/path/manifest.json", ...]} (relative to list).
Use --yes for paid generation; interrupted jobs are never automatically resubmitted.
"""
from __future__ import annotations

import argparse
import asyncio
import fcntl
import hashlib
import json
import os
import re
import sys
import time
import uuid
from contextlib import contextmanager
from pathlib import Path

import studio_generate as sg
import studio_prepare as sp
from budget_ledger import BudgetError, BudgetLedger, atomic_json, now, sync_directory


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument('job_list', type=Path)
    result.add_argument('--ledger', type=Path, required=True)
    result.add_argument('--limit', type=int, default=15000)
    result.add_argument('--progress', type=Path, help='default: LEDGER.progress.json')
    result.add_argument('--profile', type=Path, default=sp.DEFAULT_PROFILE,
                        help='dedicated Tripo Chrome profile; personal profiles are refused')
    result.add_argument('--wait-s', type=int, default=900)
    group = result.add_mutually_exclusive_group()
    group.add_argument('--yes', action='store_true', help='reserve quote and click Generate once per job')
    group.add_argument('--dry-run', action='store_true', help='default; fill, verify and quote without paid click')
    return result


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_job(path):
    path = Path(path).expanduser().resolve()
    manifest = sp.load_manifest(path)
    settings = sp.settings_block(manifest)
    if sp.normalize_route(settings) != 'high_quality':
        raise sp.PrepareError(f'only HQ jobs supported: {path}')
    if settings.get('texture') is not False:
        raise sp.PrepareError(f'manifest must explicitly set texture=false: {path}')
    raw_faces = next((settings[k] for k in ('target_faces', 'face_limit', 'faces', 'target_triangles')
                      if k in settings), None)
    if type(raw_faces) is not int or not 100 <= raw_faces <= 2000000:
        raise sp.PrepareError(f'target faces must be an integer in 100..2000000: {raw_faces!r}')
    if not isinstance(manifest.get('output_original'), str) or not manifest['output_original'].strip():
        raise sp.PrepareError(f'output_original required: {path}')
    views = sp.resolve_inputs(manifest, path.parent)
    hashes = {name: digest(image) for name, image in views.items()}
    for name, image_hash in hashes.items():
        entry = manifest.get('input', {}) if name == 'single' else manifest['views'][name]
        if entry.get('sha256') and entry['sha256'] != image_hash:
            raise sp.PrepareError(f'input SHA256 mismatch: {path} {name}')
    requested = {'route': 'high_quality', 'image_mode': sp.image_mode(manifest),
                 'target_faces': raw_faces, 'texture': False,
                 'topology': sp.normalize_topology(settings) or 'triangles'}
    identity = json.dumps({'requested': requested, 'images': hashes}, sort_keys=True).encode()
    destination = (path.parent / manifest['output_original']).resolve()
    if destination.suffix.lower() != '.glb':
        raise sp.PrepareError(f'output_original must name a GLB: {destination}')
    output = path.parent / str(manifest.get('download_directory') or 'tripo/')
    return {'manifest_path': path, 'manifest_sha256': digest(path),
            'job_id': str(manifest.get('job_id') or path),
            'input_hash': hashlib.sha256(identity).hexdigest(),
            'requested': requested, 'destination': destination,
            'attempt_path': output / f'{destination.stem}.generation_attempt.json'}


def load_jobs(path):
    path = Path(path).expanduser().resolve()
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict) or not isinstance(data.get('jobs'), list) or not data['jobs']:
        raise sp.PrepareError('job list must contain nonempty jobs=[manifestpaths]')
    jobs, ids, hashes, destinations = [], set(), set(), set()
    for entry in data['jobs']:
        if not isinstance(entry, str):
            raise sp.PrepareError('each jobs entry must be a manifest path string')
        job = load_job(path.parent / entry)
        for key, seen in [('job_id', ids), ('input_hash', hashes), ('destination', destinations)]:
            if job[key] in seen:
                raise sp.PrepareError(f'duplicate {key} in batch: {job[key]}')
            seen.add(job[key])
        jobs.append(job)
    return jobs


def parse_quote(label):
    # Fail closed if UI changes, contains a discount pair, a sign, or decimals.
    if not re.search(r'生成\s*模型', label) or re.search(r'[-+−.]', label):
        raise sp.PrepareError(f'unrecognized Generate quote: {label!r}')
    numbers = re.findall(r'\d[\d,]*', label)
    if len(numbers) != 1 or not re.fullmatch(r'(?:\d+|\d{1,3}(?:,\d{3})+)', numbers[0]):
        raise sp.PrepareError(f'ambiguous Generate quote: {label!r}')
    cost = int(numbers[0].replace(',', ''))
    if cost <= 0:
        raise sp.PrepareError(f'nonpositive Generate quote: {label!r}')
    return cost


def publish_original(staging, destination):
    # Hard-link installation is exclusive even if an original appears during download.
    with Path(staging).open('rb') as stream:
        os.fsync(stream.fileno())
    os.link(staging, destination)
    sync_directory(Path(destination).parent)
    Path(staging).unlink()


@contextmanager
def dedicated_profile(path):
    path = path.expanduser().resolve()
    personal = ('/google/chrome', '/google-chrome', '/microsoft edge', '/chromium', '/chrome/user data')
    if any(fragment in str(path).lower() for fragment in personal) or path.name in ('Default', 'Profile 1', 'Profile 2'):
        raise sp.PrepareError('refusing personal browser profile; use a dedicated Tripo directory')
    path.mkdir(parents=True, exist_ok=True)
    with (path / '.tripo_batch.lock').open('a+') as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise sp.PrepareError('another batch owns this dedicated profile') from exc
        try:
            yield path
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


class Progress:
    def __init__(self, path, jobs, ledger, paid):
        self.path, self.ledger = path, ledger
        self.data = {'started_at': now(), 'mode': 'paid' if paid else 'dry_run',
                     'state': 'starting', 'jobs': [
                         {'job_id': j['job_id'], 'manifest': str(j['manifest_path']), 'state': 'pending'} for j in jobs]}
        self.save()

    def save(self, phase=None, index=None, **values):
        self.data['updated_at'] = now()
        if phase:
            self.data['state'] = phase
        if index is not None:
            self.data['current_index'] = index
            self.data['jobs'][index].update(values)
        elif values:
            self.data.update(values)
        summary = self.ledger.snapshot()
        self.data['budget'] = {key: summary[key] for key in ('limit', 'committed_credits', 'remaining_credits')}
        atomic_json(self.path, self.data)


async def visible_face_input(page):
    candidates = []
    for item in await page.locator('input').all():
        if await item.is_visible():
            try:
                value = await item.input_value()
            except Exception:
                continue
            if value.isdigit() and 100 <= int(value) <= 2000000:
                candidates.append(item)
    if len(candidates) != 1:
        raise sp.PrepareError(f'expected one visible target-face input, found {len(candidates)}')
    return candidates[0]


async def texture_switch(page):
    switch = page.get_by_text('贴图生成', exact=True).last.locator('..').get_by_role('switch')
    if await switch.count() != 1:
        raise sp.PrepareError('texture generation switch not uniquely identified')
    return switch


async def wait_uploaded_inputs(page, run, timeout_s=90):
    """The input setter can return while Studio is still uploading to its server."""
    deadline = time.monotonic() + timeout_s
    stable = 0
    while time.monotonic() < deadline:
        body = await sg.body_text(page)
        previews = await page.locator('img').evaluate_all("""images => images.filter(image => { const r=image.getBoundingClientRect(); return r.x>=60 && r.x<315 && r.y>130 && r.y<420 && r.width>40 && image.complete && image.naturalWidth>0; }).length""")
        pending = bool(re.search(r'上传中|正在上传|Uploading', body, re.I))
        required = 4 if run.image_mode == 'multiview' else 1
        stable = stable + 1 if not pending and previews >= required else 0
        if stable >= 2:
            run.log['upload_ready_verified'] = {'preview_images': previews, 'pending_text': False}
            return
        await page.wait_for_timeout(1000)
    raise sp.PrepareError('image upload/preview did not finish; no paid action')


async def prepare_hq(page, run, job):
    await sg.wait_workbench(page, run)
    await sp.select_route(page, 'high_quality')
    if run.image_mode == 'single_image':
        await sg.upload_single_image(page, run)
    else:
        await sp.select_multiview(page)
        await sg.upload_by_label(page, run)
    await wait_uploaded_inputs(page, run)
    # Some HQ versions expose no quantity control. If present, verify one.
    quantity = page.get_by_text('生成数量', exact=True)
    if await quantity.count():
        group = quantity.locator('..').locator('..')
        await group.locator('button[value="1"]').click()
        selected = await group.locator('button[aria-pressed="true"]').evaluate_all('buttons => buttons.map(b => b.value)')
        if selected != ['1']:
            raise sp.PrepareError(f'quantity did not retain one: {selected}')
    await sp.open_topology_or_geometry(page, 'high_quality')
    toggle = await texture_switch(page)
    state = await toggle.get_attribute('aria-checked')
    if state == 'true':
        await toggle.click()
    if await toggle.get_attribute('aria-checked') != 'false':
        raise sp.PrepareError('texture generation is not confirmed OFF')
    await sp.apply_topology(page, job['requested']['topology'])
    box = await visible_face_input(page)
    await box.fill(str(job['requested']['target_faces']))
    await box.press('Enter')
    await run.shot(page, '01_hq_parameters')
    await page.keyboard.press('Escape')
    await sp.open_topology_or_geometry(page, 'high_quality')
    toggle = await texture_switch(page)
    box = await visible_face_input(page)
    faces = await box.input_value()
    if await toggle.get_attribute('aria-checked') != 'false' or faces != str(job['requested']['target_faces']):
        raise sp.PrepareError('HQ texture/target face settings did not survive reopening')
    run.log['hq_verified'] = {'texture': False, 'faces_after_reopen': faces,
                              'topology': job['requested']['topology'], 'quantity': 1}
    await run.shot(page, '02_hq_verified_reopened')
    await page.keyboard.press('Escape')
    await page.wait_for_timeout(500)
    button = await sg.generate_button(page)
    label = (await button.inner_text()).replace('\n', ' ').strip()
    quote = parse_quote(label)
    run.log['quote'] = {'button_text': label, 'quoted_cost': quote, 'at': now()}
    run.log['quote']['screenshot'] = await run.shot(page, '03_quoted_before_generate')
    run.save_log()
    return button, label, quote


async def wait_result(page, run, before, wait_s, progress, index):
    deadline, started, seen = time.monotonic() + wait_s, time.monotonic(), False
    last_shot = started
    while time.monotonic() < deadline:
        await page.wait_for_timeout(5000)
        text = await sg.body_text(page)
        if ('登录' in text and '生成模型' not in text) or 'Cloudflare' in text[:1500]:
            raise sp.PrepareError('login or verification appeared after submission; do not resubmit')
        busy = bool(sg.PROGRESS_RE.search(text))
        seen = seen or busy
        after = await sg.asset_signature(page)
        progress.save('running', index, state='generating', busy=busy, last_observed_at=now())
        if time.monotonic() - last_shot >= 60:
            await run.shot(page, f'04_wait_{int(time.monotonic() - started)}')
            last_shot = time.monotonic()
        if not busy and len(after) > len(before) and (seen or time.monotonic() - started > 150):
            if len(after) != len(before) + 1:
                raise sp.PrepareError('multiple new assets; result identity uncertain; stop without retry')
            return
    raise sp.PrepareError('generation timeout; inspect existing task, never resubmit')


async def process_job(page, args, job, ledger, progress, index):
    # Recheck file bytes/settings after previous long-running jobs, before any upload.
    if load_job(job['manifest_path']) != job:
        raise sp.PrepareError('manifest/input changed since batch start; stop and review')
    ledger.check(job['job_id'], job['input_hash'], job['attempt_path'], job['destination'])
    config = argparse.Namespace(dry_run=not args.yes, download_only=False, yes=args.yes)
    run = sg.Run(job['manifest_path'], config)
    run.log['batch_identity'] = {k: str(job[k]) for k in ('job_id', 'input_hash', 'manifest_sha256')}
    reservation = None
    try:
        progress.save('running', index, state='preparing', log=str(run.out / f'studio_run_{run.stamp}.json'))
        button, label, quote = await prepare_hq(page, run, job)
        progress.save('running', index, state='quoted', quoted_cost=quote, parameters=job['requested'])
        if quote > ledger.snapshot()['remaining_credits']:
            raise BudgetError(f'quote {quote} exceeds remaining budget; no click')
        if not args.yes:
            run.ev('dry-run; no reservation or paid action')
            progress.save('running', index, state='dry_run_verified')
            return
        before = await sg.asset_signature(page)
        # Re-read immediately before reserve so a changed quote never uses a stale price.
        current_label = (await button.inner_text()).replace('\n', ' ').strip()
        if current_label != label or parse_quote(current_label) != quote:
            raise sp.PrepareError('Generate quote changed before reservation; no click')
        reservation = ledger.reserve(job['job_id'], job['input_hash'], quote,
                                     run.attempt_path, run.destination,
                                     manifest=str(job['manifest_path']), manifest_sha256=job['manifest_sha256'],
                                     requested=job['requested'], quote=run.log['quote'], run=run.stamp)
        run.log['budget_reservation'] = reservation
        run.save_log()
        progress.save('running', index, state='reserved', reservation_id=reservation['reservation_id'])
        await button.click()  # Exactly one paid click. Never retried, including exceptions.
        run.ev('clicked HQ Generate once', quoted_cost=quote)
        await run.shot(page, '04_after_single_click')
        await wait_result(page, run, before, args.wait_s, progress, index)
        ledger.mark(reservation['reservation_id'], 'confirmed', result_observed_at=now())
        progress.save('running', index, state='downloading')
        await sg.dismiss_tips(page)
        await run.shot(page, '05_result')
        run.destination.parent.mkdir(parents=True, exist_ok=True)
        staging = run.destination.with_name(f'.{run.destination.stem}.{uuid.uuid4().hex}.partial.glb')
        if not await sg.try_download(page, run, staging):
            raise sp.PrepareError('download failed; recover existing task separately, never resubmit')
        if not staging.is_file() or staging.stat().st_size < 12:
            raise sp.PrepareError(f'download not a GLB; preserved staging: {staging}')
        with staging.open('rb') as stream:
            if stream.read(4) != b'glTF':
                raise sp.PrepareError(f'download not a GLB; preserved staging: {staging}')
        publish_original(staging, run.destination)
        run.log['download'].update(file=str(run.destination), sha256=digest(run.destination))
        ledger.mark(reservation['reservation_id'], 'confirmed', download=run.log['download'])
        progress.save('running', index, state='complete', original=str(run.destination), sha256=digest(run.destination))
    except BaseException as exc:
        run.ev('stopped; no automatic resubmission', error=str(exc))
        if reservation:
            ledger.mark(reservation['reservation_id'], 'ambiguous', error=str(exc),
                        note='full quote retained, including download-only failure')
        try:
            await run.shot(page, '99_stopped')
        except Exception:
            pass
        progress.save('stopped', index, state='stopped', error=str(exc))
        raise
    finally:
        run.save_log()


async def main_async(args):
    ledger = BudgetLedger(args.ledger, args.limit)
    jobs = load_jobs(args.job_list)
    if args.wait_s <= 0:
        raise sp.PrepareError('--wait-s must be positive')
    progress_path = args.progress or args.ledger.with_name(args.ledger.name + '.progress.json')
    with dedicated_profile(args.profile) as profile:
        progress = Progress(progress_path, jobs, ledger, args.yes)
        # Fail before launching Chrome if any unfinished attempt requires recovery.
        pending = []
        for index, job in enumerate(jobs):
            if job['destination'].exists():
                progress.save('starting', index, state='skipped_existing_original', original=str(job['destination']))
                continue
            try:
                ledger.check(job['job_id'], job['input_hash'], job['attempt_path'], job['destination'])
            except BaseException as exc:
                progress.save('stopped', index, state='recovery_required', error=str(exc))
                raise
            pending.append((index, job))
        if not pending:
            progress.save('complete')
            return 0
        from playwright.async_api import async_playwright
        try:
            async with async_playwright() as playwright:
                context = await playwright.chromium.launch_persistent_context(
                    str(profile), channel='chrome', headless=False, viewport={'width': 1440, 'height': 960},
                    locale='zh-CN', accept_downloads=True)
                context.set_default_timeout(30000)
                page = context.pages[0] if context.pages else await context.new_page()
                try:
                    for index, job in pending:
                        await process_job(page, args, job, ledger, progress, index)
                    progress.save('complete')
                finally:
                    await context.close()
        except BaseException as exc:
            progress.save('stopped', error=str(exc))
            raise
    return 0


def main():
    args = parser().parse_args()
    try:
        return asyncio.run(main_async(args))
    except KeyboardInterrupt:
        print('interrupted; existing reservations remain charged, do not resubmit', file=sys.stderr)
        return 130
    except Exception as exc:
        print(f'stopped: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
