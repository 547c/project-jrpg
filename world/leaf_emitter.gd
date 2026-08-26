class_name LeafEmitter
extends Node2D

# 야외 씬에 은은하게 떠도는 낙엽 앰비언트 파티클(배경용 — 화면 공간 전경 낙엽은
# systems/foreground_leaves.gd). 낙하/착지/페이드에 더해 WindSystem 연동(흔들림 폭·스폰 빈도),
# 높낮이를 표현하는 그림자, 스폰 페이드인까지 포함한다.
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
const SPAWN_FADE_IN_DURATION := 0.2 # 생성 직후 뿅 나타나지 않도록 알파 0->1로 서서히

# [WindSystem 연동]
# WIND_SWAY_BOOST: 돌풍(wind_strength=1)일 때 좌우 흔들림 폭을 몇 배까지 키울지.
# WIND_SPAWN_BOOST: 돌풍일 때 스폰 간격을 얼마나 줄일지(더 자주 스폰) — 간격을 (1+wind*BOOST)로
# 나누므로, wind_strength=1이면 간격이 최대 1/(1+BOOST)배로 줄어든다(잎이 그만큼 더 자주 태어남)
const WIND_SWAY_BOOST := 1.4
const WIND_SPAWN_BOOST := 1.5

# [돌풍 버스트]
# 위 WIND_SPAWN_BOOST는 "바람이 센 동안 계속 스폰 간격이 짧아지는" 연속적인 효과라, 돌풍이
# 막 시작되는 그 순간의 "확 터지는" 느낌은 따로 안 난다. 그래서 wind_changed 시그널로
# wind_strength가 GUST_BURST_THRESHOLD를 막 넘어서는 상승 엣지(레벨이 아니라 "그 순간")를
# 감지해 한꺼번에 GUST_BURST_COUNT장을 스폰한다.
#
# [GUST_BURST_COOLDOWN이 필요한 이유]
# WindSystem의 리듬을 실제로 시뮬레이션해보면, 하나의 "큰 돌풍" 안에서도 빠른 주기(FAST_PERIOD
# =5.4초) 성분 때문에 문턱을 짧은 간격(4~6초)으로 두 번 넘나드는 경우가 흔하다 — 쿨다운 없이
# 매번 반응하면 같은 돌풍인데 버스트가 두 번 터진다. GUST_BURST_COOLDOWN(8초)을 넉넉히 둬서
# 같은 돌풍 안의 재진입은 무시하고, 진짜 다음 돌풍(보통 15~25초 뒤)에만 다시 터지게 한다
const GUST_BURST_THRESHOLD := 0.7
const GUST_BURST_COUNT := 10
const GUST_BURST_COOLDOWN := 8.0

# [그림자]
# 착지 직전까지는 잎과 그림자 사이가 멀어져(SHADOW_MAX_GAP) 공중에 떠 있는 높낮이감을 주고,
# 착지 순간 거리 0으로 완전히 겹친다. 그림자는 ShadowLayer(CanvasGroup)로 넘어가 다른 그림자와
# 겹쳐도 밝기가 균일하게 유지된다 — 나무/식생/캐릭터와 같은 공용 레이어를 그대로 재사용한다.
#
# [단순한 점이 아니라 프롭과 같은 실루엣 방식]
# tree_prop.gd/vegetation_prop.gd/rock_prop.gd와 같은 방식(잎 텍스처를 그대로 복제해 검게
# 칠한 뒤 ShadowLayer.lay_on_ground()로 눕힘)을 쓴다. 다만 프롭과 달리 낙엽은 떨어지는 동안
# 계속 회전(spin_speed)하므로, 프롭처럼 한 번만 눕히고 끝나는 게 아니라 매 프레임 "회전 →
# 눕히기" 순서로 다시 계산해야 한다(_apply_shadow_transform). 높이에 따른 간격(SHADOW_MAX_GAP)은
# 이 실루엣 변환과 무관하게 여전히 global_position만으로 표현한다 — 잎이 중심 정렬(centered=true)
# 이라 프롭의 발밑 보정(SORT_BIAS)이 필요 없고, 단순히 위치를 띄우는 것만으로 충분하다.
const SHADOW_MAX_GAP := 12.0


