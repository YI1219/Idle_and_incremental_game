#!/usr/bin/env python3
"""Geometry identity and guarded Studio texture workflow (headed dedicated profile)."""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import re
import struct
import sys
import time
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import urlsplit

import studio_batch as batch
import studio_generate as sg
import studio_prepare as sp
from budget_ledger import BudgetLedger, atomic_json, now
from glb_texture_validation import validate_textured_result, TextureValidationError


def glb_parts(path):
    data = Path(path).read_bytes()
    if len(data) < 20 or struct.unpack_from('<4sII', data) != (b'glTF', 2, len(data)):
        raise sp.PrepareError(f'invalid GLB: {path}')
    document, binary, offset = None, None, 12
    while offset < len(data):
        length, kind = struct.unpack_from('<II', data, offset)
        payload = data[offset + 8: offset + 8 + length]
        if len(payload) != length:
            raise sp.PrepareError('truncated GLB')
        if kind == 0x4e4f534a:
            document = json.loads(payload)
        elif kind == 0x004e4942:
            binary = payload
        offset += 8 + length
    if document is None or binary is None:
        raise sp.PrepareError('GLB must contain JSON and embedded BIN')
    return document, binary


def geometry_identity(path):
    """Exact geometry, hierarchy and transforms, ignoring export metadata/materials.

    Reordering geometry is intentionally a mismatch: uncertainty blocks payment.
    Accessor stride/padding does not affect the identity.
    """
    doc, binary = glb_parts(path)
    sizes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    components = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
    def accessor(index):
        item = doc['accessors'][index]
        if 'sparse' in item:
            raise sp.PrepareError('sparse accessor identity is unsupported')
        view = doc['bufferViews'][item['bufferView']]
        if view.get('buffer', 0) != 0:
            raise sp.PrepareError('external geometry buffer unsupported')
        width = sizes[item['componentType']] * components[item['type']]
        start = view.get('byteOffset', 0) + item.get('byteOffset', 0)
        stride = view.get('byteStride', width)
        chunks = [binary[start + n*stride:start + n*stride + width] for n in range(item['count'])]
        if any(len(chunk) != width for chunk in chunks):
            raise sp.PrepareError('geometry buffer out of bounds')
        return {'componentType': item['componentType'], 'type': item['type'], 'count': item['count'],
                'sha256': hashlib.sha256(b''.join(chunks)).hexdigest()}
    meshes = []
    for mesh in doc.get('meshes', []):
        primitives = []
        for p in mesh['primitives']:
            primitives.append({'mode': p.get('mode', 4), 'positions': accessor(p['attributes']['POSITION']),
                               'indices': accessor(p['indices']) if 'indices' in p else None})
        meshes.append(primitives)
    nodes = [{key: n[key] for key in ('mesh', 'children', 'translation', 'rotation', 'scale', 'matrix') if key in n}
             for n in doc.get('nodes', [])]
    if not meshes:
        raise sp.PrepareError('no mesh geometry')
    return {'meshes': meshes, 'nodes': nodes, 'scenes': doc.get('scenes'), 'scene': doc.get('scene', 0)}


def parse_texture_quote(label):
    if not re.search(r'生成\s*贴图', label):
        raise sp.PrepareError(f'not a texture quote: {label!r}')
    return batch.parse_quote(re.sub(r'生成\s*贴图', '生成模型', label))


def require_project_target(card_href, raw_params):
    """Generate/texture routes differ; bind the action to the observed project id."""
    match = re.search(r'([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$', card_href, re.I)
    params = json.loads(raw_params or '{}')
    if not match or params.get('project_id') != match.group(1):
        raise sp.PrepareError('Generate target differs from the geometry-verified project; no paid action')
    return match.group(1)


def credit_balance_from_text(body):
    values = {int(value.replace(',', '')) for value in re.findall(r'(\d[\d,]*)\s+升级\b', body)}
    return next(iter(values)) if len(values) == 1 else None


async def ui_credit_balance(page):
    return credit_balance_from_text(await sg.body_text(page))


