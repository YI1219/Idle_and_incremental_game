"""Bind actual local diagnostic images and unchanged production scope; no art acceptance."""
import hashlib,json,math,shutil,struct,subprocess
from array import array
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/cliff_finish/2026-10-17'
LOCAL=ROOT/'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT=ROOT/'art/review/terrain_fidelity/2026-10-17/cliff_finish'
GALLERY=ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'logs').mkdir(exist_ok=True)
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
production=['assets','scripts','shaders','scenes','tests','project.godot']
assert not subprocess.check_output(['git','diff','--name-only','480f702','--',*production],cwd=ROOT).strip()
assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*production],cwd=ROOT).strip()
baseline=read(LOCAL/'exposed_cleft1_captures.json')
planes=read(WORK/'plane_report.json');skin=read(WORK/'skin_report.json')
for attr in ['vertices','normals','colors','uv']:
 assert sha(WORK/(attr+'.bin'))==baseline['skin_'+attr+'_sha256']
assert planes['input_vertex_sha256']==sha(WORK/'vertices.bin')
assert planes['input_normal_sha256']==sha(WORK/'normals.bin')
assert planes['output_normal_sha256']==sha(WORK/'plane_normals.bin')
assert planes['original_source_sha256']==sha(ROOT/'art/work/rendered_island/2026-10-17/complete/source.json')
assert planes['root_source_sha256']==sha(ROOT/'art/work/rendered_join/2026-10-17/crown_roots/v2/report.json')
normals=array('f');normals.frombytes((WORK/'plane_normals.bin').read_bytes())
assert len(normals)==planes['vertices']*3
max_unit_error=max(abs(math.sqrt(sum(v*v for v in normals[i:i+3]))-1) for i in range(0,len(normals),3))
assert all(math.isfinite(v) for v in normals) and max_unit_error<1e-5
assert sum(planes['source_kind_counts'].values())==planes['normal_occurrences_changed']==64694
assert skin['grey_below_cap_area']>5 and skin['upward_grey_area']>6
captures={};grass={}
tags=['cliff_planes1','shoulder_clusters1','shoulder_soil1','shoulder_mats1','shoulder_mats2']
for tag in tags:
 meta=read(LOCAL/f'{tag}_captures.json')
 assert len(meta['captures'])==3 and meta['water_phase']==baseline['water_phase']==1.25
 if tag!='shoulder_soil1':
  for key in ['data_sha256','samples','skin_vertices_sha256','skin_colors_sha256','skin_uv_sha256']:
   assert meta[key]==baseline[key]
  assert meta['skin_normals_sha256']==planes['output_normal_sha256']
 cap=read(LOCAL/f'{tag}_actual_cap.json')
 assert cap['unsupported_anchor_samples']==cap['open_boundaries']==cap['ambiguous_junctions']==0
 normal=read(LOCAL/f'{tag}_field_normals.json')
 assert normal['uploaded_geometry_color_uv_unchanged'] and normal['meshes_replaced']==20
 assert normal['transform_buffer_sha256_before']==normal['transform_buffer_sha256_after']
 hashes={}
 for e,b in zip(meta['captures'],baseline['captures']):
  assert e['position']==b['position'] and e['rotation']==b['rotation'] and e['error']==0
  p=LOCAL/e['file'];blob=p.read_bytes()
  assert blob[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',blob[16:24])==(1671,941)
  hashes[e['file']]=sha(p);shutil.copy2(p,GALLERY/e['file'])
 log=Path('/tmp')/f'yunlu_{tag}.log';text=log.read_text()
 assert 'Metal 3.2 - Forward+' in text and 'SCULPT BASE CAPTURES: 3' in text
 assert 'SCRIPT ERROR' not in text and '\nERROR:' not in text
 shutil.copy2(log,OUT/'logs'/log.name)
 captures[tag]={'metadata':meta,'png_sha256':hashes,'cap':cap,'normal_diagnostic':normal,'faithful_for_art_judgment':tag not in ['shoulder_clusters1','shoulder_mats1']}
 if tag.startswith('shoulder_') and tag!='shoulder_soil1':
  r=read(LOCAL/f'{tag}_shoulder_clusters.json');grass[tag]=r
  assert r['terrain_attributes_unchanged'] and r['rejected_fans']==0
  assert r['max_root_height_error']<.01401 and len(r['anchors'])==r['fans']
  assert all(3.12<=a['height']<=3.501 and a['normal_y']>=.60 for a in r['anchors'])
  assert r['props_transform_buffer_sha256']=='2e1af498762e191538f4a90bb7c49f62e2fd015224a7a35cee9bd63b4d0e48f2'
  if tag=='shoulder_mats2':
   assert r['existing_rim_prefix_unchanged'] and r['all_source_leaf_triangles_preserved']
   assert r['uploaded_vertex_occurrences']==r['added_vertex_occurrences']==r['fans']*r['source_fan_vertex_occurrences']
   assert r['meshes_replaced']==1
for e in baseline['captures']:shutil.copy2(LOCAL/e['file'],GALLERY/e['file'])
source=ROOT/'art/work/rendered_join/2026-10-17/exposed_cleft/exposed_cleft_v1.json'
soil=read(WORK/'soil_report.json');original=read(source);filled=read(WORK/'shoulder_soil_v1.json')
assert soil['input_save_sha256']==sha(source) and soil['save_sha256']==sha(WORK/'shoulder_soil_v1.json')
assert soil['anchors_sha256']==sha(WORK/'cluster_anchors.json')
assert filled['version']==original['version']==4 and filled['cells']==original['cells']
assert len(filled['rocks'])==soil['samples']==26729
def rows(d):return {(r['x'],r['y'],r['z']):r['density'] for r in d['rocks']}
a,b=rows(original),rows(filled)
grid=read(ROOT/'art/work/exposed_bedrock/2026-10-17/source.json');lo,hi=grid['lo'],grid['hi']
nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
base=array('f');base.frombytes((ROOT/'art/work/exposed_bedrock/2026-10-17/base_nodes.bin').read_bytes())
changes=[];added=removed=0
for key in a.keys()|b.keys():
 index=((key[2]-lo[2])*ny+key[1]-lo[1])*nx+key[0]-lo[0]
 before,after=a.get(key,base[index]),b.get(key,base[index])
 if abs(before-after)>1e-6:changes.append(key)
 added+=before>0 and after<0;removed+=before<0 and after>0
assert len(changes)==soil['changed_nodes']==74 and soil['rounded_write_attempts']==79 and added==soil['added_sign_nodes']==5 and removed==0
assert all(3.0<=k[1]*.25<=3.5 for k in changes)
for name in ['yunlu_local_skin_finish.log','yunlu_local_skin_clusters.log','yunlu_cliff_plane_transfer.log','yunlu_shoulder_soil_bake.log','yunlu_shoulder_clusters1_parse_failed.log']:
 shutil.copy2(Path('/tmp')/name,OUT/'logs'/name)
failed=(OUT/'logs/yunlu_shoulder_clusters1_parse_failed.log').read_text();assert 'SCRIPT ERROR' in failed
leaf_counts={tag:{'source_vertex_occurrences_per_fan':465,'expected_source_vertex_occurrences':r['fans']*465,'generated_vertex_occurrences':r['added_vertex_occurrences']} for tag,r in grass.items()}
grass={tag:{**{k:v for k,v in r.items() if k not in ['anchors','cluster_centers']},'report_sha256':sha(LOCAL/f'{tag}_shoulder_clusters.json')} for tag,r in grass.items()}
result={'new_native_local_frames':15,'faithful_native_local_frames':9,'technically_incomplete_canopy_frames':6,'reused_local_control_frames':3,'production_unchanged_from':'480f702','plane_report':planes,'skin_report':skin,'max_normal_unit_error':max_unit_error,'soil_report':soil,'captures':captures,'grass':grass,'source_leaf_count_controls':leaf_counts,'scope':'Actual matched local near/contact/reverse only. Six sparse/initial-canopy views lost valid source leaves to terrain-sized triangle filtering and cannot reject the full-source hypothesis. Corrected mats2 preserves and uploads all original leaf triangles. No fresh whole/far/water, topology, arbitrary editing, full-leaf support, regeneration/picking or device-performance acceptance. Existing exposed-cleft orphan96tri remains inherited. All variants tool-only; no default promotion.'}
(OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
html='''<!doctype html><meta charset="utf-8"><title>岩肩连接研究</title><style>body{margin:24px;background:#e9e7df;color:#303933;font:16px system-ui}p{max-width:1080px;line-height:1.7}select{font:inherit;padding:8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}img{width:100%}figure{margin:0}section{margin-top:24px}</style>
<h1>岩肩与草沿 · 局部实验</h1><p>默认仍为 spall_finish1。本页是未采用的局部诊断：真实原岩面法线只略微加强转折；填土产生平草台和尖角，舍弃。稀疏草丛、低草初版因细碎面过滤丢失叶片，不能据此否定完整草丛；修正版保留完整原叶片，但仍未解决宽灰肩。均未达到参考图质量。</p>
<label>左侧<select id="base"><option value="exposed_cleft1">既有局部形体</option><option value="cliff_planes1" selected>原岩面法线</option></select></label>
 <label>右侧<select id="stage"><option value="cliff_planes1">原岩面法线</option><option value="shoulder_clusters1">稀疏草丛 · 叶片缺失</option><option value="shoulder_soil1">填土 · 舍弃</option><option value="shoulder_mats1">低草初版 · 叶片缺失</option><option value="shoulder_mats2" selected>低草 · 完整叶片</option></select></label>
<main id="views"></main><p>15张新实机图，其中6张叶片缺失图只作为故障证据。3张既有局部对照沿用旧图；水体相位固定，云雾仍实时变化。没有整岛推广、性能或美术通过声明。</p>

<script>function draw(){views.innerHTML=['close','grass','reverse'].map(v=>`<section><h2>${v}</h2><div class="pair"><figure><img src="${base.value}_${v}.png"></figure><figure><img src="${stage.value}_${v}.png"></figure></div></section>`).join('')}base.onchange=stage.onchange=draw;draw()</script>'''
(GALLERY/'cliff_finish.html').write_text(html)
print('CLIFF FINISH REVIEW: 9 faithful + 6 incomplete native local frames; unchanged production; no art promotion.')
