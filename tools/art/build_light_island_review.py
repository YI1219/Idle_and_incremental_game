"""Verify current runtime light candidates and show original/previous controls."""
import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'art/review/terrain_fidelity/2026-10-19'
OUT = BASE / 'island_light'
OLD = ROOT / 'art/review/terrain_fidelity/2026-10-18/beautiful_island/playable'
WORK = ROOT / 'art/work/retained_island/2026-10-19/light'
CASES = ['courtyard_7301', 'courtyard_7319', 'bay_7301', 'bay_7319']
VIEWS = ['whole', 'play', 'close', 'reverse', 'low']


def read(p):
    return json.loads(p.read_text())


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def vector(s):
    return [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?', s)]


def run():
    current = read(OUT / 'captures.json')
    previous = read(OLD / 'captures.json')
    original = read(OLD / 'control/captures.json')
    manifest = read(WORK / 'manifest.json')
    edits = read(WORK / 'verification.json')
    support = read(OUT / 'support.json')
    assert set(current['stages']) == set(manifest['cases']) == set(edits['cases']) == set(CASES)
    assert support['failures'] == 0
    png = {}
    for case in CASES:
        stage = current['stages'][case]
        saved = manifest['cases'][case]
        assert stage['major_props'] == previous['stages'][case]['major_props']
        assert stage['source_draws'] == 0 and stage['ordinary_version'] == 4
        assert stage['vertex_sha256'] == saved['vertex_sha256']
        assert stage['density_records'] == saved['records']
        assert sha(ROOT / f'assets/terrain_editor/island_presets/{case}.res') == saved['source_preset_sha256']
        assert sha(ROOT / f'assets/terrain_editor/island_presets_light/{case}.res') == saved['runtime_resource_sha256']
        assert sha(WORK / case / 'output_geometry/playable.bin') == stage['vertex_sha256']
        assert edits['cases'][case]['edit']['passed'] == edits['cases'][case]['edit']['total'] == 12
        for name, gate in edits['cases'][case]['geometry']['stages'].items():
            assert gate['finite_gate_passes'] and sha(WORK / case / f'output_geometry/{name}.bin') == gate['source_sha256']
        assert support['cases'][case]['passed'] and support['cases'][case]['roots']['tree']['instances'] == 2
        for view in VIEWS:
            name = f'{case}_{view}.png'
            frame = next(f for f in current['captures'] if f['file'] == name)
            assert frame['error'] == 0
            for folder, report in [(OLD, previous), (OLD / 'control', original)]:
                before = next(f for f in report['captures'] if f['file'] == name)
                target = vector(before['position']); target[1] -= 2
                assert max(abs(a-b) for a, b in zip(target, vector(frame['position']))) < .00002
                assert max(abs(a-b) for a, b in zip(vector(before['rotation']), vector(frame['rotation']))) < .00002
                assert Image.open(folder / name).size == (1671, 941)
            assert Image.open(OUT / name).size == (1671, 941)
            png[name] = sha(OUT / name)
    for rule in ['rule1', 'rule2']:
        folder = BASE / 'island_meadow' / rule
        study = read(folder / 'captures.json')
        assert len(study['captures']) == 10
        assert sha(folder / 'island_meadow_form.gd.txt') == study['rule_source_sha256']
        for frame in study['captures']:
            assert frame['error'] == 0 and Image.open(folder / frame['file']).size == (1671, 941)
        for stage in study['stages'].values():
            assert stage['published_tree_count'] == 2 and len(stage['props']) == 6
    record = {'new_runtime_frames': 20, 'retained_control_frames': 40, 'rejected_meadow_frames': 20,
              'four_cases': CASES, 'five_ground_relative_views': VIEWS,
              'world_camera_shift_from_controls': [0, -2, 0],
              'same_original_resources_verified': True, 'png_sha256': png,
              'fresh_four_case_edit_and_finite_reports': True, 'fresh_native_support': True,
              'user_art_accepted': False, 'goal_status': 'active',
              'limits': 'Two offline contours x two seeds, ordinary editable data; not arbitrary-contour crown compiler. Broad walls/platter/painted triangle rim, rebuild latency and user beauty acceptance remain. Target hardware and release export untested.'}
    (OUT / 'verification.json').write_text(json.dumps(record, indent=2) + '\n')
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>浮庭 · 浅岛柔光可编辑预览</title><style>body{margin:0;background:#1d2d2b;color:#eff2e6;font:16px/1.65 system-ui}main{max-width:1600px;margin:auto;padding:22px}h1{font-size:28px}h2{font-size:21px}.status{padding:12px 16px;background:#30443c;border-left:4px solid #d2dda6}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0;border-radius:8px;overflow:hidden;background:#324848}figcaption{padding:9px 13px}img{width:100%;display:block;cursor:zoom-in}button,a.button{display:inline-block;border:1px solid #7d9689;background:#35504a;color:#eff3e5;padding:7px 12px;border-radius:5px;margin:3px;font:inherit;text-decoration:none}button.active{background:#d5e2b6;color:#23372d}p{color:#d1dccf}a{color:#d9e6b4}.note{font-size:14px}.panel,details{padding:14px;background:#293f37;border-radius:8px;margin-top:14px}code{font-size:14px}summary{cursor:pointer}@media(max-width:800px){.pair{grid-template-columns:1fr}main{padding:12px}}</style>
<main><h1>浮庭 · 浅岛柔光</h1><p class="status">新的一份可操作候选：压浅岩体、清爽草色、柔和日光与底部补光。长目标仍在进行，尚未达到最终美术验收。</p>
<p>保留原有房屋、树木和主要摆放，让庭院成为画面主体。新候选已扩展为两种岛形、各两个种子，所有陆地仍来自同一片可以雕刻、保存的地形。</p>
<nav id="cases"></nav><nav id="views"></nav><nav id="controls"></nav>
<div class="pair"><figure><figcaption id="leftLabel">上一候选</figcaption><img id="before" alt="原版或上一候选实拍"></figure><figure><figcaption>浅岛柔光 · 当前可编辑候选</figcaption><img id="after" alt="浅岛柔光实拍"></figure></div>
<p class="note">右侧20张本轮Godot原生实拍；左侧可切换已保留的原版与上一候选。中央地面降低2米，相机也下降2米以保持相对地面的视角，不能称为相同世界坐标相机。五个方向都保留，未裁去背面或底部。</p>
<p><a class="button" href="../../2026-10-18/beautiful_island/references.html">三个参考游戏的官方画面</a><a class="button" href="../island_proportion/index.html">比例与草簇试验</a><a class="button" href="../island_daylight/daylight_whole.png">配色光照单组试拍</a></p>
<h2>实际操作</h2><p>新场景：<code>scenes/beautiful_island_light.tscn</code>；上一候选：<code>scenes/beautiful_island.tscn</code>；原版默认场景保留。</p><p>左键编辑，右键拖动环绕，中键或WASD平移，滚轮缩放，Home回中。面板可以切换四组地形、雕刻、放置土地、撤销重做和保存读取。新试作使用自己的存档，保留上一候选及原版存档。</p>
<div class="panel"><p>本轮实际鼠标射线切削/土地放置、历史、存读、界面与字体检查：新旧候选各22/22。四个新预设各12/12实际源岩体切削与文件检查，八个编辑前后有限几何检查通过；原生植物底部顶点、藤蔓质心支撑抽查通过，每组保留两棵原树。</p><p>这是四个离线编排后可继续编辑的普通预设，尚未实现任意新轮廓的实时岩体风格编排。“放置”指土地，没有新增自由摆放建筑界面。功能与有限几何通过不能替代美术通过。</p><p><a href="verification.json">实拍核对</a> · <a href="support.json">新支撑抽查</a> · <a href="/art/work/retained_island/2026-10-19/light/verification.json">四组编辑与几何</a> · <a href="captures.json">本机性能原始记录</a></p></div>
<h2>仍需继续处理</h2><p>这一版更轻、更明亮，但低角度仍有连续托盘感，近景仍能看到三角形草石过渡；曲湾侧面仍有平直块面。执行者和独立复查均未据此宣布达到参考游戏的美术水准。</p>
<p>Apple M4 Pro、Forward+、1671×941、4XMSAA，本轮短时观察中位约8.3–8.5毫秒、P95约10.9–11.2毫秒；切换地形仍需2.8–3.0秒。目标轻薄本、MacBook Air、长期功耗、发布版构建尚未验证。</p>
<details><summary>本轮未采用的坡地构造：两次规则，完整实拍保留</summary><p>第一轮整列变形造成薄边、折痕和铺路石悬空；第二轮独立控制顶部/底部、保护铺路石并使用体积梯度法线，虽然更平滑，但仍像覆盖草皮的底座，失去了较好的岩体与植被层次。两轮不胜出，停止这个局部构造机制，没有接入候选。</p><div class="pair"><figure><figcaption>坡地第一轮 · 未采用</figcaption><img id="meadow1" alt="失败的第一轮坡地"></figure><figure><figcaption>坡地第二轮 · 未采用</figcaption><img id="meadow2" alt="未胜出的第二轮坡地"></figure></div></details>
</main><script>let current='courtyard_7301',view='whole',control='previous';const cases={courtyard_7301:'圆庭 · 7301',courtyard_7319:'圆庭 · 7319',bay_7301:'曲湾 · 7301',bay_7319:'曲湾 · 7319'},views={whole:'整体',play:'游玩距离',close:'近景',reverse:'反向',low:'低角度'},controls={previous:'对比上一候选',original:'对比原版'};function render(){document.getElementById('before').src='../../2026-10-18/beautiful_island/playable/'+(control==='original'?'control/':'')+current+'_'+view+'.png';document.getElementById('after').src=current+'_'+view+'.png';document.getElementById('leftLabel').textContent=control==='original'?'原版渲染规则':'上一候选 · 原比例与配色';document.getElementById('meadow1').src='../island_meadow/rule1/meadow_'+view+'.png';document.getElementById('meadow2').src='../island_meadow/rule2/meadow_'+view+'.png';document.querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.case===current||b.dataset.view===view||b.dataset.control===control))}for(const[k,v]of Object.entries(cases)){const b=document.createElement('button');b.textContent=v;b.dataset.case=k;b.onclick=()=>{current=k;render()};document.getElementById('cases').append(b)}for(const[k,v]of Object.entries(views)){const b=document.createElement('button');b.textContent=v;b.dataset.view=k;b.onclick=()=>{view=k;render()};document.getElementById('views').append(b)}for(const[k,v]of Object.entries(controls)){const b=document.createElement('button');b.textContent=v;b.dataset.control=k;b.onclick=()=>{control=k;render()};document.getElementById('controls').append(b)}for(const i of document.querySelectorAll('img'))i.onclick=()=>window.open(i.src,'_blank');render();</script></html>'''
    (OUT / 'index.html').write_text(html)
    print('LIGHT REVIEW: 20 fresh runtime frames + 40 retained controls, ordinary resources/edit/geometry/support identities verified; ART OPEN')


if __name__ == '__main__':
    run()
