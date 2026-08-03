extends CanvasLayer

# 상시 표시 HUD (autoload). 좌상단 체력바 카드+퀘스트 버튼(MainHud)과
# 우상단 objective 패널(ObjectiveHud)을 별도 컨테이너로 분리해 표시한다.
# 대화/전투/일시정지/게임오버/퀘스트로그/오프닝 컷신이 열려 있거나, 게임 진행 중(플레이어 존재)이
# 아니거나, 타이틀/엔딩 씬이면 둘 다 숨긴다. 퀘스트 버튼은 QuestLog를 토글한다.

# HUD 전체를 가려야 하는 상황을 나타내는 UI 그룹들 (cutscene_box: 오프닝 컷신 재생 중)
const BLOCKING_GROUPS := ["dialogue_box", "battle_box", "pause_menu", "game_over", "quest_log", "cutscene_box", "level_up"]

# objective 패널 폭 자동 조절: 텍스트 실제 폭 + 라벨 좌우 inset(18+18)만큼 여유를 두고, 이 범위로 clamp
const OBJECTIVE_PANEL_MIN_WIDTH := 180.0
const OBJECTIVE_PANEL_MAX_WIDTH := 560.0
const OBJECTIVE_LABEL_PADDING := 36.0
const OBJECTIVE_PANEL_RIGHT_OFFSET := -12.0 # 화면 오른쪽 가장자리에서의 고정 여백 (이 값은 절대 안 바뀜)

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


func _ready() -> void:
	_quest_button.pressed.connect(_on_quest_button_pressed)

	# 진행 상황이 바뀔 때만 레벨/목표 텍스트를 다시 계산 (매 프레임 문자열을 만들 필요 없음)
	GameState.flag_changed.connect(_on_progress_changed)
	GameState.quest_changed.connect(_on_progress_changed)
	_refresh_objective()

	# 골드는 flags를 거치지 않는 별도 필드라 전용 시그널로 실시간 갱신
	GameState.gold_changed.connect(_on_gold_changed)
	_update_gold_label()


# 매 프레임 표시 조건을 갱신하고, 체력바를 현재 HP에 맞춘다 (신호 누락 걱정 없이 항상 정확)
func _process(_delta: float) -> void:
	var show_hud := _should_show_hud()
	_main_hud.visible = show_hud
	_objective_hud.visible = show_hud
	_update_stat_bars()


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


# 레벨(=quest_level)과 현재 메인 목표 문구를 GameState 계산값으로 갱신
func _refresh_objective() -> void:
	_lv_label.text = "Lv. %d" % GameState.get_flag("quest_level")
	_objective_label.text = GameState.get_objective_text()
	_update_objective_panel_width()


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
	if _quest_log.is_open():
		_quest_log.close()
	else:
		_quest_log.open()
