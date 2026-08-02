class_name CutsceneBox
extends Control

# 오프닝처럼 화자 표시 없이 나레이션만 순서대로 보여주는 전용 컷신 UI.
# DialogueData의 노드(id/narration or text/next_id)를 그대로 재사용하되,
# 선택지는 다루지 않고 next_id를 따라 선형으로만 진행한다.
signal cutscene_ended(last_node_id: String)

@onready var _text_label: Label = $ScrollPanel/TextLabel
@onready var _bleep_player: AudioStreamPlayer = $BleepPlayer
@onready var _skip_button: Button = $SkipButton
@onready var _confirm_popup: Control = $ConfirmPopup
@onready var _confirm_yes_button: Button = $ConfirmPopup/Panel/VBox/ButtonRow/YesButton
@onready var _confirm_no_button: Button = $ConfirmPopup/Panel/VBox/ButtonRow/NoButton

var _nodes_by_id: Dictionary = {}
var _last_shown_node_id: String = ""
var _typewriter: Typewriter
var _confirm_open: bool = false # 스킵 확인 팝업이 떠 있는 동안은 클릭/키 입력으로 컷신이 진행되지 않게 막음


func _ready() -> void:
	add_to_group("cutscene_box")
	_typewriter = Typewriter.new(_text_label, _bleep_player)
	_skip_button.pressed.connect(_on_skip_pressed)
	_confirm_yes_button.pressed.connect(_on_confirm_yes)
	_confirm_no_button.pressed.connect(_on_confirm_no)
	_confirm_popup.hide()


# 컷신 노드 배열을 id 기준으로 인덱싱하고 start_id 노드부터 재생 시작
func start_cutscene(node_tree: Array, start_id: String) -> void:
	_nodes_by_id.clear()
	for node in node_tree:
		_nodes_by_id[node["id"]] = node

	_confirm_open = false
	_confirm_popup.hide()
	show()
	_show_node(start_id)


# 주어진 id의 노드를 표시 (id가 없거나 빈 문자열이면 컷신 종료)
func _show_node(node_id: String) -> void:
	if node_id == "" or not _nodes_by_id.has(node_id):
		_end_cutscene()
		return

	_last_shown_node_id = node_id
	var node: Dictionary = _nodes_by_id[node_id]
	var narration: String = node.get("narration", "")
	_typewriter.start(narration if narration != "" else node.get("text", ""))


# 타이핑 중이면 스킵, 다 표시된 상태면 다음 노드로 진행 (확인 팝업이 떠 있으면 아무것도 안 함)
func _advance() -> void:
	if _confirm_open:
		return
	if _typewriter.is_typing:
		_typewriter.skip()
		return

	var node: Dictionary = _nodes_by_id.get(_last_shown_node_id, {})
	_show_node(node.get("next_id", ""))


func _end_cutscene() -> void:
	hide()
	cutscene_ended.emit(_last_shown_node_id)


# "스킵" 버튼: 바로 스킵하지 않고 확인 팝업부터 띄움
func _on_skip_pressed() -> void:
	_confirm_open = true
	_confirm_popup.show()


# "예": 오프닝 전체를 즉시 종료
func _on_confirm_yes() -> void:
	_confirm_open = false
	_confirm_popup.hide()
	_end_cutscene()


# "아니요": 팝업만 닫고 컷신은 계속 재생
func _on_confirm_no() -> void:
	_confirm_open = false
	_confirm_popup.hide()


# 화면 아무 곳이나 클릭하면 다음으로 진행 (확인 팝업 위 버튼 클릭은 버튼이 먼저 소비하므로 여기까지 안 옴)
func _gui_input(event: InputEvent) -> void:
	if _confirm_open:
		return
	if event is InputEventMouseButton and event.pressed:
		_advance()
		get_viewport().set_input_as_handled()


# 키보드 아무 키나 누르면 다음으로 진행
func _unhandled_input(event: InputEvent) -> void:
	if _confirm_open:
		return
	if visible and event is InputEventKey and event.pressed and not event.echo:
		_advance()
		get_viewport().set_input_as_handled()
