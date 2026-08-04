extends CanvasLayer

# 유서프 상점 (autoload). YUSUF_DIALOGUE의 "[물건을 산다]" 옵션이 open()으로 대화창 위에 띄운다
# (대화창은 뒤에 그대로 남아있고, Dim이 클릭을 가로채 닫기 전까지는 손댈 수 없음).
# 판매 아이템(마나/체력 포션)은 구매 즉시 소비되지 않고 인벤토리(GameState.inventory)에 추가된다.
# 가격은 두 포션 모두 동일하게 POTION_PRICE로 통일

const POTION_PRICE := 3

@onready var _root: Control = $Root
@onready var _gold_label: Label = $Root/Panel/VBox/GoldLabel
@onready var _mana_icon: TextureRect = $Root/Panel/VBox/ManaRow/ItemIcon
@onready var _mana_label: Label = $Root/Panel/VBox/ManaRow/ItemLabel
@onready var _mana_buy_button: Button = $Root/Panel/VBox/ManaRow/BuyButton
@onready var _hp_icon: TextureRect = $Root/Panel/VBox/HpRow/ItemIcon
@onready var _hp_label: Label = $Root/Panel/VBox/HpRow/ItemLabel
@onready var _hp_buy_button: Button = $Root/Panel/VBox/HpRow/BuyButton
@onready var _message_label: Label = $Root/Panel/VBox/MessageLabel
@onready var _close_button: Button = $Root/Panel/VBox/CloseButton


func _ready() -> void:
	add_to_group("shop_menu")
	_root.visible = false

	_setup_item_row("mana_potion", _mana_icon, _mana_label)
	_setup_item_row("hp_potion", _hp_icon, _hp_label)

	_mana_buy_button.pressed.connect(_on_buy_pressed.bind("mana_potion"))
	_hp_buy_button.pressed.connect(_on_buy_pressed.bind("hp_potion"))
	_close_button.pressed.connect(_on_close_pressed)
	GameState.gold_changed.connect(_on_gold_changed)


# 아이콘/설명 라벨을 ItemData 기준으로 채움 (이름+설명 조합, 가격은 공용 POTION_PRICE)
func _setup_item_row(item_id: String, icon: TextureRect, label: Label) -> void:
	var item: Dictionary = ItemData.ITEMS[item_id]
	icon.texture = ItemData.build_icon(item_id)
	label.text = "%s - %s (%d 골드)" % [item["name"], item["description"], POTION_PRICE]


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


# 골드 표시와 두 구매 버튼의 활성 상태를 현재 골드로 갱신 (부족하면 버튼 비활성화)
func _refresh() -> void:
	_gold_label.text = "보유 골드: %d" % GameState.gold
	var can_afford := GameState.gold >= POTION_PRICE
	_mana_buy_button.disabled = not can_afford
	_hp_buy_button.disabled = not can_afford


# 포션 구매: 골드 소모에 성공하면 인벤토리에 추가(즉시 소비 아님), 부족하면 안내만 표시
func _on_buy_pressed(item_id: String) -> void:
	if not GameState.spend_gold(POTION_PRICE):
		_show_message("골드가 부족합니다")
		return

	GameState.add_item(item_id, 1)
	_show_message("%s을 구매했다!" % ItemData.ITEMS[item_id]["name"])
	_refresh()


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true


func _on_close_pressed() -> void:
	close()
