class_name Compass
extends Control

# 캐릭터 주위를 도는 방향 나침반. GameState.get_current_objective_stage()로 결정되는 현재 목표를,
# "현재 씬 안"에 있으면 그 대상(NPC/가디언) 방향을, "다른 씬"에 있으면 그 씬으로 가는 포탈 방향을
# 가리킨다. 월드는 허브-스포크 구조(village가 허브, forest/cave/tavern은 village에만 연결)라,
# 다른 스포크로 가야 할 땐 목적지행 직접 포탈이 없으면 허브(village)행 포탈로 대신 안내한다.
#
# 화살표는 화면 중앙(카메라가 항상 플레이어를 따라가므로 곧 플레이어 위치)에서 ORBIT_RADIUS만큼
# 떨어진 채 목표 방향 쪽 궤도 위에 떠서, 마치 캐릭터 주위를 도는 것처럼 보이게 한다.
#
# 방향 계산 로직(resolve_target)은 트리에 붙지 않아도 되는 순수 함수로 분리해 headless로 검증한다.

const VILLAGE := "res://world/village.tscn"
const FOREST := "res://world/forest.tscn"
const CAVE := "res://world/cave.tscn"
const TAVERN := "res://world/tavern.tscn"

const ORBIT_RADIUS := 70.0 # 화면 중앙(≈ 플레이어)으로부터 화살표를 띄우는 거리(px)

@onready var _arrow: Polygon2D = $Arrow

var _enabled: bool = true # 기본 켜짐 (M으로 토글)


func is_enabled() -> bool:
	return _enabled


# M 키(hud.gd가 호출) 등으로 켜짐/꺼짐 전환
func toggle() -> void:
	_enabled = not _enabled


# HUD가 매 프레임 호출. HUD가 보이는 상태(hud_visible)이고 나침반이 켜져 있으며 가리킬 대상이 있을 때만
# 화살표를 목표 방향으로 회전시켜 표시하고, 그 외에는 숨긴다
func update_compass(hud_visible: bool) -> void:
	if not _enabled or not hud_visible or not SceneManager.has_player():
		_arrow.visible = false
		return

	var scene := get_tree().current_scene
	if scene == null:
		_arrow.visible = false
		return

	var player_pos: Vector2 = SceneManager.get_player_position()
	var result := resolve_target(scene, player_pos)
	if not result["visible"]:
		_arrow.visible = false
		return

	var dir: Vector2 = result["position"] - player_pos
	if dir.length() < 0.001: # 목표 위에 겹쳐 서 있으면 방향이 무의미하므로 숨김
		_arrow.visible = false
		return

	var screen_center: Vector2 = get_rect().size / 2.0
	_arrow.visible = true
	_arrow.position = screen_center + dir.normalized() * ORBIT_RADIUS
	_arrow.rotation = dir.angle() # 화살표 폴리곤은 +X(오른쪽)를 향하도록 정의되어 있음


# [순수/검증 대상] 현재 씬과 플레이어 위치로부터 가리킬 목표를 계산.
# 반환: {"visible": bool, "position": Vector2}. visible=false면 가리킬 대상 없음(화살표 숨김)
func resolve_target(scene: Node, player_pos: Vector2) -> Dictionary:
	var stage: int = GameState.get_current_objective_stage()
	var scene_path: String = scene.scene_file_path

	# Stage 4(몬스터 처치)는 특정 대상 하나를 가리키기 애매하므로 별도 처리
	if stage == 4:
		return _resolve_monster_stage(scene, scene_path, player_pos)

	# 나머지 stage: (목표 씬, 그 씬 안에서 가리킬 노드 이름)으로 환원
	var target_scene := ""
	var node_name := ""
	match stage:
		1, 6:
			target_scene = VILLAGE
			node_name = "Elara"
		2:
			target_scene = VILLAGE # 마을 안에서 가리킬 NPC는 아래에서 "안 만난 쪽 중 가까운 쪽"으로 결정
		3:
			target_scene = TAVERN
			node_name = "Mia"
		5:
			target_scene = CAVE
			node_name = "GuardianEncounter"
		7:
			target_scene = VILLAGE # 2부: 유서프에게 더 알아보기 — 마을 안이면 유서프, 아니면 마을 포탈
			node_name = "Yusuf"
		8:
			target_scene = VILLAGE # 2부: 부두에서 출항 — 마을 안이면 부두, 아니면 마을 포탈
			node_name = "Dock"
		_:
			return _hidden()

	# 목표가 현재 씬 안이면 그 대상 노드를, 아니면 그 씬으로 가는 포탈을 가리킨다
	if scene_path == target_scene:
		var node: Node
		if stage == 2:
			node = _nearest_unmet_villager(scene, player_pos)
		else:
			node = scene.get_node_or_null(node_name)
		return _from_node(node)

	return _from_node(_portal_toward(scene, scene_path, target_scene))


