import argparse
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools' / 'tripo'))
import studio_prepare as sp
import studio_generate as sg


class InputTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        (self.base / 'one.png').write_bytes(b'input fixture')

    def test_single_resolves_only_selected_image(self):
        manifest = {'submission_mode': 'single_image', 'input': {'file': 'one.png'},
                    'views': {'front': {'file': 'missing.png'}}}
        self.assertEqual(sp.image_mode(manifest), 'single_image')
        self.assertEqual(sp.resolve_inputs(manifest, self.base), {'single': self.base / 'one.png'})

    def test_old_multiview_order_and_missing_image_rejection(self):
        manifest = {'views': {k: {'file': 'one.png'} for k in sp.VIEW_ORDER}}
        self.assertEqual(sp.image_mode(manifest), 'multiview')
        self.assertEqual(list(sp.resolve_inputs(manifest, self.base)), list(sp.VIEW_ORDER))
        manifest['views']['back']['file'] = 'missing.png'
        with self.assertRaises(sp.PrepareError):
            sp.resolve_inputs(manifest, self.base)

    def test_unknown_mode_and_missing_single_are_rejected(self):
        for manifest in [{'submission_mode': 'mystery'}, {'submission_mode': 'single_image'}]:
            with self.assertRaises(sp.PrepareError):
                sp.resolve_inputs(manifest, self.base)

    def test_changed_selected_image_is_rejected_before_browser_launch(self):
        manifest = {'submission_mode': 'single_image',
                    'input': {'file': 'one.png', 'sha256': 'wrong'}}
        with self.assertRaises(sp.PrepareError):
            sp.resolve_inputs(manifest, self.base)

    def test_current_manifest_parameters_are_not_silently_dropped(self):
        manifest = {'recommended_parameters': {'route': 'smart_mesh', 'topology': 'triangles',
                     'target_triangles': 2500, 'texture': False}}
        settings = sp.settings_block(manifest)
        self.assertEqual(sp.face_limit(settings), 2500)
        self.assertEqual(sp.normalize_topology(settings), 'triangles')
        self.assertFalse(sp.want_texture(settings))

    def test_destination_and_attempt_are_scoped_to_one_selected_task(self):
        manifest = {'submission_mode': 'single_image', 'input': {'file': 'one.png'},
                    'output_original': 'tripo/cliff.glb'}
        path = self.base / 'manifest.json'
        path.write_text(json.dumps(manifest))
        args = argparse.Namespace(dry_run=False, download_only=False)
        run = sg.Run(path, args)
        self.assertEqual(run.destination, self.base / 'tripo' / 'cliff.glb')
        run.reserve_generation()
        with self.assertRaises(sp.PrepareError):
            sg.Run(path, args).reserve_generation()
        self.assertTrue(run.attempt_path.is_file())


if __name__ == '__main__':
    unittest.main()
