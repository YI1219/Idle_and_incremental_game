"""Verify and show the small reference-informed adopt/reject experiment."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/review/terrain_fidelity/2026-10-18/neighbor_cliff'
WORK = ROOT/'art/work/neighbor_cliff/2026-10-18'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    report = json.loads((OUT/'direct/captures.json').read_text())
    gate = json.loads((WORK/'geometry_checks.json').read_text())
    names = {'control', 'neighbor1', 'neighbor2'}
    assert set(report['stages']) == set(gate['stages']) == names
    assert len(report['frames']) == 15
    dimensions = {}; bounds = {}; pngs = {}
    for name in names:
        path = WORK/(name+'.bin'); digest = sha(path)
        assert report['stages'][name]['sha256'] == gate['stages'][name]['source_sha256'] == digest
        assert gate['stages'][name]['finite_gate_passes']
        p = np.fromfile(path, dtype='<f4').reshape(-1, 3)
        bounds[name] = [p.min(0), p.max(0)]
        dimensions[name] = (p.max(0)-p.min(0)).tolist()
        if name != 'control':
            meta = json.loads((WORK/(name+'.json')).read_text())
            assert meta['source_sha256'] == digest
            assert meta['control_sha256'] == sha(WORK/'control.bin')
    base_lo, base_hi = bounds['control']
    for name in ['neighbor1', 'neighbor2']:
        lo, hi = bounds[name]
        assert abs((hi-lo)[0]-(base_hi-base_lo)[0]) < 1e-5
        assert abs(hi[1]-base_hi[1]) < 1e-5
        assert max(abs(((lo+hi)-(base_lo+base_hi))[[0, 2]])) < 1e-5
    for frame in report['frames']:
        path = OUT/'direct'/frame['file']
        assert frame['error'] == 0 and Image.open(path).size == (1671, 941)
        peers = [f for f in report['frames'] if f['view'] == frame['view']]
        assert len(peers) == 3
        assert all([f[k] for k in ['position', 'target', 'size']] ==
                   [frame[k] for k in ['position', 'target', 'size']] for f in peers)
        pngs[frame['file']] = sha(path)
    source_evidence = OUT/'sources.md'
    assert source_evidence.exists()
    assert (OUT/'independent_review.md').is_file()
    target = ROOT/'art/source/visual_targets/2026-10-16/cliff_user_target.png'
    assert sha(target) == '1f16fa5540c7539175faa0b3d167b3a8b0e9df0651aba96397f47075009de2e7'
    result = {'small_goal':'Reference-informed adopt/reject decision, not complete original art target',
              'decision':'reject_current_convex_region_union_generator',
              'current_native_frames':15, 'source_and_camera_checks':True,
              'source_finite_gates':gate, 'png_sha256':pngs, 'dimensions_xyz':dimensions,
              'same_width_peak_and_xz_center':True, 'only_uniform_similarity_transform':True,
              'target_sha256':sha(target), 'source_evidence_sha256':sha(source_evidence),
              'early_public_prototype_revision':'3f6a459c0424ed9177a0dceec4d72a380cbd80c2',
              'actual_shipped_cliff_algorithms_known':False,
              'not_complete_neighbor_state_or_arbitrary_footprint_compiler':True,
              'substantive_rules':2, 'extra_raw_frames':'direct_raw/captures.json',
              'paid_jobs':0, 'external_art_assets':0, 'converted_to_density':False,
              'full_art_accepted':False, 'formal_default_promoted':False,
              'reason':'Some3Dface/bevel and plinth gains, but box-like repeated faces, blank rear, broad flat/angular bottom and abrupt ends remain; insufficient overall natural cliff composition.',
              'conditional_phases_omitted':'No new density/support/history/layout/seed/performance acceptance after failed source art.',
              'independent_review':'independent_review.md'}
    (OUT/'verification.json').write_text(json.dumps(result, indent=2)+'\n')
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>参考游戏小目标 · 邻接岩体实测</title>
<style>body{margin:0;background:#182729;color:#edf1e5;font:16px/1.65 system-ui}main{max-width:1500px;margin:auto;padding:24px}h1{font-size:27px}h2{font-size:22px;margin-top:28px}p{color:#c7d3ca}.pair,.three{display:grid;gap:14px;grid-template-columns:repeat(2,minmax(0,1fr))}.three{grid-template-columns:repeat(3,minmax(0,1fr))}figure{margin:0;background:#304346;border-radius:9px;overflow:hidden}figcaption{padding:10px}img{display:block;width:100%;cursor:zoom-in}button{background:#324b4e;color:#edf1e5;border:1px solid #879990;border-radius:6px;margin:3px;padding:10px}button.active{background:#c9d8ac;color:#182726}a{color:#d4e6ac}table{border-collapse:collapse;width:100%}td,th{text-align:left;padding:10px;border-bottom:1px solid #4c6260}@media(max-width:650px){.pair,.three{grid-template-columns:1fr}}</style>
<main><h1>小目标实测：参考邻接生成原则，否决当前凸体拼合实现</h1>
<p>本轮核对了公开来源，并做了两轮不同于环状拉伸的形体实验。主面的三维转折有所增加，第二版减少了正面底座，但整体仍偏箱体与整墙，底部也未形成目标的自然共同收束。决定不推广这套具体生成器。</p>
<div class="pair"><figure><figcaption>用户目标 · 相机与构图不同</figcaption><img src="/art/source/visual_targets/2026-10-16/cliff_user_target.png"></figure><figure><figcaption>第二版实际Godot灰模 · 仍未通过美术</figcaption><img src="direct/neighbor2_close.png"></figure></div>
<h2>同宽度、同相机、同中性材质对比</h2><p>原对照是上一轮代码母样，不是正式庭院默认版本。候选只做统一缩放和平移，使宽度、顶部和水平中心一致，保留各自比例。下方可查看近景、上部、整体、反向与底部。</p><nav id="views"></nav>
<div class="three"><figure><figcaption>原代码母样 · 112三角面</figcaption><img id="control"></figure><figure><figcaption>邻接边界拟合＋三维面约束 · 746面</figcaption><img id="neighbor1"></figure><figure><figcaption>共同收底修订 · 752面</figcaption><img id="neighbor2"></figure></div>
<p>三个当前源都通过有限的闭合、单连通、边/顶点链接和严格交叉检查；这不等于自然岩体。候选没有转换到雕刻数据，也没有用草和材质掩盖失败形体。正面仍有并排块面，反向仍像墙，下部保留大平面与突兀收口。</p>
<h2>到底参考到了什么</h2><table><tr><th>来源</th><th>查到的一手证据</th><th>边界</th></tr><tr><td>Brushland</td><td>官方说明：地块根据邻接关系改变形态</td><td>未查到可验证的岩壁内部算法</td></tr><tr><td>Tiny Glade开发者</td><td>多个针对具体元素的生成、组合和变形流程</td><td>早期公开原型不等于正式悬崖系统</td></tr><tr><td>country-slice原始代码</td><td>高度纹理位移、沿曲线布砖和贴地</td><td>不能直接解决悬崖和可雕刻下部</td></tr><tr><td>Oskar Stålberg本人说明</td><td>逻辑主网格与渲染用对偶网格可以分开</td><td>网格选择本身不提供达标的岩体美术</td></tr></table>
<p>这里的生成器是我自己的实验，不是Brushland或Tiny Glade内部算法的复刻。当前只拟合四个岩区的邻接边界跨度和切向，高度、深度与倾斜仍是局部参数；尚无完整邻接状态语法或任意地块再生。</p>
<p><a href="sources.md">公开来源与原始代码核查</a> · <a href="README.md">采用/否决报告</a> · <a href="verification.json">本轮验证</a> · <a href="independent_review.md">独立复核与范围</a> · <a href="../cliff_planes/index.html">之前拍摄的正式原版场景上下文</a></p>
<p>15张当前新Godot截图；统一尺寸前的10张另存。两轮后停止，无付费生成、外部美术资产、正式默认或树木建筑布局水体改动。完成的是这一步研究决策，完整PCG美术目标仍需共享雕刻验证、多轮廓多种子和用户认可。</p></main>
<script>let view='close';const labels={close:'近景',grass:'上部交界',whole:'整体',reverse:'反向',bottom:'底部'};function draw(){for(const name of ['control','neighbor1','neighbor2'])document.getElementById(name).src='direct/'+name+'_'+view+'.png';document.querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.view===view))}for(const[k,v]of Object.entries(labels)){let b=document.createElement('button');b.textContent=v;b.dataset.view=k;b.onclick=()=>{view=k;draw()};document.getElementById('views').append(b)}for(const i of document.querySelectorAll('img'))i.onclick=()=>window.open(i.src,'_blank');draw();</script></html>'''
    (OUT/'index.html').write_text(html)
    print('NEIGHBOR REVIEW: 15current native frames; samewidth/peak/center/cameras; 3finite passes; explicit negative decision.')


if __name__ == '__main__':
    run()
