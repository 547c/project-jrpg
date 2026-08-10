class_name DialogueBox
extends Control

# 대화가 완전히 종료되었을 때 발행. last_node_id는 종료 직전 마지막으로 보여준 노드의 id
# (구독자가 "어떤 대사에서 끝났는지"로 특별 처리를 하고 싶을 때 사용 — 예: 엔딩 트리거)
signal dialogue_ended(last_node_id: String)

const MAX_OPTIONS := 6
# 상하 레이아웃 기준 높이. 세로로 쌓인 콘텐츠(상단 카드/이름/호감도 + 대사 + 2열 옵션 그리드) 전체
# 최소 높이로 패널 높이가 정해진다. 2열 옵션이라 옵션 영역이 낮아져 예전보다 여유가 생김
const MIN_PANEL_HEIGHT := 160.0
const MAX_PANEL_HEIGHT := 380.0

# 옵션 버튼 글자색: 일반(갈색) / 잠김(빨강, 호감도 부족) / 이미 봄(회색). 우선순위 잠김 > 봄 > 일반
const COLOR_NORMAL := Color(0.22, 0.09, 0.03, 1)
const COLOR_LOCKED := Color(0.68, 0.14, 0.11, 1)
const COLOR_SEEN := Color(0.5, 0.43, 0.36, 1)

# 잠긴(호감도 부족) 옵션을 눌렀을 때 대사 자리에 잠깐 보여주는 안내
const LOCKED_HINT := "아직은... 좀 더 가까워져야 들을 수 있을 것 같다."

# npc_id -> 얼굴 카드용 초상화(각 NPC의 Idle 시트에서 머리 부분만 크롭)와 상단에 고정 표시할 이름.
# region은 스프라이트 알파를 분석해 머리+어깨가 들어가는 정사각형에 가깝게 잡았다(비주얼은 조정 가능).
# 여기에 없는 npc_id(빈 문자열 포함)는 "NPC가 아닌 대화"로 간주해 얼굴/호감도 UI를 숨긴다
const PORTRAITS: Dictionary = {
	"elara": {
		"sheet": "res://assets/Pixel Crawler - Free Pack/Entities/Npc's/Knight/Idle/Idle-Sheet.png",
		"region": Rect2(6, 2, 18, 18),
		"name": "엘라라",
	},
	"rohan": {
		"sheet": "res://assets/Pixel Crawler - Free Pack/Entities/Npc's/Rogue/Idle/Idle-Sheet.png",
		"region": Rect2(6, 1, 19, 19),
		"name": "로한",
	},
	"yusuf": {
		"sheet": "res://assets/Pixel Crawler - Free Pack/Entities/Npc's/Wizzard/Idle/Idle-Sheet.png",
		"region": Rect2(4, 0, 25, 25),
		"name": "유서프",
	},
	"mia": {
		"sheet": "res://assets/Pixel Crawler - Free Pack/Entities/Npc's/Citizen_F/Peasant_A/Idle/Idle-Sheet.png",
		"region": Rect2(21, 16, 22, 22),
		"name": "미아",
	},
	"kamil": {
		"sheet": "res://assets/Pixel Crawler - Free Pack/Entities/Npc's/Citizen_F/Tavern_A/Idle/Idle_Side-Sheet.png",
		"region": Rect2(21, 16, 22, 22),
		"name": "카밀",
	},
}

@onready var _decisive_frame: Control = $DecisiveFrame
@onready var _content: VBoxContainer = $Panel/Content
@onready var _top_row: HBoxContainer = $Panel/Content/TopRow
@onready var _face_card: Panel = $Panel/Content/TopRow/FaceCard
@onready var _portrait: TextureRect = $Panel/Content/TopRow/FaceCard/Portrait
@onready var _speaker_label: Label = $Panel/Content/TopRow/InfoColumn/SpeakerLabel
@onready var _affinity_row: HBoxContainer = $Panel/Content/TopRow/InfoColumn/AffinityRow
@onready var _affinity_bar: ProgressBar = $Panel/Content/TopRow/InfoColumn/AffinityRow/AffinityBar
@onready var _affinity_value_label: Label = $Panel/Content/TopRow/InfoColumn/AffinityRow/AffinityValueLabel
@onready var _narration_label: Label = $Panel/Content/NarrationLabel
@onready var _text_label: Label = $Panel/Content/TextLabel
@onready var _options_container: GridContainer = $Panel/Content/OptionsContainer
@onready var _bleep_player: AudioStreamPlayer = $BleepPlayer

