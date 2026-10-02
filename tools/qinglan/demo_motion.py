"""Small authored motion set with delayed skirt and three-joint ribbon motion."""
import bpy,math
from mathutils import Vector

def add_ribbons(rig,defs,objects,S):
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for o in objects:
        if not o.name.startswith('Ribbon'):continue
        points=[v.co.copy() for v in o.data.vertices]
        anchor=Vector((0,.025,.56))*S
        near=sorted(points,key=lambda p:(p-anchor).length)[:max(4,len(points)//12)]
        start=sum(near,Vector())/len(near)
        far=sorted(points,key=lambda p:(p-start).length)[-max(4,len(points)//12):]
        end=sum(far,Vector())/len(far)
        parent='Hips'
        for i in range(3):
            n=o.name+'.'+str(i);b=rig.data.edit_bones.new(n)
            b.head=start.lerp(end,i/3);b.tail=start.lerp(end,(i+1)/3)
            b.parent=rig.data.edit_bones[parent];b.align_roll(Vector((0,0,1)))
            defs[n]=(b.head.copy(),b.tail.copy());parent=n
    bpy.ops.object.mode_set(mode='OBJECT')

def pulse(u,peak=.36):
    t=max(0,min(1,u/peak if u<peak else (1-u)/(1-peak)))
    return t*t*(3-2*t)

def make_animations(rig,S):
    scene=bpy.context.scene;scene.render.fps=30;rig.animation_data_clear()
    for name,length in [('idle',90),('walk',24),('attack_1',15),('attack_2',19),('dodge',11)]:
        for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
        for frame in range(length+1):
            u=frame/length;t=u*math.tau;walking=name=='walk';attack=name.startswith('attack');dodging=name=='dodge'
            force=pulse(u,.38 if name=='attack_1' else .42) if attack or dodging else 0
            lag=pulse(max(0,u-.10),.46) if attack or dodging else 0
            side=1 if name=='attack_2' else -1
            for suf,sign in [('L',1),('R',-1)]:
                arm=rig.pose.bones['UpperArm.'+suf];fore=rig.pose.bones['Forearm.'+suf]
                arm.rotation_euler=(math.sin(t)*sign*.26 if walking else math.sin(t)*.015,0,sign*math.radians(66))
                fore.rotation_euler=(-.12,0,0)
                if attack:
                    lead=sign==side
                    arm.rotation_euler.x+=(-.75 if lead else .20)*force
                    arm.rotation_euler.z-=sign*(.35 if lead else .12)*force
                    fore.rotation_euler.x+=(-.25 if lead else -.20)*force
                if dodging:
                    arm.rotation_euler.x+=.5*force
                    fore.rotation_euler.x-=.4*force
                stride=math.sin(t)*sign if walking else 0
                rig.pose.bones['Thigh.'+suf].rotation_euler.x=stride*.40+(.22*force if dodging else (-.12*force*sign if attack else 0))
                rig.pose.bones['Shin.'+suf].rotation_euler.x=max(0,-stride)*.48+(.3*force if dodging else 0)
                rig.pose.bones['Foot.'+suf].rotation_euler.x=max(0,stride)*-.14
                rig.pose.bones['Skirt.'+suf].rotation_euler=(math.sin(t-.65)*sign*(.065 if walking else .016)+lag*.07,math.sin(t-.9)*.025,sign*lag*.08)
            rig.pose.bones['Skirt.Front'].rotation_euler=(math.sin(t-.5)*(.035 if walking else .009)+lag*.09,side*lag*.025,0)
            rig.pose.bones['Skirt.Back'].rotation_euler=(math.sin(t-.8)*(.09 if walking else .023)+lag*.16,side*lag*.035,0)
            rig.pose.bones['Chest'].rotation_euler=(math.sin(t)*.008+(.18*force if dodging else -.04*force),0,side*.30*force if attack else math.sin(t)*(.035 if walking else .009))
            rig.pose.bones['Hips'].rotation_euler.z=-side*.10*force if attack else math.sin(t)*(.025 if walking else .008)
            rig.pose.bones['Root'].location.z=(math.cos(2*t)*.006 if walking else (-.02*force if dodging else math.sin(t)*.002))*S
            for pb in rig.pose.bones:
                if pb.name.startswith('Ribbon.'):
                    i=int(pb.name.rsplit('.',1)[1]);sgn=1 if pb.name.startswith('Ribbon.1') else -1
                    amp=.09 if walking else .035
                    pb.rotation_euler=(math.sin(t-i*.65)*amp+lag*.16,math.sin(t-.5-i*.55)*amp*.5,sgn*(math.sin(t-.8-i*.6)*amp*.7+lag*.10))
                pb.keyframe_insert('rotation_euler',frame=frame,group=pb.name)
                if pb.name=='Root':pb.keyframe_insert('location',frame=frame,group=pb.name)
            if name in ('idle','walk') and frame==length:
                pass
        action=rig.animation_data.action;action.name=name;action.use_fake_user=True
        track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,0,action);track.mute=True
        rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=False
    scene.frame_end=90;scene.frame_set(0)
