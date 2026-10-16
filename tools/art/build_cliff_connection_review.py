"""Evidence-only gallery. Rejected studies never replace the main preview."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/sculpt_base'
REVIEW = ROOT / 'art/review/terrain_fidelity/2026-10-16/cliff_connection'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
REVIEW.mkdir(parents=True, exist_ok=True)
VIEWS = dict(close='岛缘近景', overview='全岛', far='远景', grass='草石交界', reverse='反向', shore='池岸', bottom='底面')
TAGS = dict(connection_control1='当前默认 · 新拍基准', source_return1='源横截面延长 · 拒绝', worn1='小幅转角磨蚀 · 拒绝', worn2='重网格浅侵蚀 · 拒绝', worn2smooth='浅侵蚀＋平滑小折面 · 拒绝', worn3smooth='浅侵蚀减面 · 拒绝')
reports = {}
for tag in TAGS:
    data = json.loads((SOURCE / f'{tag}_captures.json').read_text())
    assert data['water_phase'] == 1.25 and not data['sculpt_base'] and data['samples'] == 0
    cameras = {}
    images = {}
    for entry in data['captures']:
        view = entry['file'].removeprefix(tag + '_').removesuffix('.png')
        assert entry['error'] == 0 and view in VIEWS
        image = SOURCE / entry['file']
        assert image.is_file()
        cameras[view] = [entry['position'], entry['rotation']]
        images[view] = hashlib.sha256(image.read_bytes()).hexdigest()
        shutil.copy2(image, OUT / image.name)
    assert set(cameras) == set(VIEWS)
    reports[tag] = dict(cameras=cameras, data_sha256=data['data_sha256'], images_sha256=images)
control = reports['connection_control1']
assert all(r['cameras'] == control['cameras'] and r['data_sha256'] == control['data_sha256'] for r in reports.values())
(REVIEW / 'matched_views.json').write_text(json.dumps(dict(evidence=reports, new_native_captures=42, same_cameras_and_authoritative_data=True, water_clocks=1.25, live_layers=['cloud sea', 'waterfall mist'], all_trials_rejected=True), ensure_ascii=False, indent=2) + '\n')
page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>云露村 · 崖石连接试验</title><style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:28px}h1{font-size:30px;font-weight:500}p{max-width:1100px}a{color:#526e5a}select{font:inherit;padding:7px;margin:8px 18px 15px 4px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%}figcaption{padding:7px;background:#f5f2e8}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">当前整岛实景</a><h1>崖石连接与源模型磨蚀 · 未采用的试验</h1><p>本页各方案都没有接进默认场景。下腹延长形成直墙、台阶和小三角；只磨转角收益太小；重网格浅侵蚀让近景转折更软，但没有解决上层挂板与下层托底，还增加面数。减面版另有裁切皮闭合问题。保留原来的正式候选，避免为局部变化牺牲整体。</p><label>机位<select id="view"></select></label><label>右侧<select id="variant"></select></label><div class="pair"><figure><figcaption>当前默认 · 实际Godot新拍</figcaption><img id="before" alt="当前默认实景"></figure><figure><figcaption id="caption"></figcaption><img id="after" alt="未采用试验实景"></figure></div><p>七个匹配机位，作者数据相同，四组主要水时钟1.25；云海、水雾仍运动。试验源模型和默认源模型保持分离。没有更换树、建筑、地形数据、石色或湖水设置。源横截面试验只覆盖代表段；磨蚀源试验替换四种崖壁冠部，未修改高石、低台等原有全露源模型。所有图均来自引擎；视觉目标图不混入试验。</p></main><script>const views=VIEWS,tags=TAGS;for(const [id,items]of [['view',views],['variant',tags]])for(const[key,label]of Object.entries(items)){if(id==='variant'&&key==='connection_control1')continue;const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}const view=document.getElementById('view'),variant=document.getElementById('variant');view.value='close';variant.value='worn2smooth';function update(){document.getElementById('before').src='connection_control1_'+view.value+'.png';document.getElementById('after').src=variant.value+'_'+view.value+'.png';document.getElementById('caption').textContent=tags[variant.value]+' · '+views[view.value]}view.onchange=variant.onchange=update;update();</script></html>'''
(OUT / 'cliff_connection.html').write_text(page.replace('VIEWS', json.dumps(VIEWS, ensure_ascii=False)).replace('TAGS', json.dumps(TAGS, ensure_ascii=False)))
print(OUT / 'cliff_connection.html')
