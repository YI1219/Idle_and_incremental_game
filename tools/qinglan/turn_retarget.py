"""Retarget CMU captured turn steps to Qinglan; separate actor root motion for collision."""
import bpy,sys,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
sys.path.insert(0,str(Path(__file__).parent))
from turn_source import ROOT,SOURCE,CONVERT,read_asf,read_amc,pose,unwrapped
OUT=ROOT/'art/work/turn_motion'
MAPPING={'Hips':'root','Spine':'lowerback','Chest':'thorax','Neck':'upperneck','Head':'head'}
for side,prefix in [('L','l'),('R','r')]:
 for target,source in [('UpperArm','humerus'),('Forearm','radius'),('Hand','hand'),('Thigh','femur'),('Shin','tibia'),('Foot','foot')]:MAPPING[target+'.'+side]=prefix+source
REFLECTION=Matrix.Diagonal(Vector((-1,1,1)))

def main():
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/work/qinglan/qinglan_clothed_v04.blend'))
 target=next(o for o in bpy.data.objects if o.type=='ARMATURE');target.animation_data_clear()
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 bones=read_asf();rest={n:b.matrix_local.copy() for n,b in target.data.bones.items()}
 scale=(target.data.bones['Thigh.L'].length+target.data.bones['Shin.L'].length)/(bones['lfemur']['length']+bones['ltibia']['length'])
 scene=bpy.context.scene;scene.render.fps=30
 body=bpy.data.objects['Body'];foot_vertices=[v.index for v in body.data.vertices if v.co.z<.105]
 foot_sides={side:[v.index for v in body.data.vertices if v.co.z<.105 and (v.co.x>0)==(side=='L')] for side in ['L','R']}
 specs={'turn_left_180':('69_13',432,624,False),'turn_right_180':('69_13',432,624,True)}
 # Dedicated quarter-turn recordings are bounded around the change of heading.
 if (SOURCE/'69_20.amc').exists() and (SOURCE/'69_24.amc').exists():
  specs.update({'turn_right_90':('69_20',192,348,False),'turn_left_90':('69_24',120,276,False)})
 report={'source':'Carnegie Mellon University Graphics Lab Motion Capture Database','source_url':'http://mocap.cs.cmu.edu/','license':'Free for commercial product inclusion; raw data may not be resold, including converted data.','acknowledgment':'The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.','source_fps':120,'baked_fps':30,'motion_scale':scale,'mapping':MAPPING,'grounding':'Per-frame pelvis-height correction places the lowest bare-foot sole at 3 mm above floor. Captured limb rotations and relative foot lift are retained.','method':'ASF C M C-inverse forward kinematics, captured world orientation with anatomical rest-direction correction, target parent-relative rotation; continuous pelvis heading and ground travel extracted for actor movement. Right 180 is a sagittal mirror with swapped limbs.','clips':{}}
 target.animation_data_create()
 for clip,(trial,start,end,mirror) in specs.items():
  frames=read_amc(trial);ys=unwrapped(frames)
  indices=list(range(start,end+1,4)); yaw0=ys[start];pos0=Vector(frames[start]['root'][:3]); norm=Matrix.Rotation(-yaw0,3,'Y')
  curve=[]; samples=[]; sole_samples=[]
  source_rest={}
  for name,sn in MAPPING.items():
   rq=rest[name].to_quaternion()
   if sn=='root':source_rest[name]=rq;continue
   td=target.data.bones[name].tail_local-target.data.bones[name].head_local
   sd=CONVERT@bones[sn]['direction']
   source_rest[name]=td.normalized().rotation_difference(sd.normalized())@rq
  for output_frame,index in enumerate(indices):
   rotations,positions=pose(bones,frames[index]);heading=ys[index]
   remove_yaw=Matrix.Rotation(-heading,3,'Z')
   for pb in target.pose.bones:
    pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion();pb.location=(0,0,0);pb.scale=(1,1,1)
   bpy.context.view_layer.update()
   for name,sn in MAPPING.items():
    source_name=name
    if mirror and '.' in name:source_name=name[:-1]+('R' if name[-1]=='L' else 'L');sn=MAPPING[source_name]
    rotation=remove_yaw@rotations[sn]
    desired=rotation.to_quaternion()@source_rest[source_name]
    if mirror:desired=(REFLECTION@desired.to_matrix()@REFLECTION).to_quaternion()
    # Mirroring changes local bone axes; reconstruct direction-preserving target orientation.
    if mirror:
     source_rest_m=(REFLECTION@rest[source_name].to_3x3()@REFLECTION).to_quaternion()
     desired=desired@source_rest_m.inverted()@rest[name].to_quaternion()
    pb=target.pose.bones[name]
    local_rest=pb.parent.bone.matrix_local.inverted()@pb.bone.matrix_local if pb.parent else pb.bone.matrix_local
    basis=pb.parent.matrix@local_rest if pb.parent else local_rest
    pb.rotation_quaternion=basis.to_quaternion().inverted()@desired
    if name=='Hips':
     hip=rest[name].translation.copy();hip.z+=(frames[index]['root'][1]-pos0.y)*scale
     pb.location=basis.inverted()@hip
    bpy.context.view_layer.update()
   for side in ['L','R']:
    bend=target.pose.bones['Thigh.'+side].rotation_quaternion.to_euler('XYZ').x
    target.pose.bones['Skirt.'+side].rotation_quaternion=Quaternion((1,0,0),bend*.35)
   bends=[target.pose.bones['Thigh.'+s].rotation_quaternion.to_euler('XYZ').x for s in ['L','R']]
   target.pose.bones['Skirt.Front'].rotation_quaternion=Quaternion((1,0,0),min(bends)*.43)
   target.pose.bones['Skirt.Back'].rotation_quaternion=Quaternion((1,0,0),max(bends)*.43)
   for pb in target.pose.bones:
    if pb.name.startswith('Ribbon.'):
     i=int(pb.name.rsplit('.',1)[1]);pb.rotation_quaternion=Quaternion((1,0,0),[-.34,-.1,.04][i])
    pb.keyframe_insert('rotation_quaternion',frame=output_frame,group=pb.name)
    if pb.name=='Hips':pb.keyframe_insert('location',frame=output_frame,group=pb.name)
   # Retarget proportion correction: keep the lowest visible bare-foot sole on ground.
   # Captured joint rotations and relative foot lift stay unchanged.
   bpy.context.view_layer.update()
   evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get());evaluated_mesh=evaluated.to_mesh()
   sole_z=min((evaluated.matrix_world@evaluated_mesh.vertices[v].co).z for v in foot_vertices)
   sole_samples.append({side:min((evaluated.matrix_world@evaluated_mesh.vertices[v].co).z for v in ids)+.003-sole_z for side,ids in foot_sides.items()})
   evaluated.to_mesh_clear()
   hip_bone=target.pose.bones['Hips']
   hip_basis=hip_bone.parent.matrix@hip_bone.parent.bone.matrix_local.inverted()@hip_bone.bone.matrix_local
   hip_bone.location+=hip_basis.to_3x3().inverted()@Vector((0,0,.003-sole_z))
   hip_bone.keyframe_insert('location',frame=output_frame,group='Hips')
   local=norm@(Vector(frames[index]['root'][:3])-pos0)*scale
   curve.append([round(output_frame/30,6),round((heading-yaw0)*(-1 if mirror else 1),7),round(local.x*(-1 if mirror else 1),7),round(local.z,7)])
   bpy.context.view_layer.update()
   samples.append({n:list(target.pose.bones[n].head) for n in ['Hips','Thigh.L','Thigh.R','Shin.L','Shin.R','Foot.L','Foot.R']})
  action=target.animation_data.action;action.name=clip;action.use_fake_user=True
  track=target.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,0,action);track.mute=True;target.animation_data.action=None
  report['clips'][clip]={'source_trial':trial,'source_url':'http://mocap.cs.cmu.edu/subjects/69/'+trial+'.amc','source_frames_inclusive':[start+1,indices[-1]+1],'seconds':(len(indices)-1)/30,'mirrored':mirror,'yaw_radians':curve[-1][1],'curve_columns':['seconds','yaw_radians','root_x','root_z'],'root_curve':curve,'timing':'Original 120 Hz sampling reduced to 30 Hz without speeding up.'}
  clip_meta=report['clips'][clip]
  clip_meta['foot_curve_columns']=['seconds','left_x','left_y','left_z','right_x','right_y','right_z']
  clip_meta['foot_curve_reference']='Yaw-removed grounded target Foot.L/R bone heads, character-local Godot coordinates (+Z forward); samples at the same times as root_curve. Use sole_height_curve to identify the supporting foot.'
  clip_meta['foot_curve']=[]
  for row,joints in zip(curve,samples):
   left=joints['Foot.L'];right=joints['Foot.R']
   clip_meta['foot_curve'].append([row[0],left[0],left[2],-left[1],right[0],right[2],-right[1]])
  clip_meta['sole_height_curve_columns']=['seconds','left_sole_min_y','right_sole_min_y']
  clip_meta['sole_height_curve']=[[row[0],h['L'],h['R']] for row,h in zip(curve,sole_samples)]
  (OUT/(clip+'_joints.json')).write_text(json.dumps(samples))
 for track in target.animation_data.nla_tracks:track.mute=False
 report['source_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.iterdir() if p.suffix in ['.amc','.asf']}
 (ROOT/'assets/characters/qinglan/turn_motion.json').write_text(json.dumps(report,indent=2)+'\n')
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'turn_motion.blend'))
 bpy.ops.export_scene.gltf(filepath=str(OUT/'turn_motion.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True)
 print('TURN CLIPS',[(n,c['seconds'],c['yaw_radians']) for n,c in report['clips'].items()])
if __name__=='__main__':main()
