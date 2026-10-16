"""Finite evidence for rejected side-envelope and retained-body studies."""
import hashlib
import json
import shutil
import struct
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
LOCAL=ROOT/'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT=ROOT/'art/review/terrain_fidelity/2026-10-17/cliff_face_replacement'
FACE=ROOT/'art/work/cliff_face_replacement/2026-10-17'
BODY=ROOT/'art/work/rendered_island/2026-10-17'
GALLERY=ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
TAGS={
 'rendered_legacy_control1':'原场景主体基准',
 'face_replacement1':'旧源前表面替换', 'face_replacement2':'旧源上段与连续下返',
 'face_scan1':'扫描面原朝向', 'face_scan2':'扫描面刚性转向',
 'face_scan3':'扫描面回接原统一底', 'face_scan4':'扫描面等比放大',
 'face_scan5':'扫描面竖向与端部渐接', 'face_scan6_bare':'保留顶缘起伏 · 裸面',
 'face_scan6_cap':'实际轮廓草盖 · 两扇', 'face_scan6_leaf':'实际轮廓草盖 · 原三扇',
 'rendered_body1':'原主体 · 不可靠绕数转换',
 'rendered_envelope1':'原主体 · 竖向填实',
 'rendered_envelopecap1':'原主体 · 填实与均匀草顶距离',
 'rendered_complete1':'含高出露岩的局部转换',
 'retained_return1':'连续下返 · 船腹感加重，舍弃',
}
VIEWS={'close':'岛缘近景','grass':'草石接缝','reverse':'反向'}
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def check_png(p):
 b=p.read_bytes();assert b[:8]==b'\x89PNG\r\n\x1a\n'
 assert struct.unpack('>II',b[16:24])==(1671,941)
 return sha(p)

OUT.mkdir(parents=True,exist_ok=True);(OUT/'logs').mkdir(exist_ok=True)
for pattern in ['yunlu_face*.log','yunlu_rendered*.log','yunlu_retained*.log']:
 for p in Path('/tmp').glob(pattern):shutil.copy2(p,OUT/'logs'/p.name)
scope=['assets','scripts','shaders','scenes','tests','project.godot']
assert not subprocess.check_output(['git','diff','--name-only','f7ccc00','--',*scope],cwd=ROOT).strip()
assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*scope],cwd=ROOT).strip()
captures={}
for tag in TAGS:
 meta=read(LOCAL/f'{tag}_captures.json');assert len(meta['captures'])==3 and meta['water_phase']==1.25
 assert meta['sculpt_base']==(tag!='rendered_legacy_control1')
 logname='yunlu_rendered_envelope1_metal.log' if tag=='rendered_envelope1' else f'yunlu_{tag}.log'
 log=(OUT/'logs'/logname).read_text()
 assert 'Metal 3.2 - Forward+' in log and 'SCULPT BASE CAPTURES: 3' in log
 assert 'SCRIPT ERROR' not in log and '\nERROR:' not in log
 views={}
 for entry in meta['captures']:
  view=entry['file'].removeprefix(tag+'_').removesuffix('.png');assert view in VIEWS and entry['error']==0
  p=LOCAL/entry['file'];views[view]={'sha256':check_png(p),'position':entry['position'],'rotation':entry['rotation']}
  shutil.copy2(p,GALLERY/p.name)
 assert set(views)==set(VIEWS)
 captures[tag]={'views':views,'data_sha256':meta['data_sha256'],'samples':meta['samples']}
baseline=captures['rendered_legacy_control1'];assert baseline['samples']==0
for stage in captures.values():
 for view in VIEWS:
  for key in ['position','rotation']:assert stage['views'][view][key]==baseline['views'][view][key]
for tag in ['face_scan6_bare','face_scan6_cap','face_scan6_leaf']:
 meta=read(LOCAL/f'{tag}_captures.json')
 assert meta['data_sha256']==captures['face_scan6_bare']['data_sha256']
 for key in ['skin_vertices_sha256','skin_normals_sha256']:
  assert meta[key]==read(LOCAL/'face_scan6_bare_captures.json')[key]
