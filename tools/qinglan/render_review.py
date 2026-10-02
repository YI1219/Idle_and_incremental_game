"""Render rest/animation review views from an existing character .blend."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
path=Path(args[0]) if args else ROOT/'art/work/qinglan/qinglan_candidate.blend'
out=Path(args[1]) if len(args)>1 else ROOT/'art/review/qinglan';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(path));scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=800;scene.render.resolution_y=950;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
world=bpy.data.worlds.new('ReviewWorld');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.78,.8,.83,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6
for name,loc,power,size in [('Key',(-3,-4,5),450,4),('Fill',(3,1,3),220,3)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.6))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200);ground=bpy.context.object;ground.name='ReviewGround';ground.location.z=-.025
mat=bpy.data.materials.new('ReviewGround');mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.65,.63,.57,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.95;ground.data.materials.append(mat)
d=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',d);scene.collection.objects.link(cam);scene.camera=cam;d.type='ORTHO';d.ortho_scale=1.43
rig=next((o for o in bpy.data.objects if o.type=='ARMATURE'),None)
def render(name,loc,anim=None,frame=0):
 if rig:
  if rig.animation_data:
   for t in rig.animation_data.nla_tracks:t.mute=True
   rig.animation_data.action=bpy.data.actions.get(anim) if anim else None
  for pb in rig.pose.bones:pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
  scene.frame_set(frame)
 cam.location=Vector(loc)+Vector((0,0,.55));cam.rotation_euler=(Vector((0,0,.55))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
render('rest_front',(0,-3,0))
render('rest_side',(3,0,0))
render('idle_threequarter',(2,-3,.6),'idle',15)
render('walk_threequarter',(2,-3,.6),'walk',9)
render('idle_back',(0,3,.3),'idle',15)

render('attack_1',(2,-3,.6),'attack_1',6)
render('attack_2',(-2,-3,.6),'attack_2',8)
render('dodge',(2,-3,.6),'dodge',4)
