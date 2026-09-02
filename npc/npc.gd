@tool
class_name NPC
extends Area2D

const UiTranslator := preload("res://systems/ui_translator.gd")

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
@export var npc_id: String = "" # 호감도/초상화용 NPC 식별자(예: "elara"). 비워두면 met_flag_name에서 자동 도출("met_elara"->"elara")
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
#
# [@tool과 에디터 가드]
# 서브클래스(elara_npc.gd 등)가 전용 스프라이트를 끼워야 회색 점 대신 실제 그림이 보이는데,
# 그 할당은 서브클래스의 _ready()가 super._ready()를 호출한 "다음" 줄에서 일어난다 — 즉
# 서브클래스도 @tool이어야 하고, 이 base _ready()도 에디터에서 안전하게 끝까지 돌아야 한다.
# 그런데 이 아래 로직(SceneManager 참조, 감지/배회/그림자)은 전부 "게임이 실제로 실행 중"이라는
# 전제 위에 있다 — SceneManager는 오토로드라 에디터에는 아예 노드로 존재하지 않아 그 자리에서
# 바로 에러나고, 배회/애니메이션이 에디터에서까지 돌면 편집 중에 NPC가 제멋대로 움직여 보인다.
# 그래서 에디터에서는 아무것도 하지 않고 바로 리턴 — 스프라이트 표시는 서브클래스가 이 함수
# 호출 여부와 무관하게 직접 처리한다(_play_idle_or_static() 참고)
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 플레이어/나무와 같은 밴드에 서야 Y-Sort 씬(마을)에서 서로 앞뒤가 갈린다.
	# Y-Sort를 안 쓰는 씬에서도 데코 타일에 덮이지 않게 되어 표시가 더 안정적이다
	z_index = SceneManager.CHARACTER_BAND_Z_INDEX
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	UiTranslator.bind(self)
	_interact_prompt.hide()
	_name_label.text = _resolve_display_name()
	_name_label.hide()

	_pulse = InteractPulse.new(self, _sprite)

	_home_position = global_position
	_wander_target = _home_position
	_enter_wander_idle_state()

	# 발밑 그림자는 한 프레임 미뤄서 붙인다 — 서브클래스(elara_npc.gd 등)가 super._ready() 다음
	# 줄에서야 sprite_frames를 채우기 때문에, 여기서 바로 재면 아직 잴 그림이 없다
	_attach_shadow.call_deferred()


# 서브클래스가 전용 sprite_frames를 끼운 뒤 이 함수로 idle을 표시한다. 게임 중에는 평소처럼
# 재생하고, 에디터에서는 애니메이션을 재생하지 않고 idle 첫 프레임만 정지 표시한다 —
# 트리/식생의 흔들림 셰이더와 같은 이유로, "계속 살아 움직이는 미리보기"까지는 필요 없다
func _play_idle_or_static() -> void:
	if not Engine.is_editor_hint():
		_sprite.play("idle")
		return
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("idle"):
		_sprite.animation = "idle"
		_sprite.frame = 0
	_sprite.stop()


# 캐릭터 시트를 재서 발밑 타원 그림자를 만들어 씬의 ShadowLayer에 붙인다
# (그림자 레이어가 없는 씬에서는 아무 일도 일어나지 않는다 — world/character_shadow.gd 참고)
func _attach_shadow() -> void:
	CharacterShadow.attach(self, _sprite)


# dialogue_tree에서 dialogue_start_id에 해당하는 노드의 speaker 필드를 찾아 반환 (없으면 빈 문자열)
func _resolve_display_name() -> String:
	for node in dialogue_tree:
		if node.get("id", "") == dialogue_start_id:
			return tr(node.get("speaker", ""))
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
	if Engine.is_editor_hint():
		return
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# 대화 중이 아닐 때만 배회: 가만히 서 있다가(Idle) 잠시 후 반경 내 무작위 목표로 천천히 이동하고,
# 도착하면 다시 Idle로 돌아간다. 이동 방향의 좌우 성분으로 flip_h를 갱신해 바라보는 방향에 맞게 뒤집는다
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
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


# 씬에서 DialogueBox를 찾아 이 NPC의 대화 트리로 대화를 시작하고, 정상 대화가 열렸을 때만
# 이 NPC를 만났음을 GameState에 기록 (잠금 placeholder만 본 경우는 "만남"으로 치지 않는다)
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	var start_id := _resolve_start_id()
	if met_flag_name != "" and start_id == dialogue_start_id:
		GameState.set_flag(met_flag_name, true)

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_in_dialogue = true
	_update_wander_animation(false) # _process가 멈추는 동안(아래 참고) 재생 중이던 run/walk 루프도 함께 idle로 고정
	_interact_prompt.hide()
	_name_label.hide()
	dialogue_box.start_dialogue(dialogue_tree, start_id, _resolve_npc_id())


# 호감도/초상화용 npc_id를 반환. 명시적으로 지정돼 있으면 그것을, 아니면 met_flag_name에서
# "met_" 접두어를 떼어 도출한다("met_elara" -> "elara" — 호감도 딕셔너리 키와 정확히 일치)
func _resolve_npc_id() -> String:
	if npc_id != "":
		return npc_id
	if met_flag_name.begins_with("met_"):
		return met_flag_name.trim_prefix("met_")
	return ""


# 실제로 시작할 대화 노드 id를 반환. 기본은 dialogue_start_id.
# 서브클래스가 오버라이드해 조건(선행 flag 등)에 따라 placeholder 노드로 게이팅할 수 있음.
# (met_flag_name 자동 기록은 게이팅과 무관하게 위에서 이미 수행되므로 "만났다" 기록은 항상 남음)
func _resolve_start_id() -> String:
	return dialogue_start_id


# 대화가 끝났을 때 배회를 재개하고, 플레이어가 아직 범위 안이면 안내 문구와 이름표를 다시 표시.
# _wander_state 자체는 대화 중에도 안 바뀌었으므로(MOVING이면 그대로 MOVING), 애니메이션을
# 그 상태에 맞춰 다시 맞춰줘야 한다 — 안 그러면 idle로 멈춰 있던 스프라이트가 다음 프레임부터
# 위치만 다시 슬금슬금 움직이는(애니메이션과 실제 이동이 어긋나는) 정반대 문제가 생긴다
func _on_dialogue_ended(_last_node_id: String = "") -> void:
	_in_dialogue = false
	_update_wander_animation(_wander_state == WanderState.MOVING)
	if _player_in_range:
		_interact_prompt.show()
		_name_label.show()
		_name_label.show()
