"""Deterministic tileable material data; RGBA = value, slope X/Y, roughness.
Maps are linear data, not sRGB. Run with Python + numpy + Pillow.
No source photograph or AI artwork is used. Runtime shaders retain the palette.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
OUT=Path(__file__).resolve().parents[2]/'assets/textures/terrain'
N=1024
rng=np.random.default_rng(121026)
def noise(scale):
    a=rng.standard_normal((N,N))
    k=np.fft.fftfreq(N)*N
    filt=np.exp(-(k[:,None]**2+k[None,:]**2)/(scale**2))
    a=np.fft.ifft2(np.fft.fft2(a)*filt).real
    return (a-a.mean())/a.std()
def save(name,value,height,rough,strength):
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*strength
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))*strength
    rgba=np.stack([value,.5+dx,.5+dy,rough],-1)
    Image.fromarray((np.clip(rgba,0,1)*255).astype('uint8')).save(OUT/name)
# Broad mineral clouds, close-grained grit and sparse shallow pits. Scales
# deliberately avoid painted cracks: mesh fractures provide the large cuts.
cloud=noise(7);grain=noise(70);fine=noise(220);pits=np.maximum(noise(145)-1.25,0)
height=.20*cloud+.13*grain+.055*fine-.17*pits
save('stone_detail.png',.5+.065*cloud+.043*grain+.026*fine-.045*pits,height,.88+.045*grain,1.8)
# Tileable short overlapping leaf/blade tufts, with fine fibrous soil between.
canvas=Image.new('F',(N,N),0);draw=ImageDraw.Draw(canvas)
for i in range(6500):
    x,y=rng.uniform(0,N,2);ang=rng.uniform(0,np.pi*2)
    length=rng.uniform(4,21);width=rng.uniform(1,3);tone=rng.uniform(.2,1)
    dx,dy=np.cos(ang),np.sin(ang)
    poly=[(x-dy*width,y+dx*width),(x+dx*length,y+dy*length),(x+dy*width,y-dx*width)]
    for ox in [-N,0,N]:
        for oy in [-N,0,N]:draw.polygon([(px+ox,py+oy) for px,py in poly],fill=tone)
blades=np.asarray(canvas);soil=noise(110);clump=noise(13)
height=.16*blades+.055*soil+.08*clump
save('ground_detail.png',.48+.21*blades+.036*soil+.035*clump,height,.94-.04*blades,1.1)
print('Baked two 1024² tileable packed material maps')
