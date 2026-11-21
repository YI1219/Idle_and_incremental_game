from pathlib import Path
import hashlib
import json
from PIL import Image

PACK = Path(__file__).resolve().parents[1]
ROOT = PACK.parents[2]
reports = {name: json.loads((PACK / name / 'captures.json').read_text())
           for name in ['before','final','final_held2104','final_held4242','final_held913','final_night']}
before, final = reports['before'], reports['final']
assert all(x['valid'] and x['sources_unchanged'] and x['data_unchanged'] for x in reports.values())
assert before['data_sha256'] == final['data_sha256']
assert before['captures'] == final['captures'], 'camera/light/quality/capture metadata changed'
changed = [key for key in before['source_sha256'] if before['source_sha256'][key] != final['source_sha256'][key]]
assert changed == ['res://scripts/terrain_editor/terrain_decoration.gd'], changed
for report in reports.values():
    if report is before:
        continue
    assert report['source_sha256'] == final['source_sha256']
for key, expected in final['source_sha256'].items():
    assert hashlib.sha256((ROOT / key.removeprefix('res://')).read_bytes()).hexdigest() == expected, key
for state, report in reports.items():
    for shot in report['captures']:
        assert Image.open(PACK / state / shot['file']).size == (2560,1440)
script = ROOT / 'scripts/terrain_editor/terrain_decoration.gd'
snapshot = PACK / 'checks/source_before/terrain_decoration.gd'
assert hashlib.sha256(snapshot.read_bytes()).hexdigest() == before['source_sha256']['res://scripts/terrain_editor/terrain_decoration.gd']
assert script.read_bytes() == (PACK / 'checks/source_after.gd').read_bytes()
rows = json.loads((PACK / 'checks/suite.json').read_text())
assert len(rows) == 37 and all(x['ok'] for x in rows)
result = dict(valid=True, art_accepted=False, frames=sum(len(x['captures']) for x in reports.values()),
              default_matched_pairs=len(final['captures']), resolution=[2560,1440],
              camera_light_quality_metadata_equal=True, data_equal=True, changed_sources=changed,
              protected_source_hashes_equal=True, final_sources_match_disk=True,
              test_groups=len(rows), reports=list(reports), user_layouts_accessed=False)
(PACK / 'checks/audit.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
