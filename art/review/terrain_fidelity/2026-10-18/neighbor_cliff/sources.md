# Reference evidence for the small neighbor-cliff decision goal

Checked2026-10-18. Sources do not establish a finished implementation or visual
acceptance in this project. No art assets were downloaded or imported.

## Brushland: documented interaction, unknown cliff internals

[Developer-authored Steam description](https://store.steampowered.com/app/5163450/Brushland/)
describes painting tiles whose appearance responds to neighbors, including rock,
mountains, rivers and cliffs. [Transhuman Design announcement,2026-10-16](https://www.gamespress.com/en-US/Brushland-announced-paint-an-entire-kingdom)
confirms the game and announced demo plans. These establish the behavior we want
to study, not whether it uses SDF/Voronoi/WFC, handcrafted cliff modules, a
heightfield or a particular shader. No public cliff source was found in this
bounded search; do not turn that into a claim that none exists.

## Tiny Glade: multiple curated systems, not a universal algorithm

[Direct interview with Anastasia Opara and Tomasz Stachowiak,2024-05-30](https://80.lv/articles/exclusive-tiny-glade-developers-discuss-bevy-proceduralism-publishers-cozy-games)
explains that the developers author procedural rules and use different pipelines
for creating, assembling, morphing and deforming different elements. It also
describes their custom rendering/GPU generation. It does not publish the shipped
cliff-construction algorithm. Lighting/GPU choices alone do not supply a natural
rock silhouette; no engine replacement is implied.

Anastasia's [country-slice repository](https://github.com/anopara/country-slice)
is a public MIT-licensed Rust/Bevy/OpenGL hobby prototype. Inspected exact revision
**3f6a459c0424ed9177a0dceec4d72a380cbd80c2**, not a guessed release version:

- [terrain.rs](https://github.com/anopara/country-slice/blob/3f6a459c0424ed9177a0dceec4d72a380cbd80c2/src/resources/terrain.rs)
  defines a512×512height texture, optional Perlin FBM generation, height queries;
  initial texture is flat. It is not a volumetric cliff/overhang generator.
- [vertex_color_terrain.vert](https://github.com/anopara/country-slice/blob/3f6a459c0424ed9177a0dceec4d72a380cbd80c2/shaders/vertex_color_terrain.vert)
  samples that texture using XZ and displaces Y. Copying this alone would lose
  our required editable undercuts and common underside.
- [wall_constructor.rs](https://github.com/anopara/country-slice/blob/3f6a459c0424ed9177a0dceec4d72a380cbd80c2/src/geometry/wall_constructor.rs)
  fits varied bricks into curve-space rows; this is masonry, not cliff proof.
- [instanced_wall.vert](https://github.com/anopara/country-slice/blob/3f6a459c0424ed9177a0dceec4d72a380cbd80c2/shaders/instanced_wall.vert)
  deforms instances and samples the same terrain texture to adjust contact.
  Shared contact data is transferable as a principle; this project's previous
  actual-field contact already follows a stronger editable-volume constraint.

These source inspections prevent mislabeling the hobby prototype or a fan clone
as shipped Tiny Glade cliff source. No executable/dependency install was run.

## Townscaper: separate logical state and rendered tiling

[Oskar Stålberg's own2021-10-13thread, archived verbatim](https://threadreaderapp.com/scrolly/1448248658865049605)
explains using a dual grid for rendered field-like tiles while retaining the main
grid for gameplay logic and objects. His [Beyond Townscapers conference talk](https://www.youtube.com/watch?v=Uxeo9c-PX-w)
is a primary lead, but this study does not claim to have verified a transcript
or reproduce its full deformation system. This is not proof that WFC, an
irregular quad grid or any tile system alone yields our target rock forms.

## Our own bounded inference and test

Take context-sensitive construction and curated element-specific rules, while
retaining our shared sculptable terrain authority. One small own experiment
fits bounded3Dconvex face regions to neighbor boundary spans/tangents and makes
unequal inclined shoulders and bottom cuts. Exact union with a common volume
produces one candidate surface; originals remain hidden source construction
evidence, not independent runtime stones or a separate decorative bottom shell.

This differs from failed concentric perimeter rings and from the earlier random
3Dfracture partition. It is still only a four-region standard fixture, not an
arbitrary-contour/seed compiler or a faithful recreation of reference internals.
Actual neutral art and finite checks decide adopt/reject before conversion.
At most two substantive rules; no material/detail/seed sweeps or paid generation.

The small goal is a research/feasibility decision. The earlier full target still
requires user-approved main form/contact/basal finish, multiple layouts/seeds,
shared editable integration and separate performance evidence.
