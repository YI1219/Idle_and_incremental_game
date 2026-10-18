# coding: utf-8
"""Verify25actual frames and build the bounded source/soil review."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/review/terrain_fidelity/2026-10-18/master_mantle'


def run():
    data=json.loads((OUT/'captures.json').read_text());frames=data['frames']
    assert len(frames)==25 and len({f['file'] for f in frames})==25
    for f in frames:
        assert f['error']==0 and (OUT/f['file']).stat().st_size>10000
        peers=[p for p in frames if p['view']==f['view']]
        assert len(peers)==5
        assert all([p[k] for k in ['position','target','size']]==[f[k] for k in ['position','target','size']] for p in peers)
    html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<title>岩体与薄土层 · 实际接合验证</title>
<style>
body{margin:0;background:#162123;color:#e9eee5;font:16px/1.6 system-ui}main{max-width:1500px;margin:auto;padding:26px}
h1{font-size:26px;margin:0}p{color:#becbc4}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}
figure{margin:0;background:#263639;border-radius:8px;overflow:hidden}figcaption{padding:11px 14px}img{width:100%;display:block;cursor:zoom-in}
button,select{background:#2a3b3c;color:inherit;border:1px solid #607671;border-radius:7px;padding:9px;margin:3px;cursor:pointer}
button.active{background:#bdcfa1;color:#15201a}a{color:#c5dbac}small{color:#b9c9c2}@media(max-width:850px){.grid{grid-template-columns:1fr}}
</style><main><h1>物理土层与接地已验证，形体仍未达到目标</h1>
<p>这轮保留已有母样比例，按11米宽的完整样段检验，并把薄土层写进同一份可雕刻地形数据。仍有窄石脊、宽灰台、机械台阶与厚圆岩腹；这是未通过美术验收的小样。</p>
<div class="grid"><figure><figcaption>目标图 · 构图与相机不同</figcaption>
<img src="/art/source/visual_targets/2026-10-16/cliff_user_target.png"></figure>
<figure><figcaption>本轮候选 · 实际 Godot 近景</figcaption><img src="contact_close.png"></figure></div>
<p>下面五组视角使用相同相机。可切换原始母样、可雕刻转换和有体积的薄土层；中性材质用于检查真实形状。</p>
<nav id="views"></nav><p>
<label>左侧 <select id="leftStage"><option value="source_neutral">原始母样 · 中性材质</option><option value="sampled_neutral">转换后 · 中性材质</option><option value="soil_neutral">加土后 · 中性材质</option></select></label>
<label>右侧 <select id="rightStage"><option value="contact">加土与草 · 最终小样</option><option value="soil_neutral">加土后 · 中性材质</option><option value="carved">公开雕刻操作后</option></select></label></p>
<div class="grid"><figure><figcaption id="leftLabel"></figcaption><img id="leftImage"></figure>
<figure><figcaption id="rightLabel"></figcaption><img id="rightImage"></figure></div>
<p>草根71个，完整叶片顶点33,015个。草根与实际表面吻合，并落在保存的实际地块中。原始、转换、加土、接地、雕刻后五份几何通过本轮有限检查；编辑存读9项检查通过。技术通过不代表美术完成。</p>
<p>土层受平滑地块轮廓约束，部分新增体积会越过实际格子的凹角；材质顶点与草根另做实际格检查。这些体积仍在同一份可编辑密度数据内。该小样从母样反推地块，尚不能作为由任意地块轮廓生成场景的PCG或正式编辑器。</p>
<p><a href="README.md">完整审查</a> · <a href="../tripo_master/index.html">之前白模与转换对比</a> · <a href="../pcg_fracture/index.html">之前两条路线的对比</a></p>
<small>没有新生成模型或贴图，没有改动正式默认版本、树木、建筑、布局或水体。首次接地中断的25张图已隔离，不计入本页。</small></main>
<script>
let view='close';const labels={close:'近景',grass:'草石交界',whole:'整体',reverse:'反向',bottom:'底部'};
for(const [key,label] of Object.entries(labels)){let b=document.createElement('button');b.textContent=label;b.dataset.key=key;b.onclick=()=>{view=key;draw()};document.querySelector('#views').append(b)}
function draw(){for(const side of ['left','right']){let s=document.querySelector('#'+side+'Stage');document.querySelector('#'+side+'Image').src=s.value+'_'+view+'.png';document.querySelector('#'+side+'Label').textContent=s.selectedOptions[0].textContent}document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('active',b.dataset.key===view))}
document.querySelectorAll('select').forEach(s=>s.onchange=draw);document.querySelectorAll('img').forEach(i=>i.onclick=()=>window.open(i.src,'_blank'));draw();
</script></html>'''
    (OUT/'index.html').write_text(html)
    print('MASTER MANTLE REVIEW:25verified frames with matching cameras')


if __name__=='__main__':run()
