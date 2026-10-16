"""Validate and display finite, rejected existing-source volume studies.

Powered by Poly Haven. Original geometry and licenses are in the download
manifest; no source website raster previews are used in this review.
"""
import hashlib
import json
import shutil
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCAL = ROOT/'art/review/terrain_fidelity/2026-10-16/sculpt_base'
REVIEW = ROOT/'art/review/terrain_fidelity/2026-10-17/bedrock_local'
NEUTRAL = REVIEW.parent/'polyhaven_sources'
WORK = ROOT/'art/work/polyhaven_rocks/2026-10-17'
EXPOSED = ROOT/'art/work/exposed_bedrock/2026-10-17'
SOURCE = ROOT/'art/source/third_party/polyhaven/2026-10-17'
GALLERY = ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
BASE = '3a4c613'
TAGS = {
    'exposed_control1': '统一体积基准', 'exposed1': '旧源完整外露',
    'scannedbedrock1': '扫描石组 · 内收', 'scannedbedrock2': '扫描石组 · 外露',
    'scannedbedrock3': '扫描石组 · 正立', 'scanned_single1': '单岩体 · 拉长嵌入',
    'scanned_replace1': '单岩体 · 侧壁退让', 'scanned_fitcap1': '单岩体 · 原比例与截面接合',
}
VIEWS = dict(close='岛缘近景', grass='草石接缝', reverse='反向')

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text())
def png(path, size):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II', data[16:24]) == size
    return sha(path)
def log_ok(name, marker):
    text = (REVIEW/'logs'/name).read_text()
    assert marker in text and 'SCRIPT ERROR' not in text and '\nERROR:' not in text

scope = ['assets', 'scripts', 'shaders', 'scenes', 'tests', 'project.godot']
assert not subprocess.check_output(['git','diff','--name-only',BASE,'--',*scope],cwd=ROOT).strip()
assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*scope],cwd=ROOT).strip()
evidence = {}
for tag in TAGS:
    meta = read(LOCAL/f'{tag}_captures.json')
    assert meta['sculpt_base'] and meta['sculpt_profile'] == 'local'
    assert meta['water_phase'] == 1.25 and len(meta['captures']) == 3
    log_ok(tag+'.log', f'SCULPT BASE CAPTURES: 3 samples={meta["samples"]}')
    views = {}
    for entry in meta['captures']:
        view = entry['file'].removeprefix(tag+'_').removesuffix('.png')
        assert view in VIEWS and entry['error'] == 0
        path = LOCAL/entry['file']
        views[view] = dict(sha256=png(path,(1671,941)),position=entry['position'],rotation=entry['rotation'])
        shutil.copy2(path,GALLERY/path.name)
    assert set(views) == set(VIEWS)
    evidence[tag] = dict(views=views,samples=meta['samples'],data_sha256=meta['data_sha256'])
control = evidence['exposed_control1']
assert control['samples'] == 0
for stage in evidence.values():
    for view in VIEWS:
        assert stage['views'][view]['position'] == control['views'][view]['position']
        assert stage['views'][view]['rotation'] == control['views'][view]['rotation']

baseline = read(EXPOSED/'base_save.json')
volumes = {}
for version,tag in [('v1','scannedbedrock1'),('v2','scannedbedrock2'),('v3','scannedbedrock3'),
                    ('single','scanned_single1'),('replace','scanned_replace1'),('fitcap','scanned_fitcap1')]:
    path = WORK/f'scanned_bedrock_{version}.json'
    payload, report = read(path), read(WORK/f'scanned_bedrock_report_{version}.json')
    assert payload['cells'] == baseline['cells']
    assert len(payload['rocks']) == evidence[tag]['samples'] == report['samples']
    assert sha(path) == report['save_sha256'] and sha(ROOT/report['source']) == report['source_sha256']
    diagnostic = read(REVIEW/f'connectivity_scanned{"" if version=="v1" else "_"+version}.json')
    assert len(diagnostic['components']) == 1 and diagnostic['non_two_use_edges'] == 0
    volumes[version] = dict(samples=report['samples'],save_sha256=sha(path),raw_skin=diagnostic)
exposed = read(EXPOSED/'exposed_v1.json'); report = read(EXPOSED/'report_v1.json')
assert exposed['cells'] == baseline['cells'] and len(exposed['rocks']) == evidence['exposed1']['samples'] == report['samples']
assert sha(EXPOSED/'exposed_v1.json') == report['save_sha256']
assert sha(EXPOSED/'source.json') == report['input_sha256']

neutral = {}
for path in sorted(NEUTRAL.glob('*_views.json')):
    records = read(path); assert len(records) == 1
    record = records[0]; assert len(record['views']) == 5
    stem = path.name.removesuffix('_views.json')
    neutral[stem] = {view:png(NEUTRAL/f'{stem}_{view}.png',(1024,1024)) for view in record['views']}
