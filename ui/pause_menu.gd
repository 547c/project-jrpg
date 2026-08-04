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


# ESC 입력을 GUI보다 먼저 가로채(_input) 메뉴를 토글. 열려 있으면 항상 닫고, 닫혀 있으면 조건이 될 때만 연다.
# 슬롯 메뉴가 위에 떠 있으면 그쪽이 ESC를 처리하도록 양보한다
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if SaveSlotMenu.is_open():
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
	for group in ["dialogue_box", "battle_box", "game_over", "quest_log", "level_up", "inventory_menu"]:
		var ui := get_tree().get_first_node_in_group(group) as CanvasItem
		if ui != null and ui.visible:
			return false
	return true


func _open() -> void:
	_toast.visible = false
	_root.visible = true


func _close() -> void:
	_root.visible = false


# 외부(슬롯 메뉴 로드 성공 시)에서 일시정지 메뉴를 강제로 닫을 때 사용
func dismiss() -> void:
	_root.visible = false


func _on_continue() -> void:
	_close()


# 저장/불러오기는 슬롯 선택 메뉴를 띄운다 (일시정지 메뉴는 뒤에 그대로 유지 → 닫기 시 복귀)
func _on_save() -> void:
	SaveSlotMenu.open_save_mode()


func _on_load() -> void:
	SaveSlotMenu.open_load_mode()


func _on_title() -> void:
	_close()
	SceneManager.return_to_title()
