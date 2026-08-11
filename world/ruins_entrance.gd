class_name RuinsEntrance
extends Area2D

# 사막의 유적 입구. dock.gd와 동일한 상호작용 패턴([E] -> DialogueBox, dialogue_ended의 last_node_id로 판정).
# - ruins_available=false (나딤과 대화 전): "아직 입구를 찾지 못한 것 같다" 안내만 (옵션 없이 종료)
# - ruins_available=true (나딤이 유적 위치를 알려준 뒤): "유적으로 들어가시겠습니까?" 확인 후 "예"면 유적 씬으로 전환
# 범위에 들어올 때마다 flag를 재확인해 안내 문구/대화가 자동으로 바뀐다.

const RUINS_SCENE_PATH := "res://world/ruins.tscn"
const RUINS_SPAWN_POINT := "RuinsSpawn"

const PROMPT_UNAVAILABLE := "[E] 살펴보기"
const PROMPT_AVAILABLE := "[E] 유적으로 들어가기"

const UNAVAILABLE_DIALOGUE: Array = [
	{
		"id": "ruins_unavailable",
		"speaker": "",
		"narration": "모래에 반쯤 묻힌 낡은 석조물이 보인다.",
		"text": "아직 입구를 찾지 못한 것 같다.",
		"is_decisive": false,
		"options": [],
	},
]

const ENTER_DIALOGUE: Array = [
	{
		"id": "ruins_ask",
		"speaker": "",
		"narration": "어둠이 내려앉은 유적의 입구가 입을 벌리고 있다.",
		"text": "유적으로 들어가시겠습니까?",
		"is_decisive": false,
		"options": [
			{"label": "예", "next_id": "ruins_confirm_yes"},
			{"label": "아니요", "next_id": ""},
		],
	},
	{
		"id": "ruins_confirm_yes",
		"speaker": "",
		"narration": "(유적 안으로 발을 들인다)",
		"text": "",
		"is_decisive": false,
		"options": [],
	},
]

@onready var _interact_prompt: Label = $InteractPrompt

var _player_in_range: bool = false


# 감지 영역 시그널을 연결하고 안내 문구를 초기 상태로 숨김
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_interact_prompt.hide()


# 플레이어가 범위에 들어오면 현재 ruins_available 상태에 맞는 안내를 표시 (매번 재확인해 flag 변화를 반영)
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_interact_prompt.text = PROMPT_AVAILABLE if GameState.get_flag("ruins_available") else PROMPT_UNAVAILABLE
		_interact_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_interact_prompt.hide()


# 범위 안에서 상호작용 입력이 들어오면 대화를 시작
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# ruins_available에 따라 안내 대화(입구 못 찾음) 또는 유적 진입 확인 대화를 띄운다
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_interact_prompt.hide()
	if GameState.get_flag("ruins_available"):
		dialogue_box.start_dialogue(ENTER_DIALOGUE, "ruins_ask")
	else:
		dialogue_box.start_dialogue(UNAVAILABLE_DIALOGUE, "ruins_unavailable")


# 진입 확인("예")을 끝까지 확인(ruins_confirm_yes에서 종료)했을 때만 유적 씬으로 전환.
# 그 외(입구 못 찾음 안내/"아니요")에는 아무 일도 없이 안내만 다시 표시
func _on_dialogue_ended(last_node_id: String) -> void:
	if last_node_id == "ruins_confirm_yes":
		SceneManager.change_scene(RUINS_SCENE_PATH, RUINS_SPAWN_POINT)
		return

	if _player_in_range:
		_interact_prompt.show()
