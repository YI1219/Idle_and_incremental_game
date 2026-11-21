"""Non-destructive static Tripo prop processing, Blender background only.

blender -b --python tools/art/process_style_library.py -- \
  --manifest art/source/.../manifest.json --out-dir /tmp/new_asset

Uniform scale only. No orientation guesses, hole filling, material merging, or
height-based coloring. Reports describe technical candidates, not art acceptance.
"""
import argparse
import hashlib
import json
import math
import os
import sys
import traceback
from collections import Counter
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

VERSION = 1


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def positive(value, label):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
        raise ValueError(f'{label} must be a positive finite number: {value!r}')
    return float(value)


def contract(manifest):
    settings = next((manifest[k] for k in ('recommended_parameters', 'studio', 'suggested_settings', 'tripo_suggested_settings')
                     if isinstance(manifest.get(k), dict)), {})
    budget = next((settings[k] for k in ('target_triangles', 'target_faces', 'face_limit', 'faces') if k in settings), None)
    if type(budget) is not int or budget < 4:
        raise ValueError('recommended_parameters must provide an integer triangle budget >=4')
    ac = manifest.get('asset_contract', {})
    lods = next((block[k] for block in (ac, manifest) for k in ('lod_triangle_budgets', 'lod_triangles') if k in block),
                [budget, max(4, int(budget * .4)), max(4, int(budget * .15))])
    if not isinstance(lods, list) or len(lods) != 3 or any(type(x) is not int or x < 4 for x in lods):
        raise ValueError('three positive integer LOD budgets >=4 are required')
    if any(lods[i] < lods[i + 1] for i in range(2)):
        raise ValueError('LOD budgets must descend; explicit runtime budgets may differ from generation budget')
    # Explicit physical fields only. Several proposed dimensions are aspirations;
    # height (then width/depth) anchors uniform scale; other axes are reported.
    dimensions, anchor, anchor_path = {}, None, None
    for block_name, block in (('asset_contract', ac), ('manifest', manifest)):
        for key, axis in (('height_m', 'height'), ('diameter_m', 'diameter'), ('target_width_m', 'width'),
                          ('width_m', 'width'), ('depth_m', 'depth')):
            if key in block:
                value = positive(block[key], f'{block_name}.{key}')
                if axis in dimensions and abs(dimensions[axis] - value) > 1e-8:
                    raise ValueError(f'conflicting requested {axis} dimensions')
                dimensions[axis] = value
                if anchor is None:
                    anchor, anchor_path = axis, f'{block_name}.{key}'
        for key in ('target_dimensions_m', 'proposed_size_m', 'proposed_size'):
            if key not in block:
                continue
            values = block[key]
            if not isinstance(values, dict):
                raise ValueError(f'{block_name}.{key} is ambiguous; use a dictionary of width/depth/height in metres')
            found = {}
            for axis in ('height', 'width', 'depth', 'diameter'):
                value = values.get(axis, values.get(axis + '_m'))
                if value is not None:
                    found[axis] = positive(value, f'{block_name}.{key}.{axis}')
            if not found:
                raise ValueError(f'{block_name}.{key} has no explicit metric dimensions')
            for axis, value in found.items():
                if axis in dimensions and abs(dimensions[axis] - value) > 1e-8:
                    raise ValueError(f'conflicting requested {axis} dimensions')
                dimensions[axis] = value
            if anchor is None:
                anchor = next(iter(found))
                anchor_path = f'{block_name}.{key}.{anchor}'
    if anchor is None:
        raise ValueError('scale unresolved: add asset_contract.height_m/diameter_m or explicit proposed_size_m dimensions; no output guessed')
    return settings, lods, {'anchor': anchor, 'anchor_field': anchor_path,
                            'requested_dimensions_m': dimensions, 'policy': 'uniform scale, preserve source proportions'}


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == 'MESH']


