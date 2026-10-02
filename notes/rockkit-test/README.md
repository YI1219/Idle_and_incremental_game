# Rock-kit floating-island underside: prototype (云露村)

The top stays procedural. The underside and shore edge are built from a small kit of CC0 low-poly rocks,
placed along the coastline polygon by rules. Blender 4.2.3 renders it headless with Eevee and a toon ramp.

- Script: `rockkit_island.py`. Run it with `blender -b -P rockkit_island.py -- --seed 7 --views side,overview --glb` (other flags: `--contact`, `--cone`, `--res WxH`)
- Renders: `renders/` (seed7_side, seed7_overview, seed23_side, seed23_side34, kit_contact_sheet, baseline_cone_seed7_side)
- Export: `export/island_seed7.glb` contains the rocks joined into one mesh, with the palette baked into COLOR_0, plus the top slab and roots. `export/layout_seed7.json` holds the coastline, the params, and every instance's piece name, ring, coast segment, and 4x4 matrix.

## Assets (all CC0 1.0; license checked on the source page and in the bundled license file)
| Pack | Source page | Pieces used |
|---|---|---|
| KayKit – Forest Nature Pack 1.0 (FREE), Kay Lousberg | https://kaylousberg.itch.io/kaykit-forest (page says "CC0 Licensed"; `License.txt`: CC0) | Rock_2_H, Rock_2_E, Rock_3_Q, Rock_3_O, Rock_3_K, Rock_3_G, Rock_1_O, Rock_1_K |
| Quaternius – Stylized Nature MegaKit [Standard] | https://quaternius.com/packs/stylizednaturemegakit.html → https://quaternius.itch.io/stylized-nature-megakit ("CC0 License"; `License_Standard.txt`: CC0 1.0) | Rock_Medium_1, Rock_Medium_3 |

Quaternius *Ultimate Nature* (https://quaternius.com/packs/ultimatenature.html, CC0) could not be downloaded. It is hosted on Google Drive, which returned "Quota exceeded". Kenney was not needed.
Neither pack includes hanging roots or vines. The roots in the renders are procedural bevelled curves, not assets.

## Assembly algorithm (units are metres, Z up in Blender, so Y up in Godot)
1. **Coastline:** `r(θ) = R0·(1 + Σ a_k·sin(kθ+φ_k))`, with R0 = 6 and (k, a) = (2, .10), (3, .08), (5, .035), (7, .015). Each amplitude gets a random ×0.7–1.3 and each phase is random. The polygon is resampled to 256 points at equal arclength, CCW.
2. **Kit normalisation:** each piece is flipped upside down (180° about X), so the flat base sits against the slab and the crown points down. The origin is moved to the **top-centre** of the bounding box. Store `width = max(dx, dy)` and `height`. Each piece gets a role: `rim`, `mid`, or `tip`.
3. **Rings:** each ring is the coastline scaled about its centroid by `s`. The piece count is `round(perimeter / (width·spacing))`, with a random start offset. Spacing < 1 makes neighbours overlap and hides the seams.

| ring | s | top z | target width | scale rand | z-stretch | inward tilt | spacing | pool |
|---|---|---|---|---|---|---|---|---|
| 0 (shore) | 0.985 | -0.15 | 2.6 | 0.8–1.3 | 0.9–1.15 | 10° | 0.62 | rim |
| 1 | 0.80 | -1.25 | 2.3 | 0.8–1.2 | 1.0–1.25 | 16° | 0.66 | rim+mid |
| 2 | 0.58 | -2.35 | 2.0 | 0.8–1.15 | 1.0–1.3 | 20° | 0.70 | mid+rim |
| 3 | 0.35 | -3.40 | 1.7 | 0.8–1.1 | 1.05–1.35 | 24° | 0.75 | mid |

   For each piece:
   - `scale = target_width / piece.width · rand`. Scale is non-uniform: Z gets `· zstretch`.
   - Yaw is random from 0 to 2π.
   - Tilt is applied about the coastline tangent, with the sign chosen so the bottom leans **inward**. The tilt is ±(0.7–1.2)× the ring value.
   - Position: `p − n·(0.75·half_width − protrude)`. `protrude` is 0.05 on ring 0 and 0 elsewhere. Jitter is ±25% of the step along the arc, ±0.18 m radially, and ±0.15 m in z.
   - After rotation, the piece's **true** top (the max vertex z) is snapped to the ring's top z. Tilt lifts one edge, and without the snap it pokes through the grass.
4. **Tips:** 1–3 `tip` pieces. The first sits at the centroid, top at z -3.7, width 2.3–2.9, z-stretch 0.65–0.85. The others are offset 0.6–1.3 m, smaller, and tilted outward.
5. **Occluder core:** a hidden faceted inverted cone, built from the coastline ×0.9 from z -0.7 down to -4.6, using the rock material. It stops sky showing through gaps between rings. It is cheap, and it lets the spacing stay loose.
6. **Palette:** one shared rock material. Base colour is a **world-Z gradient**: warm #9b7d64 at the rim, #86796f in the middle, cool #6f7279 at -7.5 m, with an EASE ramp and ±0.06 per-instance value jitter. Shading is flat (faceted), with Diffuse → ShaderToRGB → a 3-stop soft ramp. Grass is #9cbf7a and earth is #9a7656.
7. **Seed:** a single `random.Random(seed)` drives everything, in a fixed call order, so the result is deterministic.

Seed 7 uses about 74 instances and about 22k tris. The kit pieces are 168–529 tris each.

## Porting to Godot 4 (plan)
- Import the kit GLBs once and apply step 2's flip and recentre (or bake it in Blender). Use one `MultiMeshInstance3D` per kit piece. 10 pieces means 10 draw calls per island, or share them across islands.
- The rock shader colours from world-space Y: in the vertex shader, `world_y = (MODEL_MATRIX * vec4(VERTEX,1)).y`, then feed that to the gradient and toon ramp. **Do not bake vertex colours.** Instances share one mesh, so baked colours can't follow the gradient. The GLB here is baked only so it can be previewed.
- Placement data per instance: `{piece, ring, seg_index, arclen_t}`. When the coastline changes:
  - recompute each ring's polygon and perimeter;
  - for each ring, compare the new piece count with the old one, then add or remove instances at the end of the arclength list and re-space the rest with the same per-slot RNG. Seed each slot with `hash(island_seed, ring, slot)` so pieces don't reshuffle;
  - re-run the top-snap, so pieces always hang from the slab and nothing floats;
  - rebuild the occluder core from the new coastline.
- Keep the ring table as a `Resource` so artists can tune it.

## Honest notes
**Good**
- It reads as a mass of faceted boulders and cliff blocks, with a broken, stepped silhouette. That is far better than the smooth cone (compare `baseline_cone_seed7_side.png`).
- The warm-to-cool gradient sells depth.
- The KayKit trapezoid blocks (Rock_2_*) make good shore cliffs.

**Weak**
- The stepped KayKit column tip (Rock_1_O) can read as a "drill bit" (seed 7).
- On seed 23 the tip is mostly buried. Tip height should be relative to the lowest ring bottom, not a fixed z.
- Ring 0 cliff blocks can look boxy and repetitive in a straight side view.
- A thin smooth earth band remains under the grass lip.
- The roots are thin procedural sticks.
- The KayKit and Quaternius styles differ a little, but the shared flat palette hides most of it.
- The top surface is a plain flat plate (out of scope).
- At about 22k tris per island it is fine on desktop. For mobile, drop ring 3 or use smaller pieces.
