class_name LeafEmitter
extends Node2D

# 야외 씬에 은은하게 떠도는 낙엽 앰비언트 파티클. 이번 라운드는 기본 낙하/착지/페이드만 —
# 카메라 앞 확대/블러 전경 레이어(다음 라운드 예정)는 여기 포함하지 않는다.
#
# [스폰 범위 = 고정 지점이 아니라 "현재 화면"]
# 씬마다 나무 근처 등 손으로 여러 지점에 심어두는 대신, 매번 스폰할 때 Viewport.get_camera_2d()로
# 지금 화면에 실제로 보이는 범위(+여유분)를 구해서 그 안에서 스폰한다 — 그래야 씬에 인스턴스를
# 하나만 둬도 플레이어가 어디로 가든(숲이든 광장이든 다리 건너든) 화면에 낙엽이 보인다.
# 이 노드 자체는 움직이지 않는다 — 스폰 시점에만 카메라 위치/줌을 읽어 "어디서 태어날지"만
# 정하고, 태어난 뒤에는(부모가 안 움직이니) 평범한 로컬 좌표로 그냥 떨어진다. 만약 이 노드
# 자체를 카메라처럼 매 프레임 움직이면, 이미 떨어지고 있던 낙엽들까지 그 이동에 딸려가 버린다
# (부모-자식 변환이라 자식 로컬 좌표는 그대로여도 화면상 위치가 부모를 따라 밀려버림) — 그래서
# "따라다니는 건 스폰 위치 계산뿐, 노드 자신은 고정"이라는 구조를 골랐다.
# 카메라 줌은 평상시/달리기 때가 달라서(player.gd의 BASE_ZOOM/RUN_ZOOM), 스폰마다 그 시점의
# 실제 zoom을 다시 읽어 화면에 보이는 실제 월드 범위를 그때그때 다시 계산한다.
#
# [나무/식생 프롭처럼 "인스턴스마다 스크립트 노드 하나"가 아닌 이유]
# 나무는 맵에 고정 배치된 개별 오브젝트라 각자 Y-Sort/충돌/그림자를 따로 가져야 하지만, 낙엽은
# 계속 스폰되고 사라지는 동질적인 다수다. 하나마다 Node2D+스크립트를 새로 만들고 지우면(계속
# 스폰될 걸 감안하면) 인스턴스화/free 비용과 _process 콜백 수만 쓸데없이 늘어난다. 대신 이
# 노드 하나가 Sprite2D 풀을 들고 배열 하나를 매 프레임 훑는 쪽이 훨씬 가볍고, "오브젝트 풀링"도
# 그 풀을 재사용하는 것만으로 자연히 딸려온다(요청하신 성능 대응이 곧 이 구조 자체다).
#
# [바닥 판정을 실제 타일 조사 없이 시간 기반으로 단순화한 이유]
# 예전에 마을 땅/물 타일을 픽셀 색으로 분류했던 작업(village.tscn 나무/바위 배치 때)은 그때그때
# 쓰고 버린 파이썬 분석 스크립트였을 뿐 게임 코드로 남지 않았다. 설령 GDScript로 옮기더라도
# Water_tiles.png의 정확한 아틀라스 좌표에 결박된 로직이라 마을 바깥(숲/사막 등)에서는 못 쓴다.
# 낙엽은 어느 야외 씬에서나 켜질 범용 앰비언트 효과라 씬별 타일 지식이 없는 편이 맞고, 요청하신
# "너무 복잡한 물리 시뮬레이션 말고"와도 맞아떨어진다 — 그래서 "무작위 시간만큼 떨어지면 땅에
# 닿은 것으로 친다"는 시간 기반 시뮬레이션으로 충분하다.
#
# [원본 스프라이트가 흰색/회색조인 이유]
# assets/vfx/ELR_LeafSheet.aseprite를 뜯어보면 실제로 쓰인 팔레트 색은 흰색·밝은 회색·중간
# 회색뿐이다(팔레트 전체에는 주황/초록 등 다른 색도 있지만 그건 에셋팩의 범용 팔레트고, 이 잎
# 그림 자체는 그중 어느 것도 안 쓴다) — 즉 이 시트는 애초에 modulate로 색을 입히라고 무채색으로
# 그려둔 "틀"이다. 그래서 색상 요구사항(진녹/연녹/황록 랜덤)을 시트를 바꾸지 않고 modulate만으로
# 그대로 구현할 수 있다.

enum _State { FALLING, LANDED, FADING }

const LEAF_SHEET: Texture2D = preload("res://assets/vfx/ELR_LeafSheet.png")
const FRAME_SIZE := 16
const FRAME_COUNT := 5

