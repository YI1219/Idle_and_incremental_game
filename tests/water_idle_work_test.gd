extends "res://tests/water_renderer_test.gd"
## Recreating identical GPU resources during idle is a performance regression.
func run() -> void:
	water_script = load("res://scripts/terrain_editor/water_renderer.gd")
	var data: Data = closed_pair()
	data.cells[Vector2i.RIGHT].water=2
	var pair: Array[Node3D]=make_pair(data)
	var water: Node3D=pair[1]
	var mesh: Mesh=water.get_node("water").mesh
	var revision: int=water.publication_revision
	var pixels: PackedByteArray=water.live_field_image.get_data()
	for i: int in 5:
		water.tick(.1); water.flush()
	check(water.get_node("water").mesh==mesh,"unchanged closed pool reuses its GPU mesh")
	check(water.publication_revision==revision,"unchanged physical state avoids redundant publication")
	check(water.live_field_image.get_data()==pixels,"reusing a stationary pool preserves every field pixel")
	check(close(water.simulated_seconds,.5) and close(water.published_volume,2.0),"idle optimization preserves simulation clock and mass")
	data.cells[Vector2i.RIGHT].height=-1.0; water.sync(); water.tick(.1); water.flush()
	check(water.publication_revision>revision and water.get_node("water").mesh!=mesh,"bed edits invalidate cached water even after a stationary interval")
	check(close(water.published_volume+water.published_discharged_volume,2.0),"waking a stationary pool preserves conserved mass")
	pair[0].free()
	var dry: Data=Data.new();dry.make_preset(2)
	pair=make_pair(dry);water=pair[1];revision=water.publication_revision
	for i: int in 5: water.tick(.1);water.flush()
	check(water.publication_revision==revision and water.published_volume==0,"dry island avoids mesh and texture churn")
	pair[0].free()
	var recovery: RefCounted=load("res://scripts/terrain_editor/grass_recovery.gd").new()
	recovery.sync({Vector2i.ZERO:{"height":1.5}}, {})
	var image: Image=recovery.image
	recovery.sync({Vector2i.ZERO:{"height":1.5}}, {Vector2i.ZERO:.25}, {Vector2i.ZERO:1.75})
	check(recovery.image==image,"water-level updates reuse the unchanged grass fringe layout")
	check(recovery.image.get_pixel(1,1).b==1.75,"reused grass layout receives the latest water height")
	recovery.sync({Vector2i.RIGHT:{"height":3.5}}, {})
	check(recovery.rect.position==Vector2(0,-1) and recovery.image.get_pixel(1,1).g==3.5,"moving or raising terrain rebuilds grass fringe ownership")
	print("WATER IDLE ",checks," checks, ",failures," failures"); quit(1 if failures else 0)
