# Floating Island LookDev — Execution Brief

## 1. Objective and completion meaning

Improve the existing Godot floating-island environment into a coherent, visually improved, review-ready real-time scene. Work in the actual project: inspect, implement, run, capture, compare, and refine. Do not substitute a design essay, shader source alone, an offline render, or an AI-generated image for an improved running scene.

The central artistic objective is a peaceful, inhabitable, stylized Chinese-fantasy sanctuary: simple geometry, strong large-scale forms, convincing liquid water, differentiated materials, readable lighting, restrained atmosphere, and deliberately placed detail.

The target is **a verified candidate ready for the user's art review**, not an unbounded promise of perfection. Technical validation and the user's final aesthetic approval are separate. Do not invent an aesthetic score or claim that the user has approved the result.

## 2. Inputs and reference hierarchy

Read the repository's applicable instructions and inspect the actual project before editing. Identify the Godot version, active rendering method, main scene, camera controls, terrain generation or source meshes, water materials, lighting/environment resources, and existing performance targets.

Use the supplied images as follows:

- **Current in-engine screenshot:** the baseline for existing layout, scene identity, and visible problems. Reproduce this view in the running project when possible.
- **Preferred daytime concept, if supplied:** a secondary reference for comfortable terrain proportions, irregular but blunt rock masses, simple trees, and two flat terraces.
- **Night concept:** a reference for brightness hierarchy, cool environmental light versus localized warm light, grounded objects, coherent rock masses, water highlights, and atmospheric separation. It is not a replacement layout.

Do not copy the night concept's single terrace, pavilion, thick inverted-cone underside, oversized moon, or exact object positions. Do not assume the concept demonstrates a physically consistent or affordable real-time rendering setup. Extract visual qualities and reproduce them coherently within the actual project.

A screenshot establishes appearance, not implementation. Distinguish visible symptoms from causes confirmed by inspecting meshes, shaders, lights, and runtime behavior. In particular, do not infer absent Fresnel, a specific roughness value, polygon counts, animation quality, or GPU cost from a still image alone.

## 3. Non-negotiable constraints

Preserve two flat, usable terrain terraces at different elevations; one lake on each; water flowing from the upper lake into the lower lake and then off the island; and a modest traditional Chinese cottage rather than a pavilion, temple, or palace.

Preserve a moderately thick, broadly shallow island base. Avoid an inverted cone, a smooth boat-shaped bowl, knife-like protrusions, downward spikes, detached floating stones, and regimented rows of equally sized rock blocks. Local irregularity must not turn playable terrace surfaces into uneven slopes.

Keep trees simple, with a few large crown masses rather than individual leaves or many small clusters. Preserve useful open ground and gameplay readability. Do not solve the scene by filling it with vegetation, fences, particles, or decorative props.

Retain the rotatable, zoomable gameplay camera. Do not optimize exclusively for a locked presentation view. Preserve gameplay behavior, collisions, navigation, save compatibility, and unrelated systems. Modify procedural source or original resources when needed so improvements survive regeneration and reopening.

Do not change the engine version, switch renderer, add a substantial dependency, buy assets, publish anything, or perform destructive project-wide restructuring without approval. Preserve existing user changes. Keep edits reversible and inside the visual scope.

## 4. Art direction and implementation targets

### A. Composition and visual hierarchy

**Problem to investigate:** the scene reads as separately placed assets with several equally strong focal points.

**Analysis:** the layout already contains a useful visual sequence, but scale, brightness, contrast, detail density, and peripheral objects may not support it consistently.

**Required result:** organize attention around cottage/upper lake → connecting waterfall → lower lake → outer waterfall. Let trees frame the scene without becoming stronger than the inhabited area. Keep quiet areas between detail clusters and preserve clear playable space. Avoid making every surface equally bright, saturated, or textured.

**Candidate edits:** adjust tree crown size, peripheral prop placement, focal-area lighting, local ground color, and unnecessary repeated decoration. Do not move major gameplay structures merely to improve one screenshot.

### B. Terrain silhouette and terrace relationship

**Problem to investigate:** two neatly cut platforms or matching ellipses rather than a naturally irregular island.

**Analysis:** small triangle facets cannot compensate for a generic outline or a uniform relationship between the two terraces.

**Required result:** preserve flat playable surfaces but introduce a few large-scale protrusions, recesses, and asymmetric terrace shoulders. The lower terrace should wrap around the upper one unevenly rather than tracing it uniformly. Keep the height difference clear and both lakes comfortably embedded in their terrain.

