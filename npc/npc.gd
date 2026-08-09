class_name NPC
extends Area2D

# 배회: monster_encounter.gd의 WANDER 상태(반경 내 랜덤 이동, 저속)를 참고한 훨씬 좁고 느린 버전.
# "서성거림" 정도의 자연스러운 느낌을 위해 몬스터(반경 40~60px, 18px/s)보다 훨씬 좁고 느리게 잡는다.
# 실내 NPC 등은 서브클래스가 _ready()에서 super._ready() 호출 전에 wander_radius_min/max를 덮어써 더 좁힐 수 있다
const WANDER_SPEED := 8.0 # px/s (몬스터의 절반 이하로 느릿하게)
const WANDER_IDLE_DURATION_MIN := 2.0 # 목표 도착 후 다음 이동 전까지 가만히 서 있는 시간(초)
const WANDER_IDLE_DURATION_MAX := 4.0

enum WanderState { IDLE, MOVING }

@export var dialogue_tree: Array = DialogueData.TEST_DIALOGUE.duplicate(true) # 이 NPC가 재생할 대화 트리 (지금은 테스트용 기본값)
@export var dialogue_start_id: String = "start" # 대화를 시작할 노드 id
@export var met_flag_name: String = "" # 대화가 시작되면 true로 설정할 GameState 플래그 이름 (예: "met_elara"), 없으면 ""
@export var wander_radius_min: float = 30.0 # 스폰 위치 기준 배회 반경(최소)
@export var wander_radius_max: float = 40.0 # 스폰 위치 기준 배회 반경(최대)

@onready var _interact_prompt: Label = $InteractPrompt
@onready var _name_label: Label = $NameLabel
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _player_in_range: bool = false # 플레이어가 상호작용 범위 안에 있는지 여부
var _in_dialogue: bool = false # 이 NPC와 대화가 진행 중인지 여부 (배회 정지 조건)

var _home_position: Vector2 # 스폰(배회 중심) 위치
var _wander_target: Vector2
var _wander_state: int = WanderState.IDLE
var _wander_idle_timer: float = 0.0

var _pulse: InteractPulse


# 감지 영역 시그널을 연결하고, 안내 문구/이름표를 초기 상태로 숨김. 이름표는 dialogue_tree에서
# dialogue_start_id 노드의 speaker 값을 읽어와 채움 (게이팅된 placeholder도 같은 speaker를 쓰므로 안전)
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_interact_prompt.hide()
	_name_label.text = _resolve_display_name()
	_name_label.hide()

	_pulse = InteractPulse.new(self, _sprite)

	_home_position = global_position
	_wander_target = _home_position
	_enter_wander_idle_state()


# dialogue_tree에서 dialogue_start_id에 해당하는 노드의 speaker 필드를 찾아 반환 (없으면 빈 문자열)
func _resolve_display_name() -> String:
	for node in dialogue_tree:
		if node.get("id", "") == dialogue_start_id:
			return node.get("speaker", "")
	return ""


# 플레이어가 범위에 들어오면 "말 걸기" 안내와 이름표를 표시하고, pulse를 더 뚜렷하게 바꿈
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_interact_prompt.show()
		_name_label.show()
		_pulse.set_strong(true)


# 플레이어가 범위를 벗어나면 안내와 이름표를 숨기고, pulse를 다시 은은하게 되돌림
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_interact_prompt.hide()
		_name_label.hide()
		_pulse.set_strong(false)


# 범위 안에서 상호작용 입력이 들어오면 대화를 시작
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# 대화 중이 아닐 때만 배회: 가만히 서 있다가(Idle) 잠시 후 반경 내 무작위 목표로 천천히 이동하고,
# 도착하면 다시 Idle로 돌아간다. 이동 방향의 좌우 성분으로 flip_h를 갱신해 바라보는 방향에 맞게 뒤집는다
func _process(delta: float) -> void:
	if _in_dialogue:
		return

	match _wander_state:
		WanderState.IDLE:
			_wander_idle_timer -= delta
			if _wander_idle_timer <= 0.0:
				_enter_wander_moving_state()
		WanderState.MOVING:
			var to_target := _wander_target - global_position
			var step_len: float = WANDER_SPEED * delta
			if to_target.length() <= step_len:
				global_position = _wander_target
				_enter_wander_idle_state()
			else:
				var direction := to_target.normalized()
				global_position += direction * step_len
				if absf(direction.x) > 0.01:
					_sprite.flip_h = direction.x < 0.0


