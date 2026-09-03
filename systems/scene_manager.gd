extends Node

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const CUTSCENE_BOX_SCENE: PackedScene = preload("res://ui/cutscene_box.tscn")
const CHAPTER_TITLE_CARD_SCENE: PackedScene = preload("res://ui/chapter_title_card.tscn")
const VILLAGE_SCENE_PATH := "res://world/village.tscn"
const TITLE_SCREEN_PATH := "res://ui/title_screen.tscn"
const BATTLE_SCENE_PATH := "res://battle/battle_scene.tscn"

# Y-Sort를 쓰지 않는 씬에서 플레이어에게 주는 z_index. SceneManager는 오토로드라 배경 씬보다
# 먼저 그려지므로, 그냥 두면 배경에 가려진다
const PLAYER_OVERLAY_Z_INDEX := 10

# Y-Sort 씬에서 "서로 앞뒤를 가려야 하는 것들"(플레이어/NPC/나무)이 함께 서는 z_index.
# z_index가 y좌표보다 먼저 비교되므로, 이들이 서로 정렬되려면 값이 같아야 한다.
# 0이 아니라 5인 이유: 타일맵 데코 레이어가 z_index 1~4를 쓰고 있어서, 0으로 두면 바닥에 깔린
# 돌·풀 타일이 캐릭터와 나무를 덮어버린다 (예전엔 플레이어가 z 10이라 항상 그 위였다)
#
# 새 맵 오브젝트(건물/바위 등)를 Y-Sort에 참여시킬 때도 이 상수를 그대로 쓸 것 — 규칙과 배경은
# docs/map_objects.md, 적용 사례는 world/tree_prop.gd 참고
const CHARACTER_BAND_Z_INDEX := 5

# 그림자 전용 레이어(world/shadow_layer.gd)의 z_index. 캐릭터 밴드보다 1 낮게 고정해서, y좌표와
# 무관하게 그림자는 항상 캐릭터/나무 스프라이트보다 아래·데코 타일보다는 위에 깔리게 한다
# (Godot는 y-sort보다 z_index를 먼저 비교하므로, 이 값 하나로 순서가 고정된다).
# 그림자는 여러 개가 겹쳐도 균일한 밝기를 유지해야 해서 y-sort로 개별 정렬할 필요가 없다 —
# "땅 위에 평평하게 깔린 것"이라 서로 앞뒤를 다툴 이유가 없다는 뜻이기도 하다
const SHADOW_LAYER_Z_INDEX := CHARACTER_BAND_Z_INDEX - 1

# 파트 1 타이틀 카드 문구 (오프닝 컷신 직후). 파트가 늘어나면 그 전환 지점에서
# show_chapter_title()에 다른 문구만 넘기면 된다 — 카드 자체는 문구를 모른다
const PART1_TITLE := "PART 1"
const PART1_SUBTITLE := "오르시아"

# 타이틀 카드를 올릴 CanvasLayer 번호. 모든 UI(최대 120)보다 위, FadeOverlay(1000)보다는 아래라
# 카드가 HUD/메뉴를 덮으면서도 페이드에는 정상적으로 덮인다
const CHAPTER_TITLE_CARD_LAYER := 130
# 카드와 페이드 둘 다 검은 화면이라 서로 넘어가는 게 보이지 않는다 — 길게 끌 이유가 없어 짧게만
const CHAPTER_TITLE_FADE_DURATION := 0.12

# 씬 경로별로 GameState에 기록할 방문 플래그를 매핑
const VISITED_FLAGS: Dictionary = {
	"res://world/village.tscn": "visited_village",
	"res://world/forest.tscn": "visited_forest",
	"res://world/cave.tscn": "visited_cave",
	"res://world/desert.tscn": "arrived_desert",
}

# 씬 경로별로 진입 시 재생할 배경음악을 매핑 (전투 씬은 battle_scene.gd가 직접 재생하므로 여기 없음)
const BGM_TRACKS: Dictionary = {
	"res://world/village.tscn": "Definitely Our Town",
	"res://world/forest.tscn": "Silent Forest",
	"res://world/cave.tscn": "Frozen Abyss",
	"res://world/tavern.tscn": "Definitely Our Town",
	"res://world/desert.tscn": "Where The Winds Roam",
}

# 씬 경로별 은은한 색조 오버레이 (SceneTint autoload가 그림). 매핑에 없는 씬(전투 씬 등)은
# _apply_scene_tint()의 기본값(완전 투명)으로 자동 해제됨
const SCENE_TINTS: Dictionary = {
	"res://world/village.tscn": Color(1.0, 0.75, 0.35, 0.12), # 따뜻한 노을빛
	"res://world/forest.tscn": Color(0.25, 0.55, 0.3, 0.12), # 차분한 초록빛
	"res://world/cave.tscn": Color(0.2, 0.15, 0.45, 0.15), # 어둡고 음침한 청보라빛
	"res://world/tavern.tscn": Color(0.75, 0.4, 0.15, 0.13), # 실내의 따뜻한 갈색/주황
}

