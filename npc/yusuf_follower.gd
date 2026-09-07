@tool
extends CompanionFollower

const SPRITE_FRAMES := preload("res://npc/yusuf_sprite_frames.tres")

# 유서프가 동료로 합류한 뒤 오버월드에서 플레이어를 따라다니는 팔로워. 대화 트리는 씬10-B에서
# 배치형 NPC로 쓰던 것을 그대로 재사용한다 — 표시 방식만 바뀌는 것뿐, 새 대사는 없다.
# 추종 이동 로직(가속/사거리/블러/방향전환)은 전부 companion_follower.gd 공용 — 여기는
# 유서프 전용 설정(대화 트리, 스프라이트)만 남긴다


func _ready() -> void:
	dialogue_tree = DialogueData.YUSUF_DESERT_DIALOGUE
	dialogue_start_id = "yusuf_desert_greeting"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.3594, 1.3594)
	_play_idle_or_static()
	_interact_prompt.text = tr("[E] 동료와 대화")
