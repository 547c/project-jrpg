extends Area2D

const DIALOGUE_START_ID := "guardian_greeting"
const RETURN_SCENE_PATH := "res://world/forest.tscn"
const RETURN_SPAWN_POINT := "ForestSpawnFromCave"

var _triggered: bool = false


# body_entered 시그널을 콜백에 연결
func _ready() -> void:
	body_entered.connect(_on_body_entered)


# 플레이어가 처음 도달했을 때만(1회 제한) 수호자 조우를 시작
func _on_body_entered(body: Node2D) -> void:
	if _triggered or GameState.get_flag("guardian_event_done"):
		return
	if not body.is_in_group("player"):
		return

	_triggered = true
	GameState.set_flag("guardian_event_done", true)
	_start_encounter()


# 기존 DialogueBox를 찾아 수호자 대화를 시작
func _start_encounter() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	dialogue_box.start_dialogue(DialogueData.GUARDIAN_DIALOGUE, DIALOGUE_START_ID)


# 대화가 끝나면 동굴 볼일이 끝났다는 의미로 숲으로 자동 전환
func _on_dialogue_ended() -> void:
	SceneManager.change_scene(RETURN_SCENE_PATH, RETURN_SPAWN_POINT)
