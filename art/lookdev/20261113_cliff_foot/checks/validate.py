from pathlib import Path
import json
import subprocess
import time

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
prior = json.loads((ROOT / 'art/lookdev/20261113_background_foliage/checks/suite.json').read_text())
rows = []
cases = [dict(test='tests/cliff_outer_foot_test.gd', headless=True),
         dict(test=str((OUT / 'protection.gd').relative_to(ROOT)), headless=True)] + prior + [
             dict(test='tests/cliff_outer_color_test.gd', headless=False)]
for case in cases:
    name = Path(case['test']).stem
    started = time.monotonic()
    log = OUT / f'test_{name}.log'
    command = [GODOT, '--path', str(ROOT)]
    if case['headless']:
        command.append('--headless')
    command += ['--script', case['test']]
    with log.open('w') as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=120)
    output = log.read_text()
    ok = result.returncode == 0 and 'SCRIPT ERROR:' not in output and '\nERROR:' not in output
    rows.append(dict(test=case['test'], headless=case['headless'], ok=ok,
                     exit=result.returncode, seconds=round(time.monotonic()-started, 2)))
    (OUT / 'suite.json').write_text(json.dumps(rows, indent=2))
    print(name, 'PASS' if ok else 'FAIL', flush=True)
    if not ok:
        raise RuntimeError(f'{name}: see {log}')
with (OUT / 'normal_entry.log').open('w') as stream:
    result = subprocess.run([GODOT, '--path', str(ROOT), '--quit-after', '90'], cwd=ROOT,
                            stdout=stream, stderr=subprocess.STDOUT, timeout=60)
if result.returncode:
    raise RuntimeError('normal entry failed')
print('ALL VALIDATION COMPLETE', flush=True)
