extends Control

# 우하단 미니맵. 별도 SubViewport의 Camera2D가 메인 화면과 같은 World2D를 공유해서,
# 지금 씬을 위에서 내려다보는 모습을 실시간으로 그대로 렌더링한다 — 새 아트 없이도
# 존이 바뀌면 자동으로 그 존이 비친다. 카메라는 메인 카메라와 같은 씬 경계로 clamp되고,
# 시야 제한 씬(동굴 등)에서는 지형 대신 검은 화면 위에 마커만 떠 있게 된다.

const ZOOM := 0.22 # 작을수록 넓게 보인다 (player.gd의 BASE_ZOOM 주석과 같은 기준)
const UNBOUNDED := 10000000 # 씬 경계를 못 구했을 때 되돌릴 Camera2D 기본 limit 값

@onready var _viewport_container: SubViewportContainer = $ViewportContainer
@onready var _viewport: SubViewport = $ViewportContainer/SubViewport
@onready var _camera: Camera2D = $ViewportContainer/SubViewport/Camera2D
@onready var _darkness_mask: ColorRect = $DarknessMask
@onready var _markers = $Markers

var _last_scene: Node


func _ready() -> void:
	_viewport.world_2d = get_tree().root.get_world_2d()
	_camera.zoom = Vector2(ZOOM, ZOOM)
	_camera.make_current()
	_markers.camera = _camera
	_markers.zoom = ZOOM


func _process(_delta: float) -> void:
	if not SceneManager.has_player():
		return

	var scene := get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		_apply_scene_bounds()
		_darkness_mask.visible = get_tree().get_first_node_in_group("darkness_overlay") != null

	_camera.global_position = SceneManager.get_player_position()


func _apply_scene_bounds() -> void:
	var bounds := SceneManager.get_current_scene_bounds()
	if bounds.size == Vector2.ZERO:
		_camera.limit_left = -UNBOUNDED
		_camera.limit_top = -UNBOUNDED
		_camera.limit_right = UNBOUNDED
		_camera.limit_bottom = UNBOUNDED
		return
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)
