extends Control

const UiTranslator := preload("res://systems/ui_translator.gd")

# 카드 컬렉션/덱 구성 스펠북 (HUD의 책 버튼이 open()/close()로 토글).
# 배경은 Franuka RPG UI Pack의 펼친 책(Spellbook.png, 2x)이고, 항목/탭은 인벤토리 메뉴와 같은
# "실측 좌표 + 코드 생성" 방식으로 그림 위에 정확히 겹쳐 배치한다.
#
# [해상도] 원본 2x 에셋(512x320)을 1.5배(768x480)로 띄운다. 2x 에셋은 1x 픽셀 하나가 2x2 블록이라
# 1.5배를 곱하면 3x3 블록이 되어 원본 픽셀 격자가 그대로 유지된다 — 정수배가 아닌데도 픽셀이
# 뭉개지지 않는 이유다. 아래 좌표는 전부 이 768x480 표시 공간 기준.
#
# [페이지 영역] 배경 이미지의 종이 부분을 픽셀 단위로 재서 얻은 안전 영역:
# 왼쪽 종이 x 84~348, 오른쪽 종이 x 423~687 (둘 다 y 30~412).
#
# [탭 두 개] "컬렉션"은 12종 전체를 보여주고 스킬포인트로 잠금해제하는 화면, "덱 구성"은 보유한
# 카드만 골라 전투 덱 15장을 짜는 화면이다. 두 탭은 항목 6칸을 그대로 공유하고, 오른쪽 끝
# 영역만 갈아끼운다 (컬렉션=비용/보유 라벨, 덱=[-] 장수 [+] 버튼).

# 한 페이지(펼침면)에 좌 3 + 우 3 = 6개. 12종이라 2페이지가 된다
const ENTRIES_PER_SIDE := 3
const ENTRIES_PER_PAGE := ENTRIES_PER_SIDE * 2

const LEFT_PAGE_X := 84.0
const RIGHT_PAGE_X := 423.0
const PAGE_WIDTH := 264.0
const ENTRY_TOP := 76.0
const ENTRY_HEIGHT := 96.0
const ENTRY_GAP := 4.0

const ICON_FRAME_SIZE := 52.0
const ICON_INSET := 9.0 # 프레임 안쪽으로 아이콘을 이만큼 들여 그린다

# 항목 오른쪽 끝의 공용 영역. 컬렉션 탭에서는 비용/보유 라벨이, 덱 탭에서는 [-] 장수 [+]가 들어간다
const RIGHT_ZONE_X := 186.0
const RIGHT_ZONE_WIDTH := 76.0
const STEP_BUTTON_SIZE := 26.0
# [주의] 팩의 작은 버튼(Button_01B)은 64x32 캔버스 안에 그림이 x14~49, y4~29로만 그려져 있고
# 나머지는 투명 여백이다. 그래서 region_rect 없이 9슬라이스를 걸면 테두리 조각이 죄다 투명 여백을
# 집어 가운데만 늘어난 세로 막대처럼 찌그러진다(실제로 그렇게 나왔다). 실측한 그림 영역만 잘라
# 쓰고, 여백은 그 영역 기준으로 준다
const STEP_BUTTON_REGION := Rect2(14.0, 4.0, 36.0, 26.0)
const STEP_BUTTON_MARGIN := 8.0

# 보유/미보유를 아이콘 프레임 색으로도 구분한다 (금색 = 가진 카드)
const SLOT_DIR := "res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Item slots/"
const SLOT_FRAME_UNLOCKED := SLOT_DIR + "Slot_03_Empty.png" # 금색 테두리
const SLOT_FRAME_LOCKED := SLOT_DIR + "Slot_01_Empty.png"   # 차분한 살구색 테두리
# 이 팩에는 자물쇠 아이콘이 없어서(전체 32종을 훑어 확인함) 물음표를 "아직 모르는 카드" 표시로 쓴다.
# 열쇠 아이콘(Icon_24)도 후보였지만 "이미 열쇠가 있다"로 읽힐 여지가 있어 물음표를 골랐다
const LOCK_BADGE_PATH := "res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Mini icons/Icon_08.png"

