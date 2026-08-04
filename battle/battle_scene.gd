class_name BattleScene
extends Node2D

# 몬스터 조우 시 SceneManager가 전환해 들어오는 전용 전투 씬 (포켓몬 스타일 구도).
# 왼쪽 아래 = 플레이어(뒷모습), 오른쪽 위 = 몬스터. 자체 스프라이트로 공격/피격 연출을 재생하고,
# 턴 로직(공격/스킬/마나)을 처리한다. 승리 시 SceneManager.return_from_battle()로 원래 좌표에 복귀,
# 패배 시 GameOverScreen으로 넘긴다. HUD/일시정지 억제를 위해 "battle_box" 그룹에 등록한다.

const PLAYER_SPRITE_PATH := "res://assets/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Idle_Base/Idle_Up-Sheet.png"
const PLAYER_FRAME_SIZE := 64
const FRAME_COUNT := 4
const IDLE_FPS := 4.0

const MONSTER_IDLE_FPS := 4.0
const MONSTER_DEATH_FPS := 8.0

# 카드 초상화용 얼굴 크롭 (Idle_Down-Sheet.png 기준 — 전투 중 실제로 보여주는 Idle_Up과는 다른 시트지만
# HUD 카드와 동일한 얼굴 그래픽을 쓰기 위해 정면 얼굴이 나온 Idle_Down에서 잘라온다)
const PLAYER_PORTRAIT_SHEET_PATH := "res://assets/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Idle_Base/Idle_Down-Sheet.png"
const PLAYER_PORTRAIT_REGION := Rect2(23, 16, 18, 17)

const PLAYER_SCALE := 2.4
const MONSTER_SCALE := 3.2

const HP_TWEEN_DURATION := 0.4
const DAMAGE_POPUP_RISE := 34.0
const DAMAGE_POPUP_DURATION := 0.85
const DAMAGE_POPUP_FONT_SIZE := 30
const DAMAGE_COLOR := Color(0.95, 0.2, 0.15, 1)
const HEAL_COLOR := Color(0.25, 0.85, 0.35, 1)
const DODGE_COLOR := Color(0.5, 0.85, 1.0, 1)
const HIT_TINT := Color(1.0, 0.35, 0.35, 1)
const HIT_TINT_DURATION := 0.12
const SHAKE_AMOUNT := 7.0
const SHAKE_STEP_DURATION := 0.05
const SHAKE_STEPS := 3
const LUNGE_DISTANCE := 26.0
const LUNGE_OUT_DURATION := 0.08
const LUNGE_BACK_DURATION := 0.12
const VICTORY_HEAL_FRACTION := 0.25
const FLEE_HP_THRESHOLD := 0.5 # 최대 HP의 이 비율 이상일 때만 도망 가능

# 턴 진행 상태: ACTION=행동 선택, SKILL=스킬 선택, BUSY=연출 재생 중(입력 무시), OVER=전투 종료
enum Mode { ACTION, SKILL, BUSY, OVER }

@onready var _actors: Node2D = $View/Actors
@onready var _player_sprite: AnimatedSprite2D = $View/Actors/PlayerSprite
@onready var _monster_sprite: AnimatedSprite2D = $View/Actors/MonsterSprite
@onready var _player_shadow: Polygon2D = $View/PlayerShadow
@onready var _monster_shadow: Polygon2D = $View/MonsterShadow
@onready var _hud: Control = $View/HUD
@onready var _player_portrait: TextureRect = $View/HUD/PlayerCard/Portrait
@onready var _player_hp_bar: ProgressBar = $View/HUD/PlayerCard/HPBar
@onready var _player_hp_bar_label: Label = $View/HUD/PlayerCard/HPBarLabel
@onready var _player_mana_bar: ProgressBar = $View/HUD/PlayerCard/ManaBar
@onready var _player_mana_bar_label: Label = $View/HUD/PlayerCard/ManaBarLabel
@onready var _player_gold_label: Label = $View/HUD/PlayerCard/GoldLabel
@onready var _monster_portrait: TextureRect = $View/HUD/MonsterCard/Portrait
@onready var _monster_hp_bar: ProgressBar = $View/HUD/MonsterCard/HPBar
@onready var _monster_hp_bar_label: Label = $View/HUD/MonsterCard/HPBarLabel
@onready var _monster_gold_label: Label = $View/HUD/MonsterCard/GoldLabel
@onready var _message: Label = $View/HUD/BottomBar/HBox/MessageLabel
@onready var _action_row: HBoxContainer = $View/HUD/BottomBar/HBox/Menus/ActionRow
@onready var _skill_row: GridContainer = $View/HUD/BottomBar/HBox/Menus/SkillRow
@onready var _attack_button: Button = $View/HUD/BottomBar/HBox/Menus/ActionRow/AttackButton
@onready var _skill_button: Button = $View/HUD/BottomBar/HBox/Menus/ActionRow/SkillButton
@onready var _flee_button: Button = $View/HUD/BottomBar/HBox/Menus/ActionRow/FleeButton
@onready var _strike_button: Button = $View/HUD/BottomBar/HBox/Menus/SkillRow/StrikeButton
@onready var _heal_button: Button = $View/HUD/BottomBar/HBox/Menus/SkillRow/HealButton
@onready var _dodge_button: Button = $View/HUD/BottomBar/HBox/Menus/SkillRow/DodgeButton
@onready var _back_button: Button = $View/HUD/BottomBar/HBox/Menus/SkillRow/BackButton
@onready var _close_button: Button = $View/HUD/BottomBar/HBox/Menus/CloseButton

