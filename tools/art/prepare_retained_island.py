"""Union finite-valid retained closed rock operands into ordinary saved densities.

Run with Blender Python. Original operands and baseline remain untouched. This
is scalar CSG, not overlapping visible rock props or a new reconstruction kernel.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]


def run():
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,default=ROOT/'art/work/retained_island/2026-10-18')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    folder=args.input.resolve()
    operands=json.loads((folder/'operands.json').read_text())
    gates=json.loads((folder/'geometry_checks.json').read_text())['stages']
    raw=(folder/'base_values.bin').read_bytes()
    assert hashlib.sha256(raw).hexdigest()==operands['base_values_sha256']
    nx,ny,nz=map(int,operands['base_size']);low=tuple(map(int,operands['base_low']))
    values=np.frombuffer(raw,dtype='<f4').reshape(nz,ny,nx)
    spec=importlib.util.spec_from_file_location('retained_sign',ROOT/'tools/art/sample_cliff_representation.py')
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    distance_spec=importlib.util.spec_from_file_location('retained_distance',ROOT/'tools/art/retained_distance.py')
    exact_distance=importlib.util.module_from_spec(distance_spec);distance_spec.loader.exec_module(exact_distance)
    def sample_closed(points):
        triangles=points.reshape(-1,3,3)
        bounds_lo,bounds_hi=points.min(0),points.max(0)
        grid_lo=np.floor((bounds_lo-.75)/.25).astype(int)
        grid_hi=np.ceil((bounds_hi+.75)/.25).astype(int)
        rays=[Vector(v).normalized() for v in [(.8731,.3817,.3039),(-.429,.791,.436),(.265,-.413,.872)]]
        result=[];checks=0;near=0
        for z in range(grid_lo[2],grid_hi[2]+1):
            for y in range(grid_lo[1],grid_hi[1]+1):
                for x in range(grid_lo[0],grid_hi[0]+1):
                    at=Vector((x*.25,y*.25,z*.25))
                    distance,_=exact_distance.nearest(points,at)
                    inside=False
                    if np.all(np.asarray(at)>=bounds_lo) and np.all(np.asarray(at)<=bounds_hi):
                        exact=[helper.analytic_inside(triangles,at,ray) for ray in rays]
                        checks+=1
                        if distance>1e-4:assert len(set(exact))==1,(list(at),exact)
                        else:near+=1
                        inside=sum(exact)>=2
                    value=round(max(-.5,min(.5,(-1 if inside else 1)*distance)),5)
                    if abs(value)<.00001:value=.00002
                    if value<.5:result.append(dict(x=int(x),y=int(y),z=int(z),density=value))
        return result,{'method':'Every node uses independent float64 all-triangle face/edge distance; every AABB-interior node uses three independent float64 triangle ray windings without ray advancement; AABB-exterior nodes are outside. Native BVH is not used for distance or sign.','analytic_three_ray_nodes':checks,'near_surface_nodes':near,'sample_records':len(result),'grid_step':.25,'bounds':[bounds_lo.tolist(),bounds_hi.tolist()]}
    changed={};reports=[]
    def baseline(key):
        x,y,z=(key[i]-low[i] for i in range(3))
        return float(values[z,y,x]) if 0<=x<nx and 0<=y<ny and 0<=z<nz else .5
    # Remove the legacy deep taper as an ordinary subtractive authoring edit.
    # A broad, slightly rounded underside sits below the retained crowns;
    # this modifies saved density records, never a visual clipping plane.
    horizontal=np.fromfile(folder/'horizontal_distance.bin',dtype='<f4').reshape(nz,nx)
    floor_changed=0
    for z in range(nz):
        for x in range(nx):
            depth=max(0.,-float(horizontal[z,x]))
            floor=-.85+.8*np.exp(-depth/1.5)
            for y in range(ny):
                key=(x+low[0],y+low[1],z+low[2])
                old=float(values[z,y,x])
                value=float(np.float32(min(.5,max(old,floor-key[1]*.25))))
                if value!=old:changed[key]=value;floor_changed+=1
    for operand in operands['pieces']:
        name=operand['stage'];source=folder/operand['file']
        digest=hashlib.sha256(source.read_bytes()).hexdigest()
        assert gates[name]['finite_gate_passes'] and gates[name]['source_sha256']==digest==operand['sha256']
        points=np.fromfile(source,dtype='<f4').reshape(-1,3).astype(float)
        records,report=sample_closed(points)
        if digest=='488749567f5eea66d00a71ba806300cf415c08bfe5fba7ae52216eee0a8a00bf':
            regression=next(r for r in records if (r['x'],r['y'],r['z'])==(-57,4,-52))
            assert regression['density']>0,'Known repeated-BVH-face exterior point misclassified'
        affected=0
        for record in records:
            key=tuple(record[k] for k in ['x','y','z'])
            value=float(np.float32(record['density']))
            old=changed.get(key,baseline(key))
            if value<old:changed[key]=value;affected+=1
        reports.append({'operand':name,'source_sha256':digest,'sampling':report,'union_record_updates':affected})
        print('RETAINED SCALAR UNION',name,len(records),'records',affected,'updates',flush=True)
    guards=[]
    for key,value in list(changed.items()):
        if abs(value)<.0002:
            guarded=-.0002 if value<0 else .0002
            guards.append({'key':key,'before':value,'after':guarded});changed[key]=guarded
    records=[dict(x=k[0],y=k[1],z=k[2],density=v) for k,v in sorted(changed.items())]
    assert len(records)<=160000
    payload=json.loads((folder/'control.layout').read_text())
    assert payload['version']==4 and payload['sculpt_profile']=='local' and not payload['rocks']
    payload['rocks']=records
    (folder/'candidate.layout').write_text(json.dumps(payload,separators=(',',':'))+'\n')
    report={'method':'Local-derived baseline with a shallow rounded underside subtracted in saved density records, then pointwise min of independently finite-gated original closed crown SDFs, at native .25m grid. Ordinary version4overrides, no visible overlapping props.','underside_edit':{'changed_base_nodes':floor_changed,'floor_range_m':[-.85,-.05],'rule':'floor=-.85+.8*exp(-inward_contour_distance/1.5), scalar intersection before source union'},'original_layout':'control.layout','candidate_layout':'candidate.layout','candidate_sha256':hashlib.sha256((folder/'candidate.layout').read_bytes()).hexdigest(),'density_overrides':len(records),'operands':reports,'near_zero_sign_preserving_guard':guards,'geometry_and_art_accepted':False,'limits':'Fixed compact contour/seed authoring cases. Reconstructed output, support, actual history/editor and visual fidelity require fresh checks; source validity is not output/art acceptance.'}
    (folder/'union.json').write_text(json.dumps(report,indent=2)+'\n')
    print('RETAINED UNION PREPARED:',len(records),'standard overrides; candidate must be reconstructed and reviewed',flush=True)


if __name__=='__main__':run()
