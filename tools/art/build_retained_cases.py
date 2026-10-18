"""Prepare the three remaining fixed contour/seed acceptance cases.

Each export and gate is recorded before conversion; a failed gate stops work.
This is offline authoring of ordinary saved sculpt data, not runtime geometry.
"""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art/work/retained_island/2026-10-18'
GODOT = '/opt/homebrew/bin/godot'
BLENDER = '/Applications/Blender.app/Contents/MacOS/Blender'


def run(args, log):
    with log.open('w') as stream:
        result = subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f'{log}: exit {result.returncode}')


for layout, seed in [('courtyard', 7301), ('courtyard', 7319), ('bay', 7301), ('bay', 7319)]:
    folder = WORK if (layout, seed)==('courtyard',7301) else WORK / f'{layout}_{seed}'
    folder.mkdir(parents=True, exist_ok=True)
    run([GODOT, '--headless', '--path', str(ROOT), '--script',
         'tools/art/export_retained_island.gd', '--', f'--output={folder}/',
         f'--layout={layout}', f'--seed={seed}'], folder / 'export.log')
    operands = json.loads((folder / 'operands.json').read_text())
    stages = ','.join(piece['stage'] for piece in operands['pieces'])
    run([BLENDER, '--background', '--factory-startup', '--python',
         'tools/art/check_pcg_cliff.py', '--', f'--input={folder}',
         f'--stages={stages}'], folder / 'operand_gates.log')
    gates = json.loads((folder / 'geometry_checks.json').read_text())['stages']
    assert len(gates) == len(operands['pieces'])
    assert all(gate['finite_gate_passes'] for gate in gates.values()), folder
    print('SOURCE GATES PASS', layout, seed, len(gates), flush=True)
    run([BLENDER, '--background', '--factory-startup', '--python',
         'tools/art/prepare_retained_island.py', '--', f'--input={folder}'],
        folder / 'conversion.log')
    assert (folder / 'candidate.layout').exists()
    print('ORDINARY CANDIDATE READY', layout, seed, flush=True)
