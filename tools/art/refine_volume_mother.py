"""Blender: one bounded lower-body refinement of the preserved Tripo mother.

No new topology, cap deformation, remesh, generation job or source overwrite.
The original canonical copy remains in a hidden collection in the work .blend.
"""
import hashlib
import importlib.util
import json
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/source/cliff_master_v2/2026-10-18/tripo/cliff_land_master_v2_white.glb'
WORK = ROOT / 'art/work/volume_shape/2026-10-20'
SCALE = 8.503401418144534
OFFSET_Y = -1.1471089444


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def triangles(objects):
    result = []
    for obj in objects:
        obj.data.calc_loop_triangles()
        for triangle in obj.data.loop_triangles:
            # Blender CCW -> Godot CW; canonical Blender XYZ -> Godot XZ-Y.
            for index in reversed(triangle.vertices):
                p = obj.matrix_world @ obj.data.vertices[index].co
                result.append((p.x, p.z, -p.y))
    return np.asarray(result, dtype='<f4')


def smoothstep(low, high, value):
    t = np.clip((value-low)/(high-low), 0., 1.)
    return t*t*(3.-2.*t)


def run():
    WORK.mkdir(parents=True, exist_ok=True)
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    originals = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    original_collection = bpy.data.collections.new('Preserved canonical original')
    bpy.context.scene.collection.children.link(original_collection)
    refined_collection = bpy.data.collections.new('Lower body refinement v1')
    bpy.context.scene.collection.children.link(refined_collection)
    for obj in originals:
        positions = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
        for vertex, p in zip(obj.data.vertices, positions):
            vertex.co = Vector((p.y*SCALE, -p.x*SCALE, p.z*SCALE+OFFSET_Y))
        obj.matrix_world.identity()
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        original_collection.objects.link(obj)
    original_points = triangles(originals)
    canonical = np.fromfile(ROOT/'art/work/volume_patch/2026-10-19/source.bin', dtype='<f4').reshape(-1, 3)
    # Exporter face ordering is not assumed. Every canonical source position
    # must coincide before any refinement is allowed.
    from mathutils.kdtree import KDTree
    tree = KDTree(len(original_points))
    for i, p in enumerate(original_points):
        tree.insert(Vector(p), i)
    tree.balance()
    nearest = [tree.find(Vector(p)) for p in canonical]
    delta = np.asarray([hit[0][:] for hit in nearest])-canonical
    canonical_error = max(hit[2] for hit in nearest)
    print('CANONICAL COMPARISON', json.dumps(dict(error=canonical_error, delta_min=delta.min(0).tolist(),
          delta_max=delta.max(0).tolist(), delta_mean=delta.mean(0).tolist(),
          blender_bounds=[original_points.min(0).tolist(), original_points.max(0).tolist()],
          godot_bounds=[canonical.min(0).tolist(), canonical.max(0).tolist()])), flush=True)
    # Blender and Godot decode the same GLB to positions differing by<=.8mm
    # in this8.5m pose. Conform the working copy to the *actual preserved
    # Godot baseline* before editing, rather than drifting its unchanged cap.
    assert canonical_error < .001, canonical_error
    canonical_tree = KDTree(len(canonical))
    for i, p in enumerate(canonical):
        canonical_tree.insert(Vector(p), i)
    canonical_tree.balance()
    matched = set()
    for obj in originals:
        for vertex in obj.data.vertices:
            p = vertex.co
            hit = canonical_tree.find(Vector((p.x, p.z, -p.y)))
            matched.add(tuple(hit[0]))
            vertex.co = Vector((hit[0].x, -hit[0].z, hit[0].y))
    assert len(matched) == 2516
    original_points = triangles(originals)
    refined, cap_errors, displacements = [], [], []
    for original in originals:
        obj = original.copy()
        obj.data = original.data.copy()
        obj.name = 'cliff_land_v2_lower_return_v1'
        refined_collection.objects.link(obj)
        positions = np.asarray([v.co[:] for v in obj.data.vertices], dtype=float)
        before = positions.copy()
        neighbors = [set() for _ in positions]
        for edge in obj.data.edges:
            a, b = edge.vertices
            neighbors[a].add(b)
            neighbors[b].add(a)
        # Remove small puffy lower protrusions without flattening the cap or
        # reducing height. This is an existing-vertex, horizontal-only edit.
        weight = .35 * (1.-smoothstep(.0, 2.15, positions[:, 2]))
        for _ in range(8):
            average = np.asarray([positions[list(n)].mean(0) if n else p for n, p in zip(neighbors, positions)])
            positions[:, :2] += (average[:, :2]-positions[:, :2])*weight[:, None]
        factor = .62 + .38*smoothstep(-1.147109, 2.15, positions[:, 2])
        positions[:, :2] *= factor[:, None]
        for vertex, p in zip(obj.data.vertices, positions):
            vertex.co = Vector(p)
        cap_errors.extend(np.linalg.norm((positions-before)[before[:, 2] >= 2.15], axis=1).tolist())
        displacements.extend(np.linalg.norm(positions-before, axis=1).tolist())
        refined.append(obj)
    refined_points = triangles(refined)
    topology = module('refined_topology', 'tools/art/sample_cliff_representation.py')
    before_topology = topology.topology([Vector(p) for p in original_points])
    after_topology = topology.topology([Vector(p) for p in refined_points])
    assert after_topology['non_two_use_edges'] == 0 and after_topology['signed_volume'] > 0, after_topology
    assert before_topology['triangles'] == after_topology['triangles'] == 5028
    assert max(cap_errors, default=0.) == 0.
    assert np.array_equal(original_points[:, 1], refined_points[:, 1])
    (WORK/'source.bin').write_bytes(refined_points.tobytes())
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    for obj in refined:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = refined[0]
    original_collection.hide_render = True
    original_collection.hide_viewport = True
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'cliff_land_v2_lower_return_v1.blend'))
    export = WORK/'cliff_land_v2_lower_return_v1.glb'
    bpy.ops.export_scene.gltf(filepath=str(export), export_format='GLB', use_selection=True,
                              export_animations=False, export_morph=False)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
    report = dict(source=str(SOURCE.relative_to(ROOT)), source_sha256=source_hash,
                  blender=bpy.app.version_string, pre_conformance_import_difference_m=canonical_error,
                  conformed_to_preserved_godot_baseline=True, conformed_unique_vertices=len(matched),
                  before_topology=before_topology, after_topology=after_topology,
                  cap_y_at_or_above=2.15, cap_max_displacement_m=max(cap_errors, default=0.),
                  y_coordinates_identical=True, max_vertex_displacement_m=max(displacements),
                  horizontal_smoothing=dict(iterations=8, lower_weight=.35), bottom_scale=.62,
                  bounds=[refined_points.min(0).tolist(), refined_points.max(0).tolist()],
                  source_triangles_sha256=hashlib.sha256(refined_points.tobytes()).hexdigest(),
                  export_sha256=hashlib.sha256(export.read_bytes()).hexdigest(),
                  scope='Existing-source horizontal smoothing and lower return only. Topology and absent-UV status retained; no new bake or custom generation. Art unaccepted.')
    (WORK/'refinement.json').write_text(json.dumps(report, indent=2)+'\n')
    sampler = module('refined_sampler', 'tools/art/sample_tripo_master.py')
    records, evidence = sampler.sample_geometry(refined_points.astype(float))
    low = np.floor((refined_points.min(0)-.75)/.25).astype(int)
    high = np.ceil((refined_points.max(0)+.75)/.25).astype(int)
    size = high-low+1
    density = np.full((size[2], size[1], size[0]), .5, dtype='<f4')
    for record in records:
        density[record['z']-low[2], record['y']-low[1], record['x']-low[0]] = record['density']
    density.tofile(WORK/'density.bin')
    evidence.update(low=low.tolist(), size=size.tolist(), input_topology=after_topology,
                    density_sha256=hashlib.sha256(density.tobytes()).hexdigest())
    (WORK/'sampling.json').write_text(json.dumps(evidence, indent=2)+'\n')
    print('VOLUME MOTHER REFINEMENT:', json.dumps(report), flush=True)


if __name__ == '__main__':
    run()
