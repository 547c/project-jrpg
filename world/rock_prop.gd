@tool
class_name RockProp
extends StaticBody2D

# 마을의 바위 하나. 나무(tree_prop.gd)/식생(vegetation_prop.gd)과 같은 규칙을 따르는 세 번째
# 사례이므로, 구조의 "왜"는 docs/map_objects.md에 있고 여기서는 바위만의 차이만 적는다.
#
# [나무/식생과 다른 점]
# 1. 흔들리지 않는다 — foliage_sway.gdshader를 붙이지 않는다. 바위가 살랑이면 곤란하다.
# 2. 충돌이 밑동이 아니라 "바닥 발자국"이다. 나무는 줄기만 가늘게 막으면 되지만(잎 아래로는
#    지나다닐 수 있어야 한다), 바위는 덩어리 전체가 땅에 놓여 있어 아랫부분을 통째로 막는다.
#    그래도 타일이던 시절처럼 그림 전체(32x48)를 막지는 않는다 — 위쪽은 뒤로 지나갈 수 있어야
#    Y-Sort가 의미를 갖는다.
# 3. 정렬 기준점을 크기에 따라 다르게 준다 (아래 SORT_BIAS 주석 참고).

# [정렬 기준점 = "발밑"] (docs/map_objects.md #1)
# 큰 바위/중간 바위는 "돌아서 지나가는 물체"라 나무와 같은 20을 쓴다(캐릭터 원점이 발보다
# 약 23px 위에 있는 것을 상쇄하는 값 — 그래야 바위 밑동에 선 캐릭터가 바위 앞에 그려진다).
# 작은 돌은 반대로 "밟고 지나가는 바닥 장식"이라, 식생의 잔풀과 같은 8을 써서 그 위에 선
# 캐릭터를 오히려 살짝 덮게 둔다 — 돌 사이에 서 있는 것처럼 보인다
const SORT_BIAS := 20.0
const PEBBLE_SORT_BIAS := 8.0

# 바닥 발자국 충돌 크기 (그림 크기에 대한 비율). 실제로 재보면 바위 그림은 좌우 여백이
# 2~3px뿐이라 폭은 거의 그림 전체이고, 깊이는 3/4 시점에서 아래쪽 1/3 정도가 땅에 닿아 보인다
const BASE_WIDTH_RATIO := 0.8
const BASE_DEPTH_RATIO := 0.33

const SHEET := "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png"

# 실제 마을에 찍혀 있던 바위 타일에서 그대로 뽑아낸 표.
# blocks=true 는 돌아가야 하는 바위(바닥 충돌 있음), false 는 밟고 지나가는 작은 돌(충돌 없음)
const VARIANTS: Dictionary = {
	"boulder_6_1": {"region": Rect2(96, 16, 32, 48), "blocks": true},
	"rock_8_1": {"region": Rect2(128, 16, 32, 32), "blocks": true},
	"stone_9_3": {"region": Rect2(144, 48, 16, 16), "blocks": false},
	"stone_10_6": {"region": Rect2(160, 96, 16, 16), "blocks": false},
	"stone_11_1": {"region": Rect2(176, 16, 16, 16), "blocks": false},
	"stone_11_4": {"region": Rect2(176, 64, 16, 16), "blocks": false},
}

## 어느 변종으로 그릴지 (VARIANTS의 키)
@export var variant: String = "":
	set(value):
		variant = value
		if is_node_ready():
			_build()

var _shadow: Sprite2D
var _sprite: Sprite2D
var _collision: CollisionShape2D


func _ready() -> void:
	# @tool이라 에디터에서도 _ready()가 실행된다. SceneManager는 오토로드라 에디터에는 없으므로
	# (게임이 실제로 돌아갈 때만 트리에 붙는다), 에디터에서는 이 줄을 건드리면 안 된다
	if not Engine.is_editor_hint():
		add_to_group("rock_prop")
		# 플레이어/NPC/나무와 같은 밴드에 서야 서로 Y 좌표로 앞뒤가 갈린다
		# (docs/map_objects.md #3, SceneManager의 상수 주석)
		z_index = SceneManager.CHARACTER_BAND_Z_INDEX
	_build()


# 변종 표를 보고 스프라이트/그림자를 구성하고, 큰 바위면 바닥 충돌까지 만든다.
# 에디터에서는 스프라이트만 그리고 그림자/충돌은 건너뛴다 (이유는 tree_prop.gd 참고)
func _build() -> void:
	if not VARIANTS.has(variant):
		push_warning("RockProp: 알 수 없는 variant '%s'" % variant)
		return

	var spec: Dictionary = VARIANTS[variant]
	var region: Rect2 = spec["region"]
	var blocks := bool(spec["blocks"])
	var sort_bias: float = SORT_BIAS if blocks else PEBBLE_SORT_BIAS
	var art_offset := Vector2(-region.size.x / 2.0, sort_bias - region.size.y)

	var atlas := AtlasTexture.new()
	atlas.atlas = load(SHEET) as Texture2D
	atlas.region = region

	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.centered = false
		add_child(_sprite)

	_sprite.texture = atlas
	# 그림의 아래 끝이 정렬 기준점보다 sort_bias만큼 아래(= 실제 바닥)에 오도록 배치
	_sprite.offset = art_offset

	if Engine.is_editor_hint():
		return

	# 일단 이 노드의 자식으로 만든 뒤 공용 ShadowLayer로 넘긴다 (tree_prop.gd와 동일)
	if _shadow == null:
		_shadow = Sprite2D.new()
		_shadow.name = "Shadow"
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_shadow.centered = false
		_shadow.modulate = Color(0, 0, 0, 1)
		add_child(_shadow)
		ShadowLayer.adopt(_shadow, self)

	_shadow.texture = atlas
	ShadowLayer.lay_on_ground(_shadow, art_offset, sort_bias)

	_build_collision(region, blocks)


# 큰 바위면 바닥에 닿는 부분만 막고, 작은 돌이면 충돌 노드를 아예 두지 않는다
func _build_collision(region: Rect2, blocks: bool) -> void:
	if not blocks:
		if _collision != null:
			_collision.queue_free()
			_collision = null
		return

	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.name = "CollisionShape2D"
		add_child(_collision)

	var depth := region.size.y * BASE_DEPTH_RATIO
	var shape := RectangleShape2D.new()
	shape.size = Vector2(region.size.x * BASE_WIDTH_RATIO, depth)
	_collision.shape = shape
	_collision.position = Vector2(0.0, SORT_BIAS - depth / 2.0)
