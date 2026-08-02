class_name DialogueBox
extends Control

# 대화가 완전히 종료되었을 때 발행. last_node_id는 종료 직전 마지막으로 보여준 노드의 id
# (구독자가 "어떤 대사에서 끝났는지"로 특별 처리를 하고 싶을 때 사용 — 예: 엔딩 트리거)
signal dialogue_ended(last_node_id: String)

const MAX_OPTIONS := 5
const MIN_PANEL_HEIGHT := 180.0 # 화자 + 본문 한두 줄 + 옵션 1개 정도가 들어가는 최소 높이
const MAX_PANEL_HEIGHT := 440.0 # 옵션 4개가 다 보여도 화면 안에 들어오는 최대 높이

@onready var _decisive_frame: Control = $DecisiveFrame
@onready var _vbox: VBoxContainer = $Panel/VBox
@onready var _speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var _narration_label: Label = $Panel/VBox/NarrationLabel
@onready var _text_label: Label = $Panel/VBox/TextLabel
@onready var _options_container: VBoxContainer = $Panel/VBox/OptionsContainer
@onready var _bleep_player: AudioStreamPlayer = $BleepPlayer

var _nodes_by_id: Dictionary = {}
var _last_shown_node_id: String = ""
var _typewriter: Typewriter


# 다른 씬에서 이 DialogueBox를 찾을 수 있도록 그룹에 등록하고 공용 타이핑 헬퍼를 준비
func _ready() -> void:
	add_to_group("dialogue_box")
	_typewriter = Typewriter.new(_text_label, _bleep_player)


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

	_decisive_frame.visible = is_decisive
	_typewriter.start(_resolve_text(node))

	_populate_options(node.get("options", []), node.get("next_id", ""))
	_update_panel_height()


# 화자/지문/본문/옵션 개수에 맞춰 대화창 높이를 동적으로 조절.
# 화면 하단(offset_bottom)은 고정한 채 위쪽으로만 자라나게(offset_top만 변경) 해서
# 옵션이 적을 땐 화면을 덜 가리고, 옵션 4개일 때도 화면 밖으로 잘리지 않게 함
func _update_panel_height() -> void:
	await get_tree().process_frame # 버튼 표시/숨김이 반영된 뒤의 실제 최소 크기를 읽기 위해 한 프레임 대기

	var vbox_padding: float = _vbox.offset_top - _vbox.offset_bottom # VBox의 상하 여백(Panel 기준)
	var content_height: float = _vbox.get_combined_minimum_size().y + vbox_padding
	var target_height: float = clampf(content_height, MIN_PANEL_HEIGHT, MAX_PANEL_HEIGHT)

	offset_top = offset_bottom - target_height


# text_if_flag가 있으면 해당 flag 값에 따라 text(참)/text_false(거짓)를 골라 반환, 없으면 text 그대로
func _resolve_text(node: Dictionary) -> String:
	var text_if_flag: String = node.get("text_if_flag", "")
	if text_if_flag == "":
		return node.get("text", "")
	return node.get("text", "") if GameState.get_flag(text_if_flag) else node.get("text_false", "")


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
	if _typewriter.is_typing:
		_typewriter.skip()
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
