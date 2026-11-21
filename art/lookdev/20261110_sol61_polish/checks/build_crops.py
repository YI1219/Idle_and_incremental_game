from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
b=Path(__file__).resolve().parents[1];out=b/'comparison_crops';out.mkdir(exist_ok=True)
font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',26)
cases=[('junction','1 草石交界','00_approved_day','01_planted_junction_day','cliff_close.png',(450,300,1840,720)),('path','5 石板路阴影','01_planted_junction_day','02_path_contact_day','close.png',(550,220,1250,1120)),('rhythm','2 岩壁重复','02_path_contact_day','03_cliff_rhythm_day','whole.png',(400,500,2250,1400)),('roots','3 岩壁底部','03_cliff_rhythm_day','04_planar_roots_day','whole.png',(450,780,2140,1400)),('waterfall','4 瀑布','04_planar_roots_day','06_final_day','whole.png',(1530,930,1840,1400))]
records=[]
for name,label,before,after,file,roi in cases:
 pics=[Image.open(b/folder/file).convert('RGB').crop(roi) for folder in [before,after]]
 width=800;height=round(pics[0].height*width/pics[0].width)
 sheet=Image.new('RGB',(width*2+12,height+52),(22,32,32));draw=ImageDraw.Draw(sheet)
 for i,pic in enumerate(pics):
  sheet.paste(pic.resize((width,height),Image.Resampling.LANCZOS),(i*(width+12),52));draw.text((14+i*(width+12),8),label+(' · 前' if i==0 else ' · 后'),font=font,fill=(235,236,215))
 sheet.save(out/(name+'_before_after.png'));records.append({'item':name,'before':before+'/'+file,'after':after+'/'+file,'native_roi':roi,'analysis_resize_only':True})
(out/'rois.json').write_text(json.dumps(records,indent=2,ensure_ascii=False)+'\n')
print('5 analysis-only crops; native frames untouched')
