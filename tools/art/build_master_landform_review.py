# coding: utf-8
"""Verify the two rejected form-rule studies and present actual native pairs."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/review/terrain_fidelity/2026-10-18/master_landform'


def run():
    reports=[json.loads((OUT/p/'captures.json').read_text()) for p in [Path('.'),Path('inverse')]]
    frames=[f for d in reports for f in d['frames']]
    assert len(frames)==20
    for folder,report in zip(['.','inverse'],reports):
        assert len(report['frames'])==10
        for f in report['frames']:
            assert f['error']==0 and (OUT/folder/f['file']).stat().st_size>10000
            peers=[p for p in frames if p['view']==f['view']]
            assert len(peers)==4
            assert all([p[k] for k in ['position','target','size']]==[f[k] for k in ['position','target','size']] for p in peers)
    direct=json.loads((ROOT/'art/work/master_landform/2026-10-18/geometry_checks.json').read_text())
    inverse=json.loads((ROOT/'art/work/master_landform/2026-10-18/inverse/geometry_checks.json').read_text())
    assert direct['stages']['source']['finite_gate_passes']
    assert not direct['stages']['candidate']['finite_gate_passes']
    assert inverse['stages']['source_field']['finite_gate_passes']
    assert not inverse['stages']['candidate_field']['finite_gate_passes']
    html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<title>两轮整体修形 · 实际失败对比</title>
<style>
body{margin:0;background:#182224;color:#eef0e6;font:16px/1.6 system-ui}main{max-width:1500px;margin:auto;padding:26px}
h1{font-size:26px;margin:0}p{color:#c2ccc5}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}
figure{margin:0;background:#28383a;border-radius:8px;overflow:hidden}figcaption{padding:11px 14px}img{display:block;width:100%;cursor:zoom-in}
button,select{background:#2b3b3d;color:inherit;border:1px solid #607671;border-radius:7px;padding:10px;margin:3px;cursor:pointer}
button.active{background:#bfcea2;color:#17211a}a{color:#cedfae}small{color:#bbc8c2}@media(max-width:850px){.grid{grid-template-columns:1fr}}
</style><main><h1>两轮整体修形未通过，停止继续试调</h1>
<p>这轮改了上部地表、主岩面与共用底部的关系。第一版抬后侧石台后出现高直墙与穿插；第二版从原本有效的体积重排高度，仍形成柱状侧壁和封闭空腔。都没有达到目标。</p>
<div class="grid"><figure><figcaption>用户目标 · 构图和相机不同</figcaption>
<img src="/art/source/visual_targets/2026-10-16/cliff_user_target.png"></figure>
<figure><figcaption>第二版实际 Godot 近景 · 中性材质 · 未通过</figcaption><img src="inverse/candidate_field_close.png"></figure></div>
<p>下方两组实验各自使用匹配相机、材质和法线规则。第二版读取有效的原始体积数据，没有使用第一版穿插的网格。</p>
<select id="route"><option value="direct">第一版：调整现有网格副本</option><option value="inverse" selected>第二版：重排原始有效体积</option></select><nav id="views"></nav>
<div class="grid"><figure><figcaption id="leftLabel"></figcaption><img id="left"></figure>
<figure><figcaption id="rightLabel"></figcaption><img id="right"></figure></div>
<p id="result"></p>
<p>原始模型和原有数据均保留。本轮没有新提交Tripo、生成贴图或修改正式默认版本。两版均不进入草、材质细化或整岛推广。</p>
<p>按已约定的两轮停止条件，下一步需要选择母样制作方式：重新设计可拼接崖壁参考并再生成，或由你在Blender手工修现有模型的主要结构。前者重点是宽地表直接转入错落崖面，取消作为独立平台的横台。</p>
<p><a href="README.md">完整报告</a> · <a href="../master_mantle/index.html">上一轮真实土层与接地</a> · <a href="../tripo_master/index.html">原始白模与转换</a></p>
<small>本轮20张新引擎截图。数据存读检查通过不构成几何、美术、任意轮廓或正式编辑器验收。目标仍未完成。</small></main>
<script>
let view='close';const views={close:'近景',grass:'上部衔接',whole:'整体',reverse:'反向',bottom:'底部'};
for(const [key,label] of Object.entries(views)){let b=document.createElement('button');b.textContent=label;b.dataset.key=key;b.onclick=()=>{view=key;draw()};document.querySelector('#views').append(b)}
function draw(){const inverse=document.querySelector('#route').value==='inverse';document.querySelector('#left').src=(inverse?'inverse/source_field_':'source_')+view+'.png';document.querySelector('#right').src=(inverse?'inverse/candidate_field_':'candidate_')+view+'.png';document.querySelector('#leftLabel').textContent=inverse?'原始有效可雕刻体积':'原始母样网格';document.querySelector('#rightLabel').textContent=inverse?'体积重排候选 · 未通过':'网格修形候选 · 未通过';document.querySelector('#result').textContent=inverse?'第二版：未检出严格面片穿插，但多出一个内向封闭表面，探针显示其为空腔。地表仍有断阶、长柱和薄片风险。':'第一版：原有顶点连接关系仍闭合，但检测到32处严格面片穿插；后侧变成了高直墙。';document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('active',b.dataset.key===view))}
document.querySelector('#route').onchange=draw;document.querySelectorAll('img').forEach(i=>i.onclick=()=>window.open(i.src,'_blank'));draw();
</script></html>'''
    (OUT/'index.html').write_text(html)
    print('LANDFORM REVIEW:20verified frames,two rejected geometry/art stages')


if __name__=='__main__':run()
