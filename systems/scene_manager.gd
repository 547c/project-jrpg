extends Node

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

# 씬 경로별로 GameState에 기록할 방문 플래그를 매핑
const VISITED_FLAGS: Dictionary = {
	"res://world/village.tscn": "visited_village",
	"res://world/forest.tscn": "visited_forest",
	"res://world/cave.tscn": "visited_cave",
}

var _player: Node2D
var _is_changing_scene: bool = false


# 게임 시작 시 플레이어를 한 번만 생성해 SceneManager의 자식으로 유지 (씬 전환에도 삭제되지 않음)
func _ready() -> void:
	_player = PLAYER_SCENE.instantiate() as Node2D
	_player.z_index = 10 # SceneManager가 오토로드라 배경 씬보다 먼저 그려지므로, 배경 위에 보이도록 z_index를 높임
	add_child(_player)
	await get_tree().process_frame
	_place_initial_player()


# 메인 씬이 트리에 들어온 뒤, 현재 씬의 첫 스폰 지점으로 플레이어를 이동하고 방문 플래그를 기록
func _place_initial_player() -> void:
	var current := get_tree().current_scene
	if current != null:
		_record_visited(current.scene_file_path)

	var spawn_points := get_tree().get_nodes_in_group("spawn_points")
	if spawn_points.is_empty():
		return

	var first_spawn := spawn_points[0] as SpawnPoint
	_move_player_to(first_spawn.spawn_point_name)


# 배경 씬 교체 요청을 받아, 물리 콜백(쿼리 플러시)이 끝난 뒤 안전하게 처리하도록 지연시킴
func change_scene(scene_path: String, spawn_point_name: String) -> void:
	if _is_changing_scene:
		return
	_is_changing_scene = true
	_apply_scene_change.call_deferred(scene_path, spawn_point_name)


# 실제 배경 씬 교체와 플레이어 이동을 수행 (call_deferred로 호출되어 물리 콜백 밖에서 실행됨)
func _apply_scene_change(scene_path: String, spawn_point_name: String) -> void:
	var old_scene := get_tree().current_scene
	if old_scene != null:
		get_tree().root.remove_child(old_scene)
		old_scene.queue_free()

	var next_scene := load(scene_path) as PackedScene
	var new_scene := next_scene.instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	# 전환한 구역의 방문 여부를 GameState에 기록
	_record_visited(scene_path)

	# 새로 추가된 트리거가 물리 서버에 아직 반영되지 않은(오래된) 플레이어 위치로 겹침 판정을 하는 것을 막기 위해 잠시 꺼둠
	var new_triggers := get_tree().get_nodes_in_group("area_transitions")
	for trigger in new_triggers:
		(trigger as Area2D).monitoring = false

	_move_player_to(spawn_point_name)

	await get_tree().physics_frame

	for trigger in new_triggers:
		(trigger as Area2D).monitoring = true

	_is_changing_scene = false


# 이름이 일치하는 스폰 지점을 찾아 (재생성 없이) 기존 플레이어의 위치만 이동
func _move_player_to(spawn_point_name: String) -> void:
	var spawn := _find_spawn_point(spawn_point_name)
	if spawn == null:
		push_warning("SceneManager: spawn point '%s' not found" % spawn_point_name)
		return

	_player.global_position = spawn.global_position


# 씬 경로에 대응하는 방문 플래그가 있으면 GameState에 true로 기록
func _record_visited(scene_path: String) -> void:
	if VISITED_FLAGS.has(scene_path):
		GameState.set_flag(VISITED_FLAGS[scene_path], true)


# "spawn_points" 그룹에서 이름이 일치하는 SpawnPoint를 탐색
func _find_spawn_point(spawn_point_name: String) -> SpawnPoint:
	for point in get_tree().get_nodes_in_group("spawn_points"):
		var sp := point as SpawnPoint
		if sp != null and sp.spawn_point_name == spawn_point_name:
			return sp
	return null
