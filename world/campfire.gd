class_name Campfire
extends Area2D

const UiTranslator := preload("res://systems/ui_translator.gd")

# NPC(npc.gd)와 동일한 상호작용 패턴: 범위 안에서 [E]를 누르면 DialogueBox로 쉬어갈지 묻는다.
# "예"를 끝까지 확인(닫기)하면 체력을 모두 회복한다.

const REST_DIALOGUE: Array = [
	{
		"id": "campfire_ask",
		"speaker": "",
		"narration": "모닥불이 따뜻하게 타오르고 있다.",
		"text": "잠시 쉬어가시겠습니까?",
		"is_decisive": false,
		"options": [
			{"label": "예", "next_id": "campfire_rest"},
			{"label": "아니요", "next_id": ""},
		],
	},
	{
		"id": "campfire_rest",
		"speaker": "",
		"text": "체력을 모두 회복했다.",
		"is_decisive": false,
		"options": [],
	},
]

const HEAL_VFX_PATH := "res://assets/vfx/Free/Part 10/475.png"
const HEAL_VFX_ROW := 3
const HEAL_VFX_FRAME_COUNT := 12
const HEAL_VFX_FPS := 26.0
const HEAL_VFX_FRAME_SIZE := 64
const HEAL_VFX_SCALE := 0.9
const HEAL_SFX := "res://assets/sfx/400 Sounds pack/Musical Effects/vibraphone_chime_positive.wav"

@onready var _interact_prompt: Label = $InteractPrompt
@onready var _sprite: Sprite2D = $Sprite2D

var _player_in_range: bool = false
var _player_body: Node2D
var _pulse: InteractPulse
var _heal_vfx_frames: SpriteFrames


# 감지 영역 시그널을 연결하고 안내 문구를 초기 상태로 숨김
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	UiTranslator.bind(self)
	_interact_prompt.hide()
	_pulse = InteractPulse.new(self, _sprite)
	_heal_vfx_frames = _build_heal_vfx_frames()


# 전투의 힐 스킬(VFX_CONFIG["heal"])과 같은 시트/행에서 프레임을 그대로 가져와 재사용
func _build_heal_vfx_frames() -> SpriteFrames:
	var sheet := load(HEAL_VFX_PATH) as Texture2D
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("play")
	frames.set_animation_speed("play", HEAL_VFX_FPS)
	frames.set_animation_loop("play", false)
	for i in range(HEAL_VFX_FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * HEAL_VFX_FRAME_SIZE, HEAL_VFX_ROW * HEAL_VFX_FRAME_SIZE, HEAL_VFX_FRAME_SIZE, HEAL_VFX_FRAME_SIZE)
		frames.add_frame("play", atlas)
	return frames


func _play_heal_effect() -> void:
	if _player_body == null:
		return
	SFXPlayer.play(HEAL_SFX)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _heal_vfx_frames
	sprite.position = _player_body.global_position + Vector2(0, -16)
	sprite.scale = Vector2.ONE * HEAL_VFX_SCALE
	sprite.z_index = 10
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_tree().current_scene.add_child(sprite)
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play("play")


# 플레이어가 범위에 들어오면 "쉬어가기" 안내를 표시하고, pulse를 더 뚜렷하게 바꿈
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_player_body = body
		_interact_prompt.show()
		_pulse.set_strong(true)


# 플레이어가 범위를 벗어나면 안내를 숨기고, pulse를 다시 은은하게 되돌림
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_player_body = null
		_interact_prompt.hide()
		_pulse.set_strong(false)


# 범위 안에서 상호작용 입력이 들어오면 대화를 시작
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# 씬에서 DialogueBox를 찾아 쉬어가기 대화를 시작
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_interact_prompt.hide()
	dialogue_box.start_dialogue(REST_DIALOGUE, "campfire_ask")


# 대화가 "체력을 모두 회복했다" 노드에서 끝났을 때만(= "예"를 선택하고 닫기까지 확인) 실제로 회복시킴
func _on_dialogue_ended(last_node_id: String) -> void:
	if last_node_id == "campfire_rest":
		GameState.heal_player_full()
		_play_heal_effect()

	if _player_in_range:
		_interact_prompt.show()
