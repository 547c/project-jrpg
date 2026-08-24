class_name TreeProp
extends StaticBody2D

# 마을의 나무 한 그루. 예전에는 타일맵에 여러 타일로 찍혀 있어서 충돌도 정렬도 흔들림도 줄 수 없었는데,
# 이제 나무 하나 = 노드 하나라 밑동 충돌 / Y-Sort / 잎 살랑임을 각각 붙일 수 있다.
#
# 이 파일은 "플레이어를 가리기도 가려지기도 해야 하는 맵 오브젝트"의 첫 사례라, 그 구조를
# docs/map_objects.md에 재사용 가능한 규칙으로 정리해뒀다. 건물/바위 등 다음 프리팹을 만들 때는
# 여기 코드를 베끼기보다 그 문서를 먼저 보는 게 낫다 — 왜 이렇게 만들었는지(원점을 왜 발밑에
# 두는지, z_index를 왜 이 값으로 맞추는지 등)의 "이유"가 문서 쪽에 있고, 여기는 그 규칙을 나무에
# 적용한 한 가지 구현일 뿐이다. 아래 주석은 규칙을 요약만 하고, 자세한 배경은 문서를 가리킨다.
#
# monster_encounter.gd가 변종 표에서 하나를 골라 스프라이트를 조립하는 방식을 그대로 따른다 —
# 인스턴스는 variant 이름만 지정하고, 시트에서 어디를 잘라낼지는 아래 표가 결정한다.
#
# [노드 원점 = 정렬 기준점 = "발밑"] (docs/map_objects.md #1)
# 캐릭터(플레이어/NPC)는 스프라이트 중심이 노드 원점이라 발보다 한참 위를 기준으로 Y-Sort된다.
# 나무만 시각적 밑동을 기준으로 두면 캐릭터가 나무를 스쳐 지나갈 때 앞뒤가 바뀌는 시점이 어긋나
# 보이므로, 원점을 밑동보다 SORT_BIAS만큼 위에 두고 그림과 충돌을 그만큼 내려서 그린다.
# (SORT_BIAS 값 자체는 계산이 아니라 실제로 캐릭터 옆에 세워보며 맞춘 값 — 문서 참고)

const SORT_BIAS := 20.0

# 밑동 충돌 크기. 스프라이트 전체가 아니라 줄기 밑동만 막아서, 잎 아래로는 지나다닐 수 있게 한다
const TRUNK_WIDTH_RATIO := 0.22
const TRUNK_WIDTH_MIN := 10.0
const TRUNK_HEIGHT := 12.0

# [그림자 = 스프라이트를 검게 복제해 바닥에 눕힌 실루엣]
# 타원 대신 나무와 같은 texture/region을 그대로 쓰는 두 번째 Sprite2D를 쓴다 — 그러면 나무 13종의
# 캐노피 모양이 제각각이어도(동그란 활엽수/뾰족한 침엽수/앙상한 고사목 등) 그림자가 항상 그 나무의
# 실제 실루엣을 따라간다. 크기도 region을 그대로 재사용하니 변종마다 별도 비율 계산이 필요 없다.
# 눕히는 각도/납작한 정도는 맵 전체가 공유하는 광원 방향(ShadowLayer.GROUND_LEAN/SQUASH)을 쓰고,
# 밑동은 발밑에 딱 붙는다 — 그림자를 통째로 옆으로 밀면 접지점이 떨어져 오히려 떠 보인다

const SWAY_SHADER: Shader = preload("res://world/foliage_sway.gdshader")

