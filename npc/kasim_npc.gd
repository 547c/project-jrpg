extends NPC

# 카심(정체를 숨긴 무기 상인). 술집에 상주하며 검/지팡이/방패 9종을 판매한다.
# 전용 NPC 스프라이트가 이미 전부 소진돼(Knight/Rogue/Wizzard/Citizen_F 계열 모두 다른 NPC가 사용 중),
# 대신 몬스터 팩의 Skeleton - Rogue(후드 쓴 스켈레톤) 시트를 재활용했다 — 대화에서 그 정체를
# 플레이어가 직접 알아채는 것 자체가 캐릭터의 재미 포인트다(정체를 완전히 밝히지는 않는다).
const SPRITE_FRAMES := preload("res://npc/kasim_sprite_frames.tres")


# 카심 전용 설정을 고정한 뒤 기본 NPC 초기화를 이어서 실행
func _ready() -> void:
	dialogue_tree = DialogueData.KASIM_DIALOGUE
	dialogue_start_id = "kasim_greeting"
	met_flag_name = "met_kasim"
	npc_id = "kasim"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	# 몬스터 팩 시트(32x32 Idle)라 몬스터 표시 배율을 그대로 재사용한다 — 이미 플레이어(1.45배, 64px
	# 프레임) 기준으로 측정해둔 값이라(monster_encounter.gd의 DISPLAY_SCALE["SKELETON"]) 새로 잴 필요가 없다
	$AnimatedSprite2D.scale = Vector2(1.5104, 1.5104)
	$AnimatedSprite2D.play("idle")