var _nodes_by_id: Dictionary = {}
var _last_shown_node_id: String = ""
var _npc_id: String = "" # 현재 대화 상대 NPC의 id (빈 문자열이면 NPC가 아닌 대화 — 얼굴/호감도 숨김)
var _typewriter: Typewriter


# 다른 씬에서 이 DialogueBox를 찾을 수 있도록 그룹에 등록하고 공용 타이핑 헬퍼를 준비
func _ready() -> void:
	add_to_group("dialogue_box")
	_typewriter = Typewriter.new(_text_label, _bleep_player)


# 대화 트리를 id 기준으로 인덱싱하고 start_id 노드부터 대화를 시작.
# npc_id를 넘기면(NPC와의 대화) 얼굴 카드/이름/호감도 바를 표시하고, 빈 문자열이면(가디언/캠프파이어/
# 상자 등 NPC가 아닌 대화) 그 UI를 숨긴다
func start_dialogue(dialogue_tree: Array, start_id: String, npc_id: String = "") -> void:
	_nodes_by_id.clear()
	for node in dialogue_tree:
		_nodes_by_id[node["id"]] = node

	_npc_id = npc_id
	_setup_npc_panel(npc_id)

	show()
	_show_node(start_id)


# 얼굴 카드/호감도 영역을 npc_id에 맞춰 구성. PORTRAITS에 있는 NPC면 초상화를 크롭해 세팅하고
# 호감도 바를 켜며, 없으면(비-NPC 대화) 얼굴 카드와 호감도 행을 모두 숨긴다
func _setup_npc_panel(npc_id: String) -> void:
	var is_npc: bool = PORTRAITS.has(npc_id)
	_face_card.visible = is_npc
	_affinity_row.visible = is_npc

	if is_npc:
		var info: Dictionary = PORTRAITS[npc_id]
		var atlas := AtlasTexture.new()
		atlas.atlas = load(info["sheet"]) as Texture2D
		atlas.region = info["region"]
		_portrait.texture = atlas
		_refresh_affinity_display()


# 호감도 바와 "값/100" 라벨을 현재 NPC의 호감도로 갱신 (NPC 대화가 아니면 아무것도 안 함)
func _refresh_affinity_display() -> void:
	if not PORTRAITS.has(_npc_id):
		return
	var value: int = GameState.get_affinity(_npc_id)
	_affinity_bar.value = value
	_affinity_value_label.text = "%d/100" % value


# 상단에 표시할 이름: NPC 대화면 PORTRAITS의 고정 이름(대화 중 노드마다 speaker가 비어도 안정적),
# 아니면 노드의 speaker(가디언 "???" 등)로 폴백
func _resolve_display_name(node: Dictionary) -> String:
	if PORTRAITS.has(_npc_id):
		return PORTRAITS[_npc_id].get("name", "")
	return node.get("speaker", "")


