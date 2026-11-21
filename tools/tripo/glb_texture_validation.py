"""Offline GLB release gate; standard library only, no import/render side effects.

validate_textured_result(source, result, normalized_tolerance=1e-6) returns a JSON
audit report. TextureValidationError is a ValueError with a .report on failure.
Surface equivalence compares a MULTISET of unordered triangle corners after node
world transforms. Names, vertex/index order, normals and UV seam vertex splitting
are ignored. Winding/shading correctness and art acceptance are separate reviews.
One shared source-bounds origin/scale is used, never independent normalization.
The tolerance is a rounding-grid precision, not a nearest-neighbour distance test.
Unsupported deformation/compression fails closed rather than guessing geometry.
"""
from __future__ import annotations

from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib


class TextureValidationError(ValueError):
    def __init__(self, message, report):
        super().__init__(message)
        self.report = report


_COMPONENT = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2),
              5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
_WIDTH = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
_IDENTITY = (1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1.)


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _finite(values, label):
    _require(all(isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) for v in values), label + ' contains non-finite/invalid numbers')


def _multiply(a, b):
    return tuple(sum(a[r * 4 + k] * b[k * 4 + c] for k in range(4)) for r in range(4) for c in range(4))


def _transform(matrix, point):
    result = tuple(sum(matrix[r * 4 + k] * point[k] for k in range(3)) + matrix[r * 4 + 3] for r in range(3))
    _finite(result, 'world POSITION')
    return result


def _node_matrix(node):
    if 'matrix' in node:
        _require(not any(k in node for k in ('translation', 'rotation', 'scale')), 'node mixes matrix and TRS')
        values = node['matrix']; _require(len(values) == 16, 'node matrix must have 16 elements'); _finite(values, 'matrix')
        result = tuple(values[c * 4 + r] for r in range(4) for c in range(4))
        _require(all(abs(result[i] - v) <= 1e-12 for i, v in ((12, 0), (13, 0), (14, 0), (15, 1))), 'non-affine node matrix unsupported')
        return result
    translation = node.get('translation', [0, 0, 0]); scale = node.get('scale', [1, 1, 1]); q = node.get('rotation', [0, 0, 0, 1])
    _require(len(translation) == len(scale) == 3 and len(q) == 4, 'invalid node TRS dimensions')
    _finite(translation + scale + q, 'node TRS')
    norm = math.sqrt(sum(v * v for v in q)); _require(abs(norm - 1.) < 1e-4, 'node quaternion must be unit length')
    x, y, z, w = [v / norm for v in q]
    rotation = (1 - 2 * (y*y + z*z), 2 * (x*y - z*w), 2 * (x*z + y*w), 0,
                2 * (x*y + z*w), 1 - 2 * (x*x + z*z), 2 * (y*z - x*w), 0,
                2 * (x*z - y*w), 2 * (y*z + x*w), 1 - 2 * (x*x + y*y), 0, 0, 0, 0, 1)
    return tuple(translation[r] if c == 3 and r < 3 else (rotation[r*4+c] * scale[c] if r < 3 and c < 3 else rotation[r*4+c]) for r in range(4) for c in range(4))


def _degenerate(points):
    a, b, c = points
    u = [b[i] - a[i] for i in range(3)]; v = [c[i] - a[i] for i in range(3)]
    return (u[1]*v[2] - u[2]*v[1], u[2]*v[0] - u[0]*v[2], u[0]*v[1] - u[1]*v[0]) == (0, 0, 0)


