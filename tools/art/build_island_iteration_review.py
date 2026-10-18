"""Verify and present the bounded 2026-10-19 native island experiments."""
import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'art/review/terrain_fidelity/2026-10-19'
OUT = BASE / 'island_proportion'
WORK = ROOT / 'art/work/retained_island/2026-10-19'
VIEWS = ['whole', 'play', 'close', 'reverse', 'low']


def read(path):
    return json.loads(path.read_text())


def vector(text):
    return [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?', text)]


def run():
    proportion = read(OUT / 'captures.json')
    contact = read(BASE / 'island_contact/captures.json')
    grass = read(BASE / 'island_contact/rim_grass/captures.json')
    low = read(BASE / 'island_contact/rim_low/captures.json')
    png_hashes = {}
    for folder, report in [(OUT, proportion), (BASE / 'island_contact', contact),
                           (BASE / 'island_contact/rim_grass', grass),
                           (BASE / 'island_contact/rim_low', low)]:
        assert len(report['captures']) == len(report['stages']) * 5
        for frame in report['captures']:
            assert frame['error'] == 0
            path = folder / frame['file']
            with Image.open(path) as im:
                assert im.size == (1671, 941)
                im.verify()
            png_hashes[str(path.relative_to(BASE))] = hashlib.sha256(path.read_bytes()).hexdigest()
    control = contact['stages']['control']
    for report in [contact, grass, low]:
        for stage in report['stages'].values():
            for key in ['vertex_sha256', 'layout_sha256', 'props', 'triangles']:
                assert stage[key] == control[key], key
        for frame in report['captures']:
            view = next(v for v in VIEWS if frame['file'].endswith('_' + v + '.png'))
            original = next(f for f in contact['captures'] if f['file'] == f'control_{view}.png')
            assert frame['position'] == original['position']
            assert frame['rotation'] == original['rotation']
    for style, stage in proportion['stages'].items():
        geometry = WORK / f'proportion/{style}.bin'
        assert hashlib.sha256(geometry.read_bytes()).hexdigest() == stage['vertex_sha256']
        assert geometry.stat().st_size == stage['triangles'] * 36
        assert stage['props'] == control['props'] and stage['cells'] == 145
    for view in VIEWS:
        a = next(f for f in proportion['captures'] if f['file'] == f'control_{view}.png')
        b = next(f for f in proportion['captures'] if f['file'] == f'shallow_{view}.png')
        expected = vector(a['position']); expected[1] -= 2
        assert max(abs(x-y) for x, y in zip(expected, vector(b['position']))) < .00002
        assert max(abs(x-y) for x, y in zip(vector(a['rotation']), vector(b['rotation']))) < .00002
    checks = read(WORK / 'proportion/edit_checks.json')
    assert checks['passed'] == checks['total'] == 12
    gates = []
    for path in [WORK / 'proportion/geometry_checks.json', WORK / 'proportion/output_geometry/geometry_checks.json']:
        gate = read(path)
        assert all(stage['finite_gate_passes'] for stage in gate['stages'].values())
        for name, stage in gate['stages'].items():
            raw = path.parent / f'{name}.bin'
            assert hashlib.sha256(raw.read_bytes()).hexdigest() == stage['source_sha256']
        gates.append({'file': str(path.relative_to(ROOT)), 'report': gate})
    record = {
        'native_frames': 30, 'contact_frames': 20, 'proportion_frames': 10,
        'contact_terrain_and_data_identical': True,
        'rooted_styles_add_existing_plant_geometry': True,
        'proportion_cameras_same_ground_relative_view_but_world_y_minus_2': True,
        'proportion_cases': ['courtyard_7301'], 'ordinary_edit_history_file_checks': '12/12',
        'geometry_reports': gates, 'png_sha256': png_hashes,
        'art_accepted': False, 'goal_status': 'active',
        'limits': 'Contact rules not adopted. Shallow is one tools-only contour/seed, not current four-preset UI or complete support/placement/hardware acceptance. Invalid initial shader frames excluded.'
    }
    (OUT / 'verification.json').write_text(json.dumps(record, indent=2) + '\n')
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>浮庭 · 小岛比例与边缘试验</title>
<style>body{margin:0;background:#1c2b2b;color:#eef0e5;font:16px/1.65 system-ui}main{max-width:1600px;margin:auto;padding:22px}h1{font-size:28px;margin-bottom:10px}h2{font-size:21px}.status{border-left:4px solid #cfdda8;background:#30413d;padding:12px 16px}p{color:#d1d9ce}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0;background:#304347;border-radius:8px;overflow:hidden}figcaption{padding:8px 14px}img{display:block;width:100%;cursor:zoom-in}button,a.button{background:#344c4e;border:1px solid #7d958b;color:#edf1e8;border-radius:5px;padding:7px 12px;margin:3px;display:inline-block;font:inherit;text-decoration:none}button.active{background:#d3dfb6;color:#233429}a{color:#d7e6b8}table{border-collapse:collapse}td,th{text-align:left;padding:8px 14px;border-bottom:1px solid #53675f}.note{font-size:14px}.panel{padding:12px 16px;background:#273c39;border-radius:8px}@media(max-width:800px){.pair{grid-template-columns:1fr}main{padding:12px}}</style>
<main><h1>让小岛托住房屋，而不让岩体抢走画面</h1>
<p class="status">长期目标仍在进行：以整体美观和风格统一为标准。右侧是新的比例试验，尚未替换可操作候选，也没有获得最终美术认可。</p>
<p>只降低岛体的厚度，保留房屋、两棵树的原始大小和水平位置。整体上更轻，房屋与庭院更突出；低角度仍像连续托盘，草石接缝与部分平直块面还需要解决。</p>
<nav id="views"></nav><div class="pair"><figure><figcaption>当前候选 · 原比例</figcaption><img id="before" alt="原比例的游戏实拍"></figure><figure><figcaption>压浅岛体 · 实际可雕刻数据</figcaption><img id="after" alt="压浅岛体的游戏实拍"></figure></div>
<p class="note">10张 Godot 原生实拍。地面从3.5米降至1.5米，相机也下降2米，保持相对地面的观察距离和角度；不是相同的世界坐标相机。没有缩小房屋或树木，没有隐藏背面。</p>
<p><a class="button" href="../../2026-10-18/beautiful_island/playable/index.html">原有两种岛形 × 两个种子</a> <a class="button" href="../../2026-10-18/beautiful_island/references.html">三个参考游戏的官方画面</a></p>
<h2>草石边缘：哪些尝试还不够好</h2><p>连续材质覆盖仍偏涂色。再加真实草簇，第一轮偏暗、偏尖，第二轮压低并柔化以后更自然一些，但主要起点缀作用。两轮都没有解决整体接缝，所以暂不接入正式编辑器，也不继续只调草的密度。</p>
<nav id="contacts"></nav><div class="pair"><figure><figcaption>相同地形 · 当前边缘</figcaption><img id="contactBefore" alt="当前边缘"></figure><figure><figcaption id="contactLabel"></figcaption><img id="contactAfter" alt="边缘试验"></figure></div>
<p class="note">20张有效原生实拍；与上方共用视角选择。四种边缘的地形顶点和存档完全相同，草簇方案另加现有植物实例。最初着色器路径失败的10张画面保留在故障目录，未计入这次比较。</p>
<h2>实际验证与剩余工作</h2><div class="panel"><p>压浅版当前只验证了圆庭7301这一组：实际雕刻、撤销重做、文件保存读取12/12通过；原比例、压浅版和切削后的有限几何检查通过。它仍是研究样本，尚未扩展到四组可操作预设，也没有完成全部接触支撑检查。</p>
<p>这轮还减少了网格生成中的重复工作。四个现有预设的顶点、法线、颜色、UV全部保持逐字节一致，28/28检查通过。密度读取减少约58%，材质计算减少约83%；这不代表整体重建已经流畅。</p>
<table><tr><th>开发机单次观察</th><th>修改前</th><th>修改后</th></tr><tr><td>单独生成网格</td><td>约1.39秒</td><td>约0.90秒</td></tr><tr><td>完整重建</td><td>约3.41秒</td><td>约3.00秒</td></tr></table>
<p class="note">Apple M4 Pro，单次无窗口诊断，存在后台负载与测量波动；不是严谨性能基准，也不代表目标轻薄本、MacBook Air或挂机功耗达标。约3秒的完整重建仍是明显限制。</p>
<p><a href="verification.json">实拍与范围核对</a> · <a href="captures.json">比例试验原始记录</a> · <a href="/art/work/retained_island/2026-10-19/proportion/edit_checks.json">实际编辑检查</a></p></div>
<p>保留压浅比例作为下一步造型线索，继续处理底部的整体形状与草石接缝。功能通过与局部改善都不代替最终美术认可。</p></main>
<script>let view='whole',contact='world_boundary';const views={whole:'整体',play:'游玩距离',close:'近景',reverse:'反向',low:'低角度'},contacts={world_boundary:'连续材质覆盖',rooted_rim:'草簇第一轮',rooted_low:'草簇第二轮'},paths={world_boundary:'../island_contact/',rooted_rim:'../island_contact/rim_grass/',rooted_low:'../island_contact/rim_low/'};function render(){document.getElementById('before').src='control_'+view+'.png';document.getElementById('after').src='shallow_'+view+'.png';document.getElementById('contactBefore').src='../island_contact/control_'+view+'.png';document.getElementById('contactAfter').src=paths[contact]+contact+'_'+view+'.png';document.getElementById('contactLabel').textContent=contacts[contact];document.querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.view===view||b.dataset.contact===contact))}for(const[k,v]of Object.entries(views)){const b=document.createElement('button');b.textContent=v;b.dataset.view=k;b.onclick=()=>{view=k;render()};document.getElementById('views').append(b)}for(const[k,v]of Object.entries(contacts)){const b=document.createElement('button');b.textContent=v;b.dataset.contact=k;b.onclick=()=>{contact=k;render()};document.getElementById('contacts').append(b)}for(const i of document.querySelectorAll('img'))i.onclick=()=>window.open(i.src,'_blank');render();</script></html>'''
    (OUT / 'index.html').write_text(html)
    print('ISLAND ITERATION REVIEW: 30 valid native frames; 5 ground-relative proportion pairs; 4 exact-terrain contact styles; art OPEN')


if __name__ == '__main__':
    run()
