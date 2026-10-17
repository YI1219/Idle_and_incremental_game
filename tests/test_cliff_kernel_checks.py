"""Geometry gates must distinguish an immersed surface from valid topology."""
import importlib.util,unittest
from pathlib import Path
import numpy as np
spec=importlib.util.spec_from_file_location('cross',Path(__file__).resolve().parents[1]/'tools/art/check_cliff_dual_intersections.py')
cross=importlib.util.module_from_spec(spec);spec.loader.exec_module(cross)
class KernelCheckTests(unittest.TestCase):
 def test_strict_interior_crossing(self):
  hit=cross.hit(np.array([.25,.25,-1]),np.array([.25,.25,1]),np.array([[0.,0,0],[1.,0,0],[0.,1,0]]))
  self.assertIsNotNone(hit);self.assertAlmostEqual(hit['segment_fraction'],.5)
 def test_coplanar_is_not_claimed_as_a_strict_crossing(self):
  self.assertIsNone(cross.hit(np.array([.1,.1,0]),np.array([.2,.2,0]),np.array([[0.,0,0],[1.,0,0],[0.,1,0]])))
 def test_outside_triangle_is_not_a_crossing(self):
  self.assertIsNone(cross.hit(np.array([2.,2,-1]),np.array([2.,2,1]),np.array([[0.,0,0],[1.,0,0],[0.,1,0]])))
 def tetra(self,scale):
  p=np.array([[0.,0,0],[1.,0,0],[0.,1,0],[0.,0,1]])*scale
  return p[[0,2,1,0,1,3,1,2,3,2,0,3]]
 def test_closed_tetrahedron_has_cycle_links(self):
  self.assertEqual(cross.vertex_link_defects(self.tetra(1)),0)
 def test_two_tetrahedra_sharing_one_vertex_have_bad_link(self):
  self.assertEqual(cross.vertex_link_defects(np.vstack((self.tetra(1),self.tetra(-1)))),1)
if __name__=='__main__':unittest.main()
