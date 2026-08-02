extends Node

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const CUTSCENE_BOX_SCENE: PackedScene = preload("res://ui/cutscene_box.tscn")
const VILLAGE_SCENE_PATH := "res://world/village.tscn"
const TITLE_SCREEN_PATH := "res://ui/title_screen.tscn"

# 씬 경로별로 GameState에 기록할 방문 플래그를 매핑
const VISITED_FLAGS: Dictionary = {
	"res://world/village.tscn": "visited_village",
	"res://world/forest.tscn": "visited_forest",
	"res://world/cave.tscn": "visited_cave",
}

var _player: Node2D
var _is_changing_scene: bool = false


# 타이틀 화면의 PLAY 버튼에서 호출. 플레이어를 생성하고 타이틀 화면을 마을 씬으로 교체한 뒤,
# (처음이라면) 오프닝 컷신을 재생하고 최초 스폰 지점으로 플레이어를 배치한다
func start_game() -> void:
	_player = PLAYER_SCENE.instantiate() as Node2D
	_player.z_index = 10 # SceneManager가 오토로드라 배경 씬보다 먼저 그려지므로, 배경 위에 보이도록 z_index를 높임
	add_child(_player)

	var old_scene := get_tree().current_scene
	if old_scene != null:
		get_tree().root.remove_child(old_scene)
		old_scene.queue_free()

	var village_scene := load(VILLAGE_SCENE_PATH) as PackedScene
	var new_scene := village_scene.instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	await get_tree().process_frame

	if not GameState.get_flag("seen_opening"):
		await _play_opening()

	_place_initial_player()


# 엔딩 화면 등에서 타이틀로 돌아갈 때 호출. 플레이어를 정리하고 타이틀 씬으로 교체한다
# (다음 start_game() 호출 시 플레이어를 새로 만들 수 있도록)
func return_to_title() -> void:
	if _player != null:
		_player.queue_free()
		_player = null

	var old_scene := get_tree().current_scene
	if old_scene != null:
		get_tree().root.remove_child(old_scene)
		old_scene.queue_free()

	var title_scene := load(TITLE_SCREEN_PATH) as PackedScene
	var new_scene := title_scene.instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene


# 오프닝 인트로를 (딱 한 번) 전용 CutsceneBox로 화면 전체에 재생하고, 끝날 때까지 기다림.
# 특정 월드 씬에 속하지 않도록 CanvasLayer와 함께 직접 생성했다가 끝나면 정리한다
# (village.tscn 등 월드 씬을 건드리지 않기 위함)
func _play_opening() -> void:
	GameState.set_flag("seen_opening", true)

	var cutscene_layer := CanvasLayer.new()
	add_child(cutscene_layer)
	var cutscene_box := CUTSCENE_BOX_SCENE.instantiate() as CutsceneBox
	cutscene_layer.add_child(cutscene_box)

	cutscene_box.start_cutscene(DialogueData.OPENING_DIALOGUE, "opening_1")
	await cutscene_box.cutscene_ended

	cutscene_layer.queue_free()


# 메인 씬이 트리에 들어온 뒤, 현재 씬의 "최초 스폰" 지점으로 플레이어를 이동하고 방문 플래그를 기록
func _place_initial_player() -> void:
	var current := get_tree().current_scene
	if current != null:
		_record_visited(current.scene_file_path)

	var initial_spawn := _find_initial_spawn_point()
	if initial_spawn == null:
		push_warning("SceneManager: is_initial_spawn=true인 스폰 지점을 찾지 못했습니다")
		return

	_move_player_to(initial_spawn.spawn_point_name)


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


# "spawn_points" 그룹에서 is_initial_spawn=true로 표시된 스폰 지점을 탐색 (트리 순서에 의존하지 않음)
func _find_initial_spawn_point() -> SpawnPoint:
	for point in get_tree().get_nodes_in_group("spawn_points"):
		var sp := point as SpawnPoint
		if sp != null and sp.is_initial_spawn:
			return sp
	return null
