class_name LockedDoor
extends Area2D

# 장식용 잠긴 문. NPC/캠프파이어(campfire.gd)와 동일한 상호작용 패턴을 따르되,
# 대화에 옵션이 없어(DialogueBox의 기본 "닫기" 버튼만 뜸) 확인만 하고 바로 닫히며,
# 씬 이동 등 다른 효과는 전혀 일으키지 않는다

const LOCKED_DIALOGUE: Array = [
	{
		"id": "locked_door",
		"speaker": "",
		"text": "지금은 들어갈 수 없다.",
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


# 플레이어가 범위에 들어오면 "[E] 문" 안내를 표시
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_interact_prompt.show()


# 플레이어가 범위를 벗어나면 안내를 숨김
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_interact_prompt.hide()


# 범위 안에서 상호작용 입력이 들어오면 짧은 안내 대화를 시작
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# 씬에서 DialogueBox를 찾아 옵션 없는 짧은 안내 대화를 시작
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_interact_prompt.hide()
	dialogue_box.start_dialogue(LOCKED_DIALOGUE, "locked_door")


# 대화가 끝났을 때, 플레이어가 아직 범위 안이면 안내 문구를 다시 표시
func _on_dialogue_ended(_last_node_id: String) -> void:
	if _player_in_range:
		_interact_prompt.show()
