from pathlib import Path
from PIL import Image
import json,hashlib,re,subprocess
root=Path(__file__).resolve().parents[1];project=root.parents[2]
folders=['waterfall_before_day','final_day','final_night','held2104','held4242','held913']
reports={name:json.loads((root/name/'captures.json').read_text()) for name in folders}
assert all(x['valid'] and x['actor_absent'] and x['house_absent'] and x['f11_handled'] and x['data_unchanged'] and x['sources_unchanged'] for x in reports.values())
a=reports['waterfall_before_day'];b=reports['final_day']
assert a['data_sha256']==b['data_sha256']
for x,y in zip(a['captures'],b['captures']):
 for key in x:
  if key not in ['waterfall_variant']:assert x[key]==y[key],(x['file'],key,x[key],y.get(key))
for name in ['interaction_ready','water_evolution_review','controls_review']:
 p={'interaction_ready':'interaction.json','water_evolution_review':'water_evolution.json','controls_review':'controls.json'}[name]
 x=json.loads((root/name/p).read_text());assert x['valid'] and x['sources_unchanged']
evo=json.loads((root/'water_evolution_review/water_evolution.json').read_text());assert evo['geometry_unchanged'] and max(abs(x['balance_error']) for x in evo['samples'])<1e-8
checks=json.loads((root/'checks/test_results.json').read_text());assert all(x['clean'] for x in checks)
images=0
for name in folders+['interaction_ready','water_evolution_review','controls_review','wallpapers']:
 for file in (root/name).glob('*.png'):
  with Image.open(file) as im:assert im.size==(2560,1440),(file,im.size);im.verify()
  images+=1
protected={}
previous=json.loads((root.parent/'20261110_waterfall_cavity/03_fixed_day/captures.json').read_text())['source_sha256']
for path in ['scripts/terrain_editor/terrain_environment.gd','scripts/gameplay/systems/time_solar_system.gd','scripts/terrain_editor/stone_normals.gd','shaders/terrain_editor/stone_surface.gdshaderinc']:
 digest=hashlib.sha256((project/path).read_bytes()).hexdigest();assert previous['res://'+path]==digest,path
 protected[path]=digest
# Final F11 images predate a later pointer-only correction. The capture disables
# editor processing and never calls the changed input methods. Keep exact hashes
# instead of pretending the stills were regenerated after that input fix.
source_differences={}
for name in folders[1:]:
 changed=[]
 for path,digest in reports[name]['source_sha256'].items():
  actual=hashlib.sha256((project/path.removeprefix('res://')).read_bytes()).hexdigest()
  if digest!=actual:changed.append(path)
 assert set(changed)<= {'res://scripts/terrain_editor/editor.gd'},(name,changed)
 source_differences[name]=changed
report={'valid':True,'native_2k_frames_in_review':images,'paired_cameras_lighting_data_equal':True,'all_native_capture_jobs_valid':True,'regression_groups':len(checks),'regressions_clean':True,'protected_sources_unchanged':protected,'water_balance_max_error':max(abs(x['balance_error']) for x in evo['samples']),'post_capture_input_only_source_changes':source_differences,'notes':['Final F11 stills disable editor processing; later editor.gd correction is confined to pointer anchoring. interaction_ready captures and tests cover the final pointer code.','Browser rendered preview not performed; page resource/state validation is separate.'],'art_accepted':False}
(root/'checks/validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
r=subprocess.run(['node',str(root/'checks/validate_page.js')],capture_output=True,text=True);assert r.returncode==0,r.stdout+r.stderr
report['page_states']=json.loads(r.stdout);(root/'checks/validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ['protected_sources_unchanged','post_capture_input_only_source_changes','notes']},ensure_ascii=False))
