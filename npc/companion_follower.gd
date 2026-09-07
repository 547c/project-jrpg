@tool
class_name CompanionFollower
extends NPC

# 파티에 합류한 동료가 오버월드에서 플레이어를 따라다니는 공통 이동 로직. 배회(NPC._process) 대신
# 이 _process()가 완전히 대체한다. 유서프 전용이던 yusuf_follower.gd에서 뽑아냈다 — 여기 있는 건
# 전부 "누구를 따라가는가"와 무관한 범용 로직이라(사거리/가속/블러/방향전환), 앞으로 추가될 동료도
# 서브클래스에서 _ready()만 자기 것으로 채우면 그대로 쓸 수 있다.
#
# player.gd의 가속도(ACCEL_TIME, move_toward)·애니메이션 speed_scale·달리기 블러(SpeedVignette)
# 패턴을 그대로 가져왔다 — 플레이어 이동 스크립트 자체는 손대지 않았다.

const FOLLOW_STOP_DISTANCE := 36.0 # 이 안쪽이면 완전히 멈춘다("개인 공간")
const FOLLOW_CATCHUP_DISTANCE := 140.0 # 이 밖이면 최고 속도 쪽으로 더 붙는다("너무 멀어짐")
const FOLLOW_SPEED := 150.0 # 정상 추종 속도(플레이어 걷기와 비슷한 페이스)
const FOLLOW_CATCHUP_SPEED := 260.0 # 많이 뒤처졌을 때의 최고 속도
const FOLLOW_SNAP_DISTANCE := 500.0 # 이보다 멀면(씬 전환 직후 등) 순간이동 — 안전장치, 그대로 유지

# player.gd의 ACCEL_TIME과 같은 역할 — 목표 속도까지 즉시가 아니라 이 시간에 걸쳐 서서히
const FOLLOW_ACCEL_TIME := 0.2
# player.gd의 ANIM_MIN_SPEED_SCALE과 같은 역할(가속 중 애니메이션 재생 속도 하한)
const ANIM_MIN_SPEED_SCALE := 0.5
# 좌우 스프라이트 flip을 바꿀 속도 하한. 이보다 작은 x성분은 무시해 상하로 거의 곧장
# 움직일 때 좌우로 미세하게 흔들리며 flip이 깜빡이는 것을 막는다
const FACING_FLIP_DEADZONE := 20.0
# 이 속도를 넘어 움직이면 "빠르게 따라잡는 중"으로 보고 화면 블러를 켠다
const BLUR_SPEED_THRESHOLD := FOLLOW_SPEED

@export var follow_offset := Vector2(-28, 18) # 플레이어 기준 목표 위치 오프셋(캐릭터 그림 크기별로 다를 수 있어 export)

var _velocity := Vector2.ZERO


# SceneManager가 씬을 옮겨 붙일 때마다 호출 (플레이어의 attach_shadow()와 같은 이유 —
# 그림자는 씬의 ShadowLayer가 들고 있어서 씬과 함께 사라진다)
func resync_shadow() -> void:
	_attach_shadow()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _in_dialogue:
		SpeedVignette.set_companion_running(false)
		return
	if not SceneManager.has_player():
		return

	var target: Vector2 = SceneManager.get_player_position() + follow_offset
	var to_target := target - global_position
	var dist := to_target.length()

	if dist > FOLLOW_SNAP_DISTANCE:
		global_position = target
		_velocity = Vector2.ZERO
		SpeedVignette.set_companion_running(false)
		_update_wander_animation(false)
		return

	var target_velocity := Vector2.ZERO
	if dist > 0.01:
		target_velocity = (to_target / dist) * _target_speed_for_distance(dist)

	var accel := FOLLOW_CATCHUP_SPEED / FOLLOW_ACCEL_TIME
	_velocity = _velocity.move_toward(target_velocity, accel * delta)
	global_position += _velocity * delta

	_update_facing_and_animation()
	SpeedVignette.set_companion_running(_velocity.length() > BLUR_SPEED_THRESHOLD)


# 거리 -> 목표 속도. 세 구간을 선형으로 이어 붙여 "너무 가까우면 0까지 느려지고, 너무 멀면
# 최고 속도까지 부드럽게 올라가는" 하나의 연속된 곡선을 만든다(예전엔 두 값을 그냥 스위치했다)
func _target_speed_for_distance(dist: float) -> float:
	if dist <= FOLLOW_STOP_DISTANCE:
		return 0.0
	if dist <= FOLLOW_CATCHUP_DISTANCE:
		return remap(dist, FOLLOW_STOP_DISTANCE, FOLLOW_CATCHUP_DISTANCE, 0.0, FOLLOW_SPEED)
	return remap(minf(dist, FOLLOW_SNAP_DISTANCE), FOLLOW_CATCHUP_DISTANCE, FOLLOW_SNAP_DISTANCE, FOLLOW_SPEED, FOLLOW_CATCHUP_SPEED)


# player.gd._update_animation()과 같은 두 가지를 한다: (1) 실제 속도 방향으로만 flip을 바꿔
# 순간적으로 홱 도는 대신 가속도를 타고 자연스럽게 좌우가 바뀌게 하고, (2) 애니메이션 재생
# 속도를 실제 이동 속도 비율에 맞춰 다리가 미끄러지는 것처럼 보이지 않게 한다
func _update_facing_and_animation() -> void:
	var speed_now := _velocity.length()
	if speed_now < 1.0:
		_sprite.speed_scale = 1.0
		_update_wander_animation(false)
		return

	if absf(_velocity.x) > FACING_FLIP_DEADZONE:
		_sprite.flip_h = _velocity.x < 0.0

	var speed_fraction := clampf(speed_now / FOLLOW_CATCHUP_SPEED, 0.0, 1.0)
	_sprite.speed_scale = lerpf(ANIM_MIN_SPEED_SCALE, 1.0, speed_fraction)
	_update_wander_animation(true)
