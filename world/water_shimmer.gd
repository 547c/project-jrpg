extends Node


func _ready() -> void:
	if not GraphicsToggles.water_shimmer_enabled:
		return

	var tilemap := _find_tilemap()
	if tilemap == null:
		return

	var water_source_id := _find_water_source_id(tilemap.tile_set)
	if water_source_id == -1:
		return

	var source := tilemap.tile_set.get_source(water_source_id) as TileSetAtlasSource
	var image := source.texture.get_image()

	var water_layer := TileMapLayer.new()
	water_layer.name = "WaterShimmerLayer"
	water_layer.tile_set = tilemap.tile_set
	water_layer.position = tilemap.position
	water_layer.z_index = -1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/water_shimmer.gdshader")
	water_layer.material = mat

	var classified := {}
	var moved_any := false
	for layer in range(tilemap.get_layers_count()):
		for cell in tilemap.get_used_cells(layer):
			if tilemap.get_cell_source_id(layer, cell) != water_source_id:
				continue
			var coords := tilemap.get_cell_atlas_coords(layer, cell)
			if not classified.has(coords):
				classified[coords] = _is_water_tile(image, source, coords)
			if classified[coords]:
				water_layer.set_cell(cell, water_source_id, coords)
				tilemap.set_cell(layer, cell, -1)
				moved_any = true

	if moved_any:
		tilemap.get_parent().add_child.call_deferred(water_layer)
	else:
		water_layer.free()


func _find_tilemap() -> TileMap:
	for sibling in get_parent().get_children():
		if sibling is TileMap:
			return sibling
	return null


func _find_water_source_id(tile_set: TileSet) -> int:
	for i in range(tile_set.get_source_count()):
		var source_id := tile_set.get_source_id(i)
		var source := tile_set.get_source(source_id)
		if source is TileSetAtlasSource and source.texture and "Water_tiles" in source.texture.resource_path:
			return source_id
	return -1


func _is_water_tile(image: Image, source: TileSetAtlasSource, coords: Vector2i) -> bool:
	var region := source.get_tile_texture_region(coords)
	var total_r := 0.0
	var total_g := 0.0
	var total_b := 0.0
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.05:
				continue
			total_r += pixel.r
			total_g += pixel.g
			total_b += pixel.b
			count += 1
	if count == 0:
		return false
	var avg_r := total_r / count
	var avg_g := total_g / count
	var avg_b := total_b / count
	return avg_b > avg_g * 1.15 and avg_b > avg_r * 1.05
