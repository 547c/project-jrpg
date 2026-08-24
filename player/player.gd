class_name Player
extends CharacterBody2D

const RUN_SPEED_MULTIPLIER := 1.6

# 카메라 줌. 값이 작을수록 더 멀리서(넓게) 보인다 — 기존 2.0에서 살짝 낮춰 맵이 더 보이게 하고,
# 달리는 동안은 거기서 한 번 더 낮춰 속도감을 준다(SpeedVignette의 가장자리 흐림과 짝을 이루는 연출).
# 딱 바뀌지 않고 CAMERA_ZOOM_TWEEN_DURATION에 걸쳐 부드럽게 전환한다(_update_camera_zoom 참고)
const BASE_ZOOM := 1.8
const RUN_ZOOM := 1.6
const CAMERA_ZOOM_TWEEN_DURATION := 0.4

# 발소리: 걷기/달리기 중 일정 간격마다 무작위 발소리를 재생. 지형 구분 없이 Grass 세트를 공용으로 사용
const FOOTSTEP_DIR := "res://assets/sfx/NA_Character Footsteps (Dirt & Grass) - Pack 1/"
const FOOTSTEP_WALK_FILES: Array[String] = [
	"Walk/Grass/GRASS - Walk 1.wav",
	"Walk/Grass/GRASS - Walk 2.wav",
	"Walk/Grass/GRASS - Walk 3.wav",
	"Walk/Grass/GRASS - Walk 4.wav",
	"Walk/Grass/GRASS - Walk 5.wav",
	"Walk/Grass/GRASS - Walk 6.wav",
	"Walk/Grass/GRASS - Walk 7.wav",
	"Walk/Grass/GRASS - Walk 8.wav",
	"Walk/Grass/GRASS - Walk short 1.wav",
	"Walk/Grass/GRASS - Walk short 2.wav",
	"Walk/Grass/GRASS - Walk short 3.wav",
	"Walk/Grass/GRASS - Walk short 4.wav",
	"Walk/Grass/GRASS - Walk short 5.wav",
	"Walk/Grass/GRASS - Walk short 6.wav",
	"Walk/Grass/GRASS - Walk short 7.wav",
	"Walk/Grass/GRASS - Walk short 8.wav",
]
const FOOTSTEP_RUN_FILES: Array[String] = [
	"Run/Grass/GRASS - Run 1.wav",
	"Run/Grass/GRASS - Run 2.wav",
	"Run/Grass/GRASS - Run 3.wav",
	"Run/Grass/GRASS - Run 4.wav",
	"Run/Grass/GRASS - Run 5.wav",
	"Run/Grass/GRASS - Run 6.wav",
	"Run/Grass/GRASS - Run 7.wav",
	"Run/Grass/GRASS - Run 8.wav",
	"Run/Grass/GRASS - Run Short 1.wav",
	"Run/Grass/GRASS - Run Short 2.wav",
	"Run/Grass/GRASS - Run Short 3.wav",
	"Run/Grass/GRASS - Run Short 4.wav",
	"Run/Grass/GRASS - Run Short 5.wav",
	"Run/Grass/GRASS - Run Short 6.wav",
	"Run/Grass/GRASS - Run Short 7.wav",
	"Run/Grass/GRASS - Run Short 8.wav",
]
const FOOTSTEP_INTERVAL_WALK := 0.35 # 초
const FOOTSTEP_INTERVAL_RUN := 0.22 # 달릴 때는 더 짧게(잦게)
const FOOTSTEP_VOLUME_DB := -14.0 # 과하지 않게 낮춤

@export var speed: float = 150.0

var _direction_queue: Array[String] = []
var _last_facing: String = "down"
var _footstep_timer: float = 0.0
var _shadow: CharacterShadow
var _is_running_moving: bool = false # "달리는 중"의 실제 기준 = Shift를 누른 채 실제로 이동 중
var _zoom_tween: Tween

@onready var _footstep_player: AudioStreamPlayer = $FootstepPlayer
@onready var _camera: Camera2D = $Camera2D

const _AXIS_VECTORS := {
	"up": Vector2(0, -1),
	"down": Vector2(0, 1),
	"left": Vector2(-1, 0),
	"right": Vector2(1, 0),
}


# Area2D 트리거 등이 플레이어를 식별할 수 있도록 "player" 그룹에 등록
func _ready() -> void:
	add_to_group("player")
	_camera.zoom = Vector2(BASE_ZOOM, BASE_ZOOM)


# 발밑 그림자를 현재 씬의 ShadowLayer에 만들어 붙인다 (그림자를 쓰는 씬에서만 실제로 생긴다).
# 플레이어는 씬을 넘어 살아남지만 그림자는 씬과 함께 사라지므로, 씬에 들어올 때마다
# SceneManager가 다시 불러준다 — 자세한 이유는 world/character_shadow.gd 주석
func attach_shadow() -> void:
	if is_instance_valid(_shadow):
		_shadow.queue_free()
	_shadow = CharacterShadow.attach(self, $AnimatedSprite2D as AnimatedSprite2D)


