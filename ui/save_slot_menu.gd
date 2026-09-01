extends CanvasLayer

# 5슬롯 저장/불러오기 선택 UI (autoload). PauseMenu / TitleScreen / GameOverScreen에서
# open_save_mode() / open_load_mode()로 띄운다. 이전 메뉴 위에 모달로 뜨고, 닫기 시 그대로 복귀.
# 로드 성공 시 self와 pause/game_over 메뉴를 모두 닫고 게임으로 진입한다.

const SLOT_COUNT := 5

@onready var _root: Control = $Root
@onready var _title_label: Label = $Root/Panel/VBox/TitleLabel
@onready var _close_button: Button = $Root/Panel/VBox/CloseButton
@onready var _toast: Label = $Root/Panel/VBox/Toast
@onready var _confirm_popup: Control = $Root/ConfirmPopup
@onready var _confirm_yes: Button = $Root/ConfirmPopup/Panel/VBox/ButtonRow/YesButton
@onready var _confirm_no: Button = $Root/ConfirmPopup/Panel/VBox/ButtonRow/NoButton

var _mode: String = "save" # "save" 또는 "load"
var _pending_save_slot: int = -1 # 덮어쓰기 확인 대기 중인 슬롯
var _slot_buttons: Array = []


func _ready() -> void:
	_root.visible = false
	_confirm_popup.visible = false
	_toast.visible = false

	_close_button.pressed.connect(_on_close_button_pressed)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_on_confirm_no)

	for i in range(SLOT_COUNT):
		var slot_num := i + 1
		var btn: Button = $Root/Panel/VBox.get_node("Slot%d" % slot_num)
		_slot_buttons.append(btn)
		btn.pressed.connect(_on_slot_pressed.bind(slot_num))


func open_save_mode() -> void:
	_mode = "save"
	_title_label.text = tr("저장하기")
	_open()


func open_load_mode() -> void:
	_mode = "load"
	_title_label.text = tr("불러오기")
	_open()


func is_open() -> bool:
	return _root.visible


func close() -> void:
	_confirm_popup.visible = false
	_pending_save_slot = -1
	_root.visible = false


# 닫기 버튼 전용 래퍼 — close()는 로드 성공 시 다른 곳에서도 조용히(소리 없이) 호출되므로,
# 클릭 소리는 사용자가 버튼을 직접 눌렀을 때만 나야 해서 여기 한 겹을 둔다
func _on_close_button_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	close()


func _open() -> void:
	_confirm_popup.visible = false
	_toast.visible = false
	_pending_save_slot = -1
	_refresh_slots()
	_root.visible = true


# 5개 슬롯 버튼의 라벨/활성화 상태를 현재 저장 요약으로 갱신
func _refresh_slots() -> void:
	var summaries := SaveManager.get_all_save_summaries()
	for i in range(SLOT_COUNT):
		var slot_num := i + 1
		var summary: Dictionary = summaries[i]
		var btn: Button = _slot_buttons[i]
		if summary.is_empty():
			btn.text = tr("슬롯 %d\n비어있음") % slot_num
			btn.disabled = (_mode == "load") # 불러오기 모드에선 빈 슬롯 선택 불가
		else:
			btn.text = tr("슬롯 %d    Lv. %d    HP: %d/%d\n%s") % [
				slot_num, summary["progress"], summary["player_hp"], summary["player_max_hp"], summary["objective_text"],
			]
			btn.disabled = false


# 슬롯 클릭: 불러오기 모드면 로드, 저장 모드면 (데이터 있으면 확인 팝업, 없으면 바로 저장)
func _on_slot_pressed(slot_num: int) -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	if _mode == "load":
		_do_load(slot_num)
	elif SaveManager.has_save(slot_num):
		_pending_save_slot = slot_num
		_confirm_popup.visible = true
	else:
		_do_save(slot_num)


func _do_save(slot_num: int) -> void:
	if SaveManager.save_game(slot_num):
		_refresh_slots()
		_show_toast(tr("슬롯 %d에 저장했습니다") % slot_num)
	else:
		_show_toast(tr("저장에 실패했습니다"))


func _do_load(slot_num: int) -> void:
	if SaveManager.load_game(slot_num):
		_finish_load()


# 로드 성공: 슬롯 메뉴와 그 아래 메뉴(pause/game_over)를 모두 닫고 게임으로 진입
func _finish_load() -> void:
	close()
	PauseMenu.dismiss()
	GameOverScreen.dismiss()


func _on_confirm_yes() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_confirm_popup.visible = false
	var slot := _pending_save_slot
	_pending_save_slot = -1
	if slot > 0:
		_do_save(slot)


func _on_confirm_no() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_confirm_popup.visible = false
	_pending_save_slot = -1


# 열려 있을 때 ESC: 확인 팝업이 떠 있으면 팝업만 닫고, 아니면 메뉴를 닫는다
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		if _confirm_popup.visible:
			_on_confirm_no()
		else:
			close()
		get_viewport().set_input_as_handled()


# 짧은 안내 문구를 잠깐 보여줬다 숨김
func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	await get_tree().create_timer(1.5).timeout
	_toast.visible = false
