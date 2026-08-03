extends CanvasLayer

# 퀘스트 완료로 quest_level이 올라 GameState.leveled_up이 방출될 때 화면 중앙에 스탯 상승을 알리는
# 안내창 (autoload). "확인"을 눌러야 닫히며, 열려 있는 동안은 "level_up" 그룹으로 플레이어 이동/
# 다른 메뉴 열기를 막는다 (다른 UI 오버레이들과 동일한 그룹-가시성 패턴)

@onready var _root: Control = $Root
@onready var _stats_label: Label = $Root/Panel/VBox/StatsLabel
@onready var _confirm_button: Button = $Root/Panel/VBox/ConfirmButton


func _ready() -> void:
	# CanvasLayer 자신은 CanvasItem이 아니라 .visible 기반 차단 체크(as CanvasItem)에 걸리지 않으므로,
	# 실제로 보이고 숨겨지는 _root(Control)를 그룹에 등록한다
	_root.add_to_group("level_up")
	_root.visible = false
	_confirm_button.pressed.connect(_on_confirm)
	GameState.leveled_up.connect(_on_leveled_up)


# 레벨업 시 최대 체력/마나 상승폭을 안내 문구로 만들어 창을 띄움
func _on_leveled_up(hp_gain: int, mana_gain: int) -> void:
	_stats_label.text = "최대 체력 +%d\n최대 마나 +%d" % [hp_gain, mana_gain]
	_root.visible = true


func _on_confirm() -> void:
	_root.visible = false
