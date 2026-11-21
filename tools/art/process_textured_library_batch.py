#!/usr/bin/env python3
"""Offline serial material/LOD processing for an explicit list of asset manifests.

python3 tools/art/process_textured_library_batch.py --jobs-list jobs.json --watch
Only jobs=[manifestpaths] are considered. Missing original_textured.glb stays
pending. --max-seconds bounds waiting; an asset already processing may finish.
No generation, browser, rendering, GPU work, or Godot invocation occurs here.
"""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import math
import os
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PREPARE = ROOT / 'tools/art/prepare_style_materials.py'
PROCESS = ROOT / 'tools/art/process_style_library.py'
sys.path.insert(0, str(ROOT / 'tools/tripo'))
import glb_texture_validation as texture_validation


class BatchError(RuntimeError):
    pass


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def now():
    return datetime.now(timezone.utc).isoformat()


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


@contextmanager
def exclusive(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a+') as stream:
        try:
            fcntl.flock(stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise BatchError(f'another processor owns {path}') from exc
        try:
            yield
        finally:
            fcntl.flock(stream.fileno(), fcntl.LOCK_UN)


def require(condition, message):
    if not condition:
        raise BatchError(message)


def populated(path):
    return path.exists() and any(path.iterdir())


def load_jobs(path, candidate_root):
    data = json.loads(path.read_text(encoding='utf-8'))
    require(isinstance(data, dict) and isinstance(data.get('jobs'), list) and data['jobs'],
            'list must contain nonempty jobs=[manifestpaths]')
    jobs, selected = [], set()
    for entry in data['jobs']:
        require(isinstance(entry, str), 'every job must be a manifest path string')
        manifest = (path.parent / entry).expanduser().resolve()
        require(manifest not in selected, f'duplicate selected manifest: {manifest}')
        selected.add(manifest)
        require(manifest.is_file(), f'missing selected manifest: {manifest}')
        value = json.loads(manifest.read_text(encoding='utf-8'))
        require(isinstance(value, dict), f'manifest must be an object: {manifest}')
        family, asset = manifest.parent.parent.name, manifest.parent.name
        require(family in ('architecture', 'nature', 'props'), f'unknown asset family: {family}')
        size = 1024 if family == 'architecture' or asset in ('curved_pine', 'drooping_willow_v02') else 512
        jobs.append({'manifest': manifest, 'manifest_sha256': sha(manifest), 'data': value,
                     'key': f'{family}/{asset}', 'max_size': size,
                     'source': manifest.parent / 'tripo/original_textured.glb',
                     'material_dir': manifest.parent / 'material_runtime',
                     'candidate_dir': candidate_root / family / (asset + '_textured')})
    require(len({str(job['candidate_dir']) for job in jobs}) == len(jobs), 'duplicate candidate destination')
    return jobs


def verify_inputs(job, source_hash):
    require(sha(job['manifest']) == job['manifest_sha256'], f'manifest changed: {job["manifest"]}')
    require(sha(job['source']) == source_hash, f'original changed: {job["source"]}')


def validate_material(job, source_hash):
    out = job['material_dir']
    report_path, manifest_path, asset_path = out / 'material_report.json', out / 'manifest_runtime.json', out / 'material_source.glb'
    require(all(path.is_file() for path in (report_path, manifest_path, asset_path)),
            f'partial material output; refusing overwrite: {out}')
    report = json.loads(report_path.read_text())
    require(report.get('source_sha256') == source_hash and report.get('tool_sha256') == sha(PREPARE),
            f'material source/tool hash mismatch; refusing overwrite: {out}')
    require(Path(report.get('source', '')).resolve() == job['source'].resolve() and
            Path(report.get('manifest', '')).resolve() == job['manifest'], f'material input path mismatch: {out}')
    require(report.get('max_size') == job['max_size'], f'material resolution mismatch: {out}')
    require(report.get('output', {}).get('sha256') == sha(asset_path), f'material GLB hash mismatch: {out}')
    require(report['output'].get('bytes') == asset_path.stat().st_size, f'material GLB size mismatch: {out}')
    expected = dict(job['data'])
    expected.update(source_glb=str(asset_path), source_manifest=str(job['manifest']),
                    original_textured_glb=str(job['source'].resolve()), asset=job['manifest'].parent.name)
    expected['asset_contract'] = dict(job['data'].get('asset_contract', {}), runtime_texture_max_size=job['max_size'],
                                    material_policy=report.get('policy'), weld_uv_seam_geometry=True)
    require(json.loads(manifest_path.read_text()) == expected, f'derived manifest/input mismatch: {out}')
    validation = texture_validation.validate_textured_result(job['source'], asset_path)
    images = validation['textures']['bound_base_color_images']
    require(images and all(max(image['dimensions']) <= job['max_size'] for image in images),
            f'embedded runtime image exceeds limit: {out}')
    verify_inputs(job, source_hash)
    return report, manifest_path, validation


def validate_candidate(job, material_manifest, blender_version):
    out = job['candidate_dir']
    path = out / 'process_report.json'
    require(path.is_file(), f'partial candidate output; refusing overwrite: {out}')
    report = json.loads(path.read_text())
    identity = report.get('identity', {})
    expected = {'source_sha256': sha(job['material_dir'] / 'material_source.glb'),
                'manifest_sha256': sha(material_manifest), 'tool_sha256': sha(PROCESS),
                'blender': blender_version, 'version': 1}
    require(identity == expected, f'candidate input/tool hash mismatch; refusing overwrite: {out}')
    require(report.get('processing_complete') and report.get('original_source_unchanged'),
            f'incomplete candidate output; refusing overwrite: {out}')
    files = {artifact.get('file'): artifact.get('sha256') for artifact in report.get('artifacts', [])}
    require(set(files) == {'lod0.glb', 'lod1.glb', 'lod2.glb', 'asset.blend'}, f'incomplete candidate artifact list: {out}')
    for name, checksum in files.items():
        artifact = out / name
        require(artifact.is_file() and sha(artifact) == checksum, f'candidate artifact hash mismatch: {artifact}')
    require(len(report.get('lods', [])) == 3, f'candidate lacks three LOD reports: {out}')
    for level in range(3):
        asset = texture_validation._GLB(out / f'lod{level}.glb')
        textures = texture_validation._textures(asset, asset.surface()[1])
        require(all(max(image['dimensions']) <= job['max_size'] for image in textures['bound_base_color_images']),
                f'LOD image exceeds runtime size: {out}')
    return report


def blender_version(binary):
    result = subprocess.run([binary, '--version'], capture_output=True, text=True, check=True)
    for line in result.stdout.splitlines():
        if line.startswith('Blender '):
            return line[len('Blender '):].strip()
    raise BatchError('unable to read Blender version')


def run_blender(args, script, parameters, logfile):
    with logfile.open('x', encoding='utf-8') as stream:
        result = subprocess.run([args.blender, '--factory-startup', '-b', '--python-exit-code', '1',
                                 '--python', str(script), '--', *map(str, parameters)],
                                cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
    require(result.returncode == 0, f'Blender exit {result.returncode}; inspect {logfile}')


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument('--jobs-list', type=Path, required=True)
    result.add_argument('--watch', action='store_true')
    result.add_argument('--max-seconds', '--max_seconds', type=float, default=3600)
    result.add_argument('--poll', type=float, default=30)
    result.add_argument('--progress', type=Path)
    result.add_argument('--log-dir', type=Path, help='base directory for a new per-run log folder')
    result.add_argument('--candidate-root', type=Path, default=ROOT / 'assets/candidates/style_library_20261112')
    result.add_argument('--blender', default='blender')
    result.add_argument('--dry-run', action='store_true', help='report selected plans; no Blender or output mutation')
    return result


def run(args):
    require(math.isfinite(args.max_seconds) and math.isfinite(args.poll) and args.max_seconds > 0 and args.poll > 0,
            'max-seconds and poll must be positive finite numbers')
    selected_list = args.jobs_list.expanduser().resolve()
    jobs = load_jobs(selected_list, args.candidate_root.expanduser().resolve())
    progress_path = (args.progress or selected_list.with_name(selected_list.stem + '_runtime_progress.json')).resolve()
    stamp = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S_%f')
    logs = ((args.log_dir or selected_list.parent / 'batchlogs') / ('textured_runtime_' + stamp)).resolve()
    logs.mkdir(parents=True, exist_ok=False)
    progress = {'started': now(), 'state': 'dry_run' if args.dry_run else 'running',
                'jobs_list': str(selected_list), 'jobs_list_sha256': sha(selected_list), 'logs': str(logs), 'jobs': {job['key']:
                {'state': 'pending', 'manifest': str(job['manifest']), 'manifest_sha256': job['manifest_sha256'],
                 'original': str(job['source']), 'material_dir': str(job['material_dir']),
                 'candidate_dir': str(job['candidate_dir']), 'texture_max_size': job['max_size']}
                for job in jobs}}
    def save():
        progress['updated'] = now()
        states = [item['state'] for item in progress['jobs'].values()]
        progress['counts'] = {state: states.count(state) for state in sorted(set(states))}
        atomic_json(progress_path, progress)
    def event(kind, **values):
        print(json.dumps({'at': now(), 'event': kind, **values}, ensure_ascii=False), flush=True)
    with exclusive(progress_path.with_name(progress_path.name + '.lock')):
        save()
        event('started', progress=str(progress_path), selected=len(jobs), logs=str(logs))
        deadline = time.monotonic() + args.max_seconds
        try:
            version = None if args.dry_run else blender_version(args.blender)
            while True:
                for job in jobs:
                    status = progress['jobs'][job['key']]
                    if status['state'] in ('complete', 'skipped_existing', 'planned'):
                        continue
                    if not job['source'].is_file():
                        status.update(state='pending', last_checked=now())
                        continue
                    if args.dry_run:
                        status.update(state='planned', original_sha256=sha(job['source']))
                        continue
                    with exclusive(job['manifest'].parent / '.material_runtime_batch.lock'):
                        original_hash = sha(job['source'])
                        verify_inputs(job, original_hash)
                        progress['state'] = 'running'
                        status.update(state='validating', original_sha256=original_hash)
                        save()
                        material_existed = populated(job['material_dir'])
                        candidate_existed = populated(job['candidate_dir'])
                        if not material_existed:
                            require(not candidate_existed, 'candidate exists without its material source; refusing reconstruction')
                            status.update(state='preparing_materials'); save()
                            logfile = logs / (job['key'].replace('/', '_') + '_prepare.log')
                            status['prepare_log'] = str(logfile)
                            run_blender(args, PREPARE, ['--manifest', job['manifest'], '--out-dir', job['material_dir'],
                                                      '--max-size', job['max_size']], logfile)
                        material_report, runtime_manifest, validation = validate_material(job, original_hash)
                        atomic_json(logs / (job['key'].replace('/', '_') + '_material_validation.json'), validation)
                        if not candidate_existed:
                            status.update(state='processing_lods'); save()
                            logfile = logs / (job['key'].replace('/', '_') + '_process.log')
                            status['process_log'] = str(logfile)
                            run_blender(args, PROCESS, ['--manifest', runtime_manifest, '--out-dir', job['candidate_dir']], logfile)
                        report = validate_candidate(job, runtime_manifest, version)
                        verify_inputs(job, original_hash)
                        status.update(state='skipped_existing' if material_existed and candidate_existed else 'complete',
                                      finished=now(), not_game_ready=report['not_game_ready'],
                                      triangles=[lod['reimport']['triangles'] for lod in report['lods']],
                                      material_report=str(job['material_dir'] / 'material_report.json'),
                                      process_report=str(job['candidate_dir'] / 'process_report.json'))
                        save()
                        event('processed', asset=job['key'], state=status['state'],
                              not_game_ready=status['not_game_ready'], triangles=status['triangles'])
                save()
                pending = any(item['state'] == 'pending' for item in progress['jobs'].values())
                if args.dry_run or not args.watch or not pending:
                    progress['state'] = 'dry_run_complete' if args.dry_run else ('pending' if pending else 'complete')
                    break
                if time.monotonic() >= deadline:
                    progress['state'] = 'waiting_timed_out'
                    break
                progress['state'] = 'waiting'; save()
                time.sleep(min(args.poll, max(0, deadline - time.monotonic())))
            save(); event('finished', state=progress['state'], counts=progress['counts'])
            return 0
        except BaseException as exc:
            progress.update(state='stopped', error=str(exc))
            if 'status' in locals() and status['state'] not in ('complete', 'skipped_existing', 'pending'):
                status.update(state='stopped', error=str(exc))
            save(); event('stopped', error=str(exc))
            raise


def main():
    args = parser().parse_args()
    try:
        return run(args)
    except KeyboardInterrupt:
        print('stopped; partial outputs retained, no automatic overwrite', file=sys.stderr)
        return 130
    except Exception as exc:
        print('stopped: ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
