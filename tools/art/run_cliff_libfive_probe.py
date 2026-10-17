"""Run actual unmodified libfive algorithms through the existing-source adapter."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/cliff_kernel/2026-10-17'
BINARY=Path('/tmp/yunlu_cliff_libfive_probe')
SOURCE=ROOT/'art/work/cliff_representation/2026-10-17/union.bin'
def main():
    revision=json.loads(Path('/tmp/yunlu_cliff_kernel_deps/revision.json').read_text())
    report={**revision,'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            'adapter_sha256':hashlib.sha256((ROOT/'tools/art/cliff_libfive_probe.cpp').read_bytes()).hexdigest(),
            'source_license':'libfive core MPL2; separate temporary unmodified build; no GUI or language bindings installed',
            'settings':{'region':[[-23,-6,-5],[-7,10,11]],'min_feature':.25,'max_err':1e-8,'workers':4},
            'source_oracle':'Euclidean triangle distance, three-ray parity majority, center-distance plus half-diagonal Lipschitz interval with1e-4 float margin. One selected SDF gradient; no complete multi-feature fan.',
            'edited_expression':'max(source_sdf,min(y-3.25,4-length(p-(-15,3.25,3))))',
            'scope':'Offline kernel feasibility only; source/analytic operation data are additional to density-only records. No persistent editor/history/collision/support/backend or target-device performance acceptance.',
            'stages':{}}
    for alg,name in enumerate(['dc','simplex','hybrid']):
        for edited in [False,True]:
            stage='libfive_'+name+('_edited' if edited else '')
            command=[str(BINARY),str(SOURCE),str(OUT/(stage+'.bin')),str(alg),str(int(edited))]
            result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
            log=Path('/tmp')/('yunlu_cliff_kernel_'+stage+'.log');log.write_text(result.stdout)
            report['stages'][stage]={'returncode':result.returncode,'command':command,'log':str(log),'result':result.stdout}
            (OUT/'kernel_runs.json').write_text(json.dumps(report,indent=2)+'\n')
            print(stage,result.returncode,result.stdout.strip(),flush=True)
            if result.returncode!=0:continue
            assert (OUT/(stage+'.bin')).stat().st_size>0
    print('KERNEL RUNS COMPLETE',flush=True)
if __name__=='__main__':main()
