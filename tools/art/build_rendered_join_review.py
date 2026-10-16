"""Verify and bind the local reconstruction/root studies, not art acceptance."""
import hashlib,json,math,shutil,struct,subprocess
from array import array
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/rendered_join/2026-10-17'
LOCAL=ROOT/'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT=ROOT/'art/review/terrain_fidelity/2026-10-17/rendered_join'
GALLERY=ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'logs').mkdir(exist_ok=True)
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
scope=['assets','scripts','shaders','scenes','tests','project.godot']
assert not subprocess.check_output(['git','diff','--name-only','d541513','--',*scope],cwd=ROOT).strip()
assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*scope],cwd=ROOT).strip()
source=ROOT/'art/work/rendered_island/2026-10-17/complete';source_meta=read(source/'source.json')
for c in source_meta['components']:
 assert hashlib.sha256((source/c['path']).read_bytes().hex().encode()).hexdigest()==c['sha256_hex']
reports={};saves={}
for folder,prefix in [(WORK,''),(WORK/'cap_fix','cap_')]:
 r=read(folder/'report.json');assert r['source_sha256']==sha(source/'source.json')
 assert r['ambiguous_nodes']==79710 and r['total_nodes']==1530585
 for kind in ['raw','closed']:
  p=folder/f'join_{kind}.json';d=read(p);assert sha(p)==r['versions'][kind]['sha256'];saves[prefix+kind]=d
 reports[prefix+'reconstruction']=r
for version,folder in [('v1',WORK/'crown_roots'),('v2',WORK/'crown_roots/v2'),('v3',WORK/'crown_roots/v3')]:
 r=read(folder/'report.json');p=folder/f'crown_roots_{version}.json';assert sha(p)==r['save_sha256']
 assert r['input_save_sha256']==sha(WORK/'cap_fix/join_raw.json') and r['frames_sha256']==sha(WORK/'crown_frames.json')
 assert r['source_sha256']==sha(source/'source.json') and len(r['hulls'])==3
 for h in r['hulls']:
  assert h['volume']>0 and h['assigned_triangles']>3
  for eq in h['hull_equations']:
   assert abs(math.sqrt(sum(v*v for v in eq[:3]))-1)<1e-6
   for point in h['hull_vertices']+h['section_points']+h['root_points']:
    assert sum(a*b for a,b in zip(eq[:3],point))+eq[3]<1e-5
 saves['roots_'+version]=read(p);reports['roots_'+version]=r
cleft=read(WORK/'exposed_cleft/report.json');p=WORK/'exposed_cleft/exposed_cleft_v1.json'
assert sha(p)==cleft['save_sha256'] and cleft['input_save_sha256']==sha(WORK/'crown_roots/v2/crown_roots_v2.json')
assert cleft['skin_sha256']==sha(WORK/'crown_roots/v2/crownroots2_skin.bin') and cleft['sign_nodes_added']==0
assert len(cleft['paths'])==1 and cleft['paths'][0]['upper_depth_vs_chord']<=-.05
saves['exposed_cleft']=read(p);reports['exposed_cleft']=cleft
for key,d in saves.items():
 assert d['version']==4 and d['cells']==source_meta['cells']
 assert all(math.isfinite(r['density']) and .002-1e-8<=abs(r['density'])<=.5 for r in d['rocks'])
base_path=ROOT/'art/work/exposed_bedrock/2026-10-17';grid=read(base_path/'source.json');lo,hi=grid['lo'],grid['hi'];nx,ny,nz=[hi[k]-lo[k]+1 for k in range(3)]
base=array('f');base.frombytes((base_path/'base_nodes.bin').read_bytes())
def nodes(d):return {(r['x'],r['y'],r['z']):r['density'] for r in d['rocks']}
raw=nodes(saves['cap_raw']);changes={}
for key,guard in [('cap_closed',2.5),('roots_v1',2.5),('roots_v2',1.6),('roots_v3',1.6)]:
 other=nodes(saves[key]);changed=[]
 for k in raw.keys()|other.keys():
  index=((k[2]-lo[2])*ny+k[1]-lo[1])*nx+k[0]-lo[0]
  if abs(raw.get(k,base[index])-other.get(k,base[index]))>1e-6:changed.append(k)
 assert changed and all(k[1]*.25<guard for k in changed)
 changes[key]={'changed_nodes_vs_cap_raw':len(changed),'highest_changed_node_y':max(k[1]*.25 for k in changed),'preserved_nodes_y_at_or_above':guard,'continuous_interpolation_may_reach_y':2.5 if guard==2.5 else 1.75}