async def wait_submission_receipt(page, run, before, quote, timeout_s=45):
    """Keep this page alive until UI billing acknowledges this one click.

    A click/screenshot is not acknowledgement. Navigating immediately can abort
    the task-creation request. Uncertain outcomes stop, never submit again.
    """
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        await page.wait_for_timeout(500)
        after = await ui_credit_balance(page)
        if after == before - quote:
            receipt = {'before':before, 'after':after, 'quote':quote, 'at':now(), 'evidence':'visible credit header exact debit'}
            run.log['submission_receipt'] = receipt
            await page.wait_for_timeout(1000)
            return receipt
    raise sp.PrepareError('no unambiguous submission debit receipt; task may be pending; preserve reservation and never resubmit')


def texture_job(manifest_path, ledger):
    base = batch.load_job(manifest_path)
    source = base['destination']
    if not source.is_file():
        raise sp.PrepareError(f'geometry original missing: {source}')
    entry = next((e for e in ledger.snapshot()['reservations'] if e['destination'] == str(source)), None)
    if not entry or entry['state'] != 'confirmed':
        raise sp.PrepareError('source must be a confirmed geometry job in this same ledger')
    downloads = [u['download'] for u in entry.get('updates', []) if u.get('state') == 'confirmed' and u.get('download')]
    if entry['input_hash'] != base['input_hash'] or not downloads or downloads[-1].get('sha256') != batch.digest(source):
        raise sp.PrepareError('confirmed source input/download hash does not match; source changed')
    requested = {'action': 'texture_existing_geometry', 'resolution': '2K', 'delight': True,
                 'reference_input_hash': base['input_hash'], 'source_sha256': batch.digest(source)}
    destination = source.with_name('original_textured.glb')
    dates = [entry['reserved_at']] + [u['at'] for u in entry.get('updates', [])]
    doc, _ = glb_parts(source)
    uuids = {m.group(1) for node in doc.get('nodes', [])
             for m in [re.fullmatch(r'tripo_node_([0-9a-f-]{36})', node.get('name', ''), re.I)] if m}
    return {'manifest_path': base['manifest_path'], 'job_id': base['job_id'] + ':texture_2k_delight_v1',
            'input_hash': hashlib.sha256(json.dumps(requested, sort_keys=True).encode()).hexdigest(),
            'requested': requested, 'source': source, 'source_identity': geometry_identity(source),
            'source_dates': dates, 'source_node_uuid': next(iter(uuids)) if len(uuids) == 1 else None, 'destination': destination,
            'attempt_path': destination.with_name('original_textured.generation_attempt.json')}


async def select_time_card(page, label):
    """Visible Studio card, located through its own rendered date label."""
    count = await page.evaluate('''label => {
      document.querySelectorAll('[data-codex-texture-card]').forEach(e => e.removeAttribute('data-codex-texture-card'));
      const cards = new Set();
      for (const node of document.querySelectorAll('div,span,p')) {
        if ((node.textContent||'').trim() !== label) continue;
        let e = node;
        for (let i=0; e && i<7; i++, e=e.parentElement) {
          const b=e.getBoundingClientRect();
          if (b.x>1150 && b.width>=80 && b.width<230 && b.height>=75 && b.height<230 && e.querySelector('img')) {
            cards.add(e); break;
          }
        }
      }
      for (const e of cards) e.setAttribute('data-codex-texture-card', 'selected');
      return cards.size;
    }''', label)
    if count != 1:
        raise sp.PrepareError(f'expected one visible card at {label}, got {count}')
    await page.locator('[data-codex-texture-card="selected"]').click()
    await page.wait_for_timeout(4500)


