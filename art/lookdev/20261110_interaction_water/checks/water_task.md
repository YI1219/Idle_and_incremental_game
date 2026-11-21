# 连续守恒水量任务

Read CURRENT_CONTEXT.md and AGENTS.md first. Work only on scripts/terrain_editor/water_flow.gd and tests/water_flow_test.gd. Other people edit the workspace. Do not revert others, touch terrain_data/renderer/editor/shaders, spawn agents or commit. Implement typed GDScript on installed Godot4.7.2.

User requirements are natural conservation, no water sources or spontaneous increase, redistribution to level connected pools, donor decreases and receiver increases, discharge off island reduces total. Bed elevations come from TerrainData.cells[cell].height, area=1. Preserve old integer record.water as the authored flag/initial surface (height=water*.5), allow an optional record.water_volume value overriding initial depth. Never simulate by half-metre water-level quantization.

Create RefCounted water_flow.gd with public interfaces
- configure(data) resets to that data's volumes and sets discharged_volume=0.
- sync(data) reconciles authoring edits to the same data. Existing unchanged cells keep their volume, raised/lowered bed displaces existing water (no creation), deleted cells discharge their water; added dry cells start empty. Explicit water/dry authoring changes reset only those affected cells using optional water_volume or authored water plane.
- step(delta:float) advances finite nonnegative delta with bounded stable time steps. Data itself is not modified. No arbitrary volume deletion for small positive depths.
- depths:Dictionary of Vector2i→positive float volumes/depths, heights:Dictionary Vector2i→absolute surface height (read only consumers), discharged_volume:float.
- basins:Array[Dictionary] with {id:int,cells:Dictionary,height:float,volume:float}; contiguous equal/near-equal surface cells can flatten to one volume-derived level. Incoming transfers propagate to existing basins. Cells below a flat level share that exact level, use bed heights to remove dry members as volume falls. Do not merge waterfalls between substantially different surface elevations prematurely.
- last_transfers:Array[Dictionary] with {from:Vector2i,to:Variant(Vector2i or null for void),rate:float,source_height:float,target_height:float}. Enough for visual flow intensity. Step output/update APIs can be minimally extended, report exact interfaces.
- total_volume()->float.

For flux, use positive head above max(source bed, target bed, downstream surface) and conservative simultaneous per-cell donor scaling. Typical coefficient around .45 for head^1.5 at metre scale, stable fixed substeps. Physical wet connectivity may use small surface tolerance then level pools. Caller ticks around 10Hz and handles separate water rendering. Keep model deterministic and no global shader/server state.

Tests must reproduce failures before implementation where feasible, exercise initial static records and optional volumes, closed unequal connected pool reaching a flat surface, bounded donor→receiver transfer, unchanged total in closed domain, total+discharged preserved in open domain, dry island never creates water, high beds block flow, topology sync, finite values. Record commands/results and any limitations in checks/water_task_report.md. Do not overbuild hydrodynamics unrelated to these outcomes. Parent owns integration and visual validation.
