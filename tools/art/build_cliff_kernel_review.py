# -*- coding: utf-8 -*-
"""Publish bounded kernel evidence, keeping technical and art acceptance separate."""
import hashlib,json,shutil,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art/work/cliff_kernel/2026-10-17'
OUT=ROOT/'art/review/terrain_fidelity/2026-10-17/cliff_kernel'
GALLERY=ROOT/'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
def run():
    geometry=json.loads((WORK/'geometry_validation.json').read_text())
    boundary=json.loads((WORK/'boundary.json').read_text())
    runs=json.loads((WORK/'kernel_runs.json').read_text())
    oracle=json.loads((WORK/'oracle_validation.json').read_text())
    provenance=json.loads((WORK/'build_provenance.json').read_text())
    assert not provenance['source_files_modified_against_archive']
    assert runs['adapter_sha256']==hashlib.sha256((ROOT/'tools/art/cliff_libfive_probe.cpp').read_bytes()).hexdigest()
    assert runs['source_sha256']==hashlib.sha256((ROOT/'art/work/cliff_representation/2026-10-17/union.bin').read_bytes()).hexdigest()
    assert all(x['returncode']==0 for x in runs['stages'].values()) and len(runs['stages'])==6
    assert all(boundary[k] for k in ['undo_mesh_bytes_equal','redo_mesh_bytes_equal','reload_mesh_bytes_equal','recipe_vector_values_equal_at_engine_precision'])
    assert boundary['localcut_brush_max_y']<3.4
    for a,b in [('grown','undo'),('carved','redo'),('carved','reload')]:assert (WORK/('boundary_'+a+'.bin')).read_bytes()==(WORK/('boundary_'+b+'.bin')).read_bytes()
    passed={name for name,s in geometry['stages'].items() if s['finite_geometry_gate_passes']}
    assert passed=={'boundary','boundary_edited','boundary_grown','boundary_undo','boundary_localcut'}
    for name,entry in geometry['stages'].items():assert entry['crossings']['mesh_sha256']==hashlib.sha256((WORK/(name+'.bin')).read_bytes()).hexdigest()
    assert oracle['edited_query']['all_node_density_differences_above_3e5']==48 and oracle['edited_query']['brush_sphere_boundary_sign_differences']==1
    matched={};hashes={}
    for scene,file,count in [(False,'captures.json',36),(True,'scene_captures.json',8)]:
        data=json.loads((OUT/file).read_text());assert len(data['captures'])==count
        for entry in data['captures']:
            assert entry['error']==0
            name=entry['file'];raw=(OUT/name).read_bytes();assert raw[:8]==b'\x89PNG\r\n\x1a\n'
            assert struct.unpack('>II',raw[16:24])==((1671,941) if scene else (1440,960))
            key=('scene_' if scene else 'lab_')+name.removesuffix('.png').split('_')[-1];camera=[entry['position'],entry['rotation'],entry.get('size')]
            if key in matched:assert matched[key]==camera
            matched[key]=camera;hashes[name]=hashlib.sha256(raw).hexdigest();shutil.copy2(OUT/name,GALLERY/('kernel_'+name))
    scene=json.loads((OUT/'scene_captures.json').read_text())
    assert scene['replaced_source_instances']==3 and scene['unchanged_authoritative_data'] and scene['water_phase']==1.25
    assert all(x['lid_triangles_not_drawn']>0 for x in scene['cap_draw_controls'].values())
    (OUT/'logs').mkdir(exist_ok=True)
    logs=['configure','build','adapter_build','queries','runs','boolean','validation','detector_regression','tests','capture','scene']
    for name in logs:
        file=Path('/tmp')/('yunlu_cliff_kernel_'+name+'.log');log=file.read_text()
        assert not any(x in log for x in ['SCRIPT ERROR','SHADER ERROR','Traceback','AssertionError','PROBE ERROR','ERROR:']),name
        if name=='tests':assert 'Ran 10 tests' in log and 'OK' in log
        shutil.copy2(file,OUT/'logs'/(name+'.txt'))
    for source,name in [('/tmp/yunlu_cliff_kernel_recipe_precision.log','rejected_initial_recipe_precision.txt'),('/tmp/yunlu_cliff_boost_download.log','failed_parallel_boost_download.txt')]:
        if Path(source).exists():
            # Download progress lines carry trailing spaces; normalize only
            # that whitespace for the tracked review copy. Raw logs stay /tmp.
            log=Path(source).read_text()
            (OUT/'logs'/name).write_text(''.join(line.rstrip()+'\n' for line in log.splitlines()))
    result={'successful_native_frames':44,'isolated_frames':36,'scene_frames':8,'camera_groups':matched,'image_sha256':hashes,
            'finite_geometry_passes':sorted(passed),'failed_stages':sorted(set(geometry['stages'])-passed),
            'recipe_mesh_replay_exact':True,'arbitrary_sequence_accepted':False,'production_backend_accepted':False,
            'art_candidate_accepted':False,'production_changed':False,
            'decision':'Actual pinned libfive kernel built and tested; reject this adapter/settings combination. Direct-boundary plane/grow/localcut pass finite gates, but carve+redo/reload fail. Recipe replay equality does not validate geometry. Localcut looks like a circular incision and gives no useful far gain, so reject art promotion. Ground contact unchanged; no new material experiment or default change.'}
    (OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>崖体 · 成熟内核验证</title><style>body{margin:0;background:#e8e7df;color:#34413b;font:16px/1.7 system-ui}main{max-width:1900px;margin:auto;padding:24px}h1{font-size:28px;font-weight:550}p{max-width:1100px}label{display:inline-block;margin:4px 18px 12px 0}select{font:inherit;padding:7px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}figcaption{padding:9px;background:#f5f1e8}img{width:100%;display:block}.note{background:#eadbc9;padding:12px}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="cliff_dual.html">上轮重建实验</a> · <a href="comparison.html">当前整岛版本</a><h1>崖体 · 成熟内核的实际验证</h1><p class="note">本轮没有采用新的美术版本。直接编辑原表面能保住原形，但局部修面产生了弧形切痕，远景没有实质改善。它只通过了这一次的有限几何检查。连续挖除和六个 libfive 重建输出未通过，不能据此更换正式地形。</p><label>显示<select id="mode"><option value="scene">实际场景</option><option value="stone">隔离 · 石材</option><option value="crease">隔离 · 棱角平滑</option><option value="flat">隔离 · 平面法线</option></select></label><label>视角<select id="view"></select></label><label>右侧试验<select id="stage"></select></label><div class="pair"><figure><figcaption>原形保留 · 同一材质与机位</figcaption><img id="left"></figure><figure><figcaption id="caption"></figcaption><img id="right"></figure></div><p id="explain"></p><p>44张本轮 Godot 实拍：36张隔离、8张场景。场景只替换三块岩石的绘制；局部修面范围严格低于草地，保留原有地表、树木、建筑、底部和布局。没有接入玩家编辑、碰撞或支撑计算。水体相位固定，云雾仍实时变化。</p><p>本次实际构建并运行了完整 libfive 内核，并测试三种重建方式；当前适配仍有穿插／退化，不能归结为通用内核本身的结论。直接使用 Godot 已有的 Manifold 表面运算，原形、平面切削、增厚和一次侧面修整通过有限检查；后续球形挖除仍失败。保存／恢复得出相同网格，只证明可重复，不证明网格有效。</p><p>当前结论：内核能够帮助保留已有形状，但岩体大形、相邻面的关系和草石接触仍需设计。美术没有通过，不把技术测试图当作画面升级。</p></main><script>const M=document.querySelector('#mode'),V=document.querySelector('#view'),S=document.querySelector('#stage');const stages={boundary_localcut:'局部修面 · 弧形切痕，未采用',boundary_edited:'平面笔刷 · 功能测试',boundary_grown:'增厚笔刷 · 功能测试'};function options(){const prior=S.value;const views=M.value==='scene'?{close:'近景',grass:'草石交界',reverse:'反向',far:'远景'}:{near:'近景',oblique:'斜向',reverse:'反向'};V.innerHTML=Object.entries(views).map(([v,t])=>`<option value="${v}">${t}</option>`).join('');S.innerHTML=Object.entries(stages).filter(([v])=>M.value!=='scene'||v==='boundary_localcut').map(([v,t])=>`<option value="${v}">${t}</option>`).join('');if([...S.options].some(x=>x.value===prior))S.value=prior;draw()}function draw(){const file=s=>'kernel_'+(M.value==='scene'?'scene_'+s+'_'+V.value:s+'_'+M.value+'_'+V.value)+'.png';document.querySelector('#left').src=file('boundary');document.querySelector('#right').src=file(S.value);document.querySelector('#caption').textContent=stages[S.value];document.querySelector('#explain').textContent=S.value==='boundary_localcut'?'这次修面没有触及草地。圆弧状边界仍像人为切痕，不符合自然岩体的要求，未采用。':'这是独立岩体的笔刷功能验证，不是庭院造型方案；对应场景地表没有随之更新，所以只展示隔离图。'}M.onchange=options;V.onchange=S.onchange=draw;options();</script></html>'''
    (GALLERY/'cliff_kernel.html').write_text(page)
    print('CLIFF KERNEL REVIEW:44 successful native captures; bounded geometry leads only; no art/backend promotion.')
if __name__=='__main__':run()
