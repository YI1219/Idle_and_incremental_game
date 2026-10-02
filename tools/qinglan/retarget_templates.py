"""Retarget licensed Quaternius animation, preserving authored primary body mechanics.

Original Qinglan meshes/materials/rest joints and downloaded files remain untouched.
World-rest corrections transfer rotation across the rigs' different bone axes.
"""
import bpy,json,math,hashlib,struct
from pathlib import Path
from mathutils import Vector,Quaternion
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/source/third_party/quaternius_animation/2026-09-20/original/Universal Animation Library[Standard]/Unreal-Godot'
SOURCE2=ROOT/'art/source/third_party/quaternius_animation_2/2026-09-20/original/Universal Animation Library 2[Standard]/Unreal-Godot'
MAPPING={'Root':'root','Hips':'pelvis','Spine':'spine_01','Chest':'spine_03','Neck':'neck_01','Head':'Head'}
for side,src in [('L','l'),('R','r')]:
 for target,original in [('UpperArm','upperarm'),('Forearm','lowerarm'),('Hand','hand'),('Thigh','thigh'),('Shin','calf'),('Foot','foot')]:
  MAPPING[target+'.'+side]=original+'_'+src
CLIPS={'idle':'Idle_Loop','walk':'Walk_Loop','formal_walk':'Walk_Formal_Loop','jog':'Jog_Fwd_Loop','run':'Sprint_Loop','armed_idle':'Sword_Idle','attack_1':'Sword_Attack'}

def source_speed(name,scale):
 blob=(SOURCE/'UAL1_Standard_RM.glb').read_bytes();n=struct.unpack_from('<I',blob,12)[0];doc=json.loads(blob[20:20+n]);buffer=blob[28+n:]
 def values(index):
  a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];width=3 if a['type']=='VEC3' else 1;start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',width*4)
  return [struct.unpack_from('<'+'f'*width,buffer,start+i*stride) for i in range(a['count'])]
 animation=next(a for a in doc['animations'] if a['name']==name)
 for ch in animation['channels']:
  if doc['nodes'][ch['target']['node']].get('name')=='root' and ch['target']['path']=='translation':
   sample=animation['samplers'][ch['sampler']];points=values(sample['output']);times=values(sample['input']);d=Vector(points[-1])-Vector(points[0]);duration=times[-1][0]-times[0][0]
   return d.length*scale/max(duration,.001)
 return 0.0

