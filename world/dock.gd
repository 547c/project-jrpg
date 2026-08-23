class_name Dock
extends Area2D

# 마을 부두. campfire.gd와 동일한 상호작용 패턴(범위 안 [E] -> DialogueBox)에, dialogue_ended의
# last_node_id로 결과를 판정하는 방식을 재사용한다.
# - boat_available=false: "아직은 이용할 수 없는 것 같다" 안내만 (옵션 없이 종료)
# - boat_available=true: "정말 떠나시겠습니까?" 확인 후 "예"면 사막 씬으로 전환
# (desert.tscn은 아직 없고 경로만 참조 — 다음 단계에서 제작 예정)

const DESERT_SCENE_PATH := "res://world/desert.tscn"
const DESERT_SPAWN_POINT := "DesertSpawn"

# 사막 도착 = 2부 시작 지점이라, 씬을 넘기기 전에 파트 타이틀 카드를 끼워 넣는다
const PART2_TITLE := "PART 2"
const PART2_SUBTITLE := "잊혀진 진실"

const PROMPT_UNAVAILABLE := "[E] 부두"
const PROMPT_AVAILABLE := "[E] 배를 타고 떠나기"

const UNAVAILABLE_DIALOGUE: Array = [
	{
		"id": "dock_unavailable",
		"speaker": "",
		"narration": "낡은 부두에 아무것도 묶여 있지 않다.",
		"text": "아직은 이용할 수 없는 것 같다.",
		"is_decisive": false,
		"options": [],
	},
]

const DEPART_DIALOGUE: Array = [
	{
		"id": "dock_ask",
		"speaker": "",
		"narration": "부두에 작은 배 한 척이 준비되어 있다.",
		"text": "정말 떠나시겠습니까?",
		"is_decisive": false,
		"options": [
			{"label": "예", "next_id": "dock_confirm_yes"},
			{"label": "아니요", "next_id": ""},
		],
	},
	{
		"id": "dock_confirm_yes",
		"speaker": "",
		"narration": "(배에 오른다)",
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


# 플레이어가 범위에 들어오면 현재 boat_available 상태에 맞는 안내를 표시 (매번 재확인해 flag 변화를 반영)
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_interact_prompt.text = PROMPT_AVAILABLE if GameState.get_flag("boat_available") else PROMPT_UNAVAILABLE
		_interact_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_interact_prompt.hide()


# 범위 안에서 상호작용 입력이 들어오면 대화를 시작
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# boat_available에 따라 안내 대화(이용 불가) 또는 출항 확인 대화를 띄운다
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_interact_prompt.hide()
	if GameState.get_flag("boat_available"):
		dialogue_box.start_dialogue(DEPART_DIALOGUE, "dock_ask")
	else:
		dialogue_box.start_dialogue(UNAVAILABLE_DIALOGUE, "dock_unavailable")


# 출항 확인("예")을 끝까지 확인(dock_confirm_yes에서 종료)했을 때만 사막으로 떠난다.
# 그 외(이용 불가 안내/"아니요")에는 아무 일도 없이 안내만 다시 표시
func _on_dialogue_ended(last_node_id: String) -> void:
	if last_node_id == "dock_confirm_yes":
		_depart_to_desert()
		return

	if _player_in_range:
		_interact_prompt.show()


# 처음 떠날 때만 부두 화면을 먼저 검게 덮고(타이틀 카드가 요구하는 전제) 2부 타이틀 카드를 띄운 뒤
# 사막 씬으로 넘긴다. 이미 한 번 떠나본 적이 있으면(왕복 등) 카드 없이 곧장 전환한다 —
# change_scene()이 알아서 페이드를 감싸므로 여기서 따로 fade_out할 필요가 없다
func _depart_to_desert() -> void:
	if GameState.get_flag("boat_used"):
		SceneManager.change_scene(DESERT_SCENE_PATH, DESERT_SPAWN_POINT)
		return

	GameState.set_flag("boat_used", true)
	await FadeOverlay.fade_out()
	await SceneManager.show_chapter_title(PART2_TITLE, PART2_SUBTITLE)
	SceneManager.change_scene(DESERT_SCENE_PATH, DESERT_SPAWN_POINT)
