# -*- coding: utf-8 -*-
"""Show rejected native studies separately from the unchanged default preview."""
import json
from pathlib import Path
from shutil import copy2

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/sculpt_base'
REVIEW = ROOT / 'art/review/terrain_fidelity/2026-10-16/cliff_return'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
VIEWS = {'close':'岛缘近景','overview':'全岛','far':'远景','grass':'草石','reverse':'反向','shore':'湖岸','bottom':'底面'}
VARIANTS = {'return_control1':'保留的默认形体','return_tall1':'收脚副本 · 拒绝',
            'earlyshape1':'早期形体搭配当前材质 · 拒绝','mass_control1':'连续体基础 · 未接受',
            'mass1':'重塑两块主体 · 拒绝','mass2':'追加切面 · 拒绝',
            'compact_body1':'短底试作 · 拒绝','compact_mass1':'短底与主体 · 拒绝',
            'honest_norm1':'去底部法线偏置 · 拒绝','honest_ao1':'去附加AO · 未保留','honest_both1':'两项着色去除 · 拒绝'}
evidence = {}
for tag in VARIANTS:
    report = json.loads((SOURCE / f'{tag}_captures.json').read_text())
    cameras = {}
    assert report['water_phase'] == 1.25
    for entry in report['captures']:
        assert entry['error'] == 0
        view = entry['file'].removeprefix(tag+'_').removesuffix('.png')
        cameras[view] = [entry['position'],entry['rotation']]
        copy2(SOURCE / entry['file'], OUT / entry['file'])
    assert set(cameras) == set(VIEWS)
    evidence[tag] = cameras
assert all(cameras == evidence['return_control1'] for cameras in evidence.values())
(REVIEW / 'matched_views.json').write_text(json.dumps({'same_cameras':True,'principal_water_phase':1.25,'mist_cloud_frozen':False,'views':VIEWS,'variants':VARIANTS,'camera_evidence':evidence,'production_art_changed':False,'full_art_accepted':False},ensure_ascii=False,indent=2))
copy2(ROOT / 'art/source/studies/2026-10-16/cliff_continuity_overpaint_v1.png', OUT / 'cliff_continuity_concept.png')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>岛体形状 · 未采用研究</title><style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:28px}h1{font-size:30px;font-weight:500}p{max-width:1100px}a{color:#526e5a}select{font:inherit;padding:7px;margin:8px 18px 15px 4px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{display:block;width:100%}figcaption{padding:7px;background:#f5f2e8}.notice{color:#8a4838}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">保留的默认实景</a><h1>岛体形状研究 · 未采用</h1><p class="notice">本页记录未达到美术要求的实机试作，默认场景保持原来的形体与材质。不要把这些截图视为已经接受的替换版本。</p><p>单独收脚产生托台；连续体重塑仍像宽墙，追加切面出现薄刃和草顶阶梯；缩短底部未解决长船形；早期形体搭配当前材质仍有挂板和分层。去除附加着色也没有修好体块关系。</p><label>机位<select id="view"></select></label><label>左侧<select id="leftTag"></select></label><label>右侧<select id="rightTag"></select></label><div class="pair"><figure><figcaption id="leftCaption"></figcaption><img id="left"></figure><figure><figcaption id="rightCaption"></figcaption><img id="right"></figure></div><p>77张实际Godot截图，七个机位相同、四个主要水体时钟1.25；云雾仍运动。不同几何会改变由支撑与遮挡派生的植被布局。短底仅为临时底形试作，普通存档不能复现这个被替换的底高。</p><details><summary>后续形体修整稿 · 仅二维概念，非Godot实景</summary><p class="notice">这是AI生成的局部形体概念，尚未转成可编辑三维。参考的是大岩体向共同底部的连续转折；新增草密度和细碎纹理不采用。单张图不能证明背面、底面或沙盒编辑成立。</p><img src="cliff_continuity_concept.png" alt="二维形体修整概念，非游戏截图"></details></main><script>const views=VIEWS,variants=VARIANTS;for(const [id,items] of [['view',views],['leftTag',variants],['rightTag',variants]]){for(const [key,label] of Object.entries(items)){const o=document.createElement('option');o.value=key;o.textContent=label;document.getElementById(id).append(o)}}const view=document.getElementById('view'),left=document.getElementById('leftTag'),right=document.getElementById('rightTag');view.value='close';left.value='return_control1';right.value='return_tall1';function update(){for(const [id,select] of [['left',left],['right',right]]){document.getElementById(id).src=select.value+'_'+view.value+'.png';document.getElementById(id).alt=variants[select.value]+' · '+views[view.value];document.getElementById(id+'Caption').textContent=variants[select.value]+' · '+views[view.value]}}view.onchange=left.onchange=right.onchange=update;update();</script></html>'''
(OUT / 'cliff_body_studies.html').write_text(page.replace('VIEWS',json.dumps(VIEWS,ensure_ascii=False)).replace('VARIANTS',json.dumps(VARIANTS,ensure_ascii=False)))
print(OUT / 'cliff_body_studies.html')