for tag in ['face_scan6_cap','face_scan6_leaf','rendered_envelopecap1']:
 cap=read(LOCAL/f'{tag}_actual_cap.json')
 assert cap['loops']==2 and cap['open_boundaries']==cap['ambiguous_junctions']==cap['unsupported_anchor_samples']==0
failed=read(LOCAL/'face_scan6_actual_cap.json');assert failed['loops']==143
failed_images={e['file']:check_png(LOCAL/e['file']) for e in read(LOCAL/'face_scan6_captures.json')['captures']}
base=read(ROOT/'art/work/exposed_bedrock/2026-10-17/base_save.json')
saves={}
for version,tag in [('v1','face_replacement1'),('v2','face_replacement2'),('scan','face_scan1'),('scan2','face_scan2'),('scan3','face_scan3'),('scan4','face_scan4'),('scan5','face_scan5'),('scan6','face_scan6_leaf')]:
 p=FACE/f'face_replacement_{version}.json';payload=read(p);report=read(FACE/f'report_{version}.json')
 assert payload['version']==4 and payload['cells']==base['cells'] and len(payload['rocks'])==report['samples']==captures[tag]['samples']
 assert sha(p)==report['save_sha256']
 if 'scan_source' in report:assert sha(ROOT/report['scan_source'])==report['scan_sha256']
 saves[version]={'sha256':sha(p),'samples':report['samples'],'operation':report['operation']}
body_source=read(BODY/'source.json');assert len(body_source['components'])==48 and body_source['cells']==base['cells']
for c in body_source['components']:
 assert hashlib.sha256((BODY/c['path']).read_bytes().hex().encode()).hexdigest()==c['sha256_hex']
for version in ['v1','closed','envelope','envelopecap']:
 p=BODY/f'rendered_body_{version}.json';payload=read(p);report=read(BODY/f'report_{version}.json')
 assert payload['version']==4 and payload['cells']==base['cells'] and len(payload['rocks'])==report['samples'] and sha(p)==report['save_sha256']
 assert sha(BODY/'source.json')==report['source_sha256']
 saves['body_'+version]={'sha256':sha(p),'samples':report['samples'],'operation':report['operation']}
complete=BODY/'complete';full_source=read(complete/'source.json')
assert full_source['outcrops_included'] and len(full_source['components'])==62
assert full_source['components'][:48]==body_source['components']
for c in full_source['components']:
 assert hashlib.sha256((complete/c['path']).read_bytes().hex().encode()).hexdigest()==c['sha256_hex']
full=read(complete/'rendered_body_complete.json');full_report=read(complete/'report_complete.json')
returned=read(complete/'retained_return_v1.json');return_report=read(complete/'retained_return_report_v1.json')
assert full['cells']==returned['cells']==base['cells'] and full['version']==returned['version']==4
assert sha(complete/'source.json')==full_report['source_sha256']
for version,payload,report,filename,tag in [('complete',full,full_report,'rendered_body_complete.json','rendered_complete1'),('return',returned,return_report,'retained_return_v1.json','retained_return1')]:
 assert len(payload['rocks'])==report['samples']==captures[tag]['samples']
 assert sha(complete/filename)==report['save_sha256']
 saves['body_'+version]={'sha256':sha(complete/filename),'samples':report['samples'],'operation':report['operation']}
assert return_report['input_save_sha256']==full_report['save_sha256']
full_rows={(r['x'],r['y'],r['z']):r['density'] for r in full['rocks']}
return_rows={(r['x'],r['y'],r['z']):r['density'] for r in returned['rocks']}
for key in full_rows.keys()|return_rows.keys():
 if key[1]>=6 or key[1]<=-14:assert full_rows.get(key)==return_rows.get(key)
for tag in ['rendered_complete1','retained_return1']:
 cap=read(LOCAL/f'{tag}_actual_cap.json')
 assert cap['loops']==2 and cap['grass_anchor_count']==557 and cap['unsupported_anchor_samples']==0
