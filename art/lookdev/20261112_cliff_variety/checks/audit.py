import json,hashlib,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
repo=root.parents[2]
read=lambda p:json.loads(p.read_text())
before=read(root/'before/captures.json');final=read(root/'final/captures.json')
assert before['valid'] and final['valid']
changed=[k for k,v in before['source_sha256'].items() if final['source_sha256'][k]!=v]
assert changed==['res://scripts/terrain_editor/procedural_shard.gd'],changed
pairs=[]
for b in before['captures']:
 a=next(x for x in final['captures'] if x['file']==b['file'])
 assert a==b,(a['file'],'camera/light/metadata differ')
 pairs.append(b['file'])
for key in ['data_sha256','resolution','msaa','phase','seed','preset']:
 assert before[key]==final[key],key
for path,digest in final['source_sha256'].items():
 assert hashlib.sha256((repo/path.removeprefix('res://')).read_bytes()).hexdigest()==digest,path
captures=[]
for folder in ['final','held2104','held4242','held913']:
 m=read(root/folder/'captures.json')
 assert m['valid'] and m['data_unchanged'] and m['sources_unchanged'] and m['source_sha256']==final['source_sha256']
 for c in m['captures']:
  assert (root/folder/c['file']).is_file()
 captures.append({'folder':folder,'seed':m['seed'],'preset':m['preset'],'frames':len(m['captures']),'valid':True})
tests=read(root/'checks/final_tests.json')
assert all(t['exit']==0 for t in tests)
assert '16 checks, 0 failures' in (root/'checks/protected_geometry.log').read_text()
page=(root/'compare.html').read_text()
for ref in re.findall(r'(?:src|href)="([^"]+)"',page):
 assert ref=='checks/audit.json' or (root/ref).exists(),ref
report={'paired_frames':pairs,'camera_light_metadata_exact_match':True,'data_exact_match':True,'changed_production_sources':changed,'current_disk_matches_final_capture':True,'final_capture_sets':captures,'final_native_frames':sum(x['frames'] for x in captures),'baseline_native_frames':len(before['captures']),'functional_groups_passed':len(tests)+1,'protected_geometry_checks':16,'comparison_page_local_links_valid':True,'browser_interaction_tested':False,'art_accepted':False}
(root/'checks/audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
