# -*- coding: utf-8 -*-
"""Actual paired native views for the retained local stone-relief material."""
import json
from pathlib import Path
from shutil import copy2

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
REVIEW = ROOT / 'art/review/terrain_fidelity/2026-10-16/stone_spall'
REVIEW.mkdir(exist_ok=True)
VIEWS = {'close':'岛缘近景', 'overview':'全岛', 'far':'远景', 'grass':'草石交界',
         'reverse':'反向', 'shore':'池岸', 'bottom':'底面'}
TAGS = {'spall_control1':'修改前', 'spall1':'整面浅起伏 · 未采用',
        'spall2':'较宽波纹 · 拒绝', 'spall3':'局部浅剥蚀 · 试作',
        'spall_final1':'正式材质 · 当前候选'}
reports = {}
for tag in TAGS:
    report = json.loads((SOURCE / (tag+'_captures.json')).read_text())
    cameras = {}
    assert report['water_phase'] == 1.25
    for entry in report['captures']:
        assert entry['error'] == 0
        view = entry['file'].removeprefix(tag+'_').removesuffix('.png')
        assert view in VIEWS
        cameras[view] = [entry['position'], entry['rotation']]
        copy2(SOURCE / entry['file'], OUT / entry['file'])
    assert set(cameras) == set(VIEWS)
    reports[tag] = {'cameras':cameras, 'data_sha256':report['data_sha256']}
assert all(r == reports['spall_control1'] for r in reports.values())
(REVIEW / 'matched_views.json').write_text(json.dumps({
    'same_cameras_and_authoritative_data':True, 'principal_water_clocks':1.25,
    'live_layers':['cloud sea','waterfall mist'], 'evidence':reports,
    'scope':'Local stone material improvement only; unchanged geometry; not whole-art acceptance',
}, ensure_ascii=False, indent=2))
copy2(ROOT / 'art/source/visual_targets/2026-10-16/cliff_user_target.png', OUT / 'cliff_user_target.png')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>云露村 · 局部石质对照</title><style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:28px}h1{font-size:30px;font-weight:500}p{max-width:1100px}a{color:#526e5a}select{font:inherit;padding:7px;margin:8px 18px 15px 4px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%}figcaption{padding:7px;background:#f5f2e8}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">当前整岛实景</a><h1>石质 · 局部浅剥蚀</h1><p>让部分岩面出现浅剥蚀，留出较平静的大面。原石色、粗糙度与细纹基底保留；没有增加脏斑或高光。整面波纹试作没有采用。本轮没有修改岛形、树木、建筑、草边、湖水与摆放。</p><p>近景有有限石质改善，全岛和远景变化很小。宽板、横向腰带、硬草缘与独立底壳仍未解决，整体美术没有达标。</p><label>机位<select id="view"></select></label><label>右侧<select id="variant"></select></label><div class="pair"><figure><figcaption>修改前 · 实际Godot</figcaption><img id="before"></figure><figure><figcaption id="caption"></figcaption><img id="after"></figure></div><p>七个匹配机位、相同作者数据，水面／水底光纹／瀑布／泡沫四组时钟1.25。云海和水雾仍运动，不能把它们的变化算作材质改进。正式候选通过正常材质绑定加载原生纹理资源，不是只在截图工具中覆盖材质。</p><details><summary>用户认可的目标效果 · 非当前Godot截图</summary><img src="cliff_user_target.png"><p>这是当前视觉目标，形体与草石关系尚未在实景达到。</p></details></main><script>const views=VIEWS,tags=TAGS;for(const [id,items]of [['view',views],['variant',tags]])for(const[key,label]of Object.entries(items)){if(id==='variant'&&key==='spall_control1')continue;const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}const view=document.getElementById('view'),variant=document.getElementById('variant');view.value='close';variant.value='spall_final1';function update(){document.getElementById('before').src='spall_control1_'+view.value+'.png';document.getElementById('after').src=variant.value+'_'+view.value+'.png';document.getElementById('caption').textContent=tags[variant.value]+' · '+views[view.value]}view.onchange=variant.onchange=update;update();</script></html>'''
(OUT / 'stone_spall.html').write_text(page.replace('VIEWS',json.dumps(VIEWS,ensure_ascii=False)).replace('TAGS',json.dumps(TAGS,ensure_ascii=False)))
print(OUT / 'stone_spall.html')