var _monster_type: String = ""
var _monster_data: Dictionary = {}
var _variant: Dictionary = {} # 필드 MonsterEncounter가 뽑은 시각 변종 (SceneManager가 그대로 전달)
var _monster_hp: int = 0
var _mode: int = Mode.BUSY
var _dodging: bool = false


func _ready() -> void:
	add_to_group("battle_box")

	_attack_button.pressed.connect(_on_attack_pressed)
	_skill_button.pressed.connect(_open_skill_menu)
	_flee_button.pressed.connect(_on_flee_pressed)
	_strike_button.pressed.connect(_on_skill_pressed.bind("STRIKE"))
	_heal_button.pressed.connect(_on_skill_pressed.bind("HEAL"))
	_dodge_button.pressed.connect(_on_skill_pressed.bind("DODGE"))
	_back_button.pressed.connect(_close_skill_menu)
	_close_button.pressed.connect(_on_close_pressed)


# SceneManager가 전투 씬을 트리에 넣은 직후 호출. 몬스터 종류/시각 변종(필드에서 뽑힌 것과 동일)을
# 받아 스프라이트/구도/HP·마나를 세팅하고 행동 선택 상태로 진입한다
func start_with(monster_type: String, variant: Dictionary) -> void:
	_monster_type = monster_type
	_monster_data = BattleData.MONSTERS[monster_type]
	_variant = variant
	_monster_hp = _monster_data["max_hp"]

	MusicManager.play("Battle 1")

	_setup_sprites()
	_layout_actors()

	_monster_hp_bar.max_value = _monster_data["max_hp"]
	_monster_hp_bar.value = _monster_hp
	_player_hp_bar.max_value = GameState.get_flag("player_max_hp")
	_player_hp_bar.value = GameState.get_flag("player_hp")
	_update_player_hp_text()
	_update_monster_hp_text()

	_player_gold_label.text = str(GameState.gold)
	_monster_gold_label.text = "%d~%d" % [_monster_data["gold_min"], _monster_data["gold_max"]]

	_refresh_battle_hud()
	_message.text = "%s 출현!" % _monster_data["name"]

	_close_button.visible = false
	_skill_row.visible = false
	_action_row.visible = true
	_mode = Mode.ACTION


