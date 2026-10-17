"""REJECTED plane-fit experiment: closed sources develop self-intersections.

Retained for reproduction only; use the separate coherent cage study instead.
"""
import bpy,bmesh,hashlib,json
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/work/rendered_island/2026-10-17/complete'
OUT=ROOT/'art/work/cliff_art_patch/2026-10-18/rejected_plane_fit';OUT.mkdir(parents=True,exist_ok=True)

def sculpt(raw,count):
    tri=raw.reshape(-1,3,3).astype(float)
    vertices,face=np.unique(tri.reshape(-1,3),axis=0,return_inverse=True);face=face.reshape(-1,3)
    normals=-np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);areas=np.linalg.norm(normals,axis=1);normals/=np.maximum(areas[:,None],1e-20)
    centers=tri.mean(axis=1);lo=vertices.min(0);hi=vertices.max(0)
    selected=(np.abs(normals[:,1])<.78)&(centers[:,1]<3.49)&(areas>1e-7)
    ids=np.where(selected)[0]
    # Orientation and locality keep unrelated opposite rock faces separate.
    data=np.concatenate((normals[ids],(centers[ids]-(lo+hi)/2)/(hi-lo)*.65),axis=1)
    seeds=[int(np.argmax(areas[ids]))]
    for _ in range(count-1):
        distances=np.min(np.sum((data[:,None]-data[seeds][None])**2,axis=2),axis=1)
        seeds.append(int(np.argmax(distances)))
    means=data[seeds].copy()
    for _ in range(24):
        labels=np.argmin(np.sum((data[:,None]-means[None])**2,axis=2),axis=1)
        for k in range(count):
            mask=labels==k
            if mask.any():means[k]=np.average(data[mask],axis=0,weights=areas[ids][mask])
    planes=[]
    for k in range(count):
        chosen=ids[labels==k];n=np.sum(normals[chosen]*areas[chosen,None],axis=0);n/=np.linalg.norm(n)
        center=np.average(centers[chosen],axis=0,weights=areas[chosen]);planes.append((n,float(n@center)))
    ownership={int(i):int(label) for i,label in zip(ids,labels)}
    incident=[set() for _ in vertices]
    for i,polygon in enumerate(face):
        if i in ownership:
            for v in polygon:incident[v].add(ownership[i])
    result=vertices.copy();moves=[]
    for i,p in enumerate(vertices):
        if p[1]>=3.49999 or not incident[i]:continue
        groups=sorted(incident[i]);a=np.array([planes[k][0] for k in groups]);b=np.array([planes[k][1]-planes[k][0]@p for k in groups])
        delta=np.linalg.lstsq(np.vstack((a,np.eye(3)*.25)),np.r_[b,[0.,0.,0.]],rcond=1e-7)[0]
        magnitude=np.linalg.norm(delta)
        if magnitude>.16:delta*=.16/magnitude
        # Cap coordinates stay exact; a short approach prevents a roof kink.
        weight=np.clip((3.5-p[1])/.28,0,1);delta*=weight
        result[i]+=delta;moves.append(float(np.linalg.norm(delta)))
    assert np.array_equal(result[vertices[:,1]>=3.49999],vertices[vertices[:,1]>=3.49999])
    return result[face].reshape(-1,3).astype('<f4'),{'plane_groups':count,'vertices':len(vertices),'triangles':len(face),'source_bounds':[lo.tolist(),hi.tolist()],'max_vertex_shift':max(moves),'mean_vertex_shift':float(np.mean(moves)),'protected_cap_vertices':int((vertices[:,1]>=3.49999).sum())}

def run():
    bpy.ops.wm.read_factory_settings(use_empty=True);report={'sources':{},'operation':'Plane-group sculpt of retained closed source copies; shared existing topology and exactY3.5cap preserved. No source replacement, generation, circular CSG cut or density remeshing.'}
    for number,groups in [(36,9),(37,7),(38,10)]:
        file=SOURCE/f'crown_{number}.bin';before=file.read_bytes();raw=np.frombuffer(before,dtype='<f4').reshape(-1,3)
        after,details=sculpt(raw,groups);after.tofile(OUT/f'planes_{number}.bin')
        for label,points in [('original',raw),('planes',after)]:
            vertices,indices=np.unique(points,axis=0,return_inverse=True);triangles=indices.reshape(-1,3)[:,[0,2,1]]
            mesh=bpy.data.meshes.new(f'{label}_{number}');mesh.from_pydata(vertices.tolist(),[],triangles.tolist());mesh.update()
            obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(obj)
            obj.hide_render=label=='original';obj.hide_viewport=label=='original'
            bm=bmesh.new();bm.from_mesh(mesh);nonmanifold=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
            assert nonmanifold==0 and volume>0,(number,label,nonmanifold,volume)
            if label=='planes':details.update(nonmanifold_edges=nonmanifold,signed_volume=volume)
        assert file.read_bytes()==before
        details['sha256']=hashlib.sha256(before).hexdigest();report['sources'][str(number)]=details
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'retained_planes.blend'))
    (OUT/'refinement.json').write_text(json.dumps(report,indent=2)+'\n');print('CLIFF ART PATCH',json.dumps(report),flush=True)
if __name__=='__main__':run()
