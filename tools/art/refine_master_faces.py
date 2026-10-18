"""One bounded art refinement of the preserved master; not original geometry.

Compose a major central face turn and shoulder-to-foot return by a coherent
triangular-coordinate warp. The top is pinned. This is not a new runtime model
generator or a qualified master until native art review says so.
"""
import importlib.util
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/work/pcg_fracture/2026-10-18/route2_faces'


def warp(tri):
    p = tri.reshape(-1,3).copy()
    y = p[:,1].copy()
    tangent = np.array([.85,.526782687642637])
    outward = np.array([-tangent[1],tangent[0]])
    u = p[:,[0,2]]@tangent
    v = p[:,[0,2]]@outward
    t = np.clip((3.5-y)/3.5,0,1)
    # The entire source receives the same coordinate map. Positive width
    # scales and a monotone base-height profile are construction choices,
    # not a validity guarantee for the final triangulated mesh. This actual
    # candidate fails the strict-crossing gate and must not be retained.
    su = np.interp(t,[0,.16,.55,.82,1],[1,1.035,.96,.78,.58])
    sv = np.interp(t,[0,.16,.55,.82,1],[1,1.04,.97,.82,.63])
    shoulder = np.interp(t,[0,.16,.55,.82,1],[0,.24,.30,-.18,-.68])
    # An asymmetric central ridge creates two major facing directions. It
    # dies into the lower return, instead of cutting a full-height channel.
    central = np.maximum(0,1-np.abs((u-.25)/2.35))
    turn = central*np.interp(t,[0,.16,.55,.82,1],[0,.35,.48,.16,0])
    lean = np.clip(u/5,-1,1)*np.interp(t,[0,.16,.55,.82,1],[0,-.05,.14,.05,0])
    unew = u*su
    vnew = v*sv+shoulder+turn+lean
    p[:,[0,2]] = unew[:,None]*tangent+vnew[:,None]*outward
    ybase = np.interp(t,[0,.16,.55,.82,1],[3.5,2.75,.55,-1.65,-2.85])
    # A second vertical shear varies the basal edge across the complete
    # source. It creates neither another bottom skin nor separate feet.
    lower = np.clip((.6-ybase)/3.45,0,1)
    basal = .12*np.abs(unew-.6)+.10*vnew
    p[:,1] = ybase+lower*basal
    cap = np.abs(y-3.5)<1e-5
    p[cap] = tri.reshape(-1,3)[cap]
    return p


def run():
    spec=importlib.util.spec_from_file_location('existing_master',ROOT/'tools/art/probe_cliff_master.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    module.OUT=OUT;module.warp=warp;module.run()
    path=OUT/'master_report.json';report=json.loads(path.read_text())
    report['design']='Coherent source-frame central main-face turn, unequal shoulder projection and shared narrowing basal return; exact cap preserved.'
    report['source_original_model_created']=False
    path.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':run()
