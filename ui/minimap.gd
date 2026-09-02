extends Control

# 우상단 미니맵. 별도 SubViewport의 Camera2D가 메인 화면과 같은 World2D를 공유해서,
# 지금 씬을 위에서 내려다보는 모습을 실시간으로 그대로 렌더링한다 — 새 아트 없이도
# 존이 바뀌면 자동으로 그 존이 비친다. 카메라가 매 프레임 플레이어를 따라가므로
# 플레이어는 항상 화면 중앙에 오고, 표시는 그 중앙에 고정된 점 하나로 충분하다.

const ZOOM := 0.22 # 작을수록 넓게 보인다 (player.gd의 BASE_ZOOM 주석과 같은 기준)
const MARKER_RADIUS := 4.0
const MARKER_SIDES := 12
const MARKER_COLOR := Color(0.96, 0.85, 0.35, 1) # Compass 화살표와 같은 색으로 통일

@onready var _viewport_container: SubViewportContainer = $ViewportContainer
@onready var _viewport: SubViewport = $ViewportContainer/SubViewport
@onready var _camera: Camera2D = $ViewportContainer/SubViewport/Camera2D
@onready var _marker: Polygon2D = $Marker
@onready var _marker_outline: Line2D = $Marker/Outline


func _ready() -> void:
	_viewport.world_2d = get_tree().root.get_world_2d()
	_camera.zoom = Vector2(ZOOM, ZOOM)
	_camera.make_current()

	var circle := _build_circle(MARKER_RADIUS, MARKER_SIDES)
	_marker.polygon = circle
	_marker.position = _viewport_container.position + _viewport_container.size / 2.0
	_marker_outline.points = circle + PackedVector2Array([circle[0]])


func _process(_delta: float) -> void:
	if SceneManager.has_player():
		_camera.global_position = SceneManager.get_player_position()


func _build_circle(radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := TAU * i / sides
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
