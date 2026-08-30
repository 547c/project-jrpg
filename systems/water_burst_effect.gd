class_name WaterBurstEffect
extends RefCounted

# 물지기의 봉인이 풀릴 때 공통으로 쓰는 물 이펙트(SFX + 파티클 + 카메라 흔들림).
# guardian_encounter.gd(동굴)에서 처음 만들어졌고, filter_room.gd(유적 필터룸)에서도 그대로 재사용한다.

const SFX := "res://assets/sfx/400 Sounds pack/Environment/water_splashing.wav"
const PARTICLE_COUNT := 60
const LIFETIME := 1.4
const COLOR := Color(0.55, 0.85, 1.0, 0.85)
const CAMERA_SHAKE_STRENGTH := 6.0
const CAMERA_SHAKE_STEP := 0.05
const CAMERA_SHAKE_DURATION := 0.4


static func play(caller: Node, at_position: Vector2) -> void:
	SFXPlayer.play(SFX)
	_shake_camera(caller)

	var particles := CPUParticles2D.new()
	particles.global_position = at_position
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = PARTICLE_COUNT
	particles.lifetime = LIFETIME
	particles.direction = Vector2.UP
	particles.spread = 60.0
	particles.gravity = Vector2(0.0, 260.0)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = COLOR
	caller.get_parent().add_child(particles)
	particles.emitting = true
	caller.get_tree().create_timer(LIFETIME + 0.5).timeout.connect(particles.queue_free)


static func _shake_camera(caller: Node) -> void:
	if SceneManager._player == null:
		return
	var camera: Camera2D = SceneManager._player._camera
	var tween := caller.create_tween()
	var elapsed := 0.0
	while elapsed < CAMERA_SHAKE_DURATION:
		var offset := Vector2(randf_range(-CAMERA_SHAKE_STRENGTH, CAMERA_SHAKE_STRENGTH), randf_range(-CAMERA_SHAKE_STRENGTH, CAMERA_SHAKE_STRENGTH))
		tween.tween_property(camera, "offset", offset, CAMERA_SHAKE_STEP)
		elapsed += CAMERA_SHAKE_STEP
	tween.tween_property(camera, "offset", Vector2.ZERO, CAMERA_SHAKE_STEP)
