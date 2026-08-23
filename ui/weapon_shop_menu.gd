extends CanvasLayer

# 카심의 무기점 (autoload). KASIM_DIALOGUE의 "[물건을 산다]" 옵션이 open()으로 대화창 위에 띄운다.
# 기존 ShopMenu(포션/선물, 3개 고정 행)와 같은 구조·구매 흐름을 따르되, 장비 9종을 3개씩
# 페이지로 나눠 보여준다는 점만 다르다. shop_menu.gd는 건드리지 않고 완전히 별도로 둔다.
#
# ITEM_ORDER를 슬롯별로 3개씩 묶어(검/지팡이/방패) 자연스러운 페이지 구성이 되게 했다 —
# 1페이지 검 3종, 2페이지 지팡이 3종, 3페이지 방패 3종. 등급별 가격은 PRICE_BY_TIER 하나로
# 관리해 나무/뼈/금마다 개별 가격을 일일이 나열하지 않는다.

const MIN_QUANTITY := 1
const ROWS_PER_PAGE := 3

const ITEM_ORDER: Array[String] = [
	"wooden_sword", "bone_sword", "gold_sword",
	"wooden_staff", "bone_staff", "gold_staff",
	"wooden_shield", "bone_shield", "gold_shield",
]

# 등급별 가격 (검/지팡이/방패 공통 — 나무 10 / 뼈 20 / 금 30)
const PRICE_BY_TIER: Dictionary = {
	"wood": 10,
	"bone": 20,
	"gold": 30,
}

@onready var _root: Control = $Root
@onready var _gold_label: Label = $Root/Panel/VBox/GoldLabel
@onready var _page_label: Label = $Root/Panel/VBox/PageRow/PageLabel
@onready var _prev_button: Button = $Root/Panel/VBox/PageRow/PrevButton
@onready var _next_button: Button = $Root/Panel/VBox/PageRow/NextButton
@onready var _message_label: Label = $Root/Panel/VBox/MessageLabel
@onready var _close_button: Button = $Root/Panel/VBox/CloseButton

# 행 3개의 자식 노드 참조를 배열로 모아둠 (인덱스 0~2 = 화면상 위~아래 행)
var _row_icons: Array[TextureRect] = []
var _row_labels: Array[Label] = []
var _row_minus: Array[Button] = []
var _row_qty_labels: Array[Label] = []
var _row_plus: Array[Button] = []
var _row_total_labels: Array[Label] = []
var _row_buy: Array[Button] = []

var _page: int = 0
# 아이템별 현재 선택된 구매 수량 (페이지를 넘겨도 유지 — 다시 돌아왔을 때 골라둔 수량이 남아있게)
var _quantities: Dictionary = {}


func _ready() -> void:
	add_to_group("weapon_shop_menu")
	_root.visible = false

	for i in range(ROWS_PER_PAGE):
		var row := $Root/Panel/VBox.get_node("Row%d" % i)
		_row_icons.append(row.get_node("TopRow/ItemIcon"))
		_row_labels.append(row.get_node("TopRow/ItemLabel"))
		_row_minus.append(row.get_node("BottomRow/MinusButton"))
		_row_qty_labels.append(row.get_node("BottomRow/QuantityLabel"))
		_row_plus.append(row.get_node("BottomRow/PlusButton"))
		_row_total_labels.append(row.get_node("BottomRow/TotalLabel"))
		_row_buy.append(row.get_node("BottomRow/BuyButton"))

		_row_minus[i].pressed.connect(_on_quantity_step.bind(i, -1))
		_row_plus[i].pressed.connect(_on_quantity_step.bind(i, 1))
		_row_buy[i].pressed.connect(_on_buy_pressed.bind(i))

	_prev_button.pressed.connect(_on_prev_page)
	_next_button.pressed.connect(_on_next_page)
	_close_button.pressed.connect(_on_close_pressed)
	GameState.gold_changed.connect(_on_gold_changed)


func _total_pages() -> int:
	return int(ceil(float(ITEM_ORDER.size()) / ROWS_PER_PAGE))


# 아이템의 판매 가격 (등급 기반 — PRICE_BY_TIER에 없는 등급이면 0)
func _price(item_id: String) -> int:
	return PRICE_BY_TIER.get(ItemData.get_tier(item_id), 0)


