"""Verify current native captures and publish the selected-source review locally."""
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/review/terrain_fidelity/2026-10-18/tripo_land_v2'


def run():
    white=json.loads((OUT/'captures.json').read_text())
    contact=json.loads((OUT/'contact/captures.json').read_text())
    for folder,report,count in [('',white,32),('contact',contact,25)]:
        assert len(report['frames'])==count
        for frame in report['frames']:
            assert frame['error']==0
            assert Image.open(OUT/folder/frame['file']).size==(1671,941)
            peers=[p for p in report['frames'] if p['view']==frame['view']]
            assert all([p[k] for k in ['position','target','size']]==[frame[k] for k in ['position','target','size']] for p in peers)
    geometry=json.loads((ROOT/'art/work/cliff_land_v2/2026-10-18/geometry_checks.json').read_text())
    edited=json.loads((ROOT/'art/work/cliff_land_v2/2026-10-18/contact/geometry_checks.json').read_text())
    assert set(geometry['stages'])=={'old','new'} and all(s['finite_gate_passes'] for s in geometry['stages'].values())
    assert set(edited['stages'])=={'master_source','sampled_neutral','soil_neutral','contact','carved'} and all(s['finite_gate_passes'] for s in edited['stages'].values())
    html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>新崖壁母样 · 实景对比</title>
<style>body{margin:0;background:#172426;color:#eef0e5;font:16px/1.65 system-ui}main{max-width:1600px;margin:auto;padding:24px}h1{font-size:27px}h2{font-size:22px;margin-top:32px}p{color:#c4d0c7}.pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}figure{margin:0;background:#2b3d3e;border-radius:10px;overflow:hidden}figcaption{padding:10px 14px}img{width:100%;display:block;cursor:zoom-in}button,select{background:#31484a;color:#f3f1de;border:1px solid #718880;padding:10px;border-radius:7px;margin:3px;cursor:pointer}button.active{background:#ccdaa8;color:#172426}a{color:#d1e6a4}.four{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}@media(max-width:850px){.pair{grid-template-columns:1fr}.four{grid-template-columns:repeat(2,1fr)}}</style>
<main><h1>新崖壁母样：宽地表直接衔接崖面</h1>
<p>已按选择重设四视图并生成一次无纹理模型。新母样有实质结构进步：上部形成宽连续地面，旧窄山脊和大横台明显减少；底部鼓包、硬土边和背面整墙仍未解决，当前仍是候选。</p>
<div class="pair"><figure><figcaption>用户目标 · 构图与相机不同，只作形体和完成度参考</figcaption><img src="/art/source/visual_targets/2026-10-16/cliff_user_target.png"></figure><figure><figcaption>本轮实际 Godot 土草样段 · 尚未达到目标</figcaption><img src="contact/contact_grass.png"></figure></div>
<p>本次 Tripo：P2.0，单个模型，目标5,000面／实际5,028三角面，2,516顶点，实际消耗100点。未生成贴图。原始模型和正式场景保留。</p>
<h2>新旧白模：相同宽度、相同相机与材质</h2>
<p>两者均只做刚性朝向对齐与等比缩放至6.5米宽。旧模型深5.591米，新模型深3.769米，减少约33%；并非通过压扁来制造改善。</p>
<select id="normal"><option value="crease">相同折角法线</option><option value="white">各自原始导入法线</option></select><nav id="whiteViews"></nav>
<div class="pair"><figure><figcaption>上一份原始白模</figcaption><img id="old"></figure><figure><figcaption>新原始白模</figcaption><img id="new"></figure></div>
<h2>转为可雕刻数据，再加入真实土层和草</h2>
<p>这一组把新母样等比放大为11米宽，保留原比例；所有组内相机匹配。土层和岩体在同一份可保存、雕刻的数据中；草根落在实际表面。地块由母样推导，尚不具备任意轮廓自动再生能力。</p>
<select id="pair"><option value="convert">原始形体 → 可雕刻重建（中性材质）</option><option value="soil">重建 → 加入实体土层（中性材质）</option><option value="finish" selected>实体土层 → 土草材质与草</option><option value="edit">土草候选 → 实际雕刻</option></select><nav id="contactViews"></nav>
<div class="pair"><figure><figcaption id="labelA"></figcaption><img id="a"></figure><figure><figcaption id="labelB"></figcaption><img id="b"></figure></div>
<p>重建会软化主面并加入格点小面；当前土边仍偏齐，底部仍有多个垂脚。先前土色沿低岩肩下垂的错误已定位修正，早期结果另行保留。有限几何及数据历史检查通过，不代表美术、任意编辑、两种轮廓／种子或性能验收。</p>
<h2>四张独立生成参考</h2><div class="four">VIEWS</div>
<p><a href="README.md">本轮报告</a> · <a href="/art/source/cliff_master_v2/2026-10-18/manifest.json">参数和原始记录</a> · <a href="/art/source/cliff_master_v2/2026-10-18/tripo/cliff_land_master_v2_white.glb">新原始白模 GLB</a></p>
<p>本页57张当前实际引擎截图。正式默认版本、树木、建筑、布局和水体未修改。完整目标仍未完成。</p></main>
<script>let w='close',c='grass';const names={front:'正面',back:'背面',left:'左侧',right:'右侧',close:'近景',grass:'草石交界',whole:'整体',reverse:'反向',bottom:'底部'};
function buttons(id,keys,change){for(const key of keys){let b=document.createElement('button');b.textContent=names[key];b.dataset.key=key;b.onclick=()=>change(key);document.getElementById(id).append(b)}}
function white(){let n=document.querySelector('#normal').value;for(const k of ['old','new'])document.getElementById(k).src=k+'_'+n+'_'+w+'.png';document.querySelectorAll('#whiteViews button').forEach(b=>b.classList.toggle('active',b.dataset.key===w))}
const pairs={convert:['source_neutral','sampled_neutral','原始三维模型','同一模型的可雕刻重建'],soil:['sampled_neutral','soil_neutral','可雕刻重建','实体浅土层'],finish:['soil_neutral','contact','实体浅土层 · 中性材质','土草候选 · 未验收'],edit:['contact','carved','雕刻前','公开雕刻操作后']};
function contact(){let p=pairs[document.querySelector('#pair').value];for(const [id,i]of [['a',0],['b',1]])document.getElementById(id).src='contact/'+p[i]+'_'+c+'.png';document.querySelector('#labelA').textContent=p[2];document.querySelector('#labelB').textContent=p[3];document.querySelectorAll('#contactViews button').forEach(b=>b.classList.toggle('active',b.dataset.key===c))}
buttons('whiteViews',['front','back','left','right','close','whole','reverse','bottom'],key=>{w=key;white()});buttons('contactViews',['close','grass','whole','reverse','bottom'],key=>{c=key;contact()});document.querySelector('#normal').onchange=white;document.querySelector('#pair').onchange=contact;document.querySelectorAll('img').forEach(i=>i.onclick=()=>window.open(i.src,'_blank'));white();contact();</script></html>'''
    views=''.join(f'<figure><figcaption>{label}</figcaption><img src="/art/source/cliff_master_v2/2026-10-18/inputs/{name}.png"></figure>' for name,label in [('front','正面'),('left','左侧'),('right','右侧'),('back','背面')])
    (OUT/'index.html').write_text(html.replace('VIEWS',views))
    print('LAND V2 REVIEW:57 current native frames, matched groups,7 finite gates confirmed')


if __name__=='__main__':run()