var _player: Player
var _is_changing_scene: bool = false
var _transitions_suppressed: bool = false

# 전투 진입 시 저장해두는 복귀 컨텍스트 (승리 시 이 좌표/씬으로 정확히 되돌아간다)
var _battle_return_path: String = ""
var _battle_return_position: Vector2 = Vector2.ZERO
var _battle_monster_type: String = ""
var _battle_variants: Array = [] # 이번 전투 몬스터들의 시각 변종 (0번 = 필드에서 부딪힌 그 개체)
var _battle_encounter_id: String = ""
# 전투 승리 후 복귀할 때, 방금 쓰러뜨린 몬스터를 리젠 상태로 돌려놓기 위한 대기 ID
var _pending_defeated_encounter_id: String = ""


# 씬 전환 직후에는 트리거를 무시해야 하는지 여부 (area_transition이 조회).
# monitoring을 잠시 꺼도 물리 서버가 이미 큐에 넣어둔 오래된 body_entered가 재활성화 시점에
# 뒤늦게 발행되어 엉뚱한 전환을 일으킬 수 있어, 콜백 단에서 한 번 더 방어한다
func is_transition_suppressed() -> bool:
	return _transitions_suppressed


# 타이틀 화면의 PLAY 버튼에서 호출. 플레이어를 생성하고 타이틀 화면을 마을 씬으로 교체한 뒤,
# (처음이라면) 오프닝 컷신을 재생하고 최초 스폰 지점으로 플레이어를 배치한다.
# 오프닝을 보여줄 차례라면 마을 음악 대신 프롤로그 곡을 먼저 틀고, 컷신이 끝난 뒤에야
# 마을 음악으로 넘어간다 (컷신 중에 마을 음악이 깔리지 않도록 순서를 맞춤)
func start_game() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.z_index = PLAYER_OVERLAY_Z_INDEX
	add_child(_player)

	var old_scene := get_tree().current_scene
	if old_scene != null:
		_detach_player_from_scene() # 씬과 함께 플레이어까지 해제되지 않도록 먼저 빼낸다
		get_tree().root.remove_child(old_scene)
		old_scene.queue_free()

	var village_scene := load(VILLAGE_SCENE_PATH) as PackedScene
	var new_scene := village_scene.instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	_attach_player_to_scene()

	var show_opening: bool = not GameState.get_flag("seen_opening")
	if show_opening:
		MusicManager.play("Falling Apart (Prologue)")
	else:
		_play_scene_music(VILLAGE_SCENE_PATH)
		_apply_scene_tint(VILLAGE_SCENE_PATH)

	await get_tree().process_frame

	if show_opening:
		# 컷신 -> 파트 타이틀 카드 -> 마을. 둘 다 화면이 검게 덮인 상태로 끝나므로,
		# 마을 음악/색조를 올리고 플레이어를 스폰까지 시킨 뒤에 페이드를 걷어낸다
		# (그래야 플레이어가 제자리로 옮겨지는 순간이 화면에 보이지 않는다)
		await _play_opening()
		await show_chapter_title(PART1_TITLE, PART1_SUBTITLE)
		_play_scene_music(VILLAGE_SCENE_PATH)
		_apply_scene_tint(VILLAGE_SCENE_PATH)
		_place_initial_player()
		await FadeOverlay.fade_in()
		return

	_place_initial_player()


# 엔딩 화면 등에서 타이틀로 돌아갈 때 호출. 플레이어를 정리하고 타이틀 씬으로 교체한다
# (다음 start_game() 호출 시 플레이어를 새로 만들 수 있도록)
func return_to_title() -> void:
	if _player != null:
		_detach_player_from_scene() # 씬과 이중으로 해제되지 않도록 먼저 빼낸 뒤 정리
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


