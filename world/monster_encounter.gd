class_name MonsterEncounter
extends Area2D

# 몬스터 타입별 화면 표시 배율(= Idle 32x32 프레임 기준). 플레이어(64x64 프레임, 1.45배)와 같은 기준으로,
# 각 Idle 프레임 안 캐릭터의 실제 알파 높이를 16px 단위로 측정해 (측정값 * 1.45/1.8)로 계산함
# (플레이어/NPC 스프라이트를 맞출 때 쓴 것과 동일한 방식 — npc/rohan_npc.gd 등 참고).
# Run(64x64)은 캔버스만 더 크지만 캐릭터가 차지하는 실제 픽셀 높이는 Idle과 동일(둘 다 ~32px)하다.
# scale은 원본 픽셀 크기에 곱해지는 값이라, 캐릭터의 실제 픽셀 크기가 같으면 캔버스 크기와 무관하게
# 같은 scale을 쓰는 것이 곧 같은 화면 크기를 보장한다 — 프레임 크기별로 scale을 따로 보정하면 오히려
# 캔버스가 큰 애니메이션(Run)의 캐릭터가 실제보다 작게 표시되는 버그가 된다 (한 번 겪은 실수)
const DISPLAY_SCALE := {
	"ORC": 1.6111,
	"SKELETON": 1.5104,
	"MUMMY": 1.5608, # 미라 Idle 캐릭터 실측 높이(~31px)로 오크/스켈레톤과 같은 방식(높이/16 * 1.45/1.8)으로 산출
	"RUINS_BOSS": 2.81, # 미라(1.5608)의 약 1.8배 — 보스답게 크게 (임시, 전용 에셋 나오면 교체 예정)
}

const IDLE_FPS := 4.0
const RUN_FPS := 8.0

# AnimatedSprite2D는 기본적으로 centered라 캔버스 "중앙"이 노드 위치에 고정된다. 그런데 캐릭터의 발은
# Idle 캔버스든 Run 캔버스든 항상 캔버스 맨 아래 줄에 붙어있어서(실측 확인), 캔버스가 큰 쪽으로 전환되면
# 중앙이 그대로 고정된 채 발만 더 아래로 밀려나 캐릭터가 가라앉아 보이고, 반대로 돌아오면 튀어 오르는 것처럼
# 보인다. offset으로 그 차이(캔버스 높이 차의 절반)만큼 위로 당겨서 두 애니메이션의 발 위치를 맞춘다.
# Idle/Run 프레임 크기는 변종마다 다를 수 있어(미라는 둘 다 64) 스프라이트 구성 시 변종값으로 계산한다

# 배회: 스폰 지점 기준 이 반경 내에서 목표 지점을 향해 이동(Run)했다가, 도착하면 잠시 멈춰 섬(Idle).
# 예전에는 항상 다음 목표를 향해 움직여서 미끄러지듯 보였는데, 이제 Idle 휴식 구간을 둬서 자연스럽게 함
const WANDER_RADIUS_MIN := 40.0
const WANDER_RADIUS_MAX := 60.0
const WANDER_SPEED := 18.0 # px/s (느릿하게)
const IDLE_DURATION_MIN := 1.5 # 목표 도착 후 다음 이동 전까지 가만히 서 있는 시간(초)
const IDLE_DURATION_MAX := 3.0

# 인식/추적: 배회 중 플레이어가 이 반경 안에 들어오면 짧은 "!" 경고(ALERT) 후 추적(CHASE)을 시작한다.
# 추적은 배회보다 훨씬 빠르지만(2.3배), 거리가 벌어지거나 일정 시간이 지나면 포기하고 스폰 지점으로 복귀(RETURN)한다
const ALERT_RADIUS := 130.0
const ALERT_DURATION := 0.5 # "!" 표시 지속 시간(초)
const CHASE_SPEED_MULTIPLIER := 2.3
const CHASE_SPEED := WANDER_SPEED * CHASE_SPEED_MULTIPLIER
const GIVE_UP_DISTANCE := 280.0 # 이 거리 이상 벌어지면 추적 포기
const CHASE_TIMEOUT := 7.0 # 추적 시작 후 이 시간(초)이 지나면 추적 포기

