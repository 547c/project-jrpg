extends CanvasLayer

const UiTranslator := preload("res://systems/ui_translator.gd")

# 상시 표시 HUD (autoload). 좌상단 체력바 카드+퀘스트 버튼(MainHud)과
# 우상단 objective 패널(ObjectiveHud)을 별도 컨테이너로 분리해 표시한다.
# 대화/전투/일시정지/게임오버/퀘스트로그/오프닝 컷신이 열려 있거나, 게임 진행 중(플레이어 존재)이
# 아니거나, 타이틀/엔딩 씬이면 둘 다 숨긴다. 퀘스트 버튼은 QuestLog를 토글한다.

# HUD 전체를 가려야 하는 상황을 나타내는 UI 그룹들 (cutscene_box: 오프닝 컷신 재생 중)
const BLOCKING_GROUPS := ["dialogue_box", "battle_box", "pause_menu", "game_over", "quest_log", "cutscene_box", "level_up", "inventory_menu", "spellbook_menu"]

# objective 패널 폭 자동 조절: 텍스트 실제 폭 + 라벨 좌우 inset(28+28)만큼 여유를 두고, 이 범위로 clamp.
# 패널이 Franuka 명판(BannerMedium_05A)으로 바뀌면서 좌우 끝에 20px짜리 금속 브래킷이 생겼다 —
# 라벨을 그만큼 안쪽으로 밀어야 글자가 브래킷에 물리지 않으므로 inset과 최소 폭을 함께 키웠다
const OBJECTIVE_PANEL_MIN_WIDTH := 210.0
const OBJECTIVE_PANEL_MAX_WIDTH := 560.0
const OBJECTIVE_LABEL_PADDING := 56.0
const OBJECTIVE_PANEL_RIGHT_OFFSET := -12.0 # 화면 오른쪽 가장자리에서의 고정 여백 (이 값은 절대 안 바뀜)

# 경험치 진행바 자리. Lv 라벨(x 14~102, y 104~124)과 같은 줄의 남는 오른쪽 공간을 쓴다 —
# 위로는 스탯 카드가 y 100에서 끝나고 아래로는 버튼 줄이 y 130에서 시작해, 이 줄만 비어 있다.
#
# 높이 32는 임의값이 아니라 Slider01_Box 텍스처의 원본 높이다. 이 텍스처는 세로로 늘릴 수 있는
# 균일한 중앙 행이 없어서(위아래가 통째로 테두리 장식), 원본 높이 그대로 써야 프레임이 안 뭉개진다.
# 실제로 보이는 홈은 그 안의 y 8~27 구간이라, 숫자 라벨은 GROOVE 상수로 그 자리에 맞춘다
const XP_BAR_RECT := Rect2(104, 96, 178, 32)
const XP_BAR_GROOVE_TOP := 8.0
const XP_BAR_GROOVE_HEIGHT := 20.0

# 체력/마나바와 같은 프레임을 쓰고 채움색만 초록으로 구분한다 (빨강=체력, 청록=마나, 초록=경험치).
# 프레임/채움을 .tscn이 아니라 여기서 만드는 이유는 바 자체를 코드로 만들기 때문 — 규칙이
# 한 곳에 모여 있어야 나중에 위치를 옮길 때 씬과 코드가 어긋나지 않는다
const BAR_BOX_PATH := "res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Sliders & Bars/Slider01_Box.png"
const XP_BAR_FILL_PATH := "res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Sliders & Bars/Slider01_Bar04.png"
# 9-slice 여백: 좌우 10은 텍스처 양 끝 마감을 지키는 최소값이고, 상하는 원본 높이 그대로 쓰므로
# 실제로 늘어나지 않는다 (체력/마나바의 .tscn 설정과 같은 값)
const BAR_PATCH_LEFT := 10.0
const BAR_PATCH_TOP := 8.0
const BAR_PATCH_RIGHT := 10.0
const BAR_PATCH_BOTTOM := 6.0

@onready var _main_hud: Control = $MainHud
@onready var _hp_bar: ProgressBar = $MainHud/StatCard/HPBar
@onready var _hp_bar_label: Label = $MainHud/StatCard/HPBarLabel
@onready var _mana_bar: ProgressBar = $MainHud/StatCard/ManaBar
@onready var _mana_bar_label: Label = $MainHud/StatCard/ManaBarLabel
@onready var _gold_label: Label = $MainHud/StatCard/GoldLabel
@onready var _lv_label: Label = $MainHud/LvLabel
@onready var _objective_hud: Control = $ObjectiveHud
@onready var _objective_panel: Panel = $ObjectiveHud/ObjectivePanel
@onready var _objective_label: Label = $ObjectiveHud/ObjectivePanel/ObjectiveLabel
@onready var _quest_button: Button = $MainHud/QuestButton
@onready var _quest_log = $QuestLog
@onready var _inventory_button: Button = $MainHud/InventoryButton
@onready var _inventory_menu = $InventoryMenu
@onready var _spellbook_button: Button = $MainHud/SpellbookButton
@onready var _spellbook_menu = $SpellbookMenu
@onready var _compass: Compass = $Compass
@onready var _compass_hint: Label = $ObjectiveHud/CompassHint

