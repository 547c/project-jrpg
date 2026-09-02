class_name RuinsLore
extends Area2D

const UiTranslator := preload("res://systems/ui_translator.gd")

# 유적 내부의 벽화/기록 오브젝트. locked_door.gd와 동일한 상호작용 패턴(범위 안 [E] -> DialogueBox)이되,
# 옵션이 있는 짧은 대화 트리를 재생하고 마지막 노드(ruins_lore_2)에서 truth_discovered 플래그를 세운다.
# 씬 이동 등 다른 효과는 없다. 외형(벽화)은 맵의 배경/타일이 담당하고, 여기선 감지 + 표식만.

const LORE_DIALOGUE: Array = [
	{
		"id": "ruins_lore_intro",
		"speaker": "",
		"narration": "벽에 새겨진 그림이 보인다: 사람들이 물줄기 앞에서 무언가를 지키는 존재들에게 예를 표하고 있다. 그 옆에는 낯선 글자로 쓰인 기록이 있다.",
		"is_decisive": false,
		"options": [
			{"label": "[기록을 읽어본다]", "next_id": "ruins_lore_1"},
		],
	},
	{
		"id": "ruins_lore_1",
		"speaker": "",
		"text": "...번역하긴 어렵지만, 몇 단어는 알아볼 수 있다: '봉인', '감시자', '실수'.",
		"is_decisive": false,
		"next_id": "ruins_lore_2",
	},
	{
		"id": "ruins_lore_2",
		"speaker": "",
		"text": "마지막 줄엔 이렇게 적혀 있다: '우리가 막으려 했던 것이, 결국 우리 손으로 풀려났다.'",
		"set_flag_on_show": "truth_discovered", # 이 노드에 도달하는 순간 유적의 진실을 발견한 것으로 기록
		"is_decisive": false,
		"options": [],
	},
]

const MARKER_COLOR := Color(0.75, 0.7, 0.95, 0.6) # 신비로운 벽화 느낌의 옅은 보랏빛

@onready var _interact_prompt: Label = $InteractPrompt

var _player_in_range: bool = false
var _presence_marker: Label # 전용 스프라이트가 없어(벽화 외형은 맵이 담당) pulse 전용으로 만든 작은 표식
var _pulse: InteractPulse


# 감지 영역 시그널을 연결하고 안내 문구를 초기 상태로 숨김
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	UiTranslator.bind(self)
	_interact_prompt.hide()
	_create_presence_marker()


# "여기 뭔가 있다"를 멀리서도 알 수 있도록 항상 보이는 작은 표식
func _create_presence_marker() -> void:
	_presence_marker = Label.new()
	_presence_marker.text = "✦"
	_presence_marker.position = Vector2(-8, -26)
	_presence_marker.add_theme_font_size_override("font_size", 16)
	_presence_marker.add_theme_color_override("font_color", MARKER_COLOR)
	_presence_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_presence_marker)
	_pulse = InteractPulse.new(self, _presence_marker)


# 플레이어가 범위에 들어오면 "[E] 살펴보기" 안내를 표시하고, pulse를 더 뚜렷하게 바꿈
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


# 범위 안에서 상호작용 입력이 들어오면 벽화/기록 대화를 시작
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# 씬에서 DialogueBox를 찾아 벽화 대화를 시작
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_interact_prompt.hide()
	dialogue_box.start_dialogue(LORE_DIALOGUE, "ruins_lore_intro")


# 대화가 끝났을 때, 플레이어가 아직 범위 안이면 안내 문구를 다시 표시
func _on_dialogue_ended(_last_node_id: String) -> void:
	if _player_in_range:
		_interact_prompt.show()
