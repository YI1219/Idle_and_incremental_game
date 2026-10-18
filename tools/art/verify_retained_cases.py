"""Fresh real edit/file replay and pre/post finite gates for all four cases."""
from pathlib import Path
import json
import subprocess

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/retained_island/2026-10-18'
GODOT='/opt/homebrew/bin/godot'
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
summary={}
for case in ['courtyard_7301','courtyard_7319','bay_7301','bay_7319']:
    folder=WORK if case=='courtyard_7301' else WORK/case
    assert (folder/'output_geometry/playable.bin').exists()
    with (folder/'edit_checks.log').open('w') as stream:
        result=subprocess.run([GODOT,'--headless','--path',str(ROOT),'--script',
            'tests/retained_island_edit_test.gd','--',f'--work={folder}/'],
            cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
    assert result.returncode==0,(case,'edit_checks.log')
    edit=json.loads((folder/'edit_checks.json').read_text())
    assert edit['passed']==edit['total']==12
    with (folder/'output_geometry/gates.log').open('w') as stream:
        result=subprocess.run([BLENDER,'--background','--factory-startup','--python',
            'tools/art/check_pcg_cliff.py','--',f'--input={folder}/output_geometry',
            '--stages=playable,retained_carved'],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
    assert result.returncode==0
    gates=json.loads((folder/'output_geometry/geometry_checks.json').read_text())['stages']
    assert len(gates)==2 and all(g['finite_gate_passes'] for g in gates.values()),case
    summary[case]={'edit_checks':edit,'finite_gates':gates}
    print('ACTUAL CASE VERIFIED',case,'12/12 edit/history/file checks; 2 finite geometry gates',flush=True)
(WORK/'verification.json').write_text(json.dumps({'cases':summary,'scope':'Fresh four ordinary-data candidates and one public rock cut each. Geometry gates are finite; support/native screen input/performance/art acceptance separate.'},indent=2)+'\n')
