"""Verify current native comparison identities and publish the local review."""
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'art/review/terrain_fidelity/2026-10-18/beautiful_island'
OUT=BASE/'playable'
WORK=ROOT/'art/work/retained_island/2026-10-18'
CASES=['courtyard_7301','courtyard_7319','bay_7301','bay_7319']
VIEWS=['whole','play','close','reverse','low']


def run():
    current=json.loads((OUT/'captures.json').read_text())
    control=json.loads((OUT/'control/captures.json').read_text())
    assert set(current['stages'])==set(control['stages'])==set(CASES)
    hashes={}
    sheet=Image.new('RGB',(1670,4*212),'#203b36')
    draw=ImageDraw.Draw(sheet)
    for row,case in enumerate(CASES):
        folder=WORK if case==CASES[0] else WORK/case
        original=json.loads((folder/'control.layout').read_text())
        candidate=json.loads((folder/'candidate.layout').read_text())
        assert original['cells']==candidate['cells']
        stage=current['stages'][case]
        assert stage['source_draws']==0 and stage['ordinary_version']==4
        assert stage['major_props']==control['stages'][case]['major_props']
        geometry=folder/'output_geometry/playable.bin'
        assert hashlib.sha256(geometry.read_bytes()).hexdigest()==stage['vertex_sha256']
        assert geometry.stat().st_size==stage['triangles']*36
        for col,view in enumerate(VIEWS):
            name=f'{case}_{view}.png'
            a=next(f for f in current['captures'] if f['file']==name)
            b=next(f for f in control['captures'] if f['file']==name)
            assert a['position']==b['position'] and a['rotation']==b['rotation']
            for prefix in ['', 'control/']:
                path=OUT/prefix/name
                assert Image.open(path).size==(1671,941)
                hashes[prefix+name]=hashlib.sha256(path.read_bytes()).hexdigest()
            thumb=Image.open(OUT/name).resize((334,188))
            sheet.paste(thumb,(col*334,row*212+24))
            draw.text((col*334+5,row*212+4),case+' / '+view,fill='#eef2d8')
    sheet.save(OUT/'all_views.png')
    record={'native_frames':40,'four_fixed_cases':CASES,'five_matched_global_cameras':True,
            'same_cells_and_major_prop_names_with_control':True,'source_draws_in_candidates':0,
            'png_sha256':hashes,'user_art_accepted':False,'goal_status':'active',
            'limits':'Fixed offline authored presets, not arbitrary-contour runtime crown compiler. New land uses existing shared base; target devices/power and user art acceptance open. Native GPU support audit separate from dummy headless server.'}
    (OUT/'verification.json').write_text(json.dumps(record,indent=2)+'\n')
    html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>浮庭 · 可编辑小岛试作</title>
