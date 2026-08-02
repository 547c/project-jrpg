class_name BattleBox
extends Control

# 전투가 끝났을 때 발행. victory는 몬스터를 물리쳤는지(true) 정신을 잃었는지(false)
signal battle_ended(victory: bool)

const HP_TWEEN_DURATION := 0.4
const DAMAGE_POPUP_RISE := 30.0
const DAMAGE_POPUP_DURATION := 0.8
const DAMAGE_POPUP_COLOR := Color(0.85, 0.1, 0.1, 1)
const SHAKE_AMOUNT := 6.0
const SHAKE_STEP_DURATION := 0.05
const SHAKE_STEPS := 3
const LUNGE_DISTANCE := 20.0
const LUNGE_OUT_DURATION := 0.08
const LUNGE_BACK_DURATION := 0.12

@onready var _monster_label: Label = $MonsterCard/VBox/MonsterLabel
@onready var _monster_hp_bar: ProgressBar = $MonsterCard/VBox/MonsterHPBar
@onready var _player_label: Label = $PlayerCard/VBox/PlayerLabel
@onready var _player_hp_bar: ProgressBar = $PlayerCard/VBox/PlayerHPBar
@onready var _result_label: Label = $BottomBar/HBox/ResultLabel
@onready var _attack_button: Button = $BottomBar/HBox/AttackButton

var _monster_type: String = ""
var _monster_data: Dictionary = {}
var _monster_hp: int = 0
var _monster_sprite: Node2D = null
var _player_node: Node2D = null
var _battle_over: bool = false
var _victory: bool = false


func _ready() -> void:
	add_to_group("battle_box")
	_attack_button.pressed.connect(_on_attack_button_pressed)


# 지정한 몬스터 타입("ORC"/"SKELETON")으로 전투를 시작. monster_sprite는 찌르기 모션을 재생할
# 실제 월드의 AnimatedSprite2D (없으면 그 연출만 생략됨)
func start_battle(monster_type: String, monster_sprite: Node2D = null) -> void:
	_monster_type = monster_type
	_monster_data = BattleData.MONSTERS[monster_type]
	_monster_hp = _monster_data["max_hp"]
	_monster_sprite = monster_sprite
	_player_node = get_tree().get_first_node_in_group("player")
	_battle_over = false
	_victory = false

	_attack_button.text = "공격"
	_result_label.text = ""

	_monster_hp_bar.max_value = _monster_data["max_hp"]
	_monster_hp_bar.value = _monster_hp
	_player_hp_bar.max_value = GameState.get_flag("player_max_hp")
	_player_hp_bar.value = GameState.get_flag("player_hp")

	_update_labels()
	show()


# 버튼 클릭 처리: 전투가 끝난 상태면 창을 닫고, 아니면 한 턴(공격 주고받기)을 진행
func _on_attack_button_pressed() -> void:
	if _battle_over:
		_close_battle()
	else:
		_run_turn()


# 플레이어가 먼저 공격하고, 몬스터가 살아있으면 몬스터도 반격하는 한 턴을 처리
func _run_turn() -> void:
	_shake_camera()
	_lunge_toward(_player_node, _monster_sprite)

	var player_damage := randi_range(BattleData.PLAYER_ATTACK_DAMAGE_MIN, BattleData.PLAYER_ATTACK_DAMAGE_MAX)
	_monster_hp = max(0, _monster_hp - player_damage)
	_show_damage_popup(_monster_hp_bar, player_damage)
	_animate_hp_bar(_monster_hp_bar, _monster_hp)
	var result_text := "플레이어가 %s에게 %d의 피해를 입혔다!" % [_monster_data["name"], player_damage]

	if _monster_hp <= 0:
		result_text += "\n전투 종료 - %s를 물리쳤다!" % _monster_data["name"]
		_finish_battle(result_text, true)
		return

	var monster_damage: int = _monster_data["damage"]
	_lunge_toward(_monster_sprite, _player_node)
	GameState.damage_player(monster_damage)
	_show_damage_popup(_player_hp_bar, monster_damage)
	_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
	result_text += "\n%s%s 플레이어에게 %d의 피해를 입혔다!" % [_monster_data["name"], _subject_particle(_monster_data["name"]), monster_damage]

	if GameState.get_flag("player_hp") <= 0:
		result_text += "\n정신을 잃었다..."
		_finish_battle(result_text, false)
		return

	_update_labels()
	_result_label.text = result_text


