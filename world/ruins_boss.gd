class_name RuinsBoss
extends MonsterEncounter

# 유적 문지기 보스. 일반 MonsterEncounter(monster_encounter.gd)를 확장해, 접촉 시 곧바로 전투가
# 시작되는 대신 짧은 대치 대화(문지기는 대화가 통하지 않는다)를 먼저 보여준 뒤 전투로 넘어간다.
# 처치 후에는 (씬 재로드 시) 유서프의 짧은 반응 대사가 한 번 자동으로 재생되고, 이야기상
# 1회성 보스라 다시 리젠하지 않는다.

const INTRO_DIALOGUE: Array = [
	{
		"id": "ruins_boss_greeting",
		"speaker": "문지기",
		"narration": "(기계적인 목소리로)",
		"text": "...허가되지 않은 자. 물러가라.",
		"is_decisive": false,
		"options": [
			{"label": "[당신도 감시자예요?]", "next_id": "ruins_boss_repeat"},
		],
	},
	{
		"id": "ruins_boss_repeat",
		"speaker": "문지기",
		"narration": "(문지기는 반응 없이 같은 말만 반복한다. 대화가 통하지 않는다 — 이미 이 존재도 오래전에 인간성을 잃은 듯하다)",
		"text": "...허가되지 않은 자. 물러가라.",
		"is_decisive": false,
		"options": [
			{"label": "[전투]", "next_id": "ruins_boss_fight_confirm"},
		],
	},
	{
		"id": "ruins_boss_fight_confirm",
		"speaker": "",
		"text": "",
		"is_decisive": false,
		"options": [],
	},
]

const AFTERMATH_DIALOGUE: Array = [
	{
		"id": "ruins_boss_aftermath_1",
		"speaker": "유서프",
		"narration": "(문지기를 내려다보며)",
		"text": "...이것도 한때는 사람이었을까.",
		"is_decisive": false,
		"options": [
			{"label": "[모르겠어요. 근데 왠지, 그럴 것 같아요.]", "next_id": "ruins_boss_aftermath_end"},
		],
	},
	{
		"id": "ruins_boss_aftermath_end",
		"speaker": "유서프",
		"narration": "(고개를 끄덕인다)",
		"text": "...가자.",
		"is_decisive": false,
		"options": [],
	},
]


func _ready() -> void:
	super._ready()
	if not GameState.get_flag("ruins_boss_defeated"):
		return

	# 이미 처치된 보스라면(전투 승리 직후든, 나중에 다시 들어온 것이든) 씬 로드 즉시 숨기고
	# 상호작용을 막는다 — enter_regen_state()는 전투 복귀 흐름에서만 호출되므로,
	# ToDesert로 나갔다 다시 들어오는 것 같은 일반적인 재방문에는 이 체크가 반드시 필요하다
	visible = false
	monitoring = false
	if not GameState.has_seen_node("ruins_boss_aftermath_end"):
		call_deferred("_show_aftermath_dialogue")


# 이미 처치된 보스라면(씬 재로드 시) 다시 리젠하지 않고 영구히 숨긴다
func enter_regen_state() -> void:
	if GameState.get_flag("ruins_boss_defeated"):
		_triggered = false
		_regenerating = true
		if _sprite != null:
			_sprite.visible = false
		monitoring = false
		return
	super.enter_regen_state()


# 접촉 시 곧바로 전투로 넘어가는 대신, 먼저 문지기와의 짧은 대치 대화를 보여준다
func _on_body_entered(body: Node2D) -> void:
	if _triggered or _regenerating:
		return
	if not body.is_in_group("player"):
		return
	if SceneManager.is_transition_suppressed():
		return

	_triggered = true
	_alert_label.hide()

	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		_begin_battle()
		return

	if not dialogue_box.dialogue_ended.is_connected(_on_intro_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_intro_dialogue_ended, CONNECT_ONE_SHOT)
	dialogue_box.start_dialogue(INTRO_DIALOGUE, "ruins_boss_greeting")


func _on_intro_dialogue_ended(last_node_id: String) -> void:
	if last_node_id == "ruins_boss_fight_confirm":
		_begin_battle()
		return
	_triggered = false


# monster_encounter.gd의 _on_body_entered 후반부(전투 진입)와 동일한 로직
func _begin_battle() -> void:
	var return_path := ""
	var current := get_tree().current_scene
	if current != null:
		return_path = current.scene_file_path

	var variants := BattleData.build_group_variants(monster_type, _variant)
	SceneManager.enter_battle(monster_type, variants, encounter_id, return_path, SceneManager.get_player_position())


func _show_aftermath_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return
	dialogue_box.start_dialogue(AFTERMATH_DIALOGUE, "ruins_boss_aftermath_1")
