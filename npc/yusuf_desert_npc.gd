@tool
extends NPC

const SPRITE_FRAMES := preload("res://npc/yusuf_sprite_frames.tres")

# 씬10-B: 유서프가 카밀의 배를 타고 사막까지 동행한 뒤, 나딤과의 첫 대화 전후로 짧게 반응만 남기는 버전.
# 유서프가 이미 동료로 합류했으면(npc/yusuf_follower.gd가 대신 등장) 이 배치형 NPC는 나타나지 않는다.
func _ready() -> void:
	if not Engine.is_editor_hint() and GameState.is_companion_recruited("yusuf"):
		queue_free()
		return

	dialogue_tree = DialogueData.YUSUF_DESERT_DIALOGUE
	dialogue_start_id = "yusuf_desert_greeting"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.3594, 1.3594)
	_play_idle_or_static()