# Stage 4: 아직 완료 못 한 몬스터 퀘스트(숲/동굴)의 씬으로 가는 포탈을 가리킨다.
# 단, 이미 그 몬스터 씬 안에 있으면(여러 마리라 특정 하나를 가리키기 애매) 화살표를 숨긴다
func _resolve_monster_stage(scene: Node, scene_path: String, player_pos: Vector2) -> Dictionary:
	var incomplete: Array[String] = []
	if not GameState.get_flag("forest_quest_complete"):
		incomplete.append(FOREST)
	if not GameState.get_flag("cave_quest_complete"):
		incomplete.append(CAVE)

	if incomplete.is_empty():
		return _hidden() # 방어적 (stage 4면 최소 하나는 미완료여야 함)

	if scene_path in incomplete:
		return _hidden() # 클리어해야 할 몬스터 씬 안 — 화살표 숨김

	# 미완료 씬으로 가는 포탈 중 플레이어에게 가장 가까운 쪽을 가리킨다
	var best: Node2D = null
	var best_dist := INF
	for target_scene in incomplete:
		var portal := _portal_toward(scene, scene_path, target_scene)
		if portal != null:
			var d: float = player_pos.distance_squared_to(portal.global_position)
			if d < best_dist:
				best_dist = d
				best = portal
	return _from_node(best)


# 마을에서 아직 안 만난 로한/유서프 중 플레이어에게 더 가까운 쪽 노드를 반환 (둘 다 만났으면 null)
func _nearest_unmet_villager(scene: Node, player_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for pair in [["Rohan", "met_rohan"], ["Yusuf", "met_yusuf"]]:
		if GameState.get_flag(pair[1]):
			continue
		var npc := scene.get_node_or_null(pair[0]) as Node2D
		if npc != null:
			var d: float = player_pos.distance_squared_to(npc.global_position)
			if d < best_dist:
				best_dist = d
				best = npc
	return best


# target_scene으로 가는 포탈을 반환. 현재 씬에 직접 연결 포탈이 없으면 허브(village)행 포탈로 대체.
# (허브-스포크 구조라 스포크→다른 스포크는 항상 village를 경유한다)
func _portal_toward(scene: Node, scene_path: String, target_scene: String) -> Node2D:
	var direct := _find_portal_to(scene, target_scene)
	if direct != null:
		return direct
	if scene_path == VILLAGE:
		return null # 이미 허브인데 직접 포탈이 없다면 안내 불가
	return _find_portal_to(scene, VILLAGE)


# 현재 씬의 직계 자식 중 destination_scene_path가 dest와 일치하는 area_transition을 찾아 반환
func _find_portal_to(scene: Node, dest: String) -> Node2D:
	for child in scene.get_children():
		if child.get("destination_scene_path") == dest:
			return child as Node2D
	return null


func _from_node(node: Node) -> Dictionary:
	if node == null:
		return _hidden()
	return {"visible": true, "position": (node as Node2D).global_position}


func _hidden() -> Dictionary:
	return {"visible": false, "position": Vector2.ZERO}
