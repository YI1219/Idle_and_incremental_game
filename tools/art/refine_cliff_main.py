"""Blender: refine retained CC0 Rock_Medium_1/2 sources, never its original.

Run: blender --factory-startup --background --python tools/art/refine_cliff_main.py
Only the selected existing cliff task is authorized for Codex Blender operation.
"""
import bpy,bmesh,json,hashlib,sys
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
VERSION=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'v4'
assert VERSION in ['v1','v2','v3','v4','v5','v6','v7','v8','tall_v1','tall_v2'], 'Select a recorded refinement variant'
TALL=VERSION.startswith('tall_')
STEM='cliff_'+VERSION if TALL else 'cliff_main_'+VERSION
SOURCE=ROOT/('assets/nature/quaternius/Rock_Medium_1.gltf' if TALL else 'assets/nature/quaternius/Rock_Medium_2.gltf')
OUT=ROOT/'art/work/cliff_refinement/2026-10-15/output'
REVIEW=ROOT/'art/review/terrain_fidelity/2026-10-15/cliff_refinement'
OUT.mkdir(parents=True,exist_ok=True)
original_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(objects)==1, 'Inspect unfamiliar multi-part source before proceeding'
obj=objects[0];bpy.context.view_layer.objects.active=obj;obj.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
original_vertices=len(obj.data.vertices);original_triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
bm=bmesh.new();bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
# Remove only triangulation diagonals on the source's truly coplanar faces.
bmesh.ops.dissolve_limit(bm,angle_limit=.002,verts=list(bm.verts),edges=list(bm.edges),delimit=set())
if VERSION in ['v4','v5','v6','v7','v8','tall_v1']:
 # The retained source has thin inward knife folds. Repair its outer skin
 # from its own silhouette vertices before adding broad geological turns.
 source_points=[v.co.copy() for v in bm.verts]
 bm.free();bm=bmesh.new()
 for point in source_points:bm.verts.new(point)
 hull=bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
 unused=[v for v in bm.verts if not v.link_faces]
 if unused:bmesh.ops.delete(bm,geom=unused,context='VERTS')
low=Vector(tuple(min(v.co[k] for v in bm.verts) for k in range(3)))
high=Vector(tuple(max(v.co[k] for v in bm.verts) for k in range(3)))
size=high-low;center=(low+high)*.5
# Three unequal local shoulders. Oblique cuts give each wall usable middle
# scale geometry; directional weighting keeps them from forming global rings.
features=[
 {'direction':Vector((-.65,-.76)), 'a':.10,'b':-.07,
  'profile':[(0,-.015),(.14,.005),(.27,.070),(.32,-.022),(.60,-.012),(1,0)]},
 {'direction':Vector((.90,-.44)), 'a':-.08,'b':.12,
  'profile':[(0,0),(.32,.010),(.50,.060),(.56,-.030),(1,.010)]},
 {'direction':Vector((.08,.997)), 'a':.13,'b':.05,
  'profile':[(0,0),(.54,.004),(.70,.045),(.75,-.025),(1,.008)]},
]
if VERSION=='v2':
 for feature in features:
  feature['profile']=[p for p in feature['profile'] if p[0] not in [.14,.60,.32,.54] or (feature is features[0] and p[0]==.32)]
  feature['profile']=[(h,amount*.62) for h,amount in feature['profile']]
if VERSION in ['v3','v4','v5','v6','v7','v8'] or TALL:
 features[0]['profile']=[(0,-.008),(.23,.052),(.48,-.016),(1,0)]
 features[1]['profile']=[(0,0),(.43,.050),(.69,-.020),(1,.006)]
 features[2]['profile']=[(0,0),(.62,.042),(.89,-.012),(1,.006)]
if TALL:
 features[0].update(a=.30,b=-.20,profile=[(0,-.005),(.22,.055),(.50,-.018),(1,0)])
 features[1].update(a=-.27,b=.25,profile=[(0,0),(.40,.072),(.72,-.018),(1,.008)])
 features[2].update(a=.22,b=.15,profile=[(0,0),(.65,.050),(.92,-.008),(1,0)])
if VERSION=='tall_v2':
 features[0]['profile']=[(0,0),(.27,.028),(.64,-.006),(1,0)]
 features[1]['profile']=[(0,0),(.42,.035),(.78,-.008),(1,0)]
 features[2]['profile']=[(0,0),(.64,.025),(.93,-.005),(1,0)]
