extends CanvasLayer

# 야외 씬(마을 등)에 왼쪽 위에서 스며드는 빛줄기(갓레이)를 그리는 화면 공간 오버레이 (autoload).
# world 레이어(기본 0)보다는 위, SceneTint(layer 2)보다는 아래에 그려서 — 빛줄기가 구역별
# 색조에 자연스럽게 섞이고, 달릴 때 SpeedVignette(layer 3)가 가장자리를 어둡게 덮으면 빛줄기도
# 함께 죽는다. HUD(layer 8)보다 한참 아래라 UI에는 전혀 영향이 없다.
#
# [저해상도 SubViewport 확대 트릭을 포기한 이유]
# 자세한 사정은 god_rays.gdshader 상단 주석 참고 — 실제 village.tscn(무거운 진짜 게임 씬)에서
# SubViewport 결과를 화면에 보여주는 TextureRect가 원인 불명의 이유로 전혀 렌더링되지 않는
# 문제가 있어(작은 디버그 씬에서는 정상 작동), 화면에 직접 그리는 방식으로 되돌렸다.
#
# [왜 씬마다 배치하지 않고 오토로드인가]
# ForegroundLeaves/SpeedVignette와 같은 이유 — 화면 공간 오버레이는 씬이 바뀌어도 항상 같은
# 레이어에 있어야 한다. 배경 낙엽이 없는 씬(전투/동굴/실내)에서까지 빛줄기가 뜨면 안 되므로,
# ForegroundLeaves와 완전히 같은 기준("leaf_emitter" 그룹 노드가 지금 씬에 있는가)으로
# 켜고 끈다 — 별도 마커를 새로 만들지 않고 "야외라 낙엽이 날리는 씬 = 갓레이도 있는 씬"으로
# 취급한다.
#
# 빛 방향은 shadow_layer.gd의 GROUND_LEAN/GROUND_SQUASH를 그대로 셰이더에 넘긴다 — 그림자가
# 눕는 방향과 빛줄기 방향이 어긋나면 광원이 두 군데인 것처럼 보인다.
#
# [틈새 위치가 화면 UV가 아니라 월드 좌표인 이유]
# 처음엔 화면 UV(0~1)에 고정된 자리였는데, 그러면 카메라가 어디를 보든 항상 같은 화면 위치에
# 떠 있는 "렌즈 얼룩"처럼 보이고, 실제 지도의 어디에 캐노피 틈새가 있는지와도 무관해진다.
# "플레이어가 실제로 자주 지나다니는 구역에 있어야 한다"는 피드백을 받아, village.tscn을
# 실제로 열어 나무 좌표를 확인하고 그 경로를 따라 잡았다 — darkness_overlay.gd가 몬스터 월드
# 좌표를 매 프레임 화면 좌표로 바꾸는 것과 같은 방식으로, 여기서도 카메라 위치/줌을 보고
# 매 프레임 화면 UV로 다시 계산해 셰이더에 넘긴다.
#
# [자리 6곳 — 스폰~숲 경로 3곳 + 동굴 가는 길 2곳 + 마을 서쪽 1곳]
# 처음엔 스폰(1,-1)~숲 입구(ToForest, 1014,13) 경로 3곳만 있었는데, "동굴 가는 길/마을
# 곳곳에도 뿌려달라"는 요청으로 늘렸다. 동굴 쪽은 VillageSpawnFromCave(-48,-431)/ToCave(-45,-528)
# 로 이어지는 북쪽 나무 줄(예: (9,-351),(18,-398),(79,-453) 등)을 따라 2곳, 서쪽은 그 반대편
# 나무 군집(예: (-477,-107),(-453,-443))에서 1곳을 잡았다. 배열 길이는 god_rays.gdshader의
# LEAK_COUNT(6)와 정확히 맞춰야 한다.
const LEAK_WORLD_POSITIONS: Array[Vector2] = [
	Vector2(250, -80), # 스폰 직후 첫 나무들 사이
	Vector2(680, -40), # 마을-숲 중간 나무 군집
	Vector2(900, -60), # 숲 입구 앞 나무가 빽빽한 구간
	Vector2(30, -370), # 동굴 가는 길 초입 나무 사이
	Vector2(60, -470), # 동굴 입구 앞 나무 군집
	Vector2(-460, -200), # 마을 서쪽 나무 군집
]
var _leak_along := PackedFloat32Array([0.4, 0.32, 0.35, 0.3, 0.32, 0.34])
var _leak_across := PackedFloat32Array([0.13, 0.1, 0.11, 0.1, 0.1, 0.11])

@onready var _rect: ColorRect = $Rect

var _mat: ShaderMaterial


func _ready() -> void:
	_mat = _rect.material as ShaderMaterial
	_mat.set_shader_parameter("light_dir", Vector2(ShadowLayer.GROUND_LEAN, ShadowLayer.GROUND_SQUASH))
	_mat.set_shader_parameter("leak_along", _leak_along)
	_mat.set_shader_parameter("leak_across", _leak_across)
	visible = false # 첫 _process가 판단하기 전 한 프레임 동안 실내/전투 씬에서 잠깐 비치는 것 방지


func _process(_delta: float) -> void:
	visible = get_tree().get_first_node_in_group("leaf_emitter") != null
	if visible:
		_update_leak_screen_positions()


# 고정된 월드 좌표(LEAK_WORLD_POSITIONS)를 지금 카메라 기준 화면 UV로 매 프레임 다시 계산한다.
# darkness_overlay.gd의 몬스터 글로우 좌표 변환과 같은 방식(get_screen_center_position() 기준)
func _update_leak_screen_positions() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var zoom: float = maxf(camera.zoom.x, 0.01)
	var view_size := viewport_size / zoom
	var view_top_left := camera.get_screen_center_position() - view_size / 2.0

	var uv_positions := PackedVector2Array()
	for world_pos in LEAK_WORLD_POSITIONS:
		uv_positions.append((world_pos - view_top_left) / view_size)
	_mat.set_shader_parameter("leak_pos", uv_positions)
