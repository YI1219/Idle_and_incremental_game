"""Verify native first-stage art alternatives and show the active long goal."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/review/terrain_fidelity/2026-10-18/beautiful_island'


def run():
    global OUT
    import sys
    if len(sys.argv)>1:OUT=ROOT/sys.argv[1]
    report = json.loads((OUT/'captures.json').read_text())
    names = {'control', 'soft', 'graphic', 'terraced'}
    assert set(report['recipes']) == names
    frames = report['captures']
    assert len(frames) == 20
    hashes = {}
    for view in ['whole', 'play', 'close', 'reverse', 'low']:
        peers = [f for f in frames if f['file'].endswith('_'+view+'.png')]
        assert len(peers) == 4
        assert {f['file'].removesuffix('_'+view+'.png') for f in peers} == names
        assert all([f['position'], f['rotation']] == [peers[0]['position'], peers[0]['rotation']] for f in peers)
        for frame in peers:
            path = OUT/frame['file']
            assert frame['error'] == 0 and Image.open(path).size == (1671, 941)
            hashes[frame['file']] = hashlib.sha256(path.read_bytes()).hexdigest()
    recipes = report['recipes']
    assert len({r['cells_sha256'] for r in recipes.values()}) == 1
    assert all(r['original_cells_unchanged'] for r in recipes.values())
    assert all(r['visible_props'] == recipes['control']['visible_props'] for r in recipes.values())
    for name in names-{'control'}:
        path = OUT/(name+'.bin')
        assert hashlib.sha256(path.read_bytes()).hexdigest() == recipes[name]['mesh_vertex_sha256']
        assert path.stat().st_size == recipes[name]['triangles']*36
    verification = {'goal_status':'active', 'user_art_accepted':False,
                    'stage':'complete native style comparison, not integrated candidate',
                    'native_frames':20, 'matched_camera_records':True,
                    'same_authoritative_cells':True, 'same_visible_prop_names':True,
                    'layout_kind':recipes['control'].get('layout_kind','original'),
                    'png_sha256':hashes, 'recipes':recipes,
                    'portable_save_profile_implemented':False,
                    'actual_geometry_gate_run':False,
                    'support_edit_history_checks_run':False,
                    'two_layouts_and_two_seeds':False,
                    'target_device_measured':False,
                    'lighting_difference':report['lighting_difference'],
                    'earlier_pale_frames':'/art/review/terrain_fidelity/2026-10-18/beautiful_island/pass0_pale/captures.json',
                    'isolated_color_fix_proof':'/art/review/terrain_fidelity/2026-10-18/beautiful_island/color_probe/captures.json'}
    (OUT/'verification.json').write_text(json.dumps(verification,indent=2)+'\n')
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>美观优先的小岛 · 长目标进行中</title>
<style>body{margin:0;background:#19282a;color:#edf1e8;font:16px/1.7 system-ui}main{max-width:1540px;margin:auto;padding:24px}h1{font-size:27px}h2{font-size:21px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:15px}figure{margin:0;background:#304245;border-radius:8px;overflow:hidden}figcaption{padding:10px}img{display:block;width:100%;cursor:zoom-in}button{background:#344c4e;border:1px solid #8a9b92;color:#edf1e8;border-radius:6px;padding:9px 14px;margin:3px}button.active{background:#d3dfb6;color:#233429}p{color:#cbd5ca}a{color:#d8e8ba}.status{padding:12px;background:#334341;border-left:4px solid #c9d9a4}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style>
<main><h1>做出美观的小岛，允许有意的简化与夸张</h1><p class="status">长 goal 进行中。第一阶段比较完整实机风格，尚未接入正式可保存预设，也未获得美术认可。</p>
<p>参考 Brushland、Tiny Glade、Townscaper 的完成度：看轮廓、配色、衔接和建筑植被的协调。旧概念图保留作审美参考，不要求复刻它的岩壁或真实地质。</p>
<h2>正式原版与完整场景方案</h2><nav id="styles"></nav><nav id="views"></nav>
<div class="pair"><figure><figcaption>本轮实拍 · 正式原版</figcaption><img id="control"></figure><figure><figcaption id="label"></figcaption><img id="candidate"></figure></div>
<p>四组使用同一地块、主要摆放和匹配相机；候选将形体、色彩及柔光作为整体方案比较。云雾实时变化。点击图片可看原尺寸。</p>
<h2>本阶段的判断</h2><p>当前三种侧面生成方案均未胜出：仍偏光滑底板、整墙或层叠蛋糕。它们作为过程证据保留，长目标继续换路线。实验使用与网格和支撑一致的真实密度数据；正式保存、地块再生和编辑历史接入将在选出有视觉收益的方向后完成。这些截图不表示功能或美术验收通过。</p>
<p><a href="/art/review/terrain_fidelity/2026-10-18/beautiful_island/references.html">三个参考游戏的官方实机画面</a> · <a href="/art/review/terrain_fidelity/2026-10-18/beautiful_island/README.md">持续执行记录</a> · <a href="verification.json">实拍核对</a> · <a href="/docs/superpowers/specs/2026-10-18-beautiful-editable-island-design.md">目标与验收标准</a></p>
<p>下一阶段：收敛更好的形体与接触，做成真正可编辑、可保存的候选；再验证两种岛形、两个种子和远近/反向镜头。最终由用户认可整体美术后完成长 goal。</p></main>
<script>let style='soft',view='whole';const styles={soft:'绘本柔形',graphic:'概括块面',terraced:'清爽层台'},views={whole:'整体',play:'游玩距离',close:'近景交界',reverse:'反向',low:'低角度'};function draw(){document.getElementById('control').src='control_'+view+'.png';document.getElementById('candidate').src=style+'_'+view+'.png';document.getElementById('label').textContent=styles[style]+' · 实验方案，尚未验收';document.querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.style===style||b.dataset.view===view))}for(const[k,v]of Object.entries(styles)){const b=document.createElement('button');b.textContent=v;b.dataset.style=k;b.onclick=()=>{style=k;draw()};document.getElementById('styles').append(b)}for(const[k,v]of Object.entries(views)){const b=document.createElement('button');b.textContent=v;b.dataset.view=k;b.onclick=()=>{view=k;draw()};document.getElementById('views').append(b)}for(const i of document.querySelectorAll('img'))i.onclick=()=>window.open(i.src,'_blank');draw();</script></html>'''
    html=html.replace('<h2>本阶段的判断</h2>', '<p><a href="/art/review/terrain_fidelity/2026-10-18/beautiful_island/index.html">完整大岛比较</a> · <a href="/art/review/terrain_fidelity/2026-10-18/beautiful_island/courtyard/index.html">紧凑庭院比较</a> · <a href="/art/review/terrain_fidelity/2026-10-18/beautiful_island/whole_object.html">整座岛三维主形试验</a></p>'+'<h2>本阶段的判断</h2>')
    if recipes['control'].get('layout_kind')=='courtyard':
        html=html.replace('本轮实拍 · 正式原版','相同小场景 · 原渲染规则').replace('正式原版与完整场景方案','小庭院：相同布局的完整风格比较')
    html=html.replace('<main>','<main><div class="status">本页为早期阶段证据。<a href="/art/review/terrain_fidelity/2026-10-18/beautiful_island/playable/index.html">查看当前可操作候选与40张实机对比</a>。长目标仍在进行。</div>',1)
    (OUT/'index.html').write_text(html)
    print('BEAUTY REVIEW: 20 native frames; same cells/props/cameras; long goal ACTIVE, no art/function acceptance claim.')


if __name__ == '__main__':
    run()
