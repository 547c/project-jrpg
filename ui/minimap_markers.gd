extends Control

# 미니맵 위에 얹는 점 표시 전용 레이어. ViewportContainer/DarknessMask보다 나중에 그려져야 하므로
# (부모 자신의 _draw()는 자식보다 먼저 그려져 가려진다) 별도 자식 노드로 분리했다.
# 시야 제한 씬에서도(DarknessMask가 지형을 덮어도) 이 레이어는 그대로 그려져 "위치는 안다"는
# 느낌을 준다.

const ENEMY_COLOR := Color(0.85, 0.15, 0.15, 1)
const NPC_COLOR := Color(0.3, 0.55, 0.95, 1)
const PLAYER_COLOR := Color(0.96, 0.85, 0.35, 1)
const OUTLINE_COLOR := Color(0.1, 0.05, 0.05, 0.9)
const MARKER_RADIUS := 4.0
const OUTLINE_RADIUS := 5.5
const ENEMY_BLINK_SPEED := 4.0
const ENEMY_BLINK_MIN_ALPHA := 0.25

var camera: Camera2D
var zoom: float = 1.0

var _blink_time := 0.0


func _process(delta: float) -> void:
	_blink_time += delta
	queue_redraw()


func _draw() -> void:
	if camera == null:
		return
	var view_center: Vector2 = camera.get_screen_center_position()
	var half_extent: Vector2 = size / 2.0
	var blink_alpha := lerpf(ENEMY_BLINK_MIN_ALPHA, 1.0, (sin(_blink_time * ENEMY_BLINK_SPEED) + 1.0) / 2.0)

	for node in get_tree().get_nodes_in_group("monster_encounters"):
		var enemy := node as MonsterEncounter
		if enemy != null and enemy.is_active_in_world():
			_draw_marker(enemy.global_position, view_center, half_extent, ENEMY_COLOR, blink_alpha)

	for node in get_tree().get_nodes_in_group("npcs"):
		_draw_marker((node as Node2D).global_position, view_center, half_extent, NPC_COLOR, 1.0)

	if SceneManager.has_player():
		_draw_marker(SceneManager.get_player_position(), view_center, half_extent, PLAYER_COLOR, 1.0)


func _draw_marker(world_pos: Vector2, view_center: Vector2, half_extent: Vector2, color: Color, alpha: float) -> void:
	var offset := (world_pos - view_center) * zoom
	if absf(offset.x) > half_extent.x or absf(offset.y) > half_extent.y:
		return
	var pos: Vector2 = half_extent + offset
	draw_circle(pos, OUTLINE_RADIUS, Color(OUTLINE_COLOR.r, OUTLINE_COLOR.g, OUTLINE_COLOR.b, OUTLINE_COLOR.a * alpha))
	draw_circle(pos, MARKER_RADIUS, Color(color.r, color.g, color.b, color.a * alpha))
