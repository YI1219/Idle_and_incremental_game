# -*- coding: utf-8 -*-
"""Publish matched actual scene studies; never promotes an unaccepted default."""
from pathlib import Path
from shutil import copy2
import json
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
views = {'overview':'全岛', 'far':'远景', 'close':'岛缘近景', 'grass':'草石接缝', 'shore':'湖岸', 'reverse':'反向', 'bottom':'岛底'}
variants = {'legacy_shoulder4':'旧版 · 当前默认', 'plain_shoulder4':'连续岛体 · 未塑形', 'shoulder4':'局部塑形试作', 'shoulder_full1':'整岛扩展试作'}
matched = {}
for variant in variants:
    report = json.loads((SOURCE / f'{variant}_captures.json').read_text())
    matched[variant] = {entry['file'].replace(variant+'_','').replace('.png',''): (entry['position'], entry['rotation']) for entry in report['captures']}
    assert set(matched[variant]) == set(views)
    assert all(entry['error'] == 0 for entry in report['captures'])
    for view in views:
        copy2(SOURCE / f'{variant}_{view}.png', OUT / f'{variant}_{view}.png')
assert all(value == matched['legacy_shoulder4'] for value in matched.values()), 'Cameras must actually match'
(SOURCE / 'shoulder_matched_views.json').write_text(json.dumps({'same_cameras':True, 'views':views, 'variants':variants, 'camera_evidence':matched, 'art_accepted':False}, ensure_ascii=False, indent=2), encoding='utf-8')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>岩体塑形 · 同机位实景</title><style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:28px}h1{font-size:30px;font-weight:500}p{max-width:1100px;color:#63736a}a{color:#526e5a}select{font:inherit;padding:7px;margin:8px 18px 15px 4px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%;border-radius:6px}figcaption{padding:4px;color:#63736a}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">默认岛屿候选</a> · <a href="sculpt_base.html">前一轮整体塑形</a><h1>直接塑造岩体 · 同机位实景</h1><p>斜肩笔触直接修改连续岩体，玩家与预制作者使用同一入口。它保留转折，下端向共同岛底收回；没有在地形外摆一圈独立模型。草地覆盖也限制在原有草地附近，新伸出的石面不会继承远处的草色。</p><p><strong>整岛试作尚未采用。</strong>局部轮廓比球形笔触明确，但整岛仍偏宽大石墙，部分面与底部关系生硬；草石接缝、水和整体气韵也未达到参考图要求。默认保持旧版。本页是28张实际 Godot 同机位截图，不是概念图，也不代表最终美术验收。</p><label>机位<select id="view"></select></label><label>左侧<select id="before"></select></label><label>右侧<select id="after"></select></label><div class="pair"><figure><img id="left"><figcaption id="left-label"></figcaption></figure><figure><img id="right"><figcaption id="right-label"></figcaption></figure></div><p>实际笔触、鼠标操作、撤销存档、闭合体积与草根支撑已验证。任意玩家造型、编辑速度、动态水路和目标设备性能仍未验收。</p></main><script>const views=VIEWS,variants=VARIANTS;for(const [id,items] of [['view',views],['before',variants],['after',variants]]){for(const [key,label] of Object.entries(items)){const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}}const view=document.getElementById('view'),before=document.getElementById('before'),after=document.getElementById('after');view.value='close';before.value='legacy_shoulder4';after.value='shoulder4';function update(){for(const [image,select] of [['left',before],['right',after]]){document.getElementById(image).src=select.value+'_'+view.value+'.png';document.getElementById(image).alt=variants[select.value]+' · '+views[view.value];document.getElementById(image+'-label').textContent=variants[select.value]+' · '+views[view.value]}}view.onchange=before.onchange=after.onchange=update;update();</script></html>'''
page=page.replace('VIEWS',json.dumps(views,ensure_ascii=False)).replace('VARIANTS',json.dumps(variants,ensure_ascii=False))
(OUT / 'shoulder_sculpt.html').write_text(page, encoding='utf-8')
print(OUT / 'shoulder_sculpt.html')
