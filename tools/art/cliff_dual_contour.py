"""Uniform dual-contouring experiment, not a runtime terrain implementation.

Own implementation of Hermite/QEF principles explained by Matt Keeter and
Nick Gildea. No upstream code is vendored. Face-connected patches get separate
cell vertices; this is not the adaptive Manifold Dual Contouring algorithm.
"""
import itertools
import numpy as np

CORNERS=list(itertools.product((0,1),repeat=3))
EDGES=[(c,axis) for c in CORNERS for axis in range(3) if c[axis]==0]

def solve_qef(points,normals,lo,hi):
    points=np.asarray(points,dtype=float);a=np.asarray(normals,dtype=float)
    lo=np.asarray(lo,dtype=float)+1e-4;hi=np.asarray(hi,dtype=float)-1e-4
    mass=points.mean(axis=0);b=np.einsum('ij,ij->i',a,points-mass)
    # Small mass-point regularization stabilizes planar/edge rank deficiencies.
    aa=np.vstack((a,np.eye(3)*1e-4));bb=np.concatenate((b,np.zeros(3)))
    answer=np.linalg.lstsq(aa,bb,rcond=1e-5)[0]+mass
    if np.all(answer>=lo) and np.all(answer<=hi):return answer
    best=None;best_error=float('inf')
    # Enumerate interior, faces, edges and corners for a bounded least-squares
    # solve. Clamping an unconstrained solution does not minimize this QEF.
    for state in itertools.product((-1,0,1),repeat=3):
        free=np.array([i for i,s in enumerate(state) if s==0],dtype=int)
        fixed=np.array([i for i,s in enumerate(state) if s!=0],dtype=int)
        candidate=np.zeros(3)
        for i in fixed:candidate[i]=(lo[i] if state[i]<0 else hi[i])-mass[i]
        if len(free):candidate[free]=np.linalg.lstsq(aa[:,free],bb-aa[:,fixed]@candidate[fixed],rcond=1e-5)[0]
        position=candidate+mass
        if np.any(position<lo-1e-9) or np.any(position>hi+1e-9):continue
        error=float(np.sum((aa@candidate-bb)**2))
        if error<best_error:best_error=error;best=position
    assert best is not None and np.isfinite(best).all()
    return best

def reconstruct(records,edge_sampler=None,step=.25):
    values={tuple(int(r[k]) for k in ('x','y','z')):float(r['density']) for r in records}
    def value(q):return values.get(tuple(q),.5)
    def gradient(q):
        g=np.array([value(np.asarray(q)+np.eye(3,dtype=int)[i])-value(np.asarray(q)-np.eye(3,dtype=int)[i]) for i in range(3)])
        return g/max(np.linalg.norm(g),1e-12)
    cells=set()
    for q,v in values.items():
        if v<0:
            for c in CORNERS:cells.add(tuple(np.asarray(q)-c))
    cells=sorted(c for c in cells if len({value(np.asarray(c)+o)<0 for o in CORNERS})==2)
    crossings={};cell_vertices={};vertices=[];hermite=[];split_cells=0
    for cell in cells:
        cell_edges=[]
        for corner,axis in EDGES:
            q=np.asarray(cell)+corner;end=q+np.eye(3,dtype=int)[axis]
            va,vb=value(q),value(end)
            if (va<0)==(vb<0):continue
            key=(tuple(q),axis)
            if key not in crossings:
                t=va/(va-vb);p=(q+(end-q)*t)*step
                normal=gradient(q)*(1-t)+gradient(end)*t
                normal/=max(np.linalg.norm(normal),1e-12)
                if edge_sampler is not None:p,normal=edge_sampler(q*step,end*step,p,normal)
                assert np.isfinite(p).all() and np.isfinite(normal).all()
                crossings[key]=(np.asarray(p),np.asarray(normal))
                hermite.append({'node':[int(x) for x in q],'axis':axis,'point':list(map(float,p)),'normal':list(map(float,normal))})
            cell_edges.append(key)
        graph={key:set() for key in cell_edges}
        for face_axis in range(3):
            for side in [0,1]:
                coordinate=cell[face_axis]+side
                face_edges=[key for key in cell_edges if key[1]!=face_axis and key[0][face_axis]==coordinate]
                pairs=[]
                if len(face_edges)==2:pairs=[face_edges]
                elif len(face_edges)==4:
                    face_corners=[np.asarray(cell)+c for c in CORNERS if c[face_axis]==side]
                    center_inside=sum(value(c) for c in face_corners)<0
                    for corner in face_corners:
                        if (value(corner)<0)==center_inside:continue
                        touching=[key for key in face_edges if np.array_equal(key[0],corner) or np.array_equal(np.asarray(key[0])+np.eye(3,dtype=int)[key[1]],corner)]
                        assert len(touching)==2;pairs.append(touching)
                else:assert len(face_edges)==0
                for x,y in pairs:graph[x].add(y);graph[y].add(x)
        remaining=set(cell_edges);patch_count=0
        while remaining:
            stack=[min(remaining)];patch=[]
            while stack:
                key=stack.pop()
                if key not in remaining:continue
                remaining.remove(key);patch.append(key);stack.extend(sorted(graph[key]))
            index=len(vertices);patch_count+=1
            ps=[crossings[key][0] for key in patch];ns=[crossings[key][1] for key in patch]
            vertices.append(solve_qef(ps,ns,np.asarray(cell)*step,(np.asarray(cell)+1)*step))
            for key in patch:cell_vertices[(cell,key)]=index
        split_cells+=patch_count>1
    triangles=[];missing_quads=0
    for (q,axis),(p,n) in crossings.items():
        u,v=(axis+1)%3,(axis+2)%3;ring=[]
        for du,dv in [(0,0),(-1,0),(-1,-1),(0,-1)]:
            c=list(q);c[u]+=du;c[v]+=dv
            if (tuple(c),(q,axis)) not in cell_vertices:missing_quads+=1;break
            ring.append(cell_vertices[(tuple(c),(q,axis))])
        if len(ring)!=4:continue
        # Winding follows sign/topology, never the geometric cross product of
        # an individual possibly concave triangle in a non-planar quad.
        if value(q)<0:ring.reverse()
        # Consistent triangulation of each dual quad; no mesh smoothing.
        triangles.extend([(ring[0],ring[1],ring[2]),(ring[0],ring[2],ring[3])])
    vertices=np.asarray(vertices);triangles=np.asarray(triangles,dtype=int)
    return vertices[triangles].reshape(-1,3),{'active_cells':len(cells),'dual_vertices':len(vertices),'split_patch_cells':split_cells,'crossing_edges':len(crossings),'missing_quad_cells':missing_quads,'triangles':len(triangles),'hermite':hermite}
