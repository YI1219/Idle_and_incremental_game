"""Measure bone alignment and foot soles in the exported turn workfile, without benchmarking."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).parent))
from turn_source import ROOT,CONVERT,read_asf,read_amc,pose,unwrapped
from turn_retarget import MAPPING
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/work/turn_motion/turn_motion.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=bpy.data.objects['Body']
for t in rig.animation_data.nla_tracks:t.mute=True
report={};bones=read_asf();metadata=json.loads((ROOT/'assets/characters/qinglan/turn_motion.json').read_text())
feet={s:[v.index for v in body.data.vertices if v.co.z<.105 and (v.co.x>0)==(s=='L')] for s in ['L','R']}
for name,clip in metadata['clips'].items():
 frames=read_amc(clip['source_trial']);ys=unwrapped(frames);rig.animation_data.action=bpy.data.actions[name]
 angles=[];heights=[]
 for i,row in enumerate(clip['root_curve']):
  bpy.context.scene.frame_set(i);bpy.context.view_layer.update()
  si=clip['source_frames_inclusive'][0]-1+i*4
  rotations,positions=pose(bones,frames[si]);remove=Matrix.Rotation(-ys[si],3,'Z')
  for n,sn in MAPPING.items():
   if sn=='root':continue
   if clip['mirrored'] and '.' in n:sn=MAPPING[n[:-1]+('R' if n[-1]=='L' else 'L')]
   expected=remove@rotations[sn]@CONVERT@bones[sn]['direction']
   if clip['mirrored']:expected.x=-expected.x
   actual=rig.pose.bones[n].tail-rig.pose.bones[n].head
   angles.append(actual.angle(expected)*180/math.pi)
  evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
  mesh=evaluated.to_mesh()
  heights.append({s:min((evaluated.matrix_world@mesh.vertices[v].co).z for v in ids) for s,ids in feet.items()})
  evaluated.to_mesh_clear()
 report[name]={'source_direction_alignment_max_error_deg':max(angles),'source_direction_alignment_average_error_deg':sum(angles)/len(angles),'left_sole_z_range':[min(h['L'] for h in heights),max(h['L'] for h in heights)],'right_sole_z_range':[min(h['R'] for h in heights),max(h['R'] for h in heights)],'support_sole_max_z':max(min(h.values()) for h in heights),'foot_samples':heights}
(ROOT/'art/review/turn_motion/verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({n:{k:v for k,v in r.items() if k!='foot_samples'} for n,r in report.items()},indent=2))
