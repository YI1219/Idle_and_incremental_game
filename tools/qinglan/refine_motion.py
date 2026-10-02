"""Refine the existing Qinglan rig without changing source meshes or materials."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
S = 1.12 / .99951171875
TAU = math.tau

def smooth(u):
    u = max(0.0, min(1.0, u))
    return u*u*(3-2*u)

def pulse(u, peak=.36):
    return smooth(u/peak) if u < peak else 1-smooth((u-peak)/(1-peak))

def point_bone(rig, name, direction):
    bone = rig.pose.bones[name]
    rest = bone.bone.matrix_local.to_quaternion()
    desired = rest @ Vector((0, 1, 0))
    world = desired.rotation_difference(direction.normalized()) @ rest
    parent = bone.parent
    local_rest = parent.bone.matrix_local.inverted() @ bone.bone.matrix_local
    parent_world = parent.matrix.to_quaternion() @ local_rest.to_quaternion()
    bone.rotation_mode = 'QUATERNION'
    bone.rotation_quaternion = parent_world.inverted() @ world
    bpy.context.view_layer.update()

def leg(rig, side, target):
    """Bake a two-bone sagittal solve: forward knee, world-level planted foot."""
    thigh = rig.pose.bones['Thigh.'+side]
    shin = rig.pose.bones['Shin.'+side]
    hip = thigh.head.copy()
    a, b = thigh.bone.length, shin.bone.length
    delta = target-hip
    distance = min(delta.length, (a+b)*.998)
    axis = delta.normalized()
    toward = Vector((0, -1, 0))
    bend = (toward-axis*toward.dot(axis)).normalized()
    along = (a*a-b*b+distance*distance)/(2*distance)
    height = math.sqrt(max(0, a*a-along*along))
    knee = hip+axis*along+bend*height
    point_bone(rig, 'Thigh.'+side, knee-hip)
    point_bone(rig, 'Shin.'+side, hip+axis*distance-knee)
    foot = rig.pose.bones['Foot.'+side]
    rest_direction = foot.bone.tail_local-foot.bone.head_local
    point_bone(rig, 'Foot.'+side, rest_direction)

def build():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/work/qinglan/qinglan_candidate.blend'))
    rig = next(o for o in bpy.data.objects if o.type=='ARMATURE')
    rig.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    scene = bpy.context.scene
    scene.render.fps = 30
    clips = [('idle',144),('walk',18),('attack_1',33),('attack_2',48),('dodge',24)]
    # Longer source actions are retimed to the existing gameplay durations at runtime.
    report = {'source':'art/work/qinglan/qinglan_candidate.blend', 'geometry_changed':False,
              'materials_changed':False, 'clips':{}, 'acceptance':'pending user visual acceptance'}
    for name, length in clips:
        for frame in range(length+1):
            u = frame/length
            t = u*TAU
            walk = name=='walk'
            attack = name=='attack_1'
            guard = name=='attack_2'
            dodge = name=='dodge'
            action = attack or guard or dodge
            effort = pulse(u, .37 if attack else .43) if action else 0
            follow = pulse(max(0,(u-.10)/.90), .45) if action else 0
            # Periodic breath and asymmetry; action endpoints exactly match idle phase zero.
            breathe = math.sin(t) if not action else 0
            for pb in rig.pose.bones:
                pb.rotation_mode='XYZ'
                pb.rotation_euler=(0,0,0)
                pb.location=(0,0,0)
                pb.scale=(1,1,1)
            rig.pose.bones['Chest'].rotation_euler=(.014*breathe+(.055 if walk else 0)+(-.07 if attack else .035)*effort,0,(-.21 if attack else .08 if guard else 0)*effort)
            rig.pose.bones['Spine'].rotation_euler=(.008*breathe,0,(.045*math.sin(t) if walk else .009*breathe))
            rig.pose.bones['Hips'].rotation_euler=(0,0,.035*math.sin(t) if walk else .06*effort if attack else 0)
            rig.pose.bones['Head'].rotation_euler=(-.010*breathe-(.025 if walk else 0),.016*math.sin(t),(.016*math.sin(t) if not action else .07*effort))
            vertical=(-.078+.016*(1-math.cos(2*t)) if walk else -.045*effort if dodge else -.012*effort)*S
            root_bone=rig.pose.bones['Root']
            root_bone.location=root_bone.bone.matrix_local.to_3x3().inverted() @ Vector((0,0,vertical))
            bpy.context.view_layer.update()
            for side,sign in [('L',1),('R',-1)]:
                swing = math.sin(t)*sign
                arm = rig.pose.bones['UpperArm.'+side]
                arm.rotation_euler=(-.025+.016*breathe + (swing*.17 if walk and side=='L' else swing*.055 if walk else 0), .015*sign, sign*math.radians(69))
                fore = rig.pose.bones['Forearm.'+side]
                fore.rotation_euler=(-.16-(.10 if walk and side=='L' else 0),0,0)
                if action:
                    arm.rotation_euler.x += (-.44 if side=='R' and attack else -.31 if side=='R' and guard else .19 if dodge else -.12)*effort
                    arm.rotation_euler.z -= sign*(.18 if side=='R' else .10)*effort
                    fore.rotation_euler.x -= (.24 if side=='R' else .15)*effort
                bpy.context.view_layer.update()
                ankle = rig.data.bones['Foot.'+side].head_local.copy()
                if walk:
                    # Center the stride below the hip rather than the offset rest ankle.
                    ankle.y -= .023*S
                    phase = (u+(0 if side=='L' else .5))%1
                    stance = .44
                    if phase < stance:
                        ankle.y += (-.24+.48*phase/stance)*S
                    else:
                        air = (phase-stance)/(1-stance)
                        ankle.y += (.24-.48*smooth(air))*S
                        ankle.z += .085*math.sin(math.pi*air)**1.4*S
                elif action:
                    ankle.y += (-.11 if side=='R' and attack else .06 if attack else .03*sign)*effort*S
                    if dodge:
                        ankle.y += .11*effort*S
                        ankle.z += (.06 if side=='L' else .02)*effort*S
                leg(rig,side,ankle)
                cloth = (math.sin(t-.55)*sign*.075 if walk else .012*math.sin(t))
                rig.pose.bones['Skirt.'+side].rotation_euler=(cloth+.045*follow,.010*breathe,sign*(.025 if walk else 0)+sign*.055*follow)
            rig.pose.bones['Skirt.Front'].rotation_euler=(.028*math.sin(2*t-.3) if walk else .010*breathe,0,.020*follow)
            rig.pose.bones['Skirt.Back'].rotation_euler=(.055+.095*math.sin(t-.8) if walk else .014*breathe+.12*follow,0,-.025*follow)
            for pb in rig.pose.bones:
                if pb.name.startswith('Ribbon.'):
                    i=int(pb.name.rsplit('.',1)[1])
                    sign=1 if pb.name.startswith('Ribbon.1') else -1
                    # A travelling wave follows the body; secondary wave avoids rigid flags.
                    wave=(math.sin(t-.60*i)-math.sin(-.60*i))
                    secondary=(math.sin(2*t-.8*i)-math.sin(-.8*i))
                    amp=.065 if walk else .025
                    pb.rotation_euler=((-0.36 if i==0 else -.12 if i==1 else .08)+wave*amp+secondary*.009+follow*(.10+.025*i)+(.12 if walk else 0),
                                       sign*wave*amp*.30,
                                       sign*(wave*amp*.45+follow*.07))
                path='rotation_quaternion' if pb.rotation_mode=='QUATERNION' else 'rotation_euler'
                pb.keyframe_insert(path,frame=frame,group=pb.name)
                if pb.name=='Root':pb.keyframe_insert('location',frame=frame,group=pb.name)
        action_data=rig.animation_data.action
        action_data.name=name
        action_data.use_fake_user=True
        track=rig.animation_data.nla_tracks.new()
        track.name=name
        track.strips.new(name,0,action_data)
        track.mute=True
        rig.animation_data.action=None
        report['clips'][name]={'seconds':length/30,'frames':length+1}
    for track in rig.animation_data.nla_tracks:track.mute=False
    scene.frame_start=0
    scene.frame_end=144
    scene.frame_set(0)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/work/qinglan/qinglan_motion_v02.blend'))
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/qinglan/qinglan_motion_v02.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True)
    (ROOT/'art/review/animation_refinement/authoring.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':build()
