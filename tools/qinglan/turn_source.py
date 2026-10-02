"""Narrow CMU Acclaim reader. Column-vector equivalent of the published ASF rules."""
from pathlib import Path
from math import radians,atan2,pi
from mathutils import Vector,Matrix,Euler
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/source/third_party/cmu_turns'
CONVERT=Matrix.Rotation(pi/2,3,'X')

def rotation(values):return Euler(tuple(radians(v) for v in values),'XYZ').to_matrix()
def read_asf():
 text=(SOURCE/'69.asf').read_text(); bones={}; section=''; current=None
 for line in text.splitlines():
  a=line.split()
  if not a:continue
  if a[0].startswith(':'):section=a[0];continue
  if section==':bonedata':
   if a[0]=='begin':current={'dof':[]}
   elif a[0]=='end':bones[current['name']]=current
   elif a[0] in ['name','direction','length','axis','dof']:
    key=a[0];current[key]=a[1] if key=='name' else float(a[1]) if key=='length' else a[1:] if key=='dof' else tuple(float(x) for x in a[1:4])
  elif section==':hierarchy' and a[0] not in ['begin','end']:
   for child in a[1:]:bones[child]['parent']=a[0]
 for b in bones.values():b['C']=rotation(b['axis']);b['direction']=Vector(b['direction'])
 return bones

def read_amc(trial):
 frames=[];frame=None
 for line in (SOURCE/(trial+'.amc')).read_text().splitlines():
  a=line.split()
  if not a or a[0].startswith(('#',':')):continue
  if a[0].isdigit():
   if frame and len(frame)==29:frames.append(frame)
   frame={}
  else:frame[a[0]]=tuple(map(float,a[1:]))
 if frame and len(frame)==29:frames.append(frame)
 return frames

def pose(bones,frame):
 rotations={'root':rotation(frame['root'][3:])};positions={'root':Vector(frame['root'][:3])};heads={}
 def visit(name):
  if name in rotations:return
  b=bones[name];p=b['parent'];visit(p)
  angles=[0.,0.,0.]
  for key,v in zip(b['dof'],frame.get(name,[])):angles['xyz'.index(key[1])]=v
  rotations[name]=rotations[p] @ b['C'] @ rotation(angles) @ b['C'].transposed()
  heads[name]=positions[p]
  positions[name]=positions[p]+rotations[name] @ b['direction']*b['length']
 for n in bones:visit(n)
 return ({n:CONVERT@r@CONVERT.transposed() for n,r in rotations.items()}, {n:CONVERT@p for n,p in positions.items()})

def yaw(frame):
 d=rotation(frame['root'][3:])@Vector((0,0,1))
 return atan2(d.x,d.z)

def unwrapped(frames):
 result=[]
 for f in frames:
  value=yaw(f)
  if result:
   while value-result[-1]>pi:value-=2*pi
   while value-result[-1]<-pi:value+=2*pi
  result.append(value)
 return result
if __name__=='__main__':
 bones=read_asf()
 for name in ['69_07','69_13','69_16','69_20','69_24']:
  frames=read_amc(name);ys=unwrapped(frames)
  print(name,len(frames),'full frames')
  print([(round(i/120,1),round(ys[i]*180/pi)) for i in range(0,len(ys),60)])
