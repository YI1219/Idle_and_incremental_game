# coding: utf-8
"""Build an evidence-only target/original/conversion gallery from native frames."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-18/tripo_master'


def run():
    report = json.loads((OUT/'captures.json').read_text())
    frames = report['frames']
    assert len(frames) == 24
    for f in frames:
        assert (OUT/f['file']).stat().st_size > 10000
        peers = [p for p in frames if p['view'] == f['view']]
        assert len(peers) == 3
        assert all([p[k] for k in ['position','target','size']] == [f[k] for k in ['position','target','size']] for p in peers)
    target = '/art/source/visual_targets/2026-10-16/cliff_user_target.png'
    source = '/art/source/cliff_master/2026-10-18/'
    html = '''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><title>新岩体母样 · 实际效果对比</title>
<style>
body{margin:0;background:#152022;color:#ecede5;font:16px/1.6 system-ui}main{max-width:1500px;margin:auto;padding:26px}
h1{font-size:26px;margin:0}p{color:#bcc8c5}button{padding:9px 16px;border:1px solid #617471;border-radius:7px;background:#263638;color:inherit;cursor:pointer;margin:3px}
button.active{background:#bbcf9b;color:#17201b}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}
figure{margin:0;background:#263638;border-radius:8px;overflow:hidden}figcaption{padding:10px 14px}img{display:block;width:100%;height:auto;cursor:zoom-in}
.refs{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}a{color:#cadfa8}small{color:#bac7c4}
@media(max-width:850px){.grid{grid-template-columns:1fr}.refs{grid-template-columns:repeat(2,1fr)}}
</style><main>
<h1>新岩体母样：主斜面与共同收底已有，但仍未达到目标</h1>
<p>本轮已实际生成一个无贴图三维模型，并完成小范围可雕刻转换。白模仍偏厚、台阶偏平；转换又损失部分斜面和裂隙。这里展示的是实际引擎截图，未通过最终美术验收。</p>
<div class="grid"><figure><figcaption>用户目标图 · 构图与视角不同</figcaption><img src="TARGET"></figure>
<figure><figcaption>本轮四视图中的正面参考 · 输入图，不是引擎效果</figcaption><img src="SOURCEfront_v2.png"></figure></div>
<p>切换同一组相机，比较原模型、仅改变法线的平面控制，以及转换后的形体。</p><nav id="views"></nav>
<div class="grid"><figure><figcaption id="sourceLabel"></figcaption><img id="original"></figure>
<figure><figcaption>转换后 · 可雕刻数据重建 · 中性材质</figcaption><img id="sampled"></figure></div>
<button id="normals">切换原始 / 平面法线控制</button>
<p>生成费用100点，原模型5,424三角面。按宽5.5米统一缩放后，高约3.69米、深约4.73米，明显厚于参考设计意图的3米。没有使用非均匀压缩掩盖这一偏差。</p>
<p>本页未展示草土接触或正式场景整合，不能据此判断这两项已经解决。原模型和转换体通过本轮有限几何检查，编辑与存读9项检查通过；这些结果不等于美术合格。</p>
<details><summary>四个独立输入方向</summary><div class="refs">REFS</div></details>
<p><a href="README.md">完整审查记录</a> · <a href="SOURCEtripo/cliff_master_white_v1.glb">原始GLB</a> · <a href="../pcg_fracture/index.html">之前两条路线的失败对比</a></p>
<small>保留原始资产与正式默认版本。本轮候选不自动铺到整座岛，也未进行贴图生成。</small>
</main><script>
const labels={close:'近景',whole:'整体',front:'正面',back:'背面',left:'左侧',right:'右侧',bottom:'底部',reverse:'反向'};
let view='close',crease=true;
for(const [key,label] of Object.entries(labels)){let b=document.createElement('button');b.textContent=label;b.dataset.key=key;b.onclick=()=>{view=key;update()};document.querySelector('#views').append(b)}
function update(){document.querySelector('#original').src=(crease?'crease_':'white_')+view+'.png';document.querySelector('#sampled').src='sampled_'+view+'.png';document.querySelector('#sourceLabel').textContent=crease?'原模型 · 平面法线控制 · 顶点位置完全相同':'原模型 · 导出时的平滑法线';for(const b of document.querySelectorAll('nav button'))b.classList.toggle('active',b.dataset.key===view)}
document.querySelector('#normals').onclick=()=>{crease=!crease;update()};document.querySelectorAll('img').forEach(img=>img.onclick=()=>window.open(img.src,'_blank'));update();
</script></html>'''
    refs = ''.join('<figure><figcaption>'+label+'</figcaption><img src="'+source+side+'_v2.png"></figure>' for side,label in [('front','正面'),('left','左侧'),('right','右侧'),('back','背面')])
    html = html.replace('TARGET',target).replace('SOURCE',source).replace('REFS',refs)
    (OUT/'index.html').write_text(html)
    print('TRIPO REVIEW: 24 verified native frames, matched source/conversion cameras')


if __name__ == '__main__': run()