func _enter_wander_idle_state() -> void:
	_wander_state = WanderState.IDLE
	_wander_idle_timer = randf_range(WANDER_IDLE_DURATION_MIN, WANDER_IDLE_DURATION_MAX)
	_update_wander_animation(false)


func _enter_wander_moving_state() -> void:
	_pick_new_wander_target()
	_wander_state = WanderState.MOVING
	_update_wander_animation(true)


# 이동 중이면 이동 애니메이션(run 우선, 없으면 walk)으로, 정지 중이면 idle로 전환.
# 캐릭터마다 실제로 갖고 있는 애니메이션이 달라(엘라라/로한/유서프는 run만, 미아는 walk만 있음)
# 우선순위대로 있는 것을 골라 쓰고, 둘 다 없으면 조용히 건너뛰어 기존처럼 idle을 유지한다
func _update_wander_animation(moving: bool) -> void:
	var frames := _sprite.sprite_frames
	if frames == null:
		return

	var move_anim := ""
	if moving:
		if frames.has_animation("run"):
			move_anim = "run"
		elif frames.has_animation("walk"):
			move_anim = "walk"

	if move_anim == "":
		_sprite.offset = Vector2.ZERO
		if frames.has_animation("idle"):
			_sprite.play("idle")
		return

	_sprite.offset = _compute_move_offset(frames, move_anim)
	_sprite.play(move_anim)


# idle과 이동 애니메이션의 캔버스 크기가 다를 수 있다(예: Idle 32px 캔버스 / Run 64px 캔버스 —
# monster_encounter.gd의 RUN_OFFSET과 같은 상황). 그 차이의 절반만큼 위로 당겨 보정해야
# 캔버스가 큰 애니메이션으로 전환될 때 발 위치가 아래로 가라앉아 보이지 않는다.
# 두 애니메이션의 캔버스 크기가 같으면(예: 미아의 idle/walk 둘 다 64px) 자동으로 0이 된다
func _compute_move_offset(frames: SpriteFrames, move_anim: String) -> Vector2:
	if not frames.has_animation("idle") or frames.get_frame_count("idle") == 0 or frames.get_frame_count(move_anim) == 0:
		return Vector2.ZERO
	var idle_size := frames.get_frame_texture("idle", 0).get_size()
	var move_size := frames.get_frame_texture(move_anim, 0).get_size()
	return Vector2(0, -(move_size.y - idle_size.y) / 2.0)


# 스폰 지점 기준 반경 내에서 새 배회 목표를 무작위로 정함
func _pick_new_wander_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(wander_radius_min, wander_radius_max)
	_wander_target = _home_position + Vector2(cos(angle), sin(angle)) * dist


# 씬에서 DialogueBox를 찾아 이 NPC의 대화 트리로 대화를 시작하고, 이 NPC를 만났음을 GameState에 기록
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if met_flag_name != "":
		GameState.set_flag(met_flag_name, true)

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_in_dialogue = true
	_interact_prompt.hide()
	_name_label.hide()
	dialogue_box.start_dialogue(dialogue_tree, _resolve_start_id())


# 실제로 시작할 대화 노드 id를 반환. 기본은 dialogue_start_id.
# 서브클래스가 오버라이드해 조건(선행 flag 등)에 따라 placeholder 노드로 게이팅할 수 있음.
# (met_flag_name 자동 기록은 게이팅과 무관하게 위에서 이미 수행되므로 "만났다" 기록은 항상 남음)
func _resolve_start_id() -> String:
	return dialogue_start_id


# 대화가 끝났을 때 배회를 재개하고, 플레이어가 아직 범위 안이면 안내 문구와 이름표를 다시 표시
func _on_dialogue_ended() -> void:
	_in_dialogue = false
	if _player_in_range:
		_interact_prompt.show()
		_name_label.show()
