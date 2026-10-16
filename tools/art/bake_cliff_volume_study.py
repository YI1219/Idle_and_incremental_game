"""Refine exported existing crown solids, then author a bounded editable SDF.

This is an unaccepted volume experiment, not a runtime mesh replacement or
automatic source assembly feature. Blender sources and ordinary save retained.
"""
import bpy
import bmesh
import hashlib
import json
import math
import sys
from array import array
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/work/cliff_volume/2026-10-16'
VERSION = sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1', 'v2', 'v3']
source = json.loads((OUT / 'source.json').read_text())
payload = json.loads((OUT / 'base_save.json').read_text())
lo, hi, step = source['lo'], source['hi'], source['step']
nx, ny, nz = [hi[i] - lo[i] + 1 for i in range(3)]
nodes, columns = array('f'), array('f')
nodes.frombytes((OUT / 'base_nodes.bin').read_bytes())
columns.frombytes((OUT / 'base_columns.bin').read_bytes())
assert len(nodes) == nx*ny*nz
assert len(columns) == nx*nz*(len(source['levels'])+1)
assert all(math.isfinite(v) and abs(v) <= .5 for v in nodes)
bpy.ops.wm.read_factory_settings(use_empty=True)
solids, reports = [], []
for index, crown in enumerate(source['crowns']):
    # Godot uses clockwise front faces. Source positions come from the exact
    # published closed crown, not the separate wall-only draw mesh.
    vertices = crown['world_faces']
    mesh = bpy.data.meshes.new(f'ExistingCrown_{index}')
    mesh.from_pydata(vertices, [], [(i, i+2, i+1) for i in range(0, len(vertices), 3)])
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.00001)
    before_bad = sum(not e.is_manifold for e in bm.edges)
    assert before_bad == 0, (index, before_bad)
    # Add samples along real source faces before the nonlinear lower return;
    # merely dragging a few coarse core vertices made steps in the prior trial.
    for _ in range(4):
        edges = [e for e in bm.edges if e.calc_length() > .45]
        if not edges: break
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True)
    h, outward = crown['cap_height'], Vector(crown['outward'])
    for vertex in bm.verts:
        depth = max(0.0, h-vertex.co.y)
        lateral = .40*depth*depth if VERSION == 'v1' else .10*depth+.55*max(0,depth-.8)**2
        vertex.co -= outward*(.60 + lateral)
        vertex.co.y = h-depth*1.55
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bm.calc_volume(signed=True) < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    bm.normal_update()
    bad = sum(not e.is_manifold for e in bm.edges)
    tiny = sum(f.calc_area() < 1e-12 for f in bm.faces)
    volume = bm.calc_volume(signed=True)
    assert bad == tiny == 0 and volume > 0, (index, bad, tiny, volume)
    lower = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    upper = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
    solids.append((BVHTree.FromBMesh(bm, epsilon=0), lower, upper))
    reports.append(dict(kind=crown['kind'], edge=crown['edge'], triangles=len(bm.faces),
        nonmanifold_edges=bad, degenerate_faces=tiny, volume=volume,
        operation=('Existing closed source, face subdivision, cap-anchored1.55 vertical extension and inward.60+.40*depth² return.' if VERSION=='v1' else 'Existing closed source, face subdivision, cap-anchored1.55 extension; quiet upper shoulder then inward.60+.10*depth+.55*max(depth-.8,0)² return.')))
    bm.to_mesh(mesh); bm.free(); mesh.update()
    obj = bpy.data.objects.new(f'RefinedCrown_{index}_GodotYUp', mesh)
    bpy.context.collection.objects.link(obj)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f'source_volume_{VERSION}.blend'))

ray = Vector((.8731, .3817, .3039)).normalized()
def signed_distance(solid, point):
    tree, lower, upper = solid
    if any(point[i] < lower[i]-.7 or point[i] > upper[i]+.7 for i in range(3)):
        return .5
    nearest = tree.find_nearest(point)
    assert nearest[0] is not None
    distance = nearest[3]
    # Closed-source parity defines sign, including concave source shoulders.
    origin, hits = point+ray*1e-7, 0
    for _ in range(32):
        hit = tree.ray_cast(origin, ray, 100.0)
        if hit[0] is None: break
        hits += 1
        origin = hit[0] + ray*.00001
    else:
        raise RuntimeError('Unbounded parity traversal')
    return -distance if hits % 2 else distance

def ease(a, b, v):
    t = max(0.0, min(1.0, (v-a)/(b-a)))
    return t*t*(3-2*t)
def join(a, b, radius):
    t = max(0.0, min(1.0, .5+.5*(b-a)/radius))
    return b*(1-t)+a*t-radius*t*(1-t)

fractures = []
if VERSION == 'v3':
    crowns = sorted(source['crowns'], key=lambda crown:crown['edge'][0])
    for i, (a,b) in enumerate(zip(crowns,crowns[1:])):
        outward = (Vector(a['outward'])+Vector(b['outward'])).normalized()
        center = Vector(((a['edge'][0]+b['edge'][0])/2, 0, (a['edge'][1]+b['edge'][1])/2))
        tangent = Vector((-outward.z,0,outward.x))
        fractures.append((center,outward,tangent, .09 if i==0 else .16, .22 if i==0 else .30, .06 if i==0 else -.09))

