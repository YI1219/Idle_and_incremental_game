"""Blender: authored plane compression of the existing mother vertices.

This is not an official new model or a source overwrite. Plane coefficients are
an authoring choice for the local comparison, not a user-approved asset design.
"""
import hashlib
import importlib.util
import json
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT/'art/work/volume_shape/2026-10-20/cliff_land_v2_lower_return_v1.blend'
WORK = ROOT/'art/work/volume_planes/2026-10-20'
# Deliberate broad planes, in Godot meters. Rear is two oblique planes rather
# than a uniform wall. They compress protrusions; they never expand a groove.
PLANES = {'front': [1.23,.21,.09], 'rear':[1.10,.22,.22,.25],
          'sides':[2.60,.39,.14], 'compression_span':.28}


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def smoothstep(low, high, value):
    t = np.clip((value-low)/(high-low), 0., 1.)
    return t*t*(3.-2.*t)


def compress(value, limit, weight):
    excess = abs(value)-limit
    if excess <= 0:
        return value, 1.
    span = PLANES['compression_span']
    attenuation = np.exp(-excess/span)
    target = np.copysign(limit+span*(1.-attenuation), value)
    # Strictly monotone along this axis for each fixed pair of other axes.
    return value*(1.-weight)+target*weight, (1.-weight)+weight*attenuation


def run():
    WORK.mkdir(parents=True, exist_ok=True)
    source_hash = hashlib.sha256(INPUT.read_bytes()).hexdigest()
    previous = module('lower_return_helpers', 'tools/art/refine_volume_mother.py')
    geometry = module('plane_source_topology', 'tools/art/sample_cliff_representation.py')
    checks = module('plane_source_crossings', 'tools/art/check_cliff_dual_intersections.py')
    bpy.ops.wm.open_mainfile(filepath=str(INPUT))
    source = bpy.data.objects['cliff_land_v2_lower_return_v1']
    before = previous.triangles([source])
    collection = bpy.data.collections.new('Authored side-plane compression v1')
    bpy.context.scene.collection.children.link(collection)
    candidate = source.copy()
    candidate.data = source.data.copy()
    candidate.name = 'cliff_land_v2_side_planes_v1'
    collection.objects.link(candidate)
    displacements, derivatives, changed, protected = [], [], 0, 0
    for vertex in candidate.data.vertices:
        original = np.asarray((vertex.co.x, vertex.co.z, -vertex.co.y), dtype=float)
        x, y, z = original
        # Protect the actual upper planting cap, rather than a1.1m side-wall band.
        weight = .9 * (1.-smoothstep(2.45, 2.85, y))*smoothstep(-.9, .25, y)
        if weight <= 0:
            protected += 1
            continue
        front, rear, sides = PLANES['front'], PLANES['rear'], PLANES['sides']
        limit_z = front[0]+front[1]*y+front[2]*x if z >= 0 else rear[0]+rear[1]*y+rear[2]*abs(x-rear[3])
        new_z, derivative_z = compress(z, limit_z, weight)
        limit_x = sides[0]+sides[1]*y+sides[2]*new_z
        new_x, derivative_x = compress(x, limit_x, weight)
        vertex.co.x = new_x
        vertex.co.y = -new_z
        delta = float(np.hypot(new_x-x, new_z-z))
        displacements.append(delta)
        derivatives.append(derivative_z*derivative_x)
        changed += delta > .000001
    after = previous.triangles([candidate])
    assert np.array_equal(before[:, 1], after[:, 1])
    cap = before[:, 1] >= 2.85
    assert np.array_equal(before[cap], after[cap])
    path = WORK/'source.bin'
    path.write_bytes(after.tobytes())
    topology = geometry.topology([Vector(p) for p in after])
    topology['vertex_link_defects'] = checks.vertex_link_defects(after)
    intersections = checks.inspect_file(path)
    report = dict(input=str(INPUT.relative_to(ROOT)), input_sha256=source_hash,
                  blender=bpy.app.version_string, plane_parameters=PLANES, maximum_weight=.9,
                  protected_y=2.85, protected_vertices=protected, changed_vertices=changed,
                  all_y_coordinates_preserved=True, upper_source_positions_identical=True,
                  maximum_displacement_m=max(displacements), minimum_sampled_composed_axis_derivative=min(derivatives),
                  bounds=[after.min(0).tolist(), after.max(0).tolist()],
                  topology=topology, intersections=intersections,
                  source_triangles_sha256=hashlib.sha256(after.tobytes()).hexdigest(),
                  scope='One authored monotone plane compression, existing topology/height/cap retained. No new original mesh, random sweep, source overwrite, extra rendered guide or art acceptance.')
    valid = all(topology[k] == 0 for k in ['non_two_use_edges', 'directed_edge_pair_defects', 'degenerate_index_faces', 'vertex_link_defects'])
    valid = valid and topology['signed_volume'] > 0 and len(topology['vertex_components']) == 1
    valid = valid and intersections['strict_crossing_pairs_at_least'] == 0
    report['finite_gate_passed'] = valid
    (WORK/'refinement.json').write_text(json.dumps(report, indent=2)+'\n')
    assert valid, {'topology':topology, 'strict_crossings':intersections['strict_crossing_pairs_at_least']}
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
        if obj != candidate:
            obj.hide_render = True
            obj.hide_set(True)
    candidate.select_set(True)
    bpy.context.view_layer.objects.active = candidate
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'cliff_land_v2_side_planes_v1.blend'))
    export = WORK/'cliff_land_v2_side_planes_v1.glb'
    bpy.ops.export_scene.gltf(filepath=str(export), export_format='GLB', use_selection=True,
                              export_animations=False, export_morph=False)
    assert hashlib.sha256(INPUT.read_bytes()).hexdigest() == source_hash
    report['export_sha256'] = hashlib.sha256(export.read_bytes()).hexdigest()
    (WORK/'refinement.json').write_text(json.dumps(report, indent=2)+'\n')
    records, evidence = module('plane_source_sampler', 'tools/art/sample_tripo_master.py').sample_geometry(after.astype(float))
    low = np.floor((after.min(0)-.75)/.25).astype(int)
    high = np.ceil((after.max(0)+.75)/.25).astype(int)
    size = high-low+1
    density = np.full((size[2], size[1], size[0]), .5, dtype='<f4')
    for row in records:
        density[row['z']-low[2], row['y']-low[1], row['x']-low[0]] = row['density']
    density.tofile(WORK/'density.bin')
    evidence.update(low=low.tolist(), size=size.tolist(), input_topology=topology,
                    density_sha256=hashlib.sha256(density.tobytes()).hexdigest())
    (WORK/'sampling.json').write_text(json.dumps(evidence, indent=2)+'\n')
    print('SIDE PLANE COMPRESSION:', json.dumps(report), flush=True)


if __name__ == '__main__':
    run()
