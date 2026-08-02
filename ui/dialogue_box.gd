class_name DialogueBox
extends Control

# 대화가 완전히 종료되었을 때 발행. last_node_id는 종료 직전 마지막으로 보여준 노드의 id
# (구독자가 "어떤 대사에서 끝났는지"로 특별 처리를 하고 싶을 때 사용 — 예: 엔딩 트리거)
signal dialogue_ended(last_node_id: String)

const MAX_OPTIONS := 5
const TYPING_CHAR_DELAY := 0.03 # 타이핑 효과 한 글자당 대기 시간(초)
const BLEEP_DIR := "res://assets/sfx/dmochas-dialogue_bleeps_pack/ogg/"
const BLEEP_COUNT := 30
const BLEEP_PITCH_MIN := 0.95
const BLEEP_PITCH_MAX := 1.05

@onready var _panel: Panel = $Panel
@onready var _speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var _narration_label: Label = $Panel/VBox/NarrationLabel
@onready var _text_label: Label = $Panel/VBox/TextLabel
@onready var _options_container: VBoxContainer = $Panel/VBox/OptionsContainer
@onready var _bleep_player: AudioStreamPlayer = $BleepPlayer

var _normal_style: StyleBoxFlat
var _decisive_style: StyleBoxFlat
var _nodes_by_id: Dictionary = {}
var _bleep_sounds: Array[AudioStream] = []
var _last_shown_node_id: String = ""

var _typing_full_text: String = "" # 스킵 시 즉시 표시할, 이번에 보여줘야 할 전체 텍스트
var _typing_generation: int = 0 # 타이핑 세션 번호 (새 타이핑/스킵마다 증가해 이전 코루틴을 무효화)
var _is_typing: bool = false


# 기본/결정적 패널 스타일을 미리 만들고, 다른 씬에서 이 DialogueBox를 찾을 수 있도록 그룹에 등록
func _ready() -> void:
	add_to_group("dialogue_box")

	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	_normal_style.border_color = Color.WHITE
	_normal_style.set_border_width_all(2)

	_decisive_style = _normal_style.duplicate()
	_decisive_style.border_color = Color(1.0, 0.84, 0.0) # 결정적 선택: 금색 테두리
	_decisive_style.set_border_width_all(4)

	# 지문(narration)을 본문과 살짝 구분되도록 연한 회색으로 표시
	_narration_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	for i in range(1, BLEEP_COUNT + 1):
		_bleep_sounds.append(load("%sbleep%03d.ogg" % [BLEEP_DIR, i]))


# 대화 트리를 id 기준으로 인덱싱하고 start_id 노드부터 대화를 시작
func start_dialogue(dialogue_tree: Array, start_id: String) -> void:
	_nodes_by_id.clear()
	for node in dialogue_tree:
		_nodes_by_id[node["id"]] = node

	show()
	_show_node(start_id)


# 주어진 id의 대화 노드를 화면에 표시 (id가 없거나 빈 문자열이면 대화 종료)
func _show_node(node_id: String) -> void:
	if node_id == "" or not _nodes_by_id.has(node_id):
		_end_dialogue()
		return

	_last_shown_node_id = node_id
	var node: Dictionary = _nodes_by_id[node_id]
	var is_decisive: bool = node.get("is_decisive", false)

	_speaker_label.text = node.get("speaker", "")

	var narration: String = node.get("narration", "")
	_narration_label.text = narration
	_narration_label.visible = narration != ""

	_panel.add_theme_stylebox_override("panel", _decisive_style if is_decisive else _normal_style)
	_start_typing(_resolve_text(node))

	_populate_options(node.get("options", []), node.get("next_id", ""))


# text_if_flag가 있으면 해당 flag 값에 따라 text(참)/text_false(거짓)를 골라 반환, 없으면 text 그대로
func _resolve_text(node: Dictionary) -> String:
	var text_if_flag: String = node.get("text_if_flag", "")
	if text_if_flag == "":
		return node.get("text", "")
	return node.get("text", "") if GameState.get_flag(text_if_flag) else node.get("text_false", "")


