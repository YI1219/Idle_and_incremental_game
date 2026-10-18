"""User-authorized code-authored guide family, not stacked rock instances.

Large face turns/terminating clefts/common lower return are hard local geometry
constraints. Rendered independent views may guide Tripo, but cannot hard-lock it.
"""
import hashlib
import json
import math
from pathlib import Path
import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/cliff_guides/2026-10-18'
PROFILES={
 'broad_turn':{'front':[(-5.5,1.2),(-5.1,2.0),(-4.,2.35),(-3.2,2.22),(-2.95,1.80),(-2.55,2.10),(-.2,2.65),(1.5,2.35),(1.75,1.90),(2.1,2.25),(3.55,2.65),(4.9,2.10),(5.5,1.4)],'clefts':[4,8],'knee':-.45,'low':-2.35,'return':.55,'left_lift':.05},
 'high_left':{'front':[(-5.5,1.35),(-5.0,2.35),(-3.6,2.65),(-2.55,2.2),(-2.3,1.6),(-1.95,2.1),(.8,2.45),(2.1,2.4),(2.4,1.85),(2.75,2.05),(4.15,2.25),(5.0,1.8),(5.5,1.1)],'clefts':[4,8],'knee':-.9,'low':-2.65,'return':.58,'left_lift':.4},
 'shallow_corner':{'front':[(-5.5,1.15),(-5.0,1.7),(-3.8,2.0),(-2.5,1.7),(-2.2,1.25),(-1.85,1.7),(.4,2.1),(2.,2.65),(2.2,2.1),(2.55,2.5),(3.65,2.35),(4.95,1.6),(5.5,.8)],'clefts':[4,8],'knee':.05,'low':-1.7,'return':.63,'left_lift':-.15},
}


def geometry(profile,seed):
    config=PROFILES[profile]
    phase=(seed%101)*.13
    polygon=np.array(config['front']+[(5.2,-1.8),(3.6,-2.5),(1.1,-2.65),(-1.3,-2.4),(-3.8,-2.5),(-5.25,-1.8)],float)
    polygon[:,0]+=.10*np.sin(.6*polygon[:,0]+phase)
    polygon[:,1]+=.08*np.sin(.8*polygon[:,0]+phase)
    n=len(polygon);angle=np.arctan2(polygon[:,1],polygon[:,0])
    top_y=3.25+.07*np.sin(polygon[:,0]*.7+phase)+config['left_lift']*np.clip(-polygon[:,0]/5.5,0,1)
    top_y[:len(config['front'])]+=.22*np.sin(polygon[:len(config['front']),0]*.7+.9)
    top=np.column_stack([polygon[:,0],top_y,polygon[:,1]])
    middle=polygon*.83
    # Fill just the two terminating notches into a shared lower surface;
    # there are no independent boulder bottoms or repeated radial sectors.
    for index in config['clefts']:middle[index]=(middle[index-1]+middle[index+1])*.5
    middle[:,0]+=.30+.18*np.sin(polygon[:,0]*.5)
    middle[:,1]-=.04
    middle[:len(config['front']),1]+=.20*np.sin(polygon[:len(config['front']),0]*.9+.4)
    mid_y=config['knee']+.42*np.sin(angle+phase*.12)
    x=polygon[:len(config['front']),0]
    mid_y[:len(config['front'])]+=1.1*np.exp(-((x+3.7)/1.1)**2)-.6*np.exp(-((x-.2)/1.6)**2)+.4*np.exp(-((x-3.5)/1.)**2)
    middle=np.column_stack([middle[:,0],mid_y,middle[:,1]])
    lower=polygon*config['return'];lower[:,0]+=.12;lower[:,1]-=.28
    low_y=config['low']+.22*np.cos(angle*2+.4)
    lower=np.column_stack([lower[:,0],low_y,lower[:,1]])
    points=np.concatenate([top,middle,lower,[[.10,config['low']-.38,-.25]]])
    faces=[]
    for ring in range(2):
        for i in range(n):
            a=ring*n+i;b=ring*n+(i+1)%n;c=b+n;d=a+n
            faces.extend([(a,b,c),(a,c,d)])
    vectors=[Vector(v) for v in top]
    # Installed Blender5.2 returns triangle INDEX tuples, not vector objects.
    faces.extend(tessellate_polygon([vectors]))
    for i in range(n):faces.append((2*n+i,2*n+(i+1)%n,3*n))
    return points,np.array(faces,int),{'profile':profile,'seed':seed,'top_vertices':n,'cleft_vertex_indices':config['clefts'],'source_parameters':config,'geometry_rules':'Wide top; unequal major face spans; two upper clefts terminate at shared middle; one common irregular lower fan, no flat sole or separate shell.'}


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    report={'authorization':'Latest user explicitly invites code modeling as generation constraints and model-series replacement trials. These guides are new authorized original geometry, not older existing-source refinement.','scope':'Bounded source family for actual comparison; not art acceptance, arbitrary contour PCG or formal defaults. No Tripo submission/credits.','stages':{}}
    for profile in PROFILES:
        for seed in [7301,7319]:
            name=f'{profile}_{seed}';points,faces,parameters=geometry(profile,seed)
            mesh=bpy.data.meshes.new(name);mesh.from_pydata(points.tolist(),[],faces.tolist());mesh.update()
            bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
            bm.to_mesh(mesh);bm.free()
            obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.rotation_euler.x=math.pi/2
            obj.select_set(True);bpy.context.view_layer.objects.active=obj
            bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),use_selection=True,export_format='GLB')
            obj.select_set(False);obj.hide_viewport=name!='broad_turn_7301';obj.hide_render=obj.hide_viewport
            # Blender faces positive-cross outward -> Godot clockwise faces.
            tri=np.array([[mesh.vertices[i].co[:] for i in list(p.vertices)[::-1]] for p in mesh.polygons],dtype='<f4')
            tri.tofile(OUT/(name+'.bin'))
            parameters.update({'vertices':len(points),'triangles':len(tri),'sha256':hashlib.sha256((OUT/(name+'.bin')).read_bytes()).hexdigest()})
            report['stages'][name]=parameters
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'code_authored_family.blend'))
    (OUT/'guide_family.json').write_text(json.dumps(report,indent=2)+'\n')
    print('CODE CLIFF GUIDES:',','.join(report['stages']),flush=True)


if __name__=='__main__':run()