const BOOK_DIR := "res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Spellbook & Tabs/"

# 책갈피 탭. 오른쪽 옆면(Right)만 5색이 갖춰져 있고 이 레이아웃에서 책 밖으로 자연스럽게 삐져나오므로
# Bottom 대신 Right를 쓴다. 01=빨강(컬렉션), 05=청록(덱 구성)으로 색이 확실히 갈리는 두 개를 골랐다
const TAB_SIZE := Vector2(96.0, 96.0) # 64x64 원본을 1.5배
# 좌표는 팩이 직접 제공한 합성본(Spellbook_WithTabs.png)에서 역산했다 — 그 그림에서 오른쪽 탭
# 깃발은 책 바깥으로 x=490부터 삐져나오고, 탭 스프라이트(64x64) 안에서 깃발은 x=10부터 그려져
# 있으므로 스프라이트 왼쪽 모서리는 책 기준 x=460(2x) = 690(1.5배 표시 공간)이 된다.
# 세로도 같은 방식으로 첫 깃발 y=48(2x)에서 스프라이트 상단 32를 빼 얻었고, 간격은 46(2x)이다
const TAB_X := 690.0
const TAB_TOP := 48.0
const TAB_STEP := 69.0
# 96x96 스프라이트 안에서 깃발 그림이 차지하는 영역 (탭 글자를 여기에 맞춰 얹는다).
# 깃발 오른쪽 끝은 제비꼬리 모양으로 갈라져 있어 글자를 거기까지 채우면 삐져나와 보이므로,
# 실제 깃발 폭(62)보다 조금 좁게 잡아 안쪽에만 글자를 앉힌다
const TAB_LABEL_INSET := Rect2(14.0, 26.0, 54.0, 44.0)

const TAB_COLLECTION := 0
const TAB_DECK := 1
const TAB_DEFS: Array = [
	{"label": "컬렉션", "sprite": "Tab01_Right"},
	{"label": "덱 구성", "sprite": "Tab05_Right"},
]

# ── 페이지 넘김 연출 ────────────────────────────────────────────────────────
# 팩의 애니메이션 시트는 512x352 프레임 8장이 가로로 이어져 있다. 정지 상태의 책(Spellbook.png,
# 512x320)과 견주면 같은 그림이 32px 아래에 그려져 있어(프레임 안 여백이 위쪽에 더 있음),
# 겹쳐 놓으려면 표시 공간에서 32*1.5=48px 위로 올려야 한다 — .tscn의 PageFlip offset_top=-48이 그것.
const FLIP_SHEET_NEXT := BOOK_DIR + "Spellbook_NextPage.png"
const FLIP_SHEET_PREV := BOOK_DIR + "Spellbook_PreviousPage.png"
const FLIP_FRAME_SIZE := Vector2(512.0, 352.0)
const FLIP_FRAME_COUNT := 8
const FLIP_FRAME_TIME := 0.032 # 8프레임 x 0.032 = 약 0.26초
# 페이지가 시야를 가장 많이 가리는 프레임에서 내용을 갈아끼운다 (넘어가는 도중에 바뀌어야 자연스럽다)
const FLIP_SWAP_FRAME := 4

const LOCKED_MODULATE := Color(0.62, 0.58, 0.54, 0.85) # 미보유 항목 전체를 흐리게
const UNLOCKED_MODULATE := Color(1, 1, 1, 1)
const COLOR_NAME := Color(0.35, 0.18, 0.1, 1)
const COLOR_DESC := Color(0.48, 0.32, 0.22, 1)
const COLOR_COST := Color(0.72, 0.32, 0.14, 1)  # 비용(주황) — 잠긴 카드에서만 보인다
const COLOR_OWNED := Color(0.29, 0.45, 0.22, 1) # "보유 중"(초록)
const COLOR_DECK_COUNT := Color(0.35, 0.18, 0.1, 1)
const COLOR_DECK_ZERO := Color(0.6, 0.52, 0.46, 1) # 덱에 0장인 카드의 숫자는 흐리게

