"""Run real public edits and finite pre/post geometry gates for all light cases."""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art/work/retained_island/2026-10-19/light'
CASES = ['courtyard_7301', 'courtyard_7319', 'bay_7301', 'bay_7319']


def run():
    godot = shutil.which('godot')
    blender = '/Applications/Blender.app/Contents/MacOS/Blender'
    assert godot and Path(blender).is_file()
    reports = {}
    for case in CASES:
        folder = WORK / case
        resource_work = 'res://' + str(folder.relative_to(ROOT)) + '/'
        subprocess.run([godot, '--headless', '--path', str(ROOT), '--script',
                        'tests/retained_island_edit_test.gd', '--', '--work=' + resource_work], cwd=ROOT, check=True)
        edit = json.loads((folder / 'edit_checks.json').read_text())
        assert edit['passed'] == edit['total'] == 12
        subprocess.run([blender, '--background', '--factory-startup', '--python',
                        'tools/art/check_pcg_cliff.py', '--', '--input=' + str(folder / 'output_geometry'),
                        '--stages=playable,retained_carved'], cwd=ROOT, check=True)
        geometry = json.loads((folder / 'output_geometry/geometry_checks.json').read_text())
        assert all(stage['finite_gate_passes'] for stage in geometry['stages'].values())
        reports[case] = {'edit': edit, 'geometry': geometry}
    report = {'cases': reports, 'scope': 'Four actual new light candidates, fresh public source-extension carve/history/file12checks each plus8finite pre/post geometry gates. Not mouse/placement/support/targethardware/userart acceptance; separate reports required.', 'art_accepted': False}
    (WORK / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('LIGHT ISLAND: 4 actual cases x 12 edit checks + 8 finite geometry gates PASS', flush=True)


if __name__ == '__main__':
    run()