async def verify_source_card(page, run, job):
    await sg.wait_workbench(page, run)
    run.log['source_asset_labels'] = await sg.asset_signature(page)
    run.log['source_card_dom'] = await page.locator('img').evaluate_all('''nodes=>nodes.filter(e=>{
      const b=e.getBoundingClientRect();return b.x>1150&&b.width>60;
    }).slice(0,24).map(e=>e.parentElement.parentElement.outerHTML.slice(0,9000).replace(/auth_key=[^"&]+/g,'auth_key=REDACTED'))''')
    run.save_log()
    dates = [datetime.fromisoformat(d).astimezone() for d in job['source_dates']]
    start, end = min(dates) - timedelta(seconds=60), max(dates) + timedelta(seconds=60)
    labels = []
    async def export_matches(label):
        staging = run.out / f'.identity_{run.stamp}_{len(run.log.setdefault("cards_checked", []))}.glb'
        if not await sg.try_download(page, run, staging):
            raise sp.PrepareError('free identity export failed; no paid action')
        run.log['cards_checked'].append(label)
        if geometry_identity(staging) == job['source_identity']:
            card_href = urlsplit(page.url).path
            if not card_href.startswith('/workspace/generate/'):
                raise sp.PrepareError('selected source has no stable visible project URL')
            run.log['verified_source'] = {'label': label, 'card_href': card_href, 'export': str(staging),
                                          'sha256': batch.digest(staging), 'geometry_exact_match': True}
            return True
        return False
    for _ in range(12):
        # The observed Studio card thumbnail path contains its GLB node UUID.
        # This is only a DOM locator optimization; the free export must still
        # match all local geometry exactly before any payment.
        if job.get('source_node_uuid'):
            card = page.locator('a').filter(has=page.locator('img[src*="' + job['source_node_uuid'] + '"]'))
            if await card.count() == 1:
                await card.click()
                await page.wait_for_timeout(4500)
                if await export_matches('source_node_uuid:' + job['source_node_uuid']):
                    return
        labels = list(dict.fromkeys(await sg.asset_signature(page)))
        def near(label):
            stamp = datetime.strptime(str(start.year) + '-' + label, '%Y-%m-%d %H:%M').astimezone()
            return start.replace(second=0, microsecond=0) <= stamp <= end
        candidates = [label for label in labels if near(label)]
        for label in candidates:
            if label in run.log.setdefault('cards_checked', []):
                continue
            await select_time_card(page, label)
            if await export_matches(label):
                return
        scrolled = await page.evaluate('''() => {
          const scrollables=[...document.querySelectorAll('div')].filter(e=>{
            const b=e.getBoundingClientRect();return b.x>1150 && b.width<300 && b.height>300 && e.scrollHeight>e.clientHeight+10;
          }).sort((a,b)=>a.clientWidth-b.clientWidth);
          const e=scrollables[0];if(!e)return false;
          const previous=e.scrollTop;e.scrollTop+=e.clientHeight*.8;return e.scrollTop>previous;
        }''')
        if not scrolled:
            break
        await page.wait_for_timeout(1500)
    raise sp.PrepareError(f'could not verify source geometry from visible cards, checked {run.log.get("cards_checked", [])}')


async def prepare_texture(page, run, job, inspect=False):
    await verify_source_card(page, run, job)
    await sg.dismiss_tips(page)
    await page.get_by_text('贴图生成', exact=True).first.click()
    await page.wait_for_timeout(1600)
    # Studio's persisted image preview may be blank after a fresh browser session.
    # Explicitly supply the selected concept rather than trusting that cached UI.
    reference = run.views.get('single') or run.views['front']
    image_icon = page.locator('.i-tripo\\:add-image').first
    await image_icon.locator('xpath=ancestor::button[1]').click()
    await page.wait_for_timeout(400)
    inputs = page.locator('input[type="file"][accept*="image"]')
    if await inputs.count() == 0:
        # A filled reference replaces the upload input with a thumbnail/delete
        # control. Only clear that local left-panel reference, never asset cards.
        candidates = []
        for control in await page.locator('button:has(.i-tripo\\:delete)').all():
            box = await control.bounding_box()
            if box and 80 < box['x'] < 310 and 150 < box['y'] < 410:
                candidates.append(control)
        if len(candidates) != 1:
            raise sp.PrepareError(f'cannot uniquely replace local texture reference: {len(candidates)}')
        await candidates[0].click()
        await page.wait_for_timeout(400)
    await sp.upload_single(page, reference)
    original_mode = run.image_mode
    try:
        run.image_mode = 'single_image'
        await batch.wait_uploaded_inputs(page, run)
    finally:
        run.image_mode = original_mode
    run.log['texture_reference'] = {'file': str(reference), 'sha256': batch.digest(reference),
                                    'mode': 'single_image style/projection reference; existing full geometry retained'}
    await run.shot(page, 'texture_panel_before')
    run.log['texture_panel_text'] = await sg.body_text(page)
    run.log['visible_controls'] = await page.locator('button,[role="switch"]').evaluate_all('''nodes=>nodes.filter(e=>{
       const b=e.getBoundingClientRect();return b.width>0&&b.height>0;
    }).map(e=>({text:e.innerText,html:e.outerHTML.slice(0,2500)}))''')
    run.save_log()
    if inspect:
        return None, None, None
    resolution = page.get_by_role('button', name='2K', exact=True)
    await resolution.click()
    selected = await resolution.get_attribute('aria-pressed') == 'true' or await resolution.get_attribute('data-state') in ('on', 'active', 'checked')
    if not selected:
        raise sp.PrepareError('2K selection state needs UI adapter verification; no paid action')
    toggle = page.get_by_text('去光处理', exact=True).locator('..').get_by_role('switch')
    if await toggle.count() != 1:
        raise sp.PrepareError('de-light control ambiguous')
    if await toggle.get_attribute('aria-checked') == 'false':
        await toggle.click()
    if await toggle.get_attribute('aria-checked') != 'true':
        raise sp.PrepareError('de-light not enabled')
    await resolution.click()
    await page.wait_for_timeout(1500)
    states = {}
    for size in ('2K', '4K', '8K'):
        control = page.get_by_role('button', name=re.compile(r'^' + size + r'$'))
        states[size] = {'aria_pressed': await control.get_attribute('aria-pressed'),
                        'data_state': await control.get_attribute('data-state')}
    run.log['final_resolution_states'] = states
    if states['2K']['aria_pressed'] != 'true' or states['4K']['aria_pressed'] != 'false' or states['8K']['aria_pressed'] != 'false' or await toggle.get_attribute('aria-checked') != 'true':
        raise sp.PrepareError(f'texture resolution/de-light changed after settling: {states}')
    button = page.locator('button').filter(has_text=re.compile(r'生成\s*贴图')).last
    deadline = time.monotonic() + 120
    while not await button.is_enabled():
        if time.monotonic() >= deadline:
            raise sp.PrepareError('texture submit control remains disabled; no reservation or paid action')
        await page.wait_for_timeout(5000)
    label = (await button.inner_text()).replace('\n', ' ').strip()
    quote = parse_texture_quote(label)
    run.log['texture_verified'] = {'resolution': '2K', 'delight': True, 'quote': quote, 'label': label}
    await run.shot(page, 'texture_quoted_verified')
    run.save_log()
    return button, label, quote


