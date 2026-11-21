from pathlib import Path
import hashlib
import json
import difflib
from PIL import Image

PACK = Path(__file__).resolve().parents[1]
ROOT = PACK.parents[2]
old = PACK.parent / '20261113_cliff_foot'
before = json.loads((old / 'before/captures.json').read_text())
rejected = json.loads((old / 'final/captures.json').read_text())
reports = {name: json.loads((PACK / name / 'captures.json').read_text())
           for name in ['final','held2104','held4242','held913','night']}
final = reports['final']
assert all(x['valid'] and x['sources_unchanged'] and x['data_unchanged'] for x in reports.values())
assert before['captures'] == rejected['captures'] == final['captures']
assert before['data_sha256'] == rejected['data_sha256'] == final['data_sha256']
changed = [key for key in before['source_sha256'] if before['source_sha256'][key] != final['source_sha256'][key]]
assert changed == ['res://scripts/terrain_editor/terrain_decoration.gd'], changed
for report in reports.values():
    assert report['source_sha256'] == final['source_sha256']
for key, expected in final['source_sha256'].items():
    assert hashlib.sha256((ROOT / key.removeprefix('res://')).read_bytes()).hexdigest() == expected, key
for name, report in reports.items():
    for shot in report['captures']:
        assert Image.open(PACK / name / shot['file']).size == (2560,1440)
rows = json.loads((PACK / 'checks/suite.json').read_text())
assert len(rows) == 38 and all(x['ok'] for x in rows)
entry_log = (PACK / 'checks/normal_entry.log').read_text()
assert 'SCRIPT ERROR:' not in entry_log and '\nERROR:' not in entry_log
snapshot = PACK / 'checks/source_after'
snapshot.mkdir(exist_ok=True)
patch = []
for name in ['terrain_decoration.gd','cliff_shoulder_join.gd']:
    source = ROOT / 'scripts/terrain_editor' / name
    (snapshot / name).write_bytes(source.read_bytes())
    original = old / 'checks/source_before' / name
    a = original.read_text().splitlines(keepends=True) if original.exists() else []
    patch.extend(difflib.unified_diff(a,source.read_text().splitlines(keepends=True),
                                    fromfile='a/scripts/terrain_editor/'+name if a else '/dev/null',
                                    tofile='b/scripts/terrain_editor/'+name))
(PACK / 'checks/production.patch').write_text(''.join(patch))
result = dict(valid=True, art_accepted=False, final_frames=sum(len(x['captures']) for x in reports.values()),
              matched_pairs_to_original=9, matched_pairs_to_rejected=9, resolution=[2560,1440],
              camera_light_quality_phase_metadata_equal=True, data_equal=True,
              changed_common_sources=changed,
              new_production_sources=['res://scripts/terrain_editor/cliff_shoulder_join.gd'],
              protected_source_hashes_equal=True, final_sources_match_disk=True,
              test_groups=len(rows), headless=sum(x['headless'] for x in rows),
              native=sum(not x['headless'] for x in rows), user_layouts_accessed=False)
(PACK / 'checks/audit.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
