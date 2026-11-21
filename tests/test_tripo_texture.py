"""Offline identity checks protecting paid texture submissions."""
import json
import struct
import sys
import tempfile
import unittest
import asyncio
import argparse
from unittest.mock import AsyncMock, Mock, patch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/tripo'))


class TextureIdentityTests(unittest.TestCase):
    def fixture(self, path, x=1.0, extra=False):
        data = struct.pack('<9f3I', 0, 0, 0, x, 0, 0, 0, 1, 0, 0, 1, 2)
        doc = {'asset': {'version': '2.0'}, 'buffers': [{'byteLength': len(data)}],
               'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': 36},
                               {'buffer': 0, 'byteOffset': 36, 'byteLength': 12}],
               'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
                             {'bufferView': 1, 'componentType': 5125, 'count': 3, 'type': 'SCALAR'}],
               'meshes': [{'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1}]}],
               'nodes': [{'mesh': 0, 'name': 'tripo_node_sample'}],
               'scenes': [{'nodes': [0]}], 'scene': 0}
        if extra:
            doc['extras'] = {'export_time': 'different'}
        jb = json.dumps(doc).encode(); jb += b' ' * (-len(jb) % 4)
        payload = struct.pack('<II', len(jb), 0x4e4f534a) + jb + struct.pack('<II', len(data), 0x004e4942) + data
        path.write_bytes(struct.pack('<4sII', b'glTF', 2, len(payload) + 12) + payload)

    def test_geometry_identity_ignores_export_metadata_but_detects_wrong_shape(self):
        import studio_texture_batch as module
        with tempfile.TemporaryDirectory() as temp:
            a, b, c = [Path(temp)/name for name in ('a.glb', 'b.glb', 'c.glb')]
            self.fixture(a); self.fixture(b, extra=True); self.fixture(c, x=2)
            self.assertEqual(module.geometry_identity(a), module.geometry_identity(b))
            self.assertNotEqual(module.geometry_identity(a), module.geometry_identity(c))

    def test_texture_quote_cannot_be_confused_with_geometry_or_discount(self):
        import studio_texture_batch as module
        self.assertEqual(module.parse_texture_quote('生成贴图\n30'), 30)
        for label in ('生成模型30', '生成贴图30 100', '生成贴图-30', '生成贴图0', '生成贴图30.5'):
            with self.subTest(label=label), self.assertRaises(Exception):
                module.parse_texture_quote(label)

    def test_generate_target_uses_project_id_independent_of_workspace_mode(self):
        import studio_texture_batch as module
        project='a588d889-5d73-4170-bfd9-a5dc27ac7f04'
        for mode in ('generate','texture'):
            href='/workspace/'+mode+'/small-house-'+project
            self.assertEqual(module.require_project_target(href,json.dumps({'project_id':project})),project)
        with self.assertRaises(Exception):
            module.require_project_target('/workspace/generate/small-house-'+project,json.dumps({'project_id':'another'}))

    def test_credit_receipt_parses_only_the_visible_upgrade_header(self):
        import studio_texture_batch as module
        self.assertEqual(module.credit_balance_from_text('ICP\n83\n\n22,840\n\n升级\n生成贴图10'),22840)
        self.assertIsNone(module.credit_balance_from_text('生成贴图10'))

    def test_submit_receipt_waits_for_the_exact_quote_debit(self):
        import studio_texture_batch as module
        page=Mock(wait_for_timeout=AsyncMock());run=Mock(log={})
        with patch.object(module,'ui_credit_balance',AsyncMock(side_effect=[1000,990])):
            result=asyncio.run(module.wait_submission_receipt(page,run,1000,10,1))
        self.assertEqual(result['after'],990)
        self.assertEqual(result['quote'],10)

    def test_failed_result_never_resubmits_and_keeps_full_texture_quote(self):
        import studio_texture_batch as module
        from budget_ledger import BudgetLedger
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            ledger = BudgetLedger(root/'budget.json', 100)
            job = {'job_id':'texture_one', 'input_hash':'texture_hash', 'manifest_path':root/'manifest.json',
                   'attempt_path':root/'attempt.json', 'destination':root/'original_textured.glb', 'requested':{}}
            run = Mock(log={'verified_source':{'geometry_exact_match':True}}, shot=AsyncMock(), save_log=Mock())
            button = Mock(inner_text=AsyncMock(return_value='生成贴图30'), click=AsyncMock())
            args = argparse.Namespace(yes=True, inspect=False, wait_s=10)
            page = Mock()
            page.get_by_role.return_value.get_attribute = AsyncMock(return_value='true')
            with patch.object(module.sg, 'Run', return_value=run), \
                 patch.object(module,'texture_job',return_value=job), \
                 patch.object(module, 'prepare_texture', AsyncMock(return_value=(button,'生成贴图30',30))), \
                 patch.object(module.sg, 'asset_signature', AsyncMock(return_value=[])), \
                 patch.object(module, 'wait_texture_result', AsyncMock(side_effect=RuntimeError('connection lost'))):
                with self.assertRaisesRegex(RuntimeError, 'connection lost'):
                    asyncio.run(module.process_texture(page,args,job,ledger,Mock(),0))
            self.assertEqual(button.click.await_count, 1)
            state=ledger.snapshot()
            self.assertEqual(state['committed_credits'],30)
            self.assertEqual(state['reservations'][0]['state'],'ambiguous')
            with self.assertRaises(Exception):
                ledger.check(job['job_id'],job['input_hash'],job['attempt_path'],job['destination'])

    def test_over_budget_texture_has_no_paid_click(self):
        import studio_texture_batch as module
        from budget_ledger import BudgetLedger
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);ledger=BudgetLedger(root/'budget.json',20)
            job={'job_id':'texture_one','input_hash':'texture_hash','manifest_path':root/'manifest.json',
                 'attempt_path':root/'attempt.json','destination':root/'result.glb','requested':{}}
            run=Mock(log={},shot=AsyncMock(),save_log=Mock())
            button=Mock(click=AsyncMock())
            args=argparse.Namespace(yes=True,inspect=False,wait_s=10)
            with patch.object(module.sg,'Run',return_value=run), \
                 patch.object(module,'texture_job',return_value=job), \
                 patch.object(module,'prepare_texture',AsyncMock(return_value=(button,'生成贴图30',30))):
                with self.assertRaisesRegex(Exception,'exceeds remaining'):
                    asyncio.run(module.process_texture(Mock(),args,job,ledger,Mock(),0))
            self.assertEqual(button.click.await_count,0)
            self.assertEqual(ledger.snapshot()['committed_credits'],0)

    def test_confirmed_source_cannot_silently_change_after_geometry_generation(self):
        import studio_texture_batch as module
        from budget_ledger import BudgetLedger
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);ledger=BudgetLedger(root/'budget.json',100)
            source=root/'original_white.glb';attempt=root/'source.attempt'
            entry=ledger.reserve('geometry','original_inputs',30,attempt,source)
            self.fixture(source)
            ledger.mark(entry['reservation_id'],'confirmed',download={'sha256':module.batch.digest(source)})
            base={'manifest_path':root/'manifest.json','destination':source.resolve(),'input_hash':'original_inputs','job_id':'geometry'}
            with patch.object(module.batch,'load_job',return_value=base):
                module.texture_job(base['manifest_path'],ledger)
                self.fixture(source,x=2)
                with self.assertRaisesRegex(Exception,'hash|changed|match'):
                    module.texture_job(base['manifest_path'],ledger)

    def test_texture_completion_accepts_replaced_timestamp_with_same_card_count(self):
        import studio_texture_batch as module
        page=Mock(wait_for_timeout=AsyncMock())
        page.locator.return_value.filter.return_value.first.is_visible=AsyncMock(return_value=True)
        run=Mock(shot=AsyncMock())
        with patch.object(module.sg,'body_text',AsyncMock(return_value='生成贴图 10 导出')), \
             patch.object(module.sg,'asset_signature',AsyncMock(return_value=['11-12 12:05','11-12 11:52'])):
            asyncio.run(module.wait_texture_result(page,run,['11-12 11:24','11-12 11:52'],1,Mock(),0))
        self.assertEqual(run.shot.await_count,1)

    def test_submit_only_reserves_once_and_requires_export_recovery(self):
        import studio_texture_batch as module
        from budget_ledger import BudgetLedger
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);ledger=BudgetLedger(root/'budget.json',100)
            job={'job_id':'pending_texture','input_hash':'shape_ref_settings','manifest_path':root/'manifest.json',
                 'attempt_path':root/'attempt.json','destination':root/'result.glb','requested':{}}
            run=Mock(log={'verified_source':{'geometry_exact_match':True}},shot=AsyncMock(),save_log=Mock())
            button=Mock(inner_text=AsyncMock(return_value='生成贴图10'),click=AsyncMock())
            page=Mock();page.get_by_role.return_value.get_attribute=AsyncMock(return_value='true')
            args=argparse.Namespace(yes=True,inspect=False,submit_only=True,wait_s=10)
            waiter=AsyncMock()
            with patch.object(module,'texture_job',return_value=job),patch.object(module.sg,'Run',return_value=run), \
                 patch.object(module,'prepare_texture',AsyncMock(return_value=(button,'生成贴图10',10))), \
                 patch.object(module,'ui_credit_balance',AsyncMock(return_value=1000)), \
                 patch.object(module,'wait_submission_receipt',AsyncMock(return_value={'before':1000,'after':990,'quote':10})), \
                 patch.object(module.sg,'asset_signature',AsyncMock(return_value=[])), \
                 patch.object(module,'wait_texture_result',waiter):
                asyncio.run(module.process_texture(page,args,job,ledger,Mock(),0))
                with self.assertRaises(Exception):
                    asyncio.run(module.process_texture(page,args,job,ledger,Mock(),0))
            self.assertEqual(button.click.await_count,1)
            self.assertEqual(waiter.await_count,0)
            self.assertEqual(ledger.snapshot()['reservations'][0]['state'],'reserved')
            self.assertEqual(ledger.snapshot()['committed_credits'],10)
            self.assertFalse(job['destination'].exists())

    def test_recovery_without_verified_permalink_stops_before_browser_actions(self):
        import studio_texture_batch as module
        from budget_ledger import BudgetLedger
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);ledger=BudgetLedger(root/'budget.json',100)
            job={'job_id':'old_texture','input_hash':'old_hash','manifest_path':root/'manifest.json',
                 'destination':root/'result.glb','attempt_path':root/'attempt.json'}
            ledger.reserve(job['job_id'],job['input_hash'],10,job['attempt_path'],job['destination'],action='texture',verified_source={})
            page=Mock()
            with patch.object(module.sg,'wait_workbench',AsyncMock()) as ready:
                with self.assertRaisesRegex(Exception,'permalink'):
                    asyncio.run(module.recover_texture(page,Mock(),job,ledger,Mock(),0))
                self.assertEqual(ready.await_count,0)
            self.assertEqual(ledger.snapshot()['committed_credits'],10)

    def test_recovery_of_untextured_source_keeps_reservation_and_never_publishes(self):
        import studio_texture_batch as module
        from budget_ledger import BudgetLedger
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);source=root/'white.glb';self.fixture(source)
            ledger=BudgetLedger(root/'budget.json',100)
            job={'job_id':'pending','input_hash':'input','manifest_path':root/'manifest.json','source':source,
                 'destination':root/'textured.glb','attempt_path':root/'attempt.json'}
            ledger.reserve(job['job_id'],job['input_hash'],10,job['attempt_path'],job['destination'],action='texture',
                           verified_source={'card_href':'/workspace/generate/observed-123d7e9c-ceaf-4c13-be69-c3a72025521b'})
            run=Mock(log={},save_log=Mock(),shot=AsyncMock())
            page=Mock(goto=AsyncMock(),wait_for_timeout=AsyncMock())
            async def export(page,run,staging):
                Path(staging).write_bytes(source.read_bytes());return True
            with patch.object(module.sg,'Run',return_value=run),patch.object(module.sg,'wait_workbench',AsyncMock()), \
                 patch.object(module.sg,'try_download',AsyncMock(side_effect=export)),patch.object(module.batch,'publish_original') as publish:
                result=asyncio.run(module.recover_texture(page,Mock(),job,ledger,Mock(),0))
                self.assertFalse(result);publish.assert_not_called()
            self.assertEqual(ledger.snapshot()['committed_credits'],10)
            self.assertEqual(ledger.snapshot()['reservations'][0]['state'],'reserved')
            self.assertFalse(job['destination'].exists())


if __name__ == '__main__':
    unittest.main()