@onready var _book: Control = $Book
@onready var _title_label: Label = $Book/TitleLabel
@onready var _points_label: Label = $Book/PointsLabel
@onready var _hint_label: Label = $Book/HintLabel
@onready var _entries_root: Control = $Book/Entries
@onready var _tabs_root: Control = $Book/Tabs
@onready var _page_flip: TextureRect = $Book/PageFlip
@onready var _prev_button: Button = $Book/PrevButton
@onready var _next_button: Button = $Book/NextButton
@onready var _close_button: Button = $CloseButton
@onready var _confirm_popup: Control = $ConfirmPopup
@onready var _confirm_message: Label = $ConfirmPopup/Panel/MessageLabel
@onready var _confirm_button: Button = $ConfirmPopup/Panel/ConfirmButton
@onready var _cancel_button: Button = $ConfirmPopup/Panel/CancelButton

# 항목 6칸은 인벤토리 슬롯처럼 매번 새로 만들지 않고 재사용한다 — 페이지를 넘길 때는 내용만 갈아끼운다
var _entry_buttons: Array[Button] = []
var _entry_frames: Array[TextureRect] = []
var _entry_icons: Array[TextureRect] = []
var _entry_locks: Array[TextureRect] = []
var _entry_names: Array[Label] = []
var _entry_costs: Array[Label] = []
var _entry_descs: Array[Label] = []
var _entry_minus: Array[Button] = []
var _entry_plus: Array[Button] = []
var _entry_counts: Array[Label] = []
var _entry_card_ids: Array[String] = []

var _tab_buttons: Array[Button] = []
var _tab_sprites: Array[TextureRect] = []
var _tab_labels: Array[Label] = []

var _current_tab: int = TAB_COLLECTION
var _page: int = 0
var _card_ids: Array[String] = []
# 페이지 넘김 연출이 도는 동안은 버튼 입력을 전부 무시한다 (연출 도중 페이지가 또 바뀌면
# 내용 교체 시점과 어긋나 엉뚱한 페이지가 보인다)
var _is_flipping: bool = false
# 확인창이 묻고 있는 카드. 확인을 누르는 순간 이 id로 잠금해제한다 (인덱스가 아니라 id로 들고 있는
# 이유는 인벤토리 메뉴와 같다 — 목록이 다시 그려져도 같은 카드를 계속 가리키게 하려고)
var _pending_card_id: String = ""


func _ready() -> void:
	UiTranslator.bind(self, _on_locale_changed)
	add_to_group("spellbook_menu")
	visible = false
	_confirm_popup.visible = false
	_page_flip.visible = false
	_card_ids = CardLibrary.all_ids()

	_close_button.pressed.connect(_on_close_button_pressed)
	_prev_button.pressed.connect(_on_page_step.bind(-1))
	_next_button.pressed.connect(_on_page_step.bind(1))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_button_pressed)

	_build_tabs()
	_build_entries()


func open() -> void:
	_current_tab = TAB_COLLECTION
	_page = 0
	_is_flipping = false
	_page_flip.visible = false
	_close_confirm()
	_refresh()
	visible = true


func close() -> void:
	visible = false
	_close_confirm()


func is_open() -> bool:
	return visible


func _on_close_button_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	close()


func _on_cancel_button_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_close_confirm()


# ── 구성 ───────────────────────────────────────────────────────────────────

