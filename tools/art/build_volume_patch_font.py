"""Build a separate OFL subset for this study, preserving the existing UI font."""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/source/ui_font/2026-10-19/NotoSansSC-VF.ttf'
OUTPUT = ROOT / 'assets/fonts/YunluVolumeUI-Regular.ttf'

def run():
    text = (ROOT / 'scripts/terrain_volume/patch_study.gd').read_text()
    font = instantiateVariableFont(TTFont(SOURCE), {'wght': 400}, inplace=True)
    options = subset.Options()
    options.hinting = False
    selected = subset.Subsetter(options=options)
    wanted = set(range(32,127)) | {ord(c) for c in text if ord(c)>127}
    selected.populate(unicodes=wanted)
    selected.subset(font)
    for record in font['name'].names:
        if record.nameID in [1,4,6,16]:
            name = 'YunluVolumeUI-Regular' if record.nameID == 6 else 'Yunlu Volume UI'
            record.string = name.encode(record.getEncoding(), errors='replace')
    font.save(OUTPUT)
    missing = wanted - set(font.getBestCmap())
    assert not missing, missing
    print('VOLUME UI FONT:', len(font.getBestCmap()), 'glyphs;', OUTPUT.stat().st_size, 'bytes')

if __name__ == '__main__':
    run()
