# -*- coding: utf-8 -*-
"""Publish successful captures of rejected geometry, without implying acceptance."""
import hashlib,json,shutil,struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/cliff_dual/2026-10-17'
OUT=ROOT/'art/review/terrain_fidelity/2026-10-17/cliff_dual'
OLD=ROOT/'art/review/terrain_fidelity/2026-10-17/cliff_representation'
GALLERY=ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'

def run():
    mesh=json.loads((WORK/'report.json').read_text())
    crossings=json.loads((WORK/'intersections.json').read_text())
    edit=json.loads((WORK/'edit.json').read_text())
    assert all(edit[k] for k in ['undo_exact','redo_exact','reload_exact'])
    assert mesh['source_sha256']==hashlib.sha256((ROOT/'art/work/cliff_representation/2026-10-17/union.bin').read_bytes()).hexdigest()
    expected={'dc_field':120,'dc_hermite':79,'dc_field_edited':108,'dc_hermite_edited':77}
    for name,count in expected.items():
        stage=mesh['stages'][name];topology=stage['topology']
        assert all(topology[k]==0 for k in ['non_two_use_edges','directed_edge_pair_defects','degenerate_index_faces','nonmanifold_vertex_links'])
        assert len(topology['vertex_components'])==1 and topology['signed_volume']>0
        assert stage['reconstruction']['missing_quad_cells']==0
        entry=crossings['stages'][name]
        assert entry['mesh_sha256']==hashlib.sha256((WORK/(name+'.bin')).read_bytes()).hexdigest()
        assert entry['strict_crossing_pairs_at_least']==count>0
    assert all(crossings['stages'][name]['strict_crossing_pairs_at_least']==0 for name in ['union','sampled','sampled_edited'])
    matched={};images={}
    for scene,filename,count in [(False,'captures.json',45),(True,'scene_captures.json',8)]:
        # Reuse old controls; their cameras must match this round's captures.
        for folder,new in [(OLD,False),(OUT,True)]:
            data=json.loads((folder/filename).read_text())
            if new:assert len(data['captures'])==count
            for entry in data['captures']:
                name=entry['file']
                if not new and not (name.startswith('union_') or name.startswith('sampled_') or name.startswith('scene_union_') or name.startswith('scene_sampled_')):continue
                if 'contact' in name:continue
                key=('scene_' if scene else 'lab_')+name.removesuffix('.png').split('_')[-1]
                camera=[entry['position'],entry['rotation'],entry.get('size')]
                if key in matched:assert matched[key]==camera,(key,camera,matched[key])
                matched[key]=camera
                if not new:continue
                assert entry['error']==0
                raw=(folder/name).read_bytes();assert raw[:8]==b'\x89PNG\r\n\x1a\n'
                assert struct.unpack('>II',raw[16:24])==((1671,941) if scene else (1440,960))
                images[name]=hashlib.sha256(raw).hexdigest();shutil.copy2(folder/name,GALLERY/('dual_'+name))
    scene=json.loads((OUT/'scene_captures.json').read_text())
    assert scene['replaced_source_instances']==3 and scene['unchanged_authoritative_data']
    assert scene['water_phase']==1.25 and scene['lid_plane_tolerance']==.001
    assert all(x['lid_triangles_not_drawn']>0 for x in scene['cap_draw_controls'].values())
    (OUT/'logs').mkdir(exist_ok=True)
    for name in ['edit','bake','capture','scene','intersections','tests']:
        file=Path('/tmp')/('yunlu_cliff_dual_'+name+'.log');log=file.read_text()
        assert not any(s in log for s in ['SCRIPT ERROR','SHADER ERROR','Traceback','AssertionError','ERROR:']),name
        if name=='tests':assert 'Ran 5 tests' in log and 'OK' in log
        shutil.copy2(file,OUT/'logs'/(name+'.txt'))
    result={'successful_native_frames':53,'isolated_frames':45,'scene_frames':8,'reused_control_frames':26,
            'matched_camera_positions_rotations_and_lab_size':matched,'image_sha256':images,
            'topology_passes_but_geometry_rejected':expected,'geometry_accepted':False,
            'production_changed':False,'public_brush':edit,
            'decision':'Reject all four DC candidates: confirmed proper self-intersections. Captures are diagnostic only. Some shoulder planes are cleaner, but large source masses, cap contact and far appearance remain inadequate. No editor/backend, collision/support, arbitrary-edit, performance or whole-art acceptance.'}
    (OUT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>崖石 · 棱角保留实验</title><style>body{margin:0;background:#e8e7df;color:#34413b;font:16px/1.7 system-ui}main{max-width:1900px;margin:auto;padding:24px}h1{font-size:28px;font-weight:550}p{max-width:1150px}label{display:inline-block;margin:4px 18px 12px 0}select{font:inherit;padding:7px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}figcaption{padding:9px;background:#f5f1e8}img{width:100%;display:block}.warn{background:#eadbc9;padding:12px}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="cliff_representation.html">上一轮形状对照</a> · <a href="comparison.html">整岛当前版本</a><h1>崖石 · 棱角保留实验</h1><p class="warn">未采用：新重建能改善部分转折，但四个候选都有局部三角面穿插。封闭、连通不等于几何有效；正式地形保持原版本。这里展示实际 Godot 实拍，供诊断比较。</p><label>显示<select id="mode"><option value="scene">实际场景</option><option value="stone">隔离 · 石材</option><option value="crease">隔离 · 同棱角平滑算法</option><option value="flat">隔离 · 平面法线</option></select></label><label>操作<select id="edit"><option value="">修改前</option><option value="_edited">一次平面笔刷后</option></select></label><label>视角<select id="view"></select></label><label>左侧<select id="left"></select></label><label>右侧<select id="right"></select></label><div class="pair"><figure><figcaption id="lc"></figcaption><img id="li"></figure><figure><figcaption id="rc"></figcaption><img id="ri"></figure></div><p id="note"></p><p>借鉴 Hermite 交点、表面法线及 QEF 求解思路，比较仅有密度数据与额外保存原表面信息两种情况。原表面信息不是旧存档自动拥有的能力。新实现是独立的均匀网格实验，没有接入 libfive 内核，也没有替换正式编辑器。</p><p>本轮53张新实拍：45张隔离、8张场景；旧轮26张图用作同机位对照。只替换三块崖石的绘制，草地、植被、建筑与底部保留，因此不是整岛改造效果。场景中统一不绘制草地下的水平封口；闭合几何检查保留它们。修改后的图仅为独立岩体笔刷测试，不代表地表、碰撞和草地已同步接入。</p><p>四个新网格分别检出至少120、79、108、77对严格穿插；这是有限检查的下界。原合并／旧重建对照未检出此类穿插。近景虽有较利落的转折，宽大岩面、草石硬切与底部关系仍需改善，远景提升有限。</p></main><script>const M=document.querySelector('#mode'),E=document.querySelector('#edit'),V=document.querySelector('#view'),L=document.querySelector('#left'),R=document.querySelector('#right');const names={sampled:'旧采样重建',union:'原表面直接合并',dc_field:'新重建 · 仅密度，未采用',dc_hermite:'新重建 · 额外表面信息，未采用'};function options(){E.disabled=M.value==='scene';if(E.disabled)E.value='';const views=M.value==='scene'?{close:'近景',grass:'草石交界',reverse:'反向',far:'远景'}:{near:'近景',oblique:'斜向',reverse:'反向'};V.innerHTML=Object.entries(views).map(([v,t])=>`<option value="${v}">${t}</option>`).join('');for(const [s,d] of [[L,'sampled'],[R,'dc_hermite']]){const old=s.value;s.innerHTML=Object.entries(names).filter(([v])=>!(E.value&&v==='union')).map(([v,t])=>`<option value="${v}">${t}</option>`).join('');s.value=[...s.options].some(x=>x.value===old)?old:d;}draw()}function draw(){for(const [s,i,c] of [[L,'li','lc'],[R,'ri','rc']]){const name=s.value+E.value;const prefix=s.value.startsWith('dc_')||E.value?'dual_':'representation_';document.querySelector('#'+i).src=prefix+(M.value==='scene'?'scene_'+name+'_'+V.value:name+'_'+M.value+'_'+V.value)+'.png';document.querySelector('#'+c).textContent=names[s.value]+(E.value?' · 笔刷后':'');}document.querySelector('#note').textContent=E.value?'同一次公开平面笔刷：撤销、重做、记录重载一致。新网格仍有穿插，不接受为编辑器实现。':M.value==='scene'?'同场景、同材质、同机位；云雾实时变化。新方案局部更利落，但没有解决整体造型和草石交接。':'完整闭合输入，包括正式场景不绘制的封口顶盖。'}M.onchange=E.onchange=options;V.onchange=L.onchange=R.onchange=draw;options();</script></html>'''
    (GALLERY/'cliff_dual.html').write_text(page)
    print('CLIFF DUAL REVIEW: 53 successful native captures; four geometrically rejected DC candidates; production unchanged.')

if __name__=='__main__':run()
