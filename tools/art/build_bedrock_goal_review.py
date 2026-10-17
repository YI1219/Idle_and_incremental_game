"""Validate and present two rejected native shape experiments; no promotion."""
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-18/pcg_bedrock'
WORK = ROOT / 'art/work/pcg_bedrock/2026-10-18'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    target = ROOT / 'art/source/visual_targets/2026-10-16/cliff_user_target.png'
    target_hash = json.loads(target.with_suffix('.json').read_text())['sha256']
    assert sha(target) == target_hash
    cameras, images, gates = {}, {}, {}
    views = {'close', 'whole', 'reverse', 'bottom'}
    stages = {'ring_neutral', 'bedrock_neutral', 'bedrock_stone'}
    for round_name in ['round1', 'round2']:
        folder = OUT / round_name
        capture = json.loads((folder / 'captures.json').read_text())
        geometry = json.loads((folder / 'geometry_checks.json').read_text())
        assert set(capture['stages']) == stages
        assert len(capture['frames']) == 12
        assert {(f['stage'], f['view']) for f in capture['frames']} == {(s, v) for s in stages for v in views}
        for frame in capture['frames']:
            path = folder / frame['file']
            raw = path.read_bytes()
            assert frame['error'] == 0
            assert raw[:8] == b'\x89PNG\r\n\x1a\n'
            assert struct.unpack('>II', raw[16:24]) == (1671, 941)
            camera = [frame['position'], frame['target'], frame['size']]
            assert cameras.setdefault(frame['view'], camera) == camera
            images[f'{round_name}/{path.name}'] = sha(path)
        assert set(geometry['stages']) == {'ring_neutral', 'bedrock_neutral'}
        for name, record in geometry['stages'].items():
            assert record['crossings']['mesh_sha256'] == sha(WORK / round_name / f'{name}.bin')
            gates[f'{round_name}/{name}'] = record['finite_gate_passes']
        assert gates[f'{round_name}/ring_neutral']
        assert sha(WORK / round_name / 'bedrock_stone.bin') == sha(WORK / round_name / 'bedrock_neutral.bin')
        for log in ['native_log.txt', 'geometry_log.txt']:
            content = (folder / log).read_text()
            assert not any(marker in content for marker in ['SCRIPT ERROR', 'SHADER ERROR', 'ERROR:', 'Traceback', 'AssertionError'])
    assert not gates['round1/bedrock_neutral'] and gates['round2/bedrock_neutral']
    assert len(json.loads((OUT / 'round1/geometry_checks.json').read_text())['stages']['bedrock_neutral']['topology']['vertex_components']) == 2
    checks = (OUT / 'field_checks.txt').read_text()
    assert '14/14 passed' in checks and 'SCRIPT ERROR' not in checks
    production = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD', '--', 'scripts', 'shaders', 'assets', 'scenes'], cwd=ROOT, text=True)
    assert not production.strip(), production
    shutil.copy2(target, OUT / 'target.png')
    result = {'native_frames': len(images), 'matched_cameras': cameras, 'image_sha256': images,
              'target_sha256': target_hash, 'finite_gate_passes': gates, 'data_tests': '14/14',
              'art_accepted': False, 'goal_complete': False, 'stop_condition_reached': True,
              'production_changed': False, 'default_promoted': False,
              'unverified': ['edited mesh validity', 'leaf/root support', 'native editor integration',
                             'two contour/two seed visual coverage', 'target device performance'],
              'decision': 'Stop tuning; request scope decision on saved editable construction constraints before further shape work.'}
    (OUT / 'validation.json').write_text(json.dumps(result, indent=2) + '\n')
    (OUT / 'index.html').write_text(HTML)
    print('BEDROCK REVIEW: 24 matched native frames; round1 geometry rejected; round2 finite gate passes; both art rejected; stop condition reached')


