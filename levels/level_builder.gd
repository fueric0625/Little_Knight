extends Node2D

const LAYOUT_PATH := "res://levels/test_layout.txt"
const TILE_PATH := "res://art/map/tile_brick.png"
const CELL_SIZE := 128.0


func _ready() -> void:
	var texture := load(TILE_PATH) as Texture2D
	var cell := Vector2(CELL_SIZE, CELL_SIZE)
	var rows := _read_rows()
	if rows.is_empty():
		return
	_build_tiles(texture, cell, rows)
	_place_player(cell, rows)


func _read_rows() -> PackedStringArray:
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取关卡布局: %s" % LAYOUT_PATH)
		return PackedStringArray()
	var rows := PackedStringArray()
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty() or line.begins_with(";"):
			continue
		rows.append(line)
	if rows.is_empty():
		push_error("关卡布局是空的: %s" % LAYOUT_PATH)
		return rows
	var width := rows[0].length()
	for line in rows:
		if line.length() != width:
			push_error("关卡每一行的长度必须相同。期望 %d，实际 %d。" % [width, line.length()])
			return PackedStringArray()
	return rows


func _build_tiles(texture: Texture2D, cell: Vector2, rows: PackedStringArray) -> void:
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	add_child(tiles)
	var shape := RectangleShape2D.new()
	shape.size = cell
	for y in rows.size():
		var line := rows[y]
		for x in line.length():
			if line[x] != "#":
				continue
			var body := StaticBody2D.new()
			body.position = Vector2((x + 0.5) * cell.x, (y + 0.5) * cell.y)
			var tile_sprite := Sprite2D.new()
			tile_sprite.texture = texture
			var tex_size := texture.get_size()
			tile_sprite.scale = Vector2(cell.x / tex_size.x, cell.y / tex_size.y)
			body.add_child(tile_sprite)
			var tile_collision := CollisionShape2D.new()
			tile_collision.shape = shape
			body.add_child(tile_collision)
			tiles.add_child(body)


func _place_player(cell: Vector2, rows: PackedStringArray) -> void:
	var spawn := Vector2i(1, 1)
	var found := false
	for y in rows.size():
		var x := rows[y].find("P")
		if x >= 0:
			spawn = Vector2i(x, y)
			found = true
			break
	if not found:
		push_error("关卡布局里没有出生点 P。")
	var player := get_node("Player") as Player
	var shape := (player.get_node("Collision") as CollisionShape2D).shape as RectangleShape2D
	var feet_y := float(spawn.y + 1) * cell.y
	# 脚底比地面高 1 像素，第一帧落下后贴住平台。
	var pos := Vector2((spawn.x + 0.5) * cell.x, feet_y - shape.size.y * 0.5 - 1.0)
	player.configure_spawn(pos, float(rows.size()) * cell.y + 64.0)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(rows[0].length() * cell.x)
	camera.limit_bottom = int(rows.size() * cell.y)
