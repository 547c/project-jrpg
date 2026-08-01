extends CharacterBody2D

@export var speed: float = 100.0

var _direction_queue: Array[String] = []
var _last_facing: String = "down"

const _AXIS_VECTORS := {
	"up": Vector2(0, -1),
	"down": Vector2(0, 1),
	"left": Vector2(-1, 0),
	"right": Vector2(1, 0),
}


# Area2D 트리거 등이 플레이어를 식별할 수 있도록 "player" 그룹에 등록
func _ready() -> void:
	add_to_group("player")


# 매 프레임(물리) 입력 처리, 이동, 애니메이션 갱신을 순서대로 실행
func _physics_process(_delta: float) -> void:
	var direction := _get_current_direction()
	_update_velocity(direction)
	move_and_slide()
	_update_animation(direction)


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


# 주어진 방향에 따라 4방향(대각선 없음) 속도 벡터를 설정
func _update_velocity(direction: String) -> void:
	if direction == "":
		velocity = Vector2.ZERO
	else:
		velocity = _AXIS_VECTORS[direction] * speed


# 이동 방향에 맞는 walk 애니메이션을 재생하고, 정지 시 마지막 방향의 idle 애니메이션을 재생
func _update_animation(direction: String) -> void:
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
	else:
		sprite.play("walk_" + facing_key)