class _Leaf:
	var sprite: Sprite2D
	var shadow: Sprite2D
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
var _was_gusting: bool = false
var _last_burst_time: float = -INF


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

		# 나무/식생/캐릭터와 같은 방식: 일단 이 노드의 자식으로 만든 뒤 공용 ShadowLayer로 넘긴다.
		# 완전 불투명 검정으로 그리고(반투명함은 ShadowLayer의 self_modulate 알파 하나로만 준다),
		# 풀에서 쉬는 동안은 안 보이게 꺼둔다. 텍스처는 스폰될 때마다 그 순간 고른 잎 모양으로 채운다
		var shadow := Sprite2D.new()
		shadow.centered = true
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow.modulate = Color(0, 0, 0, 1)
		shadow.visible = false
		add_child(shadow)
		ShadowLayer.adopt(shadow, self)

		var leaf := _Leaf.new()
		leaf.sprite = sprite
		leaf.shadow = shadow
		_leaves.append(leaf)

	# 나무/캐릭터와 같은 밴드 — 자세한 이유는 SceneManager 상수 주석 + docs/map_objects.md #3
	z_index = SceneManager.CHARACTER_BAND_Z_INDEX
	_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y)
	WindSystem.wind_changed.connect(_on_wind_changed)


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		# 돌풍일 때 간격을 줄여(=더 자주 스폰) 바람이 셀수록 잎이 더 많이 날리게 한다
		var wind_speedup := 1.0 + WindSystem.wind_strength * WIND_SPAWN_BOOST
		_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y) / wind_speedup
		_spawn_leaf()

	for leaf in _leaves:
		if leaf.active:
			_update_leaf(leaf, delta)


# 낙엽의 지금 회전/크기를 반영해 그림자를 바닥에 눕힌 실루엣으로 그린다. fade<1.0이면(FADING
# 중) 그만큼 더 작게 그려 착지 그림자와 같은 방식(알파 대신 크기)으로 사라지게 한다.
# 프롭의 lay_on_ground는 "한 번만 눕히고 끝"이지만, 낙엽은 떨어지는 동안 계속 회전하므로 이
# 함수를 매 프레임 다시 불러 "회전 → 눕히기" 순서를 다시 계산해야 한다(순서가 바뀌면 안 된다 —
# 잎이 공중에서 스스로 도는 것과, 그 결과물을 바닥에 투영하는 건 서로 다른 단계다)
func _apply_shadow_transform(leaf: _Leaf, fade: float = 1.0) -> void:
	var spin := Transform2D(leaf.sprite.rotation, leaf.sprite.scale * fade, 0.0, Vector2.ZERO)
	var combined := ShadowLayer.ground_transform() * spin
	leaf.shadow.transform = Transform2D(combined.x, combined.y, leaf.shadow.transform.origin)


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
	var spawn_scale := randf_range(0.85, 1.15)
	sprite.scale = Vector2.ONE * spawn_scale

	leaf.color = _random_leaf_color()
	sprite.modulate = Color(leaf.color.r, leaf.color.g, leaf.color.b, 0.0) # 스폰 페이드인 시작(알파 0)

	# 화면 위쪽 한 줄이 아니라 지금 보이는 범위 전체에 고르게 스폰한다 — 그래야 한 화면 안에
	# "막 태어난 잎/떨어지는 중인 잎/막 착지한 잎"이 동시에 섞여 있는 자연스러운 앙상블이 된다
	var spawn_global := Vector2(
		randf_range(view_rect.position.x, view_rect.end.x),
		randf_range(view_rect.position.y, view_rect.end.y),
	)
	leaf.base_x = to_local(spawn_global).x
	sprite.position = to_local(spawn_global)
	sprite.visible = true

	leaf.shadow.texture = sprite.texture
	_apply_shadow_transform(leaf)
	leaf.shadow.global_position = sprite.global_position + Vector2(0.0, SHADOW_MAX_GAP)
	leaf.shadow.visible = true

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


# wind_strength가 GUST_BURST_THRESHOLD를 막 넘어서는 상승 엣지에서만 반응한다(레벨이 아니라
# 순간) — 그 위에 계속 머물러 있어도 다시 터지지 않고, GUST_BURST_COOLDOWN이 지나야 재무장된다
func _on_wind_changed(strength: float) -> void:
	var gusting := strength >= GUST_BURST_THRESHOLD
	if gusting and not _was_gusting:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_burst_time >= GUST_BURST_COOLDOWN:
			_last_burst_time = now
			_burst_leaves()
	_was_gusting = gusting


# 돌풍이 시작되는 순간 한꺼번에 여러 장을 후두둑 쏟아낸다. _spawn_leaf()는 풀에 남는 자리가
# 없으면 조용히 건너뛰므로, 이미 화면에 낙엽이 많이 떠 있을 때는 자연히 더 적게(또는 0장) 터진다
func _burst_leaves() -> void:
	for i in range(GUST_BURST_COUNT):
		_spawn_leaf()


