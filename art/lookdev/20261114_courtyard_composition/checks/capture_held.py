from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
for name,seed,preset,progress in [('final_held2104',2104,0,'.29'),('final_held4242',4242,1,'.29'),('final_held913',913,2,'.29'),('final_night',7301,0,'.00')]:
 cmd=['/opt/homebrew/bin/godot','--path',str(ROOT),'--script',str((OUT/'capture.gd').relative_to(ROOT)),'--',f'--out=art/lookdev/20261114_courtyard_composition/{name}','--suite=quick',f'--seed={seed}',f'--preset={preset}',f'--progress={progress}']
 with (OUT/f'capture_{name}.log').open('w') as stream:
  subprocess.run(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=120,check=True)
 print(name,'COMPLETE',flush=True)