**Candidate edits:** alter the terrain's outer boundary and cliff transition locally; use a few substantial shape changes instead of many tiny random displacements. Revalidate affected collisions and navigation.

### C. Rock masses, cliff shading, and island underside

**Problem to investigate:** a continuous bowl-shaped base, monotonous vertical cliff walls, or a noisy field of gray triangles.

**Analysis:** the intended style should reveal coherent rock volumes first and low-poly facets second. Uniform block repetition and arbitrary per-triangle shading both weaken that hierarchy.

**Required result:** several broad, interlocking, blunt rock masses with irregular ledges and a generally shallow, stepped underside. Keep moderate thickness; neither flatten the island into a wafer nor thicken it into a mountain.

**Candidate edits:** adjust silhouette and major massing before adding geometry. Inspect normals and face-color assignment. Group neighboring facets visually and reserve strong orientation changes for meaningful breaks. Use restrained rock-color variation and lighting to reinforce major volumes. Avoid systematic smoothing that erases all low-poly character.

### D. Lake shapes, banks, and shoreline stones

**Problem to investigate:** two pond prefabs bordered by identical continuous rings of stones.

**Analysis:** repeated sizes and equal spacing expose the placement pattern; a decorative border does not establish believable basin depth or contact.

**Required result:** distinct but related lake shapes, interrupted shoreline treatment, and visible integration with the surrounding ground. The upper lake should read as calm; the lower lake should show localized effects of incoming water rather than being uniformly turbulent.

**Candidate edits:** retain selected rock groups near outlets and meaningful bends, introduce gaps, mix larger anchor rocks with smaller groups, vary orientation and spacing, and use direct grassy or exposed-earth banks elsewhere. Create actual local shore geometry or a controlled visual approximation. Do not remove a fixed percentage of stones mechanically; let the image comparison determine what is excessive.

### E. Lake-water material — highest-priority material task

**Problem to investigate:** water resembles a matte cyan polygon mosaic, painted terrain, opaque plastic, glass, or jelly rather than a liquid surface.

**Analysis:** inspect whether the current appearance is caused by face colors, discontinuous normals, reflection setup, roughness, lighting, depth treatment, or conflicting shader layers. Do not assume that adding a named feature will automatically improve the result.

**Required result:** visually continuous, nonmetallic water with coherent specular/environment response, restrained animated surface variation, a readable but subtle shallow-to-deeper transition, and convincing contact with shore geometry. It should still belong in a low-poly environment without requiring strong triangle-by-triangle color changes.

**Candidate implementation methods:**
- Reduce dominant polygon-color patchwork while preserving only subtle faceting when it contributes to the intended style.
- Establish an appropriate dielectric specular response and angle-dependent reflectivity. Inspect the existing material/BRDF before adding custom Fresnel; avoid counting the same response twice.
- Tune roughness against the actual sun/sky and gameplay camera. Very low roughness is not automatically better: reject chrome-like patches, unstable glitter, and blown-out highlights.
- Use a restrained environment reflection or a deliberately stylized, view-consistent approximation supported by the current renderer. Do not label a flat color blend as actual reflected scene geometry.
- Test broad, low-amplitude moving normal patterns, such as two differently directed layers, without turning the lake into a noisy swimming-pool texture.
- Use plausible shallow/deep coloring from inspected basin geometry, scene depth where suitable, or authored masks/vertex attributes. Keep gradients coherent with basin shape and camera movement.
- Choose opaque, partially transparent, or refractive treatment based on measured visual benefit and cost. Transparency is not a quality goal by itself.
- Provide modest near-shore water/contact variation. Reserve foam for justified contact or agitation; do not draw a bright white outline around the entire lake.

Do not paint a camera-fixed sun/moon reflection into a rotating-camera scene. Do not force a sun highlight into a view where its absence is consistent with the lighting arrangement. Judge response across camera motion, not one still frame.

### F. Waterfalls, outlets, and impact regions

**Problem to investigate:** rigid vertical blue curtains, an abrupt lake-to-sheet transition, or identical shading for horizontal and falling water.

**Analysis:** the falling water needs a distinct directional appearance and believable transitions. Its flow should be understandable without excessive brightness or particles.

**Required result:** the upper lake gathers into an outlet, drops into the lower lake, and produces a localized impact/foam region with disturbance that fades into the surrounding calm water. The lower lake narrows toward a readable island-edge outlet and flows downward off the island.

