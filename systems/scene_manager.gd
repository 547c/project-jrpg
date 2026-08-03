extends Node

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const CUTSCENE_BOX_SCENE: PackedScene = preload("res://ui/cutscene_box.tscn")
const VILLAGE_SCENE_PATH := "res://world/village.tscn"
const TITLE_SCREEN_PATH := "res://ui/title_screen.tscn"
const BATTLE_SCENE_PATH := "res://battle/battle_scene.tscn"

# 씬 경로별로 GameState에 기록할 방문 플래그를 매핑
const VISITED_FLAGS: Dictionary = {
	"res://world/village.tscn": "visited_village",
	"res://world/forest.tscn": "visited_forest",
	"res://world/cave.tscn": "visited_cave",
}

var _player: Node2D
var _is_changing_scene: bool = false
var _transitions_suppressed: bool = false

# 전투 진입 시 저장해두는 복귀 컨텍스트 (승리 시 이 좌표/씬으로 정확히 되돌아간다)
var _battle_return_path: String = ""
var _battle_return_position: Vector2 = Vector2.ZERO
var _battle_monster_type: String = ""
var _battle_encounter_id: String = ""
# 전투 승리 후 복귀할 때, 방금 쓰러뜨린 몬스터를 리젠 상태로 돌려놓기 위한 대기 ID
var _pending_defeated_encounter_id: String = ""


# 씬 전환 직후에는 트리거를 무시해야 하는지 여부 (area_transition이 조회).
# monitoring을 잠시 꺼도 물리 서버가 이미 큐에 넣어둔 오래된 body_entered가 재활성화 시점에
# 뒤늦게 발행되어 엉뚱한 전환을 일으킬 수 있어, 콜백 단에서 한 번 더 방어한다
func is_transition_suppressed() -> bool:
	return _transitions_suppressed


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
# (village.tscn 등 월드 씬을 건드리지 않기 위함).
# 컷신이 나타날 때/사라질 때 모두 페이드로 감싸서 툭 끊기지 않게 한다
func _play_opening() -> void:
	GameState.set_flag("seen_opening", true)

	var cutscene_layer := CanvasLayer.new()
	add_child(cutscene_layer)
	var cutscene_box := CUTSCENE_BOX_SCENE.instantiate() as CutsceneBox
	cutscene_layer.add_child(cutscene_box)

	await FadeOverlay.fade_out()
	cutscene_box.start_cutscene(DialogueData.OPENING_DIALOGUE, "opening_1")
	await FadeOverlay.fade_in()

	await cutscene_box.cutscene_ended

	await FadeOverlay.fade_out()
	cutscene_layer.queue_free()
	await FadeOverlay.fade_in()


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


# 배경 씬 교체 요청을 받아, 물리 콜백(쿼리 플러시)이 끝난 뒤 안전하게 처리하도록 지연시킴.
# 이름 있는 스폰 지점으로 플레이어를 이동한다 (일반적인 구역 이동용)
func change_scene(scene_path: String, spawn_point_name: String) -> void:
	if _is_changing_scene:
		return
	_is_changing_scene = true
	_apply_scene_change.call_deferred(scene_path, spawn_point_name, false, Vector2.ZERO)


# 이름 있는 스폰 지점 대신 정확한 좌표로 플레이어를 배치하며 씬을 전환 (세이브 로드용)
func change_scene_to_position(scene_path: String, position: Vector2) -> void:
	if _is_changing_scene:
		return
	_is_changing_scene = true
	_apply_scene_change.call_deferred(scene_path, "", true, position)


# 몬스터 조우 시 호출. 현재 씬/좌표를 복귀 컨텍스트로 저장하고, 전용 전투 씬으로 전환한다.
# 물리 콜백 밖에서 안전하게 처리하도록 지연시킴 (change_scene과 동일한 방어)
func enter_battle(monster_type: String, encounter_id: String, return_path: String, return_position: Vector2) -> void:
	if _is_changing_scene:
		return
	_is_changing_scene = true
	_battle_monster_type = monster_type
	_battle_encounter_id = encounter_id
	_battle_return_path = return_path
	_battle_return_position = return_position
	_apply_battle_enter.call_deferred()


# 실제 전투 씬 진입: 페이드로 감싸고, 오버월드 플레이어 노드는 숨겨 전투 씬 위에 겹쳐 보이지 않게 한다.
# 전투 씬은 자체 스프라이트로 플레이어/몬스터를 그린다
func _apply_battle_enter() -> void:
	await FadeOverlay.fade_out()

	if _player != null:
		_player.visible = false

	var old_scene := get_tree().current_scene
	if old_scene != null:
		get_tree().root.remove_child(old_scene)
		old_scene.queue_free()

	var battle_ps := load(BATTLE_SCENE_PATH) as PackedScene
	var battle := battle_ps.instantiate() as BattleScene
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	battle.start_with(_battle_monster_type)

	await FadeOverlay.fade_in()

	_is_changing_scene = false


