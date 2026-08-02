extends CanvasLayer

# ESC로 토글되는 일시정지 메뉴 (autoload). 씬마다 배치할 필요 없이 항상 최상단에 떠 있다.
# _root(Control)는 "pause_menu" 그룹에 속하고 visible로 열림 여부를 나타내, 플레이어 이동 잠금과 연동된다.

@onready var _root: Control = $Root
@onready var _continue_button: Button = $Root/Panel/VBox/ContinueButton
@onready var _save_button: Button = $Root/Panel/VBox/SaveButton
@onready var _load_button: Button = $Root/Panel/VBox/LoadButton
@onready var _title_button: Button = $Root/Panel/VBox/TitleButton
@onready var _toast: Label = $Root/Panel/VBox/Toast


func _ready() -> void:
	_root.visible = false
	_toast.visible = false
	_continue_button.pressed.connect(_on_continue)
	_save_button.pressed.connect(_on_save)
	_load_button.pressed.connect(_on_load)
	_title_button.pressed.connect(_on_title)


# ESC 입력을 GUI보다 먼저 가로채(_input) 메뉴를 토글. 열려 있으면 항상 닫고, 닫혀 있으면 조건이 될 때만 연다
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _root.visible:
		_close()
		get_viewport().set_input_as_handled()
	elif _can_open():
		_open()
		get_viewport().set_input_as_handled()


# 대화/전투/게임오버가 떠 있거나, 게임 진행 중(플레이어 존재)이 아니거나, 엔딩 씬이면 열지 않음
func _can_open() -> bool:
	if not SceneManager.has_player():
		return false
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.begins_with("res://endings/"):
		return false
	for group in ["dialogue_box", "battle_box", "game_over"]:
		var ui := get_tree().get_first_node_in_group(group) as CanvasItem
		if ui != null and ui.visible:
			return false
	return true


func _open() -> void:
	_toast.visible = false
	_root.visible = true


func _close() -> void:
	_root.visible = false


func _on_continue() -> void:
	_close()


func _on_save() -> void:
	if SaveManager.save_game():
		_show_toast("저장 완료")
	else:
		_show_toast("저장에 실패했습니다")


func _on_load() -> void:
	if SaveManager.has_save():
		_close()
		SaveManager.load_game()
	else:
		_show_toast("저장된 게임이 없습니다")


func _on_title() -> void:
	_close()
	SceneManager.return_to_title()


# 짧은 안내 문구를 잠깐 보여줬다 숨김
func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	await get_tree().create_timer(1.5).timeout
	_toast.visible = false
