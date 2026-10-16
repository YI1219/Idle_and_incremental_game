# -*- coding: utf-8 -*-
"""Present actual water-material comparisons with checked camera/phase metadata."""
import json
import sys

CLEAN = "--clean" in sys.argv
from pathlib import Path
from shutil import copy2

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/water_surface'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
VIEWS = {'shore': '上池湖岸', 'grazing': '贴近水面', 'lower': '下池水面',
         'cascade': '近处瀑布', 'outer_fall': '外侧瀑布', 'reverse': '反向湖岸', 'overview': '全岛'}
reports = {}
pairs = [('clean_water_before', 'water_clean_before'), ('clean_water25', 'water_clean_close')] if CLEAN else [('water_before', 'surface_before'), ('water_final', 'surface_close')]
for tag, prefix in pairs:
    report = json.loads((SOURCE / f'{tag}_captures.json').read_text())
    cameras = {}
    for entry in report['captures']:
        assert entry['error'] == 0, entry
        view = entry['file'].removeprefix(tag + '_').removesuffix('.png')
        assert view in VIEWS, view
        cameras[view] = [entry['position'], entry['rotation']]
        copy2(SOURCE / entry['file'], OUT / f'{prefix}_{view}.png')
    assert set(cameras) == set(VIEWS)
    reports[tag] = {'cameras': cameras, 'water_phase': report['water_phase']}
assert reports[pairs[0][0]] == reports[pairs[1][0]], 'Actual camera/water clocks must match'
(SOURCE / ('clean_matched_views.json' if CLEAN else 'matched_views.json')).write_text(json.dumps({
    'same_cameras_and_principal_water_clocks': True,
    'unfrozen_layers': ['waterfall mist', 'cloud sea'],
    'evidence': reports, 'full_art_accepted': False,
}, ensure_ascii=False, indent=2), encoding='utf-8')
options = ''.join(f'<option value="{key}">{label}</option>' for key, label in VIEWS.items())
page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>云露村 · 湖水与瀑布实景对照</title>
<style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:28px}h1{font-size:30px;font-weight:500}p{max-width:1100px;color:#63736a}a{color:#526e5a}select{font:inherit;padding:7px;margin:8px 18px 15px 4px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%;border-radius:6px}figcaption{padding:4px;color:#63736a}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style>
<main><a href="comparison.html">当前全岛候选</a> · <a href="shoulder_sculpt.html">直接塑形试作</a><h1>湖水与瀑布 · 同机位实景</h1>
<p>池底的多边形网纹改为断续弯曲的水光；瀑布条纹疏密变宽并略有摆动，落水涟漪留出较大的断口。反射在接近水线和追踪不确定处渐弱，岸边湿土有少量露出的草土碎斑。</p>
<p>这是有限改善：大片倒影、瀑布的幕布形态、岸线几何和草石交界仍需继续处理。岛形、树木、建筑、摆放和灯光未修改。整岛美术尚未验收。</p>
<label>机位 <select id="view">OPTIONS</select></label><div class="pair"><figure><img id="left"><figcaption>修改前</figcaption></figure><figure><img id="right"><figcaption>当前水体候选</figcaption></figure></div>
<p>14张图片均为实际 Godot 截图，机位及水面、水底光纹、瀑布、泡沫四组时钟一致。未改动的水雾和云海仍在运动，因此不应把其差异算作本轮改进。近景检查、编辑再生成、美术和目标设备性能分别验收；当前只是水体候选。</p></main>
<script>const view=document.getElementById('view');view.value='lower';function update(){for(const [id,prefix] of [['left','surface_before'],['right','surface_close']]){const img=document.getElementById(id);img.src=prefix+'_'+view.value+'.png';img.alt=view.options[view.selectedIndex].text+' · '+(id==='left'?'修改前':'当前水体候选')}}view.onchange=update;update();</script></html>'''
if CLEAN:
    page = page.replace('surface_before','water_clean_before').replace('surface_close','water_clean_close').replace(
        '池底的多边形网纹改为断续弯曲的水光；瀑布条纹疏密变宽并略有摆动，落水涟漪留出较大的断口。反射在接近水线和追踪不确定处渐弱，岸边湿土有少量露出的草土碎斑。',
        '减弱水面过强的白色高光，让近岸阴影和池底深浅更清楚。水波、岸边倒影、池底水光和瀑布表现保留；没有将水面改成无反光的平涂。')
(OUT / ('water_clean.html' if CLEAN else 'water_surface.html')).write_text(page.replace('OPTIONS', options), encoding='utf-8')
print(OUT / ('water_clean.html' if CLEAN else 'water_surface.html'))
