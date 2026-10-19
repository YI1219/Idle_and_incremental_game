"""Blender: one hand-organized assembly of three preserved existing rock meshes.

No scratch primitive/model generation. Existing surfaces are posed, unioned and
trimmed to a common top. Neutral inspection precedes any density conversion.
"""
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT/'art/work/volume_modules/2026-10-20'
TOP = 3.25
PLACEMENTS = [
    dict(source='medium', span=[4.7,4.6,4.3], center_xz=[1.10,.30], yaw=-22., pitch=-5., y_range=[-1.147109,3.58]),
    dict(source='tall', span=[4.1,3.8,3.8], center_xz=[-2.05,-.10], yaw=27., pitch=8., y_range=[-.45,3.55]),
    dict(source='main', span=[3.9,3.2,3.8], center_xz=[-.25,-1.15], yaw=105., pitch=-8., y_range=[.20,3.52]),
]


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT/'tools/art'/file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def object_for(name, points):
    vertices, faces, ids = [], [], {}
    for triangle in points.reshape(-1,3,3):
        face = []
        for p in triangle:
            key = tuple(np.round(p,5))
            if key not in ids:
                ids[key] = len(vertices)
                vertices.append((float(p[0]),float(-p[2]),float(p[1])))
            face.append(ids[key])
        faces.append(list(reversed(face)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def check(path):
    geometry = module('assembled_topology','sample_cliff_representation.py')
    crossings = module('assembled_crossings','check_cliff_dual_intersections.py')
    points = np.fromfile(path,dtype='<f4').reshape(-1,3)
    topology = geometry.topology([Vector(p) for p in points])
    topology['vertex_link_defects'] = crossings.vertex_link_defects(points)
    intersections = crossings.inspect_file(path)
    valid = all(topology[k]==0 for k in ['non_two_use_edges','directed_edge_pair_defects','degenerate_index_faces','vertex_link_defects'])
    valid = valid and topology['signed_volume']>0 and len(topology['vertex_components'])==1 and intersections['strict_crossing_pairs_at_least']==0
    return dict(topology=topology,intersections=intersections,finite_gate_passed=valid)


def sample():
    geometry = np.fromfile(WORK/'assembled.bin',dtype='<f4').reshape(-1,3).astype(float)
    validation = check(WORK/'assembled.bin')
    assert validation['finite_gate_passed'], validation['topology']
    sampler = module('assembled_sampler','sample_tripo_master.py')
    records, evidence = sampler.sample_geometry(geometry)
    low = np.floor((geometry.min(0)-.75)/.25).astype(int)
    high = np.ceil((geometry.max(0)+.75)/.25).astype(int)
    size = high-low+1
    density = np.full((size[2],size[1],size[0]),.5,dtype='<f4')
    for row in records:
        density[row['z']-low[2],row['y']-low[1],row['x']-low[0]] = row['density']
    density.tofile(WORK/'density.bin')
    evidence.update(low=low.tolist(),size=size.tolist(),input_topology=validation['topology'],density_sha256=hashlib.sha256(density.tobytes()).hexdigest(),
                    source_triangles_sha256=hashlib.sha256((WORK/'assembled.bin').read_bytes()).hexdigest())
    (WORK/'sampling.json').write_text(json.dumps(evidence,indent=2)+'\n')
    print('MODULE ASSEMBLY SAMPLE:',json.dumps(evidence),flush=True)


def run():
    if '--sample' in sys.argv:
        sample()
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    evidence = json.loads((WORK/'sources.json').read_text())
    originals = {s['id']:s for s in evidence['sources']}
    sources, posed = {}, []
    for source_id, info in originals.items():
        path = WORK/(source_id+'.bin')
        assert hashlib.sha256(path.read_bytes()).hexdigest()==info['triangles_sha256']
        validation = check(path)
        assert validation['finite_gate_passed'], (source_id,validation['topology'])
        sources[source_id] = validation
    # No sweep: these three unequal poses are the authored local composition.
    for index, placement in enumerate(PLACEMENTS):
        points = np.fromfile(WORK/(placement['source']+'.bin'),dtype='<f4').reshape(-1,3).astype(float)
        low, high = points.min(0), points.max(0)
        points = (points-(low+high)*.5)*np.asarray(placement['span'])/(high-low)
        turn = Matrix.Rotation(np.deg2rad(placement['yaw']),3,'Y') @ Matrix.Rotation(np.deg2rad(placement['pitch']),3,'X') @ Matrix.Rotation(np.pi,3,'Z')
        points = points @ np.asarray(turn).T
        points[:,0] += placement['center_xz'][0]
        points[:,2] += placement['center_xz'][1]
        lo_y, hi_y = placement['y_range']
        points[:,1] = lo_y+(points[:,1]-points[:,1].min())/(points[:,1].max()-points[:,1].min())*(hi_y-lo_y)
        posed.append(points)
    all_points = np.concatenate(posed)
    horizontal_scale = 8.5/np.ptp(all_points[:,0])
    center_xz = (all_points[:,[0,2]].min(0)+all_points[:,[0,2]].max(0))*.5
    objects = []
    for index, points in enumerate(posed):
        points[:,[0,2]] = (points[:,[0,2]]-center_xz)*horizontal_scale
        objects.append(object_for('posed_'+str(index)+'_'+PLACEMENTS[index]['source'],points))
    union = objects[0].copy()
    union.data = objects[0].data.copy()
    union.name = 'three_rock_assembly_v1'
    bpy.context.scene.collection.objects.link(union)
    bpy.context.view_layer.objects.active = union
    for other in objects[1:]:
        modifier = union.modifiers.new('Existing mesh union','BOOLEAN')
        modifier.operation = 'UNION'
        modifier.solver = 'EXACT'
        modifier.object = other
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bm = bmesh.new()
    bm.from_mesh(union.data)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,
                          plane_co=(0,0,TOP),plane_no=(0,0,1),clear_outer=True,clear_inner=False)
    boundary = [edge for edge in bm.edges if edge.is_boundary]
    bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bm.to_mesh(union.data)
    bm.free()
    helpers = module('assembled_triangle_helpers','refine_volume_mother.py')
    triangles = helpers.triangles([union])
    (WORK/'assembled.bin').write_bytes(triangles.tobytes())
    validation = check(WORK/'assembled.bin')
    report = dict(source_manifest=evidence,source_checks=sources,placements=PLACEMENTS,
                  horizontal_scale=horizontal_scale,horizontal_center=center_xz.tolist(),top=TOP,
                  bounds=[triangles.min(0).tolist(),triangles.max(0).tolist()],validation=validation,
                  blender=bpy.app.version_string,source_triangles_sha256=hashlib.sha256(triangles.tobytes()).hexdigest(),
                  scope='One hand-organized3existing-rock assembly, inverted/posed/unioned/top-trimmed. Original sources preserved. Neutral inspection required before sampling; no new scratch official geometry or art acceptance.')
    (WORK/'assembly.json').write_text(json.dumps(report,indent=2)+'\n')
    assert validation['finite_gate_passed'], validation['topology']
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
        if obj!=union:
            obj.hide_render = True
            obj.hide_set(True)
    union.select_set(True)
    bpy.context.view_layer.objects.active = union
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'three_rock_assembly_v1.blend'))
    export = WORK/'three_rock_assembly_v1.glb'
    bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_animations=False)
    report['export_sha256'] = hashlib.sha256(export.read_bytes()).hexdigest()
    (WORK/'assembly.json').write_text(json.dumps(report,indent=2)+'\n')
    print('MODULE ASSEMBLY:',json.dumps({k:report[k] for k in ['bounds','validation','export_sha256']}),flush=True)


if __name__=='__main__':
    run()
