@tool
class_name VegetationProp
extends StaticBody2D

# 마을의 낮은 식생(덤불/잔풀/이파리/꽃) 한 덩이. 나무(tree_prop.gd)와 같은 규칙을 따르는 두 번째
# 사례이므로, 구조의 "왜"는 docs/map_objects.md에 있고 여기서는 식생만의 차이만 설명한다.
#
# [왜 타일이 아니라 프리팹으로 옮겼나]
# 원래는 타일맵에 찍힌 타일이었는데, 흔들림을 주려면 셰이더를 붙일 대상이 필요했다. 레거시 TileMap은
# 노드 전체가 CanvasItem 하나라 레이어별 머티리얼이 없어서, 거기 셰이더를 걸면 같은 타일맵의 땅·벽·
# 지붕·돌까지 전부 흔들린다. TileMapLayer나 TileData.material로 범위를 좁힐 수는 있지만, 타일 셰이더는
# UV가 칸 단위로 끊겨서 여러 칸짜리 덤불이 칸 경계마다 찢어진다 — 식생의 3분의 1이 2~3칸짜리라
# 그 방식을 쓸 수 없었다. 오브젝트 하나 = 스프라이트 하나로 만들면 두 문제가 한 번에 사라진다.
#
# [크기에 따라 충돌을 다르게 준다]
# 예전에는 등록된 타일 295칸 전부가 크기와 무관하게 16x16 정사각 충돌을 갖고 있어서, 발에 밟힐 만한
# 잔풀 한 포기도 벽처럼 앞을 막았다. 이제 변종 표의 blocks 값으로 갈라서, 덤불만 밑동을 막고
# 잔풀·이파리·꽃은 아예 충돌을 만들지 않는다(그 위로 지나다닐 수 있다).

const SORT_BIAS := 8.0 # 나무(20)보다 작다 — 식생은 키가 낮아 기준점을 그만큼 올릴 필요가 없다

# 덤불 밑동 충돌. 나무 줄기와 달리 덤불은 덩어리째 서 있어서 폭 비율이 훨씬 크다
const BUSH_WIDTH_RATIO := 0.6
const BUSH_HEIGHT := 10.0

# [그림자 = 스프라이트를 검게 복제해 바닥에 눕힌 실루엣] (자세한 설명은 tree_prop.gd 참고, 동일한 방식)
# 충돌 유무와 무관하게 전부(덤불+잔풀) 그린다 — 충돌 없는 잔풀도 그림자가 있어야 바닥에 붙어
# 있는 것처럼 보인다(없으면 오려 붙인 스티커처럼 붕 떠 보인다, 실제로 렌더링해서 확인).

const SWAY_SHADER: Shader = preload("res://world/foliage_sway.gdshader")
const SHEET := "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png"

# 풀은 나무보다 가볍게, 조금 더 빠르고 크게 흔들린다
const SWAY_STRENGTH := 1.1
const SWAY_SPEED := 1.9

