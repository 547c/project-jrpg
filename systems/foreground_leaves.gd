extends CanvasLayer

# 카메라 바로 앞을 스쳐 지나가는 "전경 낙엽" (autoload). world/leaf_emitter.gd의 배경 낙엽과
# 짝을 이루는 화면 공간 레이어다. SceneTint(layer 2)/SpeedVignette(layer 3) 위, HUD(layer 8)
# 아래에 그려서 — 게임 월드와 달리기 비네트 위로는 지나가되 UI는 절대 가리지 않는다
# (레이어 값 자체는 systems/foreground_leaves.tscn에 있다).
#
# [왜 world/leaf_emitter.gd처럼 월드 좌표가 아니라 화면 좌표인가]
# 배경 낙엽은 맵 위에 실제로 놓인 것처럼 보여야 해서 카메라를 따라 화면 안에서 자연스럽게
# 스쳐 지나가야 하니 월드 좌표가 맞다. 전경 낙엽은 반대로 "카메라 렌즈 앞을 스치는 먼지"에
# 가까운 연출이라 카메라가 어디를 보든 화면 기준으로 위→아래로 지나가면 충분하다. CanvasLayer는
# 원래 카메라의 줌/이동 변환을 받지 않고 항상 화면 좌표로 그려지므로(HUD가 늘 화면에 고정되는
# 것과 같은 이유), 여기서는 그 성질을 그대로 이용해 좌표 변환 없이 화면 픽셀만 다루면 된다.
#
# [왜 씬마다 배치하지 않고 오토로드인가, 그리고 언제 쉬는가]
# SpeedVignette/SceneTint와 같은 이유로 화면 공간 오버레이는 씬이 바뀌어도 항상 같은 레이어에
# 있어야 한다. 다만 배경 낙엽이 없는 씬(전투/동굴/실내 등)에서까지 전경 잎이 날리면 안 되므로,
# 현재 씬에 world/leaf_emitter.gd 인스턴스가 있을 때만(= "leaf_emitter" 그룹에 노드가 있을
# 때만) 스폰한다 — 없으면 매 프레임 그룹 조회 한 번만 하고 조용히 쉰다.

const LEAF_SHEET: Texture2D = preload("res://assets/vfx/ELR_LeafSheet.png")
const BLUR_SHADER: Shader = preload("res://systems/foreground_leaf_blur.gdshader")
const FRAME_SIZE := 16
const FRAME_COUNT := 5

const POOL_SIZE := 3 # 동시에 1~3개 정도만 — 배경 낙엽과 달리 "가끔 스쳐가는 하나"가 핵심
const SPAWN_INTERVAL := Vector2(4.0, 9.0) # 배경 낙엽(0.09~0.22초)보다 훨씬 드물게
const SCALE_RANGE := Vector2(2.5, 3.0) # 배경 낙엽보다 2.5~3배 크게 — 카메라에 가까운 느낌
# px/s, 화면 기준. 배경 낙엽(18~30px/s, 월드 기준)과 좌표계가 달라 직접 비교되는 수치는 아니고,
# "화면을 가로지르는 데 걸리는 시간이 배경 낙엽의 낙하~착지 체감(약 2~3초)과 비슷하게" 잡은 값이다
const FALL_SPEED_RANGE := Vector2(220.0, 340.0)
const SWAY_AMPLITUDE_RANGE := Vector2(14.0, 26.0)
const SWAY_FREQUENCY_RANGE := Vector2(1.0, 1.8)
const SPIN_SPEED_RANGE := Vector2(-1.0, 1.0)
const FADE_OUT_DURATION := 0.4
const EDGE_MARGIN := 60.0 # 화면 위쪽에서 이만큼 위, 아래쪽에서 이만큼 아래는 "이미 화면 밖"으로 친다
const MAX_LIFETIME := 6.0 # 화면을 못 벗어난 채 시간이 너무 지났을 때(정상적으로는 안 일어남)의 안전장치

# 색조 3종(진녹/연녹/황록) — world/leaf_emitter.gd의 HUE_VARIANTS와 완전히 같은 값이다. 두 파일이
# 서로 참조하기엔(하나는 월드 노드, 하나는 오토로드) 결합이 부자연스럽고, 값 자체도 가벼워서
# "같은 낙엽"이라는 통일감을 우선해 그대로 복제했다. 색을 조정할 땐 두 파일 모두 맞출 것
const HUE_VARIANTS: Array[Dictionary] = [
	{"hue": 0.34, "sat": Vector2(0.55, 0.75), "val": Vector2(0.28, 0.42)}, # 진녹색
	{"hue": 0.31, "sat": Vector2(0.30, 0.48), "val": Vector2(0.68, 0.88)}, # 연녹색
	{"hue": 0.24, "sat": Vector2(0.45, 0.65), "val": Vector2(0.55, 0.75)}, # 황록색
]
const HUE_JITTER := 0.015