for feature in features:
 for h,_ in feature['profile'][1:-1]:
  normal=Vector((feature['a']/size.x,feature['b']/size.y,1/size.z)).normalized()
  point=Vector((center.x,center.y,low.z+size.z*h))
  bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_co=point,plane_no=normal,clear_inner=False,clear_outer=False)
def smoothstep(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def profile(points,t):
 if t<=points[0][0]:return points[0][1]
 for (a,x),(b,y) in zip(points,points[1:]):
  if t<=b:return x+(y-x)*(t-a)/(b-a)
 return points[-1][1]
for vertex in bm.verts:
 p=vertex.co.copy();u=(p.x-center.x)/size.x;v=(p.y-center.y)/size.y;h=(p.z-low.z)/size.z
 radial=Vector((u,v));radial.normalize()
 shift=Vector((0,0,0))
 for feature in features:
  weight=smoothstep(.35 if VERSION in ['v3','v4','v5','v6','v7','v8'] or TALL else .02,.95 if VERSION in ['v3','v4','v5','v6','v7','v8'] or TALL else .88,radial.dot(feature['direction']))
  level=h+feature['a']*u+feature['b']*v
  amount=profile(feature['profile'],level)*weight
  shift.x+=feature['direction'].x*size.x*amount
  shift.y+=feature['direction'].y*size.y*amount
 # Keep the top asymmetrical without rounding away geological corners.
 shift.z+=size.z*(.040*u-.025*v)*smoothstep(.76,1,h)
 vertex.co=p+shift
if VERSION in ['v7','v8']:
 # Carve broad oblique corner planes into the retained skin instead of
 # pinching vertices into narrow folds. A closed filled cut is real stone.
 cuts=[((.72,-.58,.22),.055),((-.60,-.80,-.24),.075),((.12,.98,.10),.045)] if VERSION=='v7' else [((.72,-.58,-.80),.15),((-.60,-.80,-1.1),.12),((.12,.98,-.6),.10)]
 for normal_raw,depth in cuts:
  n=Vector(normal_raw).normalized()
  limit=max(n.dot(Vector(((v.co.x-center.x)/size.x,(v.co.y-center.y)/size.y,(v.co.z-center.z)/size.z))) for v in bm.verts)-depth
  if VERSION=='v8':
   # Preserve the cap and all upper side faces. A smaller cut cap would be
   # normalized wider by the runtime crown builder, making a new lower spear.
   protected=[]
   plane_z=low.z+size.z*.55
   for v in bm.verts:
    if v.co.z>=plane_z:protected.append(v.co.copy())
   for edge in bm.edges:
    a,b=[v.co for v in edge.verts]
    if (a.z-plane_z)*(b.z-plane_z)<0:protected.append(a.lerp(b,(plane_z-a.z)/(b.z-a.z)))
   limit=max(limit,max(n.dot(Vector(((p.x-center.x)/size.x,(p.y-center.y)/size.y,(p.z-center.z)/size.z))) for p in protected)+.002)
  normal=Vector((n.x/size.x,n.y/size.y,n.z/size.z))
  point=center+normal*(limit/normal.length_squared)
  bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_co=point,plane_no=normal,clear_inner=False,clear_outer=True)
  boundary=[e for e in bm.edges if e.is_boundary]
  if boundary:bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
