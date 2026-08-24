class_name CharacterShadow
extends Polygon2D

# 플레이어/NPC의 발밑 그림자. 나무·바위처럼 실루엣을 복제하지 않고 납작한 타원 하나로 그린다 —
# 전투 화면(battle_scene.gd의 _setup_shadow)에서 쓰던 것과 같은 방식이고, 오버월드에서도 같은
# 이유로 실루엣보다 낫다: 캐릭터는 매 프레임 팔다리 모양이 바뀌는데 그 실루엣을 그대로 바닥에
# 깔면 그림자가 같이 펄럭여 시선을 끈다. 반면 나무/바위는 모양이 고정이라 실루엣이 자연스럽다.
#
# [왜 캐릭터의 자식이 아니라 ShadowLayer의 자식인가]
# 그림자끼리 겹쳐도 진해지지 않으려면 모든 그림자가 한 CanvasGroup 안에 있어야 한다
# (이유는 shadow_layer.gd 주석). 그래서 이 노드는 캐릭터와 부모-자식 관계가 아니고,
# 대신 매 프레임 대상의 global_position을 따라간다.
#
# [발 위치/폭은 시트를 실제로 재서 정한다]
# 캐릭터마다 프레임 캔버스(32/64px)와 그 안의 여백이 제각각이라, "프레임 아래쪽"을 발로 치면
# 그림자가 발에서 한참 떨어져 뜬다(battle_scene.gd의 PLAYER_FOOT_FROM_CENTER가 같은 이유로
# 손으로 잰 값이다). 여기서는 그 측정을 idle 첫 프레임의 불투명 픽셀 범위에서 자동으로 한다.

const SEGMENTS := 20 # 타원 폴리곤의 꼭짓점 수 (battle_scene.gd와 동일)
const FLATNESS := 0.3 # 세로/가로 반지름 비 (battle_scene.gd와 동일)
# 캐릭터 실제 폭 대비 타원 가로 "반지름" (battle_scene.gd와 동일). 반지름이라 타원의 지름은
# 캐릭터 폭보다 넓어진다 — 처음에 이걸 지름으로 착각해 절반 크기로 만들었더니 발에 완전히
# 가려 아무것도 안 보였다
const WIDTH_RATIO := 0.62
const ALPHA_THRESHOLD := 0.04 # 이 값 이하는 투명 여백으로 본다 (battle_scene.gd의 측정과 동일 기준)

var _target: Node2D
var _foot: Vector2 # 대상 원점 기준 발밑 위치(그림자 중심). 광원 방향만큼 이미 옆으로 밀어둔 값


# 캐릭터의 그림자를 만들어 현재 씬의 ShadowLayer에 붙인다.
# 그림자 레이어가 없는 씬(동굴/숲 등)에서는 아무것도 만들지 않고 null을 반환한다.
# sprite에 sprite_frames가 아직 없으면 잴 것이 없으므로 마찬가지로 null — 서브클래스가 _ready()
# 안에서 프레임을 나중에 채우는 NPC들 때문에, 호출은 항상 한 프레임 미뤄서 하는 게 안전하다
static func attach(character: Node2D, sprite: AnimatedSprite2D) -> CharacterShadow:
	var layer := ShadowLayer.find_layer(character)
	if layer == null:
		return null

	var art := _measure_art(sprite)
	if art.size.x <= 0.0:
		return null

	var shadow := CharacterShadow.new()
	shadow.name = "%sShadow" % character.name
	# 불투명 검정으로 그리고, 반투명함은 ShadowLayer가 그룹 전체에 한 번만 입힌다
	shadow.color = Color(0, 0, 0, 1)
	var rx := art.size.x * WIDTH_RATIO
	shadow.polygon = _ellipse(rx, rx * FLATNESS)
	# 발밑에 두되, 나무/바위 그림자가 눕는 것과 같은 광원 방향으로 몸통 절반 높이만큼 옆으로 민다
	shadow._foot = Vector2(art.get_center().x + ShadowLayer.ground_shift(art.size.y * 0.5), art.end.y)
	shadow._target = character
	layer.add_child(shadow)
	shadow._follow_target()
	return shadow


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	_follow_target()


func _follow_target() -> void:
	global_position = _target.global_position + _foot
	# 플레이어는 전투로 넘어가는 동안 잠시 숨겨진다 — 그림자만 남아 있지 않도록 함께 따라간다
	visible = _target.visible


# 반지름 rx/ry의 타원 폴리곤
static func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(SEGMENTS):
		var angle := TAU * i / float(SEGMENTS)
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


# idle 첫 프레임에서 실제 그림이 차지하는 범위를 캐릭터 노드 기준 좌표로 돌려준다
# (프레임 안의 투명 여백을 걷어낸, 캐릭터의 진짜 폭과 발 높이)
static func _measure_art(sprite: AnimatedSprite2D) -> Rect2:
	var frames := sprite.sprite_frames
	if frames == null:
		return Rect2()

	var anim := "idle"
	if not frames.has_animation(anim):
		var names := frames.get_animation_names()
		if names.is_empty():
			return Rect2()
		anim = names[0]
	if frames.get_frame_count(anim) == 0:
		return Rect2()

	var texture := frames.get_frame_texture(anim, 0)
	if texture == null:
		return Rect2()

	# 프레임은 대개 시트에서 잘라낸 AtlasTexture다 — 시트 전체 이미지에서 그 구역만 훑어야 한다
	var image: Image
	var region: Rect2i
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		if atlas.atlas == null:
			return Rect2()
		image = atlas.atlas.get_image()
		region = Rect2i(atlas.region)
	else:
		image = texture.get_image()
		region = Rect2i(Vector2i.ZERO, image.get_size())
	if image == null:
		return Rect2()

	var opaque := _opaque_bounds(image, region)
	if opaque.size.x <= 0:
		return Rect2()

	# 프레임 좌표 -> 캐릭터 노드 좌표 (스프라이트의 centered/offset/scale을 되짚는다)
	var frame_origin := sprite.offset
	if sprite.centered:
		frame_origin -= Vector2(region.size) * 0.5
	var top_left := (frame_origin + Vector2(opaque.position)) * sprite.scale + sprite.position
	return Rect2(top_left, Vector2(opaque.size) * sprite.scale)


# image의 region 구역 안에서 불투명 픽셀이 차지하는 사각형 (region 좌상단 기준)
static func _opaque_bounds(image: Image, region: Rect2i) -> Rect2i:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var min_x := clipped.end.x
	var min_y := clipped.end.y
	var max_x := clipped.position.x - 1
	var max_y := clipped.position.y - 1
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x - region.position.x, min_y - region.position.y, max_x - min_x + 1, max_y - min_y + 1)