# 책 오른쪽 옆면에 붙는 책갈피 탭. 탭 그림(TextureRect)과 라벨을 투명 버튼 위에 얹는다
func _build_tabs() -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)

	for i in range(TAB_DEFS.size()):
		var tab := Button.new()
		tab.position = Vector2(TAB_X, TAB_TOP + i * TAB_STEP)
		tab.size = TAB_SIZE
		tab.flat = true
		for state in ["normal", "hover", "pressed", "focus"]:
			tab.add_theme_stylebox_override(state, flat)
		_tabs_root.add_child(tab)

		var sprite := TextureRect.new()
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(sprite)

		var label := Label.new()
		label.position = TAB_LABEL_INSET.position
		label.size = TAB_LABEL_INSET.size
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(1, 0.97, 0.9, 1))
		label.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.05, 0.9))
		label.add_theme_constant_override("outline_size", 3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = tr(TAB_DEFS[i]["label"])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(label)

		tab.pressed.connect(_on_tab_pressed.bind(i))
		_tab_buttons.append(tab)
		_tab_sprites.append(sprite)
		_tab_labels.append(label)


# 탭 글자와 항목 목록은 코드로 만들어 붙인 것이라 언어가 바뀌면 여기서 직접 다시 채운다
func _on_locale_changed() -> void:
	for i in range(_tab_labels.size()):
		_tab_labels[i].text = tr(TAB_DEFS[i]["label"])
	if visible:
		_refresh()


# 항목 6칸(왼쪽 3 + 오른쪽 3)을 만들어 종이 위 실측 좌표에 배치한다.
# 항목 하나는 [아이콘 프레임 + 스킬 아이콘 + (잠김 배지)] / [이름] [오른쪽 영역] / [티어 · 효과설명]
func _build_entries() -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.55, 0.3, 0.12, 0.14) # 종이 위에 옅게 깔리는 하이라이트
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4

	for i in range(ENTRIES_PER_PAGE):
		var side := i / ENTRIES_PER_SIDE # 0 = 왼쪽 종이, 1 = 오른쪽 종이
		var row := i % ENTRIES_PER_SIDE
		var entry := Button.new()
		entry.position = Vector2(
			LEFT_PAGE_X if side == 0 else RIGHT_PAGE_X,
			ENTRY_TOP + row * (ENTRY_HEIGHT + ENTRY_GAP)
		)
		entry.size = Vector2(PAGE_WIDTH, ENTRY_HEIGHT)
		entry.flat = true
		entry.add_theme_stylebox_override("normal", flat)
		entry.add_theme_stylebox_override("hover", hover)
		entry.add_theme_stylebox_override("pressed", hover)
		entry.add_theme_stylebox_override("focus", flat)
		entry.add_theme_stylebox_override("disabled", flat)
		_entries_root.add_child(entry)

		var frame := TextureRect.new()
		frame.position = Vector2(2, (ENTRY_HEIGHT - ICON_FRAME_SIZE) / 2.0)
		frame.size = Vector2(ICON_FRAME_SIZE, ICON_FRAME_SIZE)
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(frame)

		var icon := TextureRect.new()
		icon.position = frame.position + Vector2(ICON_INSET, ICON_INSET)
		icon.size = Vector2(ICON_FRAME_SIZE - ICON_INSET * 2.0, ICON_FRAME_SIZE - ICON_INSET * 2.0)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(icon)

		# 잠긴 카드에 겹쳐 붙는 작은 배지 (프레임 오른쪽 아래 모서리)
		var lock := TextureRect.new()
		lock.position = frame.position + Vector2(ICON_FRAME_SIZE - 24.0, ICON_FRAME_SIZE - 24.0)
		lock.size = Vector2(26, 26)
		lock.texture = load(LOCK_BADGE_PATH) as Texture2D
		lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_SCALE
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.visible = false
		entry.add_child(lock)

		var text_x := ICON_FRAME_SIZE + 12.0
		var name_label := Label.new()
		name_label.position = Vector2(text_x, 10)
		name_label.size = Vector2(RIGHT_ZONE_X - text_x - 4.0, 24)
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", COLOR_NAME)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(name_label)

		var cost_label := Label.new()
		cost_label.position = Vector2(RIGHT_ZONE_X, 10)
		cost_label.size = Vector2(RIGHT_ZONE_WIDTH, 24)
		cost_label.add_theme_font_size_override("font_size", 13)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(cost_label)

		var desc_label := Label.new()
		desc_label.position = Vector2(text_x, 38)
		desc_label.size = Vector2(PAGE_WIDTH - text_x - 6.0, 48)
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", COLOR_DESC)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(desc_label)

		# 덱 구성 탭에서만 보이는 장수 조절 [-] N [+] (상점의 수량 선택과 같은 배치)
		var minus := _make_step_button("-")
		minus.position = Vector2(RIGHT_ZONE_X, 10)
		entry.add_child(minus)

		var count_label := Label.new()
		count_label.position = Vector2(RIGHT_ZONE_X + STEP_BUTTON_SIZE, 10)
		count_label.size = Vector2(RIGHT_ZONE_WIDTH - STEP_BUTTON_SIZE * 2.0, STEP_BUTTON_SIZE)
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(count_label)

		var plus := _make_step_button("+")
		plus.position = Vector2(RIGHT_ZONE_X + RIGHT_ZONE_WIDTH - STEP_BUTTON_SIZE, 10)
		entry.add_child(plus)

		entry.pressed.connect(_on_entry_pressed.bind(i))
		minus.pressed.connect(_on_deck_step.bind(i, -1))
		plus.pressed.connect(_on_deck_step.bind(i, 1))

		_entry_buttons.append(entry)
		_entry_frames.append(frame)
		_entry_icons.append(icon)
		_entry_locks.append(lock)
		_entry_names.append(name_label)
		_entry_costs.append(cost_label)
		_entry_descs.append(desc_label)
		_entry_minus.append(minus)
		_entry_plus.append(plus)
		_entry_counts.append(count_label)
		_entry_card_ids.append("")