# 경고음 임시 재활용: Typewriter(ui/typewriter.gd)의 bleep 재생 방식과 동일한 자산/피치 가변 방식을 따름.
# 전용 사운드가 생기면 이 상수/함수만 교체하면 된다
const BLEEP_DIR := "res://assets/sfx/dmochas-dialogue_bleeps_pack/ogg/"
const BLEEP_COUNT := 30
const ALERT_SOUND_PITCH := 1.5
const ALERT_SOUND_VOLUME_DB := 5.0 # Typewriter의 bleep 기본 볼륨(0dB)보다 확실히 크게 들리도록

# 리젠: 처치 후 이 시간(초) 뒤 같은 자리에 다시 등장
const REGEN_DELAY_MIN := 30.0
const REGEN_DELAY_MAX := 60.0

enum WanderState { IDLE, MOVING }
enum EncounterState { WANDER, ALERT, CHASE, RETURN }

@export var monster_type: String = "ORC" # BattleData.MONSTERS의 키 ("ORC" / "SKELETON" / "MUMMY" / "RUINS_BOSS")
@export var encounter_id: String = "" # 조우 식별용 고유 ID (씬 안에서 겹치지 않게 지정)
# 테스트용 리젠 시간 강제 지정 (음수면 REGEN_DELAY_MIN~MAX 사이 랜덤 사용)
@export var regen_delay_override: float = -1.0
# 스프라이트에 입힐 색조 (기본 흰색=원본 그대로). 유적 보스처럼 기존 스프라이트를 어둡게/신비롭게 물들일 때 사용
@export var sprite_modulate: Color = Color(1, 1, 1, 1)

var _sprite: AnimatedSprite2D
var _alert_label: Label
var _alert_sound_player: AudioStreamPlayer2D
var _variant: Dictionary = {} # BattleData.pick_variant()가 채운, 이 개체가 표시할 시각 변종
var _run_offset: Vector2 = Vector2.ZERO # 현재 변종의 Idle/Run 캔버스 높이 차 보정값 (스프라이트 구성 시 계산)
var _home_position: Vector2 # 스폰(배회 중심) 위치
var _wander_target: Vector2
var _wander_state: int = WanderState.IDLE
var _idle_timer: float = 0.0

var _state: int = EncounterState.WANDER
var _alert_timer: float = 0.0
var _chase_timer: float = 0.0

var _triggered: bool = false # 전투 시작됨 (배회 중지)
var _regenerating: bool = false # 처치 후 재등장 대기 중 (숨김 + 배회 중지)


func _ready() -> void:
	add_to_group("monster_encounters") # 전투 복귀 시 SceneManager가 처치된 몬스터를 찾아 리젠시키기 위함
	_home_position = global_position
	_wander_target = _home_position
	_pick_variant_and_setup_sprite()
	_create_alert_indicator()
	_create_alert_sound_player()
	_enter_idle_state()
	body_entered.connect(_on_body_entered)


# BattleData에서 이 타입의 변종 하나를 무작위로 골라(시각 다양성 — 스탯은 타입으로 통일 유지),
# Idle/Run 애니메이션을 갖춘 AnimatedSprite2D를 구성한다
func _pick_variant_and_setup_sprite() -> void:
	_variant = BattleData.pick_variant(monster_type)

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var idle_size: int = _variant["idle_frame_size"]
	var run_size: int = _variant["run_frame_size"]
	_add_animation(frames, "idle", _variant["idle_path"], idle_size, idle_size, _variant["idle_frame_count"], IDLE_FPS)
	_add_animation(frames, "run", _variant["run_path"], run_size, run_size, _variant["run_frame_count"], RUN_FPS)
	_run_offset = Vector2(0, -(run_size - idle_size) / 2.0) # 이 변종의 Idle/Run 캔버스 높이 차 보정 (미라는 둘 다 64라 0)

	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "AnimatedSprite2D" # 명시적으로 이름을 지정 (안 하면 @AnimatedSprite2D@... 형태로 자동 생성됨)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.scale = Vector2.ONE * DISPLAY_SCALE.get(monster_type, 1.45)
		_sprite.modulate = sprite_modulate # 보스 등 색조가 지정된 경우 적용 (기본 흰색이면 원본 그대로)
		add_child(_sprite)

	_sprite.sprite_frames = frames


# sheet_path를 frame_w x frame_h 프레임 frame_count개로 잘라 frames에 anim_name 애니메이션(반복 재생)으로 등록
func _add_animation(frames: SpriteFrames, anim_name: String, sheet_path: String, frame_w: int, frame_h: int, frame_count: int, fps: float) -> void:
	var sheet := load(sheet_path) as Texture2D
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)