def main():
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/work/qinglan/qinglan_candidate.blend'))
 target=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 target.animation_data_clear()
 for action in list(bpy.data.actions):bpy.data.actions.remove(action)
 owned=set(bpy.data.objects)
 bpy.context.scene.render.fps=30
 bpy.ops.import_scene.gltf(filepath=str(SOURCE/'UAL1_Standard.glb'))
 imported=set(bpy.data.objects)-owned
 source=next(o for o in imported if o.type=='ARMATURE')
 for track in source.animation_data.nla_tracks:track.mute=True
 actions={name:bpy.data.actions[name] for name in CLIPS.values()}
 source_rest={n:source.data.bones[n].matrix_local.copy() for n in MAPPING.values()}
 target_rest={n:target.data.bones[n].matrix_local.copy() for n in MAPPING}
 scale=(target.data.bones['Thigh.L'].length+target.data.bones['Shin.L'].length)/(source.data.bones['thigh_l'].length+source.data.bones['calf_l'].length)
 report={'source_file':str(SOURCE.relative_to(ROOT)/'UAL1_Standard.glb'),'source_sha256':hashlib.sha256((SOURCE/'UAL1_Standard.glb').read_bytes()).hexdigest(),'license':'CC0 1.0 Universal','mapping':MAPPING,'motion_scale':scale,'clips':{},'method':'world-rest rotation correction; scaled pelvis translation; original timing; garment-only secondary response','visual_acceptance':'pending'}
 first_source=source
 first_rest=source_rest
 first_actions=actions
 old_imported=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(SOURCE2/'UAL2_Standard.glb'))
 second_imported=set(bpy.data.objects)-old_imported
 imported |= second_imported
 second_source=next(o for o in second_imported if o.type=='ARMATURE')
 for track in second_source.animation_data.nla_tracks:track.mute=True
 second_rest={n:second_source.data.bones[n].matrix_local.copy() for n in MAPPING.values()}
 second_clips={'attack_1':['Sword_Regular_A','Sword_Regular_A_Rec'],'counter':['Sword_Block'],'dodge':['Sword_Dash'],'dodge_recovery':['Sword_Dash']}
 specifications={clip:[original] for clip,original in CLIPS.items() if clip!='attack_1'}
 specifications.update(second_clips)
 for clip,originals in specifications.items():
  is_second=clip in second_clips
  source=second_source if is_second else first_source
  source_rest=second_rest if is_second else first_rest
  frames=[]
  for original in originals:
   action_source=bpy.data.actions[original]
   start,end=action_source.frame_range
   for at in range(round(start)+(30 if clip=='dodge_recovery' else 1 if frames else 0),round(end)+1):frames.append((action_source,at))
  count=len(frames)-1
  target.animation_data_create()
  cloth_angles={'L':0.0,'R':0.0}
  loop=clip in ['idle','walk','formal_walk','jog','run','armed_idle']
  # Warm the cloth response through one complete preceding cycle before baking.
  for frame in range(-count if loop else 0,count+1):
   sample=frame % count if frame < 0 else frame
   source.animation_data.action=frames[sample][0]
   bpy.context.scene.frame_set(frames[sample][1])
   for pb in target.pose.bones:
    pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion();pb.location=(0,0,0);pb.scale=(1,1,1)
   bpy.context.view_layer.update()
   for name,source_name in MAPPING.items():
    pb=target.pose.bones[name]
    desired=source.pose.bones[source_name].matrix.to_quaternion() @ source_rest[source_name].to_quaternion().inverted() @ target_rest[name].to_quaternion()
    rest_local=(pb.parent.bone.matrix_local.inverted() @ pb.bone.matrix_local) if pb.parent else pb.bone.matrix_local
    basis=(pb.parent.matrix @ rest_local) if pb.parent else rest_local
    pb.rotation_quaternion=basis.to_quaternion().inverted() @ desired
    if name=='Hips':
     hip=target_rest[name].translation+(source.pose.bones[source_name].matrix.translation-source_rest[source_name].translation)*scale
     pb.location=basis.inverted() @ hip
    bpy.context.view_layer.update()
   # Garment response only; no synthetic curves are applied to any humanoid joint.
   for side in ['L','R']:
    bend=target.pose.bones['Thigh.'+side].rotation_quaternion.to_euler('XYZ').x
    cloth_angles[side]=cloth_angles[side]*.58+bend*.42
    pb=target.pose.bones['Skirt.'+side]
    pb.rotation_quaternion=Quaternion((1,0,0),cloth_angles[side]*.35)
   target.pose.bones['Skirt.Front'].rotation_quaternion=Quaternion((1,0,0),min(cloth_angles.values())*.43)
   target.pose.bones['Skirt.Back'].rotation_quaternion=Quaternion((1,0,0),max(cloth_angles.values())*.43)
   for pb in target.pose.bones:
    if pb.name.startswith('Ribbon.'):
     i=int(pb.name.rsplit('.',1)[1]);angle=(-.34 if i==0 else -.1 if i==1 else .04)
     pb.rotation_quaternion=Quaternion((1,0,0),angle)
    if frame < 0:continue
    pb.keyframe_insert('rotation_quaternion',frame=frame,group=pb.name)
    if pb.name=='Hips':pb.keyframe_insert('location',frame=frame,group=pb.name)
  action=target.animation_data.action;action.name=clip;action.use_fake_user=True
  track=target.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,0,action);track.mute=True
  target.animation_data.action=None
  report['clips'][clip]={'source_animations':originals,'source_library':2 if is_second else 1,'source_start_seconds':1.0 if clip=='dodge_recovery' else 0.0,'seconds':count/30,'native_travel_speed':source_speed(originals[0],scale) if not is_second else 0.0,'source_timing_preserved':True}
 report['second_source_file']=str((SOURCE2/'UAL2_Standard.glb').relative_to(ROOT))
 report['second_source_sha256']=hashlib.sha256((SOURCE2/'UAL2_Standard.glb').read_bytes()).hexdigest()
 for o in imported:bpy.data.objects.remove(o,do_unlink=True)
 for a in actions.values():
  if a.users==0:bpy.data.actions.remove(a)
 for track in target.animation_data.nla_tracks:track.mute=False
 bpy.context.scene.frame_set(0)
 bpy.context.scene.frame_end=75
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/work/qinglan/qinglan_template_v03.blend'))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/qinglan/qinglan_template_v03.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True)
 (ROOT/'assets/characters/qinglan/template_motion.json').write_text(json.dumps(report,indent=2)+'\n')
 (ROOT/'assets/characters/qinglan/template_motion.gd').write_text('extends RefCounted\n## Generated from the licensed source clips; do not hand-tune cadence here.\nconst LOOPS = ["idle","walk","formal_walk","jog","run","armed_idle"]\nconst CLIPS = '+json.dumps(report['clips'],indent=2)+'\n')
 (ROOT/'art/review/animation_template/retarget.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
if __name__=='__main__':main()
