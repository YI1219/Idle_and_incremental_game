"""Float64 point/triangle distances, independent of native BVH skinny-face tests."""
import numpy as np


def nearest(points, point):
    tri=np.asarray(points,dtype=np.float64).reshape(-1,3,3)
    p=np.asarray(point,dtype=np.float64)
    a,b,c=tri[:,0],tri[:,1],tri[:,2]
    ab,ac=b-a,c-a
    n=np.cross(ab,ac);nn=np.einsum('ij,ij->i',n,n)
    plane=np.einsum('ij,ij->i',p-a,n)
    projected=p-n*np.divide(plane,nn,out=np.zeros_like(plane),where=nn>1e-30)[:,None]
    v=projected-a
    aa=np.einsum('ij,ij->i',ab,ab);bb=np.einsum('ij,ij->i',ab,ac);cc=np.einsum('ij,ij->i',ac,ac)
    av=np.einsum('ij,ij->i',ab,v);cv=np.einsum('ij,ij->i',ac,v)
    det=aa*cc-bb*bb
    u=np.divide(av*cc-cv*bb,det,out=np.full_like(det,-1),where=abs(det)>1e-30)
    w=np.divide(cv*aa-av*bb,det,out=np.full_like(det,-1),where=abs(det)>1e-30)
    inside=(u>=0)&(w>=0)&(u+w<=1)&(nn>1e-30)
    distances=np.where(inside,np.divide(plane*plane,nn,out=np.full_like(nn,np.inf),where=nn>1e-30),np.inf)
    for start,end in [(a,b),(b,c),(c,a)]:
        edge=end-start;length=np.einsum('ij,ij->i',edge,edge)
        t=np.clip(np.divide(np.einsum('ij,ij->i',p-start,edge),length,out=np.zeros_like(length),where=length>1e-30),0,1)
        delta=p-(start+edge*t[:,None]);distances=np.minimum(distances,np.einsum('ij,ij->i',delta,delta))
    i=int(np.argmin(distances))
    return float(np.sqrt(max(0,distances[i]))),i