root2=nodes(saves['roots_v2']);outside=nodes(saves['exposed_cleft']);diff=[]
for k in root2.keys()|outside.keys():
 index=((k[2]-lo[2])*ny+k[1]-lo[1])*nx+k[0]-lo[0]
 if abs(root2.get(k,base[index])-outside.get(k,base[index]))>1e-6:diff.append(k)
assert len(diff)==81 and all(k[1]*.25<1.5 for k in diff)
changes['exposed_cleft_vs_root2']={'changed_nodes':81,'preserved_saved_nodes_y_at_or_above':1.5}
tags={'join_raw1':'raw','join_closed1':'closed','join_rawcap1':'cap_raw','join_closedcap1':'cap_closed','crown_roots1':'roots_v1','crown_roots2':'roots_v2','crown_roots3':'roots_v3','exposed_cleft1':'exposed_cleft'}
control=read(LOCAL/'rendered_legacy_control1_captures.json');captures={}
for tag,key in tags.items():
 meta=read(LOCAL/f'{tag}_captures.json');assert len(meta['captures'])==3 and meta['water_phase']==1.25 and meta['samples']==len(saves[key]['rocks'])
 cap=read(LOCAL/f'{tag}_actual_cap.json');assert cap['unsupported_anchor_samples']==cap['open_boundaries']==cap['ambiguous_junctions']==0
 normal=read(LOCAL/f'{tag}_field_normals.json');assert normal['uploaded_geometry_color_uv_unchanged'] and normal['meshes_replaced']==20 and normal['transform_buffer_sha256_before']==normal['transform_buffer_sha256_after']
 hashes={}
 for e,c in zip(meta['captures'],control['captures']):
  assert e['position']==c['position'] and e['rotation']==c['rotation'] and e['error']==0
  p=LOCAL/e['file'];b=p.read_bytes();assert b[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',b[16:24])==(1671,941)
  hashes[e['file']]=sha(p);shutil.copy2(p,GALLERY/e['file'])
 log=Path('/tmp')/f'yunlu_{tag}.log';text=log.read_text();assert 'Metal 3.2 - Forward+' in text and 'SCULPT BASE CAPTURES: 3' in text and 'SCRIPT ERROR' not in text and '\nERROR:' not in text
 shutil.copy2(log,OUT/'logs'/log.name)
 captures[tag]={'metadata':meta,'png_sha256':hashes,'cap':cap,'normal_diagnostic':normal}
topology={}
for key,folder in [('joinclosedcap',WORK/'cap_fix'),('crownroots',WORK/'crown_roots'),('crownroots2',WORK/'crown_roots/v2'),('crownroots3',WORK/'crown_roots/v3'),('exposedcleft',WORK/'exposed_cleft')]:
 t=read(folder/f'connectivity_{key}.json');assert t['non_two_use_edges']==0
 assert len(t['components'])==(8 if key=='crownroots3' else 2)
 if key=='crownroots3':assert sum(c['signed_volume_godot_clockwise']<0 for c in t['components'])==6
 else:assert all(c['signed_volume_godot_clockwise']>0 for c in t['components'])
 topology[key]=t
checks=read(WORK/'exposed_cleft/save_checks.json')
assert checks['checks']==12 and checks['failures']==0 and checks['support_probes']==135 and checks['support_mismatches']==0 and checks['study']=='exposedcleft'
assert checks['skin_sha256_hex_algorithm']==hashlib.sha256((WORK/'exposed_cleft/exposedcleft_skin.bin').read_bytes().hex().encode()).hexdigest()
reports['finite_edit_checks']=checks
for name in ['yunlu_rendered_join_bake.log','yunlu_rendered_join_cap_bake.log','yunlu_crown_frames.log','yunlu_crown_roots_bake.log','yunlu_crown_roots2_bake.log','yunlu_crown_roots3_bake.log','yunlu_joinclosedcap_probe.log','yunlu_joinclosedcap_connectivity.log','yunlu_crown_roots_probe.log','yunlu_crown_roots_connectivity.log','yunlu_crown_roots2_probe.log','yunlu_crown_roots2_connectivity.log','yunlu_crown_roots3_probe.log','yunlu_crown_roots3_connectivity.log','yunlu_exposed_cleft_bake.log','yunlu_exposed_cleft_probe.log','yunlu_exposed_cleft_connectivity.log']:
 shutil.copy2(Path('/tmp')/name,OUT/'logs'/name)
shutil.copy2('/tmp/yunlu_exposed_cleft_save_checks.log',OUT/'logs/yunlu_exposed_cleft_save_checks.log')
for key in ['roots_v1','roots_v2','roots_v3']:
 reports[key]['hulls']=[{k:h[k] for k in ['crown','section_height','assigned_triangles','root_y_quantile','triangles','volume','outward','tangent']} for h in reports[key]['hulls']]
result={'new_native_local_frames':24,'reused_original_frames':3,'production_unchanged_from':'d541513','reports':reports,'captures':captures,'protected_node_checks':changes,'topology':topology,'decision':'No promotion. Root v2 is an unaccepted structural lead: horizontal neck corrected and left face connects to lower mass, but molded planes/grey shoulder/broad wall/right bulk and detached96tri remain. V3 bisector cuts fail with six new inward cavity shells and little useful exterior separation. One actual exposed upper cleft yields a modest central lower groove without new cavity shells; inherited orphan remains. Finite ordinary editing12/12 and135support probes pass; no full-scene/decoration/publication/performance acceptance.'}
(OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
html='''<!doctype html><meta charset="utf-8"><title>岩脚连接研究</title><style>body{margin:24px;background:#e9e7df;color:#303933;font:16px system-ui}p{max-width:1080px;line-height:1.7}select{font:inherit;padding:8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}img{width:100%}figure{margin:0}section{margin-top:24px}</style><h1>岩脚与岛底 · 局部形体研究，尚未采用</h1><p>默认仍为 spall_finish1。三向重建和整体填缝未解决分层；按原有岩块朝向连接实际下方岩体，并修正退让高度后，左侧岩面更连续。仍有过宽墙面、硬草沿和右侧悬垂体量，不能代表完成效果。整岩体交界切割产生内部空腔，舍弃；沿真实外表面接续一条已有凹缝，只获得局部改善。</p><label>左侧<select id="base"><option value="rendered_legacy_control1">原场景</option><option value="join_rawcap1">重建基线</option><option value="crown_roots1">岩脚 v1 · 横槽错误</option><option value="crown_roots2">岩脚 v2 · 局部方向</option></select></label> <label>右侧<select id="stage"><option value="join_raw1">重建初稿 · 顶面偏低</option><option value="join_closed1">小范围填合</option><option value="join_rawcap1">纠正顶面</option><option value="join_closedcap1">大范围填合</option><option value="crown_roots1">岩脚 v1 · 横槽错误</option><option value="crown_roots2" selected>岩脚 v2 · 修正连接</option><option value="crown_roots3">内部交界切割 · 舍弃</option><option value="exposed_cleft1">真实外表面凹缝 · 局部方向</option></select></label><main id="views"></main><p>24张本轮局部实机图，近景、接缝、反向；原场景3张为已有同视角对照。数据重建会改变部分装饰，法线与草沿均为工具实验。v2仍有一块96三角面脱离片；v3另产生6个朝内的封闭空腔面；外表面开槽版仍为原来的两个外向组件。功能、美术、性能分开接受。</p><script>function draw(){views.innerHTML=['close','grass','reverse'].map(v=>`<section><h2>${v}</h2><div class="pair"><figure><img src="${base.value}_${v}.png"></figure><figure><img src="${stage.value}_${v}.png"></figure></div></section>`).join('')}base.onchange=stage.onchange=draw;draw()</script>'''
(GALLERY/'rendered_join.html').write_text(html)
print('RENDERED JOIN REVIEW: 24 new native frames; eight ordinary saves; protected-node checks pass. Root v2/exterior cleft are local leads only; v3 internal cavity cuts rejected. Production unchanged.')
