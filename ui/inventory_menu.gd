extends Control

# 인벤토리 패널. HUD의 가방 버튼이 open()/close()로 토글한다.
# _root(자기 자신)가 "inventory_menu" 그룹에 속하고 visible로 열림 여부를 나타내 이동 잠금과 연동된다.
# 배경은 medieval.png의 "INVENTORY" 격자 패널 그림을 그대로 쓴다. 이 그림은 4열x3행(12칸)짜리라
# (칸 사이 간격이 완전히 균등하지도 않음) GridContainer 자동 배치 대신, 실측한 픽셀 좌표를 3배
# 확대해 슬롯 12개를 그림의 실제 칸 위치에 정확히 겹치도록 배치한다 — 위치는 _ready()에서 코드로 생성
# (전투 씬의 데미지 팝업처럼, 반복되는 단순 UI 조각을 코드로 생성하는 기존 패턴을 재사용).

const SLOT_COUNT := 12
const SLOT_SIZE := Vector2(42, 42)
# 배경 그림(98x85, 3배 확대해 294x255로 표시)에서 실측한 슬롯 좌상단 좌표 (좌->우, 위->아래 순서.
# GameState.inventory.keys() 순서와 그대로 대응)
const SLOT_POSITIONS: Array[Vector2] = [
	Vector2(36, 51), Vector2(96, 51), Vector2(156, 51), Vector2(213, 51),
	Vector2(36, 114), Vector2(96, 114), Vector2(156, 114), Vector2(213, 114),
	Vector2(36, 177), Vector2(96, 177), Vector2(156, 177), Vector2(213, 177),
]

@onready var _slots_container: Control = $Panel/Slots
@onready var _close_button: Button = $Panel/CloseButton
@onready var _tooltip: PanelContainer = $Tooltip
@onready var _tooltip_label: Label = $Tooltip/Margin/TooltipLabel

var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _slot_item_ids: Array[String] = []


func _ready() -> void:
	add_to_group("inventory_menu")
	visible = false
	_tooltip.visible = false
	_close_button.pressed.connect(close)
	GameState.inventory_changed.connect(_on_inventory_changed)
	_build_slots()


# 배경 그림에 이미 칸 테두리가 그려져 있으므로, 슬롯 버튼 자체는 완전히 투명한 클릭 영역으로 만들어
# SLOT_POSITIONS의 실측 좌표에 정확히 겹쳐 배치한다. 각 슬롯은 아이콘(TextureRect)+개수 라벨(Label)
# 자식을 갖고 시작은 둘 다 숨김(빈 칸)
func _build_slots() -> void:
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0, 0, 0, 0)

	for i in range(SLOT_COUNT):
		var slot := Button.new()
		slot.position = SLOT_POSITIONS[i]
		slot.size = SLOT_SIZE
		slot.flat = true
		slot.add_theme_stylebox_override("normal", slot_style)
		slot.add_theme_stylebox_override("hover", slot_style)
		slot.add_theme_stylebox_override("pressed", slot_style)
		slot.add_theme_stylebox_override("focus", slot_style)
		_slots_container.add_child(slot)

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		slot.add_child(icon)

		var count_label := Label.new()
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.offset_left = -24
		count_label.offset_top = -13
		count_label.offset_right = -2
		count_label.offset_bottom = -1
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
	_rebuild()
	_tooltip.visible = false
	visible = true


func close() -> void:
	visible = false
	_tooltip.visible = false


func is_open() -> bool:
	return visible


# 인벤토리가 바뀔 때(구매/사용 등) 열려 있는 동안에만 즉시 다시 그림
func _on_inventory_changed(_item_id: String) -> void:
	if visible:
		_rebuild()


# GameState.inventory의 각 항목을 슬롯에 순서대로 채우고, 남는 슬롯은 빈 칸(아이콘/개수 숨김)으로 비움
func _rebuild() -> void:
	var item_ids := GameState.inventory.keys()
	for i in range(SLOT_COUNT):
		if i < item_ids.size():
			var item_id: String = item_ids[i]
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


# 슬롯 클릭 시 아이템을 사용: mana_potion이면 최대 마나를, hp_potion이면 최대 체력을 해당 fraction만큼
# 회복(clamp)한 뒤 1개 소비. 빈 슬롯 클릭은 무시
func _on_slot_pressed(index: int) -> void:
	var item_id := _slot_item_ids[index]
	if item_id == "" or not ItemData.ITEMS.has(item_id):
		return

	var item: Dictionary = ItemData.ITEMS[item_id]

	# 유지형 아이템(열쇠 등)은 클릭해도 효과·소비 없음 — 사용은 해당 상황(유적 입구)에서만 처리된다
	if not item.get("consumable", true):
		return

	if item_id == "mana_potion":
		GameState.restore_mana_partial(item["mana_restore_fraction"])
	elif item_id == "hp_potion":
		GameState.heal_player_partial(item["hp_restore_fraction"])

	GameState.remove_item(item_id, 1)


# 슬롯 위에 마우스가 들어오면 이름+설명 툴팁을 슬롯 바로 위에 띄움 (빈 슬롯은 표시 안 함)
func _on_slot_mouse_entered(index: int) -> void:
	var item_id := _slot_item_ids[index]
	if item_id == "" or not ItemData.ITEMS.has(item_id):
		return

	var item: Dictionary = ItemData.ITEMS[item_id]
	_tooltip_label.text = "%s: %s" % [item["name"], item["description"]]
	_tooltip.global_position = _slot_icons[index].get_parent().global_position + Vector2(-20.0, -44.0)
	_tooltip.visible = true


func _on_slot_mouse_exited() -> void:
	_tooltip.visible = false
