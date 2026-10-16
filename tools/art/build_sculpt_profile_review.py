# -*- coding: utf-8 -*-
"""Publish matched actual scene studies; never promotes an unaccepted default."""
from pathlib import Path
from shutil import copy2
import json
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
views = {'overview':'全岛', 'far':'远景', 'close':'岛缘近景', 'grass':'草石接缝', 'shore':'湖岸', 'reverse':'反向', 'bottom':'岛底'}
variants = {'old_body1':'旧连续体 · 未塑形', 'local_body2':'局部高度收底 · 未塑形', 'local_shoulder2':'局部直接塑形', 'local_full2':'整岛直接塑形 · 未采用'}
matched = {}
phases = {}
for variant in variants:
    report = json.loads((SOURCE / f'{variant}_captures.json').read_text())
    phases[variant] = report['water_phase']
    matched[variant] = {entry['file'].replace(variant+'_','').replace('.png',''): (entry['position'], entry['rotation']) for entry in report['captures']}
    assert set(matched[variant]) == set(views)
    assert all(entry['error'] == 0 for entry in report['captures'])
    for view in views:
        copy2(SOURCE / f'{variant}_{view}.png', OUT / f'{variant}_{view}.png')
assert all(value == matched['old_body1'] for value in matched.values()), 'Cameras must actually match'
(SOURCE / 'profile_matched_views.json').write_text(json.dumps({'same_cameras':True, 'views':views, 'variants':variants, 'camera_evidence':matched, 'art_accepted':False, 'water_phases':phases, 'mist_cloud_frozen':False}, ensure_ascii=False, indent=2), encoding='utf-8')
assert all(phase == 1.25 for phase in phases.values())
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>岩体塑形 · 同机位实景</title><style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:28px}h1{font-size:30px;font-weight:500}p{max-width:1100px;color:#63736a}a{color:#526e5a}select{font:inherit;padding:7px;margin:8px 18px 15px 4px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%;border-radius:6px}figcaption{padding:4px;color:#63736a}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">默认岛屿候选</a> · <a href="sculpt_base.html">前一轮整体塑形</a><h1>同一块岩体，直接塑造</h1><p>玩家和预制作者都直接推高、削低、切出肩部和凹口。这里比较的是同一份地面数据形成的连续岩体，不是先搭山、再自动拼石头。</p><p><strong>本轮保留工具和基础体积修正，整岛外观仍未采用。</strong>旧连续体让低地的高度拖延高地侧面的收拢；新基础体按附近地面高度收底，并保护陡高差旁的低台地。切面笔触也改为稳定的限定范围削切，重复同一笔不会继续啃蚀。整岛仍有宽大墙面、刀切草边和重复块状感，不能用功能通过代替美术验收。</p><label>机位<select id="view"></select></label><label>左侧<select id="before"></select></label><label>右侧<select id="after"></select></label><div class="pair"><figure><img id="left"><figcaption id="left-label"></figcaption></figure><figure><img id="right"><figcaption id="right-label"></figcaption></figure></div><p>28张实际 Godot 截图，七个机位逐项相同，水面、池底光、瀑布和岸边泡沫四个时钟固定为1.25；云雾仍在运动。旧连续体也不是当前默认外观；默认候选仍在首页。实际鼠标编辑、撤销、存档和有限岸石、草根、藤蔓支撑检查通过。任意玩家造型、编辑速度、雕刻后的动态水路和目标设备性能仍未验收。</p></main><script>const views=VIEWS,variants=VARIANTS;for(const [id,items] of [['view',views],['before',variants],['after',variants]]){for(const [key,label] of Object.entries(items)){const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}}const view=document.getElementById('view'),before=document.getElementById('before'),after=document.getElementById('after');view.value='close';before.value='old_body1';after.value='local_full2';function update(){for(const [image,select] of [['left',before],['right',after]]){document.getElementById(image).src=select.value+'_'+view.value+'.png';document.getElementById(image).alt=variants[select.value]+' · '+views[view.value];document.getElementById(image+'-label').textContent=variants[select.value]+' · '+views[view.value]}}view.onchange=before.onchange=after.onchange=update;update();</script></html>'''
page=page.replace('VIEWS',json.dumps(views,ensure_ascii=False)).replace('VARIANTS',json.dumps(variants,ensure_ascii=False))
(OUT / 'local_profile.html').write_text(page, encoding='utf-8')
print(OUT / 'local_profile.html')
