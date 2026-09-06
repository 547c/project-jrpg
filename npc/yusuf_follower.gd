@tool
extends NPC

const SPRITE_FRAMES := preload("res://npc/yusuf_sprite_frames.tres")

# 유서프가 동료로 합류한 뒤 오버월드에서 플레이어를 따라다니는 팔로워. 대화 트리는 씬10-B에서
# 배치형 NPC로 쓰던 것을 그대로 재사용한다 — 표시 방식만 바뀌는 것뿐, 새 대사는 없다.
# 배회 대신 _process()를 완전히 새로 정의해 플레이어를 뒤따르게 한다
const FOLLOW_SPEED := 150.0
const FOLLOW_CATCHUP_SPEED := 260.0
const FOLLOW_CATCHUP_DISTANCE := 140.0
const FOLLOW_STOP_DISTANCE := 36.0
const FOLLOW_SNAP_DISTANCE := 500.0
const FOLLOW_OFFSET := Vector2(-28, 18)


func _ready() -> void:
	dialogue_tree = DialogueData.YUSUF_DESERT_DIALOGUE
	dialogue_start_id = "yusuf_desert_greeting"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.3594, 1.3594)
	_play_idle_or_static()
	_interact_prompt.text = tr("[E] 동료와 대화")


# SceneManager가 씬을 옮겨 붙일 때마다 호출 (플레이어의 attach_shadow()와 같은 이유 —
# 그림자는 씬의 ShadowLayer가 들고 있어서 씬과 함께 사라진다)
func resync_shadow() -> void:
	_attach_shadow()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _in_dialogue:
		return
	if not SceneManager.has_player():
		return

	var target: Vector2 = SceneManager.get_player_position() + FOLLOW_OFFSET
	var to_target := target - global_position
	var dist := to_target.length()

	if dist > FOLLOW_SNAP_DISTANCE:
		global_position = target
		return
	if dist <= FOLLOW_STOP_DISTANCE:
		_update_wander_animation(false)
		return

	var speed := FOLLOW_CATCHUP_SPEED if dist > FOLLOW_CATCHUP_DISTANCE else FOLLOW_SPEED
	var direction := to_target.normalized()
	global_position += direction * min(speed * delta, dist)
	if absf(direction.x) > 0.01:
		_sprite.flip_h = direction.x < 0.0
	_update_wander_animation(true)