if VERSION in ['v5','v6']:
 # Unequal oblique vertical shoulders divide the long source faces. They
 # continue through the dry cap as actual silhouette turns, not painted seams.
 # Each side gets one broad asymmetric turn; no concentric band or rubble.
 turns=[
  (Vector((-.65,-.76)), -.11, .16, .075, -.13, .19),
  (Vector((.90,-.44)), .16, -.22, .058, -.20, .12),
  (Vector((.08,.997)), -.03, .11, .065, -.12, .24),
 ]
 if VERSION=='v6':turns=[(d,o,t,a*1.65,l,r) for d,o,t,a,l,r in turns]
 for direction,offset,tilt,amount,left,right in turns:
  across=Vector((-direction.y,direction.x))
  for knot in [offset+left,offset,offset+right]:
   normal=Vector((across.x/size.x,across.y/size.y,tilt/size.z))
   point=center+Vector((0,0,size.z*knot/tilt))
   bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_co=point,plane_no=normal,clear_inner=False,clear_outer=False)
 for vertex in bm.verts:
  p=vertex.co.copy();u=(p.x-center.x)/size.x;v=(p.y-center.y)/size.y;h=(p.z-center.z)/size.z
  radial=Vector((u,v));radial.normalize()
  shift=Vector((0,0,0))
  for direction,offset,tilt,amount,left,right in turns:
   across=Vector((-direction.y,direction.x))
   t=across.dot(Vector((u,v)))+tilt*h
   turn=profile([(-2,0),(offset+left,0),(offset,-amount),(offset+right,amount*.28),(2,0)],t)
   weight=smoothstep(.25,.90,radial.dot(direction))
   shift.x+=direction.x*size.x*turn*weight
   shift.y+=direction.y*size.y*turn*weight
  vertex.co+=shift
if VERSION in ['v2','v3','v4','v5','v6','v7','v8'] or TALL:
 # Collapse very short section intersections before triangulation/export.
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.012)
 bmesh.ops.dissolve_degenerate(bm,dist=.003,edges=list(bm.edges))
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
if VERSION in ['v5','v6','v7']:
 # Crossing cuts can leave thin ears. Collapse their shortest edge on the
 # retained skin so Godot's normal mesh builder does not discard a tiny face.
 for cleanup in range(8):
  tiny=[f for f in bm.faces if f.calc_area()<.0003]
  if not tiny:break
  edges=set(min(f.edges,key=lambda e:e.calc_length()) for f in tiny)
  bmesh.ops.collapse(bm,edges=list(edges),uvs=False)
  bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.normal_update()
nonmanifold=sum(not e.is_manifold for e in bm.edges)
degenerate=sum(f.calc_area()<1e-10 for f in bm.faces)
volume=bm.calc_volume(signed=True)
assert nonmanifold==0 and degenerate==0 and volume>0, (nonmanifold,degenerate,volume)
triangles=len(bm.faces)
bm.to_mesh(obj.data);bm.free();obj.data.update();obj.name='Cliff_Main_Refined_'+VERSION
for polygon in obj.data.polygons:polygon.use_smooth=False
obj.data.materials.clear();material=bpy.data.materials.new('Neutral_Inspection');material.diffuse_color=(.55,.56,.54,1);material.use_nodes=True
bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(.55,.56,.54,1);bsdf.inputs['Roughness'].default_value=.9
obj.data.materials.append(material)
# Mesh/work source is retained; no camera/lights are baked into the GLB.
blend=OUT/(STEM+'.blend');glb=OUT/(STEM+'.glb')
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_materials='EXPORT',export_animations=False,export_cameras=False,export_lights=False)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==original_hash
report={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':original_hash,'source_vertices':original_vertices,'source_triangles':original_triangles,'refined_triangles':triangles,'nonmanifold_edges':nonmanifold,'degenerate_faces':degenerate,'signed_volume':volume,'blend':str(blend.relative_to(ROOT)),'glb':str(glb.relative_to(ROOT)),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'blender_version':bpy.app.version_string,'variant':VERSION,'operation':('Convex outer-skin reconstruction from retained source silhouette vertices repairs inherited inward knife folds; ' if VERSION in ['v4','v5','v6','v7','v8','tall_v1'] else '')+'Retained-source coplanar diagonal dissolve, oblique sectional cuts and three local directional shoulder profiles. '+('Three asymmetric oblique vertical turns and shortest-edge cleanup of tiny faces. ' if VERSION in ['v5','v6'] else 'Three closed broad corner cuts; '+('protect upper .55 height region from cuts. ' if VERSION=='v8' else '') if VERSION in ['v7','v8'] else '')+'No disconnected rubble or texture generation.','vertical_turns':VERSION in ['v5','v6'],'corner_plane_cuts':VERSION in ['v7','v8'],'protected_cap':VERSION=='v8','authorization':'User explicitly authorized Codex model-tool operation on 2026-10-15.'}
(REVIEW/(('refined_'+VERSION if TALL else 'refined_main_'+VERSION)+'.json')).write_text(json.dumps(report,indent=2)+'\n')
print('REFINED MAIN CLIFF:',json.dumps(report))