async def process_texture(page, args, job, ledger, progress, index):
    if texture_job(job['manifest_path'], ledger) != job:
        raise sp.PrepareError('texture source/inputs changed after batch start; no paid action')
    ledger.check(job['job_id'], job['input_hash'], job['attempt_path'], job['destination'])
    run = sg.Run(job['manifest_path'], argparse.Namespace(dry_run=not args.yes, download_only=False, yes=args.yes))
    run.destination, run.attempt_path = job['destination'], job['attempt_path']
    run.log['requested'] = job['requested']
    run.log['action'] = 'texture'
    reservation = None
    try:
        progress.save('running', index, state='verifying_source')
        button, label, quote = await prepare_texture(page, run, job, args.inspect)
        if args.inspect:
            progress.save('running', index, state='inspection_only')
            return
        if quote > ledger.snapshot()['remaining_credits']:
            raise sp.PrepareError('texture quote exceeds remaining budget')
        if not args.yes:
            progress.save('running', index, state='dry_run_verified', quote=quote)
            return
        current = (await button.inner_text()).replace('\n', ' ').strip()
        if current != label or parse_texture_quote(current) != quote:
            raise sp.PrepareError('texture quote changed; no paid action')
        if await page.get_by_role('button', name='2K', exact=True).get_attribute('aria-pressed') != 'true':
            raise sp.PrepareError('2K state changed before reservation; no paid action')
        href = run.log['verified_source'].get('card_href')
        if href:
            run.log['target_project_id_verified'] = require_project_target(href, await button.get_attribute('data-trace-params'))
        before = await sg.asset_signature(page)
        balance_before = await ui_credit_balance(page) if getattr(args, 'submit_only', False) else None
        if getattr(args, 'submit_only', False) and (balance_before is None or balance_before < quote):
            raise sp.PrepareError('cannot verify visible pre-submit balance; no paid action')
        reservation = ledger.reserve(job['job_id'], job['input_hash'], quote, job['attempt_path'], job['destination'],
                                     action='texture', requested=job['requested'], verified_source=run.log['verified_source'], ui_balance_before=balance_before)
        run.log['reservation'] = reservation
        run.save_log()
        progress.save('running', index, state='reserved', quote=quote)
        await button.click()  # One paid action. No retries.
        run.ev('clicked Texture once', quoted_cost=quote)
        await run.shot(page, 'texture_after_single_click')
        if getattr(args, 'submit_only', False):
            receipt = await wait_submission_receipt(page, run, balance_before, quote)
            ledger.mark(reservation['reservation_id'], 'reserved', acceptance_receipt=receipt)
            run.log['result_collection'] = 'existing reserved task; use --recover, never --yes again'
            progress.save('running', index, state='submitted_pending_export', reservation_id=reservation['reservation_id'])
            return
        try:
            await wait_texture_result(page, run, before, min(args.wait_s, 180), progress, index)
        except sp.PrepareError as exc:
            if not str(exc).startswith('texture result timeout'):
                raise
            # Observed Studio behavior: its original viewport can stay loading
            # after a completed texture updates the existing card. One free
            # fresh-workspace export may recover it; this path never generates.
            run.ev('viewport wait expired; one free existing-task export recovery')
            if not await recover_texture(page, args, job, ledger, progress, index):
                raise sp.PrepareError('existing task currently exports only untextured source; preserve reservation')
            run.log['recovered_by_separate_export_log'] = True
            return
        ledger.mark(reservation['reservation_id'], 'confirmed', result_observed_at=now())
        staging = job['destination'].with_name(f'.texture_{uuid.uuid4().hex}.partial.glb')
        if not await sg.try_download(page, run, staging):
            raise sp.PrepareError('texture result export failed; recover existing result without re-generation')
        doc, _ = glb_parts(staging)
        if not doc.get('images') or not any('TEXCOORD_0' in p.get('attributes', {}) for m in doc['meshes'] for p in m['primitives']):
            raise sp.PrepareError('texture export has no embedded images or UV0; preserve staging and inspect')
        try:
            run.log['result_validation'] = validate_textured_result(job['source'], staging)
        except TextureValidationError as exc:
            run.log['result_validation'] = exc.report
            raise
        batch.publish_original(staging, job['destination'])
        run.log['download'].update(file=str(job['destination']), sha256=batch.digest(job['destination']))
        ledger.mark(reservation['reservation_id'], 'confirmed', download=run.log['download'])
        progress.save('running', index, state='complete', original=str(job['destination']))
    except BaseException as exc:
        if reservation:
            ledger.mark(reservation['reservation_id'], 'ambiguous', error=str(exc))
        run.ev('stopped; no texture resubmission', error=str(exc))
        if not isinstance(exc, (asyncio.CancelledError, KeyboardInterrupt)):
            try:
                await asyncio.wait_for(run.shot(page, 'texture_stopped'), timeout=10)
            except Exception:
                pass
        progress.save('stopped', index, state='stopped', error=str(exc))
        raise
    finally:
        run.save_log()