# 새 텍스트의 타이핑 애니메이션을 시작. 세대 번호를 올려 이전에 진행 중이던 타이핑 코루틴을 무효화시킴
# (단순 bool 플래그는 "새 타이핑 시작 → 곧바로 플래그 재설정"이 await 없이 한 프레임 안에 일어나면
#  낡은 코루틴이 나중에 깨어나서 이미 바뀐(더 짧을 수 있는) _typing_full_text를 낡은 인덱스로 읽어
#  범위 초과 크래시가 날 수 있어서, 코루틴마다 자기 세대와 텍스트를 지역 변수로 들고 있게 함)
func _start_typing(full_text: String) -> void:
	_typing_generation += 1
	_typing_full_text = full_text
	_text_label.text = ""
	_is_typing = true
	_type_text(full_text, _typing_generation)


# 한 글자씩 순차적으로 텍스트를 표시하며, 공백이 아닌 글자마다 bleep 효과음을 재생.
# 자신의 세대(generation)가 더 이상 최신이 아니면(스킵되었거나 새 타이핑이 시작됐으면) 즉시 중단
func _type_text(full_text: String, generation: int) -> void:
	for i in range(full_text.length()):
		if generation != _typing_generation:
			return
		var ch := full_text[i]
		_text_label.text = full_text.substr(0, i + 1)
		if ch.strip_edges() != "":
			_play_bleep()
		await get_tree().create_timer(TYPING_CHAR_DELAY).timeout

	if generation != _typing_generation:
		return
	_text_label.text = full_text
	_is_typing = false


# bleep 효과음 중 하나를 무작위로 골라, 매번 살짝 다른 피치로 재생
func _play_bleep() -> void:
	if _bleep_sounds.is_empty():
		return
	_bleep_player.stream = _bleep_sounds[randi() % _bleep_sounds.size()]
	_bleep_player.pitch_scale = randf_range(BLEEP_PITCH_MIN, BLEEP_PITCH_MAX)
	_bleep_player.play()


# 타이핑 중인 텍스트를 즉시 전부 표시 (세대 번호를 올려 진행 중이던 코루틴을 무효화)
func _skip_typing() -> void:
	_typing_generation += 1
	_text_label.text = _typing_full_text
	_is_typing = false


# show_if_flag가 없거나 해당 flag가 true인 옵션만 남김
func _filter_visible_options(options: Array) -> Array:
	var visible_options: Array = []
	for option in options:
		var show_if_flag: String = option.get("show_if_flag", "")
		if show_if_flag == "" or GameState.get_flag(show_if_flag):
			visible_options.append(option)
	return visible_options


# 표시 조건을 통과한 옵션만큼 버튼에 라벨/연결을 채우고, 남는 버튼은 숨김.
# 표시할 옵션이 없을 때: 노드에 next_id가 있으면 "[계속]" 버튼으로 이어가고,
# 없으면(순수 종료 대사) 기본 "닫기" 버튼을 하나 자동으로 보여줌
func _populate_options(options: Array, default_next_id: String = "") -> void:
	var visible_options := _filter_visible_options(options)
	if visible_options.is_empty():
		if default_next_id != "":
			visible_options = [{"label": "[계속]", "next_id": default_next_id}]
		else:
			visible_options = [{"label": "닫기", "next_id": ""}]

	var buttons := _options_container.get_children()
	for i in range(buttons.size()):
		var button := buttons[i] as Button
		if button.pressed.is_connected(_on_button_pressed):
			button.pressed.disconnect(_on_button_pressed)

		if i < visible_options.size():
			var option: Dictionary = visible_options[i]
			button.text = option.get("label", "")
			button.pressed.connect(_on_button_pressed.bind(option))
			button.show()
		else:
			button.hide()


# 버튼 클릭 처리: 타이핑 중이면 텍스트만 즉시 완성하고, 다 표시된 상태면 실제로 옵션을 선택해 다음으로 진행
func _on_button_pressed(option: Dictionary) -> void:
	if _is_typing:
		_skip_typing()
	else:
		_on_option_pressed(option)


# 옵션 버튼 클릭 시, 그 옵션에 flag_to_set이 있으면 flag_value로 설정한 뒤 next_id 노드로 이동
func _on_option_pressed(option: Dictionary) -> void:
	var flag_to_set: String = option.get("flag_to_set", "")
	if flag_to_set != "":
		GameState.set_flag(flag_to_set, option.get("flag_value", false))

	_show_node(option.get("next_id", ""))


# 대화창을 숨기고, 마지막으로 보여줬던 노드 id와 함께 종료를 알림
func _end_dialogue() -> void:
	hide()
	dialogue_ended.emit(_last_shown_node_id)