# 덱 장수 조절용 작은 정사각 버튼. 팩의 작은 버튼(Button_01B)을 9슬라이스로 늘려 쓴다
func _make_step_button(label: String) -> Button:
	var dir := "res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Buttons/"
	var btn := Button.new()
	btn.size = Vector2(STEP_BUTTON_SIZE, STEP_BUTTON_SIZE)
	btn.text = label
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.35, 0.18, 0.1, 1))
	# 비활성이라도 +/- 글자 자체는 보여야 "여기 버튼이 있는데 지금 못 쓴다"로 읽힌다 (알파를 너무
	# 낮췄더니 버튼이 통째로 빈 칸처럼 보였다)
	btn.add_theme_color_override("font_disabled_color", Color(0.48, 0.38, 0.33, 0.9))
	for state in [["normal", "Normal"], ["hover", "Selected"], ["pressed", "Pressed"], ["disabled", "Normal"]]:
		var style := StyleBoxTexture.new()
		style.texture = load(dir + "Button_01B_%s.png" % state[1]) as Texture2D
		style.region_rect = STEP_BUTTON_REGION
		style.texture_margin_left = STEP_BUTTON_MARGIN
		style.texture_margin_top = STEP_BUTTON_MARGIN
		style.texture_margin_right = STEP_BUTTON_MARGIN
		style.texture_margin_bottom = STEP_BUTTON_MARGIN
		btn.add_theme_stylebox_override(state[0], style)
	return btn


# ── 갱신 ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_refresh_tabs()
	_refresh_entries()


func _refresh_tabs() -> void:
	for i in range(_tab_buttons.size()):
		var state := "Selected" if i == _current_tab else "Normal"
		_tab_sprites[i].texture = load(BOOK_DIR + "%s_%s.png" % [TAB_DEFS[i]["sprite"], state]) as Texture2D
		# 선택 안 된 탭은 살짝 눌러 뒤로 물러난 느낌을 준다
		_tab_buttons[i].modulate = Color(1, 1, 1, 1) if i == _current_tab else Color(0.82, 0.8, 0.78, 1)


# 현재 탭이 나열할 카드 id 목록. 컬렉션은 12종 전부, 덱 구성은 보유한 카드만
func _visible_card_ids() -> Array[String]:
	if _current_tab == TAB_COLLECTION:
		return _card_ids
	var owned: Array[String] = []
	for card_id in _card_ids:
		if GameState.is_card_unlocked(card_id):
			owned.append(card_id)
	return owned


func _refresh_entries() -> void:
	var ids := _visible_card_ids()
	var total_pages := maxi(1, ceili(float(ids.size()) / ENTRIES_PER_PAGE))
	_page = clampi(_page, 0, total_pages - 1)

	var is_deck := _current_tab == TAB_DECK
	# 페이지 번호는 제목에 붙여 쓴다 — 책 한가운데는 어두운 제본 부분이라 거기 라벨을 두면 안 읽힌다
	_title_label.text = "%s (%d/%d)" % [tr("덱 구성") if is_deck else tr("카드 컬렉션"), _page + 1, total_pages]
	if is_deck:
		_points_label.text = tr("덱: %d / %d") % [GameState.get_deck_size(), GameState.MAX_BATTLE_DECK_SIZE]
		_hint_label.text = tr("비워두면 자동 구성")
	else:
		_points_label.text = tr("스킬포인트: %d") % GameState.get_skill_points()
	_hint_label.visible = is_deck

	_prev_button.disabled = _page <= 0
	_next_button.disabled = _page >= total_pages - 1

	var deck_full := GameState.get_deck_remaining() <= 0
	for i in range(ENTRIES_PER_PAGE):
		var index := _page * ENTRIES_PER_PAGE + i
		if index >= ids.size():
			_entry_card_ids[i] = ""
			_entry_buttons[i].visible = false
			continue
		_entry_buttons[i].visible = true
		_fill_entry(i, ids[index], is_deck, deck_full)


