"""Offline CC0 geometry study, Powered by Poly Haven.

Uses already fetched official files metadata. No purchased asset, photo preview
download, texture replacement or live API dependency in the game.
"""
import hashlib
import json
import shutil
import sys
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/source/third_party/polyhaven/2026-10-17'
WORK=ROOT/'art/work/polyhaven_rocks/2026-10-17'
slugs=sys.argv[1:] or ['namaqualand_boulder_02','rock_face_02']
assert all(slug in ['namaqualand_boulder_02','rock_face_02','boulder_01'] for slug in slugs)
manifest=SOURCE/'download_manifest.json'
report=[r for r in json.loads(manifest.read_text()) if r['slug'] not in slugs] if manifest.exists() else []
for slug in slugs:
    metadata=json.loads((SOURCE/(slug+'_files.json')).read_text())
    entry=metadata['gltf']['1k']['gltf']
    original=SOURCE/slug;original.mkdir(exist_ok=True)
    work=WORK/slug;work.mkdir(parents=True,exist_ok=True)
    downloads=[]
    for relative,desc in [(slug+'_1k.gltf',entry)]+[(name,desc) for name,desc in entry['include'].items() if name.endswith('.bin')]:
        assert relative==Path(relative).name
        url=desc['url'];assert url.startswith('https://dl.polyhaven.org/')
        path=original/relative
        if not path.exists():
            req=urllib.request.Request(url,headers={'User-Agent':'YunluArtStudy/1.0 (offline CC0 evaluation)'})
            with urllib.request.urlopen(req,timeout=60) as response:path.write_bytes(response.read())
        blob=path.read_bytes()
        assert len(blob)==desc['size'] and hashlib.md5(blob).hexdigest()==desc['md5']
        downloads.append(dict(path=str(path.relative_to(ROOT)),url=url,bytes=len(blob),sha256=hashlib.sha256(blob).hexdigest(),md5=desc['md5']))
        if relative.endswith('.bin'):shutil.copy2(path,work/relative)
    gltf=json.loads((original/(slug+'_1k.gltf')).read_text())
    for key in ['materials','images','textures','samplers']:gltf.pop(key,None)
    for mesh in gltf['meshes']:
        for primitive in mesh['primitives']:primitive.pop('material',None)
    target=work/(slug+'_geometry.gltf');target.write_text(json.dumps(gltf,indent=2)+'\n')
    report.append(dict(slug=slug,page='https://polyhaven.com/a/'+slug,license='CC0-1.0',
        files=downloads,work_geometry=str(target.relative_to(ROOT)),
        geometry_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        work_operation='Strip material/image/texture/sampler references from a separate glTF copy; geometry, scene transforms, buffer bytes and originals unchanged.',
        stage='Source evaluation only; no runtime promotion or downloaded preview/texture images.'))
(SOURCE/'download_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('POLY HAVEN GEOMETRY:',json.dumps([{ 'slug':r['slug'],'files':len(r['files']),'bytes':sum(f['bytes'] for f in r['files'])} for r in report]))
