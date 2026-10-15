# Shore-stone seating correction

2026-10-15. Latest user: shoreline rocks look floating and separate from the ground. Baseline `618c9e9` / `reflection3_*`; candidate `shore1_*`. Eleven actual Godot captures, eight principal matched views inspected.

The lowest dry-bank source vertices were already below land, so this was not universal whole-object hovering. Their pinched lower flanks still emerged too high, producing separated-looking dark undersides. Some fully wet small stones used a fixed water-level offset and did not touch the actual mineral bed.

The new helper samples the retained source mesh after its existing yaw/tilt/scale. Its lower-third section is seated 3.5 cm into actual grass/shore support on its landward side; water-facing overhangs stay attached to that rooted body. Fully wet accents use the actual mesh underside at their center and actual bed triangles, with 2.5 cm burial. Unsupported stones are omitted rather than suspended, though all existing checked fixture counts remain unchanged. Support comes from the authoritative indexed triangles; no new ground or contact-outline geometry is drawn.

Only Y translation changes. Model bytes, mesh topology, tilt/scale, XZ distribution, island/pond authoring data, trees/buildings, material shaders and water optics remain. The bank retains uneven rock heights. Captures show reduced pinched dark foot bands and better contact, not final concept-level naturalness: simple rock shapes and hard material contact remain visible.

The new regression checks real lower-third triangle-edge sections against actual bank triangles and wet mesh bottoms against the actual bed. It fails the old path with 901 raised-flank/unrooted **sample** failures (not 901 stones), then passes 4,445 probes across default/dry/raise/contract with zero failures. Counts remain93/78/94/79. Existing shoreline-prop cleanup and supported-bank transition checks pass; actual rendered decoration regeneration42/42 passes. See [full evidence](checks.json). No broad full-suite or target-device performance claim.

Independent read-only art/code review recommends retaining shore1: reduced pinched-foot separation, no obvious overburied slabs or new continuous ring, and no actionable correctness defect found. It confirms final triangle indexing precedes placement. It did not rerun tests; morph-animation contact, every editable layout and regeneration CPU cost remain unverified. Dark facet contrast and chunky source shapes remain visible. Fresh editor339/339 also passes.
