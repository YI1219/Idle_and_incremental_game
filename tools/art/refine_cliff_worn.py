"""Existing-source study: physical worn corners, without new rock assemblies.

Outputs remain unaccepted copies until inspected in the actual editable rim.
"""
import bpy, bmesh, hashlib, json, math, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/work/cliff_worn/2026-10-16'
OUT.mkdir(parents=True, exist_ok=True)
reports = []
VERSION = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1', 'v2', 'v3']
for kind in ['main', 'tall']:
    source = ROOT / f'assets/nature/refined/cliff_integrated_{kind}_v1.glb'
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    obj, = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_limit(bm, angle_limit=.001, verts=list(bm.verts), edges=list(bm.edges), delimit=set())
    bm.normal_update()
    before_faces = len(bm.faces)
    size = [max(v.co[k] for v in bm.verts) - min(v.co[k] for v in bm.verts) for k in range(3)]
    width = min(size[0], size[1]) * .055
    edges = [e for e in bm.edges if e.is_manifold and e.is_convex and e.calc_face_angle() > math.radians(25)]
    selected = len(edges)
    bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type='OFFSET', segments=2, profile=.60, affect='EDGES', clamp_overlap=True, loop_slide=True)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bad = sum(not e.is_manifold for e in bm.edges)
    tiny = sum(f.calc_area() < 1e-12 for f in bm.faces)
    volume = bm.calc_volume(signed=True)
    assert bad == tiny == 0 and volume > 0, (kind, bad, tiny, volume)
    count = len(bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    if VERSION in ['v2', 'v3']:
        # Actual source sculpting: reconnect a dense surface before a shallow
        # medium-scale wear pass. No detached pebbles or extra rock volumes.
        obj.data.remesh_voxel_size = min(size[0], size[1]) * .025
        bpy.ops.object.voxel_remesh()
        smooth = obj.modifiers.new('Wear soften', 'SMOOTH')
        smooth.factor = .55
        smooth.iterations = 4
        bpy.ops.object.modifier_apply(modifier=smooth.name)
        texture = bpy.data.textures.new('Shallow geological wear', type='CLOUDS')
        texture.noise_scale = min(size[0], size[1]) * .17
        texture.noise_depth = 1
        displace = obj.modifiers.new('Shallow geological wear', 'DISPLACE')
        displace.texture = texture
        displace.texture_coords = 'GLOBAL'
        displace.strength = min(size[0], size[1]) * .035
        displace.mid_level = .5
        bpy.ops.object.modifier_apply(modifier=displace.name)
        decimate = obj.modifiers.new('Medium plane simplification', 'DECIMATE')
        decimate.ratio = .06 if VERSION == 'v3' else .24
        bpy.ops.object.modifier_apply(modifier=decimate.name)
        bm = bmesh.new(); bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bad = sum(not e.is_manifold for e in bm.edges)
        tiny = sum(f.calc_area() < 1e-12 for f in bm.faces)
        volume = bm.calc_volume(signed=True)
        assert bad == tiny == 0 and volume > 0, (kind, bad, tiny, volume)
        count = len(bm.faces)
        bm.to_mesh(obj.data); bm.free(); obj.data.update()
    for poly in obj.data.polygons:
        poly.use_smooth = False
    obj.name = f'cliff_worn_{kind}_{VERSION}'
    blend = OUT / (obj.name + '.blend')
    glb = OUT / (obj.name + '.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True, export_materials='EXPORT', export_animations=False, export_cameras=False, export_lights=False)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    reports.append(dict(kind=kind, source=str(source.relative_to(ROOT)), source_sha256=digest, width=width, selected_convex_edges=selected, segments=2, profile=.60, voxel_width_fraction=.025 if VERSION != 'v1' else None, smooth_factor=.55 if VERSION != 'v1' else None, smooth_iterations=4 if VERSION != 'v1' else None, cloud_scale_fraction=.17 if VERSION != 'v1' else None, displacement_fraction=.035 if VERSION != 'v1' else None, decimate_ratio=(.06 if VERSION == 'v3' else .24) if VERSION != 'v1' else None, source_faces=before_faces, triangles=count, nonmanifold_edges=bad, degenerate_faces=tiny, volume=volume, blend=str(blend.relative_to(ROOT)), glb=str(glb.relative_to(ROOT)), glb_sha256=hashlib.sha256(glb.read_bytes()).hexdigest(), blender_version=bpy.app.version_string, stage='Unaccepted source study; cap bounds intentionally allowed to change with physical wear. No runtime promotion.'))
(OUT / f'source_{VERSION}.json').write_text(json.dumps(reports, indent=2) + '\n')
print('WORN CLIFF SOURCES:', json.dumps(reports))
