class_name FireflyEmitter
extends Node2D

# 오브젝트 풀링/카메라 스폰 범위 계산은 world/leaf_emitter.gd와 동일한 구조를 재사용

enum _Kind { FIREFLY, MOTE }

const GLOW_TEXTURE_SIZE := 16

@export var camera_margin := 40.0
@export var firefly_count := 18
@export var mote_count := 10

const FIREFLY_LEASH_RADIUS := 70.0
const FIREFLY_WANDER_SPEED_RANGE := Vector2(6.0, 14.0)
const FIREFLY_HEADING_CHANGE_INTERVAL := Vector2(1.5, 3.0)
const FIREFLY_TURN_RATE := 0.8
const FIREFLY_SCALE_RANGE := Vector2(0.5, 0.9)
const FIREFLY_PULSE_FREQ_RANGE := Vector2(0.15, 0.3)
const FIREFLY_HUE_RANGE := Vector2(0.18, 0.28)
const FIREFLY_LIFETIME_RANGE := Vector2(8.0, 14.0)
const FIREFLY_FADE_DURATION := 1.2

const MOTE_DRIFT_SPEED_RANGE := Vector2(6.0, 12.0)
const MOTE_SWAY_AMPLITUDE_RANGE := Vector2(16.0, 30.0)
const MOTE_SWAY_FREQUENCY_RANGE := Vector2(0.08, 0.16)
const MOTE_SCALE_RANGE := Vector2(1.2, 1.8)
const MOTE_HUE_RANGE := Vector2(0.55, 0.62)
const MOTE_SAT_RANGE := Vector2(0.05, 0.2)
const MOTE_LIFETIME_RANGE := Vector2(10.0, 16.0)
const MOTE_FADE_DURATION := 1.6

const SPAWN_FADE_IN_DURATION := 1.0


class _Particle:
	var sprite: Sprite2D
	var active: bool = false
	var kind: int
	var base_pos: Vector2
	var age: float = 0.0
	var lifetime: float = 0.0
	var fading: bool = false
	var fade_timer: float = 0.0
	var fade_duration: float = 1.0
	var color: Color = Color.WHITE
	var heading: float = 0.0
	var heading_target: float = 0.0
	var heading_timer: float = 0.0
	var wander_speed: float = 0.0
	var pulse_freq: float = 0.0
	var pulse_phase: float = 0.0
	var drift_dir: Vector2 = Vector2.ZERO
	var drift_speed: float = 0.0
	var sway_amp: float = 0.0
	var sway_freq: float = 0.0
	var sway_phase: float = 0.0


var _particles: Array[_Particle] = []
var _glow_texture: ImageTexture
var _glow_material: CanvasItemMaterial


func _ready() -> void:
	if not get_parent().is_in_group("fairy_forest_ambience"):
		set_process(false)
		return

	_glow_texture = _build_glow_texture()
	_glow_material = CanvasItemMaterial.new()
	_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	for i in range(firefly_count):
		_particles.append(_make_particle(_Kind.FIREFLY))
	for i in range(mote_count):
		_particles.append(_make_particle(_Kind.MOTE))

	z_index = SceneManager.PLAYER_OVERLAY_Z_INDEX + 1

	for p in _particles:
		_spawn_particle(p)


func _process(delta: float) -> void:
	for p in _particles:
		if p.active:
			_update_particle(p, delta)
		else:
			_spawn_particle(p)


func _make_particle(kind: int) -> _Particle:
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture = _glow_texture
	sprite.material = _glow_material
	sprite.visible = false
	add_child(sprite)

	var p := _Particle.new()
	p.sprite = sprite
	p.kind = kind
	return p


# 소프트 원형 글로우를 코드로 직접 그린다 — 거리 기반 제곱 감쇠라 중심은 밝고 가장자리는 부드럽게 사라진다
func _build_glow_texture() -> ImageTexture:
	var img := Image.create(GLOW_TEXTURE_SIZE, GLOW_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2.ONE * GLOW_TEXTURE_SIZE * 0.5
	var radius := GLOW_TEXTURE_SIZE * 0.5
	for y in range(GLOW_TEXTURE_SIZE):
		for x in range(GLOW_TEXTURE_SIZE):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))
	return ImageTexture.create_from_image(img)


# leaf_emitter.gd와 동일하게, 실제로 렌더링되는 화면 중심(카메라 지연 반영)을 기준으로 스폰 범위를 구함
func _get_camera_view_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2()
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var zoom: float = maxf(camera.zoom.x, 0.01)
	var half_size := viewport_size / zoom / 2.0 + Vector2(camera_margin, camera_margin)
	var center := camera.get_screen_center_position()
	return Rect2(center - half_size, half_size * 2.0)


