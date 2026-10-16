# -*- coding: utf-8 -*-
"""Publish matched actual scene studies; never promotes an unaccepted default."""
from pathlib import Path
from shutil import copy2
import json
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
views = {'overview':'全岛', 'far':'远景', 'close':'岛缘近景', 'grass':'草石接缝', 'shore':'湖岸', 'reverse':'反向', 'bottom':'岛底'}
variants = {'cover_control1':'调整前 · 小草根垫与直立草叶', 'cover_final':'当前 · 高低外倾的原草叶'}
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
assert all(value == matched['cover_control1'] for value in matched.values()), 'Cameras must actually match'
(SOURCE / 'rim_cover_matched_views.json').write_text(json.dumps({'same_cameras':True, 'views':views, 'variants':variants, 'camera_evidence':matched, 'art_accepted':False, 'limited_contact_change_retained':True, 'water_phases':phases, 'mist_cloud_frozen':False}, ensure_ascii=False, indent=2), encoding='utf-8')
assert all(phase == 1.25 for phase in phases.values())
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>草石接缝 · 同机位实景</title><style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:28px}h1{font-size:30px;font-weight:500}p{max-width:1100px;color:#63736a}a{color:#526e5a}select{font:inherit;padding:7px;margin:8px 18px 15px 4px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%;border-radius:6px}figcaption{padding:4px;color:#63736a}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">默认岛屿候选</a> · <a href="sculpt_base.html">前一轮整体塑形</a><h1>草石接缝 · 让草叶跨过边缘</h1><p>去掉贴在边缘的小草根垫，保留原来的弯曲草叶，让每处三组草叶有直立、外倾和低伏的差异。根部留在实际草地内，压伏与岩石遮挡继续跟随建造编辑。没有给石头刷一道绿色，也没有新增独立的装饰地面。</p><p>这是有限的接缝改善：反向和湖岸近景的小圆贴片减少，部分草叶跨过草石交界；远景变化很小。采样规则不变，但去掉草根垫的限制后，实际留下的草簇可能略多。大崖面的比例、整齐草边和底部拼接感仍需继续处理。</p><label>机位<select id="view"></select></label><label>左侧<select id="before"></select></label><label>右侧<select id="after"></select></label><div class="pair"><figure><img id="left"><figcaption id="left-label"></figcaption></figure><figure><img id="right"><figcaption id="right-label"></figcaption></figure></div><p>14张实际 Godot 截图，七个机位逐项相同，水面、池底光、瀑布和岸边泡沫四个时钟固定为1.25；云雾仍在运动。不是概念图，也不代表整体美术或目标设备性能已经验收。</p></main><script>const views=VIEWS,variants=VARIANTS;for(const [id,items] of [['view',views],['before',variants],['after',variants]]){for(const [key,label] of Object.entries(items)){const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}}const view=document.getElementById('view'),before=document.getElementById('before'),after=document.getElementById('after');view.value='close';before.value='cover_control1';after.value='cover_final';function update(){for(const [image,select] of [['left',before],['right',after]]){document.getElementById(image).src=select.value+'_'+view.value+'.png';document.getElementById(image).alt=variants[select.value]+' · '+views[view.value];document.getElementById(image+'-label').textContent=variants[select.value]+' · '+views[view.value]}}view.onchange=before.onchange=after.onchange=update;update();</script></html>'''
page=page.replace('VIEWS',json.dumps(views,ensure_ascii=False)).replace('VARIANTS',json.dumps(variants,ensure_ascii=False))
(OUT / 'rim_cover.html').write_text(page, encoding='utf-8')
print(OUT / 'rim_cover.html')
