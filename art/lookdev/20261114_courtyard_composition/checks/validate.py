from pathlib import Path
import json,subprocess,time,sys
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
rows=[]
for case in json.loads((OUT/'cases.json').read_text()):
 name=Path(case['test']).stem
 mode='headless' if case['headless'] else 'native'
 log=OUT/f'test_{name}_{mode}.log'
 cmd=['/opt/homebrew/bin/godot','--path',str(ROOT)]
 if case['headless']:cmd.append('--headless')
 cmd+=['--script',case['test']]
 started=time.monotonic()
 try:
  with log.open('w') as stream: result=subprocess.run(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
  output=log.read_text()
  ok=result.returncode==0 and 'SCRIPT ERROR:' not in output and '\nERROR:' not in output
  row=dict(**case,ok=ok,exit=result.returncode,seconds=round(time.monotonic()-started,2))
 except subprocess.TimeoutExpired:
  row=dict(**case,ok=False,exit='timeout',seconds=round(time.monotonic()-started,2))
 rows.append(row)
 (OUT/'suite.json').write_text(json.dumps(rows,indent=2))
 print(name,mode,'PASS' if row['ok'] else 'FAIL',flush=True)
 if not row['ok']:
  print(log.read_text()[-4500:],flush=True)
  sys.exit(1)
with (OUT/'normal_entry.log').open('w') as stream:
 result=subprocess.run(['/opt/homebrew/bin/godot','--path',str(ROOT),'--quit-after','90'],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=60)
output=(OUT/'normal_entry.log').read_text()
assert result.returncode==0 and 'SCRIPT ERROR:' not in output and '\nERROR:' not in output, output
print('ALL VALIDATION COMPLETE',len(rows),'groups',flush=True)
