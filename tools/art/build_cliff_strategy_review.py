"""Publish evidence for local guide family, AI guidance and real-field contact."""
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/review/terrain_fidelity/2026-10-18/cliff_guides'


def run():
    groups=[(OUT,64),(OUT/'contact_control',25),(OUT/'contact_soft',25),
            (OUT.parent/'code_guided_result',32),(OUT.parent/'code_guided_result/constraint',20),
            (OUT.parent/'cliff_lower/direct',10)]
    total=0
    for folder,count in groups:
        report=json.loads((folder/'captures.json').read_text());assert len(report['frames'])==count
        for f in report['frames']:
            assert f['error']==0 and Image.open(folder/f.get('folder','')/f['file']).size==(1671,941)
            peers=[p for p in report['frames'] if p['view']==f['view']]
            assert all([p[k] for k in ['position','target','size']]==[f[k] for k in ['position','target','size']] for p in peers)
        total+=count
    assert total==176
    for stage in ['contact_control','contact_soft']:
        gate=json.loads((ROOT/'art/work/cliff_guides/2026-10-18'/stage/'geometry_checks.json').read_text())
        assert len(gate['stages'])==5 and all(s['finite_gate_passes'] for s in gate['stages'].values())
    ai=json.loads((ROOT/'art/work/code_guided_result/2026-10-18/geometry_checks.json').read_text())
    assert all(not ai['stages'][s]['finite_gate_passes'] for s in ['new','closed','constrained'])
    html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>岩体策略实测 · 代码母样与生成模型</title>
