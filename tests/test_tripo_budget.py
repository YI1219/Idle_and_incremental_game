"""Offline tests: these never launch a browser or contact Tripo."""
import importlib
import asyncio
import contextlib
import io
from unittest.mock import AsyncMock, patch
import json
import multiprocessing
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools' / 'tripo'))


def concurrent_reserve(root, number, queue):
    from budget_ledger import BudgetLedger, BudgetError
    root = Path(root)
    try:
        BudgetLedger(root / 'ledger.json', 100).reserve(
            f'job{number}', f'hash{number}', 60,
            root / f'{number}.generation_attempt.json', root / f'{number}.glb')
        queue.put('reserved')
    except BudgetError:
        queue.put('refused')


class BudgetTests(unittest.TestCase):
    def setUp(self):
        self.module = importlib.import_module('budget_ledger')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.ledger = self.module.BudgetLedger(self.root / 'ledger.json', 100)

    def reserve(self, name='one', cost=60, input_hash=None):
        return self.ledger.reserve(name, input_hash or name, cost,
                                   self.root / f'{name}.generation_attempt.json',
                                   self.root / f'{name}.glb')

    def test_full_quote_is_reserved_and_budget_cannot_be_exceeded(self):
        self.reserve(cost=60)
        with self.assertRaises(self.module.BudgetError):
            self.reserve('two', cost=41)
        self.assertEqual(self.ledger.snapshot()['committed_credits'], 60)
        self.assertFalse((self.root / 'two.generation_attempt.json').exists())
        self.reserve('three', cost=40)
        self.assertEqual(self.ledger.snapshot()['committed_credits'], 100)

    def test_job_and_input_hash_are_both_duplicate_guards(self):
        self.reserve()
        with self.assertRaises(self.module.BudgetError):
            self.reserve(input_hash='changed')
        with self.assertRaises(self.module.BudgetError):
            self.reserve('copy', input_hash='one')
        self.assertEqual(len(self.ledger.snapshot()['reservations']), 1)

    def test_reserved_confirmed_and_ambiguous_keep_full_budget(self):
        first = self.reserve(cost=30)
        second = self.reserve('two', cost=30)
        self.ledger.mark(first['reservation_id'], 'confirmed')
        self.ledger.mark(second['reservation_id'], 'ambiguous', error='lost connection')
        self.reserve('three', cost=30)
        self.assertEqual(self.ledger.snapshot()['committed_credits'], 90)
        with self.assertRaises(self.module.BudgetError):
            self.reserve('four', cost=11)

    def test_existing_original_or_attempt_blocks_even_empty_ledger(self):
        (self.root / 'one.glb').write_bytes(b'original')
        with self.assertRaises(self.module.BudgetError):
            self.reserve()
        (self.root / 'two.generation_attempt.json').write_text('{}')
        with self.assertRaises(self.module.BudgetError):
            self.reserve('two')
        self.assertEqual((self.root / 'one.glb').read_bytes(), b'original')
        self.assertEqual(self.ledger.snapshot()['committed_credits'], 0)

    def test_negative_zero_fraction_bool_and_string_costs_are_rejected(self):
        for cost in (-1, 0, 1.5, True, '30', None):
            with self.subTest(cost=cost), self.assertRaises(self.module.BudgetError):
                self.reserve(cost=cost)
        for limit in (-1, 0, 15001, True, 1.5):
            with self.subTest(limit=limit), self.assertRaises(self.module.BudgetError):
                self.module.BudgetLedger(self.root / 'bad.json', limit)

    def test_corrupt_negative_reservation_fails_closed(self):
        self.reserve()
        path = self.root / 'ledger.json'
        data = json.loads(path.read_text())
        data['reservations'][0]['quoted_cost'] = -60
        path.write_text(json.dumps(data))
        with self.assertRaises(self.module.BudgetError):
            self.reserve('two')

    def test_existing_ledger_limit_cannot_be_raised(self):
        self.reserve()
        other = self.module.BudgetLedger(self.root / 'ledger.json', 200)
        with self.assertRaises(self.module.BudgetError):
            other.reserve('two', 'two', 60, self.root/'two.attempt', self.root/'two.glb')

    def test_two_processes_reserve_under_one_flock(self):
        ctx = multiprocessing.get_context('spawn')
        queue = ctx.Queue()
        processes = [ctx.Process(target=concurrent_reserve, args=(str(self.root), i, queue)) for i in range(2)]
        for process in processes:
            process.start()
        for process in processes:
            process.join(15)
            self.assertEqual(process.exitcode, 0)
        self.assertEqual(sorted([queue.get(timeout=2), queue.get(timeout=2)]), ['refused', 'reserved'])
        self.assertEqual(self.ledger.snapshot()['committed_credits'], 60)