class _GLB:
    def __init__(self, path):
        self.path = Path(path)
        raw = self.path.read_bytes()
        self.sha256 = hashlib.sha256(raw).hexdigest()
        _require(len(raw) >= 20 and struct.unpack_from('<4sII', raw) == (b'glTF', 2, len(raw)), 'invalid GLB header/length')
        self.doc, self.binary = None, None
        offset = 12
        while offset < len(raw):
            _require(offset + 8 <= len(raw), 'truncated GLB chunk header')
            size, kind = struct.unpack_from('<II', raw, offset)
            _require(size % 4 == 0 and offset + 8 + size <= len(raw), 'truncated/unaligned GLB chunk')
            payload = raw[offset + 8:offset + 8 + size]
            if kind == 0x4e4f534a:
                _require(self.doc is None, 'duplicate JSON chunk'); self.doc = json.loads(payload)
            elif kind == 0x004e4942:
                _require(self.binary is None, 'duplicate BIN chunk'); self.binary = payload
            offset += size + 8
        _require(isinstance(self.doc, dict) and self.binary is not None, 'GLB requires embedded JSON and BIN')
        _require(str(self.doc.get('asset', {}).get('version')) == '2.0', 'glTF version must be 2.0')
        buffers = self.doc.get('buffers', [])
        _require(buffers and not buffers[0].get('uri') and 0 <= buffers[0].get('byteLength', -1) <= len(self.binary), 'GLB primary buffer must be embedded')
        self.buffer_length = buffers[0]['byteLength']
        self.cache = {}

    def view(self, index):
        _require(type(index) is int and 0 <= index < len(self.doc.get('bufferViews', [])), 'invalid bufferView index')
        view = self.doc['bufferViews'][index]
        _require('EXT_meshopt_compression' not in view.get('extensions', {}), 'compressed bufferView unsupported')
        start, length = view.get('byteOffset', 0), view.get('byteLength', -1)
        _require(view.get('buffer', 0) == 0, 'external buffer unsupported')
        _require(type(start) is int and type(length) is int and start >= 0 and length >= 0 and start + length <= self.buffer_length, 'bufferView out of bounds')
        return view, self.binary[start:start + length]

    def accessor(self, index):
        if index in self.cache:
            return self.cache[index]
        _require(type(index) is int and 0 <= index < len(self.doc.get('accessors', [])), 'invalid accessor index')
        item = self.doc['accessors'][index]
        kind, component, count = item.get('type'), item.get('componentType'), item.get('count')
        _require(kind in _WIDTH and component in _COMPONENT and type(count) is int and count >= 0, 'unsupported accessor format')
        code, size = _COMPONENT[component]; width = _WIDTH[kind]; packed_size = width * size
        def unpack(view_index, offset, rows, scalar_code=code, scalar_width=width, element_size=packed_size, allow_stride=True):
            view, data = self.view(view_index)
            stride = view.get('byteStride', element_size) if allow_stride else element_size
            _require(type(offset) is int and offset >= 0 and type(stride) is int and stride >= element_size, 'invalid accessor stride/offset')
            _require(offset + (rows - 1) * stride + element_size <= len(data) if rows else offset <= len(data), 'accessor buffer out of bounds')
            return [struct.unpack_from('<' + scalar_code * scalar_width, data, offset + i * stride) for i in range(rows)]
        values = unpack(item['bufferView'], item.get('byteOffset', 0), count) if 'bufferView' in item else [(0,) * width for _ in range(count)]
        if 'sparse' in item:
            sparse = item['sparse']; number = sparse['count']; indices = sparse['indices']; sparse_component = indices['componentType']
            _require(type(number) is int and 0 <= number <= count and sparse_component in (5121, 5123, 5125), 'invalid sparse accessor')
            sparse_code, sparse_size = _COMPONENT[sparse_component]
            addresses = unpack(indices['bufferView'], indices.get('byteOffset', 0), number, sparse_code, 1, sparse_size, False)
            replacements = unpack(sparse['values']['bufferView'], sparse['values'].get('byteOffset', 0), number, allow_stride=False)
            previous = -1
            for address, value in zip(addresses, replacements):
                i = address[0]; _require(previous < i < count, 'invalid sparse accessor index order'); previous = i; values[i] = value
        if item.get('normalized'):
            _require(component in (5120, 5121, 5122, 5123), 'invalid normalized accessor component')
            divisor = {5120: 127., 5121: 255., 5122: 32767., 5123: 65535.}[component]
            values = [tuple(max(-1., v / divisor) for v in row) for row in values]
        self.cache[index] = (item, values)
        return item, values

    def surface(self):
        _require(not self.doc.get('animations'), 'animated geometry unsupported for static texture validation')
        nodes = self.doc.get('nodes', []); meshes = self.doc.get('meshes', [])
        scenes = self.doc.get('scenes', [])
        if scenes:
            index = self.doc.get('scene', 0); _require(type(index) is int and 0 <= index < len(scenes), 'invalid active scene')
            roots = scenes[index].get('nodes', [])
        else:
            children = {i for n in nodes for i in n.get('children', [])}
            roots = [i for i in range(len(nodes)) if i not in children]
        triangles, used, visited = [], [], set()
        total_vertices = discarded = 0
        def walk(index, parent):
            nonlocal total_vertices, discarded
            _require(type(index) is int and 0 <= index < len(nodes), 'invalid scene node index')
            _require(index not in visited, 'node hierarchy cycle or multiple-parent reference')
            visited.add(index); node = nodes[index]
            _require('skin' not in node and not node.get('weights') and 'EXT_mesh_gpu_instancing' not in node.get('extensions', {}), 'deformed/instanced geometry extension unsupported')
            world = _multiply(parent, _node_matrix(node))
            if 'mesh' in node:
                mi = node['mesh']; _require(type(mi) is int and 0 <= mi < len(meshes), 'invalid mesh index')
                mesh = meshes[mi]; _require(not mesh.get('weights'), 'morph mesh unsupported')
                for pi, primitive in enumerate(mesh.get('primitives', [])):
                    _require(not primitive.get('targets') and 'KHR_draco_mesh_compression' not in primitive.get('extensions', {}), 'morph/compressed primitive unsupported')
                    attributes = primitive.get('attributes', {}); _require('POSITION' in attributes, 'primitive missing POSITION')
                    position_item, positions = self.accessor(attributes['POSITION'])
                    _require(position_item['type'] == 'VEC3', 'POSITION must be VEC3')
                    for position in positions: _finite(position, 'POSITION')
                    world_positions = [_transform(world, p) for p in positions]; total_vertices += len(positions)
                    if 'indices' in primitive:
                        item, rows = self.accessor(primitive['indices'])
                        _require(item['type'] == 'SCALAR' and item['componentType'] in (5121, 5123, 5125) and not item.get('normalized'), 'indices must be unsigned integer SCALAR')
                        indices = [r[0] for r in rows]
                    else:
                        indices = list(range(len(positions)))
                    _require(all(type(i) is int and 0 <= i < len(positions) for i in indices), 'primitive index out of range')
                    mode = primitive.get('mode', 4)
                    if mode == 4:
                        _require(len(indices) % 3 == 0, 'triangle index count not divisible by three'); faces = [indices[i:i+3] for i in range(0, len(indices), 3)]
                    elif mode == 5:
                        faces = [indices[i:i+3] for i in range(len(indices)-2)]
                    elif mode == 6:
                        faces = [[indices[0], indices[i], indices[i+1]] for i in range(1, len(indices)-1)]
                    else:
                        raise ValueError('non-triangle primitive unsupported')
                    valid_faces = []
                    for face in faces:
                        points = tuple(world_positions[i] for i in face)
                        if _degenerate(points): discarded += 1; continue
                        triangles.append(points); valid_faces.append(face)
                    if valid_faces:
                        used.append({'node': index, 'mesh': mi, 'primitive': pi, 'data': primitive, 'positions_count': len(positions), 'faces': valid_faces})
            for child in node.get('children', []): walk(child, world)
        for root in roots: walk(root, _IDENTITY)
        _require(triangles, 'no nondegenerate triangle surface in active scene')
        summary = {'path': str(self.path.resolve()), 'sha256': self.sha256, 'vertices': total_vertices, 'triangles': len(triangles), 'discarded_exact_degenerate_triangles': discarded, 'used_primitives': len(used), 'scene_nodes': len(visited)}
        return triangles, used, summary


