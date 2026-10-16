"""Actual scalar/save/skin/capture evidence for one local shoulder, not art acceptance."""
import hashlib,json,math,shutil,struct,subprocess
from collections import Counter
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2];WORK=ROOT/'art/work/actual_shoulder/2026-10-17'
LOCAL=ROOT/'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT=ROOT/'art/review/terrain_fidelity/2026-10-17/actual_shoulder'
GALLERY=ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'logs').mkdir(exist_ok=True)
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
scope=['assets','scripts','shaders','scenes','tests','project.godot']
assert not subprocess.check_output(['git','diff','--name-only','e9968db','--',*scope],cwd=ROOT).strip()
assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*scope],cwd=ROOT).strip()
source=ROOT/'art/work/rendered_join/2026-10-17/exposed_cleft/exposed_cleft_v1.json'
before=read(source);reports={};saves={}
for name,save,report in [('cut','shoulder_cut_v1.json','report.json'),('clean','shoulder_cut_clean.json','clean_report.json')]:
 r=read(WORK/report);d=read(WORK/save);reports[name]=r;saves[name]=d
 assert r['source_save_sha256']==sha(source) and r['save_sha256']==sha(WORK/save)
 assert r['source_skin_sha256']==sha(ROOT/'art/work/cliff_finish/2026-10-17/vertices.bin')
 assert r['frames_sha256']==sha(ROOT/'art/work/rendered_join/2026-10-17/crown_frames.json')
 assert len(r['along_samples'])==len(r['upper_front_samples'])==27
 assert max(abs(y-r['slope']*x-r['intercept']) for x,y in zip(r['along_samples'],r['upper_front_samples']))<.015
 assert {k:v for k,v in d.items() if k!='rocks'}=={k:v for k,v in before.items() if k!='rocks'}
 assert r['sign_nodes_added']==0 and len(d['rocks'])==r['samples']==26712
 assert all(math.isfinite(x['density']) and .002-1e-8<=abs(x['density'])<=.5 for x in d['rocks'])
BASE=ROOT/'art/work/exposed_bedrock/2026-10-17';grid=read(BASE/'source.json');lo,hi=grid['lo'],grid['hi']
nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)];base=np.fromfile(BASE/'base_nodes.bin',dtype='<f4').reshape(nz,ny,nx)
def values(d):
 v=base.astype(float).copy()
 for r in d['rocks']:v[r['z']-lo[2],r['y']-lo[1],r['x']-lo[0]]=r['density']
 return v
original=values(before);cut=values(saves['cut']);clean=values(saves['clean'])
assert np.count_nonzero(abs(cut-original)>1e-6)==reports['cut']['changed_nodes']==149
assert np.count_nonzero((original<0)&(cut>0))==reports['cut']['sign_nodes_removed']==6
assert np.all(cut>=original-1e-6)
assert np.count_nonzero(abs(clean-original)>1e-6)==reports['clean']['changed_nodes']==153
assert np.count_nonzero((original<0)&(clean>0))==reports['clean']['sign_nodes_removed']==10
changed=np.argwhere(abs(clean-cut)>1e-6)
knots=[(int(lo[0]+ix),int(lo[1]+iy),int(lo[2]+iz)) for iz,iy,ix in changed]
assert sorted(knots)==sorted(tuple(k) for k in reports['clean']['orphan_negative_knots_removed']) and len(knots)==4
for x,y,z in knots:
 assert cut[z-lo[2],y-lo[1],x-lo[0]]<0 and clean[z-lo[2],y-lo[1],x-lo[0]]>0
 for dx in [-1,0,1]:
  for dy in [-1,0,1]:
   for dz in [-1,0,1]:
    k=(x+dx,y+dy,z+dz)
    assert k in knots or cut[k[2]-lo[2],k[1]-lo[1],k[0]-lo[0]]>0
