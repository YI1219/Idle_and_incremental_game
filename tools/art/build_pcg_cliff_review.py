"""Verify and build the native PCG small-scene comparison; no default promotion."""
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-18/pcg_cliff'
WORK = ROOT / 'art/work/pcg_cliff/2026-10-18'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    captures = json.loads((OUT / 'captures.json').read_text())
    geometry = json.loads((WORK / 'geometry_checks.json').read_text())
    target = ROOT / 'art/source/visual_targets/2026-10-16/cliff_user_target.png'
    expected = json.loads(target.with_suffix('.json').read_text())['sha256']
    assert sha(target) == expected
    stages = ['control', 'pcg_shape', 'pcg_contact', 'pcg_seed7319', 'pcg_layout', 'pcg_carved', 'neutral']
    assert set(captures['stages']) == set(stages)
    assert len(captures['frames']) == 35
    cameras = {}
    images = {}
    for entry in captures['frames']:
        assert entry['error'] == 0
        path = OUT / entry['file']
        raw = path.read_bytes()
        assert raw[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', raw[16:24]) == (1671, 941)
        camera = [entry['position'], entry['target'], entry['size']]
        if entry['view'] in cameras:
            assert cameras[entry['view']] == camera
        cameras[entry['view']] = camera
        images[path.name] = sha(path)
    for name in ['control', 'pcg_shape', 'pcg_seed7319', 'pcg_layout', 'pcg_carved']:
        assert geometry['stages'][name]['finite_gate_passes'], name
        assert geometry['stages'][name]['crossings']['mesh_sha256'] == sha(WORK / f'{name}.bin')
    for name in ['pcg_contact', 'neutral']:
        assert sha(WORK / f'{name}.bin') == sha(WORK / 'pcg_shape.bin')
    contact = {}
    for name in ['pcg_contact', 'pcg_seed7319', 'pcg_layout', 'pcg_carved']:
        report = captures['stages'][name]['contact']
        assert report['roots'] and all(r['triangle_support'] and r['field_support_error'] < .0001 for r in report['roots'])
        assert report['uploaded_vertices'] == len(report['roots']) * report['source_vertices_per_fan']
        contact[name] = {'supported_roots': len(report['roots']), 'all_source_vertex_occurrences': report['uploaded_vertices'], 'max_support_error_m': report['max_root_support_error']}
    normal_control = json.loads((OUT / 'gradient_normal_control/geometry_hashes.json').read_text())
    for name, digest in normal_control.items():
        assert sha(WORK / f'{name}.bin') == digest, name
    production = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD', '--', 'scripts', 'shaders', 'assets', 'scenes'], cwd=ROOT, text=True)
    assert not production.strip(), production
    for source, destination in [('final', 'native_log.txt'), ('checks', 'field_checks.txt'), ('geometry', 'geometry_log.txt'), ('data', 'data_checks.txt')]:
        text = (Path('/tmp') / f'yunlu-pcg-{source}.log').read_text()
        assert not any(marker in text for marker in ['SCRIPT ERROR', 'SHADER ERROR', 'ERROR:', 'Traceback', 'AssertionError'])
        (OUT / destination).write_text(text)
    assert '14/14 passed' in (OUT / 'field_checks.txt').read_text()
    assert '301/301 passed' in (OUT / 'data_checks.txt').read_text()
    shutil.copy2(target, OUT / 'target.png')
    shutil.copy2(WORK / 'geometry_checks.json', OUT / 'geometry_checks.json')
    result = {'native_frames': 35, 'matched_views': cameras, 'image_sha256': images,
              'approved_target_sha256': expected, 'finite_geometry_passes': list(geometry['stages']),
              'contact': contact, 'normal_control_identical_body_vertices': True,
              'production_changed': False, 'default_promoted': False,
              'field_tests': '14/14', 'production_data_tests': '301/301',
              'scope': 'One cropped, initially single-contour, dry preset fixture; second seed, one contracted-cell layout and one below-cap cut. Ordinary v2 densities/public data APIs; not automatic cell-edit regeneration in production, native pointer/picking integration, arbitrary terrain/holes, full-island art or target-hardware acceptance.'}
    (OUT / 'validation.json').write_text(json.dumps(result, indent=2) + '\n')
    html = '''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PCG 岩体 · 小场景实际对比</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#e9e8df;color:#2f3c36;font:16px/1.65 system-ui,-apple-system,sans-serif}
main{max-width:1840px;margin:auto;padding:28px}h1{font-size:29px;font-weight:600;margin:0 0 10px}h2{font-size:20px;font-weight:550}
p{max-width:1120px}.note{padding:14px 18px;background:#e3d7c1;border-left:4px solid #8e7957}.controls{display:flex;flex-wrap:wrap;gap:18px;margin:22px 0 14px}
select{font:inherit;padding:7px 10px;margin-left:8px;border:1px solid #9daba0;border-radius:5px;background:#faf8f0;color:inherit}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px}figure{margin:0;background:#f6f3e9;border:1px solid #c3c8bc;border-radius:7px;overflow:hidden}
figcaption{padding:10px 14px;font-weight:550}img{display:block;width:100%;aspect-ratio:1671/941;object-fit:contain;background:#c7d2d4}
small{display:block;padding:8px 14px;color:#526057}.meta{font-size:14px;color:#58655c}a{color:#43684f}@media(max-width:850px){main{padding:16px}.pair{grid-template-columns:1fr}}
</style><main>
<h1>PCG 岩体 · 小场景实际对比</h1>
<p>同一份可雕刻体积连续生成草顶、崖壁和收底。原型从现有地形中截取了 81 个干燥地块；裁切形成的背侧直边属于测试边界，不代表完整岛屿设计。</p>
<p class="note">本轮完成结构验证，尚未达到目标图的美术完成度，也没有替换正式岛屿。主岩面仍偏柱状，草石交界仍显薄，底面仍偏平。请同时看反向、底部和中性材质，不只判断近景。</p>
<div class="controls"><label>实际视角<select id="view"><option value="close">近景</option><option value="grass">草石交界</option><option value="whole">整体</option><option value="reverse">反向</option><option value="bottom">底部</option></select></label>
<label>PCG 状态<select id="stage"><option value="pcg_contact">形体＋草石接触</option><option value="pcg_shape">只看形体（无草簇）</option><option value="neutral">中性材质（无草簇）</option><option value="pcg_seed7319">另一个随机种子</option><option value="pcg_layout">改变地块轮廓后重新生成</option><option value="pcg_carved">使用现有削切工具编辑后</option></select></label></div>
<div class="pair"><figure><figcaption>目标参考 · 你之前认可的效果</figcaption><a href="target.png" target="_blank"><img src="target.png" alt="用户认可的悬崖目标图"></a><small>保留的用户参考图，非本轮引擎实拍；场景、机位和构图与小样不同。</small></figure>
<figure><figcaption id="candidateTitle">本轮 PCG · Godot 实拍</figcaption><a id="candidateLink" target="_blank"><img id="candidate" alt="PCG 实际引擎截图"></a><small id="candidateNote"></small></figure></div>
<h2>同一小样地块、同机位和光照的对照</h2>
<div class="pair"><figure><figcaption>现有体积地形生成规则 · 小样基线</figcaption><a id="controlLink" target="_blank"><img id="control" alt="现有体积规则在小样地块上的基线"></a><small>现有 local 体积生成规则。不是整岛正式版的模型墙截图；用来隔离同一地块的生成差异。</small></figure>
<figure><figcaption>本轮 PCG · 与左侧相同机位</figcaption><a id="secondLink" target="_blank"><img id="second" alt="同机位 PCG 小样"></a><small>同材质、同光照，关闭草簇和使用中性材质可分别检查几何。</small></figure></div>
<p class="meta">35 张本轮原生 Godot 截图，1671 × 941。五组几何通过有限闭合性、朝向、连通性、顶点邻域与严格自交检查；雕刻数据检查 14/14，原有地形数据检查 301/301。草簇保留完整源叶片，根部同时查询实际三角面与体积场。</p>
<p class="meta">当前只验证单轮廓干地小样、两个种子、一种缩边布局与一次局部削切。完整编辑器发布、点选、任意地形、碰撞、整岛美术及目标设备性能均未验收。<a href="README.md">查看记录</a> · <a href="validation.json">核验数据</a></p>
</main><script>
const view=document.querySelector('#view'),stage=document.querySelector('#stage');
function link(id,file){document.querySelector('#'+id).href=file}
function draw(){const file=stage.value+'_'+view.value+'.png',baseline='control_'+view.value+'.png';document.querySelector('#candidate').src=file;document.querySelector('#second').src=file;document.querySelector('#control').src=baseline;link('candidateLink',file);link('secondLink',file);link('controlLink',baseline);document.querySelector('#candidateTitle').textContent='本轮 PCG · '+stage.options[stage.selectedIndex].text+' · Godot 实拍';document.querySelector('#candidateNote').textContent=stage.value==='pcg_carved'?'使用现有 public carve API；保存、撤销、重做和载入由实际数据测试验证。':stage.value==='pcg_layout'?'移除右侧一段地块后，重新执行相同 PCG 规则；尚未接入正式编辑器自动更新。':'同一 .25m 密度场生成一个闭合表面，未绘制独立石板或另一层底壳。'}view.onchange=stage.onchange=draw;draw();
</script></html>'''
    (OUT / 'index.html').write_text(html)
    print('PCG REVIEW: 35 native frames; 5 finite mesh gates; supported roots; clean logs; no production changes')


if __name__ == '__main__':
    run()
