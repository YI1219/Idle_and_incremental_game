"""Rebuild the small OFL UI subset from the preserved official Noto source.

Authoring dependency: fontTools4.60.2. Runtime uses only the generated font.
Original/source URL, hashes and license are retained in the source manifest.
"""
from pathlib import Path
import hashlib
import json
import shutil
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/source/ui_font/2026-10-19'
OUT=ROOT/'assets/fonts'


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    chars=set(range(32,127))|set(range(0x3000,0x3040))|{0x2014,0x00b7,0x2026}
    inputs=[*(ROOT/'scripts/terrain_editor').glob('island*.gd'),ROOT/'scripts/terrain_editor/editor_hud.gd']
    for path in inputs:chars.update(ord(c) for c in path.read_text() if ord(c)>127)
    font=instantiateVariableFont(TTFont(SOURCE/'NotoSansSC-VF.ttf'),{'wght':400},inplace=True)
    notice=next(n.toUnicode() for n in font['name'].names if n.nameID==0)
    options=subset.Options();options.hinting=False
    selected=subset.Subsetter(options=options);selected.populate(unicodes=chars);selected.subset(font)
    for record in font['name'].names:
        if record.nameID in [1,4,6,16]:
            name='YunluUI-Regular' if record.nameID==6 else 'Yunlu UI'
            record.string=name.encode(record.getEncoding(),errors='replace')
    output=OUT/'YunluUI-Regular.ttf';font.save(output)
    shutil.copy2(SOURCE/'LICENSE.txt',OUT/'OFL-NotoSansSC.txt')
    (OUT/'FONT-NOTICE.txt').write_text(notice+'\n\nYunlu UI is a renamed weight400 subset of Noto Sans SC for this preview.\nLicensed under SIL Open Font License1.1; see OFL-NotoSansSC.txt.\n')
    manifest=json.loads((SOURCE/'manifest.json').read_text())
    manifest.update(derivative_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
        covered_unicode_count=len(font.getBestCmap()),size_bytes=output.stat().st_size,
        generator='tools/art/build_island_ui_font.py')
    (SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('UI FONT:',len(font.getBestCmap()),'characters,',output.stat().st_size,'bytes')


if __name__=='__main__':run()
