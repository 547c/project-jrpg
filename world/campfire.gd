class_name Campfire
extends Area2D

# NPC(npc.gd)와 동일한 상호작용 패턴: 범위 안에서 [E]를 누르면 DialogueBox로 쉬어갈지 묻는다.
# "예"를 끝까지 확인(닫기)하면 체력을 모두 회복한다.

const REST_DIALOGUE: Array = [
	{
		"id": "campfire_ask",
		"speaker": "",
		"narration": "모닥불이 따뜻하게 타오르고 있다.",
		"text": "잠시 쉬어가시겠습니까?",
		"is_decisive": false,
		"options": [
			{"label": "예", "next_id": "campfire_rest"},
			{"label": "아니요", "next_id": ""},
		],
	},
	{
		"id": "campfire_rest",
		"speaker": "",
		"text": "체력을 모두 회복했다.",
		"is_decisive": false,
		"options": [],
	},
]

@onready var _interact_prompt: Label = $InteractPrompt
@onready var _sprite: Sprite2D = $Sprite2D

var _player_in_range: bool = false
var _pulse: InteractPulse


# 감지 영역 시그널을 연결하고 안내 문구를 초기 상태로 숨김
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_interact_prompt.hide()
	_pulse = InteractPulse.new(self, _sprite)


# 플레이어가 범위에 들어오면 "쉬어가기" 안내를 표시하고, pulse를 더 뚜렷하게 바꿈
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_interact_prompt.show()
		_pulse.set_strong(true)


# 플레이어가 범위를 벗어나면 안내를 숨기고, pulse를 다시 은은하게 되돌림
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_interact_prompt.hide()
		_pulse.set_strong(false)


# 범위 안에서 상호작용 입력이 들어오면 대화를 시작
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# 씬에서 DialogueBox를 찾아 쉬어가기 대화를 시작
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_interact_prompt.hide()
	dialogue_box.start_dialogue(REST_DIALOGUE, "campfire_ask")


# 대화가 "체력을 모두 회복했다" 노드에서 끝났을 때만(= "예"를 선택하고 닫기까지 확인) 실제로 회복시킴
func _on_dialogue_ended(last_node_id: String) -> void:
	if last_node_id == "campfire_rest":
		GameState.heal_player_full()

	if _player_in_range:
		_interact_prompt.show()
