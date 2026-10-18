"""Complete connected cliff study: convex unequal planes and terminating clefts.

Local code-guide authoring explicitly requested by user. No remote generation,
production promotion, or arbitrary-layout claim. Run with Blender Python.
"""
import hashlib
import json
import math
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/work/cliff_planes/2026-10-18'


def geometry(variant='planes1'):
    front = [(-5.5, 1.2), (-5.3, 1.85), (-4.75, 2.05), (-3.7, 2.15),
             (-3.3, 1.95), (-3.05, 1.25), (-2.75, 1.75), (-2.2, 2.2),
             (-.25, 2.55), (.9, 2.5), (1.35, 2.1), (1.55, 1.35),
             (1.9, 1.85), (2.6, 2.25), (3.65, 2.4), (4.0, 1.9),
             (4.2, 1.15), (4.5, 1.55), (5.15, 1.75), (5.5, 1.1)]
    back = [(5.2, -1.2), (4., -2.35), (2.7, -2.5), (1.9, -2.1),
            (1.65, -1.7), (1.25, -2.0), (-.6, -2.5), (-2.2, -2.3),
            (-2.45, -1.7), (-2.8, -2.05), (-4.3, -2.25), (-5.2, -1.25)]
    polygon = np.array(front + back, float)
    n = len(polygon)
    angle = np.arctan2(polygon[:, 1], polygon[:, 0])
    x = polygon[:, 0]
    top_y = 3.05 + .16*np.sin(x*.9+.2) + .08*np.cos(angle*2)
    if variant == 'planes2':
        # A gently tilted ground plane avoids near-collinear long top triangles
        # becoming artificial deep trenches from nonlinear rim-only heights.
        top_y = 3.10 + .018*x + .035*polygon[:, 1]
    top = np.column_stack([polygon[:, 0], top_y, polygon[:, 1]])
    rings = [top]
    # Each ring is only a shared topology scaffold: its heights and bends vary
    # per face. Clefts fill into the same lower body, not separate stone soles.
    factors = [.99, .94, .73, .45]
    heights = [2.35, .45, -1.18, -2.30]
    amplitudes = [.42, .62, .40, .28]
    clefts = [5, 11, 16, 24, 28]
    for level, (factor, y, amplitude) in enumerate(zip(factors, heights, amplitudes)):
        shape = polygon.copy()
        closure = [0., .40, .90, 1.][level]
        for i in clefts:
            shape[i] = (1-closure)*shape[i] + closure*(polygon[i-1]+polygon[(i+1)%n])*.5
        shape *= factor
        # Different inclined main masses meet one offset common return.
        shape[:, 0] += [-.04, -.24, .12, -.10][level] + [.06, .15, .10, .04][level]*np.sin(x*.65)
        shape[:, 1] += [.035, .21, -.03, -.20][level]*np.sin(angle)
        if level in [0, 1]:
            # Broad convex shoulder/face relief, not small noisy stones.
            relief = np.maximum(0., np.sin((x+2.9)*.71))**2
            shape[:len(front), 1] += [.04, .32][level]*relief[:len(front)]
        yy = y + amplitude*np.sin(x*.83+angle*.30+level*.63)
        if level == 3:
            yy += .13*np.cos(angle*2+.4)
        if variant == 'planes2':
            # Second substantive rule: maintain long lateral extent while
            # returning strongly in depth. Individual convex main faces lean
            # differently; this replaces the concentric pot/three-panel rule.
            shape = polygon.copy()
            for i in clefts:
                shape[i] = (1-closure)*shape[i] + closure*(polygon[i-1]+polygon[(i+1)%n])*.5
            shape[:, 0] *= [.99, .96, .88, .76][level]
            shape[:, 1] *= [.99, 1.02, .72, .34][level]
            shear = .62*np.sin(x*.69+.55)
            shape[:, 0] += [.08, .72, 1., .7][level]*shear
            shape[:, 1] -= [.0, .02, .16, .24][level]
            joints = [-5.5, -3.05, 1.55, 4.2, 5.5]
            for i in range(len(front)):
                group = min(int(np.searchsorted(joints, x[i], side='right'))-1, 3)
                group = max(group, 0)
                u = np.clip((x[i]-joints[group])/(joints[group+1]-joints[group]), 0, 1)
                convex = math.sin(math.pi*u)**.75
                shape[i, 1] += [.035, .68, .34, .05][level]*convex
                if level == 2:
                    yy[i] += [.35, -.35, .10, .4][group]*convex
        rings.append(np.column_stack([shape[:, 0], yy, shape[:, 1]]))
    assert all(np.all(rings[i][:, 1] > rings[i+1][:, 1]+.15) for i in range(4))
    points = np.concatenate(rings)
    faces = list(tessellate_polygon([[Vector(v) for v in top]]))
    for level in range(4):
        for i in range(n):
            a = level*n+i
            b = level*n+(i+1)%n
            c, d = b+n, a+n
            faces.extend([(a, b, c), (a, c, d)] if (i+level)%2 else [(a, b, d), (b, c, d)])
    # A center fan assumes a star-shaped projected bottom and crossed a lower
    # strip near an almost-collinear corner. Tessellate the actual XZ contour;
    # retain its non-coplanar heights instead of adding a flat bottom plate.
    bottom = rings[-1]
    cap = tessellate_polygon([[Vector((v[0], v[2], 0)) for v in bottom]])
    faces.extend(tuple(4*n+i for i in triangle) for triangle in cap)
    return points, faces, {'front':front, 'back':back, 'clefts':clefts,
                           'section_scales':factors, 'section_y':heights,
                           'section_y_amplitude':amplitudes, 'variant':variant}


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    variant = 'planes2' if '--variant=planes2' in sys.argv else 'planes1'
    points, faces, parameters = geometry(variant)
    mesh = bpy.data.meshes.new(variant)
    mesh.from_pydata(points.tolist(), [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bm.calc_volume(signed=True) < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(variant, mesh)
    bpy.context.collection.objects.link(obj)
    obj.rotation_euler.x = math.pi/2
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(variant+'.glb')), use_selection=True, export_format='GLB')
    triangles = np.array([[mesh.vertices[i].co[:] for i in list(p.vertices)[::-1]]
                          for p in mesh.polygons], dtype='<f4')
    triangles.tofile(OUT/(variant+'.bin'))
    control = ROOT/'art/work/cliff_guides/2026-10-18/broad_turn_7301.bin'
    shutil.copyfile(control, OUT/'control.bin')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(variant+'.blend')))
    report = {'rule':'Unequal convex faces, differently located shoulders and cleft termination into shared irregular lower return.',
              'parameters':parameters, 'vertices':len(points), 'triangles':len(triangles),
              'control_sha256':hashlib.sha256(control.read_bytes()).hexdigest(),
              'candidate_sha256':hashlib.sha256((OUT/(variant+'.bin')).read_bytes()).hexdigest(),
              'scope':'Selected user-authorized code guide refinement. No new remote assets, accepted art or arbitrary contour/editor integration.'}
    (OUT/(variant+'.json')).write_text(json.dumps(report, indent=2)+'\n')
    print('CLIFF PLANES:', variant, report['vertices'], report['triangles'], flush=True)


if __name__ == '__main__':
    run()
