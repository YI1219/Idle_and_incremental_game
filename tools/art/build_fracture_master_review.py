# coding: utf-8
"""Validate the actual two-route spike and publish its rejected art evidence."""
from pathlib import Path
import hashlib
import json
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/review/terrain_fidelity/2026-10-18/pcg_fracture'
WORK = ROOT/'art/work/pcg_fracture/2026-10-18'


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    target=ROOT/'art/source/visual_targets/2026-10-16/cliff_user_target.png'
    assert sha(target)==json.loads(target.with_suffix('.json').read_text())['sha256']
    cameras, images, gates = {}, {}, {}
    for route, stages in [('route1_layered_rejected',['fracture_neutral','fracture_stone']),
                          ('route1',['fracture_neutral','fracture_stone']),
                          ('route2',[f'{s}_{m}' for s in ['master_source','master_warp','master_sampled'] for m in ['neutral','stone']]),
                          ('route2_faces',[f'{s}_{m}' for s in ['master_source','master_warp','master_sampled'] for m in ['neutral','stone']])]:
        folder=OUT/route
        capture=json.loads((folder/'captures.json').read_text())
        assert set(capture['stages'])==set(stages)
        views=['close','whole','reverse','bottom']
        assert len(capture['frames'])==len(stages)*len(views)
        assert {(f['stage'],f['view']) for f in capture['frames']}=={(s,v) for s in stages for v in views}
        for frame in capture['frames']:
            raw=(folder/frame['file']).read_bytes()
            assert frame['error']==0 and raw[:8]==b'\x89PNG\r\n\x1a\n'
            assert struct.unpack('>II',raw[16:24])==(1671,941)
            camera=[frame['position'],frame['target'],frame['size']]
            assert cameras.setdefault(frame['view'],camera)==camera
            images[f'{route}/{frame["file"]}']=sha(folder/frame['file'])
        report=json.loads((WORK/route/'geometry_checks.json').read_text())
        expected={'master_source','master_warp','master_sampled'} if route.startswith('route2') else {'fracture_neutral'}
        assert set(report['stages'])==expected
        for name, result in report['stages'].items():
            assert result['crossings']['mesh_sha256']==sha(WORK/route/f'{name}.bin')
            wanted=route.startswith('route2') and not (route=='route2_faces' and name=='master_warp')
            assert result['finite_gate_passes']==wanted
            gates[f'{route}/{name}']=result['finite_gate_passes']
        shutil.copy2(WORK/route/'geometry_checks.json',folder/'geometry_checks.json')
    assert len(images)==64
    assert sha(WORK/'route1/fracture_neutral.bin')==sha(WORK/'route1/fracture_stone.bin')
    source=json.loads((WORK/'route2/master_report.json').read_text())
    assert source['source_sha256']==sha(ROOT/source['source'])=='aa2a16c21c8c3eeeedb2c89cf5d8c5ba4ab1387d879e42a87ae3d2b73cd1bb4b'
    assert len(json.loads((WORK/'route2/samples.json').read_text()))==source['sample_records']==15780
    shutil.copy2(WORK/'route2/master_report.json',OUT/'route2/master_report.json')
    latest=json.loads((WORK/'route2_faces/master_report.json').read_text())
    assert latest['source_sha256']==source['source_sha256']
    assert len(json.loads((WORK/'route2_faces/samples.json').read_text()))==latest['sample_records']==17359
    assert sha(WORK/'route2_faces/master_source.bin')==sha(WORK/'route2/master_source.bin')
    shutil.copy2(WORK/'route2_faces/master_report.json',OUT/'route2_faces/master_report.json')
    for file, count in [('route1/field_checks.txt','14/14 passed'),('partition_checks.txt','4/4 passed'),('route2/data_checks.txt','9/9 passed'),('route2_faces/data_checks.txt','9/9 passed'),('route2_faces/regression_checks.txt','3/3 passed')]:
        text=(OUT/file).read_text()
        assert count in text and not any(s in text for s in ['SCRIPT ERROR','ERROR:','AssertionError','Traceback'])
    for file in ['route1/native_log.txt','route2/native_log.txt','route2_faces/native_log.txt']:
        text=(OUT/file).read_text()
        assert not any(s in text for s in ['SCRIPT ERROR','SHADER ERROR','ERROR:','AssertionError','Traceback'])
    production=subprocess.check_output(['git','diff','--name-only','HEAD','--','scripts','shaders','assets','scenes'],cwd=ROOT,text=True)
    assert not production.strip(),production
    shutil.copy2(target,OUT/'target.png')
    old=OUT/'previous_ring';old.mkdir(exist_ok=True)
    for view in cameras:
        shutil.copy2(ROOT/f'art/review/terrain_fidelity/2026-10-18/pcg_bedrock/round2/ring_neutral_{view}.png',old/f'{view}.png')
    result={'native_frames':64,'image_sha256':images,'target_sha256':sha(target),'matched_cameras':cameras,
            'finite_geometry':gates,'fracture_data_tests':'14/14','pair_plane_metric_tests':'4/4','master_data_history_tests':'9/9',
            'master_material_control':'Recaptured all24 frames with identical actual cap depth3.5-y; neutral/stone geometry hashes match checked bodies.',
            'art_accepted':False,'goal_complete':False,'production_changed':False,'default_promoted':False,
            'new_master_revision':'Main-face/shoulder/basal refinement: direct source3strict crossings, sampled finite pass cannot validate crossed input; art rejected.',
            'next':'Two mother studies fail art; stop and ask source-strategy decision before further trials. Existing-source art refinement or explicitly authorized new reference/four-view package, before further PCG variation.',
            'unverified':['qualified master art','grass/root support','edited mesh geometry','native editor controls','two contour/two seed visual coverage','target-device performance'],
            'comparison_scope':'Same cameras/lights/material parameters; route1 is81cell crop, route2 is a different existing-source strip. Not identical layouts or target composition.'}
    (OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
    (OUT/'index.html').write_text(HTML)
    print('TWO-ROUTE REVIEW: 64 native frames; new master direct geometry has3crossings and is rejected; no art/default promotion')


HTML='''<!doctype html>
<html lang="zh-CN">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>裂隙 PCG 与母样路线 · 实拍比较</title>
<style>*{box-sizing:border-box}body{margin:0;background:#ece9e0;color:#303c35;font:16px/1.65 system-ui,-apple-system,sans-serif}main{max-width:1840px;margin:auto;padding:28px}h1{font-size:28px;margin:0 0 12px}h2{font-size:20px}p{max-width:1160px}.note{padding:14px 18px;background:#e5d6bb;border-left:4px solid #97764c}.controls{display:flex;gap:18px;flex-wrap:wrap;margin:24px 0 14px}select{font:inherit;padding:6px 10px;margin-left:8px;background:#faf8ef;border:1px solid #b5baac;border-radius:5px;color:inherit}.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px}figure{margin:0;background:#f7f4e9;border:1px solid #c5c6b8;border-radius:6px;overflow:hidden}figcaption{padding:10px 14px;font-weight:600}img{display:block;width:100%;aspect-ratio:1671/941;object-fit:contain;background:#c9d2d1}small{display:block;padding:8px 14px;color:#5b655b}.meta{font-size:14px;color:#5b655b}a{color:#476c54}@media(max-width:800px){main{padding:16px}.pair{grid-template-columns:1fr}}</style>
<main>
<h1>裂隙 PCG 与母样路线 · 实拍比较</h1>
<p class="note">第一条已停止；第二条又补做了一次主岩面、肩部和收底细化。新版本仍未达到目标，直接网格还发现3处自交，已否决。两轮母样未取得足够美术收益，停止继续试调，等待来源策略选择。</p>
<p>最新版本的主面转折更明显，但宽整板、三柱构成和硬草顶仍在。体积重建即使通过有限几何检查，也不能证明其自交输入有效或转换忠实。母样路线仍需要合格的形体来源。</p>
<div class="controls">
<label>小样<select id="sample">
<option value="route2_faces/master_warp">追加母样 · 主面细化直接网格（自交，否决）</option>
<option value="route2_faces/master_sampled">追加母样 · 体积重建（未达标）</option>
<option value="route2_faces/master_source">追加母样 · 原始来源对照</option>
<option value="route2/master_sampled">第二条 · 可雕刻体积</option>
<option value="route2/master_warp">第二条 · 变形后直接网格</option>
<option value="route2/master_source">第二条 · 原始来源对照</option>
<option value="route1/fracture">第一条 · 不分层三维裂隙</option>
<option value="route1_layered_rejected/fracture">第一条 · 最初分层试验</option>
</select>
</label>
<label>视角<select id="view">
<option value="close">近景</option>
<option value="whole">整体</option>
<option value="reverse">反向</option>
<option value="bottom">底部</option>
</select>
</label>
<label>材质<select id="material">
<option value="stone">石材与草顶</option>
<option value="neutral">中性材质</option>
</select>
</label>
</div>
<div class="pair">
<figure>
<figcaption>你认可的目标图</figcaption>
<a href="target.png" target="_blank">
<img src="target.png" alt="目标参考">
</a>
<small>保留的参考图；本轮小样的场景和构图不同。</small>
</figure>
<figure>
<figcaption id="title">
</figcaption>
<a id="candidateLink" target="_blank">
<img id="candidate" alt="实际 Godot 小样">
</a>
<small>真实引擎截图，没有生成式补画；正式场景未替换。</small>
</figure>
</div>
<h2>第二条：先区分母样形体与转换损失</h2>
<div class="pair">
<figure>
<figcaption>母样候选 · 直接网格</figcaption>
<a id="directLink" target="_blank">
<img id="direct" alt="变形后直接网格">
</a>
<small>由保留的三块岩体闭合并集细分、变形；原文件未改。仍有宽大柱面与不合格的肩部、收底。</small>
</figure>
<figure>
<figcaption>同一候选 · 转为现有可雕刻体积</figcaption>
<a id="sampledLink" target="_blank">
<img id="sampled" alt="同一候选的体积重建">
</a>
<small>相同机位、光照、材质归属高度。首轮三组有限几何通过；追加版直接网格3处自交，体积版通过也不能挽救其来源或美术。</small>
</figure>
</div>
<h2>第一条：与上次 PCG 的形体对照</h2>
<div class="pair">
<figure>
<figcaption>上次环形分段 PCG · 中性材质</figcaption>
<a id="ringLink" target="_blank">
<img id="ring" alt="上次环形 PCG">
</a>
<small>复用上次实拍，不计入本轮64张；不是正式整岛默认版。</small>
</figure>
<figure>
<figcaption>本轮三维裂隙 · 中性材质</figcaption>
<a id="fractureLink" target="_blank">
<img id="fracture" alt="本轮三维裂隙">
</a>
<small>横向分层减少，但宽墙板、硬草顶与底部大块面仍在；几何也未通过。</small>
</figure>
</div>
<p class="meta">64张Godot截图：第一条两次结构试验各8张，第二条两次母样试验各24张。全部1671×941，四组机位一致；第二条使用不同的来源岩壁条带，不能当作与第一条完全相同的地块布局。裂隙数据14/14、共享分界面4/4、两份母样保存与编辑历史各9/9；旧输出不变、保顶和有限值检查3/3。无草根支撑、编辑后几何、完整编辑器、轮廓与种子变化、目标设备验收。</p>
<p>
<a href="README.md">完整结论与复现</a> · <a href="master_art_brief.md">母样形体修改要求</a> · <a href="independent_review.md">独立审阅</a> · <a href="validation.json">核验记录</a>
</p>
</main>
<script>
const sample=document.querySelector('#sample'),view=document.querySelector('#view'),material=document.querySelector('#material');function set(id,path){document.querySelector('#'+id).src=path;document.querySelector('#'+id+'Link').href=path}function draw(){let suffix='_'+material.value+'_'+view.value+'.png';set('candidate',sample.value+suffix);let master=sample.value.startsWith('route2/')?'route2':'route2_faces';set('direct',master+'/master_warp'+suffix);set('sampled',master+'/master_sampled'+suffix);set('ring','previous_ring/'+view.value+'.png');set('fracture','route1/fracture_neutral_'+view.value+'.png');document.querySelector('#title').textContent=sample.options[sample.selectedIndex].text+' · Godot 实拍'}sample.onchange=view.onchange=material.onchange=draw;draw();</script>
</html>'''


if __name__=='__main__':run()