func _spawn_particle(p: _Particle) -> void:
	var view_rect := _get_camera_view_rect()
	if view_rect.size == Vector2.ZERO:
		return

	var spawn_global := Vector2(
		randf_range(view_rect.position.x, view_rect.end.x),
		randf_range(view_rect.position.y, view_rect.end.y),
	)
	p.base_pos = to_local(spawn_global)
	p.sprite.position = p.base_pos
	p.age = 0.0
	p.fading = false
	p.fade_timer = 0.0

	if p.kind == _Kind.FIREFLY:
		p.color = _random_firefly_color()
		p.lifetime = randf_range(FIREFLY_LIFETIME_RANGE.x, FIREFLY_LIFETIME_RANGE.y)
		p.fade_duration = FIREFLY_FADE_DURATION
		p.sprite.scale = Vector2.ONE * randf_range(FIREFLY_SCALE_RANGE.x, FIREFLY_SCALE_RANGE.y)
		p.heading = randf_range(0.0, TAU)
		p.heading_target = p.heading
		p.heading_timer = randf_range(FIREFLY_HEADING_CHANGE_INTERVAL.x, FIREFLY_HEADING_CHANGE_INTERVAL.y)
		p.wander_speed = randf_range(FIREFLY_WANDER_SPEED_RANGE.x, FIREFLY_WANDER_SPEED_RANGE.y)
		p.pulse_freq = randf_range(FIREFLY_PULSE_FREQ_RANGE.x, FIREFLY_PULSE_FREQ_RANGE.y)
		p.pulse_phase = randf_range(0.0, TAU)
	else:
		p.color = _random_mote_color()
		p.lifetime = randf_range(MOTE_LIFETIME_RANGE.x, MOTE_LIFETIME_RANGE.y)
		p.fade_duration = MOTE_FADE_DURATION
		p.sprite.scale = Vector2.ONE * randf_range(MOTE_SCALE_RANGE.x, MOTE_SCALE_RANGE.y)
		p.drift_dir = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		p.drift_speed = randf_range(MOTE_DRIFT_SPEED_RANGE.x, MOTE_DRIFT_SPEED_RANGE.y)
		p.sway_amp = randf_range(MOTE_SWAY_AMPLITUDE_RANGE.x, MOTE_SWAY_AMPLITUDE_RANGE.y)
		p.sway_freq = randf_range(MOTE_SWAY_FREQUENCY_RANGE.x, MOTE_SWAY_FREQUENCY_RANGE.y)
		p.sway_phase = randf_range(0.0, TAU)

	p.sprite.modulate = Color(p.color.r, p.color.g, p.color.b, 0.0)
	p.sprite.visible = true
	p.active = true


func _update_particle(p: _Particle, delta: float) -> void:
	p.age += delta

	if p.kind == _Kind.FIREFLY:
		_update_firefly_motion(p, delta)
	else:
		_update_mote_motion(p, delta)

	if not p.fading and p.age >= p.lifetime:
		p.fading = true
		p.fade_timer = 0.0
	elif p.fading:
		p.fade_timer += delta

	p.sprite.modulate = Color(p.color.r, p.color.g, p.color.b, _particle_alpha(p))

	if p.fading and p.fade_timer >= p.fade_duration:
		p.active = false
		p.sprite.visible = false


# 목표 방향을 몇 초에 한 번만 다시 뽑고(제자리 근처를 벗어나면 base_pos 쪽으로 편향), 그 사이엔
# 매 프레임 현재 방향을 그쪽으로 서서히(lerp_angle) 돌려 "천천히 방향을 바꾸는" 부유가 되게 함
func _update_firefly_motion(p: _Particle, delta: float) -> void:
	p.heading_timer -= delta
	if p.heading_timer <= 0.0:
		p.heading_timer = randf_range(FIREFLY_HEADING_CHANGE_INTERVAL.x, FIREFLY_HEADING_CHANGE_INTERVAL.y)
		var to_base := p.base_pos - p.sprite.position
		var pull := clampf(to_base.length() / FIREFLY_LEASH_RADIUS, 0.0, 1.0)
		p.heading_target = lerp_angle(randf_range(0.0, TAU), to_base.angle(), pull)

	p.heading = lerp_angle(p.heading, p.heading_target, delta * FIREFLY_TURN_RATE)
	p.sprite.position += Vector2.RIGHT.rotated(p.heading) * p.wander_speed * delta


# base_pos는 직선으로 서서히 흘러가고, 실제 스프라이트는 그 진행 방향에 수직으로 사인파 오프셋을
# 더해 곡선 궤적을 그림 (leaf_emitter의 좌우 sway를 임의의 진행 방향으로 일반화한 것)
func _update_mote_motion(p: _Particle, delta: float) -> void:
	p.base_pos += p.drift_dir * p.drift_speed * delta
	var perpendicular := Vector2(-p.drift_dir.y, p.drift_dir.x)
	var offset := sin(p.age * p.sway_freq * TAU + p.sway_phase) * p.sway_amp
	p.sprite.position = p.base_pos + perpendicular * offset


func _particle_alpha(p: _Particle) -> float:
	var envelope := 1.0
	if p.age < SPAWN_FADE_IN_DURATION:
		envelope = p.age / SPAWN_FADE_IN_DURATION
	if p.fading:
		envelope = minf(envelope, 1.0 - p.fade_timer / p.fade_duration)

	if p.kind == _Kind.FIREFLY:
		var pulse := sin(p.age * p.pulse_freq * TAU + p.pulse_phase) * 0.5 + 0.5
		return envelope * lerpf(0.25, 1.0, pulse)
	return envelope * 0.85


func _random_firefly_color() -> Color:
	var hue := randf_range(FIREFLY_HUE_RANGE.x, FIREFLY_HUE_RANGE.y)
	return Color.from_hsv(hue, randf_range(0.55, 0.8), 1.0)


func _random_mote_color() -> Color:
	var hue := randf_range(MOTE_HUE_RANGE.x, MOTE_HUE_RANGE.y)
	return Color.from_hsv(hue, randf_range(MOTE_SAT_RANGE.x, MOTE_SAT_RANGE.y), 1.0)
