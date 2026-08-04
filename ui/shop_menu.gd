extends CanvasLayer

# 유서프 상점 (autoload). YUSUF_DIALOGUE의 "[물건을 산다]" 옵션이 open()으로 대화창 위에 띄운다
# (대화창은 뒤에 그대로 남아있고, Dim이 클릭을 가로채 닫기 전까지는 손댈 수 없음).
# 판매 아이템은 마나 포션 1종류뿐: 구매 즉시 소비되지 않고 인벤토리(GameState.inventory)에 추가된다.

const MANA_POTION_PRICE := 3

@onready var _root: Control = $Root
@onready var _gold_label: Label = $Root/Panel/VBox/GoldLabel
@onready var _item_icon: TextureRect = $Root/Panel/VBox/ItemRow/ItemIcon
@onready var _item_label: Label = $Root/Panel/VBox/ItemRow/ItemLabel
@onready var _buy_button: Button = $Root/Panel/VBox/ItemRow/BuyButton
@onready var _message_label: Label = $Root/Panel/VBox/MessageLabel
@onready var _close_button: Button = $Root/Panel/VBox/CloseButton


func _ready() -> void:
	add_to_group("shop_menu")
	_root.visible = false

	var item: Dictionary = ItemData.ITEMS["mana_potion"]
	_item_icon.texture = ItemData.build_icon("mana_potion")
	_item_label.text = "%s - %s (%d 골드)" % [item["name"], item["description"], MANA_POTION_PRICE]

	_buy_button.pressed.connect(_on_buy_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	GameState.gold_changed.connect(_on_gold_changed)


# 대화창에서 상점을 연다
func open() -> void:
	_message_label.visible = false
	_refresh()
	_root.visible = true


func close() -> void:
	_root.visible = false


func is_open() -> bool:
	return _root.visible


# 골드가 바뀔 때(구매 등) 열려 있는 동안에만 즉시 반영
func _on_gold_changed(_new_gold: int) -> void:
	if _root.visible:
		_refresh()


# 골드 표시와 구매 버튼 활성 상태를 현재 골드로 갱신 (부족하면 버튼 비활성화)
func _refresh() -> void:
	_gold_label.text = "보유 골드: %d" % GameState.gold
	_buy_button.disabled = GameState.gold < MANA_POTION_PRICE


# 마나 포션 구매: 골드 소모에 성공하면 인벤토리에 추가(즉시 소비 아님), 부족하면 안내만 표시
func _on_buy_pressed() -> void:
	if not GameState.spend_gold(MANA_POTION_PRICE):
		_show_message("골드가 부족합니다")
		return

	GameState.add_item("mana_potion", 1)
	_show_message("마나 포션을 구매했다!")
	_refresh()


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true


func _on_close_pressed() -> void:
	close()