def _compare(source, result, precision):
    _require(isinstance(precision, (int, float)) and math.isfinite(precision) and 0 < precision <= 1e-3, 'normalized_tolerance must be >0 and <=1e-3')
    a, unused_a, summary_a = source.surface(); b, used_b, summary_b = result.surface()
    minimum = [min(p[i] for face in a for p in face) for i in range(3)]
    maximum = [max(p[i] for face in a for p in face) for i in range(3)]
    scale = max(maximum[i] - minimum[i] for i in range(3)); _require(scale > 0 and math.isfinite(scale), 'invalid source normalization bounds')
    origin = [(lo + hi) / 2 for lo, hi in zip(minimum, maximum)]
    def canonical(faces):
        result = Counter()
        for face in faces:
            points = [tuple(round(((p[i] - origin[i]) / scale) / precision) for i in range(3)) for p in face]
            result[tuple(sorted(points))] += 1
        return result
    ca, cb = canonical(a), canonical(b)
    missing, extra = ca - cb, cb - ca
    report = {'equivalent': not missing and not extra, 'source': summary_a, 'result': summary_b, 'normalization': {'policy': 'shared SOURCE world bounds only; retain relative/world transforms', 'origin': origin, 'scale': scale, 'normalized_rounding_precision': precision, 'world_rounding_cell': scale * precision}, 'triangle_policy': 'unordered corners, multiset multiplicity retained; ignore export names, UV seams, normals and winding; discard exactly zero cross-product only', 'missing_triangles': sum(missing.values()), 'extra_triangles': sum(extra.values()), 'mismatch_examples': {'missing': [list(k) for k in list(missing)[:3]], 'extra': [list(k) for k in list(extra)[:3]]}}
    return report, used_b


