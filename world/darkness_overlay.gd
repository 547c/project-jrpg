class_name DarknessOverlay
extends CanvasLayer

# 플레이어 중심의 원형 시야를 만드는 화면 전체 어둠 막. 오토로드가 아니라 씬에 얹는 노드라,
# 이 노드가 들어있는 씬(동굴)에서만 동작하고 다른 씬에는 영향이 없다.
#
# [왜 Light2D가 아니라 셰이더인가]
# - Light2D 방식은 CanvasModulate로 캔버스를 통째로 어둡게 깔아야 하는데, 이 프로젝트는 HUD와
#   메뉴가 전부 같은 캔버스의 CanvasLayer들이라 UI까지 함께 어두워질 위험이 있다.
# - 플레이어는 씬이 아니라 SceneManager(오토로드)가 들고 있어 모든 씬이 공유하고, 몬스터도
#   monster_encounter.gd 하나를 숲/사막/유적이 함께 쓴다. 조명을 달면 그 공용 노드들에
#   "동굴에서만 켠다"는 처리를 따로 심어야 한다.
# - 화면 하나를 덮는 셰이더 한 장이면 위 두 문제가 모두 없고, 반경과 감쇠를 픽셀 단위로 지정할 수
#   있어 "일정 거리 밖은 완전히 검게"를 그대로 표현할 수 있다.

const MAX_GLOWS := 8
# 빈 글로우 슬롯을 화면 밖으로 밀어 기여를 0으로 만든다 (셰이더에서 개수 분기를 없애기 위함)
const OFFSCREEN := Vector2(-10000.0, -10000.0)

@onready var _rect: ColorRect = $Rect

var _material: ShaderMaterial


func _ready() -> void:
	_material = _rect.material as ShaderMaterial


# 카메라가 플레이어를 따라다니므로 화면 좌표는 매 프레임 달라진다 — 그래서 매번 다시 넘긴다
func _process(_delta: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	_material.set_shader_parameter("player_pos", _player_screen_position())
	_material.set_shader_parameter("glow_positions", _monster_screen_positions())


# 플레이어의 월드 좌표를 카메라/줌이 반영된 화면 좌표로 변환.
# 플레이어가 없으면(전투 진입 등으로 잠시 빠졌을 때) 화면 밖으로 보내 전체를 어둡게 유지한다
func _player_screen_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return OFFSCREEN
	return player.get_global_transform_with_canvas().origin


# 지금 필드에 나와 있는 몬스터들의 화면 좌표. 남는 자리는 화면 밖 좌표로 채워
# 셰이더가 개수와 무관하게 항상 같은 길이의 배열을 받게 한다
func _monster_screen_positions() -> PackedVector2Array:
	var positions := PackedVector2Array()
	for node in get_tree().get_nodes_in_group("monster_encounters"):
		if positions.size() >= MAX_GLOWS:
			break
		var monster := node as MonsterEncounter
		if monster == null or not monster.is_active_in_world():
			continue
		positions.append(monster.get_global_transform_with_canvas().origin)

	while positions.size() < MAX_GLOWS:
		positions.append(OFFSCREEN)
	return positions