class BatchOfflineTests(unittest.TestCase):
    def setUp(self):
        self.batch = importlib.import_module('studio_batch')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def make_manifest(self, directory='asset', **updates):
        root = self.root / directory
        root.mkdir(exist_ok=True)
        (root / 'input.png').write_bytes(b'fake image bytes: hashing test only')
        manifest = {'submission_mode': 'single_image', 'input': {'file': 'input.png'},
                    'studio': {'route': 'high_quality', 'texture': False, 'target_faces': 10000, 'topology': 'triangles'},
                    'output_original': 'tripo/geometry_only.glb'}
        manifest.update(updates)
        path = root / 'manifest.json'
        path.write_text(json.dumps(manifest))
        return path

    def test_default_cli_is_dry_run_and_yes_is_explicit(self):
        args = self.batch.parser().parse_args(['jobs.json', '--ledger', 'ledger.json'])
        self.assertFalse(args.yes)
        self.assertEqual(args.limit, 15000)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.batch.parser().parse_args(['jobs.json', '--ledger', 'ledger.json', '--yes', '--dry-run'])

    def test_quoted_price_requires_one_unambiguous_positive_integer(self):
        self.assertEqual(self.batch.parse_quote('生成模型 30'), 30)
        self.assertEqual(self.batch.parse_quote('生成模型 1,000'), 1000)
        for label in ('生成模型', '生成模型 -30', '生成模型 0', '生成模型 30.5', '生成模型 30 100', '生成模型 1,00'):
            with self.subTest(label=label), self.assertRaises(self.batch.sp.PrepareError):
                self.batch.parse_quote(label)

    def test_hash_uses_real_input_bytes_and_requested_settings(self):
        one = self.batch.load_job(self.make_manifest())
        copy = self.batch.load_job(self.make_manifest('copy'))
        self.assertEqual(one['input_hash'], copy['input_hash'])
        (self.root / 'copy' / 'input.png').write_bytes(b'changed')
        changed = self.batch.load_job(self.root / 'copy' / 'manifest.json')
        self.assertNotEqual(one['input_hash'], changed['input_hash'])

    def test_wrong_hash_texture_route_face_count_or_missing_output_fails(self):
        variants = [
            {'input': {'file': 'input.png', 'sha256': 'wrong'}},
            {'studio': {'route': 'high_quality', 'texture': True, 'target_faces': 10000}},
            {'studio': {'route': 'smart_mesh', 'texture': False, 'target_faces': 10000}},
            {'studio': {'route': 'high_quality', 'texture': False, 'target_faces': -1}},
            {'studio': {'route': 'high_quality', 'texture': False, 'target_faces': 1.5}},
            {'output_original': ''},
        ]
        for variant in variants:
            with self.subTest(variant=variant), self.assertRaises(self.batch.sp.PrepareError):
                self.batch.load_job(self.make_manifest(**variant))

    def test_list_duplicate_inputs_fail_before_browser(self):
        first = self.make_manifest()
        second = self.make_manifest('copy')
        path = self.root / 'jobs.json'
        path.write_text(json.dumps({'jobs': [str(first), str(second)]}))
        with self.assertRaises(self.batch.sp.PrepareError):
            self.batch.load_jobs(path)

    def test_publishing_download_never_overwrites_original(self):
        destination = self.root / 'original.glb'
        staging = self.root / 'staging.glb'
        destination.write_bytes(b'original')
        staging.write_bytes(b'new')
        with self.assertRaises(FileExistsError):
            self.batch.publish_original(staging, destination)
        self.assertEqual(destination.read_bytes(), b'original')
        destination.unlink()
        self.batch.publish_original(staging, destination)
        self.assertEqual(destination.read_bytes(), b'new')
        self.assertFalse(staging.exists())


    def test_progress_json_records_job_state_and_full_budget(self):
        job = self.batch.load_job(self.make_manifest())
        ledger = self.batch.BudgetLedger(self.root / 'ledger.json', 100)
        progress = self.batch.Progress(self.root / 'progress.json', [job], ledger, False)
        progress.save('running', 0, state='quoted', quoted_cost=30)
        data = json.loads((self.root / 'progress.json').read_text())
        self.assertEqual(data['state'], 'running')
        self.assertEqual(data['jobs'][0]['state'], 'quoted')
        self.assertEqual(data['budget']['remaining_credits'], 100)

    def test_insufficient_budget_never_clicks(self):
        self.run_submission_case(quote=101, click_error=None, expected_clicks=0, expected_commitment=0)

    def test_uncertain_click_is_once_and_blocks_resubmission(self):
        self.run_submission_case(quote=30, click_error=RuntimeError('connection lost'),
                                 expected_clicks=1, expected_commitment=30)


    def test_dry_run_cannot_reserve_or_click_and_success_publishes_original(self):
        for paid in (False, True):
            with self.subTest(paid=paid):
                job = self.batch.load_job(self.make_manifest('paid' if paid else 'dry'))
                ledger = self.batch.BudgetLedger(self.root / ('paid.json' if paid else 'dry.json'), 100)
                argv = ['unused.json', '--ledger', str(ledger.path)] + (['--yes'] if paid else [])
                args = self.batch.parser().parse_args(argv)
                progress = self.batch.Progress(self.root / 'progress.json', [job], ledger, paid)
                button = type('Button', (), {})()
                button.inner_text = AsyncMock(return_value='生成模型 30')
                button.click = AsyncMock()
                async def prepared(page, run, entry):
                    run.log['quote'] = {'quoted_cost': 30, 'button_text': '生成模型 30'}
                    return button, '生成模型 30', 30
                async def downloaded(page, run, staging):
                    Path(staging).write_bytes(b'glTF' + bytes([2, 0, 0, 0, 12, 0, 0, 0]))
                    run.log['download'] = {'file': str(staging), 'bytes': 12}
                    return True
                with patch.object(self.batch, 'prepare_hq', side_effect=prepared), \
                     patch.object(self.batch.sg, 'asset_signature', AsyncMock(return_value=[])), \
                     patch.object(self.batch.sg.Run, 'shot', AsyncMock(return_value='offline.png')), \
                     patch.object(self.batch, 'wait_result', AsyncMock()), \
                     patch.object(self.batch.sg, 'dismiss_tips', AsyncMock()), \
                     patch.object(self.batch.sg, 'try_download', side_effect=downloaded):
                    asyncio.run(self.batch.process_job(None, args, job, ledger, progress, 0))
                self.assertEqual(button.click.await_count, int(paid))
                self.assertEqual(ledger.snapshot()['committed_credits'], 30 if paid else 0)
                self.assertEqual(job['destination'].exists(), paid)
                self.assertEqual(job['attempt_path'].exists(), paid)
                if paid:
                    self.assertEqual(ledger.snapshot()['reservations'][0]['state'], 'confirmed')
                    self.assertEqual(json.loads(progress.path.read_text())['jobs'][0]['state'], 'complete')

    def run_submission_case(self, quote, click_error, expected_clicks, expected_commitment):
        job = self.batch.load_job(self.make_manifest())
        ledger = self.batch.BudgetLedger(self.root / 'ledger.json', 100)
        args = self.batch.parser().parse_args(['unused.json', '--ledger', str(ledger.path), '--yes'])
        progress = self.batch.Progress(self.root / 'progress.json', [job], ledger, True)
        button = type('Button', (), {})()
        label = f'生成模型 {quote}'
        button.inner_text = AsyncMock(return_value=label)
        button.click = AsyncMock(side_effect=click_error)
        async def prepared(page, run, entry):
            run.log['quote'] = {'quoted_cost': quote, 'button_text': label}
            return button, label, quote
        with patch.object(self.batch, 'prepare_hq', side_effect=prepared), \
             patch.object(self.batch.sg, 'asset_signature', AsyncMock(return_value=[])), \
             patch.object(self.batch.sg.Run, 'shot', AsyncMock(return_value='offline.png')):
            with self.assertRaises((self.batch.BudgetError, RuntimeError)):
                asyncio.run(self.batch.process_job(None, args, job, ledger, progress, 0))
            self.assertEqual(button.click.await_count, expected_clicks)
            self.assertEqual(ledger.snapshot()['committed_credits'], expected_commitment)
            if expected_clicks:
                reservation = ledger.snapshot()['reservations'][0]
                self.assertEqual(reservation['state'], 'ambiguous')
                self.assertTrue(job['attempt_path'].exists())
                with self.assertRaises(self.batch.BudgetError):
                    asyncio.run(self.batch.process_job(None, args, job, ledger, progress, 0))
                self.assertEqual(button.click.await_count, 1)


if __name__ == '__main__':
    unittest.main()
