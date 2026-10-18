"""Bind rejected two-rule native evidence; no conversion or art promotion."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/review/terrain_fidelity/2026-10-18/cliff_planes'
WORK = ROOT/'art/work/cliff_planes/2026-10-18'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    captures = json.loads((OUT/'direct/captures.json').read_text())
    gates = json.loads((WORK/'geometry_checks.json').read_text())
    assert len(captures['frames']) == 15
    assert set(captures['stages']) == set(gates['stages']) == {'control', 'planes1', 'planes2'}
    pngs = {}
    for name, stage in captures['stages'].items():
        assert stage['sha256'] == sha(WORK/(name+'.bin')) == gates['stages'][name]['source_sha256']
        assert gates['stages'][name]['finite_gate_passes']
    for frame in captures['frames']:
        path = OUT/'direct'/frame['file']
        assert frame['error'] == 0 and Image.open(path).size == (1671, 941)
        peers = [f for f in captures['frames'] if f['view'] == frame['view']]
        assert all([f[k] for k in ['position', 'target', 'size']] ==
                   [frame[k] for k in ['position', 'target', 'size']] for f in peers)
        pngs[str(path.relative_to(OUT))] = sha(path)
    default = json.loads((OUT/'default/scene_captures.json').read_text())
    assert default['unchanged_authoritative_data'] and len(default['captures']) == 4
    for frame in default['captures']:
        path = OUT/'default'/frame['file']
        assert frame['error'] == 0 and Image.open(path).size == (1671, 941)
        pngs[str(path.relative_to(OUT))] = sha(path)
    result = {'scope':'Two shape-rule art failures; stop gate reached. No new field/contact/history/performance claims.',
              'current_native_frames':19, 'direct_frames':15, 'fresh_default_context_frames':4,
              'default_is_context_not_camera_matched_to_isolated_candidates':True,
              'source_geometry_gates':gates, 'png_sha256':pngs,
              'initial_invalid_frames':'direct_initial/captures.json',
              'promoted':False, 'sampled':False, 'paid_jobs':0,
              'art_accepted':False, 'full_goal_complete':False,
              'stop_reason':'Two substantive rules remain column/panel-like with poor basal rhythm; no clear target-art benefit.',
              'next_user_decision':'Deliberately author one standard mother face by face, or use an already-qualified model as geometry authority before PCG extraction.'}
    (OUT/'verification.json').write_text(json.dumps(result, indent=2)+'\n')
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>两轮岩面改形实拍 · 未达标</title>
<style>body{background:#1a2627;color:#edf0e6;margin:0;font:16px/1.65 system-ui}main{max-width:1500px;margin:auto;padding:24px}h1{font-size:27px}h2{font-size:22px}p{color:#cbd4ca}.pair,.three{display:grid;gap:14px;grid-template-columns:repeat(2,minmax(0,1fr))}.three{grid-template-columns:repeat(3,minmax(0,1fr))}figure{margin:0;background:#304043;border-radius:9px;overflow:hidden}figcaption{padding:10px}img{display:block;width:100%;cursor:zoom-in}select,button{background:#354b4c;color:#edf0df;padding:10px;border:1px solid #86968d;border-radius:6px;margin:3px}button.active{background:#c9d7ab;color:#172323}a{color:#d2e3ab}@media(max-width:650px){.pair,.three{grid-template-columns:1fr}}</style>
<main><h1>两轮实际改形：几何通过，美术未达标，已停止试调</h1>
<p>本轮没有新增付费生成或替换正式场景。两种不同形体规则仍未带来足够的目标美术收益，触发约定的停止条件。下一步需要决定标准母样的定形方式。</p>
<div class="pair"><figure><figcaption>用户目标 · 相机与构图不同</figcaption><img src="/art/source/visual_targets/2026-10-16/cliff_user_target.png"></figure><figure><figcaption>第二轮候选 · 实际Godot中性材质 · 未推广</figcaption><img src="direct/planes2_close.png"></figure></div>
<h2>同相机比较：上一轮代码母样 → 本轮规则一 → 规则二</h2>
<p>这里的对照是母样原型，不是正式默认版本。三者使用同一中性材质、42度法线处理及五个固定相机。没有覆盖草来掩盖形体问题。</p><nav id="views"></nav>
<div class="three"><figure><figcaption>上一轮母样 · 三块整板</figcaption><img id="control"></figure><figure><figcaption>规则一 · 多层肩部与凸面</figcaption><img id="planes1"></figure><figure><figcaption>规则二 · 分开宽度/深度收底与面倾斜</figcaption><img id="planes2"></figure></div>
<p>第一轮仍像立柱，底部出现大三角面。第二轮消除了顶部细长深沟，但大板面和深长缝仍强，右下有窄长垂边，反向仍是整墙；底部缺少目标的自然共同收束。两版都不进入雕刻数据。</p>
<h2>正式原版场景 · 本轮重新拍摄，保持原状</h2><p>这是现有编辑器原场景的上下文。与上面的孤立样段构图不同，不能用于像素级收益比较。建筑、树木、布局、水体及权威地形数据均保留。</p>
<select id="defaultView"><option value="close">原场景近景</option><option value="grass">草石交界</option><option value="reverse">反向</option><option value="far">全岛</option></select><figure><figcaption>原版Godot场景 · 本轮实拍</figcaption><img id="defaultImage" src="default/scene_original_close.png"></figure>
<h2>需要改变的是定形方式</h2><p>建议先逐面设计一个标准母样：明确每个主面的宽窄、倾斜、肩部、裂隙终止和共同收底，再提取PCG规则。仍可用代码指定顶点和约束；当前环状列面公式不应继续批量扩充。另一条路是以已经达标的模型作为形体基准。</p>
<p>19张当前Godot截图（15张样段＋4张原版场景）；首次几何缺陷另存10张。没有新的草土接触、支撑、雕刻历史、两轮廓两种子、设备性能或用户美术验收结论。目标仍未完成。</p>
<p><a href="README.md">本轮报告</a> · <a href="verification.json">实际验证记录</a> · <a href="../cliff_guides/index.html">上一轮母样库和土草实拍</a></p></main>
<script>let view='close';const labels={close:'近景',grass:'上部交界',whole:'整体',reverse:'反向',bottom:'底部'};function update(){for(const s of ['control','planes1','planes2'])document.getElementById(s).src='direct/'+s+'_'+view+'.png';document.querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.view===view))}for(const[k,v]of Object.entries(labels)){let b=document.createElement('button');b.textContent=v;b.dataset.view=k;b.onclick=()=>{view=k;update()};document.getElementById('views').append(b)}document.getElementById('defaultView').onchange=e=>document.getElementById('defaultImage').src='default/scene_original_'+e.target.value+'.png';for(const i of document.querySelectorAll('img'))i.onclick=()=>window.open(i.src,'_blank');update();</script></html>'''
    (OUT/'index.html').write_text(html)
    print('CLIFF PLANE REVIEW: 19 verified native frames, 3 source finite passes, both art rejected; stop gate recorded.')


if __name__ == '__main__':
    run()
