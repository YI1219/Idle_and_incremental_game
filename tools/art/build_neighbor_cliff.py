"""Neighbor-constrained convex rock regions unioned into one source prototype.

Own experiment inspired by documented context-sensitive procedural design.
Not a reconstruction of Brushland/Tiny Glade's undisclosed cliff algorithm.
"""
import hashlib
import itertools
import json
import math
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/work/neighbor_cliff/2026-10-18'


def plane_set(core=False, variant='neighbor1'):
    planes = []
    for axis in range(3):
        for sign in [-1, 1]:
            if core and axis == 1 and sign == -1:
                continue
            if core and variant == 'neighbor2' and axis == 2:
                continue
            n = np.zeros(3); n[axis] = sign
            planes.append([n, 1.])
    for a, b in [(0, 1), (1, 2), (0, 2)]:
        for sa, sb in itertools.product([-1, 1], repeat=2):
            n = np.zeros(3); n[a] = sa; n[b] = sb
            planes.append([n, 1.70 if core else 1.76])
    for signs in itertools.product([-1, 1], repeat=3):
        planes.append([np.array(signs, float), 2.35 if core else 2.28])
    if core:
        for n, d in [([.22, -1., .15], 1.04), ([-.26, -1., .13], 1.02),
                     ([.05, -1., -.22], 1.06)]:
            planes.append([np.array(n), d])
        if variant == 'neighbor2':
            # Oblique neighboring rear planes replace the single blank back.
            for n, d in [([.35, .12, -1.], 1.05), ([-.27, -.10, -1.], .98)]:
                planes.append([np.array(n), d])
    else:
        # One large oblique shoulder, not an everywhere-noise displacement.
        planes.append([np.array([-.18, .38, 1.]), 1.18])
        if variant == 'neighbor2':
            # The lower front returns into the shared body before the individual
            # region ends. Avoid a flat foot suspended over a visible plinth.
            planes.append([np.array([.06, -.65, 1.]), 1.10])
    return planes


