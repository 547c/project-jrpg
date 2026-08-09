extends CanvasLayer

# 퀘스트 완료로 quest_level이 올라 GameState.quest_completed_with_level_up이 방출될 때 화면 중앙에
# "퀘스트 완료 + 레벨업"을 함께 알리는 안내창 (autoload). 현재 구조상 퀘스트 완료는 항상 레벨업을
# 동반하므로 별개의 두 팝업 대신 이 창 하나로 합쳐서 보여준다. "확인"을 눌러야 닫히며, 열려 있는
# 동안은 "level_up" 그룹으로 플레이어 이동/다른 메뉴 열기를 막는다 (다른 UI 오버레이들과 동일한 패턴)

@onready var _root: Control = $Root
@onready var _stats_label: Label = $Root/Panel/VBox/StatsLabel
@onready var _confirm_button: Button = $Root/Panel/VBox/ConfirmButton


func _ready() -> void:
	# CanvasLayer 자신은 CanvasItem이 아니라 .visible 기반 차단 체크(as CanvasItem)에 걸리지 않으므로,
	# 실제로 보이고 숨겨지는 _root(Control)를 그룹에 등록한다
	_root.add_to_group("level_up")
	_root.visible = false
	_confirm_button.pressed.connect(_on_confirm)
	GameState.quest_completed_with_level_up.connect(_on_quest_completed_with_level_up)


# 퀘스트 완료 + 레벨업 정보를 두 줄로 안내 문구를 만들어 창을 띄움
func _on_quest_completed_with_level_up(quest_title: String, hp_gain: int, mana_gain: int) -> void:
	_stats_label.text = "퀘스트 완료: %s\n레벨업! 최대 체력 +%d / 최대 마나 +%d" % [quest_title, hp_gain, mana_gain]
	_root.visible = true


func _on_confirm() -> void:
	_root.visible = false
