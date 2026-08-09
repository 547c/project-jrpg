class_name TreasureChest
extends Area2D

# 상호작용형 보물 상자. NPC/캠프파이어(campfire.gd)와 같은 패턴(범위 안에서 [E] 안내 -> 상호작용)을
# 따른다. 한 번 열면 GameState에 "opened_chest_<chest_id>" 플래그를 남겨(기존 몬스터 처치 기록과
# 같은 ad-hoc 플래그 방식) 다시 열 수 없게 막는다.
# 시각적 스프라이트는 없음 — 감지용 CollisionShape2D만 있고, 실제 배치/외형은 맵 제작자가 담당한다

const POPUP_RISE := 26.0
const POPUP_DURATION := 1.0
const POPUP_COLOR := Color(0.95, 0.85, 0.3, 1)

@export var chest_id: String = "" # 저장용 고유 ID (씬 안에서 겹치지 않게 지정)
@export var gold_min: int = 2
@export var gold_max: int = 4

const MARKER_COLOR := Color(0.95, 0.85, 0.3, 0.65) # 보물 느낌의 은은한 금색 (골드 팝업과 톤 맞춤)

@onready var _interact_prompt: Label = $InteractPrompt

var _player_in_range: bool = false
var _presence_marker: Label # 전용 스프라이트가 없어(맵 제작자가 외형을 따로 배치) pulse 전용으로 만든 작은 표식
var _pulse: InteractPulse


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_interact_prompt.hide()
	_create_presence_marker()

	if _is_opened():
		monitoring = false # 이미 열린 상자는 감지 자체를 꺼서 안내가 다시 뜨지 않게 함
		_pulse.stop()
		_presence_marker.hide()


# "여기 뭔가 있다"를 멀리서도 알 수 있도록 항상 보이는 작은 표식 (InteractPrompt와 달리 범위와 무관하게 항상 표시)
func _create_presence_marker() -> void:
	_presence_marker = Label.new()
	_presence_marker.text = "✦"
	_presence_marker.position = Vector2(-8, -26)
	_presence_marker.add_theme_font_size_override("font_size", 16)
	_presence_marker.add_theme_color_override("font_color", MARKER_COLOR)
	_presence_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_presence_marker)
	_pulse = InteractPulse.new(self, _presence_marker)


# 플레이어가 범위에 들어오면(이미 열린 상자가 아닐 때만) "[E] 상자 열기" 안내를 표시하고, pulse를 더 뚜렷하게 바꿈
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _is_opened():
		_player_in_range = true
		_interact_prompt.show()
		_pulse.set_strong(true)


# 플레이어가 범위를 벗어나면 안내를 숨기고, pulse를 다시 은은하게 되돌림
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_interact_prompt.hide()
		if not _is_opened():
			_pulse.set_strong(false)


# 범위 안에서 상호작용 입력이 들어오면 상자를 연다
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_open()


func _flag_name() -> String:
	return "opened_chest_%s" % chest_id


func _is_opened() -> bool:
	return GameState.get_flag(_flag_name())


# 골드를 무작위(gold_min~gold_max)로 획득시키고, 다시 열 수 없도록 플래그를 남긴 뒤
# 획득량을 머리 위 팝업으로 잠깐 보여줌
func _open() -> void:
	if _is_opened():
		return

	var amount := randi_range(gold_min, gold_max)
	GameState.add_gold(amount)
	GameState.set_flag(_flag_name(), true)

	_player_in_range = false
	_interact_prompt.hide()
	monitoring = false
	_pulse.stop()
	_presence_marker.hide()
	_show_popup("골드 %d 발견!" % amount) # "N을/를 발견했다"는 숫자에 따라 조사가 갈려(10,13,16,17,18,20은 을 / 12,14,15,19는 를) 조사 없는 문구로 통일


func _show_popup(text: String) -> void:
	var popup := Label.new()
	popup.text = text
	popup.add_theme_color_override("font_color", POPUP_COLOR)
	popup.add_theme_font_size_override("font_size", 16)
	popup.z_index = 10
	add_child(popup)
	popup.position = Vector2(-40.0, -50.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - POPUP_RISE, POPUP_DURATION)
	tween.tween_property(popup, "modulate:a", 0.0, POPUP_DURATION)
	tween.chain().tween_callback(popup.queue_free)
