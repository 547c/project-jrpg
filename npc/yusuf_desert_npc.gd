@tool
extends NPC

const SPRITE_FRAMES := preload("res://npc/yusuf_sprite_frames.tres")

# 씬10-B: 유서프가 카밀의 배를 타고 사막까지 동행한 뒤, 나딤과의 첫 대화 전후로 짧게 반응만 남기는 버전.
# (2026-08-30 결정, 폐기됨) 실제 파티 시스템 없이 사막 씬에 배치된 NPC로만 존재한다(동료 시스템 불필요 — 문서 결정사항).
# 2026-09-06: 완전한 파티 시스템 채택 확정(docs/companion_system_options.md 참고). 유서프가 동료로 합류하면
# 이 배치형 NPC는 팔로워 시스템으로 대체될 예정 — 아직 미구현, Phase 2 작업 전까지 이 파일은 현행 유지.
func _ready() -> void:
	dialogue_tree = DialogueData.YUSUF_DESERT_DIALOGUE
	dialogue_start_id = "yusuf_desert_greeting"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.3594, 1.3594)
	_play_idle_or_static()