skins={name:np.fromfile(WORK/f'{version}_skin.bin',dtype='<f4').reshape(-1,3,3) for name,version in [('cut','actualshoulder'),('clean','actualshoulderclean')]}
a,b=[Counter(t.tobytes() for t in skins[name]) for name in ['cut','clean']]
removed=a-b;added=b-a
assert sum(removed.values())==96 and not added
topology={name:read(WORK/f'connectivity_{version}.json') for name,version in [('cut','actualshoulder'),('clean','actualshoulderclean')]}
assert len(topology['cut']['components'])==2 and len(topology['clean']['components'])==1
assert topology['cut']['components'][0]==topology['clean']['components'][0]
assert topology['clean']['components'][0]['signed_volume_godot_clockwise']>0
detached=topology['cut']['components'][1]
for record in removed:
 points=np.frombuffer(record,dtype='<f4').reshape(3,3)
 assert np.all(points>=np.array(detached['lo'])-1e-7) and np.all(points<=np.array(detached['hi'])+1e-7)
assert all(t['non_two_use_edges']==0 for t in topology.values())
assert reports['clean']['orphan_source_topology_sha256']==sha(WORK/'connectivity_actualshoulder.json')
metrics={};origin=np.array(reports['cut']['origin']);tangent=np.array(reports['cut']['tangent']);out=np.array(reports['cut']['outward'])
for name,t in {'before':np.fromfile(ROOT/'art/work/cliff_finish/2026-10-17/vertices.bin',dtype='<f4').reshape(-1,3,3),**skins}.items():
 center=t.mean(axis=1);cross=-np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]);area=np.linalg.norm(cross,axis=1)*.5
 normal=cross/np.maximum(2*area[:,None],1e-15);delta=center-origin;along=delta@tangent;depth=delta@out
 mask=(normal[:,1]>=.55)&(center[:,1]>=3)&(center[:,1]<3.49)&(along>=-1.35)&(along<=1)&(depth>=-.7)&(depth<=1.7)
 metrics[name]={'targeted_upward_below_cap_area':float(area[mask].sum()),'triangles':int(mask.sum())}
