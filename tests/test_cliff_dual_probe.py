"""Numerical guarantees for the tool-only, box-constrained QEF solve."""
import importlib.util,unittest
from pathlib import Path
import numpy as np
from collections import Counter
spec=importlib.util.spec_from_file_location('dc',Path(__file__).resolve().parents[1]/'tools/art/cliff_dual_contour.py')
dc=importlib.util.module_from_spec(spec);spec.loader.exec_module(dc)
class QefTests(unittest.TestCase):
 def check_oriented_closed(self,vertices):
  edges=Counter()
  for tri in np.round(vertices,5).reshape(-1,3,3):
   keys=[tuple(p) for p in tri]
   for a,b in zip(keys,keys[1:]+keys[:1]):edges[(a,b)]+=1
  self.assertTrue(all(count==1 and edges[(b,a)]==1 for (a,b),count in edges.items()))
 def test_three_planes_recover_corner(self):
  p=np.array([[.2,0,0],[0,.3,0],[0,0,.4]])
  result=dc.solve_qef(p,np.eye(3),np.zeros(3),np.ones(3))
  np.testing.assert_allclose(result,[.2,.3,.4],atol=1e-5)
 def test_rank_one_keeps_tangential_mass_center(self):
  p=np.array([[.2,.3,.6],[.8,.7,.6]])
  result=dc.solve_qef(p,np.array([[0,0,1],[0,0,1]]),np.zeros(3),np.ones(3))
  np.testing.assert_allclose(result,[.5,.5,.6],atol=1e-5)
 def test_solution_cannot_escape_cell(self):
  p=np.array([[1.2,0,0],[0,.3,0],[0,0,.4]])
  result=dc.solve_qef(p,np.eye(3),np.zeros(3),np.ones(3))
  self.assertTrue(np.all(result>=0) and np.all(result<=1))
  np.testing.assert_allclose(result,[.9999,.3,.4],atol=1e-5)
 def test_sphere_has_consistent_face_orientation(self):
  records=[]
  for q in np.ndindex((9,9,9)):
   q=np.asarray(q)-4;d=np.linalg.norm(q*.25-[.02,.03,.04])-.7
   records.append(dict(zip(('x','y','z','density'),[*map(int,q),float(d)])))
  vertices,_=dc.reconstruct(records)
  self.check_oriented_closed(vertices)
 def test_diagonal_pockets_do_not_share_a_nonmanifold_edge(self):
  records=[{'x':0,'y':0,'z':0,'density':-.2},{'x':1,'y':1,'z':0,'density':-.2}]
  vertices,_=dc.reconstruct(records)
  self.check_oriented_closed(vertices)
if __name__=='__main__':unittest.main()
