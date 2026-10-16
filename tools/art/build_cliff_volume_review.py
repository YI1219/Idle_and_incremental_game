"""Check and display rejected grass/contact and actual-volume studies."""
import hashlib
import json
import shutil
import struct
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'art/review/terrain_fidelity/2026-10-16/sculpt_base'
REVIEW = ROOT/'art/review/terrain_fidelity/2026-10-16/cliff_volume'
WORK = ROOT/'art/work/cliff_volume/2026-10-16'
OUT = ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
BASE = '824b931'
VIEWS = dict(close='岛缘近景', overview='全岛', far='远景', grass='草石接缝', reverse='反向', shore='池岸', bottom='底面')
TAGS = dict(grasspatch1='低宽草丛 · 原采样', grasssample1='原叶片 · 全周长采样',
    grasspatch2='低宽草丛 · 全周长采样', grasspatch3='低宽草丛 · 转角偏置',
    grasssample2='原叶片 · 世界探针', sourcevolume_control1='统一体积 · 未塑形基准',
    sourcevolume1='现有源下收并集 v1', sourcevolume2='保留肩部并集 v2', sourcevolume3='开口岩隙与小组件清理 v3')

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
scope = ['assets','scripts','shaders','scenes','tests','project.godot']
assert not git('diff','--name-only',BASE,'--',*scope).strip()
assert not git('ls-files','--others','--exclude-standard','--',*scope).strip()
evidence = {}
for tag in ['connection_control1',*TAGS]:
    data = json.loads((SOURCE/f'{tag}_captures.json').read_text())
    assert data['water_phase']==1.25 and len(data['captures'])==7
    volume = tag.startswith('sourcevolume')
    assert data['sculpt_base']==volume
    if not volume:assert data['samples']==0
    if tag!='connection_control1':
        log = (REVIEW/f'{tag}.log').read_text()
        assert 'SCULPT BASE CAPTURES: 7 samples='+str(data['samples']) in log
        assert 'SCRIPT ERROR' not in log and '\nERROR:' not in log
        if volume and data['samples']:
            assert 'SOURCE VOLUME STUDY: ordinary_loader=true samples='+str(data['samples']) in log
    cameras,images={},{}
    for entry in data['captures']:
        view=entry['file'].removeprefix(tag+'_').removesuffix('.png')
        assert view in VIEWS and entry['error']==0
        path=SOURCE/entry['file'];png=path.read_bytes()
        assert png[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',png[16:24])==(1671,941)
        cameras[view]=[entry['position'],entry['rotation']];images[view]=sha(path)
        shutil.copy2(path,OUT/path.name)
    assert set(cameras)==set(VIEWS)
    evidence[tag]=dict(cameras=cameras,images_sha256=images,data_sha256=data['data_sha256'],samples=data['samples'])
control=evidence['connection_control1']
assert all(e['cameras']==control['cameras'] for e in evidence.values())
assert all(evidence[t]['data_sha256']==control['data_sha256'] for t in TAGS if t.startswith('grass'))
baseline=json.loads((WORK/'base_save.json').read_text())
assert evidence['sourcevolume_control1']['data_sha256']==sha(WORK/'base_save.json')
volumes={}
for version,samples,components,bad in [('v1',19817,2,95),('v2',23584,3,95),('v3',23782,1,0)]:
    save=WORK/f'volume_{version}.json';payload=json.loads(save.read_text())
    report=json.loads((WORK/f'volume_{version}_report.json').read_text())
    assert payload['cells']==baseline['cells'] and len(payload['rocks'])==samples
    assert sha(save)==report['save_sha256'] and sha(WORK/'source.json')==report['source_sha256']
    assert sha(WORK/'base_save.json')==report['baseline_sha256']
    assert all(s['nonmanifold_edges']==s['degenerate_faces']==0 for s in report['sources'])
    connectivity=json.loads((REVIEW/f'connectivity_{version}.json').read_text())
    assert len(connectivity['components'])==components and connectivity['non_two_use_edges']==bad
    volumes[version]=dict(save_sha256=sha(save),samples=samples,connectivity=connectivity)
control_skin=json.loads((REVIEW/'connectivity_control.json').read_text())
assert len(control_skin['components'])==1 and control_skin['non_two_use_edges']==0
for version in ['baseline','arc','world']:
    log=(REVIEW/f'sampling_{version}.log').read_text()
    assert 'SCRIPT ERROR' not in log and '\nERROR:' not in log
    assert f'RIM SAMPLING FIXTURES: {2 if version=="world" else 0}/2' in log
report=dict(base_commit=BASE,unchanged_production=True,new_successful_native_views=63,
    reused_default_control_views=7,principal_water_clocks=1.25,live_layers=['cloud sea','waterfall mist'],
    evidence=evidence,volumes=volumes,all_eight_trials_rejected=True,
    scope='Source volume tests change saved density, not cell layout. Unified mode changes all derived geometry relative to legacy. Grass tests are render-time overrides. Neither is default/player feature acceptance. Exact v3 raw-skin closure is finite, before chunk clipping; no arbitrary edit, publication, collision, support, water routing, motion, export or performance claim.')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>云露村 · 接缝与岩体试验</title><style>body{margin:0;background:#eeece3;color:#35443e;font:16px/1.65 system-ui}main{max-width:1800px;margin:auto;padding:26px}h1{font-size:29px;font-weight:500}p{max-width:1100px}a{color:#496c59}select{font:inherit;padding:7px;margin:5px 15px 15px 3px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%}figcaption{padding:8px;background:#faf7ed}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">返回默认实景</a><h1>草石接缝与实际体积 · 全部未采用</h1><p>草丛加宽让部分裂隙更可读，但反面出现叶片排边。稳定采样通过有限功能检查，却让反面裸露更多。现有崖石烘入可编辑体积后，仍像宽墙接圆腹；加入开口岩隙、清除孤片，也没有达到目标的自然折面与连贯收底。默认场景不变。</p><label>机位<select id="view"></select></label><label>试验<select id="variant"></select></label><label>左图<select id="base"><option value="auto">相应模式基准</option><option value="connection_control1">正式默认基准</option><option value="sourcevolume_control1">统一体积基准</option></select></label><div class="pair"><figure><figcaption id="beforecaption"></figcaption><img id="before" alt="实际引擎基准"></figure><figure><figcaption id="aftercaption"></figcaption><img id="after" alt="拒绝采用的实际引擎试验"></figure></div><p>各七个匹配机位，四组水时钟固定1.25，云海和水雾仍运动。草丛五版保留默认作者数据；体积三版保留同一格子数据，加入普通存档密度样本，统一模式与正式默认的全岛衍生几何不同。小样本功能或闭合通过不等于美术通过。目标图单独保留，不混作实机成果。</p></main><script>const views=VIEWS,tags=TAGS;for(const[id,items]of [['view',views],['variant',tags]])for(const[key,label]of Object.entries(items)){const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}const v=document.getElementById('view'),t=document.getElementById('variant'),b=document.getElementById('base');t.value='sourcevolume3';function update(){let before=b.value==='auto'?(t.value.startsWith('sourcevolume')?'sourcevolume_control1':'connection_control1'):b.value;document.getElementById('before').src=before+'_'+v.value+'.png';document.getElementById('after').src=t.value+'_'+v.value+'.png';document.getElementById('beforecaption').textContent=before==='connection_control1'?'正式默认 · 前轮基准':'统一体积 · 本轮新拍基准';document.getElementById('aftercaption').textContent=tags[t.value]+' · 未采用'}v.onchange=t.onchange=b.onchange=update;update();</script></html>'''
(OUT/'cliff_volume.html').write_text(page.replace('VIEWS',json.dumps(VIEWS,ensure_ascii=False)).replace('TAGS',json.dumps(TAGS,ensure_ascii=False)))
if '--http' in sys.argv:
    pages=['cliff_volume.html','comparison.html']+[f'{tag}_{view}.png' for tag in evidence for view in VIEWS]
    for page in pages:
        with urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:18771/'+page,method='HEAD'),timeout=5) as response:assert response.status==200
    report['http_200_resources']=len(pages)
(REVIEW/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('VOLUME/GRASS EVIDENCE: 63 new successful native views, 7 reused default views; 8 trials rejected, production unchanged.')