# 주어진 id의 대화 노드를 화면에 표시 (id가 없거나 빈 문자열이면 대화 종료)
func _show_node(node_id: String) -> void:
	if node_id == "" or not _nodes_by_id.has(node_id):
		_end_dialogue()
		return

	_last_shown_node_id = node_id
	GameState.mark_node_seen(node_id) # 이 노드를 "본 적 있음"으로 기록 (옵션 회색/정렬 판단 기반)

	var node: Dictionary = _nodes_by_id[node_id]
	var is_decisive: bool = node.get("is_decisive", false)

	# 이 노드에 "도달"한 순간 세워둘 flag (예: 결정적 선택을 통과해 결과 노드에 이르렀음을 기록)
	var flag_on_show: String = node.get("set_flag_on_show", "")
	if flag_on_show != "":
		GameState.set_flag(flag_on_show, true)

	# 이 노드에 "도달"한 순간 적용할 호감도 변화 (예: 속내를 털어놓는 대사에 도달한 것 자체가 효과를 가짐).
	# 옵션 선택 시 효과(affinity_change)와 달리, 선택 없이 이어지는 서술형 노드에 쓰는 용도
	var affinity_on_show: Dictionary = node.get("affinity_change_on_show", {})
	if not affinity_on_show.is_empty():
		GameState.change_affinity(affinity_on_show.get("npc_id", ""), int(affinity_on_show.get("amount", 0)))

	_speaker_label.text = _resolve_display_name(node)
	_refresh_affinity_display() # on-show/옵션 효과로 바뀐 호감도를 매 노드마다 바에 반영

	var narration: String = node.get("narration", "")
	_narration_label.text = narration
	_narration_label.visible = narration != ""

	_decisive_frame.visible = is_decisive
	_typewriter.start(_resolve_text(node))

	_populate_options(node.get("options", []), node.get("next_id", ""))
	_update_panel_height()


# 세로로 쌓인 콘텐츠(상단 카드/이름/호감도 + 지문 + 대사 + 2열 옵션 그리드)의 전체 최소 높이에 맞춰
# 대화창 높이를 동적으로 조절. 화면 하단(offset_bottom)은 고정한 채 위쪽으로만 자라나게(offset_top만 변경)
# 해서 옵션/대사가 적을 땐 화면을 덜 가리고, 많을 때도 화면 밖으로 잘리지 않게 함
func _update_panel_height() -> void:
	var content_padding: float = _content.offset_top - _content.offset_bottom # Content VBox의 상하 여백(Panel 기준)
	var content_height := 0.0

	# 씬이 막 로드된 직후의 첫 대화처럼 이 컨트롤 트리가 아직 레이아웃을 한 번도 확정 짓지 못한 상태에서는,
	# 자동 줄바꿈 라벨(NarrationLabel/TextLabel)의 최소 높이가 실제 너비를 반영하지 못해
	# 훨씬 크게(때로는 최댓값까지) 잘못 계산될 수 있다. 측정값이 비정상적으로 크지(=MAX 이상) 않을 때까지
	# 몇 프레임 더 재측정해서, 레이아웃이 정착되기 전의 값을 그대로 믿지 않도록 방어한다
	for i in range(6):
		await get_tree().process_frame
		content_height = _content.get_combined_minimum_size().y + content_padding
		if content_height < MAX_PANEL_HEIGHT:
			break

	var target_height: float = clampf(content_height, MIN_PANEL_HEIGHT, MAX_PANEL_HEIGHT)
	offset_top = offset_bottom - target_height


# text_by_affinity_tier가 있으면 해당 NPC의 현재 호감도 구간(cold/neutral/warm/trusted)에 맞는 문구를
# 반환(구간별 문구가 없으면 "text"로 폴백). 없으면 text_if_flag(flag 참/거짓 분기)를 확인하고,
# 그마저 없으면 "text"를 그대로 반환
func _resolve_text(node: Dictionary) -> String:
	var tier_texts: Dictionary = node.get("text_by_affinity_tier", {})
	if not tier_texts.is_empty():
		var tier := GameState.get_affinity_tier(tier_texts.get("npc_id", ""))
		return tier_texts.get(tier, node.get("text", ""))

	var text_if_flag: String = node.get("text_if_flag", "")
	if text_if_flag == "":
		return node.get("text", "")
	return node.get("text", "") if GameState.get_flag(text_if_flag) else node.get("text_false", "")


# 표시 조건을 통과한 옵션만 남김
func _filter_visible_options(options: Array) -> Array:
	var visible_options: Array = []
	for option in options:
		if _is_option_visible(option):
			visible_options.append(option)
	return visible_options