# 파트가 바뀌는 지점에서 검은 화면에 "PART N / 부제" 타이틀 카드를 띄우고 끝날 때까지 기다린다.
# 파트마다 연출은 같고 문구만 다르므로, 문구만 인자로 받아 어느 파트에서든 그대로 부른다.
# [전제] 부를 때 화면이 이미 페이드로 검게 덮여 있어야 한다 (안 그러면 카드가 툭 튀어나온다).
# [보장] 끝난 뒤에도 화면은 검게 덮인 채로 남는다 — 호출부가 다음 씬을 올린 뒤 fade_in()으로 걷어내면 된다
func show_chapter_title(part_text: String, subtitle: String) -> void:
	var card_layer := CanvasLayer.new()
	card_layer.layer = CHAPTER_TITLE_CARD_LAYER
	add_child(card_layer)
	var card := CHAPTER_TITLE_CARD_SCENE.instantiate() as ChapterTitleCard
	card_layer.add_child(card)

	# 카드 배경도 검은색이라, 덮고 있던 페이드를 걷어내도 화면은 검은 채로 이어진다
	await FadeOverlay.fade_in(CHAPTER_TITLE_FADE_DURATION)
	await card.play(part_text, subtitle)
	await FadeOverlay.fade_out(CHAPTER_TITLE_FADE_DURATION)

	card_layer.queue_free()


# 오프닝 인트로를 (딱 한 번) 전용 CutsceneBox로 화면 전체에 재생하고, 끝날 때까지 기다림.
# 특정 월드 씬에 속하지 않도록 CanvasLayer와 함께 직접 생성했다가 끝나면 정리한다
# (village.tscn 등 월드 씬을 건드리지 않기 위함).
# 끝날 때는 페이드를 걷어내지 않고 검게 덮인 채로 둔다 — 곧바로 파트 타이틀 카드가 이어지기 때문
func _play_opening() -> void:
	GameState.set_flag("seen_opening", true)

	var cutscene_layer := CanvasLayer.new()
	cutscene_layer.layer = 100
	add_child(cutscene_layer)
	var cutscene_box := CUTSCENE_BOX_SCENE.instantiate() as CutsceneBox
	cutscene_layer.add_child(cutscene_box)

	await FadeOverlay.fade_out()
	cutscene_box.start_cutscene(DialogueData.OPENING_DIALOGUE, "opening_1")
	await FadeOverlay.fade_in()

	# 페이드가 걷히는 동안에도 스킵 버튼은 눌린다. 그 사이에 끝나버렸다면 cutscene_ended는
	# 기다리는 쪽 없이 이미 지나간 뒤라, 그냥 await하면 다시는 오지 않을 신호를 검은 화면에서
	# 영원히 기다리게 된다
	if not cutscene_box.is_finished():
		await cutscene_box.cutscene_ended

	await FadeOverlay.fade_out()
	cutscene_layer.queue_free()


# 현재 씬이 Y-Sort를 켠 씬(마을)이면 플레이어를 그 씬 밑으로 옮긴다.
# Y-Sort는 "같은 부모 밑의 형제들"끼리만 정렬하는데, 플레이어는 오토로드인 SceneManager가 들고 있어
# 기본적으로 씬 트리 바깥에 있다 — 그래서 옮겨주지 않으면 나무/NPC와 절대 섞여 정렬되지 않는다.
# Y-Sort를 쓰지 않는 씬(동굴/숲 등)에서는 기존처럼 SceneManager 밑에 z_index로 띄운 채 둔다
func _attach_player_to_scene() -> void:
	if _player == null:
		return

	var scene := get_tree().current_scene
	var use_y_sort: bool = scene is Node2D and (scene as Node2D).y_sort_enabled
	var desired_parent: Node = scene if use_y_sort else self

	if _player.get_parent() != desired_parent:
		var world_position := _player.global_position
		_player.get_parent().remove_child(_player)
		desired_parent.add_child(_player)
		_player.global_position = world_position

	# Y-Sort 씬에서는 나무/NPC와 같은 밴드에 서야 Y 좌표로 앞뒤를 겨룰 수 있다
	_player.z_index = CHARACTER_BAND_Z_INDEX if use_y_sort else PLAYER_OVERLAY_Z_INDEX

	# 발밑 그림자는 씬의 ShadowLayer가 들고 있어서 씬과 함께 사라진다 — 플레이어 자신은 씬을
	# 넘어 살아남으므로, 새 씬에 들어올 때마다 그 씬의 레이어에 다시 만들어 붙여야 한다
	# (그림자 레이어가 없는 씬에서는 아무 일도 일어나지 않는다)
	_player.attach_shadow()

	# WaterShimmerLayer 등 물 위 타일을 별도 레이어로 옮기는 스크립트는 add_child를 지연 호출한다.
	# 같은 프레임 안에서 더 나중에 큐에 들어간 이 호출도 지연되므로, 그 레이어가 실제로 생긴 뒤에
	# 경계를 계산하게 된다
	_apply_camera_limits.call_deferred()