# 경험치 진행바와 그 위에 겹친 숫자 라벨 (_build_xp_bar가 코드로 만들어 붙인다)
var _xp_bar: ProgressBar
var _xp_bar_label: Label


func _ready() -> void:
	UiTranslator.bind(self, _on_locale_changed)
	_quest_button.pressed.connect(_on_quest_button_pressed)
	_inventory_button.pressed.connect(_on_inventory_button_pressed)
	_spellbook_button.pressed.connect(_on_spellbook_button_pressed)
	_update_compass_hint()
	_build_xp_bar()

	# 진행 상황이 바뀔 때만 레벨/목표 텍스트를 다시 계산 (매 프레임 문자열을 만들 필요 없음)
	GameState.flag_changed.connect(_on_progress_changed)
	GameState.quest_changed.connect(_on_progress_changed)
	_refresh_objective()

	# 골드는 flags를 거치지 않는 별도 필드라 전용 시그널로 실시간 갱신
	GameState.gold_changed.connect(_on_gold_changed)
	_update_gold_label()


# HUD는 항상 떠 있어서 언어가 바뀌면 그 자리에서 다시 만들어야 한다 (열 때 갱신되는 다른 화면과 다름)
func _on_locale_changed() -> void:
	_update_compass_hint()
	_update_gold_label()
	_refresh_objective()


# 매 프레임 표시 조건을 갱신하고, 체력바를 현재 HP에 맞추며, 나침반 방향도 갱신한다
func _process(_delta: float) -> void:
	var show_hud := _should_show_hud()
	_main_hud.visible = show_hud
	_objective_hud.visible = show_hud
	_update_stat_bars()
	_compass.update_compass(show_hud)


# M 키로 나침반 표시를 켜고 끈다 (HUD가 가려져 있어도 상태 자체는 토글되며, 힌트 라벨에 반영됨)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_compass"):
		_compass.toggle()
		_update_compass_hint()


func _update_compass_hint() -> void:
	_compass_hint.text = tr("[M] 나침반: %s") % (tr("켜짐") if _compass.is_enabled() else tr("꺼짐"))


# 경험치 진행바를 코드로 만들어 Lv 라벨 오른쪽(스탯 카드 아래 한 줄)에 붙인다.
# .tscn을 고치는 대신 코드로 만드는 이유는 몬스터 마나바와 같다 — 바 하나 때문에 씬 파일을
# 건드리기보다, 만드는 규칙을 코드에 한 곳으로 모아두는 쪽이 나중에 위치를 조정하기 쉽다.
# 자리: Lv 라벨이 x 12~100을 쓰고 그 줄의 오른쪽(스탯 카드 폭 243까지)이 비어 있어 거기에 넣는다
func _build_xp_bar() -> void:
	var bg := _make_bar_stylebox(BAR_BOX_PATH)
	var fill := _make_bar_stylebox(XP_BAR_FILL_PATH)

	_xp_bar = ProgressBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.show_percentage = false
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_xp_bar.add_theme_stylebox_override("background", bg)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	_xp_bar.position = XP_BAR_RECT.position
	_xp_bar.size = XP_BAR_RECT.size
	_main_hud.add_child(_xp_bar)

	_xp_bar_label = Label.new()
	_xp_bar_label.name = "XpBarLabel"
	_xp_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 바 전체가 아니라 "실제로 보이는 홈"에 맞춰 얹는다 (텍스처 위쪽 8px는 투명 여백이다)
	_xp_bar_label.position = XP_BAR_RECT.position + Vector2(0, XP_BAR_GROOVE_TOP)
	_xp_bar_label.size = Vector2(XP_BAR_RECT.size.x, XP_BAR_GROOVE_HEIGHT)
	_xp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_bar_label.add_theme_font_size_override("font_size", 9)
	_xp_bar_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_xp_bar_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_xp_bar_label.add_theme_constant_override("outline_size", 3)
	_main_hud.add_child(_xp_bar_label)


