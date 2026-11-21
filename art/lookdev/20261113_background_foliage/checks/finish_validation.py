from pathlib import Path
import subprocess,json,time,hashlib
p=Path('art/lookdev/20261113_background_foliage/checks')
godot='/Applications/Godot.app/Contents/MacOS/Godot'
rows=[]
for size in ['2k','4k']:
 for i,variant in enumerate(['base','bg','bg','base']):
  name=f'visible_{size}_{i}_{variant}';out=p/(name+'.json')
  with (p/(name+'.log')).open('w') as f:
   r=subprocess.run([godot,'--path','.','--script',str(p/'runtime_final.gd'),'--','--size='+size,'--variant='+variant,'--out=res://'+str(out)],stdout=f,stderr=subprocess.STDOUT,timeout=50)
  if r.returncode or not out.exists():raise RuntimeError(name+' failed')
  row=json.loads(out.read_text());row['file']=out.name
  if abs(row['rendered_frames']-row['idle_frames'])>1:raise RuntimeError(name+' skipped rendering')
  rows.append(row);(p/'runtime_final.json').write_text(json.dumps(rows,indent=2));print(name,round(row['fps'],2),'FPS',flush=True)
print('BENCHMARKS COMPLETE',flush=True)
old=Path('art/lookdev/20261113_render_work/checks')
headless=[x['test'] for x in json.loads((old/'headless_suite.json').read_text())['rows']]
native=['tests/'+x['test']+'.gd' for x in json.loads((old/'native_suite.json').read_text())]+['tests/background_renderer_test.gd']
tests=[]
for headless_mode,paths in [(True,headless),(False,native)]:
 for path in paths:
  name=Path(path).stem;start=time.time()
  with (p/('test_'+name+'.log')).open('w') as f:
   r=subprocess.run([godot,'--path','.']+(['--headless'] if headless_mode else [])+['--script',path],stdout=f,stderr=subprocess.STDOUT,timeout=100)
  log=(p/('test_'+name+'.log')).read_text();ok=r.returncode==0 and 'SCRIPT ERROR:' not in log and '\nERROR:' not in log
  tests.append({'test':path,'headless':headless_mode,'ok':ok,'exit':r.returncode,'seconds':round(time.time()-start,2)});(p/'suite.json').write_text(json.dumps(tests,indent=2))
  print(name,'PASS' if ok else 'FAIL',flush=True)
  if not ok:raise RuntimeError(name+' failed')
with (p/'normal_entry.log').open('w') as f:
 r=subprocess.run([godot,'--path','.','--quit-after','90'],stdout=f,stderr=subprocess.STDOUT,timeout=60)
if r.returncode:raise RuntimeError('normal entry failed')
print('ALL VALIDATION COMPLETE',flush=True)