# 전투 승리 후 전투 씬이 호출. 방금 쓰러뜨린 몬스터를 리젠 대기로 표시하고, 숨겼던 플레이어를 다시 보이게 한 뒤
# 저장해둔 정확한 좌표로 원래 씬에 복귀한다 (기존 좌표 복귀 로직 재사용)
func return_from_battle() -> void:
	_pending_defeated_encounter_id = _battle_encounter_id
	_return_to_overworld()


# 도망가기 성공 시 전투 씬이 호출. 처치 처리는 하지 않는다(퀘스트/카운트 변화 없음).
# 씬이 통째로 다시 로드되므로 몬스터는 새 인스턴스의 기본(트리거 전) 상태로 자연히 그 자리에 남는다
func flee_battle() -> void:
	_return_to_overworld()


# 숨겼던 플레이어를 다시 표시하고, 저장해둔 정확한 좌표로 원래 씬에 복귀 (승리/도망 공용)
func _return_to_overworld() -> void:
	reveal_player()
	change_scene_to_position(_battle_return_path, _battle_return_position)


# 전투 진입 시 숨겼던 오버월드 플레이어 노드를 다시 표시 (승리 복귀/패배 게임오버 양쪽에서 사용)
func reveal_player() -> void:
	if _player != null:
		_player.visible = true


# 복귀한 씬에서 encounter_id가 일치하는 몬스터 조우를 찾아 리젠 상태로 전환 (즉시 재조우 방지)
func _mark_defeated_encounter(encounter_id: String) -> void:
	if encounter_id == "":
		return
	for node in get_tree().get_nodes_in_group("monster_encounters"):
		var enc := node as MonsterEncounter
		if enc != null and enc.encounter_id == encounter_id:
			enc.enter_regen_state()
			return


# 실제 배경 씬 교체와 플레이어 이동을 수행 (call_deferred로 호출되어 물리 콜백 밖에서 실행됨).
# use_exact_position이 true면 exact_position 좌표로, 아니면 spawn_point_name 스폰 지점으로 이동.
# 화면이 완전히 까매진 상태에서 실제 전환이 일어나도록 페이드 아웃/인으로 감싼다
# (change_scene()/change_scene_to_position()을 거치는 모든 전환 — 엔딩, 게임오버 복귀/로드 포함 — 에 자동 적용됨)
func _apply_scene_change(scene_path: String, spawn_point_name: String, use_exact_position: bool, exact_position: Vector2) -> void:
	_transitions_suppressed = true

	await FadeOverlay.fade_out()

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

	# 전투 승리 후 복귀라면, 방금 쓰러뜨린 몬스터를 리젠 상태로 두어 플레이어가 그 자리에 복귀해도 즉시 재조우되지 않게 함
	if _pending_defeated_encounter_id != "":
		_mark_defeated_encounter(_pending_defeated_encounter_id)
		_pending_defeated_encounter_id = ""

	# 새로 추가된 트리거가 물리 서버에 아직 반영되지 않은(오래된) 플레이어 위치로 겹침 판정을 하는 것을 막기 위해 잠시 꺼둠
	var new_triggers := get_tree().get_nodes_in_group("area_transitions")
	for trigger in new_triggers:
		(trigger as Area2D).monitoring = false

	if use_exact_position:
		_player.global_position = exact_position
	else:
		_move_player_to(spawn_point_name)

	await get_tree().physics_frame

	for trigger in new_triggers:
		(trigger as Area2D).monitoring = true

	# monitoring 재활성화 직후 물리 서버가 뒤늦게 발행하는 오래된 body_entered를 한 프레임 더 흘려보낸 뒤
	# 억제를 해제한다 (그 사이 발행된 전환은 area_transition이 is_transition_suppressed()로 무시함)
	await get_tree().physics_frame

	_transitions_suppressed = false

	await FadeOverlay.fade_in()

	_is_changing_scene = false


# 플레이어가 아직 없으면(타이틀 화면 등에서 로드하는 경우) 생성한다
func ensure_player_exists() -> void:
	if _player == null:
		_player = PLAYER_SCENE.instantiate() as Node2D
		_player.z_index = 10
		add_child(_player)


# 플레이어가 현재 존재하는지 (게임 진행 중인지) 여부
func has_player() -> bool:
	return _player != null


# 플레이어의 현재 월드 좌표 (없으면 원점)
func get_player_position() -> Vector2:
	return _player.global_position if _player != null else Vector2.ZERO


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
