class_name Player
extends CharacterBody2D

const RUN_SPEED_MULTIPLIER := 1.6

# 카메라 줌. 값이 작을수록 더 멀리서(넓게) 보인다 — 달리는 동안은 거기서 한 번 더 낮춰
# 속도감을 준다(SpeedVignette의 가장자리 흐림과 짝을 이루는 연출). 딱 바뀌지 않고
# CAMERA_ZOOM_TWEEN_DURATION에 걸쳐 부드럽게 전환한다(_update_run_camera_effects 참고)
const BASE_ZOOM := 1.5
const RUN_ZOOM := 1.2
const CAMERA_ZOOM_TWEEN_DURATION := 0.4

# [이동 가속도]
# 목표 속도(걷기/달리기)까지 즉시 도달하지 않고 ACCEL_TIME에 걸쳐 서서히 오른다. 가속도는
# "달리기 최고속도 기준"으로 한 번만 정하고 걷기에도 그대로 쓴다 — 목표 속도별로 따로 정하면
# 걷기 가속만 유독 굼뜨거나 급해 보여서, 같은 가속도를 공유해야 걷기<->달리기 전환도 자연스럽다
# (그 결과 걷기는 240*ACCEL_TIME/150 ≈ 0.075초 만에, 달리기는 정확히 ACCEL_TIME만에 최고속도에 닿는다)
const ACCEL_TIME := 0.12
# 가속 중 애니메이션 재생 속도 배율의 하한(최고속도에서는 1.0). 가속이 눈에 보이도록 걸음이
# 느릴 때는 다리도 그만큼 느리게 움직이게 한다 — 발이 미끄러지는(애니메이션과 실제 이동속도가
# 안 맞는) 것처럼 보이지 않기 위한 보정이기도 하다
const ANIM_MIN_SPEED_SCALE := 0.55

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
var _last_is_running: bool = false # 입력을 뗀 뒤 감속 슬라이드 중에도 걷기/달리기 애니메이션을 유지하기 위해 기억해둔다
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
	_update_velocity(direction, is_running, delta)
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


# 주어진 방향에 따라 4방향(대각선 없음) 목표 속도를 정하고, 거기로 즉시 점프하는 대신
# ACCEL_TIME에 걸쳐 서서히 다가간다(move_toward). 방향이 없으면 목표가 Vector2.ZERO라
# 같은 식으로 서서히 감속해서 멈춘다 — 가속과 감속이 같은 코드 경로를 타므로 손맛이 대칭적이다
func _update_velocity(direction: String, is_running: bool, delta: float) -> void:
	var target_velocity := Vector2.ZERO
	if direction != "":
		var target_speed := speed * RUN_SPEED_MULTIPLIER if is_running else speed
		target_velocity = _AXIS_VECTORS[direction] * target_speed

	var accel := (speed * RUN_SPEED_MULTIPLIER) / ACCEL_TIME
	velocity = velocity.move_toward(target_velocity, accel * delta)


# 이동 방향에 맞는 walk/run 애니메이션을 재생하고, 정지 시 마지막 방향의 idle 애니메이션을 재생.
#
# [왜 direction이 아니라 velocity로 "움직이는 중"을 판단하는가]
# 가속도가 생긴 뒤로는 입력을 뗀 순간(direction=="") 바로 velocity가 0이 되지 않고 잠깐
# 관성으로 미끄러진다. direction만 보면 그 짧은 순간 캐릭터가 여전히 미끄러지고 있는데
# 그림은 idle로 뚝 바뀌어 미끄러지는 것처럼 보인다 — 실제 속도가 남아있는 동안은 걷기/달리기
# 그림을 유지해야 이동과 그림이 어긋나지 않는다. 어느 쪽(걷기/달리기, 어느 방향)을 유지할지는
# 마지막으로 실제 입력이 있었을 때의 값(_last_facing/_last_is_running)을 그대로 쓴다.
#
# [애니메이션 재생 속도 = 실제 속도 비율]
# 가속이 눈에 보이도록, 현재 속도가 목표 최고속도의 몇 %인지에 맞춰 speed_scale을 함께 올린다
# (ANIM_MIN_SPEED_SCALE에서 시작해 최고속도에 도달하면 1.0). 그냥 걷기/달리기를 딱 켜고 끄기만
# 하면 다리는 이미 전속력으로 움직이는데 캐릭터는 아직 가속 중인 것처럼 보여 어긋난다
func _update_animation(direction: String, is_running: bool) -> void:
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	var moving := velocity.length() > 0.01

	if direction != "":
		_last_facing = direction
		_last_is_running = is_running

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

	if not moving:
		sprite.speed_scale = 1.0
		sprite.play("idle_" + facing_key)
		return

	var reference_speed := speed * RUN_SPEED_MULTIPLIER if _last_is_running else speed
	var speed_fraction := clampf(velocity.length() / reference_speed, 0.0, 1.0)
	sprite.speed_scale = lerpf(ANIM_MIN_SPEED_SCALE, 1.0, speed_fraction)

	if _last_is_running:
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
