from pathlib import Path
import json, hashlib, difflib
from PIL import Image
from build_review import cases

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent.parent
allowed = {'res://scripts/terrain_editor/' + f for f in ['terrain_data.gd', 'terrain_decoration.gd', 'grass_field.gd', 'grass_lip_soften.gd']}
reports = []
for key, title, before, after in cases:
    a = json.loads((OUT / before / 'captures.json').read_text())
    b = json.loads((OUT / after / 'captures.json').read_text())
    assert a['valid'] and b['valid'] and b['data_unchanged'] and b['sources_unchanged']
    assert not b['art_accepted'] and not b['user_layouts_accessed']
    for setting in ['scene', 'seed', 'preset', 'resolution', 'phase', 'renderer', 'msaa']:
        assert a[setting] == b[setting], (key, setting)
    earlier = {x['file']: x for x in a['captures']}
    count = 0
    for frame in b['captures']:
        with Image.open(OUT / after / frame['file']) as image:
            assert image.size == (2560, 1440)
        if frame['file'] in earlier:
            assert earlier[frame['file']] == frame, (key, frame['file'])
            count += 1
    changes = set()
    for path, sha in b['source_sha256'].items():
        local = ROOT / path.removeprefix('res://')
        assert hashlib.sha256(local.read_bytes()).hexdigest() == sha, path
        if path in a['source_sha256'] and not path.startswith('res://art/') and a['source_sha256'][path] != sha:
            changes.add(path)
    assert changes == allowed, (key, changes)
    data_changed = a['data_sha256'] != b['data_sha256']
    assert data_changed == (b['preset'] == 0), key
    reports.append(dict(case=key, matched_frames=count, final_frames=len(b['captures']), intentional_data_change=data_changed, production_changes=sorted(changes)))
suite = json.loads((OUT / 'checks/suite.json').read_text())
assert len(suite) == 39 and all(x['ok'] for x in suite)
normal = (OUT / 'checks/normal_entry.log').read_text()
assert 'SCRIPT ERROR:' not in normal and '\nERROR:' not in normal
patch = []
sha_after = {}
for resource in sorted(allowed):
    relative = resource.removeprefix('res://')
    before = OUT / 'checks/source_before' / relative
    after = ROOT / relative
    saved = OUT / 'checks/source_after' / relative
    saved.parent.mkdir(parents=True, exist_ok=True)
    saved.write_bytes(after.read_bytes())
    patch += list(difflib.unified_diff(before.read_text().splitlines(True), after.read_text().splitlines(True), fromfile='before/' + relative, tofile='after/' + relative))
    sha_after[relative] = hashlib.sha256(after.read_bytes()).hexdigest()
for relative in ['tests/courtyard_composition_test.gd', 'tests/courtyard_grass_clearance_test.gd', 'tests/cliff_partial_crown_seal_test.gd', 'tests/fixtures/partial_crown_terrain.json']:
    after = ROOT / relative
    saved = OUT / 'checks/source_after' / relative
    saved.parent.mkdir(parents=True, exist_ok=True)
    saved.write_bytes(after.read_bytes())
    sha_after[relative] = hashlib.sha256(after.read_bytes()).hexdigest()
(OUT / 'checks/production.patch').write_text(''.join(patch))
(OUT / 'checks/final_sha256.json').write_text(json.dumps(sha_after, indent=2))
result = dict(valid=True, cases=reports, final_frames=sum(x['final_frames'] for x in reports), matched_frames=sum(x['matched_frames'] for x in reports), validation_groups=len(suite), art_accepted=False, target_hardware_performance_measured=False)
(OUT / 'checks/audit.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
