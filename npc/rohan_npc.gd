@tool
extends NPC

const SPRITE_FRAMES := preload("res://npc/rohan_sprite_frames.tres")

# 로한 전용 설정: 대화 트리/시작 노드/met 플래그/스프라이트를 고정한 뒤 기본 NPC 초기화를 이어서 실행
# (@tool·에디터 가드 이유는 npc.gd 참고)
func _ready() -> void:
	dialogue_tree = DialogueData.ROHAN_DIALOGUE
	dialogue_start_id = "rohan_greeting"
	met_flag_name = "met_rohan"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.45, 1.45) # 플레이어(1.45)와의 비율 유지: 1.8 * (1.45/1.8)
	_play_idle_or_static()


# 엘라라를 아직 만나지 않았으면 짧은 placeholder만, 만났으면 정상 대화
func _resolve_start_id() -> String:
	return dialogue_start_id if GameState.get_flag("met_elara") else "rohan_locked_greeting"
