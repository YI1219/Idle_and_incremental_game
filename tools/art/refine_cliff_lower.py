"""Fair a COPY of the valid second master's lower surface; pin upper faces."""
import hashlib
import json
import math
from pathlib import Path
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/work/cliff_land_v2/2026-10-18/contact/master_source.bin'
OUT=ROOT/'art/work/cliff_lower/2026-10-18'


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    original=SOURCE.read_bytes()
    source=np.frombuffer(original,dtype='<f4').reshape(-1,3)
    vertices,inverse=np.unique(source,axis=0,return_inverse=True)
    faces=inverse.reshape(-1,3)
    neighbors=[set() for _ in vertices]
    for face in faces:
        for a,b in [(face[0],face[1]),(face[1],face[2]),(face[2],face[0])]:
            neighbors[a].add(b);neighbors[b].add(a)
    # A bounded existing-source refinement, not a new bottom shell or global
    # stretch. Keep every upper point exact; taper motion across the transition.
    amount=np.clip((.60-vertices[:,1])/1.65,0.,1.)
    weight=amount*amount*(3.-2.*amount)
    points=vertices.astype(float).copy()
    for _ in range(18):
        mean=np.array([points[list(n)].mean(axis=0) for n in neighbors])
        points += .38*weight[:,None]*(mean-points)
    points=points.astype('<f4')
    pinned=weight==0
    assert np.array_equal(points[pinned],vertices[pinned])
    assert np.isfinite(points).all()
    source.tofile(OUT/'source.bin');points[inverse].tofile(OUT/'refined.bin')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name,value in [('source',vertices),('refined',points)]:
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(value.tolist(),[],faces[:,[0,2,1]].tolist());mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        obj.rotation_euler.x=math.pi/2
        obj.hide_viewport=name=='source';obj.hide_render=name=='source'
        obj.select_set(name=='refined')
        if name=='refined':bpy.context.view_layer.objects.active=obj
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'existing_master_lower.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/'refined_existing_master.glb'),use_selection=True,export_format='GLB')
    displacement=np.linalg.norm(points.astype(float)-vertices,axis=1)
    report={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(original).hexdigest(),
            'refined_sha256':hashlib.sha256((OUT/'refined.bin').read_bytes()).hexdigest(),
            'vertices':len(vertices),'triangles':len(faces),'pinned_vertices':int(pinned.sum()),
            'pinned_above_y':.60,'pinned_positions_exact':True,'moved_vertices':int((displacement>0).sum()),
            'max_displacement':float(displacement.max()),'mean_moved_displacement':float(displacement[displacement>0].mean()),
            'iterations':18,'factor':.38,'source_bounds':[vertices.min(0).tolist(),vertices.max(0).tolist()],
            'refined_bounds':[points.min(0).tolist(),points.max(0).tolist()],
            'scope':'One lower-only weighted neighbor fairing of existing valid source. Same faces/upper positions, original preserved. Validity and art require separate actual checks; connectivity is not validity proof.'}
    assert SOURCE.read_bytes()==original
    (OUT/'refinement.json').write_text(json.dumps(report,indent=2)+'\n')
    print('LOWER REFINEMENT:',json.dumps(report),flush=True)


if __name__=='__main__':run()