# 초록 계열 3종 중 하나를 고르고, 그 계열 범위 안에서만 채도/명도(+아주 살짝 색상)를 흔들어
# "진하고 연하고 다양하지만 절대 이상한 색으로는 안 가는" 변주를 만든다
func _random_leaf_color() -> Color:
	var variant: Dictionary = HUE_VARIANTS[randi() % HUE_VARIANTS.size()]
	var hue: float = variant["hue"] + randf_range(-HUE_JITTER, HUE_JITTER)
	var sat_range: Vector2 = variant["sat"]
	var val_range: Vector2 = variant["val"]
	return Color.from_hsv(hue, randf_range(sat_range.x, sat_range.y), randf_range(val_range.x, val_range.y))


# 상태별로 낙엽 하나를 갱신한다: 떨어지는 중(사인파 흔들림, 스폰 직후엔 페이드인) ->
# 착지(정지, 2초 유지) -> 페이드아웃(free). 착지하지 못하고 max_lifetime을 넘기면 착지를
# 건너뛰고 바로(더 짧게) 페이드아웃한다.
#
# [그림자는 왜 알파가 아니라 크기로 페이드하는가]
# ShadowLayer(CanvasGroup)는 "자식들은 전부 불투명 검정이어야 그룹 alpha 한 번으로 겹침이
# 균일해진다"는 전제 위에 있다(shadow_layer.gd 주석). 개별 그림자에 알파를 넣어 페이드시키면
# 겹친 곳만 다시 진해지는 원래 문제가 돌아온다. 대신 도형 자체를 0까지 줄이면(scale) 여전히
# "칠해지는 곳은 항상 완전 불투명"이라는 전제를 안 깨면서도 시각적으로는 사라지는 것처럼 보인다.
func _update_leaf(leaf: _Leaf, delta: float) -> void:
	leaf.age += delta
	var sprite := leaf.sprite

	match leaf.state:
		_State.FALLING:
			leaf.timer += delta
			var wind_factor := 1.0 + WindSystem.wind_strength * WIND_SWAY_BOOST
			sprite.position.y += leaf.fall_speed * delta
			sprite.position.x = leaf.base_x + sin(leaf.age * leaf.sway_freq + leaf.sway_phase) * leaf.sway_amp * wind_factor
			sprite.rotation += leaf.spin_speed * delta

			var fade_in_alpha := clampf(leaf.age / SPAWN_FADE_IN_DURATION, 0.0, 1.0)
			sprite.modulate = Color(leaf.color.r, leaf.color.g, leaf.color.b, fade_in_alpha)

			# 잎이 계속 도는 동안은 그림자도 매 프레임 같은 회전을 반영해 다시 눕혀야 한다
			_apply_shadow_transform(leaf)
			# 착지에 가까워질수록(progress->1) 그림자와의 간격을 0으로 좁혀 높낮이감을 준다
			var progress := clampf(leaf.timer / leaf.fall_duration, 0.0, 1.0)
			leaf.shadow.global_position = sprite.global_position + Vector2(0.0, lerpf(SHADOW_MAX_GAP, 0.0, progress))

			if leaf.timer >= leaf.fall_duration:
				leaf.state = _State.LANDED
				leaf.timer = 0.0
			elif leaf.age >= max_lifetime:
				_begin_fade(leaf, NATURAL_FADE_DURATION)

		_State.LANDED:
			leaf.timer += delta
			leaf.shadow.global_position = sprite.global_position # 착지 = 그림자와 완전히 겹침
			if leaf.timer >= HOLD_DURATION:
				_begin_fade(leaf, LAND_FADE_DURATION)

		_State.FADING:
			leaf.timer += delta
			var fade := clampf(leaf.timer / leaf.fade_duration, 0.0, 1.0)
			var alpha := 1.0 - fade
			sprite.modulate = Color(leaf.color.r, leaf.color.g, leaf.color.b, alpha)
			leaf.shadow.global_position = sprite.global_position
			_apply_shadow_transform(leaf, alpha) # 그림자는 알파 대신 크기로 페이드 (ShadowLayer 사양, 위 주석 참고)
			if leaf.timer >= leaf.fade_duration:
				leaf.active = false
				sprite.visible = false
				leaf.shadow.visible = false


func _begin_fade(leaf: _Leaf, duration: float) -> void:
	leaf.state = _State.FADING
	leaf.timer = 0.0
	leaf.fade_duration = duration
