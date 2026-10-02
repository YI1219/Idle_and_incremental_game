"""Repeatable, non-destructive Qinglan assembly. Run with Blender --factory-startup.
Source coordinates: Tripo +X front / Z up. Authoring: -Y front / Z up.
"""
from pathlib import Path
import bpy, bmesh, json, math, hashlib
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/source/qinglan'
WORK=ROOT/'art/work/qinglan'
REVIEW=ROOT/'art/review/qinglan'
EXPORT=ROOT/'assets/characters/qinglan'
S=1.12/.99951171875
PALETTE={'ink':'171b20','skin':'cda98d','robe':'8297a5','ivory':'eee9dc','teal':'4c7777','pants':'f0eee5'}

def color(h):
    c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in c)+(1,)

def material(name):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=color(PALETTE[name]);bs.inputs['Roughness'].default_value=.86
    m.diffuse_color=color(PALETTE[name]);return m

def active(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def import_mesh(path,name):
    old=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(path))
    meshes=[o for o in bpy.data.objects if o not in old and o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    if len(meshes)>1:bpy.ops.object.join()
    o=bpy.context.object;o.name=name;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for v in o.data.vertices:v.co=Vector((v.co.y,-v.co.x,v.co.z))*S
    o.data.update();return o

def stats(o):
    bm=bmesh.new();bm.from_mesh(o.data)
    d={'vertices':len(bm.verts),'faces':len(bm.faces),'triangles':sum(len(f.verts)-2 for f in bm.faces),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_junctions':sum(len(e.link_faces)>2 for e in bm.edges),'degenerate_faces':sum(f.calc_area()<1e-10 for f in bm.faces)}
    bm.free();return d

def recalc(o):
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()

def segment_dist(p,a,b):
    v=b-a;t=max(0,min(1,(p-a).dot(v)/v.length_squared));return (p-a-t*v).length

def build_rig():
    data=bpy.data.armatures.new('QinglanSkeleton');rig=bpy.data.objects.new('QinglanRig',data);bpy.context.collection.objects.link(rig);active(rig);bpy.ops.object.mode_set(mode='EDIT')
    defs={}
    def bone(name,head,tail,parent=None):
        b=data.edit_bones.new(name);b.head=Vector(head)*S;b.tail=Vector(tail)*S
        if parent:b.parent=data.edit_bones[parent]
        if name.startswith(('UpperArm.','Forearm.','Hand.')):b.align_roll(Vector((0,1,0)))
        defs[name]=(b.head.copy(),b.tail.copy());return b
    bone('Root',(0,0,0),(0,0,.1));bone('Hips',(0,.015,.49),(0,.015,.58),'Root');bone('Spine',(0,.015,.58),(0,.01,.69),'Hips');bone('Chest',(0,.01,.69),(0,.005,.76),'Spine');bone('Neck',(0,0,.76),(0,0,.81),'Chest');bone('Head',(0,0,.81),(0,0,.98),'Neck')
    for sign,suf in [(1,'L'),(-1,'R')]:
        bone('UpperArm.'+suf,(sign*.075,.01,.742),(sign*.245,.012,.74),'Chest')
        bone('Forearm.'+suf,(sign*.245,.012,.74),(sign*.404,.016,.72),'UpperArm.'+suf)
        bone('Hand.'+suf,(sign*.404,.016,.72),(sign*.47,.005,.712),'Forearm.'+suf)
        bone('Thigh.'+suf,(sign*.060,.015,.50),(sign*.074,.025,.28),'Hips')
        bone('Shin.'+suf,(sign*.074,.025,.28),(sign*.08,.038,.06),'Thigh.'+suf)
        bone('Foot.'+suf,(sign*.08,.038,.06),(sign*.08,-.07,.022),'Shin.'+suf)
    for name,x,y in [('Front',0,-.07),('Back',0,.08),('L',.09,0),('R',-.09,0)]:bone('Skirt.'+name,(x,y,.53),(x*1.8,y*1.8,.20),'Hips')
    bpy.ops.object.mode_set(mode='OBJECT');return rig,defs

def bind(o,rig,defs,kind='body'):
    marker=o.vertex_groups.get('__Sleeve')
    marker_id=marker.index if marker else -1
    groups={name:o.vertex_groups.new(name=name) for name in defs}
    for v in o.data.vertices:
        p=v.co;q=p/S;z=q.z;x=q.x;suf='L' if x>=0 else 'R'
        if kind=='robe':
            sleeve_weight=next((g.weight for g in v.groups if g.group==marker_id),0.0)
            base={}
            if z<.60:
                w=max(0,min(1,(.58-z)/.20));w=w*w*(3-2*w)
                sectors={'Skirt.Front':max(0,-q.y)+.015,'Skirt.Back':max(0,q.y)+.015,'Skirt.L':max(0,q.x)*.7,'Skirt.R':max(0,-q.x)*.7}
                total=sum(sectors.values());base={n:w*value/total for n,value in sectors.items()};base['Hips']=1-w
            else:
                ds=sorted((segment_dist(p,*defs[n]),n) for n in ['Spine','Chest','Neck'])[:2]
                vals=[(1/(d+.012*S)**4,n) for d,n in ds];total=sum(w for w,n in vals)
                base={n:w/total for w,n in vals}
            for n,w in base.items():
                if w*(1-sleeve_weight)>0:groups[n].add([v.index],w*(1-sleeve_weight),'REPLACE')
            w=max(0,min(1,(abs(x)-.21)/.12))
            if sleeve_weight>0:
                groups['UpperArm.'+suf].add([v.index],(1-w)*sleeve_weight,'REPLACE')
                groups['Forearm.'+suf].add([v.index],w*sleeve_weight,'REPLACE')
            continue
        if kind=='ribbon':candidates=[n for n in defs if n.startswith(o.name+'.')]
        elif kind=='belt':candidates=['Hips']
        elif z>.815:candidates=['Head']
        elif z>.77:candidates=['Head','Neck']
        elif z>.65 and abs(x)>.105:candidates=['UpperArm.'+suf,'Forearm.'+suf,'Hand.'+suf]
        elif z<.48:candidates=['Thigh.'+suf,'Shin.'+suf,'Foot.'+suf]
        elif z<.58:candidates=['Hips','Spine']
        else:candidates=['Spine','Chest','Neck']
        ds=sorted((segment_dist(p,*defs[n]),n) for n in candidates)[:2]
        weights=[(1/(d+.012*S)**4,n) for d,n in ds];total=sum(w for w,n in weights)
        for w,n in weights:groups[n].add([v.index],w/total,'REPLACE')
    mod=o.modifiers.new('Skeleton','ARMATURE');mod.object=rig;o.parent=rig

def make_animations(rig):
    scene=bpy.context.scene;scene.render.fps=30
    rig.animation_data_clear()
    for name,length in [('idle',90),('walk',30)]:
        for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
        for frame in range(0,length+1,3):
            t=frame/length*math.tau
            for suf,sign in [('L',1),('R',-1)]:
                # Bone-local X pitches legs forward/back; local Z lowers T-pose arms.
                rig.pose.bones['UpperArm.'+suf].rotation_euler[2]=sign*math.radians(66)
                rig.pose.bones['UpperArm.'+suf].rotation_euler[0]=(math.sin(t)*sign*.12 if name=='walk' else math.sin(t)*.015)
                rig.pose.bones['Forearm.'+suf].rotation_euler[0]=-.06
                rig.pose.bones['Thigh.'+suf].rotation_euler[0]=(math.sin(t)*sign*.30 if name=='walk' else 0)
                rig.pose.bones['Shin.'+suf].rotation_euler[0]=(max(0,-math.sin(t)*sign)*.32 if name=='walk' else 0)
                rig.pose.bones['Foot.'+suf].rotation_euler[0]=(max(0,math.sin(t)*sign)*-.10 if name=='walk' else 0)
                rig.pose.bones['Skirt.'+suf].rotation_euler[0]=(math.sin(t+.7)*sign*.09 if name=='walk' else math.sin(t)*.015)
            rig.pose.bones['Skirt.Front'].rotation_euler[0]=math.sin(t+.5)*(.025 if name=='walk' else .008)
            rig.pose.bones['Skirt.Back'].rotation_euler[0]=math.sin(t-.5)*(.08 if name=='walk' else .018)
            rig.pose.bones['Chest'].rotation_euler[0]=math.sin(t)*.008
            rig.pose.bones['Root'].location.z=(math.cos(2*t)*.003*S if name=='walk' else math.sin(t)*.002*S)
            for pb in rig.pose.bones:
                pb.keyframe_insert('rotation_euler',frame=frame,group=pb.name)
                if pb.name=='Root':pb.keyframe_insert('location',frame=frame,group=pb.name)
        action=rig.animation_data.action;action.name=name;action.use_fake_user=True
        track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,0,action);track.mute=True
        rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=False
    scene.frame_end=90;scene.frame_set(0)


def main():
    for p in [WORK,REVIEW,EXPORT]:p.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats={n:material(n) for n in PALETTE};body=import_mesh(SOURCE/'body.fbx','Body')
    report={'source_sha256':hashlib.sha256((SOURCE/'body.fbx').read_bytes()).hexdigest(),'body_before':stats(body)}
    bm=bmesh.new();bm.from_mesh(body.data)
    bmesh.ops.split_edges(bm,edges=[e for e in bm.edges if len(e.link_faces)>2])
    boundary=[e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm,edges=boundary,sides=64)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free();body.data.update()
    body.data.materials.clear()
    for n in ['skin','ink','pants']:body.data.materials.append(mats[n])
    for f in body.data.polygons:
        q=f.center/S
        hair=(q.z>.930 or (q.z>.822 and (q.y>-.02 or abs(q.x)>.05)) or (q.z>.885 and q.y<-.071) or (q.z>.797 and abs(q.x)>.047 and q.y<-.045))
        f.material_index=1 if hair else (2 if .375<q.z<.586 else 0);f.use_smooth=True
    report['body_after']=stats(body)
    rig,defs=build_rig();bind(body,rig,defs)
    # Preserve a fully editable, colored body for future outfit changes.
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'body_colored_full.blend'))
    if (SOURCE/'clothes.fbx').exists():
        from fit_clothes import fit_clothes
        clothes=fit_clothes(SOURCE/'clothes.fbx',mats,S,report)
        from demo_motion import add_ribbons
        add_ribbons(rig,defs,clothes,S)
        for o in clothes:
            kind='ribbon' if o.name.startswith('Ribbon') else ('belt' if o.name.startswith('BeltDetail') else 'robe')
            bind(o,rig,defs,kind)
        # Garment-specific body mask: covered torso/upper limbs are retained in the
        # full-body file, but excluded from the clothed runtime mesh.
        bm=bmesh.new();bm.from_mesh(body.data)
        hidden=[f for f in bm.faces if (.30<max(v.co.z/S for v in f.verts) and f.calc_center_median().z/S<.77 and abs(f.calc_center_median().x/S)<.39) or (min(v.co.z/S for v in f.verts)<.785 and max(v.co.z/S for v in f.verts)<.812 and min(v.co.z/S for v in f.verts)>.73 and max(abs(v.co.x/S) for v in f.verts)>.034)]
        report['covered_body_faces_omitted']=len(hidden)
        bmesh.ops.delete(bm,geom=hidden,context='FACES');bm.to_mesh(body.data);bm.free()
    # Simple white under-trousers cover the masked upper legs during wide poses.
    # Kept separate for later tailoring; the archived Tripo body is untouched.
    for sign,side in [(1,'L'),(-1,'R')]:
        vertices=[];faces=[];rings=[(.55,.063,.049,.058),(.43,.067,.050,.059),(.32,.073,.047,.052),(.265,.076,.042,.047)]
        for z,x,rx,ry in rings:
            for i in range(16):
                t=i/16*math.tau;vertices.append((Vector((sign*x+rx*math.cos(t),.025+ry*math.sin(t),z))*S))
        for k in range(len(rings)-1):
            for i in range(16):faces.append((k*16+i,k*16+(i+1)%16,(k+1)*16+(i+1)%16,(k+1)*16+i))
        data=bpy.data.meshes.new('WhiteTrousers.'+side);data.from_pydata(vertices,[],faces);data.update()
        obj=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(obj);data.materials.append(mats['pants'])
        recalc(obj)
        for f in data.polygons:f.use_smooth=True
        bind(obj,rig,defs)
    from demo_motion import make_animations as demo_animations
    demo_animations(rig,S)
    report['status']='assembly_candidate' if (SOURCE/'clothes.fbx').exists() else 'body_only_clothes_pending'
    report['meshes']={o.name:stats(o) for o in bpy.data.objects if o.type=='MESH'}
    (REVIEW/'mesh_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'qinglan_candidate.blend'))
    bpy.ops.export_scene.gltf(filepath=str(EXPORT/'qinglan_candidate.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True)

if __name__=='__main__':
    import sys
    sys.path.insert(0,str(Path(__file__).parent));main()
