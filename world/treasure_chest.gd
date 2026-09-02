class_name TreasureChest
extends Area2D

const UiTranslator := preload("res://systems/ui_translator.gd")

# 상호작용형 보물 상자. NPC/캠프파이어(campfire.gd)와 같은 패턴(범위 안에서 [E] 안내 -> 상호작용)을
# 따른다. 한 번 열면 GameState에 "opened_chest_<chest_id>" 플래그를 남겨(기존 몬스터 처치 기록과
# 같은 ad-hoc 플래그 방식) 다시 열 수 없게 막는다.
# 시각적 스프라이트는 없음 — 감지용 CollisionShape2D만 있고, 실제 배치/외형은 맵 제작자가 담당한다

const POPUP_RISE := 26.0
const POPUP_DURATION := 1.0
const POPUP_COLOR := Color(0.95, 0.85, 0.3, 1)
const OPEN_SOUND := "res://assets/sfx/400 Sounds pack/Materials/ceramic_jar_open.wav"

@export var chest_id: String = "" # 저장용 고유 ID (씬 안에서 겹치지 않게 지정)
@export var gold_min: int = 2
@export var gold_max: int = 4
# 아래 3개가 지정되면 "골드 상자"가 아니라 "퀘스트/보상 상자"로 동작한다 (일반화):
# - quest_id: 열었을 때 골드 대신 이 퀘스트를 즉시 완료 처리 (GameState.complete_quest)
# - reward_item: 열었을 때 인벤토리에 지급할 아이템 id (열쇠 등). quest_id 없이 단독으로도 사용 가능
# - popup_text: 머리 위에 띄울 안내 문구 (미지정 시 골드/보상에 맞춰 기본 문구 사용)
@export var quest_id: String = ""
@export var reward_item: String = ""
@export var popup_text: String = ""

# drop_equipment를 켜면 "장비 확률 드롭" 모드가 된다 (quest_id/reward_item이 지정된 상자에는 적용되지 않음).
# EQUIPMENT_DROP_CHANCE 확률로 max_equipment_tier 이하의 장비 하나를 주고, 빗나가면(꽝) 기존처럼 골드를 준다.
# max_equipment_tier는 그 상자가 놓인 지역의 등급 상한이다 — 마을 상자에서 금장비가 나오지 않도록,
# 그 지역에 사는 몬스터의 등급과 같은 기준으로 맞춘다 (마을·숲=나무, 동굴=뼈, 사막·유적=금)
@export var drop_equipment: bool = false
@export_enum("wood", "bone", "gold") var max_equipment_tier: String = "wood"

# 상자는 한 번만 열 수 있어(opened_chest_<id> 플래그) 몬스터처럼 반복해서 캘 수 없다.
# 그래서 몬스터 드롭(15%)보다 훨씬 후하게 잡아, 상자를 여는 순간이 확실한 보상 기회가 되게 한다.
# 대신 절반은 꽝이라 매번 장비가 나오진 않고, 꽝이어도 원래의 골드 보상은 그대로 받는다
const EQUIPMENT_DROP_CHANCE := 0.5

const MARKER_COLOR := Color(0.95, 0.85, 0.3, 0.65) # 보물 느낌의 은은한 금색 (골드 팝업과 톤 맞춤)

@onready var _interact_prompt: Label = $InteractPrompt

var _player_in_range: bool = false
var _presence_marker: Label # 전용 스프라이트가 없어(맵 제작자가 외형을 따로 배치) pulse 전용으로 만든 작은 표식
var _pulse: InteractPulse


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	UiTranslator.bind(self)
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


# 상자를 열어 보상을 지급하고(퀘스트/아이템 상자면 그쪽, 아니면 골드), 다시 열 수 없도록 플래그를 남긴 뒤
# 결과를 머리 위 팝업으로 잠깐 보여줌
func _open() -> void:
	if _is_opened():
		return

	SFXPlayer.play(OPEN_SOUND)
	GameState.set_flag(_flag_name(), true)
	var default_popup := _grant_reward()

	_player_in_range = false
	_interact_prompt.hide()
	monitoring = false
	_pulse.stop()
	_presence_marker.hide()
	_show_popup(tr(popup_text) if popup_text != "" else default_popup)


# quest_id/reward_item이 지정되면 퀘스트 완료·아이템 지급을, 아니면 기존처럼 골드를 지급한다.
# 반환값은 popup_text가 비었을 때 쓸 기본 팝업 문구
func _grant_reward() -> String:
	if quest_id != "" or reward_item != "":
		if quest_id != "":
			GameState.complete_quest(quest_id)
		if reward_item != "":
			GameState.add_item(reward_item, 1)
		return tr("무언가를 발견했다!")

	# 장비 상자: 확률에 당첨되면 지역 상한 이하의 장비 하나를 준다.
	# 빗나가면 아래 골드 지급으로 그대로 흘러가므로 "꽝이어도 빈손은 아닌" 구조가 된다
	if drop_equipment:
		var dropped := _roll_equipment()
		if dropped != "":
			GameState.add_item(dropped, 1)
			return tr("%s 발견!") % tr(ItemData.ITEMS[dropped]["name"])

	var amount := randi_range(gold_min, gold_max)
	GameState.add_gold(amount)
	return tr("골드 %d 발견!") % amount # "N을/를 발견했다"는 숫자에 따라 조사가 갈려(10,13,16,17,18,20은 을 / 12,14,15,19는 를) 조사 없는 문구로 통일


# 장비 드롭을 굴린다. 꽝이거나 뽑을 후보가 없으면 빈 문자열
func _roll_equipment() -> String:
	if randf() >= EQUIPMENT_DROP_CHANCE:
		return ""
	return ItemData.pick_random_equipment_up_to(max_equipment_tier)


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
