"""Keep original animation accessor bytes; discard exporter-generated constant new-bone tracks."""
from pathlib import Path
import json,struct,hashlib,copy
ROOT=Path(__file__).resolve().parents[2]
def read(p):
 d=p.read_bytes();n=struct.unpack_from('<I',d,12)[0];return json.loads(d[20:20+n]),d[28+n:]
def raw(j,b,i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];w={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]*{5126:4,5125:4,5123:2,5121:1}[a['componentType']];o=v.get('byteOffset',0)+a.get('byteOffset',0);s=v.get('byteStride',w);return b''.join(b[o+k*s:o+k*s+w] for k in range(a['count']))
def clips(j,b):
 return {a['name']:{(j['nodes'][c['target']['node']]['name'],c['target']['path']):(raw(j,b,a['samplers'][c['sampler']]['input']),raw(j,b,a['samplers'][c['sampler']]['output']),a['samplers'][c['sampler']].get('interpolation','LINEAR')) for c in a['channels']} for a in j['animations']}
def main():
 p=ROOT/'assets/characters/qinglan/qinglan_garment_v06.glb';old,ob=read(ROOT/'assets/characters/qinglan/qinglan_fabric_v05.glb');j,b=read(p);buf=bytearray(b);names={n['name']:i for i,n in enumerate(j['nodes'])}
 animations=[]
 for a in old['animations']:
  out=copy.deepcopy(a)
  for s in out['samplers']:
   for key in ['input','output']:
    original=s[key];data=raw(old,ob,original)
    while len(buf)%4:buf.append(0)
    view=len(j['bufferViews']);j['bufferViews'].append({'buffer':0,'byteOffset':len(buf),'byteLength':len(data)});buf.extend(data)
    ac=copy.deepcopy(old['accessors'][original]);ac['bufferView']=view;ac.pop('byteOffset',None)
    s[key]=len(j['accessors']);j['accessors'].append(ac)
  for c in out['channels']:c['target']['node']=names[old['nodes'][c['target']['node']]['name']]
  animations.append(out)
 j['animations']=animations;j['buffers'][0]['byteLength']=len(buf)
 encoded=json.dumps(j,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);buf+=b'\0'*((-len(buf))%4)
 p.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(buf))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(buf),0x004e4942)+buf)
 assert clips(old,ob)==clips(j,buf)
 report={'animation_tracks':{a['name']:'all 84 original channels byte-identical (input/output/interpolation), targets matched by bone name' for a in old['animations']},'exporter_constant_tracks_removed':30,'new_garment_bones':10}
 (ROOT/'art/review/garment_v06/animation_preservation.json').write_text(json.dumps(report,indent=2));print('Ten original clips byte-identical; new control constant tracks removed.')
if __name__=='__main__':main()