records, maximum_delta = [], 0.0
density = list(nodes)
for iz in range(nz):
    z = (lo[2]+iz)*step
    for ix in range(nx):
        x = (lo[0]+ix)*step
        weight = ease(-20,-18.8,x)*(1-ease(-11.2,-10,x))*ease(0,.85,z)*(1-ease(7.1,8,z))
        if weight <= 0: continue
        col = (iz*nx+ix)*(len(source['levels'])+1)
        height = columns[col]
        distances = columns[col+1:col+1+len(source['levels'])]
        if distances[0] < -6 or distances[0] > 1.5: continue
        for iy in range(ny):
            y = (lo[1]+iy)*step
            index = (iz*ny+iy)*nx+ix
            old = nodes[index]
            depth = max(0.0, height-y)
            # The calm base remains behind the warped real source faces.
            candidate = max(old, distances[0]+max(0.0, depth-1.1)*.80)
            point = Vector((x,y,z))
            radius = .30 + .35*ease(2.5,5.0,depth)
            for solid in solids:
                candidate = join(candidate, signed_distance(solid, point), radius)
            # Keep the original dry top and a bounded stone shoulder. This
            # avoids the grass roofs from earlier three-axis shoulder stamps.
            allowance = (.40*ease(0,.8,depth) if VERSION == 'v1' else 3.0*ease(0,.75,depth))
            ceiling = min(max(d-allowance,y-h) for d,h in zip(distances,source['levels']))
            candidate = max(candidate, ceiling)
            if VERSION == 'v3':
                # An outward-opening fracture has no bounded horizontal roof.
                # Its tip and width vary with depth, then terminate into the
                # common lower solid rather than cutting it into loose panels.
                for center,outward,tangent,width,spread,lean in fractures:
                    offset = point-center
                    u = offset.dot(tangent)+lean*depth
                    v = offset.dot(outward)+.12*max(0,depth-1.4)**2
                    opening = max(0.0,1-ease(2.6,4.5,depth))
                    cut = max(abs(u)-(width+spread*max(0,v+.65))*opening,
                              -v-.75, depth-4.5)
                    candidate = max(candidate,-cut)
            value = round(old*(1-weight)+max(-.5,min(.5,candidate))*weight, 5)
            if abs(value) < .00001: value = .00002
            density[index] = value
            if abs(value-old) < .000001: continue
            maximum_delta = max(maximum_delta, abs(value-old))
            records.append(dict(x=lo[0]+ix,y=lo[1]+iy,z=lo[2]+iz,density=value))
removed_components = []
if VERSION == 'v3':
    # Authoring cleanup only: retain all negative components connected to the
    # unchanged collar. Use the actual six-tetrahedron edge graph, not merely
    # six-connected voxels that would misclassify diagonal solid connections.
    neighbors = [(a,b,c) for a,b,c in [(1,0,0),(0,1,0),(0,0,1),(1,1,0),(1,0,1),(0,1,1),(1,1,1)]
                 for a,b,c in [(a,b,c),(-a,-b,-c)]]
    unseen = {i for i,value in enumerate(density) if value<0}
    while unseen:
        start = unseen.pop(); stack=[start]; component=[start]; anchored=False
        while stack:
            index = stack.pop()
            iz, remainder = divmod(index,nx*ny); iy,ix=divmod(remainder,nx)
            anchored |= ix in [0,nx-1] or iy in [0,ny-1] or iz in [0,nz-1]
            for dx,dy,dz in neighbors:
                xx,yy,zz=ix+dx,iy+dy,iz+dz
                if not (0<=xx<nx and 0<=yy<ny and 0<=zz<nz):continue
                other=(zz*ny+yy)*nx+xx
                if other in unseen:
                    unseen.remove(other);stack.append(other);component.append(other)
        if not anchored:
            removed_components.append(len(component))
            for index in component:density[index]=.5
    records=[]
    for index,value in enumerate(density):
        if abs(value-nodes[index])<.000001:continue
        # Keep finite crossings away from exact lattice corners in this
        # authored study; no runtime mesher threshold is changed.
        if abs(value)<.002:value=.002 if value>0 else -.002
        iz,remainder=divmod(index,nx*ny);iy,ix=divmod(remainder,nx)
        records.append(dict(x=lo[0]+ix,y=lo[1]+iy,z=lo[2]+iz,density=value))
    maximum_delta=max(abs(record['density']-nodes[((record['z']-lo[2])*ny+record['y']-lo[1])*nx+record['x']-lo[0]]) for record in records)
assert len(records) <= 160000
payload['rocks'] = records
save = OUT / f'volume_{VERSION}.json'
save.write_text(json.dumps(payload, separators=(',', ':')) + '\n')
report = dict(source_sha256=hashlib.sha256((OUT/'source.json').read_bytes()).hexdigest(),
    baseline_sha256=hashlib.sha256((OUT/'base_save.json').read_bytes()).hexdigest(),
    save_sha256=hashlib.sha256(save.read_bytes()).hexdigest(), sources=reports,
    records=len(records), maximum_density_change=maximum_delta, removed_unanchored_node_components=removed_components,
    volume_operations=('Two unequal open-top outward V fractures, 4.5m depth termination, negative tetra-edge component cleanup and .002 minimum changed-node magnitude; source meshes remain v2.' if VERSION=='v3' else 'Smooth union with bounded cap guard; no component cleanup.'),
    step=step, bounds=dict(lo=lo,hi=hi), blender_version=bpy.app.version_string,
    stage='Unaccepted bounded editable volume study; ordinary save loader and actual native views required. Not a new player brush or runtime model assembly feature.')
(OUT/f'volume_{VERSION}_report.json').write_text(json.dumps(report, indent=2)+'\n')
print('CLIFF VOLUME BAKE:', json.dumps(report))
