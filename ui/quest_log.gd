extends Control

# 퀘스트 화면. HUD의 "퀘스트" 버튼이 open()/close()로 토글한다 (진입점은 예전 그대로).
# 자기 자신이 "quest_log" 그룹에 속하고 visible로 열림 여부를 나타내 이동 잠금과 연동된다.
#
# 화면 구성은 Franuka RPG UI 팩의 담쟁이 테두리 프레임(BGbox_07A) + 상단 타이틀 배너
# (BannerMedium_04A) + 항목별 부제목/구분선/설명 리스트로, 팩 예시 이미지의 조합을 그대로 따랐다.
# 탭 전환은 같은 팩의 덩굴 알약 버튼(BannerSmall_06A)을 메인/서브용으로 두 개 썼다.
#
# [메인/서브의 성격 차이] 메인 퀘스트는 GameState.quests가 상태를 들고 있고 수락 조건도 이미
# GameState(QUEST_REQUIREMENTS)가 판정한다 — 여기서는 그 판정 결과를 문장으로 옮겨 적기만 한다.
# 서브 퀘스트는 아직 카탈로그(SubQuestData)가 비어 있어 안내 문구만 보여준다.

enum Tab { MAIN, SUB }

# 항목 사이 구분선으로 쓰는 금색 장식선. 가로로 늘려 쓰는데, 가운데 마름모까지 함께 늘어나
# 살짝 길어지는 정도라 팩 예시 이미지에서 쓰인 모습과 같다 (9패치로 늘리면 마름모가 반복돼 버린다)
const DIVIDER_TEXTURE := "res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Dividers/Divider_07.png"
const DIVIDER_HEIGHT := 22

# 항목 글자색. 부제목(퀘스트명)은 팩 예시처럼 밝은 연두, 설명은 옅은 회백으로 대비를 준다
const SUBTITLE_COLOR := Color(0.65, 0.87, 0.45, 1)
const SUBTITLE_DONE_COLOR := Color(0.62, 0.66, 0.72, 1) # 완료된 퀘스트는 채도를 빼서 지나간 것으로 보이게
const SUBTITLE_LOCKED_COLOR := Color(0.75, 0.55, 0.5, 1) # 아직 못 받는 퀘스트
const DESC_COLOR := Color(0.9, 0.88, 0.84, 1)
const DESC_DIM_COLOR := Color(0.72, 0.68, 0.66, 1)
const SUBTITLE_FONT_SIZE := 17
const DESC_FONT_SIZE := 13

# 선택된 탭과 아닌 탭의 색조 (알약 버튼에 Normal/Selected 그림이 따로 없어 색조로 구분한다)
const TAB_SELECTED_MODULATE := Color(1, 1, 1, 1)
const TAB_IDLE_MODULATE := Color(0.62, 0.6, 0.62, 1)

@onready var _entry_list: VBoxContainer = $Panel/Scroll/EntryList
@onready var _main_tab_button: Button = $Panel/Tabs/MainTabButton
@onready var _sub_tab_button: Button = $Panel/Tabs/SubTabButton
@onready var _close_button: Button = $Panel/CloseButton

var _tab: int = Tab.MAIN


func _ready() -> void:
	add_to_group("quest_log")
	visible = false
	_close_button.pressed.connect(_on_close_button_pressed)
	_main_tab_button.pressed.connect(_on_main_tab)
	_sub_tab_button.pressed.connect(_on_sub_tab)
	GameState.sub_quest_changed.connect(_on_sub_quest_changed)


# 열 때는 항상 메인 탭부터 보여준다 (지난번에 서브 탭을 보고 닫았더라도, 열자마자
# "곧 추가될 예정"만 보이면 퀘스트를 확인하러 연 목적과 어긋나므로)
func open() -> void:
	_tab = Tab.SUB if GameState.has_active_sub_quest() else Tab.MAIN
	_rebuild()
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _on_close_button_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	close()


func _on_main_tab() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_tab = Tab.MAIN
	_rebuild()


func _on_sub_tab() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_tab = Tab.SUB
	_rebuild()


func _on_sub_quest_changed() -> void:
	if visible and _tab == Tab.SUB:
		_rebuild()


func _rebuild() -> void:
	_main_tab_button.modulate = TAB_SELECTED_MODULATE if _tab == Tab.MAIN else TAB_IDLE_MODULATE
	_sub_tab_button.modulate = TAB_SELECTED_MODULATE if _tab == Tab.SUB else TAB_IDLE_MODULATE

	for child in _entry_list.get_children():
		child.queue_free()

	if _tab == Tab.MAIN:
		_build_main_tab()
	else:
		_build_sub_tab()


# ── 메인 퀘스트 탭 ──────────────────────────────────────────────────────────

