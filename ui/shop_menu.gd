extends CanvasLayer

# 유서프 상점 (autoload). YUSUF_DIALOGUE의 "[물건을 산다]" 옵션이 open()으로 대화창 위에 띄운다
# (대화창은 뒤에 그대로 남아있고, Dim이 클릭을 가로채 닫기 전까지는 손댈 수 없음).
# 판매 아이템은 구매 즉시 소비되지 않고 인벤토리(GameState.inventory)에 추가된다.
# 아이템별 가격은 PRICES가 정한다. [-]/[+]로 수량을 골라 한 번에 여러 개 살 수 있다

const MIN_QUANTITY := 1
# 아이템별 판매 가격 (새 판매 품목을 추가할 땐 여기에 가격만 추가)
const PRICES: Dictionary = {
	"mana_potion": 7,
	"hp_potion": 7,
	"gift": 15,
}

@onready var _root: Control = $Root
@onready var _gold_label: Label = $Root/Panel/VBox/GoldLabel
@onready var _mana_icon: TextureRect = $Root/Panel/VBox/ManaRow/TopRow/ItemIcon
@onready var _mana_label: Label = $Root/Panel/VBox/ManaRow/TopRow/ItemLabel
@onready var _mana_minus_button: Button = $Root/Panel/VBox/ManaRow/BottomRow/MinusButton
@onready var _mana_quantity_label: Label = $Root/Panel/VBox/ManaRow/BottomRow/QuantityLabel
@onready var _mana_plus_button: Button = $Root/Panel/VBox/ManaRow/BottomRow/PlusButton
@onready var _mana_total_label: Label = $Root/Panel/VBox/ManaRow/BottomRow/TotalLabel
@onready var _mana_buy_button: Button = $Root/Panel/VBox/ManaRow/BottomRow/BuyButton
@onready var _hp_icon: TextureRect = $Root/Panel/VBox/HpRow/TopRow/ItemIcon
@onready var _hp_label: Label = $Root/Panel/VBox/HpRow/TopRow/ItemLabel
@onready var _hp_minus_button: Button = $Root/Panel/VBox/HpRow/BottomRow/MinusButton
@onready var _hp_quantity_label: Label = $Root/Panel/VBox/HpRow/BottomRow/QuantityLabel
@onready var _hp_plus_button: Button = $Root/Panel/VBox/HpRow/BottomRow/PlusButton
@onready var _hp_total_label: Label = $Root/Panel/VBox/HpRow/BottomRow/TotalLabel
@onready var _hp_buy_button: Button = $Root/Panel/VBox/HpRow/BottomRow/BuyButton
@onready var _gift_icon: TextureRect = $Root/Panel/VBox/GiftRow/TopRow/ItemIcon
@onready var _gift_label: Label = $Root/Panel/VBox/GiftRow/TopRow/ItemLabel
@onready var _gift_minus_button: Button = $Root/Panel/VBox/GiftRow/BottomRow/MinusButton
@onready var _gift_quantity_label: Label = $Root/Panel/VBox/GiftRow/BottomRow/QuantityLabel
@onready var _gift_plus_button: Button = $Root/Panel/VBox/GiftRow/BottomRow/PlusButton
@onready var _gift_total_label: Label = $Root/Panel/VBox/GiftRow/BottomRow/TotalLabel
@onready var _gift_buy_button: Button = $Root/Panel/VBox/GiftRow/BottomRow/BuyButton
@onready var _message_label: Label = $Root/Panel/VBox/MessageLabel
@onready var _close_button: Button = $Root/Panel/VBox/CloseButton

# 아이템별로 현재 선택된 구매 수량 (항상 MIN_QUANTITY 이상)
var _quantities: Dictionary = {"mana_potion": MIN_QUANTITY, "hp_potion": MIN_QUANTITY, "gift": MIN_QUANTITY}