class _FgLeaf:
	var sprite: Sprite2D
	var material: ShaderMaterial
	var active: bool = false
	var fading: bool = false
	var timer: float = 0.0 # fading 상태에서 흐른 시간
	var age: float = 0.0
	var base_x: float = 0.0
	var color: Color = Color.WHITE
	var sway_phase: float = 0.0
	var sway_amp: float = 0.0
	var sway_freq: float = 0.0
	var fall_speed: float = 0.0
	var spin_speed: float = 0.0


var _leaves: Array[_FgLeaf] = []
var _frames: Array[AtlasTexture] = []
var _spawn_timer: float = 0.0


func _ready() -> void:
	for i in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = LEAF_SHEET
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_frames.append(atlas)

	for i in range(POOL_SIZE):
		var sprite := Sprite2D.new()
		sprite.centered = true
		sprite.visible = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = BLUR_SHADER
		sprite.material = mat
		add_child(sprite)
		var leaf := _FgLeaf.new()
		leaf.sprite = sprite
		leaf.material = mat
		_leaves.append(leaf)

	_spawn_timer = randf_range(SPAWN_INTERVAL.x, SPAWN_INTERVAL.y)


func _process(delta: float) -> void:
	if get_tree().get_first_node_in_group("leaf_emitter") == null:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(SPAWN_INTERVAL.x, SPAWN_INTERVAL.y)
		_spawn_leaf()

	for leaf in _leaves:
		if leaf.active:
			_update_leaf(leaf, delta)


func _spawn_leaf() -> void:
	var leaf := _find_free_leaf()
	if leaf == null:
		return

	var viewport_width := get_viewport().get_visible_rect().size.x

	var sprite := leaf.sprite
	sprite.texture = _frames[randi() % FRAME_COUNT]
	sprite.rotation = randf_range(0.0, TAU)
	sprite.scale = Vector2.ONE * randf_range(SCALE_RANGE.x, SCALE_RANGE.y)

	leaf.color = _random_leaf_color()
	leaf.material.set_shader_parameter("leaf_color", leaf.color)

	leaf.base_x = randf_range(0.0, viewport_width)
	sprite.position = Vector2(leaf.base_x, -EDGE_MARGIN)
	sprite.visible = true

	leaf.active = true
	leaf.fading = false
	leaf.timer = 0.0
	leaf.age = 0.0
	leaf.sway_phase = randf_range(0.0, TAU)
	leaf.sway_amp = randf_range(SWAY_AMPLITUDE_RANGE.x, SWAY_AMPLITUDE_RANGE.y)
	leaf.sway_freq = randf_range(SWAY_FREQUENCY_RANGE.x, SWAY_FREQUENCY_RANGE.y)
	leaf.fall_speed = randf_range(FALL_SPEED_RANGE.x, FALL_SPEED_RANGE.y)
	leaf.spin_speed = randf_range(SPIN_SPEED_RANGE.x, SPIN_SPEED_RANGE.y)


func _find_free_leaf() -> _FgLeaf:
	for leaf in _leaves:
		if not leaf.active:
			return leaf
	return null


func _random_leaf_color() -> Color:
	var variant: Dictionary = HUE_VARIANTS[randi() % HUE_VARIANTS.size()]
	var hue: float = variant["hue"] + randf_range(-HUE_JITTER, HUE_JITTER)
	var sat_range: Vector2 = variant["sat"]
	var val_range: Vector2 = variant["val"]
	return Color.from_hsv(hue, randf_range(sat_range.x, sat_range.y), randf_range(val_range.x, val_range.y))


# 화면을 가로질러 떨어지다가, 화면 밖으로 완전히 나가면 바로 정리하고(이미 안 보이니 페이드가
# 의미 없다), 그 전에 수명이 다하면(정상적으로는 안 일어남) 화면 안에 남아있을 수 있으니
# 뚝 끊기지 않게 페이드로 정리한다
func _update_leaf(leaf: _FgLeaf, delta: float) -> void:
	leaf.age += delta
	var sprite := leaf.sprite

	if leaf.fading:
		leaf.timer += delta
		var alpha := 1.0 - clampf(leaf.timer / FADE_OUT_DURATION, 0.0, 1.0)
		leaf.material.set_shader_parameter("leaf_color", Color(leaf.color.r, leaf.color.g, leaf.color.b, alpha))
		if leaf.timer >= FADE_OUT_DURATION:
			leaf.active = false
			sprite.visible = false
		return

	sprite.position.y += leaf.fall_speed * delta
	sprite.position.x = leaf.base_x + sin(leaf.age * leaf.sway_freq + leaf.sway_phase) * leaf.sway_amp
	sprite.rotation += leaf.spin_speed * delta

	var viewport_height := get_viewport().get_visible_rect().size.y
	if sprite.position.y >= viewport_height + EDGE_MARGIN:
		leaf.active = false
		sprite.visible = false
	elif leaf.age >= MAX_LIFETIME:
		leaf.fading = true
		leaf.timer = 0.0
