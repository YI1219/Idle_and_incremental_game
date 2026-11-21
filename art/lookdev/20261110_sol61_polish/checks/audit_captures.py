from pathlib import Path
from PIL import Image
import hashlib,json
b=Path(__file__).resolve().parents[1];root=b.parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
pairs=[('00_approved_day','01_planted_junction_day',{'res://scripts/terrain_editor/grass_lip_soften.gd','res://shaders/terrain_editor/ground.gdshader'}),('01_planted_junction_day','02_path_contact_day',{'res://shaders/terrain_editor/cliff_rock.gdshader'}),('02_path_contact_day','03_cliff_rhythm_day',{'res://scripts/terrain_editor/procedural_shard.gd'}),('03_cliff_rhythm_day','04_planar_roots_day',{'res://scripts/terrain_editor/procedural_shard.gd'}),('04_planar_roots_day','06_final_day',{'res://scripts/terrain_editor/contour_terrain.gd','res://scripts/terrain_editor/waterfall_mist.gd','res://shaders/terrain_editor/waterfall.gdshader','res://shaders/terrain_editor/waterfall_mist.gdshader'})]
records=[]
for before,after,allowed in pairs:
 a=json.loads((b/before/'captures.json').read_text());d=json.loads((b/after/'captures.json').read_text())
 common=set(a['source_sha256'])&set(d['source_sha256']);changes={k for k in common if a['source_sha256'][k]!=d['source_sha256'][k]};ops=changes&{'res://project.godot','res://tools/art/capture_lookdev.gd'};visual=changes-ops
 assert visual==allowed,(after,visual,allowed)
 assert a['captures']==d['captures'],after
 assert a['data_sha256']==d['data_sha256'],after
 records.append({'before':before,'after':after,'visual_source_changes':sorted(visual),'operational_source_changes':sorted(ops),'capture_conditions_identical':True,'authoritative_data_identical':True})
protected=['scripts/terrain_editor/terrain_environment.gd','shaders/terrain_editor/stone_surface.gdshaderinc','scripts/terrain_editor/stone_normals.gd','scripts/gameplay/systems/time_solar_system.gd']
before=json.loads((b/'checks/source_before/sources.json').read_text())
for f in protected:assert sha(root/f)==before['res://'+f],f
final_groups=['06_final_day','06_final_night','held_seed_2104','held_seed_4242','held_seed_913']
groups=['00_approved_day','00_approved_night','01_planted_junction_day','02_path_contact_day','03_cliff_rhythm_day','04_planar_roots_day']+final_groups
native_count=0
for group in groups:
 d=json.loads((b/group/'captures.json').read_text());assert d['valid'] and d['actor_absent'] and d['house_absent'] and d['f11_handled'] and d['single_scene_capture'] and not d['user_layouts_accessed'] and d['data_unchanged'] and d['sources_unchanged'],group
 for c in d['captures']:assert Image.open(b/group/c['file']).size==(2560,1440);native_count+=1
 if group in final_groups:
  for f,h in d['source_sha256'].items():
   if f!='res://project.godot':assert sha(root/f.removeprefix('res://'))==h,(group,f)
assert native_count==55,native_count
result={'baseline_accepted_by_user':True,'new_polish_art_accepted':False,'retained_native_2k_frames':native_count,'pairs':records,'protected_sources_unchanged':protected,'final_capture_sources_match_production_except_temporary_run_args':True,'groups':groups}
(b/'checks/capture_audit.json').write_text(json.dumps(result,indent=2)+'\n');print('55 native frames, 5 isolated defect pairs and protected rock/light sources verified')
