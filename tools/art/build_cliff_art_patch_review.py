# -*- coding: utf-8 -*-
"""Validate and publish the bounded existing-source art study, without promotion."""
import hashlib
import json
import shutil
import struct
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art/work/cliff_art_patch/2026-10-18'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-18/cliff_art_patch'
SOURCE = ROOT / 'art/work/rendered_island/2026-10-17/complete'
GALLERY = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'

def sha(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()

def cap(file):
    triangles = np.fromfile(file, dtype='<f4').reshape(-1, 3, 3).astype(float)
    return triangles[np.max(abs(triangles[:, :, 1]-3.5), axis=1) < 1e-5][:, :, [0, 2]]

def inside(points, triangles):
    # Finite bidirectional vertex coverage, in addition to equal cap area.
    a = triangles[:, 0]; b = triangles[:, 1]-a; c = triangles[:, 2]-a
    cross = lambda x, y: x[..., 0]*y[..., 1]-x[..., 1]*y[..., 0]
    det = cross(b, c)
    valid = abs(det) > 1e-12
    starts = triangles.reshape(-1, 2)
    edges = (triangles[:, [1, 2, 0]]-triangles).reshape(-1, 2)
    for p in points:
        u = cross(p-a[valid], c[valid])/det[valid]
        v = cross(b[valid], p-a[valid])/det[valid]
        if np.any((u >= -1e-5) & (v >= -1e-5) & (u+v <= 1+1e-5)):
            continue
        # Float32 bisect points on narrow cap slivers can be just outside.
        t = np.clip(np.sum((p-starts)*edges, axis=1)/np.maximum(np.sum(edges*edges, axis=1), 1e-30), 0, 1)
        assert np.linalg.norm(p-(starts+t[:, None]*edges), axis=1).min() < 1e-6

def run():
    geometry = json.loads((WORK/'geometry_checks.json').read_text())
    refinement = json.loads((WORK/'cage_refinement.json').read_text())
    contact = json.loads((OUT/'contact/contact.json').read_text())
    caps = {}
    for stage in ['baseline', 'cage', 'seated']:
        parts = []
        for number in [36, 37, 38]:
            original = SOURCE/f'crown_{number}.bin'
            file = original if stage == 'baseline' else WORK/f'{stage}_{number}.bin'
            parts.append(file.read_bytes())
            if stage == 'baseline':
                continue
            name = f'{stage}_{number}'
            assert refinement['sources'][name]['source_sha256'] == sha(original)
            assert geometry[name]['intersections']['mesh_sha256'] == sha(file)
            assert geometry[name]['finite_gate_passes']
            before, after = cap(original), cap(file)
            inside(before.reshape(-1, 2), after)
            inside(after.reshape(-1, 2), before)
            assert abs(refinement['sources'][name]['cap_area_before']-refinement['sources'][name]['cap_area_after']) < 1e-4
            caps[name] = 'equal area within 1e-4 m2; bidirectional cap-vertex coverage within 1e-5 barycentric or 1e-6 m edge tolerance; changed triangulation'
        assert (WORK/f'assembly_{stage}.bin').read_bytes() == b''.join(parts)
    assert not geometry['cage']['finite_gate_passes'] and not geometry['seated']['finite_gate_passes']
    assert len(contact['roots']) == 84
    assert all(r['inside_drawn_cap'] and r['drawn_grass_triangle_support'] for r in contact['roots'])
    assert contact['all_source_faces_preserved'] and contact['source_vertex_occurrences'] == 465
    assert contact['uploaded_vertex_occurrences'] == 39060
    hashes = {}; cameras = {}; data_hashes = set()
    for folder, count in [(OUT, 12), (OUT/'contact', 8)]:
        metadata = json.loads((folder/'scene_captures.json').read_text())
        assert len(metadata['captures']) == count
        assert metadata['unchanged_authoritative_data'] and metadata['replaced_source_instances'] == 3 and metadata['water_phase'] == 1.25
        data_hashes.add(metadata['authoritative_data_sha256'])
        for entry in metadata['captures']:
            assert entry['error'] == 0
            file = folder/entry['file']; raw = file.read_bytes()
            assert raw[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', raw[16:24]) == (1671, 941)
            view = file.stem.split('_')[-1]; camera = [entry['position'], entry['rotation']]
            if view in cameras:
                assert cameras[view] == camera
            cameras[view] = camera; hashes[str(file.relative_to(OUT))] = sha(file)
            shutil.copy2(file, GALLERY/('artpatch_'+file.name))
    assert len(data_hashes) == 1
    rejected = {name: len(list((OUT/name).glob('*.png'))) for name in ['rejected_plane_fit', 'rejected_authored_domain_only', 'rejected_low_comb']}
    assert list(rejected.values()) == [8, 8, 8]
    (OUT/'logs').mkdir(exist_ok=True)
    for name in ['cage', 'checks', 'capture', 'contact', 'frames', 'union_cage', 'union_seated']:
        file = Path('/tmp')/f'yunlu_cliff_art_{name}.log'; log = file.read_text()
        assert not any(e in log for e in ['SCRIPT ERROR', 'SHADER ERROR', 'Traceback', 'AssertionError', 'ERROR:']), name
        (OUT/'logs'/f'{name}.txt').write_text(''.join(line.rstrip()+'\n' for line in log.splitlines()))
    result = dict(current_native_frames=20, rejected_or_incomplete_frames=rejected,
                  image_sha256=hashes, camera_groups=cameras, cap_checks=caps,
                  independent_parts_passed=6, unions_rejected=['cage', 'seated'],
                  grass_supported_roots=84, grass_uploaded_vertices=39060,
                  authoritative_data_sha256=next(iter(data_hashes)), production_changed=False,
                  default_promoted=False, editor_integration_accepted=False, performance_accepted=False,
                  decision='Seated is a limited unaccepted local structural lead only. Shelf exposure reduces, but broad walls, hard lip and distinct underside persist. Contact cushions give a small near benefit, not a far improvement or final sod transition. No art promotion.')
    (OUT/'validation.json').write_text(json.dumps(result, indent=2)+'\n')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>崖石 · 局部形体与草石接触</title><style>body{margin:0;background:#e8e7df;color:#34413b;font:16px/1.7 system-ui}main{max-width:1900px;margin:auto;padding:24px}h1{font-size:28px;font-weight:550}p{max-width:1150px}label{display:inline-block;margin:4px 18px 12px 0}select{font:inherit;padding:7px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}figcaption{padding:9px;background:#f5f1e8}img{width:100%;display:block}.note{background:#eadbc9;padding:12px}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style><main><a href="cliff_kernel.html">上轮内核验证</a> · <a href="comparison.html">当前整岛版本</a><h1>崖石 · 局部形体与草石接触</h1><p class="note">本轮已在实际场景试做，但没有替换正式版本。下部延展能遮住部分分层台阶，却仍是宽大的墙面，远景提升很小；草簇只带来局部接触改善，尚未达到参考图的自然感。</p><label>视角<select id="view"><option value="close">近景</option><option value="grass">草石交界</option><option value="reverse">反向</option><option value="far">远景</option></select></label><label>右侧试做<select id="stage"><option value="assembly_seated_contact">下部衔接＋低草簇</option><option value="assembly_seated">仅下部衔接</option><option value="assembly_cage">仅局部岩面转折</option><option value="assembly_baseline_contact">仅低草簇</option></select></label><div class="pair"><figure><figcaption>本轮原形对照 · 同材质、同机位</figcaption><img id="left" alt="原形对照"></figure><figure><figcaption id="caption"></figcaption><img id="right" alt="局部试做"></figure></div><p id="explain"></p><p>20张本轮 Godot 实拍。仅试做三块相邻侧石和六处现有草叶组成的小草簇，保留原有地表轮廓、树木、建筑、湖水和布局；没有增加地形噪声或继续调暗石头。水体相位固定，云雾仍实时变化。</p><p>原形与试做均按原有方式独立绘制相互交叠的石块，不能视为单一连续山体。延展后的藤蔓没有重新贴合，草簇也尚未接入编辑后的自动更新。因此这里只评估局部外观，没有完成碰撞、编辑或性能验收。</p><p>保留的方向：侧石向下衔接有助于减弱分层。但后续需要同时塑造不等宽的主岩面、转折与收底关系；单纯拉长或靠草簇遮边都不足以解决问题。</p></main><script>const V=document.querySelector('#view'),S=document.querySelector('#stage');function draw(){const image=s=>'artpatch_scene_'+s+'_'+V.value+'.png';document.querySelector('#left').src=image('assembly_baseline');document.querySelector('#right').src=image(S.value);document.querySelector('#caption').textContent=S.options[S.selectedIndex].text;document.querySelector('#explain').textContent=S.value.includes('seated')?'左侧与中部下方的分层台阶有所减弱，但岩面被拉得更长，厚重的底部仍然明显。只保留作局部结构参考，不作为新的美术版本。':S.value.includes('contact')?'草簇确实增加了局部轮廓，但大片顶缘仍然硬切，反向仍像稀疏叶束，远景变化很小。':'局部岩面增加了转折，但整体的宽墙比例没有改变。'}V.onchange=S.onchange=draw;draw();</script></html>'''
    (GALLERY/'cliff_art_patch.html').write_text(page)
    print('CLIFF ART REVIEW:20 current native frames,24 quarantined; six individual parts pass; unions rejected; no production promotion.')

if __name__ == '__main__':
    run()
