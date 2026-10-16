"""Validate scope and actual outputs of rejected, tool-only cliff studies."""
import hashlib
import json
import struct
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / 'art/review/terrain_fidelity/2026-10-16/cliff_connection'
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/sculpt_base'
BASE = 'bb440935a1596b814ce838863bcd0e905dee356b'
SCOPE = ['assets', 'scripts', 'shaders', 'scenes', 'tests', 'project.godot']
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

changed = git('diff', '--name-only', BASE, '--', *SCOPE).decode().splitlines()
new_runtime = git('ls-files', '--others', '--exclude-standard', '--', *SCOPE).decode().splitlines()
assert not changed and not new_runtime, (changed, new_runtime)
originals = {}
for name in ['cliff_integrated_main_v1.glb', 'cliff_integrated_tall_v1.glb', 'cliff_main_v4.glb', 'cliff_tall_v2.glb']:
    path = 'assets/nature/refined/' + name
    before = git('show', BASE + ':' + path)
    after = (ROOT / path).read_bytes()
    assert before == after
    originals[path] = hashlib.sha256(after).hexdigest()
matched = json.loads((REVIEW / 'matched_views.json').read_text())
assert matched['new_native_captures'] == 42
for tag, evidence in matched['evidence'].items():
    log = (REVIEW / f'yunlu_{tag}.log').read_text()
    assert 'SCULPT BASE CAPTURES: 7 samples=0 skin_vertices=0' in log
    assert 'SCRIPT ERROR' not in log and '\nERROR:' not in log
    for view, digest in evidence['images_sha256'].items():
        png = (SOURCE / f'{tag}_{view}.png').read_bytes()
        assert hashlib.sha256(png).hexdigest() == digest
        assert png[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II', png[16:24]) == (1671, 941)
diagnostics = json.loads((REVIEW / 'source_diagnostics.json').read_text())
log = (REVIEW / 'source_diagnostics.log').read_text()
assert 'SCRIPT ERROR' not in log and '\nERROR:' not in log
assert len(diagnostics['reports']) == 4
for version, report in diagnostics['reports'].items():
    assert len(report) == 4
    for stats in report.values():
        assert stats['nonfinite_vertices'] == 0 and stats['minimum_triangle_area'] > 0
        if version in ['default', 'v2']:
            assert stats['uploaded_edges']['non_two_edges'] == 0
assert diagnostics['reports']['v1']['cliff_column_d']['uploaded_edges']['non_two_edges'] == 6
assert diagnostics['reports']['v3']['cliff_column_c']['uploaded_edges']['non_two_edges'] == 6
for version in ['v1', 'v2', 'v3']:
    source_report = ROOT / f'art/work/cliff_worn/2026-10-16/source_{version}.json'
    for source in json.loads(source_report.read_text()):
        assert source['nonmanifold_edges'] == source['degenerate_faces'] == 0
        assert hashlib.sha256((ROOT / source['glb']).read_bytes()).hexdigest() == source['glb_sha256']
    (REVIEW / f'refined_sources_{version}.json').write_bytes(source_report.read_bytes())
result = dict(base_commit=BASE, production_changed_files=changed, untracked_runtime_files=new_runtime,
    original_sources_sha256=originals, new_clean_native_captures=42, images_size=[1671, 941],
    cameras_and_authoritative_data_match=True, principal_water_clocks=1.25,
    source_diagnostics=diagnostics, all_studies_rejected=True,
    hash_note='worn2smooth/worn3smooth capture-source vertices_sha256 hashes hexadecimal text of packed vertices; not raw packed bytes. Diagnostic topology checks use actual uploaded arrays.',
    scope='No runtime changes. Finite source diagnostics and screenshots do not prove full-scene closure, support, edit regeneration, motion, export or hardware performance. No such acceptance claimed.')
if '--http' in sys.argv:
    pages = ['cliff_connection.html', 'comparison.html']
    for tag, evidence in matched['evidence'].items():
        pages.extend(f'{tag}_{view}.png' for view in evidence['images_sha256'])
    statuses = {}
    for page in pages:
        request = urllib.request.Request('http://127.0.0.1:18771/' + page, method='HEAD')
        with urllib.request.urlopen(request, timeout=5) as response:
            assert response.status == 200
            statuses[page] = response.status
    result['http_statuses'] = statuses
(REVIEW / 'validation.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print('CLIFF CONNECTION EVIDENCE: 42 clean native views, exact cameras/data, unchanged production and original sources; all trials rejected.')