async def wait_texture_result(page, run, before, wait_s, progress, index):
    # Texturing replaces a card's timestamp instead of adding a card. Its count
    # can remain unchanged; a changed signature plus a ready viewport is needed.
    deadline, started = time.monotonic() + wait_s, time.monotonic()
    while time.monotonic() < deadline:
        await page.wait_for_timeout(5000)
        body = await sg.body_text(page)
        after = await sg.asset_signature(page)
        busy = bool(sg.PROGRESS_RE.search(body))
        toolbar = page.locator('button:has(.i-tripo\\:download)').filter(has_text='导出').first
        progress.save('running', index, state='generating', busy=busy, signature_changed=after != before)
        if after != before and not busy and await toolbar.is_visible():
            await run.shot(page, 'texture_result_ready')
            return
        if int(time.monotonic() - started) % 60 < 6:
            await run.shot(page, f'texture_wait_{int(time.monotonic()-started)}')
    raise sp.PrepareError('texture result timeout; recover existing card, never re-generate')


async def recover_texture(page, args, job, ledger, progress, index):
    """Only select/export an already-reserved task; no generation control exists here."""
    entry = next((e for e in ledger.snapshot()['reservations'] if e['job_id'] == job['job_id'] and e['input_hash'] == job['input_hash']), None)
    if not entry or entry.get('metadata', {}).get('action') != 'texture':
        raise sp.PrepareError('no matching previously reserved texture task to recover')
    href = entry.get('metadata', {}).get('verified_source', {}).get('card_href')
    if not isinstance(href, str) or not href.startswith('/workspace/generate/') or '?' in href or '#' in href:
        raise sp.PrepareError('recovery requires the saved geometry-verified project permalink; no paid action')
    run = sg.Run(job['manifest_path'], argparse.Namespace(dry_run=False, download_only=True, yes=False))
    run.destination, run.attempt_path = job['destination'], job['attempt_path']
    run.log['action'] = 'recover_texture_export_only'
    try:
        await sg.wait_workbench(page, run)
        for label in (href,):
            await page.goto('https://studio.tripo3d.com' + label, wait_until='domcontentloaded')
            await page.wait_for_timeout(4500)
            staging = job['destination'].with_name(f'.texture_recovery_{uuid.uuid4().hex}.partial.glb')
            if not await sg.try_download(page, run, staging):
                raise sp.PrepareError('existing texture export not ready; no paid action')
            try:
                validation = validate_textured_result(job['source'], staging)
            except TextureValidationError as exc:
                run.log.setdefault('recovery_rejected', []).append({'label':label, 'staging':str(staging), 'validation':exc.report})
                document, _ = glb_parts(staging)
                if exc.report.get('geometry', {}).get('equivalent') and not document.get('images'):
                    run.log['untextured_result_observed'] = True
                    progress.save('running', index, state='awaiting_texture_artifact', observed_untextured_export=str(staging))
                    return False
                continue
            run.log['result_validation'] = validation
            run.log['recovered_card_label'] = label
            batch.publish_original(staging, job['destination'])
            download = dict(run.log['download'], file=str(job['destination']), sha256=batch.digest(job['destination']))
            ledger.mark(entry['reservation_id'], 'confirmed', download=download, recovered_without_generation=True)
            run.log['download'] = download
            progress.save('running', index, state='recovered', original=str(job['destination']))
            return True
        raise sp.PrepareError('candidate task exports failed source/texture validation; originals preserved')
    finally:
        run.save_log()


