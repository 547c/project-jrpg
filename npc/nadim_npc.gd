@tool
extends NPC

# 나딤(사막 정착지의 지도자/생존자). 2부 초반, 카밀의 배를 타고 사막에 도착한 뒤 만나는 NPC.
# 카밀과 달리 등장 게이팅이 없어 desert.tscn에 처음부터 상주하며, 대화 끝(nadim_quest_offer)에서
# ruins_available flag를 켜 유적 입구를 열어준다. 스프라이트만 전용(Tavern_B)으로 바꿔 끼운다.

const SPRITE_FRAMES := preload("res://npc/nadim_sprite_frames.tres")


# 나딤 전용 설정을 고정한 뒤 기본 NPC 초기화를 이어서 실행하고, 전용 스프라이트로 교체한다
# (@tool·에디터 가드 이유는 npc.gd 참고)
func _ready() -> void:
	dialogue_tree = DialogueData.NADIM_DIALOGUE
	dialogue_start_id = "nadim_greeting"
	met_flag_name = "met_nadim"
	npc_id = "nadim"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.45, 1.45)
	_play_idle_or_static()
