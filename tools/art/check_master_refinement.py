"""Regression checks only; do not confuse these with geometry/art acceptance.

Run in Blender. Requires the archived old master artifacts, which the original
probe/capture scripts reproduce. The new candidate separately fails validity.
"""
import importlib.util
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]


def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def run():
    master=module('tools/art/probe_cliff_master.py','master_regression')
    source=np.fromfile(master.SOURCE,dtype='<f4').reshape(-1,3,3).astype(float)
    source+=np.array([15,0,-3]);tri=master.subdivide(source)
    before=np.fromfile(ROOT/'art/work/pcg_fracture/2026-10-18/route2/master_warp.bin',dtype='<f4').reshape(-1,3)
    assert np.array_equal(master.warp(tri).astype('<f4'),before),'default deformation changed'
    faces=module('tools/art/refine_master_faces.py','faces_regression')
    after=faces.warp(tri);cap=np.abs(tri.reshape(-1,3)[:,1]-3.5)<1e-5
    assert np.array_equal(after[cap],tri.reshape(-1,3)[cap]),'cap moved'
    assert np.isfinite(after).all(),'nonfinite points'
    print('MASTER REFINEMENT REGRESSION: 3/3 passed; archived default output identical; cap occurrences preserved; finite only, not validity/art approval')


if __name__=='__main__':run()