async def main_async(args):
    ledger = BudgetLedger(args.ledger, args.limit)
    source = args.job_list.resolve()
    jobs = [texture_job(source.parent / path, ledger) for path in json.loads(source.read_text())['jobs']]
    if len({j['input_hash'] for j in jobs}) != len(jobs):
        raise sp.PrepareError('duplicate texture inputs')
    progress = batch.Progress(args.progress or args.ledger.with_name('texture_progress.json'), jobs, ledger, args.yes)
    pending = [(i,j) for i,j in enumerate(jobs) if not j['destination'].exists()]
    for i, job in enumerate(jobs):
        if job['destination'].exists():
            progress.save('starting', i, state='skipped_existing_original', original=str(job['destination']))
    if not args.recover:
        for _, job in pending:
            ledger.check(job['job_id'], job['input_hash'], job['attempt_path'], job['destination'])
    from playwright.async_api import async_playwright
    with batch.dedicated_profile(args.profile) as profile:
        async with async_playwright() as playwright:
            context = await playwright.chromium.launch_persistent_context(str(profile), channel='chrome', headless=False,
                       viewport={'width': 1440, 'height': 960}, locale='zh-CN', accept_downloads=True)
            context.set_default_timeout(30000)
            page = context.pages[0] if context.pages else await context.new_page()
            try:
                for index, job in pending:
                    if args.recover:
                        await recover_texture(page, args, job, ledger, progress, index)
                    else:
                        await process_texture(page, args, job, ledger, progress, index)
                remaining = [j['job_id'] for j in jobs if not j['destination'].exists()]
                state = 'submissions_complete_pending_exports' if args.submit_only else ('exports_pending' if args.recover and remaining else 'complete')
                progress.save(state, remaining_outputs=remaining)
            finally:
                await context.close()


def main():
    p = batch.parser()
    p.description = __doc__
    p.add_argument('--inspect', action='store_true', help='free source identity export and texture UI inspection only')
    p.add_argument('--recover', action='store_true', help='export/validate an existing reserved texture task; never generates')
    p.add_argument('--submit-only', action='store_true', help='submit each authorized task once, retain full reservations, collect later with --recover')
    args = p.parse_args()
    if args.inspect and args.yes:
        p.error('--inspect cannot be used with --yes')
    if args.recover and (args.yes or args.inspect):
        p.error('--recover cannot be used with --yes or --inspect')
    if args.submit_only and (not args.yes or args.recover or args.inspect):
        p.error('--submit-only requires --yes and cannot inspect/recover')
    try:
        asyncio.run(main_async(args))
    except Exception as exc:
        print(f'stopped: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
