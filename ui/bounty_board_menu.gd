extends CanvasLayer

const UiTranslator := preload("res://systems/ui_translator.gd")

# 의뢰판 (autoload). ELARA_DIALOGUE의 "[의뢰판을 살펴본다]" 옵션이 open()으로 대화창 위에 띄운다.
# 의뢰 3개는 GameState.bounty_board가 들고 있고(세이브 포함), 여기서는 그리기와 버튼 처리만 한다.

const SLOT_COUNT := 3

@onready var _root: Control = $Root
@onready var _gold_label: Label = $Root/Panel/VBox/GoldLabel
@onready var _slots_box: VBoxContainer = $Root/Panel/VBox/Slots
@onready var _message_label: Label = $Root/Panel/VBox/MessageLabel
@onready var _refresh_button: Button = $Root/Panel/VBox/ButtonRow/RefreshButton
@onready var _close_button: Button = $Root/Panel/VBox/ButtonRow/CloseButton

var _title_labels: Array[Label] = []
var _reward_labels: Array[Label] = []
var _accept_buttons: Array[Button] = []


func _ready() -> void:
	UiTranslator.bind(self, _refresh)
	add_to_group("bounty_board")
	_root.visible = false
	_message_label.visible = false
	_close_button.pressed.connect(_on_close_button_pressed)
	_refresh_button.pressed.connect(_on_refresh)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.sub_quest_changed.connect(_on_sub_quest_changed)
	_bind_slots()


func _bind_slots() -> void:
	for i in range(SLOT_COUNT):
		var slot := _slots_box.get_node("Slot%d" % (i + 1))
		_title_labels.append(slot.get_node("Row/Texts/TitleLabel"))
		_reward_labels.append(slot.get_node("Row/Texts/RewardLabel"))
		var button: Button = slot.get_node("Row/AcceptButton")
		button.pressed.connect(_on_accept.bind(i))
		_accept_buttons.append(button)


func open() -> void:
	_message_label.visible = false
	GameState.ensure_bounty_board()
	_refresh()
	_root.visible = true


func close() -> void:
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func _on_close_button_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	close()


func _on_gold_changed(_new_gold: int) -> void:
	if _root.visible:
		_refresh()


func _on_sub_quest_changed() -> void:
	if _root.visible:
		_refresh()


func _refresh() -> void:
	_gold_label.text = tr("보유 골드: %d") % GameState.gold
	_refresh_button.text = tr("새로고침 (%d골드)") % SubQuestData.REFRESH_COST
	_refresh_button.disabled = GameState.gold < SubQuestData.REFRESH_COST

	var board: Array = GameState.bounty_board
	var busy := GameState.has_active_sub_quest()

	for i in range(SLOT_COUNT):
		var slot := _slots_box.get_node("Slot%d" % (i + 1)) as Control
		if i >= board.size():
			slot.visible = false
			continue
		slot.visible = true

		var quest: Dictionary = board[i]
		_title_labels[i].text = SubQuestData.title(quest)
		_reward_labels[i].text = SubQuestData.describe_rewards(quest)
		_accept_buttons[i].disabled = busy

	if busy:
		_show_message(tr("이미 진행 중인 의뢰가 있어요. 먼저 마치고 오세요."))


func _on_refresh() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	if not GameState.refresh_bounty_board():
		_show_message(tr("골드가 부족해요. (%d골드 필요)") % SubQuestData.REFRESH_COST)
		return
	_show_message(tr("새 의뢰를 붙였어요."))


func _on_accept(index: int) -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	if GameState.has_active_sub_quest():
		_show_message(tr("이미 진행 중인 의뢰가 있어요. 먼저 마치고 오세요."))
		return
	if not GameState.accept_sub_quest(index):
		_show_message(tr("그 의뢰는 지금 받을 수 없어요."))
		return
	_show_message(tr("의뢰를 맡았어요. 조심히 다녀오세요."))


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true


# 열려 있을 때 ESC로 닫기 (다른 모달 메뉴들과 동일)
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