# 현재 씬의 TileMap/TileMapLayer 사용 범위(없으면 Background)를 기준으로 카메라 이동 한계를 설정
func _apply_camera_limits() -> void:
	if _player == null:
		return
	var bounds := _compute_scene_bounds(get_tree().current_scene)
	if bounds.size == Vector2.ZERO:
		return
	_player._camera.limit_left = int(bounds.position.x)
	_player._camera.limit_top = int(bounds.position.y)
	_player._camera.limit_right = int(bounds.end.x)
	_player._camera.limit_bottom = int(bounds.end.y)


func _compute_scene_bounds(scene: Node) -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	for child in scene.get_children():
		if not (child is TileMap or child is TileMapLayer):
			continue
		var used: Rect2i = child.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var a: Vector2 = child.to_global(child.map_to_local(used.position))
		var b: Vector2 = child.to_global(child.map_to_local(used.position + used.size))
		var rect := Rect2(a, b - a).abs()
		bounds = rect if not has_bounds else bounds.merge(rect)
		has_bounds = true

	if has_bounds:
		return bounds

	var background := scene.get_node_or_null("Background") as Control
	if background != null:
		return Rect2(background.global_position, background.size)

	return Rect2()


# 현재 씬을 해제하기 전에 플레이어를 SceneManager 밑으로 되돌린다.
# 씬의 자식으로 들어가 있는 상태에서 씬을 free하면 플레이어까지 함께 사라진다
func _detach_player_from_scene() -> void:
	if _player == null or _player.get_parent() == self:
		return
	_player.get_parent().remove_child(_player)
	add_child(_player)


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
# variants는 이번 전투에 등장할 마리 수만큼의 시각 변종 배열(MonsterEncounter가 BattleData로 만든 것) —
# 0번이 필드에서 보던 그 개체라 전투 씬에도 같은 모습으로 이어진다.
# 물리 콜백 밖에서 안전하게 처리하도록 지연시킴 (change_scene과 동일한 방어)
func enter_battle(monster_type: String, variants: Array, encounter_id: String, return_path: String, return_position: Vector2) -> void:
	if _is_changing_scene:
		return
	_is_changing_scene = true
	_battle_monster_type = monster_type
	_battle_variants = variants
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
		_detach_player_from_scene() # 전투 씬으로 넘어가는 동안 플레이어가 씬과 함께 사라지지 않게
		get_tree().root.remove_child(old_scene)
		old_scene.queue_free()

	var battle_ps := load(BATTLE_SCENE_PATH) as PackedScene
	var battle := battle_ps.instantiate() as BattleScene
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	battle.start_with(_battle_monster_type, _battle_variants)
	_apply_scene_tint(BATTLE_SCENE_PATH) # 전투 화면엔 구역 색조를 남기지 않음(매핑에 없어 자동으로 꺼짐)

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
		_detach_player_from_scene() # 씬과 함께 플레이어까지 해제되지 않도록 먼저 빼낸다
		get_tree().root.remove_child(old_scene)
		old_scene.queue_free()

	var next_scene := load(scene_path) as PackedScene
	var new_scene := next_scene.instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	_attach_player_to_scene() # Y-Sort 씬이면 그 밑으로 옮겨 나무/NPC와 함께 정렬되게 한다

	# 전환한 구역의 방문 여부를 GameState에 기록
	_record_visited(scene_path)
	_play_scene_music(scene_path)
	_apply_scene_tint(scene_path)

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
		_player = PLAYER_SCENE.instantiate() as Player
		_player.z_index = PLAYER_OVERLAY_Z_INDEX
		add_child(_player)


# 플레이어가 현재 존재하는지 (게임 진행 중인지) 여부
func has_player() -> bool:
	return _player != null


# 플레이어의 현재 월드 좌표 (없으면 원점)
func get_player_position() -> Vector2:
	return _player.global_position if _player != null else Vector2.ZERO


# 현재 씬의 경계 (메인 카메라의 limit_*와 같은 계산 — 미니맵 카메라도 이걸로 clamp한다)
func get_current_scene_bounds() -> Rect2:
	return _compute_scene_bounds(get_tree().current_scene)


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


# 씬 경로에 대응하는 배경음악이 있으면 재생 (이미 같은 곡이면 MusicManager가 알아서 무시함)
func _play_scene_music(scene_path: String) -> void:
	if BGM_TRACKS.has(scene_path):
		MusicManager.play(BGM_TRACKS[scene_path])


# 씬 경로에 대응하는 색조로 오버레이를 전환 (매핑에 없으면 완전 투명으로 꺼짐 — 전투 씬 등)
func _apply_scene_tint(scene_path: String) -> void:
	SceneTint.apply(SCENE_TINTS.get(scene_path, Color(0, 0, 0, 0)))


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