func _fill_entry(i: int, card_id: String, is_deck: bool, deck_full: bool) -> void:
	var card := CardLibrary.get_card(card_id)
	if card == null:
		_entry_card_ids[i] = ""
		_entry_buttons[i].visible = false
		return

	_entry_card_ids[i] = card_id
	var unlocked := GameState.is_card_unlocked(card_id)

	_entry_frames[i].texture = load(SLOT_FRAME_UNLOCKED if unlocked else SLOT_FRAME_LOCKED) as Texture2D
	_entry_icons[i].texture = CardLibrary.build_icon(card_id)
	_entry_locks[i].visible = not unlocked
	_entry_names[i].text = tr(card.card_name)
	_entry_descs[i].text = "%s · %s" % [card.get_tier_label(), card.get_effect_description()]

	# 오른쪽 끝 영역을 탭에 맞춰 갈아끼운다
	_entry_costs[i].visible = not is_deck
	_entry_minus[i].visible = is_deck
	_entry_plus[i].visible = is_deck
	_entry_counts[i].visible = is_deck

	if is_deck:
		var count := GameState.get_deck_card_count(card_id)
		_entry_counts[i].text = str(count)
		_entry_counts[i].add_theme_color_override("font_color", COLOR_DECK_COUNT if count > 0 else COLOR_DECK_ZERO)
		_entry_minus[i].disabled = count <= 0
		# 전체 15장 한도와 별개로, 카드 하나가 개별 상한(MAX_COPIES_PER_CARD)에 닿으면 그 카드의
		# +버튼만 막는다 — 덱에 아직 여유가 있어도 "이 카드"는 더 못 넣는다는 걸 그 자리에서 보여준다
		_entry_plus[i].disabled = deck_full or count >= GameState.MAX_COPIES_PER_CARD
		# 덱 탭에는 잠긴 카드가 아예 안 뜨므로 항상 또렷하게
		_entry_buttons[i].modulate = UNLOCKED_MODULATE
		return

	if unlocked:
		_entry_costs[i].text = tr("보유 중")
		_entry_costs[i].add_theme_color_override("font_color", COLOR_OWNED)
	else:
		_entry_costs[i].text = "%dP" % CardLibrary.get_unlock_cost(card_id)
		_entry_costs[i].add_theme_color_override("font_color", COLOR_COST)

	# 미보유 카드는 항목 전체를 흐리게 (아이콘/글자 색을 하나씩 바꾸지 않고 버튼 modulate 하나로 처리)
	_entry_buttons[i].modulate = UNLOCKED_MODULATE if unlocked else LOCKED_MODULATE


# ── 페이지 넘김 연출 ────────────────────────────────────────────────────────

# 넘김 프레임을 순서대로 보여주면서, 중간에 내용을 새 페이지로 갈아끼운다.
# 연출 동안은 항목/버튼을 숨겨 넘어가는 종이 위에 옛 페이지 글자가 떠 있지 않게 한다
func _play_page_flip(forward: bool) -> void:
	_is_flipping = true
	var sheet := load(FLIP_SHEET_NEXT if forward else FLIP_SHEET_PREV) as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet

	_entries_root.visible = false
	_prev_button.visible = false
	_next_button.visible = false
	_hint_label.visible = false
	_page_flip.texture = atlas
	_page_flip.visible = true

	for f in range(FLIP_FRAME_COUNT):
		atlas.region = Rect2(f * FLIP_FRAME_SIZE.x, 0.0, FLIP_FRAME_SIZE.x, FLIP_FRAME_SIZE.y)
		if f == FLIP_SWAP_FRAME:
			_refresh_entries()
		await get_tree().create_timer(FLIP_FRAME_TIME).timeout
		# 연출 도중 창이 닫히면(닫기/ESC) 남은 프레임을 계속 돌릴 이유가 없다
		if not visible:
			break

	_page_flip.visible = false
	_entries_root.visible = true
	_prev_button.visible = true
	_next_button.visible = true
	_hint_label.visible = _current_tab == TAB_DECK
	_is_flipping = false


