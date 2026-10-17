# -*- coding: utf-8 -*-
"""Validate and publish the bounded native geometry/material comparison."""
import hashlib,json,shutil,struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/cliff_representation/2026-10-17'
OUT=ROOT/'art/review/terrain_fidelity/2026-10-17/cliff_representation'
GALLERY=ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
LOGS=['cliff_manifold','cliff_sampling','cliff_reconstruction','cliff_measure','cliff_representation_capture','cliff_representation_scene']

def run():
    reports={name:json.loads((WORK/(name+'.json')).read_text()) for name in ['native_kernel','sampling','reconstruction','measurements']}
    assert reports['sampling']['source_sha256']==hashlib.sha256((WORK/'union.bin').read_bytes()).hexdigest()
    assert reports['reconstruction']['record_roundtrip_equal']
    original=ROOT/'art/work/rendered_island/2026-10-17/complete'
    assert (WORK/'assembly.bin').read_bytes()==b''.join((original/f'crown_{i}.bin').read_bytes() for i in [36,37,38])
    groups={name:json.loads((OUT/name).read_text()) for name in ['captures.json','scene_captures.json']}
    assert len(groups['captures.json']['captures'])==33 and len(groups['scene_captures.json']['captures'])==16
    matched={};images={}
    for group,report in groups.items():
        for entry in report['captures']:
            assert entry['error']==0
            name=entry['file'];raw=(OUT/name).read_bytes();assert raw[:8]==b'\x89PNG\r\n\x1a\n'
            size=list(struct.unpack('>II',raw[16:24]));assert size==([1440,960] if group=='captures.json' else [1671,941])
            parts=name.removesuffix('.png').split('_')
            camera_key=('scene_'+parts[-1]) if group=='scene_captures.json' else ('lab_'+parts[-1])
            camera=[entry['position'],entry['rotation'],entry.get('size')]
            if camera_key in matched:assert matched[camera_key]==camera
            matched[camera_key]=camera
            images[name]=hashlib.sha256(raw).hexdigest()
            shutil.copy2(OUT/name,GALLERY/('representation_'+name))
    scene=groups['scene_captures.json']
    assert scene['replaced_source_instances']==3 and scene['unchanged_authoritative_data'] and scene['water_phase']==1.25
    assert set(scene['cap_draw_controls'])=={'assembly','union','sampled'}
    assert all(x['lid_triangles_not_drawn']>0 for x in scene['cap_draw_controls'].values())
    (OUT/'logs').mkdir(exist_ok=True)
    for name in LOGS:
        text=(Path('/tmp')/('yunlu_'+name+'.log')).read_text()
        assert not any(s in text for s in ['SCRIPT ERROR','SHADER ERROR','Traceback','AssertionError','ERROR:']),name
        shutil.copy2(Path('/tmp')/('yunlu_'+name+'.log'),OUT/'logs'/(name+'.txt'))
    result={'valid_native_frames':49,'isolated_frames':33,'scene_frames':16,'camera_groups':matched,'image_sha256':images,'reports':reports,'scene_control':{k:v for k,v in scene.items() if k!='captures'},'decision':'Diagnostic evidence only. Native union retains finite sampled exterior within1mm; .25m reconstruction loses narrow features and introduces facets. Source forms still broad and crease shading imperfect. Height contact still reads as paint; do not adopt. Production unchanged; no editor/performance/whole-art acceptance.'}
    (OUT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>崖体 · 形状保留对照</title><style>body{margin:0;background:#e8e7df;color:#34413b;font:16px/1.7 system-ui}main{max-width:1900px;margin:auto;padding:24px}p{max-width:1120px}h1{font-size:28px;font-weight:550}label{display:inline-block;margin:4px 18px 12px 0}select{font:inherit;padding:7px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}figcaption{padding:9px;background:#f5f1e8}img{width:100%;display:block}table{border-collapse:collapse}td,th{text-align:left;padding:7px 18px 7px 0;border-bottom:1px solid #c8cdc4}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="comparison.html">整岛当前版本</a><h1>崖体形状保留 · 实机诊断，未替换默认版本</h1><p>同三块现有崖石，比较原始相交组合、原生几何合并，以及当前0.25米可编辑重建。直接合并保住更多原有转折；采样重建在窄缝和边缘出现收缩、圆化和细碎折面。它们都还没有达到目标图的造型品质。</p><label>对照<select id="kind"><option value="scene">实际场景 · 同材质</option><option value="flat">隔离 · 同平面法线</option><option value="crease">隔离 · 同棱角平滑算法</option><option value="stone">隔离 · 同石材</option><option value="contact">高度混合 · 未采用</option></select></label><label>视角<select id="view"></select></label><label>左侧<select id="left"><option value="assembly">原始几何组合</option><option value="union" selected>直接合并</option><option value="sampled">当前采样重建</option><option value="original">正式版本 · 仅场景参考</option></select></label><label>右侧<select id="right"><option value="sampled" selected>当前采样重建</option><option value="union">直接合并</option><option value="assembly">原始几何组合</option></select></label><div class="pair"><figure><figcaption id="lc"></figcaption><img id="li"></figure><figure><figcaption id="rc"></figcaption><img id="ri"></figure></div><p id="note"></p><table><tr><th>局部几何</th><th>三角面</th><th>封闭连通体</th></tr><tr><td>原始相交组合</td><td>2,188</td><td>3个，彼此重叠</td></tr><tr><td>直接合并</td><td>2,248</td><td>1个</td></tr><tr><td>当前采样重建</td><td>19,240</td><td>1个</td></tr></table><p>合并表面到重建表面的有限取样：平均约2.7厘米，95分位约8.9厘米，最大取样约17.3厘米；不是全局误差上界。高度混合只是材质测试，缺少实体草簇，仍像涂色边，未采用。没有据此接受运行时编辑或目标设备性能。</p><p>49张新Godot实机图：33张隔离、16张场景。场景只换三块崖石的绘制，对三种对照一致隐藏草地下的封口顶盖；闭合几何测量保留顶盖。正式版本有原来的独立石色和法线，只供场景参考。水体相位固定，云雾实时变化。无树木、建筑、布局、地形数据和默认版本修改。</p></main><script>const K=document.querySelector('#kind'),V=document.querySelector('#view'),L=document.querySelector('#left'),R=document.querySelector('#right');const names={assembly:'原始几何组合',union:'直接合并',sampled:'当前采样重建',original:'正式版本 · 非统一材质参考'};function options(){const vals=K.value==='scene'?{close:'近景',grass:'草石交界',reverse:'反向',far:'远景'}:{near:'近景',oblique:'斜向',reverse:'反向'};V.innerHTML=Object.entries(vals).map(([v,t])=>`<option value="${v}">${t}</option>`).join('');draw()}function draw(){const contact=K.value==='contact';let a=L.value,b=R.value;if(K.value!=='scene'&&a==='original')a='assembly';const file=(s)=>'representation_'+(K.value==='scene'?'scene_'+s+'_'+V.value:s+'_'+K.value+'_'+V.value)+'.png';document.querySelector('#li').src=contact?'representation_union_linear_contact_'+V.value+'.png':file(a);document.querySelector('#ri').src=contact?'representation_union_height_contact_'+V.value+'.png':file(b);document.querySelector('#lc').textContent=contact?'线性混合 · 同一几何':names[a];document.querySelector('#rc').textContent=contact?'高度混合 · 同一几何，未采用':names[b];document.querySelector('#note').textContent=contact?'真实源高度参与权重；边界更碎、更硬，但没有形成可信的实体草石接触。':K.value==='scene'?'草地、藤蔓与其余场景保留；这只是绘制对照，没有改动碰撞或编辑数据。':'隔离图展示完整闭合输入，包括正式场景中不绘制的封口顶盖。'}K.onchange=options;V.onchange=L.onchange=R.onchange=draw;options();</script></html>'''
    (GALLERY/'cliff_representation.html').write_text(page)
    print('CLIFF REPRESENTATION REVIEW: 49 valid native frames; matched7camera groups; source/maps preserved; no promotion.')

if __name__=='__main__':run()