def bounds(objects):
    points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    if not points:
        raise ValueError('source has no mesh vertices')
    lo = Vector(tuple(min(p[k] for p in points) for k in range(3)))
    hi = Vector(tuple(max(p[k] for p in points) for k in range(3)))
    return lo, hi


def used_materials(objects):
    result = {}
    for obj in objects:
        for face in obj.data.polygons:
            if face.material_index < len(obj.data.materials):
                material = obj.data.materials[face.material_index]
                if material:
                    result[material.name] = material
    return list(result.values())


def texture_report(materials):
    images = {}
    for material in materials:
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image:
                    image = node.image
                    images[image.name] = {'name': image.name, 'resolution': list(image.size),
                                          'colorspace': image.colorspace_settings.name,
                                          'packed': bool(image.packed_file), 'source_path': image.filepath,
                                          'missing': not image.has_data}
    return list(images.values())


def edge_stats(bm):
    return {'boundary_edges': sum(e.is_boundary for e in bm.edges),
            'nonmanifold_edges': sum(not e.is_manifold for e in bm.edges),
            'overconnected_edges': sum(len(e.link_faces) > 2 for e in bm.edges),
            'loose_edges': sum(not e.link_faces for e in bm.edges),
            'loose_vertices': sum(not v.link_edges for v in bm.verts),
            'inconsistent_winding_edges': sum(e.is_manifold and not e.is_contiguous for e in bm.edges)}


def audit(objects):
    lo, hi = bounds(objects)
    span = max((hi - lo).length, 1e-12)
    weld_epsilon = span * 1e-8
    tiny_area = span * span * 1e-16
    mesh_reports = []
    for obj in objects:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.transform(obj.matrix_world)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bm.normal_update()
        raw = edge_stats(bm)
        areas = [f.calc_area() for f in bm.faces]
        normals = [v.normal for v in bm.verts] + [f.normal for f in bm.faces]
        report = {'name': obj.name, 'vertices': len(bm.verts), 'triangles': len(bm.faces),
                  'raw_topology': raw, 'zero_or_tiny_faces': sum(a <= tiny_area for a in areas),
                  'godot_tiny_triangle_candidates_area_lt_1e_10_m2': sum(a < 1e-10 for a in areas),
                  'minimum_triangle_area_m2': min(areas, default=0),
                  'invalid_normals': sum(any(not math.isfinite(x) for x in n) or n.length < .5 for n in normals),
                  'custom_normals': bool(obj.data.has_custom_normals),
                  'smooth_faces': sum(f.use_smooth for f in obj.data.polygons),
                  'uv_layers': [layer.name for layer in obj.data.uv_layers],
                  'uv_finite': all(math.isfinite(c) for layer in obj.data.uv_layers for loop in layer.data for c in loop.uv),
                  'vertex_color_layers': [layer.name for layer in obj.data.color_attributes],
                  'material_slots': [m.name if m else None for m in obj.data.materials],
                  'object_origin_world': list(obj.matrix_world.translation)}
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=weld_epsilon)
        report['position_welded_topology'] = edge_stats(bm)
        bm.free()
        mesh_reports.append(report)
    material_list = used_materials(objects)
    image_list = texture_report(material_list)
    aggregate = {key: sum(m['position_welded_topology'][key] for m in mesh_reports)
                 for key in ('boundary_edges', 'nonmanifold_edges', 'overconnected_edges', 'loose_edges', 'loose_vertices', 'inconsistent_winding_edges')}
    issues = [key for key, value in aggregate.items() if value]
    if any(m['zero_or_tiny_faces'] for m in mesh_reports):
        issues.append('degenerate_faces')
    if any(m['invalid_normals'] for m in mesh_reports):
        issues.append('invalid_normals')
    if any(not m['uv_finite'] for m in mesh_reports):
        issues.append('invalid_uv_coordinates')
    if any(i['missing'] for i in image_list):
        issues.append('missing_textures')
    return {'objects': len(objects), 'triangles': sum(m['triangles'] for m in mesh_reports),
            'materials': len(material_list), 'material_names': [m.name for m in material_list],
            'textures': image_list, 'bounds_min_m': list(lo), 'bounds_max_m': list(hi),
            'dimensions_m': list(hi - lo), 'pivot': 'object origins reported individually; Blender Z-up/glTF Y-up',
            'position_weld_epsilon_m': weld_epsilon, 'topology': aggregate,
            'meshes': mesh_reports, 'issues': issues, 'technical_geometry_ready': not issues}