# 옵션의 표시 조건들을 모두 만족하는지 판단.
# - show_if_flag: 해당 flag가 true여야 함
# - show_if_quest_inactive: 해당 퀘스트가 아직 수락되지 않았을 때만 (수락 옵션용)
# - show_if_quest_active: 해당 퀘스트가 수락되어 진행 중일 때만 (진행 확인 옵션용)
# - show_if_seen: 해당 node_id를 이미 봤을 때만 (예: 이전 대화를 이어가는 후속 옵션)
# - show_if_not_seen: 해당 node_id를 아직 안 봤을 때만 (show_if_seen과 짝지어 옵션을 서로 대체하는 용도)
func _is_option_visible(option: Dictionary) -> bool:
	var show_if_flag: String = option.get("show_if_flag", "")
	if show_if_flag != "" and not GameState.get_flag(show_if_flag):
		return false

	var quest_inactive: String = option.get("show_if_quest_inactive", "")
	if quest_inactive != "" and GameState.is_quest_active(quest_inactive):
		return false

	var quest_active: String = option.get("show_if_quest_active", "")
	if quest_active != "" and not GameState.is_quest_active(quest_active):
		return false

	var show_if_seen: String = option.get("show_if_seen", "")
	if show_if_seen != "" and not GameState.has_seen_node(show_if_seen):
		return false

	var show_if_not_seen: String = option.get("show_if_not_seen", "")
	if show_if_not_seen != "" and GameState.has_seen_node(show_if_not_seen):
		return false

	return true


# 옵션의 required_affinity 조건을 만족하는지 (없으면 항상 true). 미충족 옵션은 보이되 선택 불가(빨강)
func _is_affinity_met(option: Dictionary) -> bool:
	var req: Dictionary = option.get("required_affinity", {})
	if req.is_empty():
		return true
	return GameState.get_affinity(req.get("npc_id", "")) >= int(req.get("min", 0))


# 표시 조건을 통과한 옵션을 버튼에 채운다.
# - 이미 본 노드로 가는 옵션(next_id가 seen)은 회색 + 목록 맨 아래로 안정 정렬 (다시 듣기용, 클릭 가능)
# - 호감도 부족 옵션은 빨강 + 선택 시 안내만 (진행 안 됨)
# - 표시할 옵션이 없으면 next_id 유무에 따라 "[계속]"/"닫기" 버튼을 자동 생성
func _populate_options(options: Array, default_next_id: String = "") -> void:
	var visible_options := _filter_visible_options(options)
	var entries: Array = []

	if visible_options.is_empty():
		var fallback: Dictionary = {"label": "[계속]", "next_id": default_next_id} if default_next_id != "" else {"label": "닫기", "next_id": ""}
		entries.append({"option": fallback, "locked": false, "seen": false})
	else:
		for option in visible_options:
			entries.append({
				"option": option,
				"locked": not _is_affinity_met(option),
				"seen": GameState.has_seen_node(option.get("next_id", "")),
			})
		entries = _sort_seen_to_bottom(entries)

	var buttons := _options_container.get_children()
	for i in range(buttons.size()):
		var button := buttons[i] as Button
		if button.pressed.is_connected(_on_button_pressed):
			button.pressed.disconnect(_on_button_pressed)

		if i < entries.size():
			var entry: Dictionary = entries[i]
			var option: Dictionary = entry["option"]
			button.text = option.get("label", "")
			button.add_theme_color_override("font_color", _option_color(entry))
			button.pressed.connect(_on_button_pressed.bind(option))
			button.show()
		else:
			button.hide()


# 이미 본 옵션(seen)을 뒤로 보내되, 각 그룹 내 원래 순서는 유지하는 안정 정렬
func _sort_seen_to_bottom(entries: Array) -> Array:
	var unseen: Array = []
	var seen: Array = []
	for entry in entries:
		if entry["seen"]:
			seen.append(entry)
		else:
			unseen.append(entry)
	return unseen + seen


