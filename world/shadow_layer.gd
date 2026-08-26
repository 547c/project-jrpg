class_name ShadowLayer
extends CanvasGroup

# 맵 위 모든 그림자(나무/식생/바위의 실루엣 + 플레이어/NPC의 타원)가 모이는 공용 렌더 그룹.
# 씬마다 하나씩 두고, 그림자를 갖는 쪽이 adopt()로 자기 그림자를 맡긴다("shadow_layer" 그룹으로 찾는다).
#
# [왜 CanvasGroup인가]
# 반투명 검정 실루엣을 여러 장 겹쳐 그리면, 일반적인 알파 블렌딩은 겹친 부분만 알파가 곱해져
# 유독 진하게 뭉친다(0.28 두 장이 겹치면 1-(1-0.28)^2 ≈ 0.48 — 실측: 흰 배경 대비 밝기 0.72 ->
# 겹친 곳만 0.52). CanvasGroup은 자식들을 먼저 하나의 오프스크린 버퍼에 합성한 뒤, 그 버퍼 전체에
# 그룹 자신의 modulate 알파를 딱 한 번만 입힌다 — 자식들끼리 아무리 겹쳐도(불투명 검정끼리는
# 무엇과 겹쳐도 여전히 불투명 검정이므로) 최종 밝기가 균일하다. 실측으로 두 방식을 나란히
# 그려 겹침 지점 밝기가 그룹 방식만 한 겹일 때와 동일함을 확인한 뒤 이 설계를 골랐다.
# 그래서 이 그룹에 들어오는 그림자는 전부 완전 불투명(alpha=1) 검정으로 그리고,
# 실제로 보이는 반투명함은 아래 SHADOW_ALPHA 하나로만 준다.
#
# CanvasGroup 안에서도 자식의 CanvasItem 셰이더(흔들림 등)와 텍스처 알파(투명 배경)는 그룹
# 바깥과 똑같이 정상 동작한다는 것도 별도로 확인했다 — 그룹이 "셰이더를 무시하고 실루엣만
# 뭉뚱그려 칠하는" 방식이 아니라, 평소처럼 그린 결과를 합성만 다르게 하는 것이기 때문이다.

const GROUP := "shadow_layer"

const SHADOW_ALPHA := 0.28

# [광원 방향 — 맵 전체가 공유하는 단 하나의 값]
# 에셋(Rocks.png/Trees/Vegetation)이 전부 오른쪽 면을 어둡게 칠해둔, 즉 왼쪽 위에서 빛이 오는
# 그림이다. 그래서 바닥에 드리우는 그림자도 전부 오른쪽 아래로(= 보는 사람 쪽으로) 눕는다.
# 이 두 값은 절대 오브젝트별로 다르게 주지 말 것 — 하나라도 어긋나면 "빛이 두 군데서 온다"로 보인다.
#
# 둘 다 "각도"가 아니라 높이에 대한 비율이다. 밑동에서 h만큼 높은 지점은 바닥의
#   (오른쪽으로 h * GROUND_LEAN, 아래쪽으로 h * GROUND_SQUASH) 자리로 떨어진다.
# GROUND_SQUASH가 곧 그림자 길이다 — 값이 클수록 해가 낮게 뜬 것처럼 그림자가 길어진다.
# (계산이 아니라 마을을 실제로 렌더링해 여러 값을 나란히 비교해 고른 값 — docs/map_objects.md 참고)
const GROUND_LEAN := 0.40
const GROUND_SQUASH := 0.45

# 그림자를 맡길 레이어를 못 찾았을 때 다시 찾아보는 프레임 수(약 1초).
# 씬 파일에서 ShadowLayer가 그림자 주인보다 늦게 선언돼 있으면 _ready() 시점엔 아직 그룹에
# 등록돼 있지 않을 수 있다 — 그때를 위한 대비다
const ADOPT_RETRY_FRAMES := 60


func _ready() -> void:
	add_to_group(GROUP)
	self_modulate = Color(1, 1, 1, SHADOW_ALPHA)
	# y좌표와 무관하게 항상 캐릭터/나무보다 아래, 데코 타일보다는 위 — 자세한 이유는
	# SceneManager.SHADOW_LAYER_Z_INDEX 주석 참고
	z_index = SceneManager.SHADOW_LAYER_Z_INDEX


# 그림자 노드를 이 레이어의 자식으로 넘겨받는다. 화면상 위치가 전혀 바뀌지 않도록,
# 옮기기 전 global_position을 읽어두고 옮긴 뒤 그대로 되돌린다
# (SceneManager가 플레이어를 씬 사이로 옮길 때 쓰는 것과 같은 패턴).
# 레이어가 아직 없으면 몇 프레임 기다렸다가 다시 찾는다 — 호출부는 기다릴 필요 없이 그냥 부르면 된다
static func adopt(shadow: Node2D, requester: Node) -> void:
	if not is_instance_valid(shadow) or not is_instance_valid(requester):
		return
	if shadow.get_parent() is ShadowLayer:
		return

	var layer := find_layer(requester)
	var waited := 0
	while layer == null and waited < ADOPT_RETRY_FRAMES:
		var tree := requester.get_tree()
		if tree == null:
			return
		await tree.process_frame
		if not is_instance_valid(shadow) or not is_instance_valid(requester):
			return
		layer = find_layer(requester)
		waited += 1

	if layer == null:
		push_warning("ShadowLayer: '%s'의 그림자를 맡길 레이어가 없어 제자리에 남겨둠(겹치면 진해질 수 있음)" % requester.name)
		return

	var world_position := shadow.global_position
	if shadow.get_parent() != null:
		shadow.get_parent().remove_child(shadow)
	layer.add_child(shadow)
	shadow.global_position = world_position


