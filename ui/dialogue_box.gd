class_name DialogueBox
extends Control

# 대화가 완전히 종료되었을 때 발행. last_node_id는 종료 직전 마지막으로 보여준 노드의 id
# (구독자가 "어떤 대사에서 끝났는지"로 특별 처리를 하고 싶을 때 사용 — 예: 엔딩 트리거)
signal dialogue_ended(last_node_id: String)

const MAX_OPTIONS := 5
# 좌우 분할 레이아웃 기준 높이. 왼쪽(화자+대사)과 오른쪽(옵션들) 중 큰 쪽으로 패널 높이가 정해진다.
# 세로로 쌓던 예전보다 낮아도 되므로 범위를 줄였다
const MIN_PANEL_HEIGHT := 140.0
const MAX_PANEL_HEIGHT := 340.0

# 옵션 버튼 글자색: 일반(갈색) / 잠김(빨강, 호감도 부족) / 이미 봄(회색). 우선순위 잠김 > 봄 > 일반
const COLOR_NORMAL := Color(0.22, 0.09, 0.03, 1)
const COLOR_LOCKED := Color(0.68, 0.14, 0.11, 1)
const COLOR_SEEN := Color(0.5, 0.43, 0.36, 1)

# 잠긴(호감도 부족) 옵션을 눌렀을 때 대사 자리에 잠깐 보여주는 안내
const LOCKED_HINT := "아직은... 좀 더 가까워져야 들을 수 있을 것 같다."

@onready var _decisive_frame: Control = $DecisiveFrame
@onready var _content: HBoxContainer = $Panel/HBox
@onready var _speaker_label: Label = $Panel/HBox/LeftColumn/SpeakerLabel
@onready var _narration_label: Label = $Panel/HBox/LeftColumn/NarrationLabel
@onready var _text_label: Label = $Panel/HBox/LeftColumn/TextLabel
@onready var _options_container: VBoxContainer = $Panel/HBox/OptionsContainer
@onready var _bleep_player: AudioStreamPlayer = $BleepPlayer

var _nodes_by_id: Dictionary = {}
var _last_shown_node_id: String = ""
var _typewriter: Typewriter


# 다른 씬에서 이 DialogueBox를 찾을 수 있도록 그룹에 등록하고 공용 타이핑 헬퍼를 준비
func _ready() -> void:
	add_to_group("dialogue_box")
	_typewriter = Typewriter.new(_text_label, _bleep_player)


# 대화 트리를 id 기준으로 인덱싱하고 start_id 노드부터 대화를 시작
func start_dialogue(dialogue_tree: Array, start_id: String) -> void:
	_nodes_by_id.clear()
	for node in dialogue_tree:
		_nodes_by_id[node["id"]] = node

	show()
	_show_node(start_id)


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

	_speaker_label.text = node.get("speaker", "")

	var narration: String = node.get("narration", "")
	_narration_label.text = narration
	_narration_label.visible = narration != ""

	_decisive_frame.visible = is_decisive
	_typewriter.start(_resolve_text(node))

	_populate_options(node.get("options", []), node.get("next_id", ""))
	_update_panel_height()


# 화자/지문/본문(왼쪽)과 옵션 개수(오른쪽) 중 더 높은 쪽에 맞춰 대화창 높이를 동적으로 조절.
# 화면 하단(offset_bottom)은 고정한 채 위쪽으로만 자라나게(offset_top만 변경) 해서
# 옵션/대사가 적을 땐 화면을 덜 가리고, 많을 때도 화면 밖으로 잘리지 않게 함.
# HBoxContainer의 최소 높이는 곧 좌우 컬럼 중 더 높은 쪽이므로 그 값을 그대로 쓴다
func _update_panel_height() -> void:
	var content_padding: float = _content.offset_top - _content.offset_bottom # HBox의 상하 여백(Panel 기준)
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


# text_if_flag가 있으면 해당 flag 값에 따라 text(참)/text_false(거짓)를 골라 반환, 없으면 text 그대로
func _resolve_text(node: Dictionary) -> String:
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

	_show_node(option.get("next_id", ""))


# 대화창을 숨기고, 마지막으로 보여줬던 노드 id와 함께 종료를 알림
func _end_dialogue() -> void:
	hide()
	dialogue_ended.emit(_last_shown_node_id)
