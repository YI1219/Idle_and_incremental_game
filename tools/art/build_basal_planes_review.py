"""Verify rejected lower-return experiments and bind their actual native evidence."""
import hashlib,json,math,shutil,struct,subprocess
from collections import Counter
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2];WORK=ROOT/'art/work/basal_planes/2026-10-17'
LOCAL=ROOT/'art/review/terrain_fidelity/2026-10-16/sculpt_base';OUT=ROOT/'art/review/terrain_fidelity/2026-10-17/basal_planes'
GALLERY=ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'logs').mkdir(exist_ok=True)
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
scope=['assets','scripts','shaders','scenes','tests','project.godot']
assert not subprocess.check_output(['git','diff','--name-only','1f6449f','--',*scope],cwd=ROOT).strip()
assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*scope],cwd=ROOT).strip()
source=ROOT/'art/work/actual_shoulder/2026-10-17/shoulder_cut_clean.json';original=read(source)
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17';grid=read(BASE/'source.json');lo,hi=grid['lo'],grid['hi'];nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
base=np.fromfile(BASE/'base_nodes.bin',dtype='<f4').reshape(nz,ny,nx).astype(float)
def field(d):
 v=base.copy()
 for r in d['rocks']:v[r['z']-lo[2],r['y']-lo[1],r['x']-lo[0]]=r['density']
 return v