func _ready() -> void:
	add_to_group("shop_menu")
	_root.visible = false

	_setup_item_row("mana_potion", _mana_icon, _mana_label)
	_setup_item_row("hp_potion", _hp_icon, _hp_label)
	_setup_item_row("gift", _gift_icon, _gift_label)

	_mana_minus_button.pressed.connect(_on_quantity_step.bind("mana_potion", -1))
	_mana_plus_button.pressed.connect(_on_quantity_step.bind("mana_potion", 1))
	_mana_buy_button.pressed.connect(_on_buy_pressed.bind("mana_potion"))
	_hp_minus_button.pressed.connect(_on_quantity_step.bind("hp_potion", -1))
	_hp_plus_button.pressed.connect(_on_quantity_step.bind("hp_potion", 1))
	_hp_buy_button.pressed.connect(_on_buy_pressed.bind("hp_potion"))
	_gift_minus_button.pressed.connect(_on_quantity_step.bind("gift", -1))
	_gift_plus_button.pressed.connect(_on_quantity_step.bind("gift", 1))
	_gift_buy_button.pressed.connect(_on_buy_pressed.bind("gift"))
	_close_button.pressed.connect(_on_close_pressed)
	GameState.gold_changed.connect(_on_gold_changed)


# 아이템의 판매 가격 (PRICES에 없으면 0)
func _price(item_id: String) -> int:
	return PRICES.get(item_id, 0)


# 아이콘/설명 라벨을 ItemData 기준으로 채움 (이름+설명 조합, 가격은 아이템별 PRICES)
func _setup_item_row(item_id: String, icon: TextureRect, label: Label) -> void:
	var item: Dictionary = ItemData.ITEMS[item_id]
	icon.texture = ItemData.build_icon(item_id)
	label.text = "%s - %s (%d 골드)" % [item["name"], item["description"], _price(item_id)]


# 대화창에서 상점을 연다
func open() -> void:
	_message_label.visible = false
	_quantities = {"mana_potion": MIN_QUANTITY, "hp_potion": MIN_QUANTITY, "gift": MIN_QUANTITY}
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


# 현재 골드로 이 아이템을 최대 몇 개까지 살 수 있는지 (0개도 가능 — 그러면 구매 버튼이 비활성화됨)
func _max_affordable_quantity(item_id: String) -> int:
	return GameState.gold / _price(item_id)


# [-]/[+] 클릭: 수량을 바꾸되 최소 MIN_QUANTITY, 최대 "현재 골드로 살 수 있는 최대 개수"로 제한
# (골드가 부족해 최대치가 MIN_QUANTITY 미만이 되는 경우엔 그래도 MIN_QUANTITY로 표시하고,
# 실제 구매 가능 여부는 구매 버튼 비활성화로 따로 안내한다)
func _on_quantity_step(item_id: String, delta: int) -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	var max_q: int = max(MIN_QUANTITY, _max_affordable_quantity(item_id))
	var new_qty: int = clampi(_quantities[item_id] + delta, MIN_QUANTITY, max_q)
	_quantities[item_id] = new_qty
	_refresh()


# 골드 표시, 각 아이템의 수량 표시/총가격/구매 가능 여부를 전부 현재 상태로 갱신.
# 골드가 줄어들어(다른 아이템 구매 등) 이미 선택된 수량을 더는 감당 못 하면 자동으로 낮춘다
func _refresh() -> void:
	_gold_label.text = "보유 골드: %d" % GameState.gold

	for item_id in _quantities.keys():
		var max_q: int = max(MIN_QUANTITY, _max_affordable_quantity(item_id))
		_quantities[item_id] = clampi(_quantities[item_id], MIN_QUANTITY, max_q)

	_update_row(_mana_quantity_label, _mana_total_label, _mana_buy_button, "mana_potion")
	_update_row(_hp_quantity_label, _hp_total_label, _hp_buy_button, "hp_potion")
	_update_row(_gift_quantity_label, _gift_total_label, _gift_buy_button, "gift")


func _update_row(quantity_label: Label, total_label: Label, buy_button: Button, item_id: String) -> void:
	var qty: int = _quantities[item_id]
	var total: int = qty * _price(item_id)
	quantity_label.text = str(qty)
	total_label.text = "총 %d 골드" % total
	buy_button.disabled = GameState.gold < total


# 선택한 수량만큼 한 번에 구매: 골드를 소모(성공 시 인벤토리에 그만큼 추가), 부족하면 안내만 표시
func _on_buy_pressed(item_id: String) -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	var qty: int = _quantities[item_id]
	var total: int = qty * _price(item_id)
	if not GameState.spend_gold(total):
		_show_message("골드가 부족합니다")
		return

	GameState.add_item(item_id, qty)
	_show_message("%s을(를) %d개 구매했다!" % [ItemData.ITEMS[item_id]["name"], qty])
	_quantities[item_id] = MIN_QUANTITY
	_refresh()


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true


func _on_close_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	close()