# 색조 3종(진녹색/연녹색/황록색)을 기준 삼아 그 안에서만 채도·명도를 흔든다 — "너무 이상한 색으로는
# 안 가게"가 핵심이라, 색상(hue) 자체는 초록 대역(0.24~0.34)을 크게 벗어나지 않는다
const HUE_VARIANTS: Array[Dictionary] = [
	{"hue": 0.34, "sat": Vector2(0.55, 0.75), "val": Vector2(0.28, 0.42)}, # 진녹색
	{"hue": 0.31, "sat": Vector2(0.30, 0.48), "val": Vector2(0.68, 0.88)}, # 연녹색
	{"hue": 0.24, "sat": Vector2(0.45, 0.65), "val": Vector2(0.55, 0.75)}, # 황록색
]
const HUE_JITTER := 0.015 # 같은 계열 안에서도 완전히 똑같은 색만 나오지 않게 하는 미세한 흔들림

@export var camera_margin := 100.0 # 화면 가장자리 바깥으로 이만큼(월드 px)까지도 스폰 대상 — 가장자리에서 갑자기 팝인하지 않게
@export var pool_size := 80
@export var spawn_interval := Vector2(0.09, 0.22) # 초 단위 스폰 간격(최소/최대) — 화면 전체를 커버하려 기존보다 훨씬 잦게 스폰
@export var fall_speed_range := Vector2(18.0, 30.0) # px/s
@export var fall_duration_range := Vector2(1.6, 3.0) # 초 — 다 지나면 "땅에 닿았다"고 본다(바닥 높이가 제각각인 것처럼 보이게 개체마다 다르게)
@export var sway_amplitude_range := Vector2(6.0, 14.0)
@export var sway_frequency_range := Vector2(1.2, 2.2)
@export var max_lifetime := 6.0 # 이 시간 안에 착지하지 못한 경우(정상적으로는 안 일어남)에 대비한 안전장치

const HOLD_DURATION := 2.0
const LAND_FADE_DURATION := 1.0
const NATURAL_FADE_DURATION := 0.5


class _Leaf:
	var sprite: Sprite2D
	var active: bool = false
	var state: int = _State.FALLING
	var timer: float = 0.0 # 현재 state 안에서 흐른 시간
	var age: float = 0.0 # 스폰된 뒤 전체 경과 시간 (흔들림 위상 계산용)
	var base_x: float = 0.0
	var color: Color = Color.WHITE
	var sway_phase: float = 0.0
	var sway_amp: float = 0.0
	var sway_freq: float = 0.0
	var fall_speed: float = 0.0
	var fall_duration: float = 0.0
	var spin_speed: float = 0.0
	var fade_duration: float = LAND_FADE_DURATION


var _leaves: Array[_Leaf] = []
var _frames: Array[AtlasTexture] = []
var _spawn_timer: float = 0.0


func _ready() -> void:
	# systems/foreground_leaves.gd가 "지금 이 씬에 배경 낙엽이 있는가"를 판단하는 데 쓴다 —
	# 전투/동굴/실내처럼 이 노드가 없는 씬에서는 전경 잎도 조용히 스폰을 쉰다
	add_to_group("leaf_emitter")

	for i in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = LEAF_SHEET
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_frames.append(atlas)

	for i in range(pool_size):
		var sprite := Sprite2D.new()
		sprite.centered = true
		sprite.visible = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		var leaf := _Leaf.new()
		leaf.sprite = sprite
		_leaves.append(leaf)

	# 나무/캐릭터와 같은 밴드 — 자세한 이유는 SceneManager 상수 주석 + docs/map_objects.md #3
	z_index = SceneManager.CHARACTER_BAND_Z_INDEX
	_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y)


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y)
		_spawn_leaf()

	for leaf in _leaves:
		if leaf.active:
			_update_leaf(leaf, delta)


# 지금 화면에 실제로 보이는 월드 범위(+camera_margin)를 구한다. 활성 카메라가 아직 없으면
# (씬 전환 직후 등) 빈 Rect2를 돌려주고, 호출부가 그 스폰을 건너뛴다.
#
# get_screen_center_position()을 쓰는 이유: Camera2D.global_position은 position_smoothing이
# 켜져 있어도 매 프레임 즉시 플레이어를 따라가는 "실제 노드 위치"라, 화면에 보이는 중심과는
# 몇 프레임 어긋난다(카메라 지연 연출 자체가 그 어긋남이다) — 실제로 렌더링되는 화면 중심은
# 이 함수가 정확하다.
func _get_camera_view_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2()
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var zoom: float = maxf(camera.zoom.x, 0.01) # 0 나눗셈 방지용 최소값(정상 동작 중엔 절대 이 값까지 안 내려감)
	var half_size := viewport_size / zoom / 2.0 + Vector2(camera_margin, camera_margin)
	var center := camera.get_screen_center_position()
	return Rect2(center - half_size, half_size * 2.0)