**Candidate edits:** shape a short outlet and gently turning lip rather than an abrupt disconnected 90-degree rectangle; use a separate downward-moving waterfall material with elongated patterns, controlled breakup, and nonuniform edges; add a small impact foam surface and restrained mist only where helpful. Keep animation directions and relative flow speeds consistent.

Do not add an impact splash at the end of the outer waterfall when no receiving surface exists there. Do not make all water self-illuminating just to imitate a bright concept-image waterfall. Author any fantasy emissive accent intentionally and locally.

### G. Ground, vegetation, and detail density

**Problem to investigate:** uniformly bright yellow-green ground, scattered visual noise, and oversized tree crowns competing with the cottage.

**Analysis:** inspect albedo, exposure, lighting, and color grading separately. Do not compensate for a lighting problem solely by darkening every material.

**Required result:** restrained large-scale ground variation; distinct but subtle treatment near water, exposed edges, and the inhabited area; simple tree crowns; and intentional clusters separated by open space.

**Candidate edits:** reduce excessive saturation only where needed, use broad vertex-color/mask variation rather than high-frequency noise, simplify crown clusters, reduce peripheral visual weight, and remove low-value repeated grass or props. Wet-edge coloring should remain localized rather than becoming a uniform dark border. Avoid rigid numeric reductions in tree size or grass brightness unless comparisons support them.

### H. Cottage integration and material differentiation

**Problem to investigate:** the cottage reads as a standalone asset placed on grass, and materials respond too similarly to light.

**Required result:** a modest inhabited focal area with convincing ground contact and readable differences between rock, grass, wood, roof, and water.

**Candidate edits:** inspect the foundation and contact shadows; create a restrained entrance transition using a few stepping stones, worn ground, or one useful domestic prop. Differentiate roughness and color by material rather than adding texture resolution everywhere. Keep the roof and silhouette simple. Do not replace the cottage with ornate architecture.

### I. Lighting, value hierarchy, and grounding

**Problem to investigate:** the scene is uniformly illuminated, objects feel ungrounded, or low-poly facets are emphasized without revealing large forms.

**Required result:** readable terrain planes, a deliberate brightness hierarchy, believable grounding, and a comfortable focal area. Daylight must remain convincing rather than relying on darkness to hide weaknesses.

**Candidate edits:** test an oblique directional light and balanced environment illumination; distinguish sky contribution, ambient fill, exposure, and material albedo; use supported shadows, baked/contact shading, or AO selectively. AO must not replace cast shadows or create heavy black outlines. Confirm exact feature support for the installed Godot version and renderer instead of inventing property names or enabling an expensive effect by default.

For the optional night look, use cool environmental illumination with a small number of localized warm cottage/lantern accents. Keep playable ground readable, preserve material identity, and avoid globally blue or uniformly emissive water.

### J. Atmosphere, sky, clouds, and post-processing

**Problem to investigate:** the island and sky feel disconnected, or atmosphere and bloom are used to conceal unresolved material issues.

**Required result:** subtle depth separation with an uncluttered sky and a lower cloud layer that supports the floating-island composition. Light-emitting accents should remain selective.

**Candidate edits:** use restrained supported fog or an inexpensive authored atmospheric treatment; organize background clouds rather than increasing their density; tune tone mapping/exposure and only then restrained glow where supported and justified. Avoid volumetric clouds/fog, heavy global bloom, motion blur, or shallow depth of field as default solutions.

A camera-fixed or background-only treatment must be tested with rotation and zoom. Keep cloud overdraw and intersections under control.

## 5. Performance and compatibility contract

Measure before declaring a bottleneck. Inspect triangle counts, draw calls, material passes, shadows, transparency/overdraw, particles, resolution, CPU time, GPU time where available, and frame-time behavior. Do not assume any one of these dominates based on the screenshot.

Reuse assets/materials and batch repeated decoration where it helps. Preserve useful culling granularity when merging meshes or using instancing. Avoid turning the entire environment into one draw call at the expense of update behavior, culling, or maintainability.

Use the documented project hardware/resolution/frame-time budget when one exists. If it does not exist, record the current test hardware and matched before/after performance; use no material frame-time regression beyond observed repeatability as the interim guardrail. Ask before accepting a measured visual-quality/performance trade-off that violates this guardrail. Do not invent an absolute FPS target or claim office-laptop support without testing representative hardware.

