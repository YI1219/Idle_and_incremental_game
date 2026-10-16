"""Bind rejected 3D-source/normal studies to actual native evidence."""
import hashlib,json,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/review/terrain_fidelity/2026-10-17/cliff_group_sources'
LOCAL=ROOT/'art/review/terrain_fidelity/2026-10-16/sculpt_base'
WORK=ROOT/'art/work/cliff_group_volume/2026-10-17'
PH=ROOT/'art/source/third_party/polyhaven/2026-10-17'
GALLERY=ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def png(p,size):
 b=p.read_bytes();assert b[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',b[16:24])==size
 return sha(p)
def log(name,marker):
 p=Path('/tmp')/name;t=p.read_text();assert marker in t and 'SCRIPT ERROR' not in t and '\nERROR:' not in t
 shutil.copy2(p,OUT/'logs'/name)
(OUT/'logs').mkdir(exist_ok=True)
for name in ['yunlu_cliff_group_fetch.log','yunlu_cliff_group_refine.log','yunlu_cliff_group_volume_bake.log','yunlu_cliff_group_volume_bake2.log','yunlu_cliff_group_source_checks.log','yunlu_cliff_group_source_checks2.log','yunlu_cliff_group2_probe.log','yunlu_cliff_group2_connectivity.log']:
 shutil.copy2(Path('/tmp')/name,OUT/'logs'/name)
scope=['assets','scripts','shaders','scenes','tests','project.godot']
assert not subprocess.check_output(['git','diff','--name-only','ac83a40','--',*scope],cwd=ROOT).strip()
assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*scope],cwd=ROOT).strip()
manifest=read(PH/'cliff_group_manifest.json');assert len(manifest)==2 and len(read(PH/'download_manifest.json'))==3
for asset in manifest:
 assert asset['license']=='CC0-1.0' and len(asset['files'])==2
 for f in asset['files']:
  p=ROOT/f['path'];b=p.read_bytes();assert p.suffix in ['.gltf','.bin'] and len(b)==f['bytes'] and sha(p)==f['sha256'] and hashlib.md5(b).hexdigest()==f['md5']
 p=ROOT/asset['work_geometry'];assert sha(p)==asset['geometry_sha256'];g=read(p)
 assert all(k not in g for k in ['materials','images','textures','samplers'])
refined=read(ROOT/'art/work/polyhaven_rocks/2026-10-17/cliff_group_refinement.json');assert len(refined)==2
for r in refined:assert sha(ROOT/r['glb'])==r['glb_sha256']
neutral={}
names={'mountainside_geometry':'yunlu_mountainside_source.log','mountainside_study_4k':'yunlu_mountainside_4k.log','namaqualand_cliff_02_geometry':'yunlu_nama_cliff_source.log','namaqualand_cliff_02_study_4k':'yunlu_nama_cliff_4k.log','closed_source':'yunlu_cliff_group_closed_source.log','closed_source_v2':'yunlu_cliff_group_closed2_source.log'}
for name,logname in names.items():
 meta=read(OUT/f'{name}_views.json');assert len(meta)==1 and len(meta[0]['views'])==5 and len(meta[0]['camera_positions'])==5
 neutral[name]={v:png(OUT/f'{name}_{v}.png',(1024,1024)) for v in meta[0]['views']}
 log(logname,'CLIFF SOURCE INSPECTION: 1 sources, five views each')
captures={};baseline=read(LOCAL/'rendered_legacy_control1_captures.json')
for tag in ['cliff_group1','cliff_group2','cliff_group2_gradient']:
 meta=read(LOCAL/f'{tag}_captures.json');assert len(meta['captures'])==3 and meta['water_phase']==1.25
 views={}
 for e,control in zip(meta['captures'],baseline['captures']):
  assert e['error']==0 and e['position']==control['position'] and e['rotation']==control['rotation']
  views[e['file']]={'sha256':png(LOCAL/e['file'],(1671,941)),'position':e['position'],'rotation':e['rotation']};shutil.copy2(LOCAL/e['file'],GALLERY/e['file'])
 captures[tag]={'metadata':meta,'views':views};log(f'yunlu_{tag}.log','SCULPT BASE CAPTURES: 3')
