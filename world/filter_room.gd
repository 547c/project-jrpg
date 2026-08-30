extends Area2D

const WaterBurstEffect := preload("res://systems/water_burst_effect.gd")

# 씬12: 유적 필터룸. guardian_encounter.gd와 동일한 패턴(Area2D 트리거 + DialogueData 순차 재생 +
# 물 이펙트 재사용)으로, 문지기(ruins_boss)를 처치하기 전에는 들어갈 수 없고, 한 번 완료하면
# 다시 재생되지 않는다(has_seen_node로 판정 — guardian_event_done 같은 별도 플래그 불필요).

const DIALOGUE_START_ID := "filter_room_1"
const WATER_BURST_NODE_ID := "filter_room_waterburst"
const END_NODE_ID := "filter_room_end"

const NOT_READY_DIALOGUE: Array = [
	{"id": "filter_room_not_ready", "speaker": "", "narration": "안쪽은 아직 위험해 보인다. 문지기부터 처리해야 할 것 같다.", "is_decisive": false, "options": []},
]

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or GameState.has_seen_node(END_NODE_ID):
		return
	if not body.is_in_group("player"):
		return

	if not GameState.get_flag("ruins_boss_defeated"):
		_show_not_ready_message()
		return

	_triggered = true
	_start_encounter()


func _show_not_ready_message() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return
	dialogue_box.start_dialogue(NOT_READY_DIALOGUE, "filter_room_not_ready")


func _start_encounter() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	dialogue_box.start_dialogue(DialogueData.FILTER_ROOM_DIALOGUE, DIALOGUE_START_ID)
	_watch_for_water_burst(dialogue_box)


func _watch_for_water_burst(dialogue_box: DialogueBox) -> void:
	while is_instance_valid(dialogue_box) and dialogue_box.visible:
		if dialogue_box._last_shown_node_id == WATER_BURST_NODE_ID:
			WaterBurstEffect.play(self, global_position)
			return
		await get_tree().process_frame