HTML = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>岩体 PCG · 两轮实拍与下一步判断</title><style>
*{box-sizing:border-box}body{margin:0;background:#ece9e0;color:#303c35;font:16px/1.65 system-ui,-apple-system,sans-serif}
main{max-width:1800px;margin:auto;padding:28px}h1{font-size:28px;margin:0 0 12px}h2{font-size:20px}p{max-width:1150px}
.note{padding:14px 18px;background:#e5d6bb;border-left:4px solid #97764c}.controls{display:flex;gap:20px;flex-wrap:wrap;margin:24px 0 14px}
select{font:inherit;padding:6px 10px;margin-left:8px;background:#faf8ef;border:1px solid #b5baac;border-radius:5px;color:inherit}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px}figure{margin:0;background:#f7f4e9;border:1px solid #c5c6b8;border-radius:6px;overflow:hidden}
figcaption{padding:10px 14px;font-weight:600}img{display:block;width:100%;aspect-ratio:1671/941;object-fit:contain;background:#c9d2d1}
small{display:block;padding:8px 14px;color:#5b655b}.meta{font-size:14px;color:#5b655b}a{color:#476c54}
@media(max-width:800px){main{padding:16px}.pair{grid-template-columns:1fr}}</style><main>
<h1>岩体 PCG · 两轮实拍与下一步判断</h1>
<p class="note">两轮均未达到目标图。第二轮修复了断开的碎片，但墙板感、硬草边和底部大块体仍在。已停止继续调形体规则，没有替换正式场景。</p>
<p>需要解决的是大形的组织：不等大的岩块如何咬合、肩部如何转折、裂隙如何连到收底。加草、换材质或增加细节都不足以消除当前差距。</p>
<div class="controls"><label>轮次<select id="round"><option value="round2">第二轮 · 斜面与内收调整</option><option value="round1">第一轮 · 三维岩体域</option></select></label>
<label>视角<select id="view"><option value="close">近景</option><option value="whole">整体</option><option value="reverse">反向</option><option value="bottom">底部</option></select></label>
<label>材质<select id="stage"><option value="bedrock_stone">石材与草顶</option><option value="bedrock_neutral">中性材质</option></select></label></div>
<div class="pair"><figure><figcaption>你认可的目标图</figcaption><a href="target.png" target="_blank"><img src="target.png" alt="目标参考"></a><small>保留的参考图，非本轮实拍；机位、场景和构图不同。</small></figure>
<figure><figcaption id="title">第二轮 · Godot 实拍</figcaption><a id="candidateLink" target="_blank"><img id="candidate" alt="本轮实际渲染"></a><small>81 个干地块的小样。未添加草簇；先检查主岩体是否成立。</small></figure></div>
<h2>相同机位、光照、中性材质的形体对照</h2><div class="pair">
<figure><figcaption>上一版环形分段 PCG · 已被否定的小样</figcaption><a id="baselineLink" target="_blank"><img id="baseline" alt="上一版 PCG"></a><small>这是上次环形规则的小样对照，不是正式整岛默认版。</small></figure>
<figure><figcaption>本轮三维形体规则 · 中性材质</figcaption><a id="neutralLink" target="_blank"><img id="neutral" alt="本轮中性几何"></a><small>第二轮改善了第一轮的台阶草顶与直立墙面，但仍未构成有说服力的目标形体。</small></figure></div>
<h2>建议改变制作方式，再继续 PCG</h2>
<p>在局部原型中，让主岩面、相邻裂隙、肩部到下缘的连接和草土边缘成为可调整、可保存的构形约束。先用这些控制做出一个你认可的标准样段，再让程序变化地块轮廓与随机种子，并验证它仍然可雕刻。此方案需要扩展当前原型的形体数据与制作工具，尚未实施，也未证明能达到目标。</p>
<p class="meta">24 张新 Godot 实拍，全部 1671 × 941，四组机位跨轮次一致。第一轮有独立碎片，几何不通过；第二轮未编辑小样通过有限几何检查。数据检查 14/14，不代表美术验收、编辑后几何、草根支撑、编辑器集成或目标设备性能通过。</p>
<p class="meta">两轮没有主形收益，已触发目标约定的止损条件；等待对下一步数据与制作方式的决定。<a href="README.md">完整记录</a> · <a href="independent_review.md">独立审阅</a> · <a href="validation.json">核验数据</a></p>
</main><script>
const round=document.querySelector('#round'),view=document.querySelector('#view'),stage=document.querySelector('#stage');
function set(id,file){document.querySelector('#'+id).src=file;document.querySelector('#'+id+'Link').href=file}
function draw(){const prefix=round.value+'/';set('candidate',prefix+stage.value+'_'+view.value+'.png');set('baseline',prefix+'ring_neutral_'+view.value+'.png');set('neutral',prefix+'bedrock_neutral_'+view.value+'.png');document.querySelector('#title').textContent=round.options[round.selectedIndex].text+' · Godot 实拍'}
round.onchange=view.onchange=stage.onchange=draw;draw();</script></html>'''


if __name__ == '__main__':
    run()
