class_name MonsterEncounter
extends Area2D

# Idle 시트(BattleData.MONSTERS[type].sprite_path)의 프레임 구성: 32x32 프레임 4개가 가로로 나열됨
const FRAME_SIZE := 32
const FRAME_COUNT := 4
const IDLE_FPS := 4.0

# 몬스터 타입별 화면 표시 배율. 플레이어(64x64 프레임, 1.45배)와 같은 기준으로,
# 각 Idle 프레임 안 캐릭터의 실제 알파 높이를 16px 단위로 측정해 (측정값 * 1.45/1.8)로 계산함
# (플레이어/NPC 스프라이트를 맞출 때 쓴 것과 동일한 방식 — npc/rohan_npc.gd 등 참고)
const DISPLAY_SCALE := {
	"ORC": 1.6111,
	"SKELETON": 1.5104,
}

# 배회: 스폰 지점 기준 이 반경 내에서 천천히 돌아다님
const WANDER_RADIUS_MIN := 40.0
const WANDER_RADIUS_MAX := 60.0
const WANDER_SPEED := 18.0 # px/s (느릿하게)
const WANDER_REPICK_MIN := 2.0 # 새 목표 지점을 고르는 간격(초)
const WANDER_REPICK_MAX := 4.0

# 리젠: 처치 후 이 시간(초) 뒤 같은 자리에 다시 등장
const REGEN_DELAY_MIN := 30.0
const REGEN_DELAY_MAX := 60.0

@export var monster_type: String = "ORC" # BattleData.MONSTERS의 키 ("ORC" 또는 "SKELETON")
@export var encounter_id: String = "" # 조우 식별용 고유 ID (씬 안에서 겹치지 않게 지정)
# 테스트용 리젠 시간 강제 지정 (음수면 REGEN_DELAY_MIN~MAX 사이 랜덤 사용)
@export var regen_delay_override: float = -1.0

var _sprite: AnimatedSprite2D
var _home_position: Vector2 # 스폰(배회 중심) 위치
var _wander_target: Vector2
var _repick_timer: float = 0.0

var _triggered: bool = false # 전투 시작됨 (배회 중지)
var _regenerating: bool = false # 처치 후 재등장 대기 중 (숨김 + 배회 중지)


func _ready() -> void:
	add_to_group("monster_encounters") # 전투 복귀 시 SceneManager가 처치된 몬스터를 찾아 리젠시키기 위함
	_home_position = global_position
	_wander_target = _home_position
	_setup_sprite()
	body_entered.connect(_on_body_entered)


# BattleData의 sprite_path(Idle 시트)를 프레임 단위로 잘라 AnimatedSprite2D를 만들고 재생
func _setup_sprite() -> void:
	var sprite_path: String = BattleData.MONSTERS[monster_type]["sprite_path"]
	var sheet := load(sprite_path) as Texture2D

	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", IDLE_FPS)
	for i in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame("default", atlas)

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "AnimatedSprite2D" # 명시적으로 이름을 지정 (안 하면 @AnimatedSprite2D@... 형태로 자동 생성됨)
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2.ONE * DISPLAY_SCALE.get(monster_type, 1.45)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.play()


# 살아있고 전투/리젠 중이 아닐 때만, 스폰 반경 안에서 목표 지점을 향해 천천히 배회
func _process(delta: float) -> void:
	if _triggered or _regenerating:
		return

	_repick_timer -= delta
	if _repick_timer <= 0.0:
		_pick_new_wander_target()

	global_position = global_position.move_toward(_wander_target, WANDER_SPEED * delta)


# 스폰 지점 기준 반경 내에서 새 배회 목표와 다음 재선정 시각을 무작위로 정함
func _pick_new_wander_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(WANDER_RADIUS_MIN, WANDER_RADIUS_MAX)
	_wander_target = _home_position + Vector2(cos(angle), sin(angle)) * dist
	_repick_timer = randf_range(WANDER_REPICK_MIN, WANDER_REPICK_MAX)


# 플레이어가 닿으면(전투/리젠/전환 중이 아닐 때만) 현재 좌표를 복귀 지점으로 삼아 전용 전투 씬으로 진입
func _on_body_entered(body: Node2D) -> void:
	if _triggered or _regenerating:
		return
	if not body.is_in_group("player"):
		return
	if SceneManager.is_transition_suppressed():
		return

	_triggered = true

	var return_path := ""
	var current := get_tree().current_scene
	if current != null:
		return_path = current.scene_file_path

	SceneManager.enter_battle(monster_type, encounter_id, return_path, SceneManager.get_player_position())


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
	monitoring = false

	var delay: float = regen_delay_override if regen_delay_override >= 0.0 else randf_range(REGEN_DELAY_MIN, REGEN_DELAY_MAX)
	await get_tree().create_timer(delay).timeout

	# 대기 중 씬이 바뀌어 이 노드가 트리에서 빠졌다면 아무것도 하지 않음
	if not is_inside_tree():
		return
	_respawn()


# 스폰 지점에서 다시 살아나 배회를 재개
func _respawn() -> void:
	global_position = _home_position
	_wander_target = _home_position
	_repick_timer = 0.0
	if _sprite != null:
		_sprite.visible = true
	monitoring = true
	_regenerating = false
	_triggered = false
