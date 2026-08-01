extends NPC

const SPRITE_FRAMES := preload("res://npc/mia_sprite_frames.tres")

# 미아 전용 설정: 대화 트리/시작 노드/met 플래그/스프라이트를 고정한 뒤 기본 NPC 초기화를 이어서 실행
func _ready() -> void:
	dialogue_tree = DialogueData.MIA_DIALOGUE
	dialogue_start_id = "mia_greeting"
	met_flag_name = "met_mia"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.45, 1.45) * 0.8 # 플레이어(1.45)와 같은 기준에서 아이처럼 보이도록 0.8배 추가
	$AnimatedSprite2D.play("idle")
