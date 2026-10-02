# First inspection of the cottage original

Untextured and textured versions were both kept and imported into Blender successfully. Real model renders from two relative directions were inspected. Both have 2834 triangles and matching bounds; the textured version includes a 1024×1024 base-color map. This does not mean vertex-by-vertex geometry match was verified.

Conclusion: currently suitable as a refinement candidate. Do not ask the user to retry immediately. Roof and wall large form and color direction roughly match the reference. The doorway appears to have a closed face; it needs further inspection and opening into a traversable entrance. Beams have light color bleed; eave seams and post–beam junctions also need cleanup. Refinement, collision, actual size, and game acceptance are not done.

Raw boundary count cannot be used as hole count: the textured version has vertex splits from UV/normal seams. Merge coincident points on a work copy and locate before judging. Do not blindly fill every building opening; doors and windows should remain.

Later flow: untextured inspection → free same-parameter retry if needed → form accepted → then consider 10-credit texturing → refine and import. Fees and no-retry limits follow current user-account feedback.

## First-version refinement result

On the Tripo original: doorway cut open, frame widened, original lintel extended; timber/wall/plinth materials edited to remove color bleed; roof normals display fixed. 2966 triangles; GLB round-trip is 1 mesh, 4 materials. 16 doorway sample rays passed. Character-capsule collision and actual indoor entry still awaited game integration. Original open wall shells and local non-manifold edges were not all repaired. No regeneration needed.

### Latest status: cottage integrated into the demo

Current runtime asset `assets/buildings/cottage/cottage_tripo.glb` replaced the old cottage. Extra margin for sleeves and character collision: entrance finally widened to 1.608 m (old 1.37 m was the previous version), height 1.829 m; wall collision and doorway alignment redone. Center and left/right-offset traversal, blocking beside the door, and automatic indoor transition all passed; Demo 21/21, space 21/21, camera 8/8. Default framing was adjusted and actual picture checked. The candidate keeps open wall shells. Final art acceptance and low-spec performance are not claimed. No user retry needed this time.