<style>body{margin:0;background:#19282a;color:#edf1e8;font:16px/1.65 system-ui}main{max-width:1600px;margin:auto;padding:24px}h1{font-size:28px}h2{font-size:21px}.status{padding:12px 16px;background:#30413d;border-left:4px solid #c6dca5}.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px}figure{margin:0;background:#304245;border-radius:9px;overflow:hidden}figcaption{padding:10px 14px}img{display:block;width:100%;cursor:zoom-in}button,a.button{display:inline-block;background:#344c4e;border:1px solid #7e958b;color:#edf1e8;border-radius:6px;padding:8px 12px;margin:3px;font:inherit;text-decoration:none}button.active{background:#d3dfb6;color:#233429}p{color:#cbd5ca}a{color:#d8e8ba}.details{background:#253b3a;border-radius:8px;padding:12px 16px}code{font-size:13px;word-break:break-all}table{border-collapse:collapse}td,th{padding:8px 14px;border-bottom:1px solid #4d6460;text-align:left}@media(max-width:800px){.pair{grid-template-columns:1fr}main{padding:14px}}</style>
<main><h1>浮庭：朝美观、统一、可编辑推进</h1>
<p class="status">当前是可操作候选，长目标仍在进行。已经允许简化和夸张，不再要求复刻旧概念图；尚未宣称达到参考游戏水准或获得美术认可。</p>
<p>保留房屋、树木资产及主要摆放，以原有岩体作为整体形状的基础，转成同一片可雕刻地形。新候选收短底部、保证树脚的真实支撑，并减弱细碎地表噪声。石壁仍有平直块面，草石边缘仍偏涂色，属于需要继续判断的部分。</p>
<nav id="cases"></nav><nav id="views"></nav>
<div class="pair"><figure><figcaption>相同岛形 / 种子 · 原版渲染规则</figcaption><img id="original"></figure><figure><figcaption id="label">当前可编辑候选</figcaption><img id="candidate"></figure></div>
<p>40张当前 Godot 实拍，匹配相机和地块。配色、柔光、整体岩体、草地覆盖和底部作为完整方案比较；并非单变量实验。背景仅为清爽对比而简化，没有额外锁定地形。点击图片看原尺寸。</p>
<p><a class="button" href="../references.html">三个参考游戏的官方画面</a> <a class="button" href="../index.html">早期完整方案</a> <a class="button" href="../whole_object.html">未胜出的整体形体试验</a></p>
<h2>实际操作</h2><p>本地 Godot 场景为 <code>scenes/beautiful_island.tscn</code>，原版仍是 <code>scenes/terrain_editor.tscn</code>。左键编辑，右键拖动环绕，中键或 WASD 平移，滚轮缩放，Home 回中。左侧可切换两种岛形和两个种子、雕刻、放置土地、撤销重做及保存读取。试作使用自己的存档。</p>
<p>这里的“放置”指土地编辑；这个美术试作没有新增建筑自由摆放界面。四个预设为离线生成后保存的普通地形数据；它们可继续编辑，但不代表已实现任意新轮廓的实时岩体编排。</p>
<h2>验证和剩余差距</h2><div class="details"><p>同一可雕刻数据生成可见岩面，候选中不再叠放原始侧壁模型。底部修形也写在同一存档里。几何检查、实际编辑、支撑、存读和画面各自验收，功能通过不等于美术通过。</p><p><a href="verification.json">40张实拍核对</a> · <a href="captures.json">本机帧时与重建记录</a> · <a href="support.json">当前原生渲染支撑检查</a> · <a href="/art/work/retained_island/2026-10-18/verification.json">四组合实际切削 / 历史 / 存读 / 几何检查</a></p><p>开发机为 Apple M4 Pro；单次切换重建约3.5–3.8秒，编辑响应还有明显优化空间。帧时是这台机器的短时观察，不代表 Windows 轻薄本、MacBook Air、长期挂机功耗或稳定性达标。</p></div>
<p>下一步由实际整体美感决定继续收敛哪种形体、材质和草石衔接。当前版本没有替换正式默认场景，没有付费三维生成或购买。</p></main>
<script>let current='courtyard_7301',view='whole';const cases={courtyard_7301:'圆庭 · 7301',courtyard_7319:'圆庭 · 7319',bay_7301:'曲湾 · 7301',bay_7319:'曲湾 · 7319'},views={whole:'整体',play:'游玩距离',close:'近景',reverse:'反向',low:'低角度'};function render(){document.getElementById('original').src='control/'+current+'_'+view+'.png';document.getElementById('candidate').src=current+'_'+view+'.png';document.getElementById('label').textContent=cases[current]+' · 当前可编辑候选';document.querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.case===current||b.dataset.view===view))}for(const[k,v]of Object.entries(cases)){const b=document.createElement('button');b.textContent=v;b.dataset.case=k;b.onclick=()=>{current=k;render()};document.getElementById('cases').append(b)}for(const[k,v]of Object.entries(views)){const b=document.createElement('button');b.textContent=v;b.dataset.view=k;b.onclick=()=>{view=k;render()};document.getElementById('views').append(b)}for(const i of document.querySelectorAll('img'))i.onclick=()=>window.open(i.src,'_blank');render();</script></html>'''
    (OUT/'index.html').write_text(html)
    print('PLAYABLE REVIEW: 40 fresh native frames; 4 cases x 5 matched camera pairs; ACTUAL ART ACCEPTANCE OPEN')


if __name__=='__main__':run()