def compare_geometry_surfaces(source_path, result_path, normalized_tolerance=1e-6):
    """Geometry-only audit. Mismatch returns equivalent=False; invalid GLB raises ValueError."""
    try:
        report, _ = _compare(_GLB(source_path), _GLB(result_path), normalized_tolerance)
        return report
    except (OSError, KeyError, IndexError, TypeError, struct.error, json.JSONDecodeError) as exc:
        raise ValueError('invalid GLB geometry: ' + str(exc)) from exc


def _image_info(asset, image_index):
    images = asset.doc.get('images', [])
    _require(type(image_index) is int and 0 <= image_index < len(images), 'baseColor image index invalid')
    image = images[image_index]
    _require('bufferView' in image and 'uri' not in image, 'baseColor image must be embedded in GLB bufferView, not external/data URI')
    _, data = asset.view(image['bufferView']); mime = image.get('mimeType')
    dimensions = None
    if mime == 'image/png':
        _require(data.startswith(b'\x89PNG\r\n\x1a\n'), 'invalid embedded PNG image')
        offset, ended, compressed = 8, False, []
        while offset < len(data):
            _require(offset + 12 <= len(data), 'truncated PNG image chunk')
            count = struct.unpack_from('>I', data, offset)[0]; kind = data[offset+4:offset+8]
            _require(offset + 12 + count <= len(data), 'PNG image chunk out of bounds')
            payload = data[offset+8:offset+8+count]
            crc = struct.unpack_from('>I', data, offset+8+count)[0]
            _require(zlib.crc32(kind + payload) & 0xffffffff == crc, 'PNG image CRC mismatch')
            if kind == b'IHDR':
                _require(count == 13 and dimensions is None and offset == 8, 'invalid PNG image IHDR'); dimensions = list(struct.unpack_from('>II', payload))
            if kind == b'IDAT': compressed.append(payload)
            offset += 12 + count
            if kind == b'IEND': ended = True; break
        _require(ended and compressed and dimensions and all(x > 0 for x in dimensions), 'incomplete embedded PNG image')
        try: _require(bool(zlib.decompress(b''.join(compressed))), 'empty PNG image data')
        except zlib.error as exc: raise ValueError('invalid PNG image compressed data') from exc
    elif mime == 'image/jpeg':
        _require(data.startswith(b'\xff\xd8') and data.endswith(b'\xff\xd9'), 'invalid embedded JPEG image')
        offset = 2
        while offset + 4 <= len(data):
            _require(data[offset] == 255, 'invalid JPEG image marker')
            while offset < len(data) and data[offset] == 255: offset += 1
            marker = data[offset]; offset += 1
            if marker == 0xda: break
            length = struct.unpack_from('>H', data, offset)[0]
            _require(length >= 2 and offset + length <= len(data), 'truncated JPEG image')
            if marker in (0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf):
                _require(length >= 8, 'invalid JPEG image frame'); height, width = struct.unpack_from('>HH', data, offset+3); dimensions = [width, height]
            offset += length
        _require(dimensions and all(x > 0 for x in dimensions), 'JPEG image has no valid frame dimensions')
    elif mime == 'image/webp':
        _require(len(data) >= 30 and data[:4] == b'RIFF' and data[8:12] == b'WEBP' and struct.unpack_from('<I', data, 4)[0] + 8 == len(data), 'invalid embedded WebP image')
        if data[12:16] == b'VP8X': dimensions = [1 + int.from_bytes(data[24:27], 'little'), 1 + int.from_bytes(data[27:30], 'little')]
        elif data[12:16] == b'VP8 ' and data[23:26] == b'\x9d\x01\x2a': dimensions = [struct.unpack_from('<H', data, 26)[0] & 0x3fff, struct.unpack_from('<H', data, 28)[0] & 0x3fff]
        elif data[12:16] == b'VP8L' and data[20] == 0x2f:
            bits = int.from_bytes(data[21:25], 'little'); dimensions = [(bits & 0x3fff)+1, ((bits >> 14) & 0x3fff)+1]
        _require(dimensions and all(x > 0 for x in dimensions), 'unsupported WebP image payload')
    else:
        raise ValueError('unsupported embedded baseColor image mimeType: ' + str(mime))
    return {'image': image_index, 'mime_type': mime, 'dimensions': dimensions, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'embedded': True}


