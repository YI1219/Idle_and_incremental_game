"""Offline release gates: geometric surface identity and actually bound textures."""
import copy
import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/tripo'))


def write_glb(path, doc, binary):
    doc = copy.deepcopy(doc)
    doc['buffers'] = [{'byteLength': len(binary)}]
    raw = json.dumps(doc).encode(); raw += b' ' * (-len(raw) % 4)
    binary += b'\0' * (-len(binary) % 4)
    body = struct.pack('<II', len(raw), 0x4E4F534A) + raw + struct.pack('<II', len(binary), 0x004E4942) + binary
    path.write_bytes(struct.pack('<4sII', b'glTF', 2, len(body) + 12) + body)


def png():
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b'\0\xff\xff\xff\xff')) + chunk(b'IEND', b'')


class Builder:
    def __init__(self):
        self.binary = b''
        self.doc = {'asset': {'version': '2.0'}, 'bufferViews': [], 'accessors': [], 'nodes': [{'mesh': 0}], 'scenes': [{'nodes': [0]}], 'scene': 0}

    def view(self, data):
        self.binary += b'\0' * (-len(self.binary) % 4)
        index = len(self.doc['bufferViews'])
        self.doc['bufferViews'].append({'buffer': 0, 'byteOffset': len(self.binary), 'byteLength': len(data)})
        self.binary += data
        return index

    def accessor(self, values, kind, fmt, component):
        index = len(self.doc['accessors'])
        flat = [x for row in values for x in row] if kind != 'SCALAR' else values
        view = self.view(struct.pack('<' + fmt * len(flat), *flat))
        self.doc['accessors'].append({'bufferView': view, 'componentType': component, 'count': len(values), 'type': kind})
        return index

    def mesh(self, positions, indices, textured=False, uv=None):
        attrs = {'POSITION': self.accessor(positions, 'VEC3', 'f', 5126)}
        if textured:
            attrs['TEXCOORD_0'] = self.accessor(uv or [(0, 0), (1, 0), (0, 1)] * (len(positions) // 3), 'VEC2', 'f', 5126)
        primitive = {'attributes': attrs, 'indices': self.accessor(indices, 'SCALAR', 'I', 5125)}
        if textured:
            primitive['material'] = 0
            self.doc['images'] = [{'bufferView': self.view(png()), 'mimeType': 'image/png'}]
            self.doc['textures'] = [{'source': 0}]
            self.doc['materials'] = [{'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}}}]
        self.doc['meshes'] = [{'primitives': [primitive]}]
        return self

    def write(self, path):
        write_glb(path, self.doc, self.binary)
        return path


class TextureReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        import glb_texture_validation
        self.module = glb_texture_validation
        self.a, self.b = self.root / 'source.glb', self.root / 'result.glb'

    def fixtures(self, shift=0, seam=True):
        quad = [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)]
        Builder().mesh(quad, [0, 1, 2, 0, 2, 3]).write(self.a)
        positions = [quad[i] for i in [0, 2, 3, 0, 1, 2]] if seam else quad
        positions = [(x + shift, y, z) for x, y, z in positions]
        indices = [3, 4, 5, 0, 1, 2] if seam else [0, 1, 2, 0, 2, 3]
        uv = None if seam else [(0, 0), (1, 0), (1, 1), (0, 1)]
        return Builder().mesh(positions, indices, textured=True, uv=uv)

    def validate(self, result=None):
        if result:
            result.write(self.b)
        return self.module.validate_textured_result(self.a, self.b)

    def test_uv_seam_duplicates_and_triangle_index_reorder_are_equivalent(self):
        report = self.validate(self.fixtures())
        self.assertTrue(report['valid'])
        self.assertEqual(report['geometry']['source']['triangles'], 2)
        self.assertEqual(report['geometry']['result']['vertices'], 6)
        self.assertEqual(report['textures']['used_materials'], 1)
        json.dumps(report)

    def test_other_model_cannot_be_published(self):
        with self.assertRaisesRegex(ValueError, 'surface'):
            self.validate(self.fixtures(shift=.01))

    def test_world_parent_translation_and_column_major_matrix_are_respected(self):
        result = self.fixtures()
        source = Builder().mesh([(2, 3, 4), (3, 3, 4), (3, 4, 4), (2, 4, 4)], [0, 1, 2, 0, 2, 3])
        source.write(self.a)
        result.doc['nodes'] = [{'children': [1], 'translation': [2, 3, 4]}, {'mesh': 0, 'matrix': [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]}]
        result.doc['scenes'] = [{'nodes': [0]}]
        self.assertTrue(self.validate(result)['valid'])
        result.doc['nodes'][0]['translation'][0] = 2.1
        with self.assertRaisesRegex(ValueError, 'surface'):
            self.validate(result)

    def test_rotation_scale_and_matrix_transform_match_baked_positions(self):
        result = self.fixtures()
        result.doc['nodes'][0]['matrix'] = [0, 2, 0, 0, -3, 0, 0, 0, 0, 0, 1, 0, 4, 5, 6, 1]
        Builder().mesh([(4, 5, 6), (4, 7, 6), (1, 7, 6), (1, 5, 6)], [0, 1, 2, 0, 2, 3]).write(self.a)
        self.assertTrue(self.validate(result)['valid'])

    def test_trs_quaternion_rotation_scale_match_baked_positions(self):
        result = self.fixtures()
        result.doc['nodes'][0].update(translation=[4, 5, 6], rotation=[0, 0, 2 ** -.5, 2 ** -.5], scale=[2, 3, 1])
        Builder().mesh([(4, 5, 6), (4, 7, 6), (1, 7, 6), (1, 5, 6)], [0, 1, 2, 0, 2, 3]).write(self.a)
        self.assertTrue(self.validate(result)['valid'])

    def test_export_names_do_not_change_surface_identity(self):
        result = self.fixtures()
        result.doc['nodes'][0]['name'] = 'unrelated_export_name'
        result.doc['meshes'][0]['name'] = 'renamed'
        self.assertTrue(self.validate(result)['valid'])

    def test_exact_degenerate_triangles_are_excluded_but_counted(self):
        result = self.fixtures()
        primitive = result.doc['meshes'][0]['primitives'][0]
        primitive['indices'] = result.accessor([3, 4, 5, 0, 1, 2, 0, 0, 1], 'SCALAR', 'I', 5125)
        report = self.validate(result)
        self.assertEqual(report['geometry']['result']['discarded_exact_degenerate_triangles'], 1)

    def test_orphan_embedded_image_is_not_a_material_binding(self):
        result = self.fixtures()
        result.doc['materials'][0] = {}
        with self.assertRaisesRegex(ValueError, 'baseColor'):
            self.validate(result)

    def test_each_used_material_must_bind_embedded_base_color(self):
        result = self.fixtures()
        result.doc['materials'].append({})
        result.doc['meshes'][0]['primitives'].append(copy.deepcopy(result.doc['meshes'][0]['primitives'][0]))
        result.doc['meshes'][0]['primitives'][1]['material'] = 1
        # Duplicate source surfaces as well so geometry remains equivalent.
        source = Builder().mesh([(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)], [0, 1, 2, 0, 2, 3])
        source.doc['meshes'][0]['primitives'] *= 2; source.write(self.a)
        with self.assertRaisesRegex(ValueError, 'baseColor'):
            self.validate(result)

    def test_external_missing_image_is_rejected(self):
        result = self.fixtures(); result.doc['images'] = [{'uri': 'missing.png'}]
        with self.assertRaisesRegex(ValueError, 'embedded'):
            self.validate(result)

    def test_invalid_or_missing_uv0_is_rejected(self):
        for mode in ('missing', 'nan', 'collapsed'):
            with self.subTest(mode=mode):
                result = self.fixtures(); attrs = result.doc['meshes'][0]['primitives'][0]['attributes']
                if mode == 'missing':
                    attrs.pop('TEXCOORD_0')
                else:
                    coords = [(float('nan'), 0)] * 6 if mode == 'nan' else [(0, 0)] * 6
                    attrs['TEXCOORD_0'] = result.accessor(coords, 'VEC2', 'f', 5126)
                with self.assertRaisesRegex(ValueError, 'UV0'):
                    self.validate(result)

    def test_unused_untextured_material_does_not_fail_used_material_check(self):
        result = self.fixtures(); result.doc['materials'].append({})
        self.assertEqual(self.validate(result)['textures']['used_materials'], 1)

    def test_invalid_embedded_image_is_rejected(self):
        result = self.fixtures(); result.doc['images'][0]['bufferView'] = result.view(b'not a png')
        with self.assertRaisesRegex(ValueError, 'image'):
            self.validate(result)

    def test_triangle_multiplicity_is_preserved(self):
        result = self.fixtures(); p = result.doc['meshes'][0]['primitives'][0]
        p['indices'] = result.accessor([3, 4, 5, 0, 1, 2, 0, 1, 2], 'SCALAR', 'I', 5125)
        with self.assertRaisesRegex(ValueError, 'surface'):
            self.validate(result)

    def test_sub_tolerance_rounding_difference_passes_and_wrong_scale_fails(self):
        result = self.fixtures(shift=1e-8)
        self.assertTrue(self.validate(result)['valid'])
        result.doc['nodes'][0]['scale'] = [1.01, 1.01, 1.01]
        with self.assertRaisesRegex(ValueError, 'surface'):
            self.validate(result)

    def test_real_white_fixture_can_gain_per_face_uv_seams_without_changing_surface(self):
        source = ROOT / 'art/source/style_library_20261112/props/round_stone_lantern/tripo/original_white.glb'
        if not source.is_file():
            self.skipTest('preserved project white GLB fixture not available')
        raw = source.read_bytes(); offset = 12; doc = binary = None
        while offset < len(raw):
            size, kind = struct.unpack_from('<II', raw, offset); payload = raw[offset+8:offset+8+size]
            if kind == 0x4E4F534A: doc = json.loads(payload)
            if kind == 0x004E4942: binary = payload
            offset += size + 8
        builder = Builder(); builder.doc = copy.deepcopy(doc); builder.binary = binary[:doc['buffers'][0]['byteLength']]
        # Independently decode the known real FLOAT POSITION / unsigned indices.
        def rows(index):
            accessor = doc['accessors'][index]; view = doc['bufferViews'][accessor['bufferView']]
            code, size = {5121: ('B', 1), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}[accessor['componentType']]
            width = {'SCALAR': 1, 'VEC3': 3}[accessor['type']]
            start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0); stride = view.get('byteStride', size * width)
            return [struct.unpack_from('<' + code * width, binary, start + i * stride) for i in range(accessor['count'])]
        for mesh in builder.doc['meshes']:
            for primitive in mesh['primitives']:
                self.assertEqual(primitive.get('mode', 4), 4)
                positions = rows(primitive['attributes']['POSITION'])
                indices = [r[0] for r in rows(primitive['indices'])] if 'indices' in primitive else list(range(len(positions)))
                expanded = [positions[i] for i in indices]
                primitive['attributes'] = {'POSITION': builder.accessor(expanded, 'VEC3', 'f', 5126), 'TEXCOORD_0': builder.accessor([(0, 0), (1, 0), (0, 1)] * (len(expanded) // 3), 'VEC2', 'f', 5126)}
                primitive['indices'] = builder.accessor(list(range(len(expanded))), 'SCALAR', 'I', 5125)
                primitive['material'] = 0
        builder.doc['images'] = [{'bufferView': builder.view(png()), 'mimeType': 'image/png'}]
        builder.doc['textures'] = [{'source': 0}]
        builder.doc['materials'] = [{'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}}}]
        builder.write(self.b)
        report = self.module.validate_textured_result(source, self.b)
        self.assertTrue(report['valid'])
        self.assertGreater(report['geometry']['source']['triangles'], 100)
        self.assertGreater(report['geometry']['result']['vertices'], report['geometry']['source']['vertices'])

    def test_white_source_real_fixture_is_not_mistaken_for_textured_result(self):
        path = ROOT / 'art/source/style_library_20261112/props/round_stone_lantern/tripo/original_white.glb'
        if not path.is_file():
            self.skipTest('preserved project white GLB fixture not available')
        report = self.module.compare_geometry_surfaces(path, path)
        self.assertTrue(report['equivalent'])
        self.assertGreater(report['source']['triangles'], 100)
        with self.assertRaises(ValueError) as caught:
            self.module.validate_textured_result(path, path)
        self.assertFalse(caught.exception.report['valid'])


if __name__ == '__main__':
    unittest.main()