def select_only(objects):
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def cleanup(obj, span):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.verts.index_update()
    bm.faces.index_update()
    tolerance = max(span * 1e-10, 1e-12)
    area_epsilon = span * span * 1e-16
    def vertex_key(vertex):
        return tuple(round(c / tolerance) for c in vertex.co)
    def face_record(face, reason):
        return {'face_index': face.index, 'reason': reason, 'material_index': face.material_index,
                'area_m2': face.calc_area(), 'vertices_m': [list(v.co) for v in face.verts]}
    removed, remove, seen = [], [], set()
    for face in bm.faces:
        key = tuple(sorted(vertex_key(v) for v in face.verts))
        reason = 'tiny_degenerate' if face.calc_area() <= area_epsilon else ('duplicate_geometry' if key in seen else None)
        seen.add(key)
        if reason:
            removed.append(face_record(face, reason))
            remove.append(face)
    if remove:
        bmesh.ops.delete(bm, geom=remove, context='FACES_ONLY')
    # Coordinate adjacency also sees UV-split vertices. Only the narrow proven
    # appendage pattern is removed; every other nonmanifold boundary stays visible.
    edge_faces = {}
    for face in bm.faces:
        for edge in face.edges:
            key = tuple(sorted(vertex_key(v) for v in edge.verts))
            edge_faces.setdefault(key, set()).add(face)
    fins = []
    for face in bm.faces:
        counts = [len(edge_faces[tuple(sorted(vertex_key(v) for v in edge.verts))]) for edge in face.edges]
        if len(face.verts) == 3 and counts.count(1) >= 2 and any(n > 2 for n in counts):
            removed.append(face_record(face, 'attached_fin_two_boundary_edges_and_overconnected_shared_edge'))
            fins.append(face)
    if fins:
        bmesh.ops.delete(bm, geom=fins, context='FACES_ONLY')
    loose = [v for v in bm.verts if not v.link_faces]
    loose_count = len(loose)
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.normal_update()
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return {'object': obj.name, 'removed_faces': removed, 'removed_loose_vertices': loose_count,
            'area_epsilon_m2': area_epsilon, 'coordinate_key_tolerance_m': tolerance,
            'holes_filled': 0, 'normals_policy': 'retain smooth flags; recompute geometric normals after topology edits'}


def bake_world_transforms(objects):
    for obj in objects:
        if obj.data.shape_keys or any(m.type == 'ARMATURE' for m in obj.modifiers):
            raise ValueError('only static meshes supported; skinning/shape keys require separate processing')
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
        obj.data = obj.data.copy()
        obj.data.transform(world)
        if world.determinant() < 0:
            obj.data.flip_normals()