a,b=[captures[tag]['metadata'] for tag in ['cliff_group2','cliff_group2_gradient']]
for k in ['data_sha256','skin_vertices_sha256','skin_colors_sha256','skin_uv_sha256','samples']:assert a[k]==b[k]
assert a['skin_normals_sha256']!=b['skin_normals_sha256']
normal=read(LOCAL/'cliff_group2_gradient_field_normals.json')
assert normal['uploaded_geometry_color_uv_unchanged'] and normal['meshes_replaced']==19
assert normal['transform_buffer_sha256_before']==normal['transform_buffer_sha256_after']
base=read(ROOT/'art/work/rendered_island/2026-10-17/complete/rendered_body_complete.json');volumes={}
for version,suffix in [('v1',''),('v2','_v2')]:
 p=WORK/f'group_volume_{version}.json';d=read(p);r=read(WORK/f'report_{version}.json');c=read(WORK/f'source_checks{suffix}.json')
 assert d['version']==4 and d['cells']==base['cells'] and len(d['rocks'])==r['samples'] and sha(p)==r['save_sha256']
 assert sha(WORK/f'closed_source{suffix}.blend')==c['source_blend_sha256'] and sha(WORK/f'closed_source{suffix}.glb')==r['closed_glb_sha256']
 assert c['sampled_points']==500 and c['rays_per_point']==3 and len(c['components'])==1
 assert c['analytic_bvh_sign_mismatches']==c['analytic_direction_disagreements']==c['nonmanifold_edges']==c['degenerate_triangles']==0
 volumes[version]={'save_sha256':sha(p),'samples':r['samples'],'source_check':c,'operation':r['operation']}
topology=read(WORK/'connectivity_cliffgroup2.json')
assert len(topology['components'])==2 and topology['components'][1]['triangles']==24 and topology['non_two_use_edges']==0
superseded=OUT/'republish_normal_control';old=read(superseded/'cliff_group2_gradient_captures.json')
excluded={e['file']:png(superseded/e['file'],(1671,941)) for e in old['captures']}
result={'new_neutral_frames':30,'new_local_frames_used':9,'superseded_nonisolated_normal_frames':excluded,'neutral':neutral,'captures':captures,'volumes':volumes,'normal_control':normal,'raw_skin_v2':topology,'production_unchanged_from':'ac83a40','decision':'All art studies unaccepted; spall_finish1 remains default. Gradient control proves a substantial normal-shading contribution to staircase appearance, not adequate resolution or art acceptance. Final v2 raw skin has a detached24triangle component. No editor/support/water/whole/far/performance acceptance.'}
(OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
html='''<!doctype html><meta charset="utf-8"><title>三维崖壁组合与表面诊断</title><style>body{margin:24px;background:#e9e7df;color:#303933;font:16px system-ui}p{max-width:1000px;line-height:1.7}select{font:inherit;padding:8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}img{width:100%}figure{margin:0}section{margin-top:24px}</style><h1>三维崖壁组合 · 尚未采用</h1><p>默认画面仍为 spall_finish1。天然崖壁源经封背成为完整体积，再接入同一可编辑地形。直立版外翻、悬挂，转向版减少外翻却留下厚重斜层和突出端块。法线对照消除了大部分规则阶梯明暗，但形体与草石接缝仍不达标；还有一块24三角面的脱离片。全部不推广。</p><label>左侧<select id="base"><option value="rendered_legacy_control1">原场景</option><option value="cliff_group2">转向版 · 原法线</option></select></label> <label>右侧<select id="stage"><option value="cliff_group1">直立版</option><option value="cliff_group2">转向版</option><option value="cliff_group2_gradient" selected>转向版 · 连续法线诊断</option></select></label><main id="views"></main><p>9张正式局部实机图；另3张旧法线对照因重建道具被排除。校正后只替换岩体网格法线，上传顶点、颜色、UV以及场景变换和实例缓冲均保持一致。云雾实时，四项水钟固定。30张天然源灰模另存为来源检查，不代表成品接受。</p><script>function draw(){views.innerHTML=['close','grass','reverse'].map(v=>`<section><h2>${v}</h2><div class="pair"><figure><img src="${base.value}_${v}.png"></figure><figure><img src="${stage.value}_${v}.png"></figure></div></section>`).join('')}base.onchange=stage.onchange=draw;draw()</script>'''
(GALLERY/'cliff_groups.html').write_text(html)
print('CLIFF GROUP REVIEW: 30 neutral +9 formal local frames; 3 superseded normal frames excluded. Both source500x3 fixtures pass; final skin2components, all art unaccepted; production unchanged.')