before=field(original);control=read(LOCAL/'actual_shoulder_clean1_captures.json')
old_tri=np.fromfile(ROOT/'art/work/actual_shoulder/2026-10-17/actualshoulderclean_skin.bin',dtype='<f4').reshape(-1,3,3)
upper_before=Counter(t.tobytes() for t in old_tri if t[:,1].min()>=1.75)
results={}
for tag,version,save,report,checkfile,count,removed in [('basal_planes1','basalplanes','basal_planes_v1.json','report.json','save_checks.json',4422,972),('basal_union1','basalunion','basal_planes_union.json','union_report.json','union_save_checks.json',3238,754)]:
 r=read(WORK/report);d=read(WORK/save);v=field(d)
 assert r['source_save_sha256']==sha(source) and r['save_sha256']==sha(WORK/save)
 assert r['hulls_sha256']==sha(ROOT/'art/work/rendered_join/2026-10-17/crown_roots/v2/report.json')
 assert r['frames_sha256']==sha(ROOT/'art/work/rendered_join/2026-10-17/crown_frames.json')
 assert {k:x for k,x in d.items() if k!='rocks'}=={k:x for k,x in original.items() if k!='rocks'}
 assert len(d['rocks'])==r['samples'] and np.all(v>=before-1e-6)
 changes=np.argwhere(abs(v-before)>1e-6)
 assert len(changes)==r['changed_nodes']==count and np.all((changes[:,1]+lo[1])*.25<1.6)
 assert np.count_nonzero((before<0)&(v>0))==r['sign_nodes_removed']==removed
 assert np.count_nonzero((before>0)&(v<0))==r['sign_nodes_added']==0
 for h in r['planes']:
  assert abs(np.linalg.norm(h['new_equation'][:3])-1)<1e-8
  assert h['actual_face_area']>5 and h['crown'] in [36,37]
 raw=WORK/f'{version}_skin.bin';tri=np.fromfile(raw,dtype='<f4').reshape(-1,3,3)
 upper=Counter(t.tobytes() for t in tri if t[:,1].min()>=1.75)
 assert upper==upper_before and sum(upper.values())==72852
 topo=read(WORK/f'connectivity_{version}.json');assert len(topo['components'])==1 and topo['non_two_use_edges']==0 and topo['components'][0]['signed_volume_godot_clockwise']>0
 checks=read(WORK/checkfile);assert checks['checks']==12 and checks['failures']==0 and checks['support_probes']==135 and checks['support_mismatches']==0
 assert checks['study']==version and checks['skin_sha256_hex_algorithm']==hashlib.sha256(raw.read_bytes().hex().encode()).hexdigest()
 meta=read(LOCAL/f'{tag}_captures.json');cap=read(LOCAL/f'{tag}_actual_cap.json');normal=read(LOCAL/f'{tag}_field_normals.json')
 assert meta['samples']==len(d['rocks']) and meta['skin_vertices_sha256']==sha(raw) and len(meta['captures'])==3 and meta['water_phase']==control['water_phase']==1.25
 assert cap['unsupported_anchor_samples']==cap['open_boundaries']==cap['ambiguous_junctions']==0 and cap['grass_anchor_count']==534
 assert normal['uploaded_geometry_color_uv_unchanged'] and normal['meshes_replaced']==20 and normal['transform_buffer_sha256_before']==normal['transform_buffer_sha256_after']
 hashes={}
 for e,c in zip(meta['captures'],control['captures']):
  assert e['position']==c['position'] and e['rotation']==c['rotation'] and e['error']==0
  p=LOCAL/e['file'];blob=p.read_bytes();assert blob[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',blob[16:24])==(1671,941)
  hashes[e['file']]=sha(p);shutil.copy2(p,GALLERY/e['file'])
 log=Path('/tmp')/f'yunlu_{tag}.log';text=log.read_text();assert 'Metal 3.2 - Forward+' in text and 'SCULPT BASE CAPTURES: 3' in text and 'SCRIPT ERROR' not in text and '\nERROR:' not in text
 shutil.copy2(log,OUT/'logs'/log.name)
 results[tag]={'report':r,'skin_topology':topo,'finite_edit_checks':checks,'protected_upper_triangle_occurrences':72852,'capture':meta,'cap':cap,'normal_upload':normal,'png_sha256':hashes}
for prefix in ['basal_planes','basal_union']:
 for kind in ['bake','probe','save','connectivity']:
  p=Path('/tmp')/f'yunlu_{prefix}_{kind}.log';shutil.copy2(p,OUT/'logs'/p.name)
for e in control['captures']:shutil.copy2(LOCAL/e['file'],GALLERY/e['file'])
(OUT/'validation.json').write_text(json.dumps({'production_unchanged_from':'1f6449f','new_native_local_frames':6,'reused_control_frames':3,'results':results,'decision':'Both lower-return studies rejected. Direct plane intersection overcuts a neighbor; bounded-hull union corrects ownership but retains underside notch/broad sloping belly/right lobe. Keep actual_shoulder_clean1 only as prior unaccepted local lead. No further slope tuning; no default/whole/art/performance acceptance.'},indent=2)+'\n')
html='''<!doctype html><meta charset="utf-8"><title>岛底收束研究</title><style>body{margin:24px;background:#e9e7df;color:#303933;font:16px system-ui}p{max-width:1080px;line-height:1.7}select{font:inherit;padding:8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}img{width:100%}section{margin-top:24px}</style>
<h1>下部收束 · 两版均舍弃</h1><p>直接切面削到了相邻岩块；按实际岩块范围裁剪再合并，减轻了过切，但仍产生下缘缺口、斜腹面和右侧悬垂体量。两版均不采用，默认 spall_finish1 不变。上方72852三角面逐字节保留，不代表下部美术通过。</p>
<label>右侧<select id="stage"><option value="basal_planes1">直接切面 · 舍弃</option><option value="basal_union1" selected>实际岩体范围 · 舍弃</option></select></label><main id="views"></main>
<script>function draw(){views.innerHTML=['close','grass','reverse'].map(v=>`<section><h2>${v}</h2><div class="pair"><img src="actual_shoulder_clean1_${v}.png"><img src="${stage.value}_${v}.png"></div></section>`).join('')}stage.onchange=draw;draw()</script>'''
(GALLERY/'basal_planes.html').write_text(html)
print('BASAL REVIEW:6native local frames; two one-component skins; upper72852triangles exact; finite12/12+135probes each; both art rejected.')
