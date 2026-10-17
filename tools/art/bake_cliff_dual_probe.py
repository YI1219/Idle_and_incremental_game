"""Existing cliff + public brush Hermite data for a bounded DC experiment."""
import hashlib,importlib.util,json,time
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'tools/art'/file)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
dc=module('dc','cliff_dual_contour.py');sample=module('sample','sample_cliff_representation.py')
OLD=sample.OUT;OUT=ROOT/'art/work/cliff_dual/2026-10-17';OUT.mkdir(parents=True,exist_ok=True)
points=sample.read('union');tree=sample.tree_for(points)
tris=np.asarray([list(p) for p in points],dtype=float).reshape(-1,3,3)
a=tris[:,0];e1=tris[:,1]-a;e2=tris[:,2]-a
normals=-np.cross(e1,e2);normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-20)
center=np.array([-15,3.25,3.]);radius=4.

def inside(p):
    return sample.analytic_inside(tris,p,(.8731,.3817,.3039))

def hermite(edited,stats):
    def crossing(start,end,guess,default_normal):
        ray=(end-start)/np.linalg.norm(end-start);length=np.linalg.norm(end-start)
        h=np.cross(ray,e2);det=np.einsum('ij,ij->i',e1,h)
        valid=np.abs(det)>1e-12;f=np.zeros(len(det));f[valid]=1/det[valid]
        s=start-a;u=f*np.einsum('ij,ij->i',s,h);q=np.cross(s,e1)
        v=f*np.einsum('j,ij->i',ray,q);distance=f*np.einsum('ij,ij->i',e2,q)
        ids=np.where(valid&(u>=-1e-9)&(v>=-1e-9)&(u+v<=1+1e-9)&(distance>=-1e-7)&(distance<=length+1e-7))[0]
        candidates=[]
        for i in ids:
            p=start+ray*distance[i]
            if edited and p[1]>center[1]+1e-7 and np.linalg.norm(p-center)<radius-1e-7:continue
            candidates.append((p,normals[i],'source'))
        if edited:
            if abs(ray[1])>1e-12:
                t=(center[1]-start[1])/ray[1];p=start+ray*t
                if -1e-7<=t<=length+1e-7 and np.linalg.norm(p-center)<=radius+1e-7 and inside(p):candidates.append((p,np.array([0.,1.,0.]),'cut_plane'))
            rel=start-center;b=float(rel@ray);c=float(rel@rel-radius**2);discriminant=b*b-c
            if discriminant>=0:
                for t in [-b-np.sqrt(discriminant),-b+np.sqrt(discriminant)]:
                    p=start+ray*t
                    if -1e-7<=t<=length+1e-7 and p[1]>=center[1]-1e-7 and inside(p):candidates.append((p,-(p-center)/radius,'cut_sphere'))
        unique=[]
        for item in candidates:
            if not any(np.linalg.norm(item[0]-old[0])<1e-6 and abs(float(item[1]@old[1]))>.99999 for old in unique):unique.append(item)
        if not unique:
            stats['missing_source_intersections']+=1
            return guess,default_normal
        stats['multiple_intersections']+=len({tuple(np.round(x[0],6)) for x in unique})>1
        p,n,kind=min(unique,key=lambda item:np.linalg.norm(item[0]-guess))
        stats[kind]=stats.get(kind,0)+1
        return p,n
    return crossing

def vertex_links(points):
    keys=np.round(points,5);ids={};faces=[]
    for tri in keys.reshape(-1,3,3):
        face=[]
        for p in tri:
            key=tuple(p)
            if key not in ids:ids[key]=len(ids)
            face.append(ids[key])
        faces.append(face)
    links={i:[] for i in ids.values()}
    for x,y,z in faces:
        links[x].append((y,z));links[y].append((z,x));links[z].append((x,y))
    bad=0
    for pairs in links.values():
        graph={}
        for x,y in pairs:graph.setdefault(x,[]).append(y);graph.setdefault(y,[]).append(x)
        todo=set(graph);stack=[next(iter(todo))];seen=set()
        while stack:
            p=stack.pop()
            if p in seen:continue
            seen.add(p);stack.extend(graph[p])
        if seen!=todo or any(len(v)!=2 for v in graph.values()):bad+=1
    return bad

def metrics(vertices,edited):
    # Residual of the underlying source-plus-brush implicit function, not a
    # Euclidean distance to its edited boundary or a global error bound.
    selected=vertices[::max(1,len(vertices)//4000)];residual=[]
    for p in selected:
        nearest=tree.find_nearest(Vector(p));d=nearest[3]
        sdf=0. if d<1e-5 else (-d if inside(p) else d)
        if edited:sdf=max(sdf,min(p[1]-center[1],radius-np.linalg.norm(p-center)))
        residual.append(abs(sdf))
    return {'implicit_residual_mean':float(np.mean(residual)),'implicit_residual_p95':float(np.quantile(residual,.95)),'implicit_residual_max_sampled':float(np.max(residual)),'points':len(residual)}

def main():
    report={'source_sha256':hashlib.sha256((OLD/'union.bin').read_bytes()).hexdigest(),'step':.25,'stages':{},'references':['https://www.mattkeeter.com/projects/qef/','https://github.com/nickgildea/DualContouringSample','https://github.com/libfive/libfive'],'implementation':'Own uniform face-connected patch-split constrained QEF; no upstream code vendored, no runtime backend change.','acceptance':'Topology gates only. Run check_cliff_dual_intersections.py and inspect review validation; closed oriented topology does not imply an embedded valid surface.'}
    for edited in [False,True]:
        records=json.loads((OUT/'edited_samples.json' if edited else OLD/'samples.json').read_text())
        for mode in ['field','hermite']:
            name='dc_'+mode+('_edited' if edited else '');stats={'missing_source_intersections':0,'multiple_intersections':0}
            started=time.time();vertices,metadata=dc.reconstruct(records,hermite(edited,stats) if mode=='hermite' else None)
            raw=vertices.astype('<f4');raw.tofile(OUT/(name+'.bin'))
            topology=sample.topology([Vector(p) for p in raw]);topology['nonmanifold_vertex_links']=vertex_links(raw)
            assert metadata['missing_quad_cells']==0
            assert all(topology[key]==0 for key in ['non_two_use_edges','directed_edge_pair_defects','degenerate_index_faces','nonmanifold_vertex_links']),topology
            assert topology['signed_volume']>0,topology
            details=metadata.pop('hermite');(OUT/(name+'_hermite.json')).write_text(json.dumps(details,separators=(',',':'))+'\n')
            entry={'topology':topology,'intersections':stats,'reconstruction':metadata,'seconds_including_validation':time.time()-started,'residual':metrics(raw,edited)}
            report['stages'][name]=entry
            print('DUAL STAGE:',name,json.dumps(entry),flush=True)
    (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
