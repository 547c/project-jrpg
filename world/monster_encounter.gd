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

@export var monster_type: String = "ORC" # BattleData.MONSTERS의 키 ("ORC" 또는 "SKELETON")
@export var encounter_id: String = "" # 같은 몬스터 재조우 방지용 고유 ID (씬 안에서 겹치지 않게 지정)

var _triggered: bool = false
var _sprite: AnimatedSprite2D


# 이미 처치한 조우라면(GameState에 기록되어 있으면) 아예 생성되지 않고 스스로 제거
func _ready() -> void:
	if GameState.get_flag(_defeated_flag_name()):
		queue_free()
		return

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


# 플레이어가 닿으면(1회 제한) BattleBox를 찾아 전투를 시작
func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return

	_triggered = true

	var battle_box := get_tree().get_first_node_in_group("battle_box") as BattleBox
	if battle_box == null:
		return

	if not battle_box.battle_ended.is_connected(_on_battle_ended):
		battle_box.battle_ended.connect(_on_battle_ended, CONNECT_ONE_SHOT)

	battle_box.start_battle(monster_type, _sprite)


# 승리했다면 처치 기록을 남기고 스스로 제거, 패배(정신을 잃음)했다면 다시 조우할 수 있게 둠
func _on_battle_ended(victory: bool) -> void:
	if victory:
		GameState.set_flag(_defeated_flag_name(), true)
		queue_free()
	else:
		_triggered = false


func _defeated_flag_name() -> String:
	return "defeated_%s" % encounter_id
