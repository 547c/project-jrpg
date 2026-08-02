extends NPC

const SPRITE_FRAMES := preload("res://npc/elara_sprite_frames.tres")
const ENDING_TRIGGER_NODE_ID := "elara_ending_trigger"

# 엘라라 전용 설정: 대화 트리/시작 노드/met 플래그/스프라이트를 고정한 뒤 기본 NPC 초기화를 이어서 실행
func _ready() -> void:
	dialogue_tree = DialogueData.ELARA_DIALOGUE
	dialogue_start_id = "elara_greeting"
	met_flag_name = "met_elara"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.5, 1.5) # 플레이어(1.45)와의 비율 유지: 1.8621 * (1.45/1.8)
	$AnimatedSprite2D.play("idle")


# 기본 동작(안내 문구 복원)을 그대로 수행한 뒤, 대화가 엔딩 트리거 노드에서 끝났다면 엔딩으로 전환
func _on_dialogue_ended(last_node_id: String = "") -> void:
	super._on_dialogue_ended()
	if last_node_id == ENDING_TRIGGER_NODE_ID:
		_trigger_ending()


# GameState.check_ending() 결과에 맞는 엔딩 씬으로 SceneManager를 통해 전환
func _trigger_ending() -> void:
	var ending := GameState.check_ending()
	SceneManager.change_scene("res://endings/ending_%s.tscn" % ending, "")
