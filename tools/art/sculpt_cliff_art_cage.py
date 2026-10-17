"""Blender refinement with a coherent, piecewise-affine existing-mesh cage.

Each source is sheared only along its own outward axis; tangent/height stay
unchanged in the first stage. Splits follow the cage's affine boundaries.
The optional monotone height map seats the existing lower face more deeply.
"""
import bpy,bmesh,hashlib,json
from pathlib import Path
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/work/cliff_art_patch/2026-10-18'
SOURCE=ROOT/'art/work/rendered_island/2026-10-17/complete'
FRAMES=json.loads((OUT/'frames.json').read_text())
DESIGN={36:dict(left=-.10,right=.06,offset=-.14,knot=.10,tilt=.04,foot=-.95,middle=1.25),37:dict(left=-.12,right=.07,offset=-.24,knot=-.40,tilt=.06,foot=-1.40,middle=1.25),38:dict(left=-.06,right=.12,offset=-.12,knot=.35,tilt=-.015,foot=-.60,middle=1.60)}

def cap_area(raw):
    tris=raw.reshape(-1,3,3);selected=tris[np.max(abs(tris[:,:,1]-3.5),axis=1)<1e-5]
    return float(np.linalg.norm(np.cross(selected[:,1]-selected[:,0],selected[:,2]-selected[:,0]),axis=1).sum()/2)
def cut(bm,n,d):
    n=Vector(n)
    if n.length_squared<1e-14:return
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_no=n,plane_co=n*(d/n.length_squared),clear_inner=False,clear_outer=False)
def run():
    bpy.ops.wm.read_factory_settings(use_empty=True);report={'sources':{},'design':DESIGN,'scope':'Existing source copies, own frame-aligned piecewise-affine cage. No new original model, sphere cut or density reconstruction. Extra closed volume is not authoritative editor data.'}
    for number,params in DESIGN.items():
        file=SOURCE/f'crown_{number}.bin';raw=np.fromfile(file,dtype='<f4').reshape(-1,3);source_hash=hashlib.sha256(file.read_bytes()).hexdigest()
        vertices,indices=np.unique(raw,axis=0,return_inverse=True);faces=indices.reshape(-1,3)[:,[0,2,1]]
        frame=FRAMES[str(number)];out=np.array(frame['outward']);tangent=np.array(frame['tangent']);origin=np.array([frame['edge'][0],0,frame['edge'][1]])
        for seated in [False,True]:
            stage='seated' if seated else 'cage';mesh=bpy.data.meshes.new(f'{stage}_{number}');mesh.from_pydata(vertices.tolist(),[],faces.tolist());mesh.update()
            bm=bmesh.new();bm.from_mesh(mesh)
            bmesh.ops.dissolve_limit(bm,angle_limit=.0001,verts=list(bm.verts),edges=list(bm.edges),delimit=set())
            # f=max(left*(u-knot),right*(u-knot))+offset+tilt*(y-1.8)
            # clamped to ±.35*(3.5-y). Cut every affine region boundary first.
            cut(bm,tangent,float(tangent@origin+params['knot']))
            for slope in [params['left'],params['right']]:
                intercept=params['offset']-slope*params['knot']-params['tilt']*1.8
                for sign in [-1,1]:
                    n=slope*tangent+np.array([0,params['tilt']+sign*.35,0])
                    d=slope*(tangent@origin)-intercept+sign*.35*3.5;cut(bm,n,float(d))
            if seated:
                for y in [1.8,2.7]:cut(bm,[0,1,0],y)
            moved=0;maximum=0.
            for v in bm.verts:
                p=np.array(v.co,dtype=float);before=p.copy();u=float(tangent@(p-origin));y=p[1]
                f=max(params['left']*(u-params['knot']),params['right']*(u-params['knot']))+params['offset']+params['tilt']*(y-1.8)
                bound=max(0.,.35*(3.5-y));shift=float(np.clip(f,-bound,bound));p+=out*shift
                if seated:p[1]=np.interp(y,[0,1.8,2.7,3.5],[params['foot'],params['middle'],2.7,3.5])
                if abs(y-3.5)<1e-5:p=before
                v.co=Vector(p);distance=float(np.linalg.norm(p-before));maximum=max(maximum,distance);moved+=distance>1e-7
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
            bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
            bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY');bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True)
            assert bad==0 and volume>0,(number,stage,bad,volume)
            points=np.array([list(v.co) for face in bm.faces for v in list(face.verts)[::-1]],dtype='<f4');points.tofile(OUT/f'{stage}_{number}.bin')
            area_before=cap_area(raw);area_after=cap_area(points);assert abs(area_after-area_before)<.0001,(number,area_before,area_after)
            bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(obj);obj.hide_viewport=not seated;obj.hide_render=not seated
            report['sources'][f'{stage}_{number}']={'source_sha256':source_hash,'triangles':len(points)//3,'nonmanifold_edges':bad,'signed_volume':volume,'moved_vertices_after_cage_splits':moved,'maximum_displacement':maximum,'cap_area_before':area_before,'cap_area_after':area_after}
            assert hashlib.sha256(file.read_bytes()).hexdigest()==source_hash
    # Match production's independent overlapping source draws; these are not
    # Boolean unions and must never be described as one embedded surface.
    for stage in ['baseline','cage','seated']:
        files=[SOURCE/f'crown_{n}.bin' if stage=='baseline' else OUT/f'{stage}_{n}.bin' for n in DESIGN]
        (OUT/f'assembly_{stage}.bin').write_bytes(b''.join(f.read_bytes() for f in files))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'retained_cage.blend'));(OUT/'cage_refinement.json').write_text(json.dumps(report,indent=2)+'\n');print('CLIFF CAGE',json.dumps(report),flush=True)
if __name__=='__main__':run()