Compare the same scene content, camera path, renderer, resolution, quality settings, and measurement method. Warm up runs and distinguish rendering cost from frame caps, synchronization, compilation, or asset-loading stalls. Prefer at least three comparable runs; report median and p95 frame time where reliably measurable. Label unavailable counters and untested hardware honestly.

Do not introduce SSR, continuously updated reflection probes, expensive transparency layers, or large particle systems by default. Treat optional costly effects as experiments requiring a visible benefit and measured cost, not mandatory ingredients.

## 6. Execution loop

1. Inspect project and references; reproduce the current scene; record baseline captures, settings, and performance.
2. Diagnose the dominant visible failures. Make the smallest useful lighting/environment calibration needed to judge materials, then prioritize lake water and waterfall/contact transitions.
3. Iterate with actual renders. Inspect each candidate against the baseline and target visual cues. Preserve improvements and revert changes that worsen coherence, camera robustness, or performance.
4. Refine island massing, banks, ground, vegetation, cottage integration, and composition. Preserve the accepted two-terrace layout throughout.
5. Add restrained atmosphere and optional night-lighting treatment only after the daylight result is credible. A night preset is secondary, not a substitute for fixing the original scene and not a request for a full day/night-cycle system.
6. Validate runtime behavior, representative views, motion, performance, and persistence after reopening/regeneration.
7. Deliver the improved candidate and evidence. Do not stop merely because shaders compile or a checklist says features were added.

Use a concise implementation plan if helpful, but spend the work on the scene rather than elaborate process documents. Continue after an ordinary failed experiment by investigating its cause and testing a defensible alternative. Pause for genuinely blocking access, an incompatible requirement, a material performance trade-off needing approval, or an unresolved artistic choice—not after every reversible parameter adjustment.

## 7. Required evidence and acceptance gates

### Runtime and preservation
- The intended scene opens and runs in the actual Godot project with no new errors attributable to this work.
- Both flat terraces, two lakes, the waterfall sequence, the modest cottage, and the broad base constraints remain intact.
- Camera controls and affected collision/navigation behavior remain functional.
- Changes survive reopening and any relevant procedural regeneration.

### Visual and temporal evidence
- Capture matched before/after images at the original gameplay framing, at least two additional rotated gameplay views, and a supported close view showing shoreline/waterfall contact.
- Keep comparison resolution, camera parameters, and capture conditions documented. Lighting may change as part of the work, but disclose the change rather than presenting mismatched framing or resolution as improvement.
- Include a short runtime capture of water animation and camera movement when capture tools are available. Otherwise provide a precise manual motion-validation step and leave temporal verification explicitly pending.
- Inspect the actual image output. Code inspection or headless import success is not visual verification.
- Demonstrate improvement in water continuity and material response, shoreline integration, waterfall transitions, large rock forms, grounded lighting, and focal hierarchy. Record remaining weaknesses rather than assigning invented numerical beauty scores.
- Check for visible sorting defects, z-fighting, shoreline gaps, texture swimming, unstable shimmer, disconnected waterfalls, or camera-angle-dependent tricks.
- Do not use external image editing or generated replacement imagery as evidence of the game result.

### Performance evidence
- Provide matched baseline/final measurements and exact test conditions.
- Satisfy the existing project budget, or the interim no-material-regression guardrail described above.
- Separate verified current-host performance from unverified target-laptop performance.

### Scope review
For every area A–J, provide one compact row: observed problem → confirmed/hypothesized cause → change or reason for no change → evidence → remaining issue/cost. Do not force changes into an area that inspection shows is already satisfactory.

## 8. Deliverables and honest stopping policy

Deliver the modified project resources, the exact scene/commands needed to reproduce the result, a small before/after evidence set, relevant motion evidence, a performance comparison, and a concise change/limitation summary. Reuse the repository's existing documentation convention; do not build a new reporting framework.

Use an honest outcome:

- **READY FOR ART REVIEW:** the review-ready candidate meets the applicable implementation, visual-evidence, and performance gates. The user's final aesthetic approval remains separate.
- **BLOCKED / NEEDS INPUT:** identify the exact missing access, reference, renderer capability, approval, or validation step, what has already been completed, and the smallest input needed to continue. Do not describe blocked evidence as passed.

Do not stop at the first compilable shader. Do not continue indefinitely making cosmetic variations after the agreed candidate and evidence are ready. When additional changes require the user's taste judgment, show the alternatives and pause instead of silently changing the art direction.
