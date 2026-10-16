# -*- coding: utf-8 -*-
"""Package actual direct-sculpt studies beside the existing local gallery."""
from pathlib import Path
from shutil import copy2
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/review/terrain_fidelity/2026-10-16/rock_sculpt'
OUT = ROOT / 'art/review/terrain_fidelity/2026-10-14/courtyard_finish'
for name in ['before_close', 'sculpt1_close', 'sculpt2_close', 'sculpt2_overview', 'sculpt2_reverse', 'sculpt2_carved', 'sculpt2_undo']:
    copy2(SOURCE / f'{name}.png', OUT / f'rock_{name}.png')
page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>岩体直接塑形 · 功能试作</title><style>body{margin:0;background:#e9e8df;color:#35443e;font:16px/1.7 system-ui,sans-serif}main{max-width:1350px;margin:auto;padding:32px}h1{font-size:32px;font-weight:500}p{max-width:940px;color:#63736a}img{width:100%;display:block;border-radius:8px}select{font:inherit;padding:8px;margin:14px 0}a{color:#526e5a}</style><main><a href="comparison.html">返回默认岛屿候选</a><h1>岩体直接塑形 · 功能试作</h1><p>玩家与预制作者直接修改同一份岩体体积：增岩、削岩、切面，支持撤销、保存和继续编辑。这里没有自动摆放或组合石头。以下均为实际 Godot 场景。</p><p><strong>两组形体尚未采用。</strong>第一组偏软泥，第二组偏宽大岩片；原有侧崖与草地还没有转换成同一个可塑形表面，因此接缝仍不自然。默认岛屿没有换成这些试版。</p><label>查看步骤 <select id="view"><option value="before_close">原有岛缘</option><option value="sculpt1_close">第一组 · 外形未采用</option><option value="sculpt2_close" selected>第二组 · 外形未采用</option><option value="sculpt2_carved">同一岩体削改后</option><option value="sculpt2_undo">撤销削改后</option><option value="sculpt2_overview">第二组 · 全岛</option><option value="sculpt2_reverse">第二组 · 反向</option></select></label><img id="image" src="rock_sculpt2_close.png" alt="岩体塑形实景试作"><p>功能检查与美术接受分开：连体网格、跨区接缝、增削、切面、撤销及保存已验证；完整鼠标操作、草石整体塑形和目标设备性能仍待继续验证。</p></main><script>document.querySelector('#view').onchange=e=>document.querySelector('#image').src='rock_'+e.target.value+'.png';</script></html>'''
(OUT / 'rock_sculpt.html').write_text(page)
print(OUT / 'rock_sculpt.html')
