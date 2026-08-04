extends CanvasLayer

# ESC로 토글되는 일시정지 메뉴 (autoload). 씬마다 배치할 필요 없이 항상 최상단에 떠 있다.
# _root(Control)는 "pause_menu" 그룹에 속하고 visible로 열림 여부를 나타내, 플레이어 이동 잠금과 연동된다.

# 음소거 아이콘은 켜짐 아이콘과 같은 시트에서 다른 영역을 잘라 씀 (켜짐 쪽은 .tscn에 이미 배치돼 있음)
const SOUND_MUTED_REGION := Rect2(801, 483, 13, 12)

@onready var _root: Control = $Root
@onready var _continue_button: Button = $Root/Panel/VBox/ContinueButton
@onready var _save_button: Button = $Root/Panel/VBox/SaveButton
@onready var _load_button: Button = $Root/Panel/VBox/LoadButton
@onready var _title_button: Button = $Root/Panel/VBox/TitleButton
@onready var _music_button: Button = $Root/Panel/VBox/MusicButton
@onready var _music_icon: TextureRect = $Root/Panel/VBox/MusicButton/Icon
@onready var _toast: Label = $Root/Panel/VBox/Toast

var _sound_on_icon: AtlasTexture
var _sound_muted_icon: AtlasTexture


func _ready() -> void:
	_root.visible = false
	_toast.visible = false
	_continue_button.pressed.connect(_on_continue)
	_save_button.pressed.connect(_on_save)
	_load_button.pressed.connect(_on_load)
	_title_button.pressed.connect(_on_title)
	_music_button.pressed.connect(_on_music_toggle)

	_sound_on_icon = _music_icon.texture as AtlasTexture
	_sound_muted_icon = AtlasTexture.new()
	_sound_muted_icon.atlas = _sound_on_icon.atlas
	_sound_muted_icon.region = SOUND_MUTED_REGION


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
	_refresh_music_button()
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


# 음악 켜기/끄기 토글: 누를 때마다 상태를 뒤집고 버튼 텍스트/아이콘을 현재 상태에 맞게 갱신
func _on_music_toggle() -> void:
	MusicManager.toggle_mute()
	_refresh_music_button()


# 버튼 텍스트/아이콘을 MusicManager의 현재 음소거 상태와 일치시킴.
# 음악이 꺼진 상태면(뮤트) "음악 켜기"로, 켜진 상태면 "음악 끄기"로 표시(눌렀을 때 벌어질 동작을 안내)
func _refresh_music_button() -> void:
	if MusicManager.is_muted():
		_music_button.text = "  음악 켜기"
		_music_icon.texture = _sound_muted_icon
	else:
		_music_button.text = "  음악 끄기"
		_music_icon.texture = _sound_on_icon