# 실제 마을에 심겨 있던 나무들에서 그대로 뽑아낸 표 (모델/사이즈/시트 내 변종 위치)
const VARIANTS: Dictionary = {
	"model_01_s05_7_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_05.png", "region": Rect2(112, 0, 112, 160)},
	"model_03_s02_4_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_02.png", "region": Rect2(64, 0, 32, 80)},
	"model_01_s04_0_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_04.png", "region": Rect2(0, 0, 80, 128)},
	"model_02_s02_4_3": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_02.png", "region": Rect2(64, 48, 32, 48)},
	"model_02_s02_4_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_02.png", "region": Rect2(64, 0, 32, 48)},
	"model_02_s05_0_10": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_05.png", "region": Rect2(0, 160, 96, 160)},
	"model_03_s02_0_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_02.png", "region": Rect2(0, 0, 32, 80)},
	"model_03_s04_6_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_04-export.png", "region": Rect2(96, 0, 96, 208)},
	"model_03_s05_0_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_05.png", "region": Rect2(0, 0, 128, 256)},
	"model_01_s05_0_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_05.png", "region": Rect2(0, 0, 112, 160)},
	"model_02_s05_6_10": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_05.png", "region": Rect2(96, 160, 96, 160)},
	"model_02_s05_0_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_05.png", "region": Rect2(0, 0, 96, 160)},
	"model_01_s04_5_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_04.png", "region": Rect2(80, 0, 80, 128)},
	"model_02_s04_4_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_04.png", "region": Rect2(64, 0, 64, 112)},
	"model_03_s04_0_0": {"sheet": "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_04-export.png", "region": Rect2(0, 0, 96, 208)},
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
	add_to_group("tree_prop")
	# 플레이어/NPC와 같은 밴드에 서야 서로 Y 좌표로 앞뒤가 갈린다.
	# 자세한 이유는 SceneManager의 상수 주석 + docs/map_objects.md #3
	z_index = SceneManager.CHARACTER_BAND_Z_INDEX
	_build()


# 변종 표를 보고 스프라이트(시트에서 잘라낸 영역)와 밑동 충돌을 구성한다
func _build() -> void:
	if not VARIANTS.has(variant):
		push_warning("TreeProp: 알 수 없는 variant '%s'" % variant)
		return

	var spec: Dictionary = VARIANTS[variant]
	var region: Rect2 = spec["region"]

	var atlas := AtlasTexture.new()
	atlas.atlas = load(spec["sheet"]) as Texture2D
	atlas.region = region

	# 스프라이트와 완전히 같은 흔들림을 타도록 머티리얼 하나를 두 노드가 함께 쓴다(따로 만들면
	# 그림자만 미묘하게 다른 위상으로 흔들려 원본에서 분리된 것처럼 보인다 — MODEL_MATRIX 기반
	# 위상 계산이라 같은 리소스를 공유하는 쪽이 완전히 동일한 값을 보장한다)
	var sway_material := ShaderMaterial.new()
	sway_material.shader = SWAY_SHADER

	# 일단 이 노드의 자식으로 만든 뒤 공용 ShadowLayer로 넘긴다 — 그래야 다른 그림자와 겹쳐도
	# 밝기가 균일하다(이유는 world/shadow_layer.gd 주석)
	if _shadow == null:
		_shadow = Sprite2D.new()
		_shadow.name = "Shadow"
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_shadow.centered = false
		# 완전 불투명 검정으로 그린다 — 실제로 보이는 반투명함은 ShadowLayer의 self_modulate
		# 알파 하나로만 준다(겹쳐도 진해지지 않게 하는 핵심, ShadowLayer 주석 참고)
		_shadow.modulate = Color(0, 0, 0, 1)
		_shadow.material = sway_material
		add_child(_shadow)
		ShadowLayer.adopt(_shadow, self)

	_shadow.texture = atlas
	ShadowLayer.lay_on_ground(_shadow, Vector2(-region.size.x / 2.0, SORT_BIAS - region.size.y), SORT_BIAS)

	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.centered = false
		_sprite.material = sway_material
		add_child(_sprite)

	_sprite.texture = atlas
	# 그림의 아래 끝이 정렬 기준점보다 SORT_BIAS만큼 아래(= 실제 밑동)에 오도록 배치
	_sprite.offset = Vector2(-region.size.x / 2.0, SORT_BIAS - region.size.y)

	if _collision == null:
		_collision = CollisionShape2D.new()
		_collision.name = "CollisionShape2D"
		add_child(_collision)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(region.size.x * TRUNK_WIDTH_RATIO, TRUNK_WIDTH_MIN), TRUNK_HEIGHT)
	_collision.shape = shape
	_collision.position = Vector2(0.0, SORT_BIAS - TRUNK_HEIGHT / 2.0)