# 머리 위 "!" 표시. 전용 아이콘 에셋이 없어 우선 Label로 대체 (에셋이 생기면 텍스처로 교체 가능하도록 분리)
func _create_alert_indicator() -> void:
	_alert_label = Label.new()
	_alert_label.text = "!"
	_alert_label.position = Vector2(-8, -60)
	_alert_label.z_index = 10
	_alert_label.add_theme_font_size_override("font_size", 24)
	_alert_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2, 1))
	_alert_label.hide()
	add_child(_alert_label)


func _create_alert_sound_player() -> void:
	_alert_sound_player = AudioStreamPlayer2D.new()
	add_child(_alert_sound_player)


func _enter_idle_state() -> void:
	_wander_state = WanderState.IDLE
	_idle_timer = randf_range(IDLE_DURATION_MIN, IDLE_DURATION_MAX)
	_sprite.offset = Vector2.ZERO
	_sprite.play("idle")


func _enter_moving_state() -> void:
	_pick_new_wander_target()
	_wander_state = WanderState.MOVING
	_sprite.offset = _run_offset
	_sprite.play("run")


# 상태 머신 진입점: WANDER(배회)/ALERT(발견)/CHASE(추적)/RETURN(포기 후 복귀)를 매 프레임 갱신
func _process(delta: float) -> void:
	if _triggered or _regenerating:
		return

	match _state:
		EncounterState.WANDER:
			_process_wander(delta)
			_check_alert_trigger()
		EncounterState.ALERT:
			_process_alert(delta)
		EncounterState.CHASE:
			_process_chase(delta)
		EncounterState.RETURN:
			_process_return(delta)


# 가만히 서 있다가(Idle) 잠시 후 목표 지점으로 이동(Run)하고, 도착하면 다시 Idle로 돌아가는 배회 상태 전환.
# 이동 방향의 좌우 성분으로 flip_h를 갱신해 바라보는 방향에 맞게 뒤집는다
func _process_wander(delta: float) -> void:
	match _wander_state:
		WanderState.IDLE:
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_enter_moving_state()
		WanderState.MOVING:
			var to_target := _wander_target - global_position
			var step_len: float = WANDER_SPEED * delta
			if to_target.length() <= step_len:
				global_position = _wander_target
				_enter_idle_state()
			else:
				var direction := to_target.normalized()
				global_position += direction * step_len
				if absf(direction.x) > 0.01:
					_sprite.flip_h = direction.x < 0.0


# 스폰 지점 기준 반경 내에서 새 배회 목표를 무작위로 정함
func _pick_new_wander_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(WANDER_RADIUS_MIN, WANDER_RADIUS_MAX)
	_wander_target = _home_position + Vector2(cos(angle), sin(angle)) * dist


# "player" 그룹에서 플레이어 노드를 찾아 반환 (없으면 null — 전투/타이틀 화면 등에서는 정상적으로 없을 수 있음)
func _get_player_node() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


# 배회 중 플레이어가 ALERT_RADIUS 안에 들어오면 발견(ALERT) 상태로 전환
func _check_alert_trigger() -> void:
	var player := _get_player_node()
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= ALERT_RADIUS:
		_enter_alert_state()


# 발견 직후: 제자리에 멈춰 "!"를 짧게 띄우고 경고음을 재생
func _enter_alert_state() -> void:
	_state = EncounterState.ALERT
	_alert_timer = ALERT_DURATION
	_sprite.offset = Vector2.ZERO
	_sprite.play("idle")
	_alert_label.show()
	_play_alert_sound()


func _process_alert(delta: float) -> void:
	_alert_timer -= delta
	if _alert_timer <= 0.0:
		_enter_chase_state()


# 기존 Typewriter(ui/typewriter.gd)의 bleep 재생 방식을 임시로 재활용: 무작위 bleep을 높은 피치로 재생.
# 전용 경고음이 생기면 이 함수만 교체하면 됨
func _play_alert_sound() -> void:
	var index := randi() % BLEEP_COUNT + 1
	_alert_sound_player.stream = load("%sbleep%03d.ogg" % [BLEEP_DIR, index])
	_alert_sound_player.pitch_scale = ALERT_SOUND_PITCH
	_alert_sound_player.volume_db = ALERT_SOUND_VOLUME_DB
	_alert_sound_player.play()


# ALERT가 끝나면 추적 시작: "!"를 감추고 배회보다 빠른 속도로 플레이어를 향해 달림
func _enter_chase_state() -> void:
	_state = EncounterState.CHASE
	_chase_timer = 0.0
	_alert_label.hide()
	_sprite.offset = _run_offset
	_sprite.play("run")


