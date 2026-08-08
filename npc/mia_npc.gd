extends NPC

const SPRITE_FRAMES := preload("res://npc/mia_sprite_frames.tres")

# 미아 전용 설정: 대화 트리/시작 노드/met 플래그/스프라이트를 고정한 뒤 기본 NPC 초기화를 이어서 실행
func _ready() -> void:
	dialogue_tree = DialogueData.MIA_DIALOGUE
	dialogue_start_id = "mia_greeting"
	met_flag_name = "met_mia"
	wander_radius_min = 15.0 # 실내(술집)라 다른 마을 NPC보다 좁게
	wander_radius_max = 20.0
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.45, 1.45) * 0.8 # 플레이어(1.45)와 같은 기준에서 아이처럼 보이도록 0.8배 추가
	$AnimatedSprite2D.play("idle")


# 로한과 유서프를 둘 다 만난 뒤에만 정상 대화(결정적 선택 포함)가 열림. 아니면 짧은 placeholder만
func _resolve_start_id() -> String:
	if GameState.get_flag("met_rohan") and GameState.get_flag("met_yusuf"):
		return dialogue_start_id
	return "mia_locked_greeting"