# ── 입력 ───────────────────────────────────────────────────────────────────

func _on_tab_pressed(index: int) -> void:
	if _is_flipping or _current_tab == index:
		return
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_current_tab = index
	_page = 0
	_close_confirm()
	_refresh()


func _on_page_step(step: int) -> void:
	if _is_flipping:
		return
	var ids := _visible_card_ids()
	var total_pages := maxi(1, ceili(float(ids.size()) / ENTRIES_PER_PAGE))
	var next_page := clampi(_page + step, 0, total_pages - 1)
	if next_page == _page:
		return
	SFXPlayer.play(SFXPlayer.PAGE_TURN_SOUND)
	_page = next_page
	_play_page_flip(step > 0)


# 항목 클릭: 컬렉션 탭에서 미보유 카드만 확인창을 띄운다 (덱 탭에서는 +/- 버튼만 쓰고 본체 클릭은 무시).
# 포인트가 모자라도 창은 띄우되 잠금해제 버튼을 잠가, 왜 못 사는지(잔량/필요 비용)를 보여준다
func _on_entry_pressed(i: int) -> void:
	if _is_flipping or _current_tab != TAB_COLLECTION:
		return
	var card_id := _entry_card_ids[i]
	if card_id == "" or GameState.is_card_unlocked(card_id):
		return

	var card := CardLibrary.get_card(card_id)
	var cost := CardLibrary.get_unlock_cost(card_id)
	if card == null or cost == CardLibrary.UNKNOWN_COST:
		return

	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_pending_card_id = card_id
	var affordable := GameState.can_unlock_card(card_id)
	if affordable:
		_confirm_message.text = tr("%s 잠금해제에 %d 포인트를 사용하시겠습니까?\n(보유: %d P)") % [
			tr(card.card_name), cost, GameState.get_skill_points()
		]
	else:
		_confirm_message.text = tr("%s 잠금해제에는 %d 포인트가 필요합니다.\n(보유: %d P — 포인트가 부족합니다)") % [
			tr(card.card_name), cost, GameState.get_skill_points()
		]
	_confirm_button.disabled = not affordable
	_confirm_popup.visible = true


# 덱 구성 [-]/[+]: 한 장씩 넣고 뺀다. 한도 초과/0장 미만은 GameState가 막고 false를 돌려주므로
# 여기서는 결과와 무관하게 다시 그려 화면을 실제 상태와 맞추기만 한다
func _on_deck_step(i: int, step: int) -> void:
	if _is_flipping or _current_tab != TAB_DECK:
		return
	var card_id := _entry_card_ids[i]
	if card_id == "":
		return
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	if step > 0:
		GameState.add_card_to_deck(card_id)
	else:
		GameState.remove_card_from_deck(card_id)
	_refresh_entries()


func _on_confirm_pressed() -> void:
	var card_id := _pending_card_id
	_close_confirm()
	if card_id == "":
		return
	# 성공 여부와 무관하게 다시 그린다 — 실패해도(다른 경로로 포인트가 줄었다든지) 화면이
	# 실제 상태와 어긋나 있지 않게 하려는 것
	if GameState.unlock_card(card_id):
		SFXPlayer.play(SFXPlayer.UNLOCK_SOUND)
	_refresh()


func _close_confirm() -> void:
	_pending_card_id = ""
	_confirm_popup.visible = false


# 확인창이 열려 있으면 ESC로 확인창만 닫고, 아니면 스펠북 전체를 닫는다
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _confirm_popup.visible:
			_close_confirm()
		else:
			close()
		get_viewport().set_input_as_handled()