# 매 프레임 플레이어 쪽으로 CHASE_SPEED로 이동. 거리가 GIVE_UP_DISTANCE 이상 벌어지거나
# CHASE_TIMEOUT초가 지나면(둘 중 먼저 오는 조건) 추적을 포기하고 복귀(RETURN)한다.
# 플레이어에게 닿으면(부딪히면) 기존과 동일하게 _on_body_entered가 전투를 시작시킨다
func _process_chase(delta: float) -> void:
	_chase_timer += delta

	var player := _get_player_node()
	if player == null:
		_enter_return_state()
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()

	if distance >= GIVE_UP_DISTANCE or _chase_timer >= CHASE_TIMEOUT:
		_enter_return_state()
		return

	if distance > 0.01:
		var direction := to_player.normalized()
		global_position += direction * CHASE_SPEED * delta
		if absf(direction.x) > 0.01:
			_sprite.flip_h = direction.x < 0.0


# 추적 포기: "!"가 혹시 남아있다면 감추고(방어적) 스폰 지점을 향해 이동
func _enter_return_state() -> void:
	_state = EncounterState.RETURN
	_alert_label.hide()
	_sprite.offset = _run_offset
	_sprite.play("run")


# 스폰 지점(_home_position)에 도착하면 다시 배회(WANDER) 상태로 복귀
func _process_return(delta: float) -> void:
	var to_home := _home_position - global_position
	var step_len: float = CHASE_SPEED * delta
	if to_home.length() <= step_len:
		global_position = _home_position
		_enter_wander_state()
	else:
		var direction := to_home.normalized()
		global_position += direction * step_len
		if absf(direction.x) > 0.01:
			_sprite.flip_h = direction.x < 0.0


func _enter_wander_state() -> void:
	_state = EncounterState.WANDER
	_enter_idle_state()


# 플레이어가 닿으면(전투/리젠/전환 중이 아닐 때만) 현재 좌표를 복귀 지점으로 삼아 전용 전투 씬으로 진입.
#
# 이 순간에 이번 전투의 마리 수(1~3, 보스는 항상 1)가 정해진다 — 필드에는 개체 하나만 배회하지만
# 전투에서는 "무리로 덤벼든다"는 설정이라, 필드 스폰과 무관하게 진입 시점에 굴린다.
# 필드에서 본 그 모습이 전투 첫 번째 자리에 그대로 이어지도록 _variant를 첫 변종으로 넘기고,
# 나머지 마리의 변종은 BattleData가 새로 뽑는다
func _on_body_entered(body: Node2D) -> void:
	if _triggered or _regenerating:
		return
	if not body.is_in_group("player"):
		return
	if SceneManager.is_transition_suppressed():
		return

	_triggered = true
	_alert_label.hide()

	var return_path := ""
	var current := get_tree().current_scene
	if current != null:
		return_path = current.scene_file_path

	var variants := BattleData.build_group_variants(monster_type, _variant)
	SceneManager.enter_battle(monster_type, variants, encounter_id, return_path, SceneManager.get_player_position())


# 전투 승리 후 복귀 시 SceneManager가 호출. 이 몬스터를 리젠 상태(숨김 → 일정 시간 후 재등장)로 전환
func enter_regen_state() -> void:
	if _regenerating:
		return
	_begin_regen()


# 처치 후: 스프라이트를 숨기고 감지를 끈 뒤, 일정 시간 후 스폰 지점에서 다시 등장
func _begin_regen() -> void:
	_regenerating = true
	_triggered = false
	if _sprite != null:
		_sprite.visible = false
	_alert_label.hide()
	monitoring = false

	var delay: float = regen_delay_override if regen_delay_override >= 0.0 else randf_range(REGEN_DELAY_MIN, REGEN_DELAY_MAX)
	await get_tree().create_timer(delay).timeout

	# 대기 중 씬이 바뀌어 이 노드가 트리에서 빠졌다면 아무것도 하지 않음
	if not is_inside_tree():
		return
	_respawn()


# 스폰 지점에서 다시 살아나 배회를 재개. 리젠될 때마다 변종을 새로 뽑아 매번 다른 모습으로 등장할 수 있게 함
func _respawn() -> void:
	global_position = _home_position
	_wander_target = _home_position
	if _sprite != null:
		_sprite.visible = true
	monitoring = true
	_regenerating = false
	_triggered = false
	_pick_variant_and_setup_sprite()
	_enter_wander_state()
