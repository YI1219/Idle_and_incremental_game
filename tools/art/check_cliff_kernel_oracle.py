"""Compare actual adapter values to existing public field brush records."""
import json,subprocess
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/work/cliff_kernel/2026-10-17'
def run():
    report={}
    for edited in [False,True]:
        source=ROOT/('art/work/cliff_dual/2026-10-17/edited_samples.json' if edited else 'art/work/cliff_representation/2026-10-17/samples.json')
        records=json.loads(source.read_text());name='edited_query' if edited else 'query'
        points=np.array([[r[k]*.25 for k in ['x','y','z']] for r in records],dtype='<f4');points.tofile(OUT/(name+'_points.bin'))
        command=['/tmp/yunlu_cliff_libfive_probe',str(ROOT/'art/work/cliff_representation/2026-10-17/union.bin'),str(OUT/(name+'_results.bin')),'query',str(OUT/(name+'_points.bin')),str(int(edited))]
        subprocess.run(command,check=True)
        result=np.fromfile(OUT/(name+'_results.bin'),dtype='<f4').reshape(-1,4);expected=np.array([r['density'] for r in records]);away=np.abs(expected)>3e-5
        differences=np.abs(np.clip(result[:,0],-.5,.5)-expected)
        radius_distance=np.linalg.norm(points-[-15,3.25,3],axis=1)
        comparable=(radius_distance<4.-1e-7) if edited else np.ones(len(records),dtype=bool)
        strict_sign=away & ((np.abs(radius_distance-4.)>1e-7) if edited else True)
        entry={'nodes':len(records),'sign_mismatches_away_from_both_boundaries':int(np.sum((result[strict_sign,0]<0)!=(expected[strict_sign]<0))),
               'truncated_distance_max_error_in_comparable_domain':float(differences[comparable].max()),'gradient_norm_max_error':float(np.abs(np.linalg.norm(result[:,1:],axis=1)-1).max()),'source_boundary_bias_nodes':int((~away).sum()),
               'all_node_max_density_difference':float(differences.max()),'all_node_density_differences_above_3e5':int((differences>3e-5).sum()),
               'brush_sphere_boundary_sign_differences':int(np.sum(((result[:,0]<0)!=(expected<0))&away&(np.abs(radius_distance-4.)<=1e-7))) if edited else 0}
        assert entry['sign_mismatches_away_from_both_boundaries']==0 and entry['truncated_distance_max_error_in_comparable_domain']<3e-5 and entry['gradient_norm_max_error']<1e-5,entry
        report[name]=entry
    report['scope']='Source adapter/continuous analytic bounded brush versus public field records, ±.5 truncation. Exact value comparison is valid inside the brush only: the public brush skips distance>=radius, whereas a continuous CSG function changes interior distance values outside it without changing their signs. One sphere-boundary sample keeps negative density in the public brush but is zero analytically. This is not exact nodal/edit equivalence or old-save migration. Original positive source-boundary anti-zero bias2e-5 is not surface displacement. No full feature-fan, interval exact-predicate, TerrainData/history/support or arbitrary-edit acceptance.'
    (OUT/'oracle_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('KERNEL ORACLE:',json.dumps(report))
if __name__=='__main__':run()