diag=read(BODY/'ray_diagnostic.json')
assert diag['bad_adjacent_winding']==diag['nonmanifold_edges']==0
for raw,analytic in zip(diag['traces'][3:5],diag['analytic_traces'][3:5]):
 assert raw['point']==analytic['point']==[-15,2,0]
 assert raw['winding']==1 and analytic['winding']==0 and len(analytic['hits'])==2
 assert abs(analytic['hits'][0]['distance']-analytic['hits'][1]['distance'])<1e-10
 assert analytic['hits'][0]['signed_dot']*analytic['hits'][1]['signed_dot']<0
connectivity={}
for name in ['scan3','scan6','renderedenvelopecap']:
 report=read(OUT/f'connectivity_{name}.json')
 assert len(report['components'])==1 and report['non_two_use_edges']==0
 connectivity[name]=report
save_checks=[read(OUT/'save_checks.json'),read(BODY/'save_checks_renderedenvelopecap.json')]
for r in save_checks:assert r['checks']==12 and r['failures']==0 and r['support_probes']==135 and r['support_mismatches']==0
manifest={'valid_native_frames':48,'failed_cap_frames':failed_images,'captures':captures,'saves':saves,
 'source_sha256':sha(BODY/'source.json'),'connectivity':connectivity,'save_checks':save_checks,
 'production_paths_unchanged_from':'f7ccc00','decision':'All shape studies unaccepted; default remains spall_finish1. No whole/far/shore/bottom, arbitrary editor or performance acceptance.',
 'limitations':'Tool-only cap color/grass override. Original body source excludes outcrops; separate complete source adds all14, but density replacement remains local and unified mode changes some decoration placement. Vertical envelope fills visible overhang air too; not exact CSG or shape preservation. Closed source ray classifier is disproven by independent analytic intersections. Return trial fills a broad hull and is rejected. Clouds/mist live, four principal water clocks fixed.'}
(OUT/'validation.json').write_text(json.dumps(manifest,indent=2)+'\n')
options=''.join(f'<option value="{tag}">{label}</option>' for tag,label in TAGS.items())
html='''<!doctype html><meta charset="utf-8"><title>岛侧与原岩体试验</title>
<style>body{margin:24px;background:#eae8e0;color:#303a36;font:16px system-ui}select{font:inherit;padding:8px}section{margin:24px 0}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}img{width:100%;display:block}figure{margin:0}p{max-width:1000px;line-height:1.7}</style>
<h1>岛侧与原岩体试验 · 均未推广</h1><p>左侧是当前原场景；右侧为未接受的局部试验。前期侧面试验使用另一种更圆的统一基底，不能当作原场景保形修改。原主体第一批转换未含高出露岩；后补完整源恢复了局部高岩，但草木位置仍有变化。填实修掉草顶方格，仍有灰肩、叠底和排草问题。连续下返反而加重船腹感，舍弃。主效果仍为 spall_finish1。</p>
<select id="stage">OPTIONS</select><main id="views"></main>
<p>均为 Godot Metal 实机，固定相机及四项水体时钟；云雾实时。48张有效局部截图，另3张失败草盖记录排除。只有有限保存、支撑和拓扑检查；不代表完整编辑、美术或性能接受。</p>
<script>const labels=LABELS, views=VIEWS;stage.value='rendered_complete1';function draw(){document.querySelector('#views').innerHTML=Object.entries(views).map(([v,n])=>`<section><h2>${n}</h2><div class="pair"><figure><img src="rendered_legacy_control1_${v}.png"><figcaption>原场景</figcaption></figure><figure><img src="${stage.value}_${v}.png"><figcaption>${labels[stage.value]}</figcaption></figure></div></section>`).join('')}stage.onchange=draw;draw()</script>'''.replace('OPTIONS',options).replace('LABELS',json.dumps(TAGS,ensure_ascii=False)).replace('VIEWS',json.dumps(VIEWS,ensure_ascii=False))
(GALLERY/'face_replacement.html').write_text(html)
print('FACE REPLACEMENT REVIEW: 48 valid native frames, 3 failed cap frames excluded; 14 saves; 2 finite save fixtures; production unchanged; all art studies unaccepted.')
