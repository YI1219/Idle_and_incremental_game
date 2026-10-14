"""Build the local reference/actual-runtime gallery for the courtyard pass."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
VIEWS = [('courtyard', '庭院近景'), ('overview', '全岛'), ('distant', '远景'), ('ground', '草土材质'), ('shore', '池岸'), ('rim', '草石交界'), ('reverse', '背面'), ('bottom', '底面')]
options = ''.join(f'<option value="{key}">{label}</option>' for key, label in VIEWS)
cards = ''.join(f'<a href="final_{key}.png" target="_blank"><img src="final_{key}.png" loading="lazy" alt="{label}"><span>{label}</span></a>' for key, label in VIEWS[2:])
page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>云露村 · 云间庭院</title>
<style>*{box-sizing:border-box}body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.65 system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:36px}h1{font:500 42px Georgia,serif;margin:10px 0}h2{font-size:23px;font-weight:500;margin-top:46px}p{color:#63736a;max-width:900px}img{display:block;width:100%;border-radius:8px}a{color:#556d5b}label{display:inline-flex;gap:12px;align-items:center;margin:10px 24px 10px 0}select{font:inherit;padding:7px 12px;color:inherit;background:#f8f6ed;border:1px solid #bdc7bd;border-radius:4px}input{width:220px}summary{cursor:pointer;padding:15px 0;color:#66776b}#compare{position:relative;aspect-ratio:1671/941;overflow:hidden;border-radius:8px}#compare img{position:absolute;inset:0;width:100%;height:100%}#before{clip-path:inset(0 50% 0 0)}#divider{position:absolute;top:0;bottom:0;left:50%;border-left:2px solid #fffc}.labels{display:flex;justify-content:space-between;color:#66776b;font-size:14px;margin:8px 0}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}.grid a{text-decoration:none}.grid span{display:block;padding:7px 2px}footer{padding:40px 0;color:#718073;font-size:13px}@media(max-width:800px){main{padding:18px}h1{font-size:31px}.grid{grid-template-columns:repeat(2,1fr)}}</style>
<main><span style="letter-spacing:.25em;color:#7f8c7a">云露村 / 实景美术调整</span><h1>云间庭院</h1><p>暖阳照亮白墙与青瓦，冷色云海衬出植物、草土小路和碧水。保留原岛形，让已有庭院更自然、更亲近。</p>
<img src="final_camera_b.png" alt="当前庭院实景"><p>当前 Godot 实景 · 庭院观察视角。编辑器仍保留全岛起始视角，可自由缩放和环绕。</p>
<details><summary>查看本轮参考图</summary><img src="concept.png" alt="用户提供的庭院概念参考"><p>概念图指导氛围与材质完成度。人物、界面和固定山水布局没有照搬。</p></details>
<h2>同视角前后对照</h2><label>视角 <select id="view">OPTIONS</select></label><label>拖动对比 <input id="split" type="range" min="0" max="100" value="50" aria-label="前后对比"></label><div class="labels"><span>修改前</span><span>本轮实景</span></div>
<div id="compare"><img id="after" src="final_courtyard.png" alt="调整后"><img id="before" src="before_courtyard.png" alt="调整前"><div id="divider"></div></div>
<p><a id="full" href="final_courtyard.png" target="_blank">打开当前视角大图</a></p><h2>远看与近看</h2><div class="grid">CARDS</div>
<details><summary>本轮取舍与剩余差距</summary><p>比较了稀疏树冠与饱满树冠、背光与前侧暖光、小屋比例及三组庭院视角。保留饱满树形、前侧暖光和更清楚的建筑比例；菜圃移出墙体，草土路保持通畅。</p><p>现有树形仍不同于参考中的松树；远山、崖面和池岸造型仍较简化。近距离部分叶片与水面效果仍带有游戏化痕迹。这里展示本轮的实际改善，不代表已达到概念图完成度。</p></details>
<footer>所有前后截图均来自运行中的 Godot 场景。地形、植物支撑与编辑再生成保留；实际目标笔记本性能仍待测。</footer></main>
<script>const view=document.querySelector('#view'),split=document.querySelector('#split');function update(){document.querySelector('#before').style.clipPath=`inset(0 ${100-split.value}% 0 0)`;document.querySelector('#divider').style.left=split.value+'%'}split.oninput=update;view.onchange=()=>{document.querySelector('#after').src='final_'+view.value+'.png';document.querySelector('#before').src='before_'+view.value+'.png';document.querySelector('#full').href='final_'+view.value+'.png'};</script></html>'''
OUT.mkdir(parents=True, exist_ok=True)
(OUT/'comparison.html').write_text(page.replace('OPTIONS',options).replace('CARDS',cards))
print(OUT/'comparison.html')