# 플레이어(뒷모습=Idle_Up)는 정적 Idle 프레임을, 몬스터는 "idle"/"death" 두 애니메이션을 갖춘
# SpriteFrames를 필드와 같은 변종(_variant)의 시트에서 구성해 AnimatedSprite2D에 채우고,
# 카드에 쓸 초상화(얼굴만 크롭한 AtlasTexture)도 함께 준비한다
func _setup_sprites() -> void:
	_player_sprite.sprite_frames = _build_frames(load(PLAYER_SPRITE_PATH) as Texture2D, PLAYER_FRAME_SIZE)
	_player_sprite.scale = Vector2.ONE * PLAYER_SCALE
	_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_sprite.play("default")
	_player_portrait.texture = _build_portrait(load(PLAYER_PORTRAIT_SHEET_PATH) as Texture2D, PLAYER_PORTRAIT_REGION)

	var idle_sheet := load(_variant["idle_path"]) as Texture2D

	var monster_frames := SpriteFrames.new()
	if monster_frames.has_animation("default"):
		monster_frames.remove_animation("default")
	_add_monster_animation(monster_frames, "idle", idle_sheet, BattleData.MOB_IDLE_FRAME_SIZE, BattleData.MOB_IDLE_FRAME_SIZE, BattleData.MOB_IDLE_FRAME_COUNT, MONSTER_IDLE_FPS, true)
	_add_monster_animation(monster_frames, "death", load(_variant["death_path"]) as Texture2D, _variant["death_frame_width"], _variant["death_frame_height"], _variant["death_frame_count"], MONSTER_DEATH_FPS, false)

	_monster_sprite.sprite_frames = monster_frames
	_monster_sprite.scale = Vector2.ONE * MONSTER_SCALE
	_monster_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_monster_sprite.flip_h = true # 왼쪽의 플레이어를 바라보도록
	_monster_sprite.play("idle")
	_monster_portrait.texture = _build_portrait(idle_sheet, _monster_data["portrait_region"])