assert len(neutral) == 7
for name in ['yunlu_polyhaven_boulder_source.log','yunlu_polyhaven_face_source.log',
             'yunlu_boulder01_source.log','yunlu_polyhaven_boulder_4k_fixed.log',
             'yunlu_polyhaven_face_4k_fixed.log','yunlu_boulder01_4k.log',
             'yunlu_polyhaven_boulder_closed.log']:
    log_ok(name,'CLIFF SOURCE INSPECTION: 1 sources, five views each')
assert len(list(NEUTRAL.glob('*_insideout_failed_*.png'))) == 10
manifest = read(SOURCE/'download_manifest.json'); assert len(manifest) == 3
for asset in manifest:
    assert asset['license'] == 'CC0-1.0'
    for download in asset['files']:
        blob = (ROOT/download['path']).read_bytes()
        assert len(blob) == download['bytes']
        assert hashlib.md5(blob).hexdigest() == download['md5']
        assert hashlib.sha256(blob).hexdigest() == download['sha256']
    assert sha(ROOT/asset['work_geometry']) == asset['geometry_sha256']
for refined in read(WORK/'refinement_report.json'):
    assert sha(ROOT/refined['glb']) == refined['glb_sha256']
closed = read(WORK/'namaqualand_boulder_02/closed_report.json')
assert closed['nonmanifold_edges'] == closed['reduced_nonmanifold_edges'] == closed['degenerate_faces'] == 0
assert sha(WORK/'namaqualand_boulder_02/namaqualand_boulder_02_closed_study.glb') == closed['glb_sha256']

page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>云露村 · 岩体源与接合研究</title><style>body{margin:0;background:#eeece3;color:#35443e;font:16px/1.65 system-ui}main{max-width:1800px;margin:auto;padding:26px}h1{font-size:29px;font-weight:500}p{max-width:1100px}a{color:#496c59}select{font:inherit;padding:7px;margin:5px 15px 15px 3px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%}figcaption{padding:8px;background:#faf7ed}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">返回默认实景</a><h1>岩体源与接合研究 · 均未采用</h1><p>新的真实岩体源有不均等裂面，但烘入旧山体后，仍出现遮埋、凸贴、悬挑或背面沟槽。原比例与截面接合减少沟槽，却没有解决宽墙与凸块的关系。旧源完整外露也没有改善整体。默认场景保持上一版。</p><label>机位<select id="view"></select></label><label>试验<select id="variant"></select></label><div class="pair"><figure><figcaption>统一体积基准 · 同机位</figcaption><img id="before" alt="引擎基准"></figure><figure><figcaption id="caption"></figcaption><img id="after" alt="未采用的引擎试验"></figure></div><p>这里只验证三组局部实景，四组水时钟固定1.25，云海和水雾仍运动。统一模式本身与正式默认的衍生几何不同。闭合检查只针对原始皮肤，不是编辑、支撑、整岛美术或性能验收。目标图没有混入实机结果。</p><p>岩体形状源：<a href="https://polyhaven.com/a/namaqualand_boulder_02">Namaqualand Boulder 02</a>、<a href="https://polyhaven.com/a/rock_face_02">Rock Face 02</a>、<a href="https://polyhaven.com/a/boulder_01">Boulder 01</a>，<a href="https://polyhaven.com/license">CC0</a>。Powered by Poly Haven。原件、Blender副本和来源记录保留；没有替换树木或购买资产。</p></main><script>const views=VIEWS,tags=TAGS;for(const[id,items]of [['view',views],['variant',tags]])for(const[key,label]of Object.entries(items)){if(id==='variant'&&key==='exposed_control1')continue;const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}const v=document.getElementById('view'),t=document.getElementById('variant');t.value='scanned_fitcap1';function update(){document.getElementById('before').src='exposed_control1_'+v.value+'.png';document.getElementById('after').src=t.value+'_'+v.value+'.png';document.getElementById('caption').textContent=tags[t.value]+' · 未采用'}v.onchange=t.onchange=update;update();</script></html>'''
(GALLERY/'bedrock_sources.html').write_text(page.replace('VIEWS',json.dumps(VIEWS,ensure_ascii=False)).replace('TAGS',json.dumps(TAGS,ensure_ascii=False)))
exposed_skin = read(REVIEW/'connectivity_exposed.json')
assert len(exposed_skin['components']) == 2 and exposed_skin['components'][1]['triangles'] == 24
assert exposed_skin['non_two_use_edges'] == 0
validation = dict(base_commit=BASE,unchanged_production=True,new_local_native_views=24,
    valid_neutral_native_views=35,failed_insideout_views_excluded=10,
    evidence=evidence,source_views_sha256=neutral,volumes=volumes,
    exposed_raw_skin=exposed_skin,
    all_seven_shape_trials_rejected=True,
    scope='Three local views only; no fresh whole/far/shore/bottom, motion, support, publication, arbitrary editing or target-device acceptance. Original CC0 geometry preserved; no runtime source promotion.')
(REVIEW/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n')
print('BEDROCK SOURCE EVIDENCE: 24 local + 35 neutral valid native views; 7 shape trials rejected; production unchanged.')
