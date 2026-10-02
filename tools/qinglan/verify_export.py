"""Re-import the runtime GLB and verify deformation data and finite posed geometry."""
import bpy,json,math
from pathlib import Path
root=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'assets/characters/qinglan/qinglan_candidate.glb'))
rigs=[o for o in bpy.data.objects if o.type=='ARMATURE'];assert len(rigs)==1
meshes=[o for o in bpy.data.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
assert len(meshes)==10
expected={'idle','walk','attack_1','attack_2','dodge'}
assert {a.name for a in bpy.data.actions}>=expected
assert all(v.groups for o in meshes for v in o.data.vertices)
assert not any('Boot' in o.name or 'Shoe' in o.name for o in meshes)
rig=rigs[0];samples=0
for track in rig.animation_data.nla_tracks:track.mute=True
for action in bpy.data.actions:
 if action.name not in expected:continue
 rig.animation_data.action=action
 for fraction in [0,.25,.5,.75,1]:
  bpy.context.scene.frame_set(int(action.frame_range[0]+fraction*(action.frame_range[1]-action.frame_range[0])))
  for o in meshes:
   ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
   assert all(math.isfinite(value) and abs(value)<3 for v in ev.data.vertices for value in v.co)
  samples+=1
report={'roundtrip_import':'passed','mesh_objects':len(meshes),'bones':len(rig.data.bones),'actions':sorted(expected),'unweighted_vertices':0,'pose_samples':samples,'visual_acceptance':'demo_candidate','remaining':['袖口及衣领局部网格仍待正式资产精修','动作是基础骨骼动画，无完整布料物理和脚底IK','目前纯色材质，无高模法线烘焙']}
(root/'art/review/qinglan/roundtrip_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False))