# 승리 시: 처치 카운트를 올리고 버튼을 "닫기"로 바꿔 결과 확인 시간을 준다.
# 패배 시: 전투창을 닫고 게임오버 화면으로 넘긴다 (회복/마을 이동 등 실제 페널티 처리는 게임오버 화면이 담당)
func _finish_battle(result_text: String, victory: bool) -> void:
	if not victory:
		hide()
		GameOverScreen.show_game_over()
		return

	match _monster_type:
		"ORC":
			GameState.increment_orcs_defeated()
		"SKELETON":
			GameState.increment_skeletons_defeated()

	_victory = true
	_battle_over = true
	_attack_button.text = "닫기"

	_update_labels()
	_result_label.text = result_text


# 몬스터/플레이어 HP 표시를 갱신 (숫자 텍스트 - 바 자체 값은 _animate_hp_bar가 트윈으로 따로 갱신)
func _update_labels() -> void:
	_monster_label.text = "%s %d/%d" % [_monster_data["name"], _monster_hp, _monster_data["max_hp"]]
	_player_label.text = "플레이어 %d/%d" % [GameState.get_flag("player_hp"), GameState.get_flag("player_max_hp")]


# HP바 값을 즉시 바꾸지 않고 목표값까지 부드럽게 줄어들도록(또는 늘어나도록) 트윈
func _animate_hp_bar(bar: ProgressBar, target_value: float) -> void:
	var tween := create_tween()
	tween.tween_property(bar, "value", target_value, HP_TWEEN_DURATION)


# 맞은 대상의 HP바 위에 "-N" 텍스트를 잠깐 띄웠다가 위로 떠오르며 사라지게 함
func _show_damage_popup(anchor: Control, amount: int) -> void:
	var popup := Label.new()
	popup.text = "-%d" % amount
	popup.add_theme_color_override("font_color", DAMAGE_POPUP_COLOR)
	popup.z_index = 10
	add_child(popup)
	popup.global_position = anchor.get_global_rect().position + Vector2(anchor.size.x * 0.5 - 10.0, -22.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "global_position:y", popup.global_position.y - DAMAGE_POPUP_RISE, DAMAGE_POPUP_DURATION)
	tween.tween_property(popup, "modulate:a", 0.0, DAMAGE_POPUP_DURATION)
	tween.chain().tween_callback(popup.queue_free)


# 현재 뷰포트의 카메라를 짧게 좌우로 흔들었다가 원위치로 되돌림 (공격 명중 시 타격감용, 과하지 않게)
func _shake_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var tween := create_tween()
	for i in range(SHAKE_STEPS):
		var offset := Vector2(randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT), randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT))
		tween.tween_property(camera, "offset", offset, SHAKE_STEP_DURATION)
	tween.tween_property(camera, "offset", Vector2.ZERO, SHAKE_STEP_DURATION)


# 공격하는 쪽의 스프라이트를 상대방 방향으로 짧게 튀어나갔다 원위치로 돌아오는 "찌르기" 모션으로 움직임
func _lunge_toward(attacker: Node2D, target: Node2D) -> void:
	if attacker == null:
		return

	var direction := Vector2.RIGHT
	if target != null:
		var delta := target.global_position - attacker.global_position
		if delta.length() > 0.001:
			direction = delta.normalized()

	var original_position := attacker.position
	var tween := create_tween()
	tween.tween_property(attacker, "position", original_position + direction * LUNGE_DISTANCE, LUNGE_OUT_DURATION)
	tween.tween_property(attacker, "position", original_position, LUNGE_BACK_DURATION)


# 전투창을 숨기고 종료를 알림 (승리 시 "닫기"에서만 호출됨 — 패배는 게임오버 화면으로 분기됨)
func _close_battle() -> void:
	hide()
	battle_ended.emit(_victory)


# 한글 이름 뒤에 붙일 주격 조사("이"/"가")를 마지막 글자의 받침 유무로 판단
func _subject_particle(monster_name: String) -> String:
	if monster_name.is_empty():
		return "가"
	var last_char := monster_name.unicode_at(monster_name.length() - 1)
	if last_char >= 0xAC00 and last_char <= 0xD7A3 and (last_char - 0xAC00) % 28 != 0:
		return "이"
	return "가"