# 실제 마을에 심겨 있던 식생에서 그대로 뽑아낸 표.
# blocks=true 는 덤불(밑동 충돌 있음), false 는 잔풀/이파리/꽃(충돌 없음)
const VARIANTS: Dictionary = {
	"bush_0_4_3x2": {"region": Rect2(0, 64, 48, 32), "blocks": true},
	"bush_0_6_3x3": {"region": Rect2(0, 96, 48, 48), "blocks": true},
	"bush_3_2_3x2": {"region": Rect2(48, 32, 48, 32), "blocks": true},
	"bush_3_4_3x2": {"region": Rect2(48, 64, 48, 32), "blocks": true},
	"bush_6_0_2x2": {"region": Rect2(96, 0, 32, 32), "blocks": true},
	"bush_6_6_3x3": {"region": Rect2(96, 96, 48, 48), "blocks": true},
	"plant_0_11_1x1": {"region": Rect2(0, 176, 16, 16), "blocks": false},
	"plant_10_11_1x1": {"region": Rect2(160, 176, 16, 16), "blocks": false},
	"plant_13_10_1x2": {"region": Rect2(208, 160, 16, 32), "blocks": false},
	"plant_14_11_1x1": {"region": Rect2(224, 176, 16, 16), "blocks": false},
	"plant_2_10_1x1": {"region": Rect2(32, 160, 16, 16), "blocks": false},
	"plant_2_11_1x1": {"region": Rect2(32, 176, 16, 16), "blocks": false},
	"plant_2_13_1x1": {"region": Rect2(32, 208, 16, 16), "blocks": false},
	"plant_2_9_1x1": {"region": Rect2(32, 144, 16, 16), "blocks": false},
	"plant_3_10_1x1": {"region": Rect2(48, 160, 16, 16), "blocks": false},
	"plant_3_11_1x1": {"region": Rect2(48, 176, 16, 16), "blocks": false},
	"plant_3_14_1x1": {"region": Rect2(48, 224, 16, 16), "blocks": false},
	"plant_4_10_1x1": {"region": Rect2(64, 160, 16, 16), "blocks": false},
	"plant_5_11_1x1": {"region": Rect2(80, 176, 16, 16), "blocks": false},
	"plant_5_9_2x2": {"region": Rect2(80, 144, 32, 32), "blocks": false},
	"plant_6_11_1x1": {"region": Rect2(96, 176, 16, 16), "blocks": false},
	"plant_7_10_1x2": {"region": Rect2(112, 160, 16, 32), "blocks": false},
	"plant_9_10_1x2": {"region": Rect2(144, 160, 16, 32), "blocks": false},
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
	if not Engine.is_editor_hint():
		add_to_group("vegetation_prop")
	_build()


# 변종 표를 보고 스프라이트를 구성하고, 덤불이면 밑동 충돌까지 만든다.
# 에디터에서는 스프라이트만 그리고 그림자/흔들림 셰이더/충돌은 건너뛴다 (이유는 tree_prop.gd 참고)
func _build() -> void:
	if not VARIANTS.has(variant):
		push_warning("VegetationProp: 알 수 없는 variant '%s'" % variant)
		return

	var spec: Dictionary = VARIANTS[variant]
	var region: Rect2 = spec["region"]

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
	# 그림의 아래 끝이 정렬 기준점보다 SORT_BIAS만큼 아래(= 실제 밑동)에 오도록 배치
	_sprite.offset = Vector2(-region.size.x / 2.0, SORT_BIAS - region.size.y)

	if Engine.is_editor_hint():
		return

	# 스프라이트와 완전히 같은 흔들림을 타도록 머티리얼 하나를 두 노드가 함께 쓴다 (tree_prop.gd와 동일한 이유)
	var sway_material := ShaderMaterial.new()
	sway_material.shader = SWAY_SHADER
	sway_material.set_shader_parameter("sway_strength", SWAY_STRENGTH)
	sway_material.set_shader_parameter("sway_speed", SWAY_SPEED)
	_sprite.material = sway_material

	# 일단 이 노드의 자식으로 만든 뒤 공용 ShadowLayer로 넘긴다 (tree_prop.gd와 동일)
	if _shadow == null:
		_shadow = Sprite2D.new()
		_shadow.name = "Shadow"
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_shadow.centered = false
		_shadow.modulate = Color(0, 0, 0, 1)
		_shadow.material = sway_material
		add_child(_shadow)
		ShadowLayer.adopt(_shadow, self)

	_shadow.texture = atlas
	ShadowLayer.lay_on_ground(_shadow, Vector2(-region.size.x / 2.0, SORT_BIAS - region.size.y), SORT_BIAS)

	_build_collision(region, bool(spec["blocks"]))


# 덤불이면 밑동에만 좁은 충돌을 두고, 잔풀류면 충돌 노드를 아예 두지 않는다
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

	var shape := RectangleShape2D.new()
	shape.size = Vector2(region.size.x * BUSH_WIDTH_RATIO, BUSH_HEIGHT)
	_collision.shape = shape
	_collision.position = Vector2(0.0, SORT_BIAS - BUSH_HEIGHT / 2.0)