# GameState.quests에 정의된 순서 그대로 4개를 전부 보여준다 (수락한 것만 보여주던 예전과 달리
# 아직 못 받은 퀘스트도 조건과 함께 노출한다 — 다음에 뭘 해야 하는지가 이 화면의 핵심 정보라,
# 잠긴 항목을 감추면 "레벨을 더 올려야 한다"는 사실을 알 방법이 없어진다)
func _build_main_tab() -> void:
	for quest_id in GameState.quests.keys():
		var quest: Dictionary = GameState.quests[quest_id]
		_add_entry(_quest_title_text(quest_id, quest), _quest_status_lines(quest_id, quest), _quest_title_color(quest_id, quest))


func _quest_title_text(quest_id: String, quest: Dictionary) -> String:
	var title: String = tr(quest["title"])
	if quest["complete"]:
		return tr("%s  [완료]") % title
	if not quest["active"] and not GameState.can_start_quest(quest_id):
		return tr("%s  [잠김]") % title
	return title


func _quest_title_color(quest_id: String, quest: Dictionary) -> Color:
	if quest["complete"]:
		return SUBTITLE_DONE_COLOR
	if not quest["active"] and not GameState.can_start_quest(quest_id):
		return SUBTITLE_LOCKED_COLOR
	return SUBTITLE_COLOR


# 퀘스트 하나의 설명줄들. 상태에 따라 보여줄 내용이 다르다:
# 완료 → 의뢰인만, 진행 중 → 진행도, 미수락 → 수락 조건(진행도+레벨)과 현재 값.
# 조건 판정은 GameState.can_start_quest/get_quest_requirement_text를 그대로 쓴다 (판정 로직 중복 없음)
func _quest_status_lines(quest_id: String, quest: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append(tr("의뢰인: %s") % tr(quest["giver"]))

	if quest["complete"]:
		lines.append(tr("완료했다."))
		return lines

	if quest["active"]:
		lines.append(tr("진행도 %d / %d") % [quest["current"], quest["target"]])
		return lines

	# 아직 수락하지 않은 퀘스트: 받을 수 있으면 그렇게, 아니면 부족한 조건을 그대로 보여준다
	var requirement := GameState.get_quest_requirement_text(quest_id)
	if requirement == "":
		lines.append(tr("아직 수락하지 않았다. (지금 의뢰인에게 말을 걸 수 있다)"))
	else:
		lines.append(tr("수락 조건: %s") % requirement)
		lines.append(tr("현재: 진행도 %d · 레벨 %d") % [GameState.get_flag("progress"), GameState.get_player_level()])
	return lines


# ── 서브 퀘스트 탭 ──────────────────────────────────────────────────────────

# 의뢰는 한 번에 하나만 받을 수 있어 목록이 아니라 항목 하나(또는 안내)만 그린다
func _build_sub_tab() -> void:
	if not GameState.has_active_sub_quest():
		_add_entry(tr("진행 중인 의뢰 없음"),
			[tr("엘라라에게 말을 걸어 의뢰판을 확인해보세요.")] as Array[String], SUBTITLE_LOCKED_COLOR)
		return

	var quest := GameState.active_sub_quest
	var remaining := SubQuestData.total_target(quest) - SubQuestData.total_progress(quest)
	var lines: Array[String] = [
		tr("의뢰인: %s") % tr(SubQuestData.GIVER),
		tr("진행도: %s") % SubQuestData.describe_progress(quest),
		tr("남은 처치: %d마리") % remaining,
		tr("보상: %s") % SubQuestData.describe_rewards(quest),
	]
	_add_entry(SubQuestData.title(quest), lines, SUBTITLE_COLOR)


# ── 항목 만들기 ────────────────────────────────────────────────────────────

# 항목 하나 = 부제목 + 금색 구분선 + 설명줄들 (팩 예시 이미지의 "Subtitle A / 구분선 / 설명" 구조)
func _add_entry(title: String, lines: Array[String], title_color: Color) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var subtitle := Label.new()
	subtitle.text = title
	subtitle.add_theme_color_override("font_color", title_color)
	subtitle.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)
	block.add_child(subtitle)

	# 구분선은 가로로 꽉 채우고 세로는 고정 — TextureRect를 늘려 쓰므로 9패치가 아니다
	var divider := TextureRect.new()
	divider.texture = load(DIVIDER_TEXTURE)
	divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	divider.custom_minimum_size = Vector2(0, DIVIDER_HEIGHT)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_child(divider)

	for i in range(lines.size()):
		var desc := Label.new()
		desc.text = lines[i]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# 첫 줄(의뢰인)보다 그 아래 상태 줄을 조금 더 밝게 해서 눈이 상태로 먼저 가게 한다
		desc.add_theme_color_override("font_color", DESC_DIM_COLOR if i == 0 else DESC_COLOR)
		desc.add_theme_font_size_override("font_size", DESC_FONT_SIZE)
		block.add_child(desc)

	# 다음 항목과 붙어 보이지 않게 아래쪽 여백
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	block.add_child(spacer)

	_entry_list.add_child(block)