def convex_object(name, center, radius, angles, core=False, variant='neighbor1'):
    rotation = np.array(Euler(angles, 'XYZ').to_matrix(), float)
    transform = rotation @ np.diag(radius)
    planes = plane_set(core, variant)
    # Same actual upper ground plane clips every neighbor in world space.
    planes.append([transform[1], 3.25-center[1]])
    if core and variant == 'neighbor2':
        normal = np.array([0., -.48, 1.])
        planes.append([transform.T@normal, 1.05-normal@center])
    normals = np.array([p[0] for p in planes])
    offsets = np.array([p[1] for p in planes])
    triples = np.array(list(itertools.combinations(range(len(planes)), 3)))
    matrices = normals[triples]
    valid = np.abs(np.linalg.det(matrices)) > 1e-9
    # Explicit column RHS keeps the batched-vector meaning on NumPy2 as well.
    solutions = np.linalg.solve(matrices[valid], offsets[triples[valid]][..., None])[..., 0]
    solutions = solutions[np.all(solutions@normals.T <= offsets+1e-7, axis=1)]
    points = np.unique(np.round(solutions, 8), axis=0)@transform.T + center
    assert len(points) >= 4
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points.tolist(), [], [])
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bm.calc_volume(signed=True) < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj, {'center':list(center), 'radius':list(radius), 'euler_xyz_radians':list(angles),
                 'normalized_halfspaces':[{'normal':n.tolist(), 'offset':d} for n,d in planes]}


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    variant = 'neighbor2' if '--variant=neighbor2' in sys.argv else 'neighbor1'
    core_center = np.array([.1, .40, -.72]) if variant == 'neighbor2' else np.array([.1, -.05, -.72])
    core_radius = [5.6, 3.35, 2.25] if variant == 'neighbor2' else [5.6, 3.9, 2.25]
    core, core_record = convex_object('common_body', core_center,
                                     core_radius, [0., -.025, -.025], True, variant)
    # A small adjacency chain: common boundary points determine each region's
    # frontage span and tangent determine fitted placement. Heights/depths/leans
    # are curated per-region parameters, not a complete neighbor-case grammar.
    boundaries = np.array([[-5.5, 1.1], [-3.25, 2.2], [.05, 2.5],
                           [3.0, 2.2], [5.5, 1.0]])
    ys = [.55, .30, .72, .95]
    heights = [3.15, 3.60, 3.12, 2.80]
    depths = [1.6, 1.92, 1.65, 1.56]
    leans = [.14, -.11, .12, -.16]
    pieces = []; records = []
    for i in range(len(boundaries)-1):
        a, b = boundaries[i:i+2]
        tangent = b-a
        span = np.linalg.norm(tangent)
        center = np.array([(a[0]+b[0])*.5, ys[i], (a[1]+b[1])*.5-depths[i]*.50])
        # A nonzero deep overlap with the shared volume/neighbor is required;
        # final validity and one-component tests independently check the union.
        angles = [(.04 if i%2 else -.065), -math.atan2(tangent[1], tangent[0]), leans[i]]
        obj, record = convex_object('face_region_'+str(i), center,
                                    [span*.5+.32, heights[i], depths[i]], angles, False, variant)
        record.update({'left_neighbor':i-1 if i else None,
                       'right_neighbor':i+1 if i<3 else None,
                       'frontage_boundaries':[a.tolist(), b.tolist()],
                       'frontage_span':span, 'not_an_independent_runtime_prop':True})
        pieces.append(obj); records.append(record)
    bpy.context.view_layer.objects.active = core
    core.select_set(True)
    for obj in pieces:
        modifier = core.modifiers.new('union_'+obj.name, 'BOOLEAN')
        modifier.operation = 'UNION'; modifier.solver = 'EXACT'; modifier.object = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.hide_viewport = True; obj.hide_render = True
    bm = bmesh.new(); bm.from_mesh(core.data)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bm.calc_volume(signed=True) < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    bm.to_mesh(core.data); bm.free(); core.data.update()
    core.name = variant
    control = ROOT/'art/work/cliff_guides/2026-10-18/broad_turn_7301.bin'
    baseline = np.fromfile(control, dtype='<f4').reshape(-1, 3)
    positions = np.array([v.co[:] for v in core.data.vertices])
    lo, hi = positions.min(0), positions.max(0)
    base_lo, base_hi = baseline.min(0), baseline.max(0)
    scale = float((base_hi[0]-base_lo[0])/(hi[0]-lo[0]))
    # Fair geometric comparison: one uniform similarity transform, same width,
    # XZ bounding center and top as the original. No separate height squash.
    delta = (base_lo+base_hi)*.5 - (lo+hi)*.5*scale
    delta[1] = base_hi[1]-hi[1]*scale
    for obj in [core]+pieces:
        for v in obj.data.vertices:
            v.co = v.co*scale + Vector(delta)
        obj.data.update()
    triangles = np.array([[core.data.vertices[i].co[:] for i in list(p.vertices)[::-1]]
                          for p in core.data.polygons], dtype='<f4')
    triangles.tofile(OUT/(variant+'.bin'))
    shutil.copyfile(control, OUT/'control.bin')
    for obj in [core]+pieces:
        obj.rotation_euler.x = math.pi/2
    bpy.ops.export_scene.gltf(filepath=str(OUT/(variant+'.glb')), use_selection=True, export_format='GLB')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(variant+'.blend')))
    report = {'kind':'Own neighbor-fitted 3D plane-constrained convex regions + exact common-volume union',
              'variant':variant, 'core':core_record, 'face_regions':records,
              'vertices':len(core.data.vertices), 'triangles':len(triangles),
              'uniform_comparison_transform':{'scale':scale, 'translation':delta.tolist(),
                  'raw_bounds':[lo.tolist(),hi.tolist()], 'control_width':float(base_hi[0]-base_lo[0]),
                  'reason':'Match original width, upper peak and XZ center without changing candidate proportions.'},
              'source_sha256':hashlib.sha256((OUT/(variant+'.bin')).read_bytes()).hexdigest(),
              'control_sha256':hashlib.sha256(control.read_bytes()).hexdigest(),
              'not_a_claim_about_reference_internal_algorithms':True,
              'scope':'One standard prototype; not arbitrary contours/seed generation, art or runtime acceptance. No new external assets/paid task.'}
    (OUT/(variant+'.json')).write_text(json.dumps(report, indent=2)+'\n')
    print('NEIGHBOR CLIFF:', variant, report['triangles'], 'triangles', flush=True)


if __name__ == '__main__':
    run()
