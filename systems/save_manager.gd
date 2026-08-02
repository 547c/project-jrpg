extends Node

# 단일 슬롯 세이브/로드. GameState.flags + 현재 씬 경로 + 플레이어의 정확한 좌표를
# JSON으로 직렬화해 user://save_data.json에 저장한다.
const SAVE_PATH := "user://save_data.json"


# 저장 파일이 존재하는지 여부
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# 현재 게임 상태(flags/씬/플레이어 위치)를 JSON으로 저장. 성공 시 true
func save_game() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null or not SceneManager.has_player():
		return false

	var data := {
		"scene_path": current_scene.scene_file_path,
		"player_position": _vector2_to_dict(SceneManager.get_player_position()),
		"flags": GameState.flags,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


# 저장 파일을 읽어 flags를 복원하고, 저장된 씬으로 이동해 플레이어를 정확한 좌표에 배치. 성공 시 true
func load_game() -> bool:
	if not has_save():
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed

	var scene_path: String = data.get("scene_path", "")
	if scene_path == "":
		return false

	GameState.restore_flags(data.get("flags", {}))

	var position := _dict_to_vector2(data.get("player_position", {}))
	SceneManager.ensure_player_exists()
	SceneManager.change_scene_to_position(scene_path, position)
	return true


# Vector2를 JSON 직렬화 가능한 {x, y} 딕셔너리로 변환
func _vector2_to_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}


# {x, y} 딕셔너리를 Vector2로 복원 (JSON 숫자는 float로 오므로 그대로 받아들임)
func _dict_to_vector2(d: Dictionary) -> Vector2:
	return Vector2(d.get("x", 0.0), d.get("y", 0.0))
