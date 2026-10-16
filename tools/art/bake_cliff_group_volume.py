"""Refine an existing scan into one closed source, then author a local volume.

Actual three-dimensional front/shoulder/corner geometry is retained. The added
back is for burial inside the island, not an invented visible rock front.
"""
import bpy,bmesh,hashlib,json,math,sys
from array import array
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/polyhaven_rocks/2026-10-17/namaqualand_cliff_02'
OUT=ROOT/'art/work/cliff_group_volume/2026-10-17';OUT.mkdir(parents=True,exist_ok=True)
VERSION=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1','v2']
suffix='' if VERSION=='v1' else '_v2'
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17'
COMPLETE=ROOT/'art/work/rendered_island/2026-10-17/complete'
source=WORK/'namaqualand_cliff_02_study_4k.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bm=bmesh.new();bm.from_mesh(obj.data);bm.normal_update()
if VERSION=='v2':
 for v in bm.verts:
  y,z=v.co.y,v.co.z;v.co.y=(y-z)*math.sqrt(.5);v.co.z=(y+z)*math.sqrt(.5)
 bm.normal_update()
open_tree=BVHTree.FromBMesh(bm,epsilon=0)
cap_hit=open_tree.ray_cast(Vector((0,-100,4.8)),Vector((0,1,0)),200)
assert cap_hit[0] is not None
cap_front_y=cap_hit[0].y
boundary=[e for e in bm.edges if e.is_boundary]
assert len(boundary)==188 and all(sum(e.is_boundary for e in v.link_edges)==2 for e in boundary for v in e.verts)
# Close the single actual outer boundary behind the scan. Preserve every
# source-front vertex; synthetic side/back faces are separately identified.
back_y=max(v.co.y for v in bm.verts)+.5
back={v:bm.verts.new(Vector((v.co.x,back_y,v.co.z))) for v in {v for e in boundary for v in e.verts}}
for e in boundary:
 loop=e.link_loops[0];a,b=loop.vert,loop.link_loop_next.vert
 f=bm.faces.new((b,a,back[a],back[b]));f.material_index=1
back_edges=[e for e in bm.edges if e.is_boundary]
filled=bmesh.ops.holes_fill(bm,edges=back_edges,sides=0)['faces']
assert len(filled)==1
for f in filled:f.material_index=1
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_co=Vector((0,0,4.8)),plane_no=Vector((0,0,1)),clear_outer=True,clear_inner=False)
caps=bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)['faces']
for f in caps:f.material_index=2
bmesh.ops.triangulate(bm,faces=list(bm.faces))
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
assert not any(not e.is_manifold for e in bm.edges)
if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.normal_update()
assert bm.calc_volume(signed=True)>0
source_state={'triangles':len(bm.faces),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'signed_volume':bm.calc_volume(signed=True),'back_plane_y':back_y,'cap_plane_z':4.8,'cap_faces':len(caps)}
bm.to_mesh(obj.data);obj.data.update();bm.free()
obj.name='NamaCliff_ClosedExistingSource';obj.data.materials.clear()
for f in obj.data.polygons:f.use_smooth=True
bpy.context.view_layer.objects.active=obj;obj.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'closed_source{suffix}.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/f'closed_source{suffix}.glb'),export_format='GLB',use_selection=True,export_materials='NONE',export_animations=False)
# Source Z-up to Godot Y-up, one uniform scale and rigid horizontal rotation.
scale=1.1;yaw=math.radians(10);T=Vector((math.cos(yaw),0,math.sin(yaw)));O=Vector((-math.sin(yaw),0,math.cos(yaw)))
origin=Vector((-15.438,3.5-4.8*scale,3.728))+O*((1.3789176842083133 if VERSION=='v1' else cap_front_y)*scale)
bm=bmesh.new();bm.from_mesh(obj.data)
for v in bm.verts:
 p=v.co.copy();v.co=origin+scale*(T*p.x-O*p.y+Vector((0,p.z,0)))
bm.normal_update();tree=BVHTree.FromBMesh(bm,epsilon=0)
world_lo=[min(v.co[k] for v in bm.verts) for k in range(3)];world_hi=[max(v.co[k] for v in bm.verts) for k in range(3)]
bm.free()
grid=json.loads((BASE/'source.json').read_text());lo,hi,step=grid['lo'],grid['hi'],grid['step'];nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
base=array('f');base.frombytes((BASE/'base_nodes.bin').read_bytes())
payload=json.loads((COMPLETE/'rendered_body_complete.json').read_text())
original=list(base)
for r in payload['rocks']:original[((r['z']-lo[2])*ny+r['y']-lo[1])*nx+r['x']-lo[0]]=r['density']
outcrops=[];full=json.loads((COMPLETE/'source.json').read_text())
for component in full['components'][48:]:
 values=array('f');values.frombytes((COMPLETE/component['path']).read_bytes())
 points=[Vector(values[i:i+3]) for i in range(0,len(values),3)]
 lower=Vector([min(p[k] for p in points) for k in range(3)]);upper=Vector([max(p[k] for p in points) for k in range(3)])
 if upper.x< -22 or lower.x> -8 or upper.z< -3 or lower.z>9:continue
 outcrops.append((BVHTree.FromPolygons(points,[(i,i+2,i+1) for i in range(0,len(points),3)],all_triangles=True),lower,upper))