<style>body{margin:0;background:#182426;color:#edf1e4;font:16px/1.65 system-ui}main{max-width:1580px;margin:auto;padding:24px}h1{font-size:27px}h2{font-size:22px;margin-top:32px}p{color:#c6d2c8}.pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:15px}figure{margin:0;background:#2a3c3e;border-radius:10px;overflow:hidden}figcaption{padding:10px 14px}img{width:100%;display:block;cursor:zoom-in}button,select{background:#304849;color:#eef0df;border:1px solid #6b817c;border-radius:7px;padding:10px;margin:3px;cursor:pointer}button.active{background:#ccd9a8;color:#162224}a{color:#d4e5a8}@media(max-width:650px){.pair{grid-template-columns:1fr}}</style>
<main><h1>岩体策略实测：代码控制大形，小型母样库提供变化</h1>
<p>已实际尝试三条路线：修整现有模型、代码建模并生成一组完整岩体、代码四视图软引导Tripo。当前保留纯程序母样和浅土层作为可控方向；仍是原型，美术尚未达到目标。</p>
<div class="pair"><figure><figcaption>用户目标 · 构图和相机不同</figcaption><img src="/art/source/visual_targets/2026-10-16/cliff_user_target.png"></figure><figure><figcaption>当前纯程序母样 + 可雕刻浅土层 · 实际Godot候选</figcaption><img src="contact_soft/contact_grass.png"></figure></div>
<p>大形、主面、裂隙终止和共同收底由本地代码决定。AI图片和Tripo返回只能作为可替换候选；这次返回模型有破洞，后处理也产生交叉，已拒绝，不进入雕刻数据。</p>
<h2>六个完整模型变体：三类规则 × 两个种子</h2>
<p>每个是完整相连的岩体，不是散放石头。下方是同相机、同中性材质的真实截图。当前仍偏三块大板面与整墙；不能当作六种已通过美术的资产。</p>
<select id="family"><option value="broad_turn_7301">宽主面 · 7301</option><option value="broad_turn_7319">宽主面 · 7319</option><option value="high_left_7301">左肩较高 · 7301</option><option value="high_left_7319">左肩较高 · 7319</option><option value="shallow_corner_7301">浅侧转角 · 7301</option><option value="shallow_corner_7319">浅侧转角 · 7319</option><option value="tripo_refined">现有Tripo母样的下部修整副本</option></select><nav id="fv"></nav>
<div class="pair"><figure><figcaption>上一份Tripo原始母样（不是正式默认场景）</figcaption><img id="f0"></figure><figure><figcaption id="fl"></figcaption><img id="f1"></figure></div>
<h2>实体土层：均匀厚层 → 浅薄断续层</h2><p>两个状态使用同一程序母样、同一地块、同一雕刻格式和匹配视角。浅层用约1.4–17厘米的实际体积变化减少棕色硬边；没有另盖一圈装饰外壳。45个地块由母样推导，尚非任意布局再生。</p>
<select id="contactMode"><option value="contact">土草实际效果</option><option value="soil_neutral">实体土层 · 中性材质</option><option value="sampled_neutral">原始可雕刻重建 · 中性材质</option><option value="carved">实际雕刻后</option></select><nav id="cv"></nav>
<div class="pair"><figure><figcaption>均匀25厘米土层对照</figcaption><img id="c0"></figure><figure><figcaption>浅薄断续实体土层候选</figcaption><img id="c1"></figure></div>
<p>新候选171个草根保留完整叶片并贴在实际表面。几何、存读和精确雕刻历史检查通过；岩面仍偏板状、底部仍像楔体，草缘也未达到目标，检查通过不是美术验收。</p>
<h2>代码粗模 → 图片细化：轮廓保持，不等于三维保持</h2>
<select id="iv"><option value="front">正面</option><option value="left">左侧</option><option value="right">右侧</option><option value="back">背面</option></select>
<div class="pair"><figure><figcaption>同一个代码模型直接渲染</figcaption><img id="i0"></figure><figure><figcaption>AI添加岩面细节 · 是参考图，不是引擎模型</figcaption><img id="i1"></figure></div>
<p>四张选中图片的轮廓重合约98.6%–99.2%。实际再生成一次无纹理模型花费100点，三维厚度仍加大，且留下边界缺陷。原始导出和失败副本全部保留。</p>
<h2>实际返回和后处理：均拒绝</h2><select id="ai"><option value="new">Tripo原始返回 · 19处边缺陷</option><option value="closed">补洞副本 · 仍有6处边缺陷</option><option value="constrained">限制到代码表面附近 · 出现1222对严格交叉</option></select><nav id="av"></nav>
<div class="pair"><figure><figcaption>代码几何对照 · 统一宽度和中心</figcaption><img id="a0"></figure><figure><figcaption>实际失败副本 · 不采样、不替换</figcaption><img id="a1"></figure></div>
<p>结论是这次软引导和最近点投影不合格，不是所有AI模型都无效。后续可用代码库继续设计大形，精细资产按几何与实景筛选后再替换，不盲目批量付费。</p>
<p><a href="README.md">完整报告与限制</a> · <a href="/art/source/code_guided_cliff/2026-10-18/manifest.json">本次生成记录</a> · <a href="/art/work/cliff_guides/2026-10-18/code_authored_family.blend">可编辑的六模型Blender文件</a></p>
<p>176张当前实际引擎截图；早期失败批次另存。正式默认、树木、建筑、布局和水体未改。任意轮廓生成、正式编辑器整合、目标设备及用户美术验收仍未完成。</p></main>
<script>const labels={close:'近景',grass:'上部交界',whole:'整体',reverse:'反向',bottom:'底部'};let fv='close',cv='grass',av='close';function nav(id,fn){for(const [k,l]of Object.entries(labels)){let b=document.createElement('button');b.textContent=l;b.dataset.key=k;b.onclick=()=>fn(k);document.getElementById(id).append(b)}}function active(id,v){document.querySelectorAll('#'+id+' button').forEach(b=>b.classList.toggle('active',b.dataset.key===v))}
function family(){let s=document.querySelector('#family').value;document.querySelector('#f0').src='tripo_source_'+fv+'.png';document.querySelector('#f1').src=s+'_'+fv+'.png';document.querySelector('#fl').textContent=document.querySelector('#family').selectedOptions[0].text;active('fv',fv)}
function contact(){let s=document.querySelector('#contactMode').value;for(const [id,dir]of [['c0','contact_control'],['c1','contact_soft']])document.getElementById(id).src=dir+'/'+s+'_'+cv+'.png';active('cv',cv)}
function inputs(){let v=document.querySelector('#iv').value;document.querySelector('#i0').src='white/broad_turn_7301_'+v+'.png';document.querySelector('#i1').src='/art/source/code_guided_cliff/2026-10-18/inputs/'+v+'.png'}
function ai(){let s=document.querySelector('#ai').value;document.querySelector('#a0').src='../code_guided_result/constraint/guide_'+av+'.png';document.querySelector('#a1').src='../code_guided_result/constraint/'+s+'_'+av+'.png';active('av',av)}
nav('fv',v=>{fv=v;family()});nav('cv',v=>{cv=v;contact()});nav('av',v=>{av=v;ai()});for(const[id,fn]of [['family',family],['contactMode',contact],['iv',inputs],['ai',ai]])document.getElementById(id).onchange=fn;for(const i of document.querySelectorAll('img'))i.onclick=()=>window.open(i.src,'_blank');family();contact();inputs();ai();</script></html>'''
    (OUT/'index.html').write_text(html)
    print('STRATEGY REVIEW:',total,'verified current frames; failed AI branches explicit; local candidates finite-gated')


if __name__=='__main__':run()