# 잠김(빨강) > 봄(회색) > 일반(갈색) 우선순위로 글자색을 고른다
func _option_color(entry: Dictionary) -> Color:
	if entry["locked"]:
		return COLOR_LOCKED
	if entry["seen"]:
		return COLOR_SEEN
	return COLOR_NORMAL


# 버튼 클릭 처리: 타이핑 중이면 텍스트만 즉시 완성. 다 표시된 상태면, 호감도가 부족한 옵션은
# 안내만 띄우고 진행하지 않고, 충족한 옵션은 실제로 선택해 다음으로 진행한다
func _on_button_pressed(option: Dictionary) -> void:
	if _typewriter.is_typing:
		_typewriter.skip()
		return

	if not _is_affinity_met(option):
		_typewriter.start(LOCKED_HINT) # 대사 자리에 잠깐 안내를 타이핑 (노드는 그대로, 옵션 유지)
		return

	_on_option_pressed(option)


# 옵션 버튼 클릭 시, flag_to_set / start_quest / affinity_change 같은 부수효과를 적용한 뒤 next_id 노드로 이동.
# - open_shop: 다음 노드로 넘어가지 않고 ShopMenu를 그 위에 띄움 (대화는 현재 노드에 그대로 멈춰있음)
# - min_quest_level: quest_level이 이 값 미만이면 start_quest 등 나머지 효과를 전부 건너뛰고
#   next_id_if_blocked로 대신 이동 (옵션 자체는 항상 보이되, 선택 시 조건만 검사하는 게이팅용)
func _on_option_pressed(option: Dictionary) -> void:
	if option.get("open_shop", false):
		ShopMenu.open()
		return

	var min_quest_level: int = option.get("min_quest_level", -1)
	if min_quest_level >= 0 and GameState.get_flag("quest_level") < min_quest_level:
		_show_node(option.get("next_id_if_blocked", ""))
		return

	var flag_to_set: String = option.get("flag_to_set", "")
	if flag_to_set != "":
		GameState.set_flag(flag_to_set, option.get("flag_value", false))

	var affinity_change: Dictionary = option.get("affinity_change", {})
	if not affinity_change.is_empty():
		GameState.change_affinity(affinity_change.get("npc_id", ""), int(affinity_change.get("amount", 0)))

	var start_quest: String = option.get("start_quest", "")
	if start_quest != "":
		GameState.start_quest(start_quest)

	var next_id: String = option.get("next_id", "")
	var next_by_affinity: Dictionary = option.get("next_id_by_affinity", {})
	if not next_by_affinity.is_empty():
		next_id = _resolve_next_id_by_affinity(next_by_affinity)

	_show_node(next_id)


# next_id_by_affinity = { "npc_id": String, "thresholds": [int, ...], "next_ids": [String, ...] }
# (next_ids.size() == thresholds.size() + 1). 현재 호감도를 thresholds와 낮은 값부터 비교해,
# 처음으로 "호감도 < threshold"를 만족하는 구간의 next_id를 고른다. 어떤 threshold보다도 크거나
# 같으면 마지막 next_id(최상위 구간)를 쓴다. 예: thresholds=[40,70], next_ids=[A,B,C]
# -> 호감도 <40: A, 40~69: B, 70+: C. (고정된 4단계 tier 이름으로는 표현하기 애매한, 이 옵션 전용
# 커스텀 구간이 필요할 때 text_by_affinity_tier 대신 사용)
func _resolve_next_id_by_affinity(spec: Dictionary) -> String:
	var value := GameState.get_affinity(spec.get("npc_id", ""))
	var thresholds: Array = spec.get("thresholds", [])
	var next_ids: Array = spec.get("next_ids", [])
	if next_ids.is_empty():
		return ""

	for i in range(thresholds.size()):
		if value < int(thresholds[i]):
			return next_ids[i]
	return next_ids[next_ids.size() - 1]


# 대화창을 숨기고, 마지막으로 보여줬던 노드 id와 함께 종료를 알림
func _end_dialogue() -> void:
	hide()
	dialogue_ended.emit(_last_shown_node_id)
