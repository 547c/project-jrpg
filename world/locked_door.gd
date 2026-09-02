class_name LockedDoor
extends Area2D

const UiTranslator := preload("res://systems/ui_translator.gd")

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

const MARKER_COLOR := Color(0.85, 0.85, 0.9, 0.55) # 잠긴 문 느낌의 차분한 회백색

@onready var _interact_prompt: Label = $InteractPrompt

var _player_in_range: bool = false
var _presence_marker: Label # 전용 스프라이트가 없어(문 외형은 맵의 배경/타일이 담당) pulse 전용으로 만든 작은 표식
var _pulse: InteractPulse


# 감지 영역 시그널을 연결하고 안내 문구를 초기 상태로 숨김
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	UiTranslator.bind(self)
	_interact_prompt.hide()
	_create_presence_marker()


# "여기 뭔가 있다"를 멀리서도 알 수 있도록 항상 보이는 작은 표식 (InteractPrompt와 달리 범위와 무관하게 항상 표시)
func _create_presence_marker() -> void:
	_presence_marker = Label.new()
	_presence_marker.text = "✦"
	_presence_marker.position = Vector2(-8, -26)
	_presence_marker.add_theme_font_size_override("font_size", 16)
	_presence_marker.add_theme_color_override("font_color", MARKER_COLOR)
	_presence_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_presence_marker)
	_pulse = InteractPulse.new(self, _presence_marker)


# 플레이어가 범위에 들어오면 "[E] 문" 안내를 표시하고, pulse를 더 뚜렷하게 바꿈
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
