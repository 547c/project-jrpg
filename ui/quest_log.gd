extends Control

# 퀘스트 일지 패널. HUD의 "퀘스트" 버튼이 open()/close()로 토글한다.
# _root(자기 자신)가 "quest_log" 그룹에 속하고 visible로 열림 여부를 나타내 이동 잠금과 연동된다.

@onready var _quest_list: VBoxContainer = $Panel/VBox/QuestList
@onready var _empty_label: Label = $Panel/VBox/QuestList/EmptyLabel
@onready var _close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	add_to_group("quest_log")
	visible = false
	_close_button.pressed.connect(close)


# 현재 active인 퀘스트만 목록으로 다시 그리고 패널을 표시
func open() -> void:
	_rebuild()
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


# GameState.quests를 순회해 active인 퀘스트만 "제목 (부여자) — 1/3" 형태로 채움.
# 하나도 없으면 안내 문구만 표시
func _rebuild() -> void:
	# 이전에 동적으로 추가한 항목만 제거 (고정 노드 EmptyLabel은 유지)
	for child in _quest_list.get_children():
		if child != _empty_label:
			child.queue_free()

	var active_count := 0
	for quest_id in GameState.quests.keys():
		var quest: Dictionary = GameState.quests[quest_id]
		if not quest["active"]:
			continue
		active_count += 1
		_quest_list.add_child(_make_quest_entry(quest))

	_empty_label.visible = active_count == 0


# 퀘스트 하나를 표현하는 라벨 생성 (완료 시 "[완료]" 표기)
func _make_quest_entry(quest: Dictionary) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.22, 0.09, 0.03, 1))
	var progress := "%d/%d" % [quest["current"], quest["target"]]
	var suffix := "  [완료]" if quest["complete"] else ""
	label.text = "%s (%s) — %s%s" % [quest["title"], quest["giver"], progress, suffix]
	return label