# 현재 페이지에 표시할 아이템 id 목록 (마지막 페이지가 3개 미만이어도 안전)
func _items_on_page() -> Array[String]:
	var start := _page * ROWS_PER_PAGE
	var result: Array[String] = []
	for i in range(start, mini(start + ROWS_PER_PAGE, ITEM_ORDER.size())):
		result.append(ITEM_ORDER[i])
	return result


func open() -> void:
	_page = 0
	_quantities.clear()
	for item_id in ITEM_ORDER:
		_quantities[item_id] = MIN_QUANTITY
	_message_label.visible = false
	_refresh()
	_root.visible = true


func close() -> void:
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func _on_gold_changed(_new_gold: int) -> void:
	if _root.visible:
		_refresh()


# 현재 골드로 이 아이템을 최대 몇 개까지 살 수 있는지 (기존 ShopMenu와 동일한 계산 방식)
func _max_affordable_quantity(item_id: String) -> int:
	var price := _price(item_id)
	if price <= 0:
		return MIN_QUANTITY
	return GameState.gold / price


func _on_quantity_step(row: int, delta: int) -> void:
	var items := _items_on_page()
	if row >= items.size():
		return
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	var item_id := items[row]
	var max_q: int = max(MIN_QUANTITY, _max_affordable_quantity(item_id))
	_quantities[item_id] = clampi(_quantities.get(item_id, MIN_QUANTITY) + delta, MIN_QUANTITY, max_q)
	_refresh()


func _on_prev_page() -> void:
	if _page <= 0:
		return
	SFXPlayer.play(SFXPlayer.PAGE_TURN_SOUND)
	_page -= 1
	_message_label.visible = false
	_refresh()


func _on_next_page() -> void:
	if _page >= _total_pages() - 1:
		return
	SFXPlayer.play(SFXPlayer.PAGE_TURN_SOUND)
	_page += 1
	_message_label.visible = false
	_refresh()


# 골드/페이지 표시, 각 행의 아이템 정보·수량·총가격·구매 가능 여부를 전부 현재 상태로 갱신
func _refresh() -> void:
	_gold_label.text = "보유 골드: %d" % GameState.gold
	_page_label.text = "%d/%d" % [_page + 1, _total_pages()]
	_prev_button.disabled = _page <= 0
	_next_button.disabled = _page >= _total_pages() - 1

	var items := _items_on_page()
	for i in range(ROWS_PER_PAGE):
		if i >= items.size():
			_row_icons[i].visible = false
			_row_labels[i].text = ""
			_row_minus[i].visible = false
			_row_qty_labels[i].visible = false
			_row_plus[i].visible = false
			_row_total_labels[i].visible = false
			_row_buy[i].visible = false
			continue

		var item_id: String = items[i]
		var item: Dictionary = ItemData.ITEMS[item_id]
		var price := _price(item_id)

		var max_q: int = max(MIN_QUANTITY, _max_affordable_quantity(item_id))
		_quantities[item_id] = clampi(_quantities.get(item_id, MIN_QUANTITY), MIN_QUANTITY, max_q)
		var qty: int = _quantities[item_id]
		var total := qty * price

		_row_icons[i].visible = true
		_row_icons[i].texture = ItemData.build_icon(item_id)
		_row_labels[i].visible = true
		_row_labels[i].text = "%s - %s (%d 골드)" % [item["name"], item["description"], price]
		_row_minus[i].visible = true
		_row_qty_labels[i].visible = true
		_row_qty_labels[i].text = str(qty)
		_row_plus[i].visible = true
		_row_total_labels[i].visible = true
		_row_total_labels[i].text = "총 %d 골드" % total
		_row_buy[i].visible = true
		_row_buy[i].disabled = GameState.gold < total


# 선택한 수량만큼 한 번에 구매: 골드를 소모(성공 시 인벤토리에 그만큼 추가), 부족하면 안내만 표시
func _on_buy_pressed(row: int) -> void:
	var items := _items_on_page()
	if row >= items.size():
		return
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	var item_id := items[row]
	var qty: int = _quantities.get(item_id, MIN_QUANTITY)
	var total := qty * _price(item_id)

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