# 풀에서 쉬고 있는 낙엽 하나를 골라, 지금 화면에 보이는 범위 안 무작위 지점에서 새로 떨어뜨리기
# 시작한다. 풀이 꽉 찼거나 카메라를 아직 못 찾았으면 이번 스폰은 조용히 건너뛴다
# (다음 타이머 때 다시 시도 — 스폰 실패로 에러를 낼 이유가 없다)
func _spawn_leaf() -> void:
	var view_rect := _get_camera_view_rect()
	if view_rect.size == Vector2.ZERO:
		return

	var leaf := _find_free_leaf()
	if leaf == null:
		return

	var sprite := leaf.sprite
	sprite.texture = _frames[randi() % FRAME_COUNT]
	sprite.rotation = randf_range(0.0, TAU)
	sprite.scale = Vector2.ONE * randf_range(0.85, 1.15)

	leaf.color = _random_leaf_color()
	sprite.modulate = leaf.color

	# 화면 위쪽 한 줄이 아니라 지금 보이는 범위 전체에 고르게 스폰한다 — 그래야 한 화면 안에
	# "막 태어난 잎/떨어지는 중인 잎/막 착지한 잎"이 동시에 섞여 있는 자연스러운 앙상블이 된다
	var spawn_global := Vector2(
		randf_range(view_rect.position.x, view_rect.end.x),
		randf_range(view_rect.position.y, view_rect.end.y),
	)
	leaf.base_x = to_local(spawn_global).x
	sprite.position = to_local(spawn_global)
	sprite.visible = true

	leaf.active = true
	leaf.state = _State.FALLING
	leaf.timer = 0.0
	leaf.age = 0.0
	leaf.sway_phase = randf_range(0.0, TAU)
	leaf.sway_amp = randf_range(sway_amplitude_range.x, sway_amplitude_range.y)
	leaf.sway_freq = randf_range(sway_frequency_range.x, sway_frequency_range.y)
	leaf.fall_speed = randf_range(fall_speed_range.x, fall_speed_range.y)
	leaf.fall_duration = randf_range(fall_duration_range.x, fall_duration_range.y)
	leaf.spin_speed = randf_range(-0.6, 0.6)


func _find_free_leaf() -> _Leaf:
	for leaf in _leaves:
		if not leaf.active:
			return leaf
	return null


# 초록 계열 3종 중 하나를 고르고, 그 계열 범위 안에서만 채도/명도(+아주 살짝 색상)를 흔들어
# "진하고 연하고 다양하지만 절대 이상한 색으로는 안 가는" 변주를 만든다
func _random_leaf_color() -> Color:
	var variant: Dictionary = HUE_VARIANTS[randi() % HUE_VARIANTS.size()]
	var hue: float = variant["hue"] + randf_range(-HUE_JITTER, HUE_JITTER)
	var sat_range: Vector2 = variant["sat"]
	var val_range: Vector2 = variant["val"]
	return Color.from_hsv(hue, randf_range(sat_range.x, sat_range.y), randf_range(val_range.x, val_range.y))


# 상태별로 낙엽 하나를 갱신한다: 떨어지는 중(사인파 흔들림) -> 착지(정지, 2초 유지) -> 페이드아웃(free).
# 착지하지 못하고 max_lifetime을 넘기면 착지를 건너뛰고 바로(더 짧게) 페이드아웃한다
func _update_leaf(leaf: _Leaf, delta: float) -> void:
	leaf.age += delta
	var sprite := leaf.sprite

	match leaf.state:
		_State.FALLING:
			leaf.timer += delta
			sprite.position.y += leaf.fall_speed * delta
			sprite.position.x = leaf.base_x + sin(leaf.age * leaf.sway_freq + leaf.sway_phase) * leaf.sway_amp
			sprite.rotation += leaf.spin_speed * delta

			if leaf.timer >= leaf.fall_duration:
				leaf.state = _State.LANDED
				leaf.timer = 0.0
			elif leaf.age >= max_lifetime:
				_begin_fade(leaf, NATURAL_FADE_DURATION)

		_State.LANDED:
			leaf.timer += delta
			if leaf.timer >= HOLD_DURATION:
				_begin_fade(leaf, LAND_FADE_DURATION)

		_State.FADING:
			leaf.timer += delta
			var alpha := 1.0 - clampf(leaf.timer / leaf.fade_duration, 0.0, 1.0)
			sprite.modulate = Color(leaf.color.r, leaf.color.g, leaf.color.b, alpha)
			if leaf.timer >= leaf.fade_duration:
				leaf.active = false
				sprite.visible = false


func _begin_fade(leaf: _Leaf, duration: float) -> void:
	leaf.state = _State.FADING
	leaf.timer = 0.0
	leaf.fade_duration = duration
