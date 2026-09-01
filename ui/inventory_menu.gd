extends Control

# 인벤토리 패널. HUD의 가방 버튼이 open()/close()로 토글한다.
# _root(자기 자신)가 "inventory_menu" 그룹에 속하고 visible로 열림 여부를 나타내 이동 잠금과 연동된다.
# 슬롯(칸 테두리 + 클릭 영역 + 아이콘 + 개수)은 _ready()에서 코드로 생성 — 페이지당 칸수이지, 전체
# 아이템 종류 수의 상한이 아니다. 아이템 종류가 넘치면 무기상점/스펠북과 같은 페이지네이션으로 넘긴다.

const SLOTS_PER_PAGE := 12
const SLOT_COLUMNS := 4
# Slot_02_Empty가 32x32라 정수배(2배)로만 키운다 — 어중간한 배율이면 픽셀이 고르지 않게 늘어난다
const SLOT_SIZE := Vector2(64, 64)
const SLOT_GAP := 10.0
const SLOT_ORIGIN := Vector2(47, 118)
const SLOT_FRAME_PATH := "res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Item slots/Slot_02_Empty.png"

@onready var _slots_container: Control = $Panel/Slots
@onready var _close_button: Button = $Panel/CloseButton
@onready var _equip_button: Button = $Panel/EquipButton
@onready var _prev_button: Button = $Panel/PageRow/PrevButton
@onready var _next_button: Button = $Panel/PageRow/NextButton
@onready var _page_label: Label = $Panel/PageRow/PageLabel
@onready var _tooltip: PanelContainer = $Tooltip
@onready var _tooltip_label: Label = $Tooltip/Margin/TooltipLabel

var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _slot_item_ids: Array[String] = []

var _page: int = 0

# 장비 슬롯을 클릭해 선택된 아이템 (장착 버튼이 조작할 대상). 소비 아이템 클릭이나 빈 칸 클릭,
# 메뉴를 닫을 때는 "" 로 비워 버튼을 숨긴다. 인덱스가 아니라 item_id로 들고 있는 이유는,
# 인벤토리가 다시 그려져 슬롯 순서가 바뀌어도(포션 소비 등) 같은 아이템을 계속 가리키게 하기 위함
var _selected_item_id: String = ""


func _ready() -> void:
	add_to_group("inventory_menu")
	visible = false
	_tooltip.visible = false
	_equip_button.visible = false
	_close_button.pressed.connect(_on_close_button_pressed)
	_equip_button.pressed.connect(_on_equip_button_pressed)
	_prev_button.pressed.connect(_on_prev_page)
	_next_button.pressed.connect(_on_next_page)
	GameState.inventory_changed.connect(_on_inventory_changed)
	_build_slots()


func _slot_position(index: int) -> Vector2:
	var column := index % SLOT_COLUMNS
	var row := index / SLOT_COLUMNS
	return SLOT_ORIGIN + Vector2(column * (SLOT_SIZE.x + SLOT_GAP), row * (SLOT_SIZE.y + SLOT_GAP))


func _build_slots() -> void:
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0, 0, 0, 0)
	var frame_texture := load(SLOT_FRAME_PATH) as Texture2D

	for i in range(SLOTS_PER_PAGE):
		var frame := TextureRect.new()
		frame.texture = frame_texture
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.position = _slot_position(i)
		frame.size = SLOT_SIZE
		_slots_container.add_child(frame)

		var slot := Button.new()
		slot.position = _slot_position(i)
		slot.size = SLOT_SIZE
		slot.flat = true
		slot.add_theme_stylebox_override("normal", slot_style)
		slot.add_theme_stylebox_override("hover", slot_style)
		slot.add_theme_stylebox_override("pressed", slot_style)
		slot.add_theme_stylebox_override("focus", slot_style)
		_slots_container.add_child(slot)

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 12
		icon.offset_top = 12
		icon.offset_right = -12
		icon.offset_bottom = -12
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		slot.add_child(icon)

		var count_label := Label.new()
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.offset_left = -30
		count_label.offset_top = -20
		count_label.offset_right = -8
		count_label.offset_bottom = -6
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		count_label.add_theme_constant_override("outline_size", 2)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.visible = false
		slot.add_child(count_label)

		_slot_icons.append(icon)
		_slot_counts.append(count_label)
		_slot_item_ids.append("")

		slot.pressed.connect(_on_slot_pressed.bind(i))
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
		slot.mouse_exited.connect(_on_slot_mouse_exited)


func open() -> void:
	_page = 0
	_rebuild()
	_tooltip.visible = false
	_clear_equip_selection()
	visible = true


func close() -> void:
	visible = false
	_tooltip.visible = false
	_clear_equip_selection()


func is_open() -> bool:
	return visible


func _on_close_button_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	close()


# 인벤토리가 바뀔 때(구매/사용 등) 열려 있는 동안에만 즉시 다시 그림
func _on_inventory_changed(_item_id: String) -> void:
	if visible:
		_rebuild()


func _total_pages() -> int:
	return max(1, int(ceil(float(GameState.inventory.size()) / SLOTS_PER_PAGE)))