# 64px 프레임이 가로로 FRAME_COUNT개 나열된 Idle 시트를 SpriteFrames로 변환 (플레이어 전용, 애니메이션 이름 "default")
func _build_frames(sheet: Texture2D, frame_size: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", IDLE_FPS)
	for i in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame("default", atlas)
	return frames


# sheet를 frame_w x frame_h 프레임 frame_count개로 잘라 frames에 anim_name 애니메이션으로 등록 (몬스터 전용)
func _add_monster_animation(frames: SpriteFrames, anim_name: String, sheet: Texture2D, frame_w: int, frame_h: int, frame_count: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)


# 시트에서 region 영역만 잘라 카드 초상화용 AtlasTexture로 만듦
func _build_portrait(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas


# 뷰포트 크기에 비례해 배우 위치를 잡고(해상도 독립), 각 발밑에 타원 그림자를 그린다
func _layout_actors() -> void:
	var vp := get_viewport().get_visible_rect().size
	_player_sprite.position = Vector2(vp.x * 0.24, vp.y * 0.70)
	_monster_sprite.position = Vector2(vp.x * 0.74, vp.y * 0.40)

	var player_foot := _player_sprite.position + Vector2(0, PLAYER_FRAME_SIZE * PLAYER_SCALE * 0.5 - 6.0)
	var monster_foot := _monster_sprite.position + Vector2(0, BattleData.MOB_IDLE_FRAME_SIZE * MONSTER_SCALE * 0.5 - 4.0)
	_setup_shadow(_player_shadow, player_foot, 48.0, 14.0)
	_setup_shadow(_monster_shadow, monster_foot, 40.0, 12.0)


# 타원형 그림자 폴리곤(반지름 rx*ry)을 만들어 지정 위치에 배치
func _setup_shadow(shadow: Polygon2D, center: Vector2, rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	shadow.polygon = pts
	shadow.position = center


# [공격]: 기본 공격으로 한 턴 진행
func _on_attack_pressed() -> void:
	if _mode != Mode.ACTION:
		return
	_run_turn("ATTACK")


# [도망가기]: HP가 최대치의 FLEE_HP_THRESHOLD 이상일 때만 가능. 승패 없이 즉시 전투를 끝내고
# (처치 카운트/퀘스트 진행 없음, HP·마나는 그대로 유지) 원래 있던 위치로 복귀한다.
# 몬스터는 씬이 통째로 다시 로드되며 자연히 트리거 전 상태로 그 자리에 남으므로 리젠 처리를 하지 않는다
func _on_flee_pressed() -> void:
	if _mode != Mode.ACTION or _flee_button.disabled:
		return
	_mode = Mode.BUSY
	_action_row.visible = false
	_message.text = "전투에서 도망쳤다!"
	await _wait(0.4)
	SceneManager.flee_battle()


# 현재 HP가 FLEE_HP_THRESHOLD 미만이면 도망가기 버튼을 비활성(회색) 처리
func _refresh_flee_button() -> void:
	var hp: int = GameState.get_flag("player_hp")
	var max_hp: int = GameState.get_flag("player_max_hp")
	_flee_button.disabled = hp < max_hp * FLEE_HP_THRESHOLD


# [스킬]: 스킬 선택 서브메뉴를 열고, 마나가 부족한 스킬은 비활성(회색) 처리
func _open_skill_menu() -> void:
	if _mode != Mode.ACTION:
		return
	_mode = Mode.SKILL
	_action_row.visible = false
	_skill_row.visible = true
	_refresh_skill_buttons()


# [뒤로]: 스킬 서브메뉴를 닫고 행동 선택으로 복귀
func _close_skill_menu() -> void:
	if _mode != Mode.SKILL:
		return
	_mode = Mode.ACTION
	_skill_row.visible = false
	_action_row.visible = true


# 각 스킬 버튼의 활성/비활성을 현재 마나로 갱신 (부족하면 disabled → 회색으로 보임)
func _refresh_skill_buttons() -> void:
	_strike_button.disabled = not GameState.can_afford_mana(BattleData.SKILLS["STRIKE"]["mana_cost"])
	_heal_button.disabled = not GameState.can_afford_mana(BattleData.SKILLS["HEAL"]["mana_cost"])
	_dodge_button.disabled = not GameState.can_afford_mana(BattleData.SKILLS["DODGE"]["mana_cost"])


# 스킬 선택 시: 마나를 확인·소모하고 해당 스킬로 한 턴 진행
func _on_skill_pressed(skill_key: String) -> void:
	if _mode != Mode.SKILL:
		return
	var cost: int = BattleData.SKILLS[skill_key]["mana_cost"]
	if not GameState.can_afford_mana(cost):
		return
	GameState.spend_mana(cost)
	_update_mana_bar()
	_run_turn(skill_key)


# 한 턴 처리: 플레이어 행동(공격/강타/회복/피하기) → 몬스터 반격. 연출을 await로 순차 재생한다
func _run_turn(action: String) -> void:
	_mode = Mode.BUSY
	_action_row.visible = false
	_skill_row.visible = false
	_dodging = false

	var message := ""

	match action:
		"ATTACK":
			await _player_strike(randi_range(BattleData.PLAYER_ATTACK_DAMAGE_MIN, BattleData.PLAYER_ATTACK_DAMAGE_MAX))
			message = "플레이어의 공격!"
		"STRIKE":
			var dmg := randi_range(BattleData.PLAYER_ATTACK_DAMAGE_MIN, BattleData.PLAYER_ATTACK_DAMAGE_MAX) * int(BattleData.SKILLS["STRIKE"]["damage_mult"])
			await _player_strike(dmg)
			message = "강타! 강력한 일격!"
		"HEAL":
			await _player_heal(BattleData.SKILLS["HEAL"]["heal_fraction"])
			message = "회복 마법으로 체력을 회복했다!"
		"DODGE":
			_dodging = true
			var dmg := int(round(randi_range(BattleData.PLAYER_ATTACK_DAMAGE_MIN, BattleData.PLAYER_ATTACK_DAMAGE_MAX) * float(BattleData.SKILLS["DODGE"]["damage_mult"])))
			await _player_strike(dmg)
			message = "회피하며 반격했다!"

	_refresh_battle_hud()
	_message.text = message

	if _monster_hp <= 0:
		_finish_victory()
		return

	# 몬스터 반격 (피하기 상태면 데미지 0)
	await _wait(0.15)
	await _monster_counterattack()

	if GameState.get_flag("player_hp") <= 0:
		_finish_defeat()
		return

	_refresh_battle_hud()
	_mode = Mode.ACTION
	_action_row.visible = true


# 플레이어가 몬스터를 향해 찌르고 damage만큼 피해를 입힘 (틴트/팝업/HP바/셰이크)
func _player_strike(damage: int) -> void:
	await _lunge(_player_sprite, _monster_sprite.position)
	_monster_hp = max(0, _monster_hp - damage)
	_shake_actors()
	_flash_hit(_monster_sprite)
	_show_popup(_monster_sprite.position, "-%d" % damage, DAMAGE_COLOR)
	_animate_hp_bar(_monster_hp_bar, _monster_hp)
	_update_monster_hp_text()
	await _wait(0.35)


# 자신 HP를 최대치의 fraction만큼 회복하고 회복량을 초록 팝업으로 표시
func _player_heal(fraction: float) -> void:
	var before: int = GameState.get_flag("player_hp")
	GameState.heal_player_partial(fraction)
	var healed: int = GameState.get_flag("player_hp") - before
	_flash_hit(_player_sprite) # 짧은 반짝임으로 시전 강조 (색은 흰색 복귀)
	_show_popup(_player_sprite.position, "+%d" % healed, HEAL_COLOR)
	_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
	_update_player_hp_text()
	await _wait(0.4)


# 몬스터가 플레이어를 향해 찌르며 반격. 피하기 상태면 데미지 없이 "회피!"만 표시
func _monster_counterattack() -> void:
	await _lunge(_monster_sprite, _player_sprite.position)
	if _dodging:
		_show_popup(_player_sprite.position, "회피!", DODGE_COLOR)
		_message.text += "\n공격을 피했다!"
		await _wait(0.25)
		return

	var monster_damage: int = randi_range(_monster_data["damage_min"], _monster_data["damage_max"])
	GameState.damage_player(monster_damage)
	_shake_actors()
	_flash_hit(_player_sprite)
	_show_popup(_player_sprite.position, "-%d" % monster_damage, DAMAGE_COLOR)
	_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
	_update_player_hp_text()
	_message.text += "\n%s의 반격! %d 피해!" % [_monster_data["name"], monster_damage]
	await _wait(0.35)


# 몬스터가 쓰러졌을 때, 사라지기 전에 Death 애니메이션을 한 번(루프 없이) 재생하고 끝날 때까지 기다림.
# Death 캔버스는 변종마다 크기가 달라도 캐릭터의 실제 픽셀 크기는 Idle과 비슷해서, scale은 그대로 두면
# 된다 (프레임 크기에 반비례해서 보정하면 오히려 캔버스가 큰 변종의 캐릭터가 작게 나오는 버그가 생김 —
# monster_encounter.gd의 Idle<->Run에서 한 번 겪었던 것과 같은 실수라 여기도 동일하게 고쳤다).
# 대신 AnimatedSprite2D가 기본 centered라 캔버스 중앙이 노드 위치에 고정되는데, 발은 Idle/Death 둘 다
# 캔버스 맨 아래 줄에 붙어있어서(실측 확인) 캔버스가 더 큰 변종일수록 발이 아래로 밀려 캐릭터가
# 순간 가라앉아 보인다. offset으로 그 차이(캔버스 높이 차의 절반)만큼 위로 당겨 보정한다
# (monster_encounter.gd의 Idle<->Run 발 위치 보정과 같은 원리)
func _play_monster_death() -> void:
	if _monster_sprite.sprite_frames == null or not _monster_sprite.sprite_frames.has_animation("death"):
		return

	var death_h: float = _variant.get("death_frame_height", BattleData.MOB_IDLE_FRAME_SIZE)
	_monster_sprite.offset = Vector2(0, -(death_h - BattleData.MOB_IDLE_FRAME_SIZE) / 2.0)
	_monster_sprite.play("death")
	await _monster_sprite.animation_finished


# 승리 처리: 처치 카운트 증가 + 골드 드롭 + 소량 회복(HP만), "닫기" 버튼으로 복귀 대기.
# 승리 잔치곡을 짧게 틀어주고(결과 화면을 보는 동안), 복귀 시에는 별도 처리 없이 원래 씬에 진입할 때
# SceneManager가 그 구역의 배경음을 다시 틀어주므로 자연스럽게 이전 곡으로 돌아간다
func _finish_victory() -> void:
	await _play_monster_death()

	MusicManager.play("Victory!")

	match _monster_type:
		"ORC":
			GameState.increment_orcs_defeated()
		"SKELETON":
			GameState.increment_skeletons_defeated()

	var gold_gained := randi_range(_monster_data["gold_min"], _monster_data["gold_max"])
	GameState.add_gold(gold_gained)
	_player_gold_label.text = str(GameState.gold)

	GameState.heal_player_partial(VICTORY_HEAL_FRACTION)
	_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
	_update_player_hp_text()
	_refresh_battle_hud()
	_message.text = "%s 처치!\n골드 %d 획득!\n체력을 약간 회복했다." % [_monster_data["name"], gold_gained]

	_mode = Mode.OVER
	_action_row.visible = false
	_skill_row.visible = false
	_close_button.visible = true


# 패배 처리: 플레이어 노드를 다시 보이게 하고 게임오버 화면으로 넘긴다 (회복/복귀는 게임오버 화면이 담당)
func _finish_defeat() -> void:
	_mode = Mode.OVER
	_action_row.visible = false
	_skill_row.visible = false
	_message.text = "정신을 잃었다..."
	SceneManager.reveal_player()
	GameOverScreen.show_game_over()


# [닫기]: 승리 후 원래 씬의 정확한 좌표로 복귀 (SceneManager가 처리)
func _on_close_pressed() -> void:
	if _mode != Mode.OVER:
		return
	_mode = Mode.BUSY
	SceneManager.return_from_battle()


# 카드의 마나바와 도망가기 버튼 활성 상태를 갱신 (HP바는 _animate_hp_bar가 따로 트윈)
func _refresh_battle_hud() -> void:
	_update_mana_bar()
	_refresh_flee_button()


func _update_mana_bar() -> void:
	var mana: int = GameState.get_flag("player_mana")
	var max_mana: int = GameState.get_flag("player_max_mana")
	_player_mana_bar.max_value = max_mana
	_player_mana_bar.value = mana
	_player_mana_bar_label.text = "Mana: %d/%d" % [mana, max_mana]


# 플레이어 HP바 위에 겹친 숫자 텍스트를 GameState 값으로 갱신
func _update_player_hp_text() -> void:
	_player_hp_bar_label.text = "HP: %d/%d" % [GameState.get_flag("player_hp"), GameState.get_flag("player_max_hp")]


# 몬스터 HP바 위에 겹친 숫자 텍스트를 현재 전투 상태로 갱신
func _update_monster_hp_text() -> void:
	_monster_hp_bar_label.text = "HP: %d/%d" % [_monster_hp, _monster_data["max_hp"]]


# HP바를 목표값까지 부드럽게 트윈
func _animate_hp_bar(bar: ProgressBar, target_value: float) -> void:
	var tween := create_tween()
	tween.tween_property(bar, "value", target_value, HP_TWEEN_DURATION)


# 맞은 스프라이트를 빨갛게 틴트했다가 원래 색으로 되돌림
func _flash_hit(sprite: CanvasItem) -> void:
	sprite.modulate = HIT_TINT
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, HIT_TINT_DURATION)


# 맞은 캐릭터 머리 위로 "-N"/"+N"/"회피!" 텍스트를 크게 띄웠다가 위로 떠오르며 사라지게 함
func _show_popup(sprite_pos: Vector2, text: String, color: Color) -> void:
	var popup := Label.new()
	popup.text = text
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_font_size_override("font_size", DAMAGE_POPUP_FONT_SIZE)
	popup.z_index = 20
	_hud.add_child(popup)
	popup.position = sprite_pos + Vector2(-16.0, -66.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - DAMAGE_POPUP_RISE, DAMAGE_POPUP_DURATION)
	tween.tween_property(popup, "modulate:a", 0.0, DAMAGE_POPUP_DURATION)
	tween.chain().tween_callback(popup.queue_free)


# 배우 컨테이너 전체를 짧게 흔들었다가 원위치 (타격감용). 그림자는 View 직속이라 함께 흔들리지 않음
func _shake_actors() -> void:
	var tween := create_tween()
	for i in range(SHAKE_STEPS):
		var offset := Vector2(randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT), randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT))
		tween.tween_property(_actors, "position", offset, SHAKE_STEP_DURATION)
	tween.tween_property(_actors, "position", Vector2.ZERO, SHAKE_STEP_DURATION)


# 공격하는 스프라이트를 상대 방향으로 짧게 찔렀다가 원위치로 돌아오게 함 (완료까지 await)
func _lunge(attacker: Node2D, target_pos: Vector2) -> void:
	var original := attacker.position
	var direction := target_pos - original
	if direction.length() > 0.001:
		direction = direction.normalized()
	else:
		direction = Vector2.RIGHT

	var tween := create_tween()
	tween.tween_property(attacker, "position", original + direction * LUNGE_DISTANCE, LUNGE_OUT_DURATION)
	tween.tween_property(attacker, "position", original, LUNGE_BACK_DURATION)
	await tween.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
