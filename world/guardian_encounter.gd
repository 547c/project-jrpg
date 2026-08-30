extends Area2D

const WaterBurstEffect := preload("res://systems/water_burst_effect.gd")

const DIALOGUE_START_ID := "guardian_entrance"
const RETURN_SCENE_PATH := "res://world/village.tscn"
const RETURN_SPAWN_POINT := "VillageSpawnFromCave"
const REQUIRED_PROGRESS := 2 # 이 이상이어야 실제 수호자 이벤트가 시작됨 (숲/동굴 서브퀘 완료 개수)

const WATER_BURST_NODE_IDS := ["guardian_fight_aftermath", "guardian_peace_farewell"]

# progress(진행도)가 부족할 때 대신 보여주는 짧은 안내 (선택지 없이 닫기만)
const NOT_READY_DIALOGUE: Array = [
	{"id": "not_ready", "speaker": "", "narration": "아직 준비가 안 된 것 같다.", "is_decisive": false, "options": []},
]

var _triggered: bool = false


# body_entered 시그널을 콜백에 연결
func _ready() -> void:
	body_entered.connect(_on_body_entered)


# 플레이어가 처음 도달했을 때만(1회 제한) 수호자 조우를 시작.
# progress(진행도)가 아직 부족하면 전투/대화 없이 짧은 안내만 띄우고 그냥 지나가게 함(재시도 가능)
func _on_body_entered(body: Node2D) -> void:
	if _triggered or GameState.get_flag("guardian_event_done"):
		return
	if not body.is_in_group("player"):
		return

	if GameState.get_flag("progress") < REQUIRED_PROGRESS:
		_show_not_ready_message()
		return

	_triggered = true
	GameState.set_flag("guardian_event_done", true)
	_start_encounter()


# progress(진행도)가 부족할 때 보여주는 안내 메시지 (guardian_event_done을 세우지 않으므로 나중에 다시 시도 가능)
func _show_not_ready_message() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	dialogue_box.start_dialogue(NOT_READY_DIALOGUE, "not_ready")


# 기존 DialogueBox를 찾아 수호자 대화를 시작 (전투는 없지만 대치의 긴장감을 위해 결전곡을 틀어줌)
func _start_encounter() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	MusicManager.play("Decisive Battle 1 - Don't Be Afraid")

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	dialogue_box.start_dialogue(DialogueData.GUARDIAN_DIALOGUE, DIALOGUE_START_ID)
	_watch_for_water_burst(dialogue_box)


# 전투/평화 두 결말 모두 그 결과 나레이션 노드가 뜨는 순간 물이 터져 나오는 연출을 재생한다.
# 그 노드 하나만 지나가면 되므로, 도달을 확인하는 즉시 감시를 멈춘다
func _watch_for_water_burst(dialogue_box: DialogueBox) -> void:
	while is_instance_valid(dialogue_box) and dialogue_box.visible:
		if dialogue_box._last_shown_node_id in WATER_BURST_NODE_IDS:
			WaterBurstEffect.play(self, global_position)
			return
		await get_tree().process_frame


# 대화가 끝나면 동굴 볼일이 끝났다는 의미로 숲으로 자동 전환
func _on_dialogue_ended(_last_node_id: String = "") -> void:
	SceneManager.change_scene(RETURN_SCENE_PATH, RETURN_SPAWN_POINT)
