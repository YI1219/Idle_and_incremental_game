"""Fit the archived Tripo robe to the measured Qinglan body, keeping ribbons separate."""
import bpy,bmesh,math,hashlib
from mathutils import Vector

def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)

def assign_panels(o):
 """Follow mesh creases instead of painting arbitrary coordinate stripes."""
 bm=bmesh.new();bm.from_mesh(o.data);seen=set();regions=[]
 for face in bm.faces:
  if face in seen:continue
  stack=[face];seen.add(face);region=[]
  while stack:
   f=stack.pop();region.append(f)
   for edge in f.edges:
    if len(edge.link_faces)!=2:continue
    g=edge.link_faces[0] if edge.link_faces[1]==f else edge.link_faces[1]
    if g not in seen and f.normal.dot(g.normal)>math.cos(math.radians(40)):
     seen.add(g);stack.append(g)
  regions.append(region)
 for fs in regions:
  centers=[f.calc_center_median() for f in fs]
  lower=min(p.z for p in centers);upper=max(p.z for p in centers)
  min_y=min(p.y for p in centers);max_y=max(p.y for p in centers)
  # The inner chest and skirt panels are crease-bounded islands in this source.
  chest=len(fs)>80 and lower>.26 and min_y>-.08 and max_y<.08
  skirt=len(fs)>80 and lower<-.4 and upper<.21 and min_y>-.18 and max_y<.14
  for f in fs:f.material_index=1 if chest or skirt else 0
 # Keep inner garment and outer coat as separate surfaces along the actual crease.
 bmesh.ops.split_edges(bm,edges=[e for e in bm.edges if len(e.link_faces)==2 and e.link_faces[0].material_index!=e.link_faces[1].material_index])
 bm.to_mesh(o.data);bm.free()

def fit_clothes(path,mats,S,report):
 from build_asset import active,stats,recalc
 old=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(path))
 o=next(o for o in bpy.data.objects if o not in old and o.type=='MESH');active(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 report['clothes_source_sha256']=hashlib.sha256(path.read_bytes()).hexdigest();report['clothes_before']=stats(o)
 # Separate existing disconnected pieces; keep belt details and ribbons rather than removing them as debris.
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
 pieces=sorted([p for p in bpy.data.objects if p not in old and p.type=='MESH'],key=lambda p:len(p.data.vertices),reverse=True)
 result=[]
 for index,o in enumerate(pieces):
  ribbon=index in [1,2];o.name='Robe' if index==0 else ('Ribbon.'+str(index) if ribbon else 'BeltDetail.'+str(index))
  o.data.materials.clear()
  for n in ['robe','ivory','teal']:o.data.materials.append(mats[n])
  if index==0:assign_panels(o)
  raw={v.index:v.co.copy() for v in o.data.vertices}
  inner_vertices={i for f in o.data.polygons if f.material_index==1 for i in f.vertices}
  for f in o.data.polygons:
   if index>0:f.material_index=2
   f.use_smooth=True
  sleeve=o.vertex_groups.new(name="__Sleeve")
  if index==0:
   adjacency={v.index:set() for v in o.data.vertices}
   for e in o.data.edges:
    a,b=e.vertices;adjacency[a].add(b);adjacency[b].add(a)
   weights={};pins={}
   for i,p in raw.items():
    lateral=abs(p.y)
    if lateral<.12 or p.z<-.06:pins[i]=0.
    elif (lateral>.35 and p.z>-.025) or (lateral>.24 and p.z>.20):pins[i]=1.
    weights[i]=pins.get(i,.5)
   for _ in range(160):
    weights={i:pins[i] if i in pins else sum(weights[j] for j in neighbors)/max(1,len(neighbors)) for i,neighbors in adjacency.items()}
   for i,w in weights.items():sleeve.add([i],w,'REPLACE')
  for v in o.data.vertices:
   p=raw[v.index];a=abs(p.y)
   z=.56+(p.z-.23)*(.85 if p.z>.23 else .507)
   x=p.y*.72;depth=(p.x-.115)*.85
   if index==0 and v.index in inner_vertices and p.z<.24:
    depth+=.035*smooth(.0,.045,depth)*smooth(.12,.30,z)*(1-smooth(.54,.60,z))
   if index==0:
    w=smooth(.12,.48,a)*smooth(-.035,.04,p.z)
    x+=(1 if x>=0 else -1)*.072*w
    z+=max(0,-.0195+.3495*a)*smooth(.08,.16,a)*smooth(-.03,.03,p.z)
    z+=.032*smooth(.24,.34,p.z)
    if a>.43 and p.z>-.025:
     blend=smooth(.43,.476,a)
     theta=math.atan2((p.z-.14)/.139,(p.x-.075)/.097)
     x=(1-blend)*x+blend*(1 if x>=0 else -1)*.415
     depth=(1-blend)*depth+blend*(-.015+.058*math.cos(theta))
     z=(1-blend)*z+blend*(.669+.108*math.sin(theta))
   if index==0:
    # The generated T-pose sleeves hang too far below the arm: when lowered,
    # that excess rotates through the abdomen. Tailor the sleeve opening before skinning.
    influence=weights[v.index]
    z=z*(1-influence)+(.74+(z-.74)*.48)*influence
   v.co=Vector((x,-depth,z))*S
  recalc(o)
  active(o)
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001*S)
  bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001*S)
  bmesh.ops.split_edges(bm,edges=[e for e in bm.edges if len(e.link_faces)>2])
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
  mod=o.modifiers.new('ClothThickness','SOLIDIFY');mod.thickness=.0015*S;mod.offset=-1;mod.use_even_offset=False;mod.material_offset=0
  bpy.ops.object.modifier_apply(modifier=mod.name)
  result.append(o)
 report['clothes_fitting']={'collar_z':.7895*S,'waist_z':.56*S,'hem_z':.1901*S,'sleeve_extension':.072*S,'sleeve_lift':.13*S,'thickness':.0015*S,'retained_pieces':len(result)}
 return result