# 매 프레임(물리) 입력 처리, 이동, 애니메이션, 발소리 갱신을 순서대로 실행
func _physics_process(delta: float) -> void:
	var blocked := _is_input_blocked()
	var direction := "" if blocked else _get_current_direction()
	var is_running := not blocked and Input.is_action_pressed("run")
	_update_velocity(direction, is_running)
	move_and_slide()
	_update_animation(direction, is_running)
	_update_footsteps(direction, is_running, delta)
	_update_run_camera_effects(direction != "" and is_running)


# 카메라 줌아웃/화면 가장자리 비네트는 "Shift를 누르고 있음"이 아니라 "실제로 달리고 있음"
# (방향키도 함께 눌려 실제로 움직이는 중)을 기준으로 켠다 — 제자리에서 Shift만 누르고 있을 때
# 화면이 바뀌면 오히려 이상해 보인다. 상태가 실제로 바뀐 프레임에만 트윈을 새로 걸어서,
# 매 프레임 같은 트윈을 다시 만들어 덮어쓰는 일이 없게 한다
func _update_run_camera_effects(running_moving: bool) -> void:
	if running_moving == _is_running_moving:
		return
	_is_running_moving = running_moving

	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	var target_zoom := RUN_ZOOM if running_moving else BASE_ZOOM
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_camera, "zoom", Vector2(target_zoom, target_zoom), CAMERA_ZOOM_TWEEN_DURATION)

	SpeedVignette.set_running(running_moving)


# DialogueBox/전투 씬/PauseMenu/GameOver 중 하나라도 화면에 열려 있으면 이동 입력을 무시.
# 각 UI는 해당 그룹에 스스로 등록하고 visible로 열림 여부를 나타내므로,
# 별도 전역 플래그 없이 그 상태를 그대로 조회한다
func _is_input_blocked() -> bool:
	for group_name in ["dialogue_box", "battle_box", "pause_menu", "game_over", "quest_log", "level_up", "inventory_menu", "chapter_title_card"]:
		var ui := get_tree().get_first_node_in_group(group_name) as CanvasItem
		if ui != null and ui.visible:
			return true
	return false


# 방향키 입력의 눌림/뗌 순서를 기록해 대각선 입력 시 마지막으로 누른 방향이 우선되도록 함
func _unhandled_input(event: InputEvent) -> void:
	for dir: String in _AXIS_VECTORS.keys():
		var action: String = "move_" + dir
		if event.is_action_pressed(action):
			_direction_queue.erase(dir)
			_direction_queue.append(dir)
		elif event.is_action_released(action):
			_direction_queue.erase(dir)


# 현재 눌려 있는 방향 중 가장 최근에 눌린 방향 하나를 반환 (없으면 빈 문자열)
func _get_current_direction() -> String:
	if _direction_queue.is_empty():
		return ""
	return _direction_queue.back()


# 주어진 방향에 따라 4방향(대각선 없음) 속도 벡터를 설정. Shift(달리기)가 눌려 있으면 속도에 배율 적용
func _update_velocity(direction: String, is_running: bool) -> void:
	if direction == "":
		velocity = Vector2.ZERO
	else:
		var current_speed := speed * RUN_SPEED_MULTIPLIER if is_running else speed
		velocity = _AXIS_VECTORS[direction] * current_speed


# 이동 방향에 맞는 walk/run 애니메이션을 재생하고, 정지 시 마지막 방향의 idle 애니메이션을 재생
func _update_animation(direction: String, is_running: bool) -> void:
	var sprite := $AnimatedSprite2D as AnimatedSprite2D

	if direction != "":
		_last_facing = direction

	match _last_facing:
		"left":
			sprite.flip_h = true
		"right":
			sprite.flip_h = false
		_:
			pass

	var facing_key := _last_facing
	if facing_key == "left" or facing_key == "right":
		facing_key = "side"

	if direction == "":
		sprite.play("idle_" + facing_key)
	elif is_running:
		sprite.play("run_" + facing_key)
	else:
		sprite.play("walk_" + facing_key)


# 이동 중일 때만 일정 간격(달릴 때는 더 짧게)마다 무작위 발소리를 재생. 정지하면 타이머를 리셋하고
# 혹시 재생 중이던 발소리도 즉시 멈춰(제자리에 서있을 때는 재생되지 않도록)
func _update_footsteps(direction: String, is_running: bool, delta: float) -> void:
	if direction == "":
		_footstep_timer = 0.0
		if _footstep_player.playing:
			_footstep_player.stop()
		return

	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		var interval := FOOTSTEP_INTERVAL_RUN if is_running else FOOTSTEP_INTERVAL_WALK
		_footstep_timer = interval
		_play_footstep(is_running)


func _play_footstep(is_running: bool) -> void:
	var pool := FOOTSTEP_RUN_FILES if is_running else FOOTSTEP_WALK_FILES
	var file: String = pool[randi() % pool.size()]
	_footstep_player.stream = load(FOOTSTEP_DIR + file) as AudioStream
	_footstep_player.volume_db = FOOTSTEP_VOLUME_DB
	_footstep_player.play()
