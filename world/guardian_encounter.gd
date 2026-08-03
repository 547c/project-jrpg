extends Area2D

const DIALOGUE_START_ID := "guardian_intro_1"
const RETURN_SCENE_PATH := "res://world/village.tscn"
const RETURN_SPAWN_POINT := "VillageSpawnFromCave"
const REQUIRED_QUEST_LEVEL := 2 # 이 이상이어야 실제 수호자 이벤트가 시작됨 (숲/동굴 서브퀘 완료 개수)

# quest_level이 부족할 때 대신 보여주는 짧은 안내 (선택지 없이 닫기만)
const NOT_READY_DIALOGUE: Array = [
	{"id": "not_ready", "speaker": "", "narration": "아직 준비가 안 된 것 같다.", "is_decisive": false, "options": []},
]

var _triggered: bool = false


# body_entered 시그널을 콜백에 연결
func _ready() -> void:
	body_entered.connect(_on_body_entered)


# 플레이어가 처음 도달했을 때만(1회 제한) 수호자 조우를 시작.
# quest_level이 아직 부족하면 전투/대화 없이 짧은 안내만 띄우고 그냥 지나가게 함(재시도 가능)
func _on_body_entered(body: Node2D) -> void:
	if _triggered or GameState.get_flag("guardian_event_done"):
		return
	if not body.is_in_group("player"):
		return

	if GameState.get_flag("quest_level") < REQUIRED_QUEST_LEVEL:
		_show_not_ready_message()
		return

	_triggered = true
	GameState.set_flag("guardian_event_done", true)
	_start_encounter()


# quest_level이 부족할 때 보여주는 안내 메시지 (guardian_event_done을 세우지 않으므로 나중에 다시 시도 가능)
func _show_not_ready_message() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	dialogue_box.start_dialogue(NOT_READY_DIALOGUE, "not_ready")


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
