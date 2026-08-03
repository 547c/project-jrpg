extends Node

# 5슬롯 세이브/로드. 각 슬롯은 user://save_slot_<N>.json 파일 하나.
# 저장 데이터: 복원용(scene_path/player_position/flags/quests) + 슬롯 목록 미리보기용
# (objective_text/quest_level/player_hp/player_max_hp).
const SLOT_COUNT := 5


func _slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot


# 지정 슬롯에 저장 파일이 있는지
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


# 슬롯 중 하나라도 저장 파일이 있는지 (타이틀 LOAD 버튼 활성화 판정용)
func has_any_save() -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if has_save(slot):
			return true
	return false


# 현재 게임 상태를 지정 슬롯에 저장. 성공 시 true
func save_game(slot: int) -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null or not SceneManager.has_player():
		return false

	var data := {
		"scene_path": current_scene.scene_file_path,
		"player_position": _vector2_to_dict(SceneManager.get_player_position()),
		"flags": GameState.flags,
		"quests": GameState.quests,
		"gold": GameState.gold,
		# --- 슬롯 목록 미리보기용 (복원엔 안 쓰임) ---
		"objective_text": GameState.get_objective_text(),
		"quest_level": GameState.get_flag("quest_level"),
		"player_hp": GameState.get_flag("player_hp"),
		"player_max_hp": GameState.get_flag("player_max_hp"),
	}

	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


# 지정 슬롯을 읽어 flags/quests를 복원하고, 저장된 씬으로 이동해 플레이어를 정확한 좌표에 배치. 성공 시 true
func load_game(slot: int) -> bool:
	var data := _read_slot(slot)
	if data.is_empty():
		return false

	var scene_path: String = data.get("scene_path", "")
	if scene_path == "":
		return false

	GameState.restore_flags(data.get("flags", {}))
	GameState.restore_quests(data.get("quests", {}))
	GameState.restore_gold(int(data.get("gold", 0)))

	var position := _dict_to_vector2(data.get("player_position", {}))
	SceneManager.ensure_player_exists()
	SceneManager.change_scene_to_position(scene_path, position)
	return true


# 슬롯의 미리보기 요약을 반환. 비어있거나 손상됐으면 빈 Dictionary
func get_save_summary(slot: int) -> Dictionary:
	var data := _read_slot(slot)
	if data.is_empty():
		return {}
	return {
		"objective_text": data.get("objective_text", ""),
		"quest_level": int(data.get("quest_level", 0)),
		"player_hp": int(data.get("player_hp", 0)),
		"player_max_hp": int(data.get("player_max_hp", 0)),
	}


# 5개 슬롯 전부의 요약을 배열로 (index 0 = 슬롯1 ... index 4 = 슬롯5). 빈 슬롯은 빈 Dictionary
func get_all_save_summaries() -> Array:
	var result: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		result.append(get_save_summary(slot))
	return result


# 슬롯 파일을 열어 파싱한 Dictionary를 반환 (없거나 손상 시 빈 Dictionary)
func _read_slot(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return parsed


# Vector2를 JSON 직렬화 가능한 {x, y} 딕셔너리로 변환
func _vector2_to_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}


# {x, y} 딕셔너리를 Vector2로 복원 (JSON 숫자는 float로 오므로 그대로 받아들임)
func _dict_to_vector2(d: Dictionary) -> Vector2:
	return Vector2(d.get("x", 0.0), d.get("y", 0.0))