# 체력/마나바와 똑같은 9-slice 규칙으로 바 스타일박스 하나를 만든다
func _make_bar_stylebox(texture_path: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(texture_path) as Texture2D
	style.texture_margin_left = BAR_PATCH_LEFT
	style.texture_margin_top = BAR_PATCH_TOP
	style.texture_margin_right = BAR_PATCH_RIGHT
	style.texture_margin_bottom = BAR_PATCH_BOTTOM
	return style


# 게임 진행 중이고(플레이어 존재), 타이틀/엔딩이 아니며, 가리는 UI가 하나도 안 열려 있을 때만 표시
func _should_show_hud() -> bool:
	if not SceneManager.has_player():
		return false
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.begins_with("res://endings/"):
		return false
	for group in BLOCKING_GROUPS:
		var ui := get_tree().get_first_node_in_group(group) as CanvasItem
		if ui != null and ui.visible:
			return false
	return true


# 카드의 체력바/마나바(+겹쳐진 숫자 텍스트)를 GameState 값으로 갱신
func _update_stat_bars() -> void:
	var hp: int = GameState.get_flag("player_hp")
	var max_hp: int = GameState.get_flag("player_max_hp")
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_bar_label.text = "HP: %d/%d" % [hp, max_hp]

	var mana: int = GameState.get_flag("player_mana")
	var max_mana: int = GameState.get_flag("player_max_mana")
	_mana_bar.max_value = max_mana
	_mana_bar.value = mana
	_mana_bar_label.text = "Mana: %d/%d" % [mana, max_mana]


# 골드 시그널 콜백 (인자 무시, 최신값은 GameState.gold에서 다시 읽음)
func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_label()


func _update_gold_label() -> void:
	_gold_label.text = str(GameState.gold)


# flag_changed(flag_name, value) / quest_changed(quest_id) 어느 쪽이든 인자 무시하고 목표 갱신
func _on_progress_changed(_a = null, _b = null) -> void:
	_refresh_objective()


# 레벨(경험치로 오르는 player_level)과 현재 메인 목표 문구를 GameState 계산값으로 갱신.
# 스토리 진행도(progress)는 목표 문구 쪽이 이미 담고 있어 따로 표시하지 않는다
func _refresh_objective() -> void:
	_lv_label.text = "Lv. %d" % GameState.get_player_level()
	_refresh_xp_bar()
	_objective_label.text = GameState.get_objective_text()
	_update_objective_panel_width()


# 다음 레벨까지의 진행 정도를 Lv 라벨 오른쪽 빈 자리에 얇은 바로 보여준다.
# 체력/마나바와 같은 방식(바 + 그 위에 겹친 숫자 라벨)이라 읽는 방법이 일관된다
func _refresh_xp_bar() -> void:
	if _xp_bar == null:
		return
	var xp: int = GameState.get_player_xp()
	var needed: int = GameState.get_xp_to_next()
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_xp_bar_label.text = "%d/%d" % [xp, needed]


# objective 텍스트의 실제 필요 폭에 맞춰 패널 폭을 재계산.
# ObjectiveLabel은 autowrap을 쓰지 않는 한 줄짜리 라벨이라, DialogueBox의 높이 계산과 달리
# 컨테이너 폭이 먼저 정착되길 기다릴 필요 없이 get_minimum_size()가 곧바로 정확한 텍스트 폭을 준다.
# 오른쪽 가장자리(offset_right)는 고정한 채 왼쪽(offset_left)만 움직여서, 패널이 항상 화면
# 오른쪽에 붙어있는 채로 폭만 줄어들거나 늘어나게 한다
func _update_objective_panel_width() -> void:
	var content_width: float = _objective_label.get_minimum_size().x + OBJECTIVE_LABEL_PADDING
	var target_width: float = clampf(content_width, OBJECTIVE_PANEL_MIN_WIDTH, OBJECTIVE_PANEL_MAX_WIDTH)
	_objective_panel.offset_right = OBJECTIVE_PANEL_RIGHT_OFFSET
	_objective_panel.offset_left = OBJECTIVE_PANEL_RIGHT_OFFSET - target_width


# 퀘스트 버튼: 로그가 열려 있으면 닫고, 닫혀 있으면 연다
func _on_quest_button_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	if _quest_log.is_open():
		_quest_log.close()
	else:
		_quest_log.open()


# 가방 버튼: 인벤토리가 열려 있으면 닫고, 닫혀 있으면 연다
func _on_inventory_button_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	if _inventory_menu.is_open():
		_inventory_menu.close()
	else:
		_inventory_menu.open()


# 책 버튼: 카드 컬렉션 스펠북을 토글한다 (가방 버튼과 같은 방식)
func _on_spellbook_button_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	if _spellbook_menu.is_open():
		_spellbook_menu.close()
	else:
		_spellbook_menu.open()
