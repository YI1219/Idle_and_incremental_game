"""One existing-source copy: coherent inland cap, shorter ledge, basal return.

No new original mesh or paid generation. Preserve vertex/face connectivity;
finite intersection checks are required after this deformation.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/work/master_mantle/2026-10-18/master_source.bin'
OUT=ROOT/'art/work/master_landform/2026-10-18'


def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1)
    return t*t*(3-2*t)


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    before=SOURCE.read_bytes()
    source=np.frombuffer(before,dtype='<f4').reshape(-1,3).astype(float)
    unique,inverse=np.unique(source,axis=0,return_inverse=True)
    spec=importlib.util.spec_from_file_location('landform_source',ROOT/'tools/art/sample_cliff_representation.py')
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    tree=helper.tree_for([Vector(p) for p in source])
    roof=[];misses=0
    for p in unique:
        hits=[]
        for dx,dz in [(0,0),(.00002,0),(-.00002,0),(0,.00002),(0,-.00002)]:
            hit=tree.ray_cast(Vector((p[0]+dx,20,p[2]+dz)),Vector((0,-1,0)),50)
            if hit[0] is not None:hits.append(hit[0].y)
        if not hits:misses+=1
        roof.append(max([p[1]]+hits))
    roof=np.asarray(roof)
    p=unique.copy();x,y,z=unique.T
    # Lift only the inland upper mass into one cap. The exposed front core and
    # original lower body are not extended upwards by a global Y stretch.
    inland=1-smooth(.25,1.75,z)
    upper=smooth(-1.6,np.maximum(roof,-1.59),y)
    lift=np.maximum(3.25-roof,0)*inland*upper
    p[:,1]+=lift
    # Retire the protruding left mid-height bench into its rooted front face.
    ledge=(1-smooth(-3.0,-1.5,x))*smooth(-1.1,-.45,y)*(1-smooth(.65,1.3,y))
    setback=np.maximum(z-3.05,0)*.78*ledge
    p[:,2]-=setback
    # Inward return of the existing shared rock belly, anchored continuously
    # below the major faces. This preserves its asymmetric bottom heights.
    lower=1-smooth(-4.14,-1.4,y)
    p[:,0]*=1-.18*lower
    p[:,2]=.55+(p[:,2]-.55)*(1-.30*lower)
    candidate=p[inverse].astype('<f4')
    np.frombuffer(before,dtype='<f4').tofile(OUT/'source.bin')
    candidate.tofile(OUT/'candidate.bin')
    # Front-core hold is a measurable scope, not a claim of complete front
    # face invariance or that monotonic formulas guarantee valid triangles.
    held=(z>=1.75)&(y>=1.4)
    assert np.array_equal(p[held],unique[held])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name,values in [('source',source),('candidate',candidate.astype(float))]:
        vertices,index=np.unique(values,axis=0,return_inverse=True)
        mesh=bpy.data.meshes.new(name)
        # Godot Y-up/clockwise -> Blender Z-up/counterclockwise for inspection.
        co=vertices[:,[0,2,1]].copy();co[:,1]*=-1
        mesh.from_pydata(co.tolist(),[],index.reshape(-1,3)[:,[0,2,1]].tolist());mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        obj.hide_viewport=name=='source';obj.hide_render=name=='source'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'existing_master_landform.blend'))
    report={'source_sha256':hashlib.sha256(before).hexdigest(),
            'candidate_sha256':hashlib.sha256(candidate.tobytes()).hexdigest(),
            'original_unique_vertices':len(unique),'triangles':len(source)//3,
            'lifted_vertices':int((lift>1e-6).sum()),'max_upper_lift':float(lift.max()),
            'setback_vertices':int((setback>1e-6).sum()),'max_ledge_setback':float(setback.max()),
            'basal_return_vertices':int((lower>1e-6).sum()),'held_front_core_vertices':int(held.sum()),
            'roof_ray_misses':misses,'source_bounds':[source.min(0).tolist(),source.max(0).tolist()],
            'candidate_bounds':[candidate.min(0).tolist(),candidate.max(0).tolist()],
            'scope':'One bounded existing-source copy revision; no new original geometry/Tripo/default. Same faces do not prove valid embedding. Inspect neutral art and finite geometry before sampling or finishing.'}
    assert SOURCE.read_bytes()==before
    (OUT/'refinement.json').write_text(json.dumps(report,indent=2)+'\n')
    print('MASTER LANDFORM:',json.dumps(report),flush=True)


if __name__=='__main__':run()
