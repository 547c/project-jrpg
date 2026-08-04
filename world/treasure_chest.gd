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

@onready var _interact_prompt: Label = $InteractPrompt

var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_interact_prompt.hide()

	if _is_opened():
		monitoring = false # 이미 열린 상자는 감지 자체를 꺼서 안내가 다시 뜨지 않게 함


# 플레이어가 범위에 들어오면(이미 열린 상자가 아닐 때만) "[E] 상자 열기" 안내를 표시
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _is_opened():
		_player_in_range = true
		_interact_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_interact_prompt.hide()


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