def weld_uv_seam_geometry(obj):
    """Explicit opt-in: weld exact coincident positions, retaining corner UV data.

    glTF can split mesh vertices at UV seams. Decimating those disconnected islands
    opens physical cracks. BMesh UVs live on loops, so exact-position vertex welds
    can restore adjacency while each face corner keeps its own UV/material data.
    """
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layers = list(bm.loops.layers.uv.keys())
    if not layers:
        bm.free()
        raise ValueError(f'weld_uv_seam_geometry requires UV layers: {obj.name}')

    def snapshot():
        faces = Counter()
        for face in bm.faces:
            corners = [(tuple(loop.vert.co), tuple(tuple(loop[bm.loops.layers.uv[name]].uv)
                        for name in layers)) for loop in face.loops]
            faces[(face.material_index, tuple(sorted(corners)))] += 1
        lo = [min(v.co[k] for v in bm.verts) for k in range(3)]
        hi = [max(v.co[k] for v in bm.verts) for k in range(3)]
        measured = {'vertices': len(bm.verts), 'faces': len(bm.faces),
                    'loops': sum(len(face.loops) for face in bm.faces),
                    'uv_layers': layers, 'bounds_min': lo, 'bounds_max': hi,
                    'topology': edge_stats(bm),
                    'position_uv_material_face_multiset_sha256': hashlib.sha256(
                        json.dumps(sorted(faces.items()), separators=(',', ':')).encode()).hexdigest()}
        return faces, measured

    before_corners, before = snapshot()
    # dist=0.0 was verified in Blender 5.2.1: exact coordinate equality only.
    # Do not average UVs, merge material slots, or bridge/fill any boundary.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0)
    after_corners, after = snapshot()
    if before_corners != after_corners:
        bm.free()
        raise ValueError('exact UV seam weld changed a face position/UV/material corner; refusing export')
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return {'object': obj.name, 'enabled': True, 'position_tolerance': 0.0,
            'before': before, 'after': after, 'merged_vertices': before['vertices'] - after['vertices'],
            'all_position_uv_material_corners_exactly_preserved': True,
            'bounds_exactly_preserved': before['bounds_min'] == after['bounds_min'] and before['bounds_max'] == after['bounds_max'],
            'holes_filled': 0, 'material_slots_merged': 0}


def normalize(objects, sizing):
    lo, hi = bounds(objects)
    dimensions = hi - lo
    anchor = sizing['anchor']
    extent = {'width': dimensions.x, 'depth': dimensions.y, 'height': dimensions.z,
              'diameter': max(dimensions.x, dimensions.y)}[anchor]
    if extent <= 1e-12:
        raise ValueError('source has zero extent along requested scale anchor')
    factor = sizing['requested_dimensions_m'][anchor] / extent
    shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    transform = Matrix.Scale(factor, 4) @ Matrix.Translation(shift)
    for obj in objects:
        obj.data.transform(transform)
        obj.data.update()
    bpy.context.view_layer.update()
    sizing.update(uniform_scale=factor, source_extent=extent, translation_before_scale=list(shift),
                  pivot='base centre at world origin; original orientation retained')


def neutral_if_white(objects, settings):
    materials = used_materials(objects)
    if settings.get('texture') is not False or len(materials) > 1 or texture_report(materials):
        return 'preserved source materials and texture/UV assignments; no consolidation'
    neutral = bpy.data.materials.new('geometry_review_neutral_matte')
    neutral.use_nodes = True
    neutral.diffuse_color = (.63, .64, .61, 1)
    bsdf = neutral.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = neutral.diffuse_color
    bsdf.inputs['Roughness'].default_value = .92
    for obj in objects:
        obj.data.materials.clear()
        obj.data.materials.append(neutral)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
    return 'geometry-only untextured source with <=1 material: neutral single matte; no vertex colors added'


def make_lod(masters, level, budget, name):
    collection = bpy.data.collections.new(f'LOD{level}')
    bpy.context.scene.collection.children.link(collection)
    objects = []
    for index, master in enumerate(masters):
        obj = master.copy()
        obj.data = master.data.copy()
        obj.name = f'{name}_LOD{level}_{index}'
        collection.objects.link(obj)
        objects.append(obj)
    select_only(objects)
    for attempt in range(5):
        triangles = sum(len(p.vertices) - 2 for obj in objects for p in obj.data.polygons)
        if triangles <= budget:
            break
        ratio = budget / triangles * .992
        for obj in objects:
            if len(obj.data.polygons) < 5:
                continue
            bpy.context.view_layer.objects.active = obj
            modifier = obj.modifiers.new('triangle_budget', 'DECIMATE')
            modifier.ratio = ratio
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    span = (bounds(objects)[1] - bounds(objects)[0]).length
    cleanup_reports = [cleanup(obj, span) for obj in objects]
    return objects, cleanup_reports