ray=Vector((.8731,.3817,.3039)).normalized();queries=0
def signed(tree,p):
 global queries
 nearest=tree.find_nearest(p);assert nearest[0] is not None
 pos=p+ray*1e-5;winding=0
 for _ in range(128):
  h=tree.ray_cast(pos,ray,150)
  if h[0] is None:break
  d=h[1].dot(ray)
  if d>1e-6:winding+=1
  elif d< -1e-6:winding-=1
  pos=h[0]+ray*.0001
 else:raise RuntimeError('Ray traversal exhausted')
 queries+=1
 return (-1 if winding>0 else 1)*max(.002,nearest[3])
def ease(a,b,v):
 t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
def sample_base(p):
 coords=[p[k]/step-lo[k] for k in range(3)];low=[math.floor(v) for v in coords];frac=[coords[k]-low[k] for k in range(3)];value=0
 for dz in range(2):
  for dy in range(2):
   for dx in range(2):
    ix,iy,iz=[min(hi[k]-lo[k],max(0,low[k]+d)) for k,d in enumerate((dx,dy,dz))]
    w=math.prod(frac[k] if d else 1-frac[k] for k,d in enumerate((dx,dy,dz)))
    value+=base[(iz*ny+iy)*nx+ix]*w
 return value
records=[];changed=0
for iz in range(nz):
 z=(lo[2]+iz)*step
 for ix in range(nx):
  x=(lo[0]+ix)*step
  w=ease(-22,-20.5,x)*(1-ease(-10,-8,x))*ease(-3,-1,z)*(1-ease(7.5,9,z))
  for iy in range(ny):
   y=(lo[1]+iy)*step;index=(iz*ny+iy)*nx+ix;old=original[index];value=old
   if w>0 and y<(3.5 if VERSION=='v1' else 3.75):
    p=Vector((x,y,z));a=sample_base(p+O*1.1);b=signed(tree,p)
    # Local smooth solid union only at contact, not a front-return curve.
    radius=.3*(1-ease(2.8,3.4,y)) if VERSION=='v2' else .3
    if radius>1e-6:
     t=max(0,min(1,.5+.5*(b-a)/radius));candidate=b*(1-t)+a*t-radius*t*(1-t)
    else:candidate=min(a,b)
    for solid,lower,upper in outcrops:
     if all(lower[k]-.5<=p[k]<=upper[k]+.5 for k in range(3)):candidate=min(candidate,signed(solid,p))
    value=round(old*(1-w)+max(-.5,min(.5,candidate))*w,5)
    if abs(value)<.002:value=.002 if value>=0 else -.002
   if value!=old:changed+=1
   if abs(value-base[index])>1e-6:records.append({'x':lo[0]+ix,'y':lo[1]+iy,'z':lo[2]+iz,'density':value})
payload['rocks']=records;save=OUT/f'group_volume_{VERSION}.json';save.write_text(json.dumps(payload,separators=(',',':'))+'\n')
report={'samples':len(records),'changed_complete_nodes':changed,'source_state':source_state,'scale':scale,'yaw_degrees':10,'pitch_degrees':45 if VERSION=='v2' else 0,'cap_front_y':cap_front_y,'origin':list(origin),'world_lo':world_lo,'world_hi':world_hi,'queries':queries,'outcrop_solids':len(outcrops),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'input_save_sha256':hashlib.sha256((COMPLETE/'rendered_body_complete.json').read_bytes()).hexdigest(),'save_sha256':hashlib.sha256(save.read_bytes()).hexdigest(),'closed_glb_sha256':hashlib.sha256((OUT/f'closed_source{suffix}.glb').read_bytes()).hexdigest(),'stage':'Unaccepted local 3D-volume study, not a runtime source/model replacement. Single-ray classification requires independent consistency checks before trusting solid conversion.','operation':'Close one existing scan boundary onto an inboard back plane, clip source atZ4.8, triangulate/recalculate closed winding. Uniform1.1 scale, rigid10degree yaw. Local full3D solid union with canonical core sampled1.1m inboard; .3m contact smoothing. Existing complete-source high outcrop solids retained. Original cells unchanged; no source-front extrusion or return profile.'}
report['operation']+=(' Preserve all densityY>=3.5.' if VERSION=='v1' else ' First rigidly pitch the scan45degrees, turning its flared terrestrial base inward. Fit actual source cap intersection to retained cap center. Recompute capY3.5 density; preserveY>=3.75. Fade contact smoothing to zero at grade to avoid a raised union cap.')
(OUT/f'report_{VERSION}.json').write_text(json.dumps(report,indent=2)+'\n');print('CLIFF GROUP VOLUME:',json.dumps(report))
