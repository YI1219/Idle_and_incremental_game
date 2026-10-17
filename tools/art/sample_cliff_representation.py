"""Sample the native closed union without inventing rock geometry (Blender)."""
import bpy, hashlib, json, math, time
import numpy as np
from array import array
from collections import Counter
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/cliff_representation/2026-10-17'
STEP=.25

def read(name):
    values=array('f'); values.frombytes((OUT/(name+'.bin')).read_bytes())
    return [Vector(values[i:i+3]) for i in range(0,len(values),3)]

def topology(points):
    ids={}; faces=[]
    for i in range(0,len(points),3):
        face=[]
        for p in points[i:i+3]:
            key=tuple(round(v,5) for v in p)
            if key not in ids: ids[key]=len(ids)
            face.append(ids[key])
        faces.append(face)
    edges=Counter();directed=Counter(); signed=0.; graph=[set() for _ in ids]
    for f,offset in zip(faces,range(0,len(points),3)):
        a,b,c=points[offset:offset+3];signed-=a.dot(b.cross(c))/6
        for x,y in zip(f,f[1:]+f[:1]):
            edges[tuple(sorted((x,y)))]+=1;directed[(x,y)]+=1;graph[x].add(y);graph[y].add(x)
    todo=set(range(len(ids)));components=[]
    while todo:
        seed=todo.pop();stack=[seed];count=1
        while stack:
            for v in graph[stack.pop()]:
                if v in todo:todo.remove(v);stack.append(v);count+=1
        components.append(count)
    return {'triangles':len(faces),'welded_vertices_1e5':len(ids),'non_two_use_edges':sum(v!=2 for v in edges.values()),'directed_edge_pair_defects':sum(directed[(a,b)]!=1 or directed[(b,a)]!=1 for a,b in edges),'degenerate_index_faces':sum(len(set(f))!=3 for f in faces),'signed_volume':signed,'vertex_components':sorted(components,reverse=True)}

def tree_for(points):
    return BVHTree.FromPolygons(points,[(i,i+2,i+1) for i in range(0,len(points),3)],all_triangles=True,epsilon=0)

def analytic_inside(points,point,direction):
    """Independent float64 triangle intersections; never advance a BVH ray."""
    a=points[:,0];e1=points[:,2]-a;e2=points[:,1]-a
    ray=np.asarray(direction,dtype=np.float64);p=np.asarray(point,dtype=np.float64)
    h=np.cross(ray,e2);det=np.einsum('ij,ij->i',e1,h)
    valid=np.abs(det)>1e-12;f=np.zeros(len(det));f[valid]=1/det[valid]
    s=p-a;u=f*np.einsum('ij,ij->i',s,h);q=np.cross(s,e1)
    v=f*np.einsum('j,ij->i',ray,q);distance=f*np.einsum('ij,ij->i',e2,q)
    hit=valid&(u>=-1e-10)&(v>=-1e-10)&(u+v<=1+1e-10)&(distance>1e-7)
    # Co-located hits on the two triangles of a shared edge count once.
    groups={}
    for d,sign in zip(distance[hit],np.sign(-det[hit])):
        groups.setdefault(round(float(d),7),[]).append(int(sign))
    winding=sum(int(np.sign(sum(signs))) for signs in groups.values())
    return winding>0

def run():
    started=time.time();points=read('union');tree=tree_for(points)
    report={'input_topology':{name:topology(read(name)) for name in ['assembly','union','union_clip']},'grid_step':STEP,'source_sha256':hashlib.sha256((OUT/'union.bin').read_bytes()).hexdigest()}
    for name in ['union','union_clip']:
        t=report['input_topology'][name]
        assert t['non_two_use_edges']==0 and t['signed_volume']>0 and t['degenerate_index_faces']==0,(name,t)
    assert report['input_topology']['union_clip']['signed_volume']<report['input_topology']['union']['signed_volume']
    report['clip_max_y']=max(p.y for p in read('union_clip'));assert report['clip_max_y']<=3.25001
    lo=[math.floor((min(p[k] for p in points)-.75)/STEP) for k in range(3)]
    hi=[math.ceil((max(p[k] for p in points)+.75)/STEP) for k in range(3)]
    rays=[Vector(v).normalized() for v in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]]
    analytic_points=np.asarray([list(p) for p in points],dtype=np.float64).reshape(-1,3,3)
    records=[];disagreements=[];nearest_surface_nodes=0;crosschecks=0;corrections=0;node_index=0
    for z in range(lo[2],hi[2]+1):
        for y in range(lo[1],hi[1]+1):
            for x in range(lo[0],hi[0]+1):
                p=Vector((x*STEP,y*STEP,z*STEP));nearest=tree.find_nearest(p);distance=nearest[3]
                votes=[]
                for ray in rays:
                    origin=p+ray*1e-6;winding=0
                    for _ in range(128):
                        hit=tree.ray_cast(origin,ray,100)
                        if hit[0] is None:break
                        dot=hit[1].dot(ray)
                        if dot>1e-6:winding+=1
                        elif dot< -1e-6:winding-=1
                        origin=hit[0]+ray*1e-5
                    else:raise RuntimeError('Ray traversal exhausted')
                    votes.append(winding>0)
                if distance>1e-4 and (len(set(votes))>1 or node_index%41==0):
                    exact=[analytic_inside(analytic_points,p,ray) for ray in rays]
                    crosschecks+=1
                    assert len(set(exact))==1,{'point':list(p),'analytic_votes':exact}
                    if len(set(votes))>1:disagreements.append({'point':list(p),'bvh_votes':votes,'analytic_votes':exact,'distance':distance})
                    if (sum(votes)>=2)!=exact[0]:corrections+=1
                    votes=exact
                nearest_surface_nodes+=distance<1e-4
                inside=sum(votes)>=2
                value=round(max(-.5,min(.5,(-1 if inside else 1)*distance)),5)
                if abs(value)<.00001:value=.00002
                if value!=.5:records.append({'x':x,'y':y,'z':z,'density':value})
                node_index+=1
    (OUT/'samples.json').write_text(json.dumps(records,separators=(',',':'))+'\n')
    report.update({'grid_lo':lo,'grid_hi':hi,'sample_records':len(records),'bvh_disagreements_resolved_by_float64':disagreements,'analytic_three_ray_crosschecks':crosschecks,'bvh_majority_corrections':corrections,'near_surface_nodes':nearest_surface_nodes,'seconds':time.time()-started,'scope':'Finite local conversion from validated native union, three BVH directions at every grid node, independent float64 three-ray fallback on every disagreement plus every41st node. No global terrain edit, shape optimization, or target hardware claim.'})
    (OUT/'sampling.json').write_text(json.dumps(report,indent=2)+'\n');print('CLIFF REPRESENTATION SAMPLE:',json.dumps(report))

if __name__=='__main__':run()
