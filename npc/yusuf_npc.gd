@tool
extends NPC

const SPRITE_FRAMES := preload("res://npc/yusuf_sprite_frames.tres")

# 유서프 전용 설정: 대화 트리/시작 노드/met 플래그/스프라이트를 고정한 뒤 기본 NPC 초기화를 이어서 실행
# (@tool·에디터 가드 이유는 npc.gd 참고)
func _ready() -> void:
	dialogue_tree = DialogueData.YUSUF_DIALOGUE
	dialogue_start_id = "yusuf_greeting"
	met_flag_name = "met_yusuf"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.3594, 1.3594) # 플레이어(1.45)와의 비율 유지: 1.6875 * (1.45/1.8)
	_play_idle_or_static()


# 엘라라를 아직 만나지 않았으면 짧은 placeholder만, 만났으면 정상 대화
func _resolve_start_id() -> String:
	return dialogue_start_id if GameState.get_flag("met_elara") else "yusuf_locked_greeting"