# 현재 씬의 그림자 레이어 (그림자를 쓰지 않는 씬에서는 null)
static func find_layer(requester: Node) -> ShadowLayer:
	var tree := requester.get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as ShadowLayer


# 그림 공간을 바닥 평면으로 옮기는 변환(밑동이 원점일 때). 열 벡터로 읽으면 뜻이 그대로 보인다:
# x축은 그대로 두고, y축은 부호를 뒤집으면서(그림에서 "위"였던 것이 바닥에서는 "앞", 즉 화면
# 아래쪽이 된다) 납작하게 눌리고 오른쪽으로 밀린다.
#
# 위로 세운 채 납작하게만 만들면(= y축을 뒤집지 않으면) 그림자가 화면 위쪽, 즉 나무 뒤로 뻗어
# 나무 그림에 거의 다 가려진다 — 실제로 그렇게 만들어 렌더링해보고 알아낸 함정이다.
# 왼쪽 위에서 빛이 오면 그림자는 보는 사람 쪽(화면 아래)으로 와야 한다
static func ground_transform() -> Transform2D:
	return Transform2D(Vector2(1.0, 0.0), Vector2(-GROUND_LEAN, -GROUND_SQUASH), Vector2.ZERO)


# 실루엣 그림자를 "바닥에 눕힌다". 스프라이트를 그대로 복제만 하면 옆에 세워둔 판때기처럼 보이므로,
# 위 변환으로 눌러 눕혀서 바닥에 드리운 것처럼 만든다.
#
# [발밑을 축으로 눕혀야 한다]
# Node2D의 변환은 노드 원점을 축으로 도는데, 그림자의 원점은 발밑이 아니라(정렬 기준점 때문에)
# 발밑보다 foot_y만큼 위에 있다. 그대로 눕히면 그림자 밑동이 발에서 떨어져 붕 뜬다.
# 그렇다고 원점 자체를 발밑으로 옮기면 이번엔 흔들림 셰이더가 어긋난다 — 위상을 MODEL_MATRIX의
# 위치에서 뽑기 때문에, 스프라이트와 원점이 달라지는 순간 둘이 다른 박자로 흔들린다.
# 그래서 원점은 그대로 두고 offset만 보정해서, 결과적으로 발밑 F를 축으로 눕힌 것과 같게 만든다:
#   원하는 결과 q = F + M*(p - F) 이고 노드가 실제로 그리는 건 q = M*(offset + 픽셀) 이므로
#   offset = art_offset - F + M⁻¹*F 로 두면 두 식이 정확히 같아진다.
#
# [extra_scale / Node2D 매개변수 타입]
# 프롭은 전부 scale=1이라 그동안은 이 문제가 없었는데, 플레이어 그림자(player_shadow.gd)처럼
# 스프라이트 자체에 배율(1.45배 등)이 걸려 있으면 얘기가 다르다 — 아래에서 transform을 통째로
# 덮어쓰므로, 미리 shadow.scale을 걸어놔도 이 대입 한 줄에 지워진다. 그래서 배율을 아예 이
# 함수의 인자로 받아 눕히는 행렬 자체에 곱해 넣는다(균등 배율 한정 — x/y 배율이 다르면 대각선이
# 아닌 성분까지 어긋나 이 한 줄짜리 곱셈으로는 안 맞는다). Sprite2D.offset은 AnimatedSprite2D에도
# 똑같이 있지만 두 타입이 공통 부모를 안 쓰는 남남이라, 정적 타입을 Node2D로 넓히고 set()으로
# 덕타이핑한다(둘 다 실제로 offset 프로퍼티가 있어 런타임에는 아무 차이가 없다)
static func lay_on_ground(shadow: Node2D, art_offset: Vector2, foot_y: float, extra_scale: float = 1.0) -> void:
	var flatten := ground_transform()
	var basis_x := flatten.x * extra_scale
	var basis_y := flatten.y * extra_scale
	# 이미 ShadowLayer로 옮겨졌을 수도 있으므로 위치(origin)는 건드리지 않고 회전/기울임만 바꾼다
	shadow.transform = Transform2D(basis_x, basis_y, shadow.transform.origin)
	var foot := Vector2(0.0, foot_y)
	var basis_only := Transform2D(basis_x, basis_y, Vector2.ZERO)
	shadow.set("offset", art_offset - foot + basis_only.affine_inverse() * foot)


# 높이 height인 지점이 같은 광원 아래에서 바닥의 어디로 밀리는지(가로 거리).
# 실루엣이 아니라 타원 하나로 그리는 캐릭터 그림자(character_shadow.gd)가 중심을 옮길 때 쓴다
static func ground_shift(height: float) -> float:
	return height * GROUND_LEAN
