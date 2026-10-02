"""v06: refine preserved garment; restore knee hems/calves, add garment-only bends.
Run with Blender --factory-startup -b --python tools/qinglan/refine_garment.py.
"""
from pathlib import Path
import bpy, json, math, sys
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from refine_clothing import set_weights, smooth
from refine_fabric import textile_uv
OUT=ROOT/'art/review/garment_v06'

def snapshot(o):
 return {'vertices':[tuple(v.co) for v in o.data.vertices], 'faces':[tuple(f.vertices) for f in o.data.polygons], 'material':[f.material_index for f in o.data.polygons], 'weights':[{o.vertex_groups[g.group].name:g.weight for g in v.groups if not o.vertex_groups[g.group].name.startswith('__')} for v in o.data.vertices]}

def restore(o,data):
 mats=list(o.data.materials);mesh=bpy.data.meshes.new(o.name+'_v06');mesh.from_pydata(data['vertices'],[],data['faces']);mesh.update();o.data=mesh
 for mat in mats:mesh.materials.append(mat)
 o.vertex_groups.clear()
 for i,w in enumerate(data['weights']):set_weights(o,i,w)
 for f,idx in zip(mesh.polygons,data['material']):f.material_index=idx;f.use_smooth=True

def main():
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/work/qinglan/qinglan_template_v03.blend'))
 original={n:snapshot(bpy.data.objects[n]) for n in ['Body','WhiteTrousers.L','WhiteTrousers.R','Robe']}
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/work/qinglan/qinglan_fabric_v05.blend'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');robe=bpy.data.objects['Robe']
 restore(bpy.data.objects['Body'],original['Body'])
 pants={}
 for side in ['L','R']:
  o=bpy.data.objects['WhiteTrousers.'+side];top=[v.co.copy() for v in list(o.data.vertices)[:48]]
  restore(o,original[o.name])
  for v,p in zip(list(o.data.vertices)[:48],top):v.co=p
  for v in list(o.data.vertices)[:16]:set_weights(o,v.index,{'Hips':1})
  # Ease the source knee hem around the restored skin rather than deleting it.
  ring=list(o.data.vertices)[48:64];center=sum((v.co for v in ring),Vector())/16
  for v in ring:
   v.co.x=center.x+(v.co.x-center.x)*1.10
   v.co.y=center.y+(v.co.y-center.y)*1.10
  textile_uv(o);pants[side]={'hem_z':min(v.co.z for v in o.data.vertices),'vertices':len(o.data.vertices)}
 # Add controls only to the garment. Original rest bones and all actions unchanged.
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
 for side,sign in [('L',1),('R',-1)]:
  b=rig.data.edit_bones.new('Sleeve.'+side);b.head=(sign*.24,.013,.825);b.tail=(sign*.24,.013,.71);b.parent=rig.data.edit_bones['UpperArm.'+side]
  for j in range(2):
   b=rig.data.edit_bones.new(f'Cuff.{side}.{j}');b.head=(sign*.405,.014,.82-j*.055);b.tail=(sign*.405,.014,.765-j*.055)
   b.parent=rig.data.edit_bones['Forearm.'+side if j==0 else f'Cuff.{side}.0']
 for side in ['Front','Back','L','R']:
  base=rig.data.edit_bones['Skirt.'+side];b=rig.data.edit_bones.new('Hem.'+side);b.head=base.head.lerp(base.tail,.62);b.tail=base.tail;b.parent=base
 bpy.ops.object.mode_set(mode='OBJECT')
 counts={'sleeve':0,'hem':0}
 for v,source in zip(robe.data.vertices,original['Robe']['weights']):
  arm=sum(w for n,w in source.items() if n.startswith(('UpperArm.','Forearm.')))
  if arm>.1:
   old={robe.vertex_groups[g.group].name:g.weight for g in v.groups if not robe.vertex_groups[g.group].name.startswith('__')}
   side='L' if v.co.x>=0 else 'R'
   drop=(.837-.055*abs(v.co.x))-v.co.z
   free=.88*smooth(.018,.085,drop)*smooth(.14,.24,abs(v.co.x))*arm
   fore=smooth(.26,.37,abs(v.co.x))
   distal=smooth(.052,.10,drop)
   weights={n:w*(1-free) for n,w in old.items()}
   weights['Sleeve.'+side]=free*(1-fore)
   weights['Cuff.'+side+'.0']=free*fore*(1-distal);weights['Cuff.'+side+'.1']=free*fore*distal
   set_weights(robe,v.index,weights)
   # Take in hanging breadth, keeping the wrist opening and both shell surfaces.
   v.co.y=.012+(v.co.y-.012)*(1-.26*free)
   v.co.z+=.025*free
   counts['sleeve']+=free>.01
  elif v.co.z<.64:
   # The front/rear panel spans BOTH legs. Opposing thigh weights collapse it
   # between them. Restore continuous skirt sectors, and bend only free tips.
   lower=1-smooth(.47,.64,v.co.z)
   x,y,z=v.co; lateral=abs(x)
   front=max(0.,-y+.018);back=max(0.,y-.018)
   sectors={'Front':front**2,'Back':back**2,'L':max(0.,x)**2*.75,'R':max(0.,-x)**2*.75}
   total=sum(sectors.values())
   weights={'Hips':1-lower}
   tip=.65*(1-smooth(.23,.39,z))
   for n,w in sectors.items():
    weights['Skirt.'+n]=lower*w/total*(1-tip);weights['Hem.'+n]=lower*w/total*tip
   # Side panels sit directly beside the calf. Retain local leg support
   # there; central front/back remain continuous envelope-driven panels.
   support=.74*smooth(.065,.145,abs(x))*(1-smooth(.46,.58,z))
   shin=.50*(1-smooth(.23,.37,z))
   weights={n:w*(1-support) for n,w in weights.items()}
   side='L' if x>=0 else 'R'
   weights['Thigh.'+side]=support*(1-shin)
   weights['Shin.'+side]=support*shin
   set_weights(robe,v.index,{n:w for n,w in weights.items() if w>.0001})
   counts['hem']+=1
   # Retain source folds; a little room inside each lower panel, no added mask.
   if z<.44:v.co.y=.018+(y-.018)*(1+.045*(1-smooth(.25,.44,z)))
 robe.data.update()
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/work/qinglan/qinglan_garment_v06.blend'))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/qinglan/qinglan_garment_v06.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True)
 report={'source':'qinglan_fabric_v05.blend','restored_body':{'vertices':len(original['Body']['vertices']),'faces':len(original['Body']['faces']),'additional_mask':False},'trousers':pants,'weights':counts,'new_garment_bones':10,'cloth_solver':False}
 (OUT/'refinement.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
if __name__=='__main__':main()