def reimport(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return audit(meshes())


def run(manifest_path, out):
    manifest_path = manifest_path.expanduser().resolve()
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    source_value = manifest.get('source_glb') or manifest.get('sourceGLB') or manifest.get('output_original')
    if not isinstance(source_value, str):
        raise ValueError('manifest requires source_glb/sourceGLB or output_original')
    source = (manifest_path.parent / source_value).resolve()
    if not source.is_file() or source.suffix.lower() != '.glb':
        raise ValueError(f'GLB source missing: {source}')
    settings, budgets, sizing = contract(manifest)
    weld_seams = manifest.get('asset_contract', {}).get('weld_uv_seam_geometry', False)
    if type(weld_seams) is not bool:
        raise ValueError('asset_contract.weld_uv_seam_geometry must be an explicit boolean')
    out = out.expanduser().resolve()
    if out == source.parent or out == manifest_path.parent:
        raise ValueError('output must be a new directory distinct from original source/manifest directory')
    identity = {'source_sha256': sha(source), 'manifest_sha256': sha(manifest_path),
                'tool_sha256': sha(__file__), 'blender': bpy.app.version_string, 'version': VERSION}
    report_path = out / 'process_report.json'
    if out.exists() and any(out.iterdir()):
        if report_path.is_file():
            old = json.loads(report_path.read_text())
            if old.get('identity') == identity and old.get('processing_complete') and all(
                    (out / f['file']).is_file() and sha(out / f['file']) == f['sha256'] for f in old.get('artifacts', [])):
                print('STYLE_LIBRARY_SKIP_IDENTICAL', str(report_path))
                return
        raise FileExistsError(f'output is populated or incomplete; refusing overwrite: {out}')
    out.mkdir(parents=True, exist_ok=True)
    marker = out / '.processing'
    with marker.open('x') as stream:
        stream.write(json.dumps(identity))
    report = {'identity': identity, 'source': str(source), 'manifest': str(manifest_path),
              'processing_complete': False, 'art_accepted': False, 'godot_validated': False,
              'hardware_fps': 'unmeasured', 'size_contract': sizing, 'lod_budgets': budgets,
              'warnings': ['Godot may discard very small triangles; counts below are candidates, not engine measurements.',
                           'Closed topology is only a technical gate. Art, UV appearance and engine shading need separate review.'],
              'artifacts': []}
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.unit_settings.system = 'METRIC'
        bpy.context.scene.unit_settings.scale_length = 1
        bpy.ops.import_scene.gltf(filepath=str(source))
        masters = meshes()
        report['original'] = audit(masters)
        bake_world_transforms(masters)
        report['uv_seam_geometry_weld'] = {'enabled': weld_seams,
            'objects': [weld_uv_seam_geometry(obj) for obj in masters] if weld_seams else [],
            'policy': 'opt-in exact-position adjacency restoration; preserve every face UV/material corner; never fill holes'}
        span = (bounds(masters)[1] - bounds(masters)[0]).length
        report['cleanup'] = [cleanup(obj, span) for obj in masters]
        # Defects must not determine final dimensions or pivot. Scale after cleanup.
        normalize(masters, sizing)
        report['material_policy'] = neutral_if_white(masters, settings)
        report['normalized_master'] = audit(masters)
        actual = report['normalized_master']['dimensions_m']
        report['size_contract']['actual_dimensions_m'] = actual
        actual_axes = dict(zip(('width', 'depth', 'height'), actual))
        actual_axes['diameter'] = max(actual[0], actual[1])
        report['size_contract']['requested_axis_relative_error'] = {
            axis: (actual_axes[axis] - value) / value for axis, value in sizing['requested_dimensions_m'].items()}
        report['warnings'].append('Orientation retained from source; no automatic entrance/front rotation was inferred.')
        report['lods'] = []
        asset_name = str(manifest.get('asset') or manifest_path.parent.name)
        for level, budget in enumerate(budgets):
            objects, cleaned = make_lod(masters, level, budget, asset_name)
            measured = audit(objects)
            if measured['triangles'] > budget:
                measured['issues'].append('triangle_budget_exceeded')
            max_materials = manifest.get('asset_contract', {}).get('max_materials')
            if type(max_materials) is int and measured['materials'] > max_materials:
                measured['issues'].append('material_budget_exceeded_preserved_without_baking')
            measured['dimensions_relative_to_master'] = [
                (value - master_value) / master_value if master_value else 0
                for value, master_value in zip(measured['dimensions_m'], actual)]
            path = out / f'lod{level}.glb'
            select_only(objects)
            bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                                      export_apply=True, export_animations=False)
            item = {'level': level, 'budget': budget, 'file': path.name, 'before_export': measured,
                    'cleanup': cleaned, 'sha256': sha(path), 'bytes': path.stat().st_size}
            report['lods'].append(item)
            report['artifacts'].append({'file': path.name, 'sha256': item['sha256']})
        # Default editable-file view shows LOD0, while masters/other LODs remain editable.
        for obj in masters:
            obj.hide_set(True)
            obj.hide_render = True
        for collection in bpy.data.collections:
            if collection.name in ('LOD1', 'LOD2'):
                for obj in collection.objects:
                    obj.hide_set(True)
                    obj.hide_render = True
        # Pack images into a new editable file; original GLB and images remain unchanged.
        bpy.ops.file.pack_all()
        blend = out / 'asset.blend'
        bpy.ops.wm.save_as_mainfile(filepath=str(blend))
        report['artifacts'].append({'file': blend.name, 'sha256': sha(blend)})
        for item in report['lods']:
            imported = reimport(out / item['file'])
            before = item['before_export']
            dimensions_match = all(abs(a - b) <= max(1e-5, abs(a) * 1e-5)
                                   for a, b in zip(before['dimensions_m'], imported['dimensions_m']))
            topology_match = before['topology'] == imported['topology']
            triangles_match = before['triangles'] == imported['triangles']
            textures_match = sorted(i['resolution'] for i in before['textures']) == sorted(i['resolution'] for i in imported['textures'])
            uv_count_match = sum(len(m['uv_layers']) for m in before['meshes']) == sum(len(m['uv_layers']) for m in imported['meshes'])
            item['reimport'] = imported
            item['verification'] = {'dimensions_match': dimensions_match, 'triangles_match': triangles_match,
                                    'topology_match': topology_match, 'materials_match': before['materials'] == imported['materials'],
                                    'texture_resolutions_match': textures_match, 'uv_layer_count_match': uv_count_match}
            item['not_game_ready'] = bool(before['issues'] or imported['issues'] or not all(item['verification'].values()))
        report['not_game_ready'] = any(lod['not_game_ready'] for lod in report['lods'])
        report['processing_complete'] = True
        report['original_source_unchanged'] = sha(source) == identity['source_sha256']
        if not report['original_source_unchanged']:
            raise RuntimeError('source changed during processing')
        write_json(report_path, report)
        marker.unlink()
        print('STYLE_LIBRARY_PROCESSED', json.dumps({'report': str(report_path),
              'triangles': [x['reimport']['triangles'] for x in report['lods']], 'not_game_ready': report['not_game_ready']}))
    except BaseException as exc:
        report['error'] = str(exc)
        report['not_game_ready'] = True
        write_json(report_path, report)
        raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--out-dir', type=Path, required=True)
    options = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    try:
        run(options.manifest, options.out_dir)
    except BaseException:
        traceback.print_exc()
        # Blender otherwise exits zero for exceptions in --python scripts.
        sys.stdout.flush()
        sys.stderr.flush()
        os._exit(1)
