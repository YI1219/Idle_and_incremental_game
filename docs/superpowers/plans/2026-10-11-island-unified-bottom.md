# Floating island unified bottom and join lookdev

**Goal / spec:** The owner's 2026-10-11 goal: side stones ease into one calm unified bottom; improve rim, turf joins, pond shores and stone feel toward the supplied concept, keeping the overall footprint and pond layout.
**Architecture:** Retain authored terrain, merged crowns and separate roots. Stop breaking the closed bottom into individual protruding mantle blocks. Render its continuous surface with broad shallow relief, then visually tune the side-to-bottom transition, crown contact and supported shore surfaces.
**Execution:** Inline in the existing requested checkout/branch, continuing f39052c without reset. The request and active goal supply the visual direction and permission to iterate; no further design approval is required.
**Constraints:** No new custom asset pipeline, footprint/pond edits, character work, or claim of target-device performance. Keep authoritative terrain editing, regeneration, undo/save and existing scene assets.

## Review focus
- Bottom continuity at concave contours and between terraces; no central keel or overlapping plate interiors.
- Local expansion, contraction and deeply lowered terrain must remain closed and not move distant geometry.
- Rim and turf contact from low oblique angles; no cap holes or floating moss.
- Pond-bank details must meet dry terrain and visible water without detached ribbons.
- Materials must remain coherent from default view through close-up and orbit, under existing lighting.

## Tasks
- [x] Preserve baseline images and geometry hashes. Add a regression sampling the lower interior for a single calm continuous surface, show it fails against the slabbed baseline, and replace the blocky cap while retaining side stones.
- [x] Render five fixed views and orbit. Iterate bottom blending, rim/turf/shore contact and stone shading. Retain only defensible visual gains; record two distinct further studies if improvement plateaus.
- [x] Run fresh terrain suites and rendered regeneration; compare protected geometry hashes and inspect final captures. Fresh review, resolve actionable findings, update CURRENT_CONTEXT and review gallery, commit and push reversible work.
