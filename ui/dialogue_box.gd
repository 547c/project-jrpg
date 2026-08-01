class_name DialogueBox
extends Control

# 대화가 완전히 종료되었을 때 발행 (NPC 등이 구독해 안내 UI를 복원하는 등에 사용)
signal dialogue_ended

const MAX_OPTIONS := 4

@onready var _panel: Panel = $Panel
@onready var _speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var _text_label: Label = $Panel/VBox/TextLabel
@onready var _options_container: VBoxContainer = $Panel/VBox/OptionsContainer

var _normal_style: StyleBoxFlat
var _decisive_style: StyleBoxFlat
var _nodes_by_id: Dictionary = {}


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

	var node: Dictionary = _nodes_by_id[node_id]
	var is_decisive: bool = node.get("is_decisive", false)

	_speaker_label.text = node.get("speaker", "")
	_text_label.text = _resolve_text(node)
	_panel.add_theme_stylebox_override("panel", _decisive_style if is_decisive else _normal_style)

	_populate_options(node.get("options", []))


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
# 표시할 옵션이 하나도 없으면(순수 종료 대사) 기본 "닫기" 버튼을 하나 자동으로 보여줌
func _populate_options(options: Array) -> void:
	var visible_options := _filter_visible_options(options)
	if visible_options.is_empty():
		visible_options = [{"label": "닫기", "next_id": ""}]

	var buttons := _options_container.get_children()
	for i in range(buttons.size()):
		var button := buttons[i] as Button
		if button.pressed.is_connected(_on_option_pressed):
			button.pressed.disconnect(_on_option_pressed)

		if i < visible_options.size():
			var option: Dictionary = visible_options[i]
			button.text = option.get("label", "")
			button.pressed.connect(_on_option_pressed.bind(option))
			button.show()
		else:
			button.hide()


# 옵션 버튼 클릭 시, 그 옵션에 flag_to_set이 있으면 flag_value로 설정한 뒤 next_id 노드로 이동
func _on_option_pressed(option: Dictionary) -> void:
	var flag_to_set: String = option.get("flag_to_set", "")
	if flag_to_set != "":
		GameState.set_flag(flag_to_set, option.get("flag_value", false))

	_show_node(option.get("next_id", ""))


# 대화창을 숨기고 종료를 알림
func _end_dialogue() -> void:
	hide()
	dialogue_ended.emit()
