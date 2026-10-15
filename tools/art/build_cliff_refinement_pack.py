"""Rebuild the local, existing-source Blender handoff without modifying originals.

First run capture_cliff_sources.gd for neutral source evidence. The native
image-generation concept and supplied reference remain local art binaries.
"""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / 'art/review/terrain_fidelity/2026-10-15/cliff_refinement'
BASE = ROOT / 'art/work/cliff_refinement/2026-10-15'
manifest = json.loads((REVIEW / 'refinement_manifest.json').read_text())
for folder in ['input', 'reference', 'output']:
    (BASE / folder).mkdir(parents=True, exist_ok=True)
for record in manifest['source_files']:
    source = ROOT / record['source']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == record['sha256'], source
    shutil.copy2(source, BASE / 'input' / record['file'])
concept = BASE / 'reference/refinement_concept_v1.png'
if not concept.exists():
    original = Path(manifest['concept']['original'])
    if not original.exists():
        raise SystemExit('Restore the recorded native image-generation concept before rebuilding.')
    shutil.copy2(original, concept)
assert hashlib.sha256(concept.read_bytes()).hexdigest() == manifest['concept']['sha256']
reference = BASE / 'reference/user_cliff_reference.png'
if not reference.exists():
    raise SystemExit('Restore the supplied cliff reference before rebuilding.')
latest = manifest.get('latest_reference')
if latest:
    source = ROOT / latest['source']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == latest['sha256']
    shutil.copy2(source, BASE / 'reference' / latest['file'])
for source in REVIEW.glob('Rock_Medium_*.png'):
    shutil.copy2(source, BASE / 'reference' / source.name)
for view in ['front', 'left', 'right', 'back', 'quarter']:
    for model in ['Rock_Medium_1', 'Rock_Medium_2']:
        assert (BASE / 'reference' / f'{model}_{view}.png').exists()
for name in ['natural12_rim.png', 'natural12_overview.png', 'fracture2_rim.png', 'fracture2_overview.png']:
    source = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish' / name
    shutil.copy2(source, BASE / 'reference' / name)
shutil.copy2(REVIEW / 'concept-generation.md', BASE / 'reference/concept-generation.md')
shutil.copy2(ROOT / 'tools/art/templates/cliff_refinement.html', BASE / 'index.html')
(BASE / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
assert (BASE / 'START_HERE.md').exists()
archive = BASE.parent / 'cliff_refinement_pack_2026-10-15.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zipped:
    for file in sorted(BASE.rglob('*')):
        if not file.is_file():
            continue
        # Rebuilding the handoff must not package later user work products.
        if file.parent == BASE / 'output' and file.name != 'README.txt':
            continue
        zipped.write(file, file.relative_to(BASE.parent))
with zipfile.ZipFile(archive) as zipped:
    assert zipped.testzip() is None
    for record in manifest['source_files']:
        payload = zipped.read('2026-10-15/input/' + record['file'])
        assert hashlib.sha256(payload).hexdigest() == record['sha256']
print(f'Verified {len(manifest["source_files"])} unchanged source files: {archive}')
