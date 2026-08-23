class_name CutsceneBox
extends Control

# 오프닝처럼 화자 표시 없이 나레이션만 순서대로 보여주는 전용 컷신 UI(이미지 슬라이드쇼 방식).
# DialogueData의 노드(id/narration or text/next_id/image)를 그대로 재사용하되,
# 선택지는 다루지 않고 next_id를 따라 선형으로만 진행한다.
# 노드에 "image"가 있고 현재 배경과 다르면 FadeOverlay로 검은 페이드를 감싸 배경을 바꾼다.
# "image"가 없으면(또는 현재와 같으면) 배경은 그대로 두고 텍스트만 이어서 보여준다.
signal cutscene_ended(last_node_id: String)

@onready var _background_image: TextureRect = $BackgroundImage
@onready var _text_label: Label = $TextPanel/TextLabel
@onready var _bleep_player: AudioStreamPlayer = $BleepPlayer
@onready var _skip_button: Button = $SkipButton
@onready var _confirm_popup: Control = $ConfirmPopup
@onready var _confirm_yes_button: Button = $ConfirmPopup/Panel/VBox/ButtonRow/YesButton
@onready var _confirm_no_button: Button = $ConfirmPopup/Panel/VBox/ButtonRow/NoButton

var _nodes_by_id: Dictionary = {}
var _last_shown_node_id: String = ""
var _typewriter: Typewriter
var _confirm_open: bool = false # 스킵 확인 팝업이 떠 있는 동안은 클릭/키 입력으로 컷신이 진행되지 않게 막음
var _finished: bool = false # 이번 재생이 이미 끝났는지 (cutscene_ended를 놓친 쪽이 확인할 수 있게 남겨둠)
var _current_image_path: String = "" # 지금 배경으로 걸려 있는 이미지 경로 (다음 노드와 비교해 전환 여부 판단)
var _transitioning: bool = false # 배경 이미지가 페이드로 바뀌는 동안 입력을 막음


func _ready() -> void:
	add_to_group("cutscene_box")
	# start_cutscene() 전까지는 확실히 숨어 있게 한다. 씬 파일에 저장된 visible 값에 기대면
	# 편집기에서 눈 아이콘을 켠 채 저장되는 순간 컷신이 시작되기도 전에 화면에 뜨고,
	# 스킵 버튼까지 눌리게 된다 (실제로 그렇게 저장돼 오프닝이 멈춘 적이 있다)
	hide()
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

	_current_image_path = ""
	_confirm_open = false
	_finished = false
	_confirm_popup.hide()
	show()
	_show_node(start_id)


# 이번 재생이 이미 끝났는지. cutscene_ended는 한 번 지나가면 다시 오지 않으므로,
# 신호를 기다리기 전에 이걸로 "이미 끝난 뒤인지"를 확인할 수 있다
func is_finished() -> bool:
	return _finished


# 주어진 id의 노드를 표시 (id가 없거나 빈 문자열이면 컷신 종료).
# 배경 전환이 필요하면 먼저 끝날 때까지 기다린 뒤 텍스트 타이핑을 시작한다
func _show_node(node_id: String) -> void:
	if node_id == "" or not _nodes_by_id.has(node_id):
		_end_cutscene()
		return

	_last_shown_node_id = node_id
	var node: Dictionary = _nodes_by_id[node_id]
	await _apply_image(node)

	var narration: String = node.get("narration", "")
	_typewriter.start(narration if narration != "" else node.get("text", ""))


# node에 새 배경 이미지가 지정돼 있고 현재 배경과 다르면 교체한다.
# 첫 이미지(컷신 시작 직후)는 페이드 없이 즉시 세팅 — 바깥의 SceneManager 진입 페이드가 이미 가려준다.
# 그 뒤로 배경이 바뀔 때만 FadeOverlay로 검게 감싸 전환한다
func _apply_image(node: Dictionary) -> void:
	var path: String = node.get("image", "")
	if path == "" or path == _current_image_path:
		return

	if _current_image_path == "":
		_background_image.texture = load(path)
		_current_image_path = path
		return

	_transitioning = true
	await FadeOverlay.fade_out()
	_background_image.texture = load(path)
	_current_image_path = path
	await FadeOverlay.fade_in()
	_transitioning = false


# 타이핑 중이면 스킵, 다 표시된 상태면 다음 노드로 진행 (확인 팝업/배경 전환 중엔 아무것도 안 함)
func _advance() -> void:
	if _confirm_open or _transitioning:
		return
	if _typewriter.is_typing:
		_typewriter.skip()
		return

	var node: Dictionary = _nodes_by_id.get(_last_shown_node_id, {})
	_show_node(node.get("next_id", ""))


func _end_cutscene() -> void:
	_finished = true
	hide()
	cutscene_ended.emit(_last_shown_node_id)


# "스킵" 버튼: 바로 스킵하지 않고 확인 팝업부터 띄움 (배경 전환 중엔 무시)
func _on_skip_pressed() -> void:
	if _transitioning:
		return
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_confirm_open = true
	_confirm_popup.show()


# "예": 오프닝 전체를 즉시 종료
func _on_confirm_yes() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_confirm_open = false
	_confirm_popup.hide()
	_end_cutscene()


# "아니요": 팝업만 닫고 컷신은 계속 재생
func _on_confirm_no() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
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
