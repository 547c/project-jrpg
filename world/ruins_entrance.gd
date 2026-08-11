class_name RuinsEntrance
extends Area2D

# 사막의 유적 입구. dock.gd와 동일한 상호작용 패턴([E] -> DialogueBox, dialogue_ended의 last_node_id로 판정).
# 3단계 게이팅 (범위에 들어올 때마다·상호작용마다 상태를 재확인):
# 1. ruins_available=false (나딤이 유적 위치를 알려주기 전) → "아직 입구를 찾지 못한 것 같다"
# 2. ruins_available=true지만 미충족 → 조건별 안내 (미라 안 잡았으면 "미라들이 먼저다", 열쇠 없으면 "열쇠가 필요하다")
# 3. desert_mummies 완료 AND 유적 열쇠 보유 → "열쇠로 문을 연다. 유적으로 들어가시겠습니까?" → ruins.tscn 전환
#    (열쇠는 유지형이라 소비하지 않는다)

const RUINS_SCENE_PATH := "res://world/ruins.tscn"
const RUINS_SPAWN_POINT := "RuinsSpawn"

const RUINS_KEY_ITEM := "ruins_key"
const MUMMIES_QUEST := "desert_mummies"

const PROMPT_LOCKED := "[E] 살펴보기"
const PROMPT_OPEN := "[E] 유적으로 들어가기"

# 1단계: 나딤 대화 전
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

# 2단계: 미라가 아직 남아있음
const BLOCKED_MUMMIES_DIALOGUE: Array = [
	{
		"id": "ruins_blocked_mummies",
		"speaker": "",
		"narration": "굳게 닫힌 유적의 문 앞. 등 뒤가 서늘하다.",
		"text": "이 땅을 떠도는 미라들을 먼저 정리해야 할 것 같다.",
		"is_decisive": false,
		"options": [],
	},
]

# 2단계: 열쇠가 없음
const BLOCKED_KEY_DIALOGUE: Array = [
	{
		"id": "ruins_blocked_key",
		"speaker": "",
		"narration": "육중한 돌문에 낡은 열쇠 구멍이 보인다.",
		"text": "문을 열 열쇠가 필요하다.",
		"is_decisive": false,
		"options": [],
	},
]

# 3단계: 조건 충족 — 열쇠로 진입
const ENTER_DIALOGUE: Array = [
	{
		"id": "ruins_ask",
		"speaker": "",
		"narration": "열쇠를 꽂아 넣자 육중한 문이 천천히 열린다.",
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


# 플레이어가 범위에 들어오면 현재 상태에 맞는 안내 문구를 표시 (매번 재확인해 진행 상황 변화를 반영)
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_interact_prompt.text = PROMPT_OPEN if _can_enter() else PROMPT_LOCKED
		_interact_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_interact_prompt.hide()


# 범위 안에서 상호작용 입력이 들어오면 대화를 시작
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# 3단계 진입 조건: 미라 퀘스트 완료 AND 유적 열쇠 보유
func _can_enter() -> bool:
	return GameState.is_quest_complete(MUMMIES_QUEST) and GameState.has_item(RUINS_KEY_ITEM)


# 현재 상태(3단계)에 맞는 대화를 띄운다
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_interact_prompt.hide()

	if not GameState.get_flag("ruins_available"):
		dialogue_box.start_dialogue(UNAVAILABLE_DIALOGUE, "ruins_unavailable")
	elif not GameState.is_quest_complete(MUMMIES_QUEST):
		dialogue_box.start_dialogue(BLOCKED_MUMMIES_DIALOGUE, "ruins_blocked_mummies")
	elif not GameState.has_item(RUINS_KEY_ITEM):
		dialogue_box.start_dialogue(BLOCKED_KEY_DIALOGUE, "ruins_blocked_key")
	else:
		dialogue_box.start_dialogue(ENTER_DIALOGUE, "ruins_ask")


# 진입 확인("예")을 끝까지 확인(ruins_confirm_yes에서 종료)했을 때만 유적 씬으로 전환 (열쇠는 소비하지 않음).
# 그 외(각 단계 안내/"아니요")에는 아무 일도 없이 안내만 다시 표시
func _on_dialogue_ended(last_node_id: String) -> void:
	if last_node_id == "ruins_confirm_yes":
		SceneManager.change_scene(RUINS_SCENE_PATH, RUINS_SPAWN_POINT)
		return

	if _player_in_range:
		_interact_prompt.show()
