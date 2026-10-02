# Qinglan v06 refinement scope

Refine the existing v05 mesh, retaining Tripo sources, ten Quaternius-based animation clips and the existing gait/CMU turn controller. User explicitly authorized this pass and versioned output.

1. Capture v05 in Godot and inspect Blender topology/weights at multiple stride phases. Preserve source hashes first.
2. Restore v03 knee-length trouser design and original calf surfaces; retain v05 upper waistband fit and textile maps. Diagnose crossings before choosing local fit/weight changes. No additional body mask.
3. Add garment-only cuff/hem controls with smooth weights, retain ribbon chains, and apply bounded damped response to actual acceleration, heading change and authored stride. Do not modify humanoid joints or saved motion curves.
4. Compare actual Godot frames front/side/rear and start/stop/turn traversal. Check deforming mesh intersections and response at multiple fixed deltas. Preserve/recheck animation accessor bytes, original rest transforms, bind matrices and source hashes.
5. Run existing movement/animation/space/action tests. Update current asset entries and write candid review separating functional checks, sampled visual findings and outstanding art acceptance.

Tool assessment: existing Blender 5.2.1, Godot 4.7.2, Python, NumPy and Pillow suffice. No Cursor mechanism, MCP plugin, Blender add-on or package installation needed. No cloth solver. Directory is not a Git repository; use versioned assets and a preservation manifest, not a fictitious branch/commit.
