# -*- coding: utf-8 -*-
"""Publish matched actual scene studies; never promotes an unaccepted default."""
from pathlib import Path
from shutil import copy2
import json
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/sculpt_base'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
views = {'overview':'全岛', 'far':'远景', 'close':'岛缘近景', 'grass':'草石接缝', 'shore':'湖岸', 'reverse':'反向', 'bottom':'岛底'}
variants = {'clean_control1':'整理前', 'clean_stone1':'石面杂色减弱', 'clean_planes1':'恢复大面转折', 'clean_ground1':'草地与岸边整理 · 当前候选'}
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
assert all(value == matched['clean_control1'] for value in matched.values()), 'Cameras must actually match'
(SOURCE / 'clean_matched_views.json').write_text(json.dumps({'same_cameras':True, 'views':views, 'variants':variants, 'camera_evidence':matched, 'art_accepted':False, 'water_phases':phases, 'mist_cloud_frozen':False}, ensure_ascii=False, indent=2), encoding='utf-8')
assert all(phase == 1.25 for phase in phases.values())
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>画面整理 · 石质与层次</title><style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:28px}h1{font-size:30px;font-weight:500}p{max-width:1100px;color:#63736a}a{color:#526e5a}select{font:inherit;padding:7px;margin:8px 18px 15px 4px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%;border-radius:6px}figcaption{padding:4px;color:#63736a}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">默认岛屿候选</a> · <a href="sculpt_base.html">前一轮整体塑形</a><h1>减少杂乱，保留石质</h1><p>石面减轻灰褐杂斑，保留矿物纹理、细微凹凸与干燥的粗糙感。崖石大面转折更明确，草地上的碎色稍收敛；岸边过高的草叶缩小，让水面与石岸更清楚。</p><p>这是一轮克制的整理。岛形、树木、建筑与光照保持原来版本；没有用塑形试作的大墙面替换默认岛屿。重复崖块、长段草边和偏重的岛底仍未解决，不能把本轮变化当作整体美术已经完成。</p><label>机位<select id="view"></select></label><label>左侧<select id="before"></select></label><label>右侧<select id="after"></select></label><div class="pair"><figure><img id="left"><figcaption id="left-label"></figcaption></figure><figure><img id="right"><figcaption id="right-label"></figcaption></figure></div><p>28张实际 Godot 截图，七个机位逐项相同；水面、池底光、瀑布和岸边泡沫时钟固定为1.25，云雾仍在运动。四个阶段逐项叠加，方便判断哪些改变确实有用。功能检查与美术接受分开，目标设备性能仍待测。</p></main><script>const views=VIEWS,variants=VARIANTS;for(const [id,items] of [['view',views],['before',variants],['after',variants]]){for(const [key,label] of Object.entries(items)){const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}}const view=document.getElementById('view'),before=document.getElementById('before'),after=document.getElementById('after');view.value='close';before.value='clean_control1';after.value='clean_ground1';function update(){for(const [image,select] of [['left',before],['right',after]]){document.getElementById(image).src=select.value+'_'+view.value+'.png';document.getElementById(image).alt=variants[select.value]+' · '+views[view.value];document.getElementById(image+'-label').textContent=variants[select.value]+' · '+views[view.value]}}view.onchange=before.onchange=after.onchange=update;update();</script></html>'''
page=page.replace('VIEWS',json.dumps(views,ensure_ascii=False)).replace('VARIANTS',json.dumps(variants,ensure_ascii=False))
(OUT / 'clean_finish.html').write_text(page, encoding='utf-8')
print(OUT / 'clean_finish.html')
