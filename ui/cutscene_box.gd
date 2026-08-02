class_name CutsceneBox
extends Control

# 오프닝처럼 화자 표시 없이 나레이션만 순서대로 보여주는 전용 컷신 UI.
# DialogueData의 노드(id/narration or text/next_id)를 그대로 재사용하되,
# 선택지는 다루지 않고 next_id를 따라 선형으로만 진행한다.
signal cutscene_ended(last_node_id: String)

@onready var _text_label: Label = $ScrollPanel/TextLabel
@onready var _bleep_player: AudioStreamPlayer = $BleepPlayer

var _nodes_by_id: Dictionary = {}
var _last_shown_node_id: String = ""
var _typewriter: Typewriter


func _ready() -> void:
	add_to_group("cutscene_box")
	_typewriter = Typewriter.new(_text_label, _bleep_player)


# 컷신 노드 배열을 id 기준으로 인덱싱하고 start_id 노드부터 재생 시작
func start_cutscene(node_tree: Array, start_id: String) -> void:
	_nodes_by_id.clear()
	for node in node_tree:
		_nodes_by_id[node["id"]] = node

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


# 타이핑 중이면 스킵, 다 표시된 상태면 다음 노드로 진행
func _advance() -> void:
	if _typewriter.is_typing:
		_typewriter.skip()
		return

	var node: Dictionary = _nodes_by_id.get(_last_shown_node_id, {})
	_show_node(node.get("next_id", ""))


func _end_cutscene() -> void:
	hide()
	cutscene_ended.emit(_last_shown_node_id)


# 화면 아무 곳이나 클릭하면 다음으로 진행
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()
		get_viewport().set_input_as_handled()


# 키보드 아무 키나 누르면 다음으로 진행
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		_advance()
		get_viewport().set_input_as_handled()