# GameState.inventory 중 현재 페이지 몫만 슬롯에 순서대로 채우고, 남는 슬롯은 빈 칸(아이콘/개수 숨김)으로
# 비운다. 소비 등으로 아이템 종류 수가 줄어 지금 페이지가 더 이상 없어졌으면 마지막 페이지로 당겨온다
func _rebuild() -> void:
	_page = clampi(_page, 0, _total_pages() - 1)

	var item_ids := GameState.inventory.keys()
	var start := _page * SLOTS_PER_PAGE
	for i in range(SLOTS_PER_PAGE):
		var item_index := start + i
		if item_index < item_ids.size():
			var item_id: String = item_ids[item_index]
			_slot_item_ids[i] = item_id
			_slot_icons[i].texture = ItemData.build_icon(item_id)
			_slot_icons[i].visible = true
			_slot_counts[i].text = "x%d" % GameState.get_item_count(item_id)
			_slot_counts[i].visible = true
		else:
			_slot_item_ids[i] = ""
			_slot_icons[i].texture = null
			_slot_icons[i].visible = false
			_slot_counts[i].visible = false

	_page_label.text = "%d/%d" % [_page + 1, _total_pages()]
	_prev_button.disabled = _page <= 0
	_next_button.disabled = _page >= _total_pages() - 1


func _on_prev_page() -> void:
	if _page <= 0:
		return
	SFXPlayer.play(SFXPlayer.PAGE_TURN_SOUND)
	_page -= 1
	_clear_equip_selection()
	_tooltip.visible = false
	_rebuild()


func _on_next_page() -> void:
	if _page >= _total_pages() - 1:
		return
	SFXPlayer.play(SFXPlayer.PAGE_TURN_SOUND)
	_page += 1
	_clear_equip_selection()
	_tooltip.visible = false
	_rebuild()


# 슬롯 클릭 시: 장비(consumable: false + slot 있음)면 장착 버튼을 띄우고, 아니면 기존대로
# 즉시 사용한다(mana_potion이면 최대 마나를, hp_potion이면 최대 체력을 해당 fraction만큼
# 회복(clamp)한 뒤 1개 소비). 빈 슬롯 클릭은 무시. 장비가 아닌 슬롯을 클릭하면 열려있던
# 장착 버튼은 닫는다(선택 대상이 바뀌었으므로)
func _on_slot_pressed(index: int) -> void:
	var item_id := _slot_item_ids[index]
	if item_id == "" or not ItemData.ITEMS.has(item_id):
		_clear_equip_selection()
		return

	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	if ItemData.is_equipment(item_id):
		_selected_item_id = item_id
		_refresh_equip_button()
		return

	_clear_equip_selection()

	var item: Dictionary = ItemData.ITEMS[item_id]

	# 유지형 아이템(열쇠 등)은 클릭해도 효과·소비 없음 — 사용은 해당 상황(유적 입구)에서만 처리된다
	if not item.get("consumable", true):
		return

	if item_id == "mana_potion":
		GameState.restore_mana_partial(item["mana_restore_fraction"])
	elif item_id == "hp_potion":
		GameState.heal_player_partial(item["hp_restore_fraction"])

	GameState.remove_item(item_id, 1)


# 선택된 장비가 이미 그 슬롯에 장착 중인지에 따라 버튼 텍스트를 맞춘다.
# 텍스트는 상태 설명이 아니라 "눌렀을 때 일어날 동작"을 담아(닫기/구매하기 등 기존 버튼들과
# 같은 관례) — 이미 장착 중이면 눌렀을 때 해제되므로 "해제", 아니면 "장착"
func _refresh_equip_button() -> void:
	if _selected_item_id == "" or not ItemData.is_equipment(_selected_item_id):
		_equip_button.visible = false
		return

	var slot := ItemData.get_slot(_selected_item_id)
	_equip_button.text = tr("해제") if GameState.get_equipped(slot) == _selected_item_id else tr("장착")
	_equip_button.visible = true


# [장착/해제] 버튼: 선택된 아이템이 그 슬롯에 이미 장착 중이면 해제, 아니면 장착한다.
# 다른 아이템이 같은 슬롯에 장착돼 있었다면 equip_item()이 알아서 교체한다
func _on_equip_button_pressed() -> void:
	if _selected_item_id == "" or not ItemData.is_equipment(_selected_item_id):
		return

	SFXPlayer.play(SFXPlayer.EQUIP_SOUND)
	var slot := ItemData.get_slot(_selected_item_id)
	if GameState.get_equipped(slot) == _selected_item_id:
		GameState.unequip_slot(slot)
	else:
		GameState.equip_item(_selected_item_id)

	_refresh_equip_button()


func _clear_equip_selection() -> void:
	_selected_item_id = ""
	_equip_button.visible = false


# 슬롯 위에 마우스가 들어오면 이름+설명 툴팁을 슬롯 바로 위에 띄움 (빈 슬롯은 표시 안 함)
func _on_slot_mouse_entered(index: int) -> void:
	var item_id := _slot_item_ids[index]
	if item_id == "" or not ItemData.ITEMS.has(item_id):
		return

	var item: Dictionary = ItemData.ITEMS[item_id]
	_tooltip_label.text = "%s: %s" % [item["name"], item["description"]]
	_tooltip.global_position = _slot_icons[index].get_parent().global_position + Vector2(-16.0, -46.0)
	_tooltip.visible = true


func _on_slot_mouse_exited() -> void:
	_tooltip.visible = false