def _textures(asset, used):
    materials, textures = asset.doc.get('materials', []), asset.doc.get('textures', [])
    used_materials, checked_images, primitives = set(), {}, []
    for item in used:
        p = item['data']; mi = p.get('material')
        _require(type(mi) is int and 0 <= mi < len(materials), 'used primitive has no explicit baseColor material')
        material = materials[mi]; binding = material.get('pbrMetallicRoughness', {}).get('baseColorTexture')
        _require(isinstance(binding, dict), 'used material %d lacks baseColorTexture' % mi)
        transform = binding.get('extensions', {}).get('KHR_texture_transform', {})
        _require(transform.get('texCoord', binding.get('texCoord', 0)) == 0, 'baseColor must use UV0 / TEXCOORD_0')
        texture_index = binding.get('index'); _require(type(texture_index) is int and 0 <= texture_index < len(textures), 'baseColor texture index invalid')
        texture = textures[texture_index]
        source = texture.get('extensions', {}).get('EXT_texture_webp', {}).get('source', texture.get('source'))
        _require(source is not None, 'baseColor texture has no supported embedded image source')
        if source not in checked_images: checked_images[source] = _image_info(asset, source)
        attrs = p.get('attributes', {}); _require('TEXCOORD_0' in attrs, 'used primitive missing UV0 / TEXCOORD_0')
        uv_item, uv = asset.accessor(attrs['TEXCOORD_0'])
        _require(uv_item['type'] == 'VEC2' and len(uv) == item['positions_count'], 'UV0 must be VEC2 with POSITION vertex count')
        _require(uv_item['componentType'] == 5126 or (uv_item['componentType'] in (5121, 5123) and uv_item.get('normalized')), 'UV0 must be float or normalized unsigned coordinates')
        for coordinate in uv: _finite(coordinate, 'UV0')
        scales = transform.get('scale', [1, 1]); _require(len(scales) == 2, 'invalid UV0 texture transform scale'); _finite(scales, 'UV0 texture transform')
        _require(scales[0] != 0 and scales[1] != 0, 'UV0 texture transform collapses coordinates')
        offset = transform.get('offset', [0, 0]); _require(len(offset) == 2, 'invalid UV0 texture transform offset'); _finite(offset, 'UV0 texture transform')
        _finite([transform.get('rotation', 0)], 'UV0 texture transform rotation')
        for face in item['faces']:
            a, b, c = [uv[i] for i in face]
            _require((b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0]) != 0, 'UV0 contains collapsed nondegenerate triangle')
        used_materials.add(mi)
        primitives.append({'node': item['node'], 'mesh': item['mesh'], 'primitive': item['primitive'], 'material': mi, 'base_color_texture': texture_index, 'base_color_image': source, 'uv0_vertices': len(uv), 'valid_uv0_triangles': len(item['faces'])})
    # Any declared external image is a portability risk, even when not the baseColor.
    for image in asset.doc.get('images', []):
        _require('uri' not in image and 'bufferView' in image, 'all images must be embedded; external/missing image is not publishable')
        asset.view(image['bufferView'])
    return {'used_materials': len(used_materials), 'material_indices': sorted(used_materials), 'bound_base_color_images': list(checked_images.values()), 'primitives': primitives, 'unused_materials': len(materials) - len(used_materials), 'policy': 'all active rendered primitives require explicitly bound embedded baseColor image and finite noncollapsed UV0; unused images never establish texture readiness'}


def validate_textured_result(source_path, result_path, normalized_tolerance=1e-6):
    """Validate before publishing result. On failure exception.report is JSON-safe."""
    report = {'valid': False, 'version': 1, 'source': str(Path(source_path).resolve()), 'result': str(Path(result_path).resolve()), 'errors': [], 'art_accepted': False, 'scope': 'static world-space triangle surface equivalence and actual embedded baseColor/UV0 binding; no shading or art acceptance'}
    try:
        source, result = _GLB(source_path), _GLB(result_path)
        geometry, used = _compare(source, result, normalized_tolerance)
        report['geometry'] = geometry
        _require(geometry['equivalent'], 'source/result triangle surface mismatch')
        report['textures'] = _textures(result, used)
        report['valid'] = True
        return report
    except (ValueError, OSError, KeyError, IndexError, TypeError, struct.error, OverflowError) as exc:
        report['errors'].append(str(exc))
        raise TextureValidationError(str(exc), report) from exc
