extends CanvasLayer

# 엔딩 도감(기록) UI (autoload). 타이틀 화면의 "기록" 버튼이 open()으로 띄운다.
# SaveSlotMenu와 같은 모달 패턴(Dim + 나무 패널 + 닫기 버튼 + ESC로 닫기)을 따른다.
#
# 슬롯은 씬에 하드코딩하지 않고 EndingData.ENDINGS를 순회해 코드로 생성한다 —
# 2부 엔딩이 추가되면 ending_data.gd에 항목만 늘려도 이 UI가 그대로 확장된다
# (인벤토리 슬롯을 코드로 만드는 ui/inventory_menu.gd와 같은 방식).

const TITLE_FONT_SIZE := 18
const DESC_FONT_SIZE := 13
const SLOT_SEPARATION := 6

const COLOR_UNLOCKED_TITLE := Color(0.24, 0.11, 0.04, 1) # 나무 패널 위에 얹는 진한 갈색
const COLOR_UNLOCKED_DESC := Color(0.36, 0.24, 0.15, 1)
const COLOR_LOCKED := Color(0.45, 0.42, 0.4, 1) # 잠긴 엔딩은 흐릿한 회색

@onready var _root: Control = $Root
@onready var _progress_label: Label = $Root/Panel/VBox/ProgressLabel
@onready var _list: VBoxContainer = $Root/Panel/VBox/List
@onready var _close_button: Button = $Root/Panel/VBox/CloseButton

# 슬롯별로 만들어 둔 라벨들 (엔딩 목록 순서와 1:1 대응) — 갱신 시 텍스트/색만 바꾼다
var _title_labels: Array[Label] = []
var _desc_labels: Array[Label] = []


func _ready() -> void:
	_root.visible = false
	_close_button.pressed.connect(close)
	GameState.endings_changed.connect(_on_endings_changed)
	_build_slots()


# EndingData.ENDINGS 순서대로 슬롯(제목 라벨 + 설명 라벨)을 생성
func _build_slots() -> void:
	for _ending in EndingData.ENDINGS:
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 2)
		_list.add_child(slot)

		var title := Label.new()
		title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
		slot.add_child(title)

		var desc := Label.new()
		desc.add_theme_font_size_override("font_size", DESC_FONT_SIZE)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(desc)

		_title_labels.append(title)
		_desc_labels.append(desc)


func open() -> void:
	_refresh()
	_root.visible = true


func close() -> void:
	_root.visible = false


func is_open() -> bool:
	return _root.visible


# 도감이 열려 있는 동안 새 엔딩이 기록되면 즉시 반영 (보통은 닫혀 있어 아무 일도 안 함)
func _on_endings_changed() -> void:
	if is_open():
		_refresh()


# 각 슬롯을 현재 기록 상태로 갱신: 본 엔딩은 제목+설명, 못 본 엔딩은 ???+잠금 안내
func _refresh() -> void:
	for i in range(EndingData.ENDINGS.size()):
		var ending: Dictionary = EndingData.ENDINGS[i]
		var seen: bool = GameState.has_seen_ending(ending["id"])
		var title: Label = _title_labels[i]
		var desc: Label = _desc_labels[i]

		title.text = ending["title"] if seen else EndingData.LOCKED_TITLE
		desc.text = ending["description"] if seen else EndingData.LOCKED_DESCRIPTION
		title.add_theme_color_override("font_color", COLOR_UNLOCKED_TITLE if seen else COLOR_LOCKED)
		desc.add_theme_color_override("font_color", COLOR_UNLOCKED_DESC if seen else COLOR_LOCKED)

	_progress_label.text = "%d / %d" % [GameState.seen_ending_count(), EndingData.total_count()]


# 열려 있을 때 ESC로 닫기 (SaveSlotMenu와 동일한 동작)
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
