extends CanvasLayer

# 퀘스트 완료 / 레벨업을 알리는 안내창 (autoload). "확인"을 눌러야 닫히며, 열려 있는 동안은
# "level_up" 그룹으로 플레이어 이동/다른 메뉴 열기를 막는다 (다른 UI 오버레이들과 동일한 패턴).
#
# [전투 중에는 띄우지 않고 미뤄둔다] 경험치 도입 전에는 레벨업이 퀘스트 완료(=필드에서 대화하거나
# 상자를 열 때)에만 일어나서 그 자리에서 바로 띄우면 됐다. 이제는 몬스터를 잡을 때도 레벨이 오르는데,
# 전투 화면 위에 입력을 막는 창을 띄우면 승리 연출과 "닫기" 버튼 흐름을 정면으로 가로막는다.
# 그래서 전투 중에 들어온 안내는 큐에 쌓아두고, 전투를 빠져나와 화면이 한가해지면 그때 순서대로 띄운다.
#
# [왜 _process 폴링인가] "전투가 끝났다"를 알려주는 시그널이 따로 없고, 전투는 씬 교체로 끝나기
# 때문에(SceneManager가 전투 씬을 통째로 free) 연결해둘 대상도 사라진다. 큐가 비어 있으면 즉시
# 빠져나오는 폴링이라 비용도 사실상 없고, 어떤 경로로 전투가 끝나든(승리/도망/패배) 알아서 복구된다.

# 안내창을 띄우면 안 되는 상황을 나타내는 UI 그룹들 (이들이 보이는 동안은 큐에 쌓아둔다)
const BLOCKING_GROUPS := ["battle_box", "dialogue_box", "game_over", "cutscene_box"]

@onready var _root: Control = $Root
@onready var _title_label: Label = $Root/Panel/VBox/TitleLabel
@onready var _stats_label: Label = $Root/Panel/VBox/StatsLabel
@onready var _confirm_button: Button = $Root/Panel/VBox/ConfirmButton

# 아직 보여주지 못한 안내들. 각 항목은 {"title": String, "body": String} —
# 제목까지 담는 이유는 이 창이 이제 "퀘스트 완료"와 "레벨 업" 두 가지를 모두 알리기 때문이다
# (예전엔 둘이 항상 같이 일어나 제목이 "퀘스트 완료!"로 고정이었다)
var _pending_messages: Array[Dictionary] = []


func _ready() -> void:
	# CanvasLayer 자신은 CanvasItem이 아니라 .visible 기반 차단 체크(as CanvasItem)에 걸리지 않으므로,
	# 실제로 보이고 숨겨지는 _root(Control)를 그룹에 등록한다
	_root.add_to_group("level_up")
	_root.visible = false
	_confirm_button.pressed.connect(_on_confirm)
	GameState.quest_completed_notice.connect(_on_quest_completed)
	GameState.player_leveled_up.connect(_on_player_leveled_up)


# 큐에 밀린 안내가 있고 지금 띄워도 되는 상황이면 하나 꺼내 보여준다
func _process(_delta: float) -> void:
	if _pending_messages.is_empty() or _root.visible:
		return
	if _is_blocked():
		return
	_show(_pending_messages.pop_front())


func _is_blocked() -> bool:
	for group in BLOCKING_GROUPS:
		var ui := get_tree().get_first_node_in_group(group) as CanvasItem
		if ui != null and ui.visible:
			return true
	return false


# 퀘스트 완료 안내. 레벨업은 별도 시그널로 따로 오므로 여기서는 퀘스트와 보너스 경험치만 알린다
func _on_quest_completed(quest_title: String, xp_gained: int) -> void:
	var body := quest_title
	if xp_gained > 0:
		body += "\n경험치 +%d" % xp_gained
	_queue("퀘스트 완료!", body)


# 레벨업 안내 (한 번에 여러 레벨이 오르면 레벨마다 한 번씩 들어와 순서대로 쌓인다)
func _on_player_leveled_up(new_level: int, hp_gain: int, mana_gain: int, skill_point_gain: int) -> void:
	_queue("레벨 업!", "레벨 %d 달성!\n최대 체력 +%d / 최대 마나 +%d / 스킬포인트 +%d" % [
		new_level, hp_gain, mana_gain, skill_point_gain])


# 지금 띄울 수 있으면 바로, 아니면(전투 중 등) 큐에 넣어 나중에 띄운다
func _queue(title: String, body: String) -> void:
	var entry := {"title": title, "body": body}
	if _root.visible or _is_blocked():
		_pending_messages.append(entry)
		return
	_show(entry)


func _show(entry: Dictionary) -> void:
	_title_label.text = entry["title"]
	_stats_label.text = entry["body"]
	_root.visible = true


# 확인을 누르면 닫는다. 밀려 있던 안내가 더 있으면 다음 프레임에 _process가 이어서 띄운다
func _on_confirm() -> void:
	_root.visible = false
