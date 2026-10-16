# -*- coding: utf-8 -*-
"""Publish matched actual scene studies; never promotes an unaccepted default."""
from pathlib import Path
from shutil import copy2
import json
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
views = {'overview':'全岛', 'far':'远景', 'close':'岛缘近景', 'grass':'草石接缝', 'shore':'湖岸', 'reverse':'反向', 'bottom':'岛底'}
variants = {'smooth_rough1':'早期切面试作 · 未采用', 'smooth_polish1':'六遍柔化 · 过于圆钝', 'smooth_polish2':'两遍柔化 · 仍有尖片', 'recess_before2':'同一岩体 · 未削凹口', 'recess1':'棱面凹口 · 支撑修正前', 'recess2':'棱面凹口 · 支撑修正后'}
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
assert all(value == matched['recess_before2'] for value in matched.values()), 'Cameras must actually match'
(SOURCE / 'solid_matched_views.json').write_text(json.dumps({'same_cameras':True, 'views':views, 'variants':variants, 'camera_evidence':matched, 'art_accepted':False, 'water_phases':phases, 'mist_cloud_frozen':False}, ensure_ascii=False, indent=2), encoding='utf-8')
assert all(phase == 1.25 for phase in phases.values())
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>直接塑岩 · 凹口与收边试作</title><style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:28px}h1{font-size:30px;font-weight:500}p{max-width:1100px;color:#63736a}a{color:#526e5a}select{font:inherit;padding:7px;margin:8px 18px 15px 4px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%;border-radius:6px}figcaption{padding:4px;color:#63736a}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">默认岛屿候选</a> · <a href="sculpt_base.html">前一轮整体塑形</a><h1>直接塑岩 · 凹口与收边试作</h1><p>玩家直接推高、削低、切出岩肩和凹口；我们制作预制地形时，也使用同一套塑形操作。形状来自编辑中的岩体本身。</p><p><strong>本轮保留塑形工具和支撑修正，试作外形尚未替换默认岛屿。</strong>多遍柔化会让岩体过于圆钝；少量柔化也救不回早期削切留下的尖片。新的棱面凹口消除了局部尖片，但宽大墙面、整齐草边和底部比例仍未达到要求。</p><p>塑形削空地面后，原来的表面石块可能失去部分支撑。本轮改为检查真实底部范围：能落地的略微埋入，失去支撑的撤下。凹口前后对照都应用同一修正；“支撑修正前”仅保留为问题证据。灌木、花草也会随支撑变化。</p><label>机位<select id="view"></select></label><label>左侧<select id="before"></select></label><label>右侧<select id="after"></select></label><div class="pair"><figure><img id="left"><figcaption id="left-label"></figcaption></figure><figure><img id="right"><figcaption id="right-label"></figcaption></figure></div><p>42张实际 Godot 截图，七个机位逐项相同；水面、池底光、瀑布和岸边泡沫时钟固定为1.25，云雾仍在运动。截图展示局部方向和被舍弃的试验，不是美术完成证明。实际鼠标塑形、拾取、撤销和有限支撑检查通过；任意造型、动态水路与目标设备性能仍未验收。</p></main><script>const views=VIEWS,variants=VARIANTS;for(const [id,items] of [['view',views],['before',variants],['after',variants]]){for(const [key,label] of Object.entries(items)){const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}}const view=document.getElementById('view'),before=document.getElementById('before'),after=document.getElementById('after');view.value='close';before.value='recess_before2';after.value='recess2';function update(){for(const [image,select] of [['left',before],['right',after]]){document.getElementById(image).src=select.value+'_'+view.value+'.png';document.getElementById(image).alt=variants[select.value]+' · '+views[view.value];document.getElementById(image+'-label').textContent=variants[select.value]+' · '+views[view.value]}}view.onchange=before.onchange=after.onchange=update;update();</script></html>'''
page=page.replace('VIEWS',json.dumps(views,ensure_ascii=False)).replace('VARIANTS',json.dumps(variants,ensure_ascii=False))
(OUT / 'solid_sculpt.html').write_text(page, encoding='utf-8')
print(OUT / 'solid_sculpt.html')