assert metrics['clean']==metrics['cut'] and metrics['cut']['targeted_upward_below_cap_area']<metrics['before']['targeted_upward_below_cap_area']
control=read(LOCAL/'exposed_cleft1_captures.json');captures={}
for tag,variant in [('actual_shoulder1','cut'),('actual_shoulder2','cut'),('actual_shoulder_clean1','clean')]:
 meta=read(LOCAL/f'{tag}_captures.json');cap=read(LOCAL/f'{tag}_actual_cap.json');normal=read(LOCAL/f'{tag}_field_normals.json')
 assert len(meta['captures'])==3 and meta['water_phase']==control['water_phase']==1.25 and meta['samples']==26712
 assert meta['skin_vertices_sha256']==sha(WORK/f"{'actualshoulder' if variant=='cut' else 'actualshoulderclean'}_skin.bin")
 assert cap['unsupported_anchor_samples']==cap['open_boundaries']==cap['ambiguous_junctions']==0
 assert normal['uploaded_geometry_color_uv_unchanged'] and normal['meshes_replaced']==20
 assert normal['transform_buffer_sha256_before']==normal['transform_buffer_sha256_after']
 hashes={}
 for e,c in zip(meta['captures'],control['captures']):
  assert e['position']==c['position'] and e['rotation']==c['rotation'] and e['error']==0
  p=LOCAL/e['file'];blob=p.read_bytes();assert blob[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',blob[16:24])==(1671,941)
  hashes[e['file']]=sha(p);shutil.copy2(p,GALLERY/e['file'])
 log=Path('/tmp')/f'yunlu_{tag}.log';text=log.read_text()
 assert 'Metal 3.2 - Forward+' in text and 'SCULPT BASE CAPTURES: 3' in text and 'SCRIPT ERROR' not in text and '\nERROR:' not in text
 shutil.copy2(log,OUT/'logs'/log.name)
 captures[tag]={'metadata':meta,'png_sha256':hashes,'cap':cap,'normal':normal}
first=captures['actual_shoulder1']['metadata'];second=captures['actual_shoulder2']['metadata']
assert captures['actual_shoulder1']['normal']['transform_buffer_sha256_after']==captures['actual_shoulder_clean1']['normal']['transform_buffer_sha256_after']
for key in ['data_sha256','samples','skin_vertices_sha256','skin_colors_sha256','skin_uv_sha256']:assert first[key]==second[key]
analytic=captures['actual_shoulder2']['normal']['actual_cut_plane'];assert analytic['triangles']==60 and analytic['normal_occurrences_changed']==180 and analytic['max_vertex_plane_distance']<.005
assert first['skin_normals_sha256']!=second['skin_normals_sha256']==analytic['output_normals_sha256']
checks={}
for name,version in [('cut','actualshoulder'),('clean','actualshoulderclean')]:
 r=read(WORK/('save_checks.json' if name=='cut' else 'clean_save_checks.json'))
 assert r['checks']==12 and r['failures']==0 and r['support_probes']==135 and r['support_mismatches']==0
 assert r['study']==version and r['skin_sha256_hex_algorithm']==hashlib.sha256((WORK/f'{version}_skin.bin').read_bytes().hex().encode()).hexdigest();checks[name]=r
for name in ['yunlu_actual_shoulder_bake.log','yunlu_actual_shoulder_clean_bake.log','yunlu_actual_shoulder_probe.log','yunlu_actual_shoulder_clean_probe.log','yunlu_actual_shoulder_save.log','yunlu_actual_shoulder_clean_save.log','yunlu_actual_shoulder_connectivity.log','yunlu_actual_shoulder_clean_connectivity.log']:shutil.copy2(Path('/tmp')/name,OUT/'logs'/name)
for e in control['captures']:shutil.copy2(LOCAL/e['file'],GALLERY/e['file'])
result={'new_native_local_frames':9,'reused_local_control_frames':3,'production_unchanged_from':'e9968db','reports':reports,'targeted_geometric_metrics':metrics,'cleanup_exact_triangle_difference':{'removed':96,'added':0,'all_retained_triangles_byte_identical':True},'topology':topology,'finite_edit_checks':checks,'captures':captures,'decision':'Retain cleaned cut only as an unaccepted local structural lead. Targeted grey shoulder narrows; one exact closed skin replaces inherited detached fragment. Analytic-only normals create a rectangular shading patch and are rejected. Broad wall/rounded shoulders/lower lobe remain. No default, whole/far/shore/water, arbitrary editing/leaf support/publication/picking or target-device acceptance.'}
(OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
html='''<!doctype html><meta charset="utf-8"><title>真实岩肩截面</title><style>body{margin:24px;background:#e9e7df;color:#303933;font:16px system-ui}p{max-width:1080px;line-height:1.7}select{font:inherit;padding:8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}img{width:100%}figure{margin:0}section{margin-top:24px}</style>
<h1>实际岩肩 · 局部削回研究，尚未采用</h1><p>沿真实草沿削回一块向外鼓出的岩肩，局部灰肩变窄；通过真实可编辑体积清掉一小块既有悬空岩片，主岩体三角面逐字节保留。大岩面和岛底体量仍未达到目标，默认仍为 spall_finish1。</p>
<label>左侧<select id="base"><option value="exposed_cleft1" selected>之前的局部形体</option><option value="actual_shoulder1">局部削回</option></select></label>
<label>右侧<select id="stage"><option value="actual_shoulder1">局部削回</option><option value="actual_shoulder2">纯平面法线 · 接痕，舍弃</option><option value="actual_shoulder_clean1" selected>局部削回＋清掉悬空岩片</option></select></label>
<main id="views"></main><p>9张新实机局部图，3张既有同视角对照。水体相位固定，云雾实时变化。保存/支撑/雕刻撤销重做检查通过不代表美术通过。</p>
<script>function draw(){views.innerHTML=['close','grass','reverse'].map(v=>`<section><h2>${v}</h2><div class="pair"><figure><img src="${base.value}_${v}.png"></figure><figure><img src="${stage.value}_${v}.png"></figure></div></section>`).join('')}base.onchange=stage.onchange=draw;draw()</script>'''
(GALLERY/'actual_shoulder.html').write_text(html)
print('ACTUAL SHOULDER: 9 native local frames,149+4effective knot changes,96orphan triangles removed/0added, retained triangles exact; local lead only.')
