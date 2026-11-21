from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent
cases = [
    ('default', '默认庭院', 'before', 'final'),
    ('held2104', '种子2104 · 默认庭院', '../20261113_cliff_join/held2104', 'final_held2104'),
    ('held4242', '种子4242 · 另一布局', '../20261113_cliff_join/held4242', 'final_held4242'),
    ('held913', '种子913 · 无水布局', '../20261113_cliff_join/held913', 'final_held913'),
    ('night', '默认庭院 · 夜景', '../20261113_cliff_join/night', 'final_night'),
]
views = {'whole': '全景', 'game': '游戏距离', 'reverse': '反向', 'side_106': '侧面106°', 'side_286': '侧面286°', 'close': '后侧近景', 'cliff_close': '前侧岩壁', 'foot_front': '前侧低肩', 'foot_reverse': '反向低角', 'overview': '俯视局部'}
rows = []
for key, title, before, after in cases:
    a = json.loads((OUT / before / 'captures.json').read_text())
    common = [v for v in views if v + '.png' in {x['file'] for x in a['captures']}]
    rows.append(dict(id=key, title=title, before=before, after=after, views=common))
html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>庭院台地与树群 · Godot 实拍</title>
<style>body{margin:0;background:#172522;color:#e7ede3;font:16px/1.6 system-ui,sans-serif}main{max-width:1800px;margin:auto;padding:24px}h1{font-size:26px;margin:0 0 8px}p{color:#bed0c2;margin:8px 0 16px}label{display:inline-flex;gap:10px;align-items:center;margin:0 20px 14px 0}select{background:#30453b;color:inherit;border:1px solid #708778;border-radius:6px;padding:8px;font:inherit}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}figcaption{padding:8px;background:#294035}img{display:block;width:100%;height:auto}a{color:#c4debd}.note{font-size:14px}@media(max-width:900px){.pair{grid-template-columns:1fr}main{padding:14px}}</style>
<main><h1>宽台地、主次树群与道路留白</h1><p>两侧均为实际 Godot 输出，同镜头、同光照、原生2560×1440。默认庭院的干地高程有意改变，现有石材和色光保持。</p>
<label>布局<select id="layout"></select></label><label>视角<select id="view"></select></label>
<div class="pair"><figure><figcaption>调整前</figcaption><a id="linkA" target="_blank"><img id="imageA" alt="调整前的Godot实拍"></a></figure><figure><figcaption>当前候选</figcaption><a id="linkB" target="_blank"><img id="imageB" alt="调整后的Godot实拍"></a></figure></div>
<p class="note">点击图片查看原图。默认增加后侧宽高台与前侧低肩；其他布局保留地形，采用新的种植与清路规则。局部直壁与岩体拼缝仍可见，效果待视觉确认。</p><p class="note"><a href="README.md">检查记录与边界</a> · <a href="checks/audit.json">采集核对</a></p></main>
<script>const cases=CASES,names=NAMES;const layout=document.getElementById('layout'),view=document.getElementById('view');for(const c of cases)layout.add(new Option(c.title,c.id));function render(){const c=cases.find(c=>c.id===layout.value),v=view.value;for(const [suffix,dir]of [['A',c.before],['B',c.after]]){const path=dir+'/'+v+'.png';document.getElementById('image'+suffix).src=path;document.getElementById('link'+suffix).href=path;}}function choose(){const last=view.value,c=cases.find(c=>c.id===layout.value);view.replaceChildren();for(const v of c.views)view.add(new Option(names[v],v));view.value=c.views.includes(last)?last:'whole';render();}layout.onchange=choose;view.onchange=render;choose();</script></html>'''
(OUT / 'compare.html').write_text(html.replace('CASES', json.dumps(rows, ensure_ascii=False)).replace('NAMES', json.dumps(views, ensure_ascii=False)))
font = ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc', 26)
preview = Image.new('RGB', (2048, 620), '#172522')
draw = ImageDraw.Draw(preview)
for i, (folder, label) in enumerate([('before', '调整前'), ('final', '调整后 · Godot 实拍')]):
    im = Image.open(OUT / folder / 'whole.png').convert('RGB').resize((1024, 576), Image.Resampling.LANCZOS)
    preview.paste(im, (i * 1024, 44))
    draw.text((i * 1024 + 20, 5), label, font=font, fill='#e7ede3')
preview.save(OUT / 'preview.jpg', quality=93)
contact = Image.new('RGB', (2048, 1580), '#172522')
draw = ImageDraw.Draw(contact)
font = ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc', 18)
for row, (_, title, _, after) in enumerate(cases):
    for col, name in enumerate(['whole', 'reverse', 'side_106', 'foot_front']):
        im = Image.open(OUT / after / (name + '.png')).convert('RGB').resize((512, 288), Image.Resampling.LANCZOS)
        contact.paste(im, (col * 512, row * 316 + 28))
        draw.text((col * 512 + 8, row * 316 + 2), title + ' · ' + views[name], font=font, fill='#e7ede3')
contact.save(OUT / 'checks/final_contact.jpg', quality=91)
print('review built', len(rows), 'layouts')
