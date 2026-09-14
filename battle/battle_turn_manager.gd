class_name BattleTurnManager
extends RefCounted

const PlayerCombatant = preload("res://battle/player_combatant.gd")
const CompanionState = preload("res://battle/companion_state.gd")

# 카드 전투의 턴 진행을 총괄한다. Card/Deck/Hand/WeaponState/EnemyResistance를 하나로 엮어
# "턴 시작 → 플레이어가 카드를 자유롭게 냄 → 턴 종료 → 적 턴 → 종료 판정 → 다음 턴"을 굴린다.
#
# UI/전투 씬 연결은 아직 없다. 바깥(나중의 전투 씬)은 start() / play_card() / switch_weapon() /
# end_turn()만 호출하고, 진행 상황은 시그널로 받아 화면을 갱신하면 된다.
#
# [상태 보관 위치] 기존 battle_scene.gd의 방식을 그대로 따른다:
# - 플레이어 HP/마나: GameState.flags ("player_hp" 등). 전투 밖에서도 유지되고 세이브에 포함되므로
#   여기서 따로 들고 있지 않고 GameState 헬퍼(damage_player/heal_player_partial 등)로만 조작한다.
# - 몬스터 상태: 이 매니저가 들고 있는 monsters 배열(MonsterState). 전투가 끝나면 사라지는 값이라
#   GameState에 넣을 이유가 없다. 다인전 도입 전에는 monster_hp라는 단일 int였다.

signal turn_started(turn_number: int)
signal card_played(card: Card, damage_dealt: int) # 데미지 카드가 아니면 damage_dealt는 0
signal weapon_switched(weapon: WeaponState.WeaponType)
# 몬스터 한 마리가 파티원 한 명을 때린 결과. 다인전에서는 살아있는 마리 수만큼 순차로 발생한다
# (예전 단일 전투의 enemy_turn_resolved를 마리별로 쪼갠 것 — attacker_index가 누가 때렸는지,
# target_index가 party 배열의 누가 맞았는지 알려준다. 0이면 플레이어)
signal enemy_attack_resolved(attacker_index: int, target_index: int, damage_taken: int, dodged: bool, counter_damage: int)
# 동료 한 명이 몬스터 한 마리를 공격한 결과 (party 배열 인덱스, target_index는 몬스터 자리 번호)
signal companion_attack_resolved(companion_index: int, target_index: int, damage: int)
# 마나가 바닥나 공격 대신 숨을 고른 몬스터. mana_gained/hp_gained는 실제로 회복된 양
# (hp_gained가 0이면 이번엔 체력 회복이 안 붙은 것)
signal monster_recovered(index: int, mana_gained: int, hp_gained: int)
# 마나가 바닥나 공격 대신 숨을 고른 동료. monster_recovered와 같은 규약
signal companion_recovered(index: int, mana_gained: int, hp_gained: int)
# 동료 패시브(파티 전체 회복)가 발동함. source_index는 발동시킨 동료의 party 배열 자리 번호,
# results는 party 배열 순서대로 {"index": int, "hp": int, "mana": int} (실제 회복량, 죽은 자리는 제외)
signal party_passive_healed(source_index: int, results: Array)
# 동료 액티브(마력장벽 등) 사용. companion_index는 party 배열 자리 번호, mana_spent는 실제 소모량
signal companion_active_used(companion_index: int, mana_spent: int)
signal monster_defeated(index: int) # 마리 하나가 쓰러짐 (전투는 아직 안 끝났을 수 있음)
# 무기 하나가 과부하로 봉쇄됨 (WeaponState.WeaponType)
signal weapon_overloaded(weapon: int)
# 몬스터가 같은 속성에 적응했거나(adapted) 반대 속성에 맞아 적응이 깨짐(broken)
signal monster_adapted(index: int, resistance_type: int, adapted: bool, broken: bool)
# 스테이지 하나를 깼다 (남은 스테이지가 있을 때만 — 마지막 스테이지는 enemy_defeated로 간다)
signal stage_cleared(stage_index: int, stage_count: int)
# 버프/디버프가 새로 걸렸을 때 (target_index가 -1이면 플레이어 자신)
signal status_applied(target_index: int, kind: int, magnitude: int, rounds: int)
# 한 라운드가 끝나 상태이상이 풀렸을 때 (연출/로그가 "효과가 사라졌다"를 알릴 수 있게)
signal status_expired(target_index: int, kind: int)
signal player_defeated
signal enemy_defeated # 살아있는 몬스터가 하나도 남지 않음 = 전투 승리

const HAND_SIZE := 5

# 표식이 터지지 않은 채 버티는 라운드 수. 2라운드면 "이번 라운드 안에 전환하거나, 다음 라운드
# 첫 수로 전환하거나" 정도의 여유라 전환을 계획에 넣게 만들면서도 무한정 쌓이지는 않는다
const MARK_ROUNDS := 2

# 적 공격 대상을 고르는 가중치 (party 배열 인덱스 기준, 0=플레이어). 동료는 아직 0으로 잠가둬서
# 있어도 지금은 플레이어만 맞는다 — 실제 값 전환은 아군 연출이 갖춰진 뒤(Phase 3-c)에 한다
# (docs/companion_system_phase3_plan.md §3)
const TARGET_WEIGHT_PLAYER := 2
const TARGET_WEIGHT_COMPANION := 1

var deck: Deck
var hand: Hand
var weapon: WeaponState

# 플레이어에게 걸린 버프/디버프. 전투가 끝나면 사라지는 값이라 GameState가 아니라 여기에 둔다 —
# 몬스터 HP를 매니저가 들고 있는 것과 같은 기준이다 (세이브에 남을 이유가 없는 전투 한정 상태)
var player_status := StatusEffects.new()

# 이번 전투에 등장한 몬스터들 (1~3마리, 전부 같은 종류). 자리 순서가 곧 MonsterState.index다
var monsters: Array[MonsterState] = []

# 아군 진영 (0번은 항상 PlayerCombatant, 이후가 GameState.active_companions 순서의 CompanionState).
# 아직 피격 대상 선택/자동 행동에는 쓰이지 않는다 — 그건 Phase 3 범위이고, 여기서는 배열만 갖춘다
# (docs/companion_system_backend_plan.md §7)
var party: Array = []

var monster_type: String = "" # 그룹 전체가 같은 종류라 스칼라로 둔다
var monster_data: Dictionary = {} # 그 종류의 스탯 표 (마리별 값은 MonsterState.monster_data로 접근)

var turn_number: int = 0
var battle_over: bool = false

# 전투 시작 후 적 턴이 몇 번 완전히 끝났는지. 유서프 액티브의 "3턴 지나야 사용 가능" 1회성
# 게이트 판정에 쓴다 (docs/companion_system_options.md §7) — turn_number는 "지금 몇 번째 턴인가"라
# 이 용도로는 헷갈려서 별도로 둔다
var rounds_completed: int = 0

# 방금 낸 카드가 마리별로 입힌 실제 피해 (자리 번호 -> 피해량). 피해가 0인 대상은 담지 않는다.
# 광역기는 여러 자리가 채워지고 단일 대상 카드는 한 자리만 채워지므로, 연출은 이걸 그대로 훑어
# 몬스터마다 제 숫자를 띄우면 된다 (0 피해에 "-0"을 띄우지 않는 기존 규칙도 그대로 유지된다)
var last_hit_damage: Dictionary = {}

# 방금 낸 카드의 부가 성질(DamageTraits)이 실제로 만들어낸 결과 — {"mana_stolen": int, "hp_leeched": int}.
# 대상마다 누적되므로 광역 흡혈 카드가 생겨도 합계가 그대로 나온다. last_hit_damage와 같은 이유로
# "약속한 값"이 아니라 "실제로 오간 값"만 담는다 (플레이어 최대치에서 잘린 분은 빠져 있다)
var last_trait_result: Dictionary = {}

# 도박형 성질의 배율은 카드 한 번 사용당 한 번만 굴려야 해서, 굴린 값을 여기 담아 대상 계산에 재사용한다.
# 성질이 없거나 카드 사용 밖에서는 1.0 (배율 없음)
var _rolled_damage_multiplier: float = 1.0

# 가속(FREE_NEXT_CARD)이 켜둔 "다음 한 장 공짜" 표식. 다음에 내는 카드가 무엇이든 그 한 장에서
# 소모되고, 남아 있어도 턴이 넘어가면 사라진다 (_start_turn에서 초기화)
var _free_next_card: bool = false

# 방어/피하기 카드가 만드는 "다음 적 턴 한정" 임시 상태. 적 턴을 해결하는 즉시 소모되고 0/false로 돌아간다.
# (스펙에 세부 규칙이 없어 아래처럼 설계했다 — 근거는 take_next_monster_action() 주석 참고)
var _pending_defense: int = 0
var _pending_dodge: bool = false
var _pending_counter: int = 0 # 반격(COUNTER) 카드로 예약해둔 반격 피해량. 0이면 반격 대기 아님
# 마력장벽(액티브) 사용 시 파티 전원에게 붙는 "다음 적 턴 피해 N% 감소". 위 셋과 같은 규약으로
# 적 턴을 해결하면 무조건 0으로 되돌아간다 — 다만 방어/피하기/반격과 달리 "첫 공격 한 방"이
# 아니라 그 적 턴에 오는 공격 전부에 적용된다 (비율 감소는 방어처럼 소모되는 총량이 아니라서)
var _pending_damage_reduction_fraction: float = 0.0

# ── 예약 큐 (드래그로 내려놓은 카드 + 끼워 넣은 무기 전환) ────────────────
# 카드는 드롭하는 즉시 효과가 나가지 않고 여기 쌓였다가, 턴종료 때 예약 순서대로 하나씩 실행된다.
# 항목은 두 종류다:
#   {"kind": ENTRY_CARD, "card": Card, "target_index": int}  (광역/자기대상은 target_index = -1)
#   {"kind": ENTRY_SWITCH, "weapon": WeaponState.WeaponType} (무기 전환도 큐에 놓는 한 수다)
#
# 비용(마나/체력)과 게이지는 "실행하는 순간" 치른다. 전환이 큐에 끼어들 수 있게 되면서 어느 무기
# 게이지가 오를지가 순서에 따라 달라졌기 때문이다 — 예약 시점에 미리 걷으면 그 계산이 성립하지 않는다.
# 대신 예약할 때마다 _plan_state()로 큐를 끝까지 굴려보고 "그 시점에 낼 수 있는 카드인가"를 검사해,
# 큐 한복판에서 자원이 모자라 조용히 불발되는 일을 막는다
const ENTRY_CARD := "card"
const ENTRY_SWITCH := "switch"

var reserved: Array[Dictionary] = []

# 라운드 해결 중인지. 이 동안에는 "계획"이 아니라 지금 실제 값이 화면에 떠야 한다
var _resolving: bool = false

# ── 도발 (다음에 반격할 몬스터) ────────────────────────────────────────────
# 라운드로빈을 대신한다: 방금 때린 놈이 곧바로 되받아친다. -1이면 이번 교환에는 반격이 없다
# (겨눈 대상을 그 카드로 쓰러뜨린 경우 — 죽이면 그만큼 맞지 않는다는 게 이 규칙의 핵심 보상이다)
var _pending_retaliator: int = -1
var _last_provoked: int = -1

# ── 스테이지 ───────────────────────────────────────────────────────────────
var stages: Array[Dictionary] = []
var stage_index: int = 0
var stage_pending: bool = false # 스테이지를 깼고 보상 선택을 기다리는 중 (다음 턴은 아직 열리지 않는다)

var _stage_modifiers: Dictionary = {} # 다음 스테이지 스폰/손패에 적용할 보상 대가
var _stage_hand_delta: int = 0
var _free_round_active: bool = false
var _card_power_bonus: Dictionary = {} # card_name -> 추가 배율 (각인 — 이번 전투 내내 유지)

# 지금 효과를 적용 중인 카드가 레드라인 보너스를 받는지 (_execute_card가 켰다 끈다)
var _redline_active: bool = false


# monster_type_은 BattleData.MONSTERS의 키("ORC" 등), variants는 필드에서 부딪힌 개체의 시각 변종
# (0번만 쓴다 — 나머지 편성은 BattleStages가 스테이지별로 다시 뽑는다), cards는 이번 전투에 쓸 카드 목록.
# Deck이 생성 시 알아서 섞으므로 여기서 따로 셔플하지 않는다
func _init(monster_type_: String, variants: Array, cards: Array[Card]) -> void:
	monster_type = monster_type_
	monster_data = BattleData.MONSTERS[monster_type_]

	var first_variant: Dictionary = variants[0] if not variants.is_empty() else {}
	stages = BattleStages.build_plan(monster_type_, first_variant)

	deck = Deck.new(cards)
	hand = Hand.new()
	weapon = WeaponState.new()

	party.append(PlayerCombatant.new(player_status))
	for companion_id in GameState.get_active_companions():
		party.append(CompanionState.new(party.size(), companion_id))

	_spawn_stage(0)


# 스테이지 하나의 몬스터들을 실제로 세운다. 직전 보상이 남긴 대가(_stage_modifiers)가 여기서
# 마리 수/체력/공격력에 반영되고, 손패 증감과 "첫 라운드 무료"도 이 시점에 이번 스테이지 값으로 굳는다
func _spawn_stage(index: int) -> void:
	stage_index = index
	monsters.clear()
	_pending_retaliator = -1
	_last_provoked = -1

	var stage: Dictionary = stages[index]
	var variants: Array = stage["variants"]
	var elites: Array = stage["elites"]
	var hp_mult := float(_stage_modifiers.get("next_hp_mult", 1.0))
	var damage_mult := float(_stage_modifiers.get("next_damage_mult", 1.0))
	if stages.size() > 1:
		hp_mult *= BattleStages.hp_scale_for(index, monster_type)
		damage_mult *= BattleStages.damage_scale_for(index, monster_type)
	var count := clampi(variants.size() + int(_stage_modifiers.get("next_count_delta", 0)), 1, BattleStages.MAX_MONSTERS_PER_STAGE)
	_stage_hand_delta = int(_stage_modifiers.get("next_hand_delta", 0))
	_free_round_active = bool(_stage_modifiers.get("free_first_round", false))
	_stage_modifiers = {}

	for i in range(count):
		var variant: Dictionary = variants[i] if i < variants.size() else BattleData.pick_variant(monster_type)
		var elite: bool = bool(elites[i]) if i < elites.size() else false
		monsters.append(MonsterState.new(i, monster_type, variant, elite, hp_mult, damage_mult))

	# 같은 종류가 여러 마리면 이름에 번호를 붙여 메시지에서 구분되게 한다 (한 마리면 그냥 "오크")
	if monsters.size() > 1:
		for monster in monsters:
			monster.display_name = "%s %d" % [monster.display_name, monster.index + 1]


func stage_count() -> int:
	return stages.size()


func is_final_stage() -> bool:
	return stage_index >= stages.size() - 1


func current_stage_variants() -> Array:
	var list: Array = []
	for monster in monsters:
		list.append(monster.variant)
	return list


func current_stage_elites() -> Array:
	var list: Array = []
	for monster in monsters:
		list.append(monster.is_elite)
	return list


# 보상 선택을 마친 뒤 전투 씬이 부른다: 다음 스테이지를 세우고 새 턴을 연다
func advance_stage() -> void:
	if not stage_pending:
		return
	stage_pending = false
	_spawn_stage(stage_index + 1)
	_start_turn()


# 고른 보상을 적용한다. 즉시 효과(회복/냉각/각인)는 여기서 바로 들어가고, 대가(다음 스테이지
# 몬스터 강화/손패 감소 등)는 _stage_modifiers에 담아 뒀다가 _spawn_stage가 꺼내 쓴다
func apply_stage_reward(offer: Dictionary) -> void:
	var effect: Dictionary = offer.get("effect", {})

	if effect.has("heal_fraction"):
		GameState.heal_player_partial(float(effect["heal_fraction"]))
	if effect.has("mana_full"):
		GameState.restore_mana_partial(1.0)
	if effect.has("hp_cost_fraction"):
		var max_hp: int = GameState.get_flag("player_max_hp")
		var cost := int(round(max_hp * float(effect["hp_cost_fraction"])))
		# 보상을 고른 대가로 죽지는 않게 한다 (선택지 자체가 빈사일 땐 뜨지 않지만 이중 안전판)
		var current_hp: int = GameState.get_flag("player_hp")
		GameState.damage_player(mini(cost, maxi(0, current_hp - 1)))
	if effect.has("cool_weapons"):
		weapon.cool_everything()
	if effect.has("card_power") and offer.has("card_name"):
		var name_: String = offer["card_name"]
		_card_power_bonus[name_] = float(_card_power_bonus.get(name_, 0.0)) + float(effect["card_power"])

	for key in ["next_hp_mult", "next_damage_mult", "next_count_delta", "next_hand_delta", "free_first_round"]:
		if effect.has(key):
			_stage_modifiers[key] = effect[key]


# 보상 선택지를 뽑을 때 쓰는 현재 상황 (BattleStages.roll_offers에 그대로 넘긴다)
func stage_reward_context() -> Dictionary:
	var max_hp: float = maxf(1.0, float(GameState.get_flag("player_max_hp")))
	var max_mana: float = maxf(1.0, float(GameState.get_flag("player_max_mana")))
	var next_count := 1
	if stage_index + 1 < stages.size():
		next_count = (stages[stage_index + 1]["variants"] as Array).size()

	# 각인 대상은 "이번 전투 덱 안의 공격 카드" 중에서 고른다 — 손패에 지금 없어도 다음 스테이지에
	# 다시 돌아올 카드라 이번 전투 내내 값어치가 있다
	var names: Array[String] = []
	for card in _all_battle_cards():
		if card.effect == Card.EffectType.DAMAGE and not names.has(card.card_name):
			names.append(card.card_name)

	return {
		"hp_ratio": float(GameState.get_flag("player_hp")) / max_hp,
		"mana_ratio": float(GameState.get_flag("player_mana")) / max_mana,
		"next_count": next_count,
		"card_names": names,
	}


func _all_battle_cards() -> Array[Card]:
	var all: Array[Card] = []
	all.append_array(hand.cards)
	all.append_array(deck.draw_pile)
	all.append_array(deck.discard_pile)
	for entry in reserved:
		if entry["kind"] == ENTRY_CARD:
			all.append(entry["card"])
	return all


# 전투를 시작하고 첫 턴을 연다 (_init과 분리해 둬서, 바깥이 시그널을 먼저 연결한 뒤 시작할 수 있다).
# 시작 직전에 장비 보너스를 한 번 재계산해, 전투에 들어갈 때의 방패 최대 체력 보너스가
# 확실히 player_max_hp에 반영된 상태로 싸우게 한다
func start() -> void:
	GameState.refresh_equipment_bonuses()
	_start_turn()


# ── 턴 시작 ────────────────────────────────────────────────────────────────
# 무기 전환 횟수를 리셋하고 손패를 새로 채운다. (남은 손패는 Hand.draw_new_hand()가 알아서
# 버린 더미로 보낸 뒤 새로 뽑는다). 예전엔 여기서 마리별 저항을 무작위로 굴렸지만, 지금 저항은
# 주사위가 아니라 플레이어가 때린 순서가 만든다 (EnemyResistance = 적응)
func _start_turn() -> void:
	turn_number += 1
	weapon.reset_turn()
	# 가속은 "이번 턴" 한정이라 턴이 바뀌면 쓰지 않은 표식은 사라진다 (과열 게이지 리셋과 같은 자리)
	_free_next_card = false
	_pending_retaliator = -1
	hand.draw_new_hand(deck, maxi(1, HAND_SIZE + _stage_hand_delta))
	turn_started.emit(turn_number)


# ── 몬스터 조회 / 타겟팅 ───────────────────────────────────────────────────

# index 자리의 몬스터 (범위를 벗어나면 null)
func get_monster(index: int) -> MonsterState:
	if index < 0 or index >= monsters.size():
		return null
	return monsters[index]


# [임시 자동 타겟팅] 살아있는 몬스터 중 첫 번째. 진짜 타겟팅 UI(카드 클릭 → 대상 선택)가 붙는
# 다음 단계에서는 호출부가 플레이어가 고른 index를 직접 넘기게 되고, 이 함수는 "아무것도 안 골랐을 때의
# 기본값" 역할만 남는다. 전멸했으면 null
func get_auto_target() -> MonsterState:
	for monster in monsters:
		if monster.is_alive():
			return monster
	return null


func alive_monsters() -> Array[MonsterState]:
	var alive: Array[MonsterState] = []
	for monster in monsters:
		if monster.is_alive():
			alive.append(monster)
	return alive


func all_monsters_defeated() -> bool:
	return alive_monsters().is_empty()


# ── 플레이어 행동 (계획) ───────────────────────────────────────────────────

# 예약 큐를 끝까지 굴려본 "이 계획대로 갔을 때의 상태". 큐가 비어 있으면 지금 상태와 같다.
# 라운드 해결 중에는 계획이 아니라 실제 값이 화면에 떠야 하므로 시뮬레이션을 건너뛴다.
# 결과를 캐시하지 않는 이유: 마나/체력은 매니저 밖(승리 후 레벨업, 적 공격 등)에서도 바뀌어서 캐시가
# 옛값을 들고 있다 화면에 틀린 계획을 띄운 적이 있다. 큐는 길어야 몇 칸이라 매번 굴려도 싸다
func _plan_state() -> Dictionary:
	var state := {
		"mana": int(GameState.get_flag("player_mana")),
		"hp": int(GameState.get_flag("player_hp")),
		"weapon": weapon.copy(),
		"free_next": _free_next_card,
	}
	if not _resolving:
		for entry in reserved:
			_apply_plan_entry(state, entry)
	return state


func _apply_plan_entry(state: Dictionary, entry: Dictionary) -> void:
	var plan_weapon: WeaponState = state["weapon"]
	if entry["kind"] == ENTRY_SWITCH:
		plan_weapon.switch_weapon(entry["weapon"])
		return

	var card: Card = entry["card"]
	var free: bool = bool(state["free_next"]) or _free_round_active
	state["mana"] = maxi(0, int(state["mana"]) - (0 if free else card.get_mana_cost()))
	state["hp"] = maxi(0, int(state["hp"]) - (0 if free else card.get_hp_cost()))
	state["free_next"] = card.effect == Card.EffectType.FREE_NEXT_CARD
	plan_weapon.register_card_use(card)
	if card.on_use_set_gauge > 0:
		plan_weapon.set_both_gauges(card.on_use_set_gauge)


# 이 카드를 큐에 더 얹을 수 있는지. "지금 자원"이 아니라 "계획대로 갔을 때의 자원"으로 판단하는 게
# 핵심이다 — 그래야 예약해둔 카드가 실행 도중 자원이 모자라 조용히 불발되는 일이 없다
func can_play_card(card: Card) -> bool:
	if battle_over or stage_pending or card == null:
		return false
	if not hand.cards.has(card):
		return false
	return _can_afford_in(_plan_state(), card)


func _can_afford_in(state: Dictionary, card: Card) -> bool:
	var plan_weapon: WeaponState = state["weapon"]
	if not plan_weapon.can_use_card(card):
		return false
	var free: bool = bool(state["free_next"]) or _free_round_active
	var mana_cost := 0 if free else card.get_mana_cost()
	var hp_cost := 0 if free else card.get_hp_cost()
	if int(state["mana"]) < mana_cost:
		return false
	if hp_cost > 0 and int(state["hp"]) <= hp_cost:
		return false
	return true


# 지금 이 카드를 내는 데 실제로 들 비용. 판정과 실제 지불과 화면 배지가 전부 이 함수를 거쳐야
# "배지엔 3이라고 적혀 있는데 실제로는 0이 나가는" 어긋남이 생기지 않는다
func get_effective_mana_cost(card: Card) -> int:
	return 0 if _costs_are_free() else card.get_mana_cost()


func get_effective_hp_cost(card: Card) -> int:
	return 0 if _costs_are_free() else card.get_hp_cost()


func _costs_are_free() -> bool:
	return _free_round_active or bool(_plan_state()["free_next"])


func is_next_card_free() -> bool:
	return _costs_are_free()


# 화면이 보여줄 자원. 계획 중에는 "큐를 다 실행하고 난 뒤"의 값을 보여준다 — 지금 짜고 있는 계획의
# 결과가 곧 이번 라운드의 결과라, 판단에 쓰이는 숫자는 그쪽이다
func display_mana() -> int:
	return int(_plan_state()["mana"])


func display_hp() -> int:
	return int(_plan_state()["hp"])


func display_weapon() -> WeaponState:
	return _plan_state()["weapon"]


func can_afford_hp(cost: int) -> bool:
	if cost <= 0:
		return true
	return GameState.get_flag("player_hp") > cost


# 카드 한 장을 그 자리에서 내고 끝낸다 (헤드리스 테스트/자동 전투용 — 화면 있는 전투는 예약을 쓴다)
func play_card(card: Card, target_index: int = -1) -> bool:
	if not reserve_card(card, target_index):
		return false
	var entry: Dictionary = reserved.pop_back()
	return bool(_execute_card(entry).get("played", false))


# 카드를 손패에서 빼 예약 큐에 넣는다 (비용은 실행 시점에 낸다)
func reserve_card(card: Card, target_index: int = -1) -> bool:
	if not can_play_card(card):
		return false
	hand.cards.erase(card)
	reserved.append({"kind": ENTRY_CARD, "card": card, "target_index": target_index})
	return true


# 무기 전환을 큐의 한 수로 끼워 넣는다. 전환은 카드가 아니라 "사이에 넣는 박자"라 몬스터의 응수를
# 부르지 않고, 대신 걸려 있던 표식이 이때 전부 터진다 (템포 체인)
func can_reserve_switch() -> bool:
	if battle_over or stage_pending:
		return false
	return (_plan_state()["weapon"] as WeaponState).can_switch()


func planned_equipped() -> WeaponState.WeaponType:
	return (_plan_state()["weapon"] as WeaponState).equipped


func reserve_switch() -> bool:
	if not can_reserve_switch():
		return false
	reserved.append({"kind": ENTRY_SWITCH, "weapon": WeaponState.other_weapon(planned_equipped())})
	return true


func has_reservations() -> bool:
	return not reserved.is_empty()


# 아직 실행되지 않은 예약을 취소한다. 비용은 실행할 때 내므로 되돌릴 자원이 없다 — 카드만 손패로
# 돌려놓으면 끝이고, 뒤에 남은 예약들의 자원 계산은 _plan_state()가 알아서 다시 한다
func cancel_reservation(index: int) -> bool:
	if index < 0 or index >= reserved.size():
		return false
	var entry: Dictionary = reserved[index]
	reserved.remove_at(index)
	if entry["kind"] == ENTRY_CARD:
		hand.cards.append(entry["card"])
	return true


# 예약 하나가 지금 이 순간 실행 가능한지 (실행 직전 판정 + UI의 불발 예고 표시에 함께 쓴다)
func reservation_is_valid(entry: Dictionary) -> bool:
	if entry.get("kind", ENTRY_CARD) == ENTRY_SWITCH:
		return true
	return _card_invalid_reason(entry) == ""


# 큐 전체를 순서대로 굴려보며 각 수가 유효한지 (앞의 전환을 취소하면 뒤 카드가 봉쇄된 무기를
# 가리키게 되는 식의 어긋남을 UI가 미리 빨갛게 보여줄 수 있도록)
func queue_validity() -> Array[bool]:
	var state := {
		"mana": int(GameState.get_flag("player_mana")),
		"hp": int(GameState.get_flag("player_hp")),
		"weapon": weapon.copy(),
		"free_next": _free_next_card,
	}
	var flags: Array[bool] = []
	for entry in reserved:
		if entry["kind"] == ENTRY_SWITCH:
			flags.append((state["weapon"] as WeaponState).can_switch())
		else:
			flags.append(_can_afford_in(state, entry["card"]) and _target_still_valid(entry))
		_apply_plan_entry(state, entry)
	return flags


# 불발 사유 ("" = 정상). 대상이 이미 쓰러졌거나, 큐가 도는 사이 자원/봉쇄 상황이 바뀐 경우다
func _card_invalid_reason(entry: Dictionary) -> String:
	var card: Card = entry["card"]
	if not _target_still_valid(entry):
		return "target"
	if not weapon.can_use_card(card):
		return "locked"
	var free: bool = _free_next_card or _free_round_active
	if not free and GameState.get_flag("player_mana") < card.get_mana_cost():
		return "mana"
	if not free and card.get_hp_cost() > 0 and GameState.get_flag("player_hp") <= card.get_hp_cost():
		return "hp"
	return ""


# 겨눈 대상이 아직 살아 있는지. 단일 대상 공격 카드는 대상이 죽어 있으면 무효다
# (다른 적으로 자동 이동시키지 않는다 — 플레이어가 겨눈 자리가 사라진 것이므로 그냥 허공을 가른다)
func _target_still_valid(entry: Dictionary) -> bool:
	var card: Card = entry["card"]
	if card.is_aoe:
		return not all_monsters_defeated()
	var target_index: int = entry["target_index"]
	if target_index < 0 or not _targets_enemy_side(card):
		return true
	var target := get_monster(target_index)
	return target != null and target.is_alive()


# 이 카드가 적 진영을 겨냥하는지 (불발 판정과 도발 대상 판정에 함께 쓴다)
func _targets_enemy_side(card: Card) -> bool:
	match card.effect:
		Card.EffectType.DAMAGE, Card.EffectType.DEBUFF_ATTACK_ENEMY:
			return true
		Card.EffectType.STATUS_PACKAGE:
			return StatusEffects.package_targets_enemy(card.status_package)
		_:
			return false


# ── 실행 ───────────────────────────────────────────────────────────────────

# 큐 맨 앞의 한 수를 실행한다. 반환값의 "provokes"가 false면 이 수 뒤에는 몬스터가 응수하지 않는다
# (무기 전환이 그렇다 — 전환은 공짜 박자다)
func execute_next_reservation() -> Dictionary:
	if reserved.is_empty():
		return {"kind": "none", "played": false, "card": null, "damage": 0, "provokes": false}
	var entry: Dictionary = reserved.pop_front()
	if entry["kind"] == ENTRY_SWITCH:
		return _execute_switch(entry)
	return _execute_card(entry)


func _execute_switch(entry: Dictionary) -> Dictionary:
	var target: WeaponState.WeaponType = entry["weapon"]
	var switched := weapon.switch_weapon(target)
	if switched:
		weapon_switched.emit(target)
	return {
		"kind": ENTRY_SWITCH, "played": switched, "card": null, "damage": 0,
		"weapon": int(target), "detonations": detonate_marks(), "provokes": false,
	}


func _execute_card(entry: Dictionary) -> Dictionary:
	var card: Card = entry["card"]
	var target_index: int = entry["target_index"]

	var reason := _card_invalid_reason(entry)
	if reason != "":
		deck.discard([card] as Array[Card])
		_pending_retaliator = _resolve_provoke(null, -1)
		# 불발이어도 전멸 판정은 해야 한다 — 동료 공격 등으로 이미 다 쓰러져 있을 수 있다
		if all_monsters_defeated():
			_on_stage_wiped()
		return {"kind": ENTRY_CARD, "played": false, "card": card, "damage": 0, "reason": reason, "provokes": true}

	var free: bool = _free_next_card or _free_round_active
	var mana_cost := 0 if free else card.get_mana_cost()
	var hp_cost := 0 if free else card.get_hp_cost()
	_free_next_card = false

	# 비용을 효과보다 먼저 치른다 — 체력을 회복하는 카드가 체력 비용을 갖는 경우 순서가 뒤집히면
	# 회복분까지 비용으로 깎여 카드가 약속한 결과가 나오지 않는다
	GameState.spend_mana(mana_cost)
	if hp_cost > 0:
		GameState.damage_player(hp_cost)

	# 레드라인은 이 카드가 게이지를 올리기 "전" 값으로 판정한다 — 카드를 낸 결과로 달아오른 열은
	# 다음 카드의 몫이어야 "75를 넘긴 채 한 장 더 지르는" 선택이 성립한다
	var redline := weapon.is_redline_for_card(card)
	var overloaded: Array[int] = []
	if weapon.register_card_use(card):
		overloaded.append(int(weapon.equipped))
	if card.on_use_set_gauge > 0:
		overloaded.append_array(weapon.set_both_gauges(card.on_use_set_gauge))
	for overloaded_weapon in overloaded:
		weapon_overloaded.emit(overloaded_weapon)

	_redline_active = redline
	var damage_dealt := _apply_card_effect(card, target_index)
	_redline_active = false

	deck.discard([card] as Array[Card])
	card_played.emit(card, damage_dealt)

	_pending_retaliator = _resolve_provoke(card, target_index)

	if all_monsters_defeated():
		_on_stage_wiped()

	return {
		"kind": ENTRY_CARD, "played": true, "card": card, "damage": damage_dealt,
		"redline": redline, "overloaded": overloaded, "provokes": true,
	}


# 걸려 있는 표식을 전부 터뜨린다 (무기를 전환하는 순간). 표식 피해에는 속성이 없어 적응을 쌓지도
# 깨지도 않는다 — 적응한 상대를 우회해 때리는 통로가 하나 열려 있는 셈이다
func detonate_marks() -> Array:
	var results: Array = []
	for monster in monsters:
		if not monster.is_alive():
			continue
		var power := monster.status.get_magnitude(StatusEffects.Kind.MARK)
		if power <= 0:
			continue
		monster.status.remove(StatusEffects.Kind.MARK)
		status_expired.emit(monster.index, int(StatusEffects.Kind.MARK))
		results.append({"index": monster.index, "damage": monster.take_damage(power)})
		if not monster.is_alive():
			monster_defeated.emit(monster.index)

	if not results.is_empty() and all_monsters_defeated():
		_on_stage_wiped()
	return results


func has_marks() -> bool:
	for monster in monsters:
		if monster.is_alive() and monster.status.get_magnitude(StatusEffects.Kind.MARK) > 0:
			return true
	return false


# ── 도발 ───────────────────────────────────────────────────────────────────

# 이 카드 뒤에 반격할 몬스터 자리 번호. -1이면 이번 교환에는 반격이 없다.
#
# 도발은 "건드린 놈이 되받아친다"가 전부다. 그래서 아무 몬스터도 겨누지 않은 카드(방어/피하기/회복/
# 자기버프)나 허공을 가른 불발은 누구도 도발하지 않아 반격이 없다. 예전처럼 이런 카드도 반격을 부르면
# 피하기는 자기가 부른 반격을 자기가 막는 셈이라 아무 효과가 없는 카드가 되고, 방어도 스스로 맞을
# 매를 사는 카드가 된다. 비공격 카드는 마나를 쓰고 피해를 주지 않으므로 그 자체로 이미 대가를 치른다
func _resolve_provoke(card: Card, target_index: int) -> int:
	if card == null or not _targets_enemy_side(card):
		return -1

	if card.is_aoe:
		# 광역은 특정 대상이 없으니 살아남은 것 중 가장 약한 놈이 달려든다
		var weakest := _lowest_hp_alive()
		if weakest == null:
			return -1
		_last_provoked = weakest.index
		return weakest.index

	var target := get_monster(target_index)
	if target == null or not target.is_alive():
		return -1 # 겨눈 놈을 쓰러뜨렸다 — 죽이면 그만큼 맞지 않는다
	_last_provoked = target.index
	return target.index


func _lowest_hp_alive() -> MonsterState:
	var best: MonsterState = null
	for monster in alive_monsters():
		if best == null or monster.hp < best.hp:
			best = monster
	return best


# 지금 계획대로라면 다음에 반격할 몬스터 (UI가 발밑에 표식을 그릴 때 쓴다). 없으면 -1
func predicted_retaliator() -> int:
	if _resolving:
		return _pending_retaliator

	for entry in reserved:
		if entry["kind"] != ENTRY_CARD:
			continue
		var card: Card = entry["card"]
		if not _targets_enemy_side(card):
			continue
		if card.is_aoe:
			var weakest := _lowest_hp_alive()
			return weakest.index if weakest != null else -1
		var target := get_monster(entry["target_index"])
		if target != null and target.is_alive():
			return target.index
	return -1


# ── 스테이지 전환 ──────────────────────────────────────────────────────────

# 이번 스테이지의 몬스터가 전멸했다. 남은 스테이지가 있으면 전투를 끝내지 않고 보상 선택을 기다린다
func _on_stage_wiped() -> void:
	if stage_pending or battle_over:
		return # 한 라운드에 여러 경로(카드/표식/동료)로 들어와도 정리는 한 번만
	if stage_index < stages.size() - 1:
		stage_pending = true
		# 아직 실행 안 된 예약은 비용을 치르지 않았으므로 그냥 손패로 돌려준다 (다음 스테이지
		# 시작 시 어차피 새 손패를 뽑으므로 자연히 버린 더미로 들어간다)
		_return_reservations_to_hand()
		stage_cleared.emit(stage_index, stages.size())
		return
	_finish_battle(false)


func _return_reservations_to_hand() -> void:
	for entry in reserved:
		if entry["kind"] == ENTRY_CARD:
			hand.cards.append(entry["card"])
	reserved.clear()


# 무기 전환을 그 자리에서 실행한다 (턴당 3회 제한은 WeaponState가 관리).
# 화면이 있는 전투는 이걸 직접 쓰지 않고 reserve_switch()로 큐에 넣는다
func switch_weapon(to: WeaponState.WeaponType) -> bool:
	if battle_over:
		return false
	if not weapon.switch_weapon(to):
		return false
	weapon_switched.emit(to)
	detonate_marks()
	return true


# companion_index 자리 동료가 지금 액티브를 쓸 수 있는지 (party 배열 인덱스, 0=플레이어는 항상 false)
func can_use_companion_active(companion_index: int) -> bool:
	if battle_over or companion_index <= 0 or companion_index >= party.size():
		return false
	return party[companion_index].can_use_active(rounds_completed)


# 동료 액티브를 실제로 발동한다: 조건을 다시 확인하고(더블클릭 등으로 두 번 들어와도 안전),
# 마나를 소모한 뒤 파티 전체에 "다음 적 턴 피해 감소"를 건다.
# 마나가 남아 있는 한 몇 번이든 다시 낼 수 있는 조건(can_use_active)과 별개로, 한 번 쓰면
# CompanionState.active_used_this_round가 그 라운드가 끝날 때까지(tick_round) 재사용을 막는다 —
# 안 그러면 연타할 때마다 마나만 반복해서 깎이고 효과는 last-write로 덮어써질 뿐이라 낭비다
func use_companion_active(companion_index: int) -> bool:
	if not can_use_companion_active(companion_index):
		return false
	var companion = party[companion_index]
	var cost: int = companion.active_mana_cost()
	companion.spend_mana(cost)
	companion.active_used_this_round = true
	var fraction := float(companion.data["active"]["damage_reduction_fraction"])
	_pending_damage_reduction_fraction = fraction

	var magnitude := int(round(fraction * 100))
	for member in party:
		if member.is_alive():
			member.status.apply(StatusEffects.Kind.DAMAGE_REDUCTION, magnitude, 1)

	companion_active_used.emit(companion_index, cost)
	return true


# 카드 효과를 실제로 적용하고, 데미지 카드였다면 입힌 피해량을 반환(그 외에는 0).
# 회복류는 GameState의 기존 헬퍼를 그대로 쓴다 — 다만 그 헬퍼들은 "최대치 대비 비율"을 받는데
# Card.value는 "회복할 체력/마나"라는 절대값이므로, value/최대치로 환산해 넘긴다.
# (헬퍼 안에서 max * fraction = value로 되돌아가 결과적으로 정확히 value만큼 회복되고,
#  최대치 초과 clamp 같은 기존 규칙도 그대로 적용받는다 — 양쪽 계약을 다 지키는 방법)
# 카드 효과를 "대상 목록 전체"에 적용하고, 대상들에게 실제로 들어간 피해의 합을 반환한다.
#
# [광역 처리를 여기 한 곳에 두는 이유] 대상을 정하는 일(resolve_target_indices)과 대상 하나에
# 효과를 넣는 일(_apply_card_effect_to_target)을 분리해 두면, 이 반복 경로는 효과 종류를 전혀
# 몰라도 된다. 그래서 나중에 디버프/버프 효과 타입이 추가돼도 _apply_card_effect_to_target의
# match에 한 갈래만 늘리면 광역판이 저절로 따라온다 — 광역 반복 코드를 다시 쓸 필요가 없다.
#
# 마리별 실제 피해는 last_hit_damage에 자리 번호별로 남겨, 연출이 몬스터마다 제 숫자를 띄우게 한다
func _apply_card_effect(card: Card, target_index: int) -> int:
	last_hit_damage.clear()
	last_trait_result = {"mana_stolen": 0, "hp_leeched": 0}
	# 무작위 배율은 대상과 무관하므로 여기서 딱 한 번 굴려 아래 계산 전체가 같은 결과를 쓰게 한다
	# (대상 계산 안에서 굴리면 광역 도박 카드가 마리마다 따로 굴려진다 — damage_traits.gd 주석 참고)
	_rolled_damage_multiplier = DamageTraits.roll_random_multiplier(card.damage_trait)

	# 힐/셀프버프는 몬스터가 아니라 파티원(0=플레이어, 1+=동료)을 겨냥하므로 완전히 다른 인덱스
	# 공간이다 — resolve_target_indices()(몬스터 전용)를 타지 않고 여기서 바로 갈라야 한다
	if _is_ally_effect(card):
		_apply_ally_effect(card, target_index)
		return 0

	var targets := resolve_target_indices(card, target_index)
	if targets.is_empty():
		# 때릴 대상이 없어도(전멸 직후 등) 자기 자신에게 거는 효과는 그대로 적용돼야 한다
		return _apply_card_effect_to_target(card, -1)

	var total := 0
	for index in targets:
		var dealt := _apply_card_effect_to_target(card, index)
		if dealt > 0:
			last_hit_damage[index] = dealt
		total += dealt
	return total


# 이 카드가 이번에 영향을 줄 몬스터들의 자리 번호.
# 광역기면 살아있는 전원, 아니면 지목된 대상 하나(지목이 없거나 이미 죽었으면 자동 타겟).
# 연출 쪽도 같은 규칙으로 대상을 잡아야 하므로 public으로 열어둔다 — 규칙이 두 벌로 갈라지면
# "때린 대상"과 "이펙트가 뜨는 대상"이 어긋난다
func resolve_target_indices(card: Card, target_index: int) -> Array[int]:
	var indices: Array[int] = []

	if card.is_aoe:
		for monster in alive_monsters():
			indices.append(monster.index)
		return indices

	var target := get_monster(target_index)
	if target == null or not target.is_alive():
		target = get_auto_target()
	if target != null:
		indices.append(target.index)
	return indices


# 대상 하나에 카드 효과를 적용한다 (피해 카드가 아니면 대상과 무관한 자기 효과라 index를 무시).
# 반환값은 그 대상에게 실제로 들어간 피해량 (피해 카드가 아니면 0).
#
# [주의] 자기 자신에게 거는 효과(회복/방어/피하기/반격)는 광역기여도 한 번만 걸려야 한다.
# 지금은 그런 카드에 is_aoe를 켠 것이 없어 문제가 없지만, 나중에 켜게 되면 여기서
# "대상이 필요한 효과"만 반복되도록 갈라줘야 한다
func _apply_card_effect_to_target(card: Card, target_index: int) -> int:
	match card.effect:
		Card.EffectType.DAMAGE:
			return _damage_monster(card, target_index)
		Card.EffectType.DEBUFF_ATTACK_ENEMY:
			var debuff_target := get_monster(target_index)
			if debuff_target == null or not debuff_target.is_alive():
				debuff_target = get_auto_target()
			if debuff_target != null:
				apply_status(debuff_target.index, StatusEffects.Kind.ATTACK_DOWN, card.value, card.secondary_value)
		Card.EffectType.STATUS_PACKAGE:
			apply_status_package(card, target_index)
		Card.EffectType.RESTORE_MANA:
			var max_mana: int = GameState.get_flag("player_max_mana")
			if max_mana > 0:
				GameState.restore_mana_partial(float(card.value) / max_mana)
		Card.EffectType.DEFEND:
			_pending_defense += card.value
		Card.EffectType.DODGE:
			_pending_dodge = true
		Card.EffectType.FREE_NEXT_CARD:
			# 이미 켜져 있어도 그냥 다시 켤 뿐이다 (겹쳐서 두 장이 공짜가 되지는 않는다) —
			# 자료구조가 bool인 것 자체가 "중첩 없음" 규칙이라, 상태이상의 중첩 금지와 같은 방식이다
			_free_next_card = true
		Card.EffectType.COUNTER:
			# 방어와 같은 이유로 합산한다 — 두 장 냈는데 한 장이 조용히 사라지면 손해이기 때문
			_pending_counter += card.value
		Card.EffectType.RESTORE_BOTH:
			var both_max_hp: int = GameState.get_flag("player_max_hp")
			if both_max_hp > 0:
				GameState.heal_player_partial(float(card.value) / both_max_hp)
			var both_max_mana: int = GameState.get_flag("player_max_mana")
			if both_max_mana > 0:
				GameState.restore_mana_partial(float(card.secondary_value) / both_max_mana)
	return 0


# 이 카드가 party 배열(0=플레이어, 1+=동료)을 겨냥하는 종류인지 — 순수 체력회복과 셀프버프만
# 해당한다. 마나회복류는 동료에게 마나 개념이 없어 계속 자기 전용이고, STATUS_PACKAGE는
# 묶음 표가 적을 겨냥하는지로 갈린다(적 대상 묶음이면 false, 그대로 기존 몬스터 경로를 탄다)
func _is_ally_effect(card: Card) -> bool:
	match card.effect:
		Card.EffectType.HEAL_HP, Card.EffectType.BUFF_ATTACK_SELF:
			return true
		Card.EffectType.STATUS_PACKAGE:
			return not StatusEffects.package_targets_enemy(card.status_package)
		_:
			return false


# 힐/셀프버프 카드를 party 배열 기준 대상에게 적용한다. 대상이 유효하지 않으면(범위 밖,
# 이미 쓰러짐) 플레이어(0번)로 떨어뜨린다
func _apply_ally_effect(card: Card, target_index: int) -> void:
	var index := target_index
	if index < 0 or index >= party.size() or not party[index].is_alive():
		index = 0
	var target = party[index]

	match card.effect:
		Card.EffectType.HEAL_HP:
			target.heal(card.value)
		Card.EffectType.BUFF_ATTACK_SELF:
			target.status.apply(StatusEffects.Kind.ATTACK_UP, card.value, card.secondary_value)
			status_applied.emit(index, int(StatusEffects.Kind.ATTACK_UP), card.value, card.secondary_value)
		Card.EffectType.STATUS_PACKAGE:
			for kind in target.status.apply_package(card.status_package, card.secondary_value):
				status_applied.emit(index, int(kind), target.status.get_magnitude(kind), card.secondary_value)


# 데미지 카드 처리: 카드의 기본 위력(value)에 장비 보너스를 더한 뒤, 그 값을 "그 대상의" 저항
# 판정에 통과시킨 최종값을 대상 HP에서 깎는다. 저항은 마리마다 따로 굴리므로, 같은 카드라도
# 누구를 때리느냐에 따라 결과가 달라진다.
#
# 반환값은 카드가 약속한 수치가 아니라 MonsterState.take_damage()가 돌려준 "실제로 깎인 양"이다 —
# 오버킬일 때 팝업 숫자와 HP바 감소폭이 어긋나지 않게 하기 위함(자세한 이유는 take_damage 주석 참고).
# 이미 쓰러진 대상이거나 없는 자리를 지목하면 아무 일도 일어나지 않고 0을 반환한다
func _damage_monster(card: Card, target_index: int) -> int:
	var target := get_monster(target_index)
	if target == null or not target.is_alive():
		target = get_auto_target() # 지목이 없거나(-1) 이미 죽은 대상이면 살아있는 첫 마리로
	if target == null:
		return 0

	var final_damage := calculate_card_damage(card, target)
	var applied := target.take_damage(final_damage)

	_apply_damage_trait(card, target, applied)

	# 맞은 속성을 기억시킨다: 같은 속성으로 두 번 연속 맞으면 적응하고, 반대 속성이면 적응이 깨진다
	var adaptation := target.resistance.register_hit(card.color)
	if adaptation["adapted"] or adaptation["broken"]:
		monster_adapted.emit(target.index, int(target.resistance.current), bool(adaptation["adapted"]), bool(adaptation["broken"]))

	# 표식은 살아 있는 대상에게만 남는다 (쓰러진 뒤에 남겨봐야 터질 곳이 없다)
	if card.switch_mark > 0 and target.is_alive():
		target.status.apply(StatusEffects.Kind.MARK, card.switch_mark, MARK_ROUNDS)
		status_applied.emit(target.index, int(StatusEffects.Kind.MARK), card.switch_mark, MARK_ROUNDS)

	if not target.is_alive():
		monster_defeated.emit(target.index)

	return applied


# 피해를 넣은 "뒤에" 일어나는 부가 성질(흡혈/마력흡수)을 처리한다. 피해 계산을 건드리는 성질
# (처형/도박)은 calculate_card_damage 안에서 이미 끝나 있고, 여기는 "때린 결과로 무언가를 가져오는"
# 쪽만 담당한다 — 그래서 실제 피해량(applied)이 필요하고, 순서가 반드시 take_damage 다음이어야 한다.
#
# 실제로 오간 양만 last_trait_result에 쌓는다: 대상 마나가 모자라면 있는 만큼만 넘어오고, 플레이어
# 최대치를 넘는 분은 버려지므로, 연출이 그 값을 그대로 띄우면 화면과 실제 자원이 어긋나지 않는다
func _apply_damage_trait(card: Card, target: MonsterState, applied: int) -> void:
	var trait_id := card.damage_trait
	if trait_id == "":
		return

	var steal := DamageTraits.steal_mana_amount(trait_id)
	if steal > 0:
		# 대상에게서 실제로 빠진 만큼만 플레이어에게 넘긴다 (없는 마나를 만들어내지 않게)
		var taken := target.drain_mana(steal)
		if taken > 0:
			var max_mana: int = GameState.get_flag("player_max_mana")
			var before: int = GameState.get_flag("player_mana")
			if max_mana > 0:
				GameState.restore_mana_partial(float(taken) / max_mana)
			var gained: int = GameState.get_flag("player_mana") - before
			last_trait_result["mana_stolen"] = int(last_trait_result["mana_stolen"]) + gained

	var leech := DamageTraits.leech_amount(trait_id, applied)
	if leech > 0:
		var max_hp: int = GameState.get_flag("player_max_hp")
		var hp_before: int = GameState.get_flag("player_hp")
		if max_hp > 0:
			GameState.heal_player_partial(float(leech) / max_hp)
		var healed: int = GameState.get_flag("player_hp") - hp_before
		last_trait_result["hp_leeched"] = int(last_trait_result["hp_leeched"]) + healed


# 카드 한 장이 target에게 실제로 입힐 피해를 계산한다. 계산 순서를 이 한 함수에 모아둬,
# 나중에 배율이 더 늘어나도 "어디에 끼워 넣어야 하는지"를 여기서만 보면 되게 했다.
#
# [순서와 그 이유] 공격하는 쪽의 값을 먼저 다 만들고, 그 다음 방어하는 쪽의 배율을 건다:
#
#   1. 기본 위력 + 장비 보너스        (공격자, 덧셈)
#   2. × 플레이어 공격력 버프          (공격자, 곱셈)
#   3. × 속성 저항 감쇄               (방어자, 곱셈 — 저항 약화 디버프가 이 감쇄를 완화한다)
#   4. × 몬스터 방어력 약화            (방어자, 곱셈)
#   5. × 카드 부가 성질 배율            (카드, 곱셈 — 처형의 조건부 배율과 도박의 무작위 배율)
#
# 2번을 저항(3번)보다 "먼저" 두는 게 핵심 판단이다. 장비 보너스가 이미 저항 앞에 더해져 있어서
# (저항이 걸린 턴에는 보너스분도 함께 반감된다), 공격력 버프만 저항 뒤에 두면 같은 "공격을 세게
# 하는 수단"인데 저항을 받는 것과 안 받는 것으로 규칙이 갈린다. "때리는 힘을 모두 합친 한 방을
# 상대가 얼마나 흘려내는가"로 통일하는 편이 설명하기도 쉽고 기존 장비 규칙과도 어긋나지 않는다.
#
# 3번과 4번은 둘 다 방어자 쪽 곱셈이라 순서를 바꿔도 결과가 같다(곱셈의 교환법칙). 그래도
# "저항 → 방어력" 순으로 적어둔 건 읽는 사람이 기존 규칙(저항)을 먼저 만나게 하려는 것뿐이다.
#
# 5번을 맨 끝에 두는 건 카드가 약속한 문구가 "최종 데미지 2배"이기 때문이다 — 저항이 걸린 턴이든
# 아니든 "그 상황에서 나올 피해의 2배"가 되어야 설명 그대로 읽힌다. 앞쪽(2번 자리)에 두면 저항이
# 그 배율까지 반감시켜서, 저항 턴에만 처형이 조용히 약해진다.
#
# 반올림은 마지막에 한 번만 한다 — 단계마다 반올림하면 버프 20%가 붙었는데 피해가 그대로인
# 자투리 오차가 생긴다
func calculate_card_damage(card: Card, target: MonsterState) -> int:
	var raw: float = float(card.value + _equipment_damage_bonus(card))

	# 공격자 측 배율
	raw *= player_status.get_increase_multiplier(StatusEffects.Kind.ATTACK_UP)
	# 각인(스테이지 보상)으로 이번 전투 동안 벼려진 카드
	raw *= 1.0 + float(_card_power_bonus.get(card.card_name, 0.0))
	# 레드라인: 달궈진 무기를 든 채 그 무기 카드를 낼 때만. 적응보다 "앞"에 두어, 적응한 상대에게
	# 레드라인을 쏟으면 보너스까지 같이 반감되게 했다(1.5 x 0.5 = 0.75배) — 뜨거울 때 누구를
	# 때리느냐가 곧 판단거리가 된다
	if _redline_active:
		raw *= 1.0 + WeaponState.REDLINE_DAMAGE_BONUS

	# 방어자 측 배율 — 저항 감쇄는 저항 약화 디버프만큼 완화된다
	var resist_reduction := target.status.get_magnitude(StatusEffects.Kind.RESIST_DOWN)
	var after_resist := target.resistance.calculate_damage(card, int(round(raw)), resist_reduction)
	var after_defense := after_resist * (1.0 + target.status.get_magnitude(StatusEffects.Kind.DEFENSE_DOWN) / 100.0)

	# 카드 부가 성질 배율. 조건부(처형)는 대상 상태만 보므로 여기서 그때그때 구해도 값이 흔들리지 않고,
	# 무작위(도박)는 카드 사용 시점에 이미 한 번 굴려둔 값을 그대로 쓴다
	var trait_multiplier := DamageTraits.conditional_multiplier(card.damage_trait, target.hp, target.max_hp)
	return int(round(after_defense * trait_multiplier * _rolled_damage_multiplier))


# 몬스터가 이번에 때릴 피해량. monster_data의 범위에서 뽑은 뒤 공격력 디버프를 곱한다.
# 최소 0에서 막아 디버프가 100%를 넘어도 회복이 되지 않게 한다
func calculate_monster_attack_damage(attacker: MonsterState) -> int:
	var rolled := randi_range(attacker.monster_data["damage_min"], attacker.monster_data["damage_max"])
	var multiplier := attacker.status.get_decrease_multiplier(StatusEffects.Kind.ATTACK_DOWN)
	# 엘리트/스테이지 보상 대가로 붙은 공격력 배율
	return maxi(0, int(round(rolled * multiplier * attacker.damage_multiplier)))


# ── 버프/디버프 ────────────────────────────────────────────────────────────

# target_index가 -1이면 플레이어 자신, 아니면 그 자리 몬스터에게 상태이상을 건다.
# 대상별로 갈라지는 유일한 지점이라, 새 상태이상 종류가 늘어도 이 함수는 그대로 쓸 수 있다
func apply_status(target_index: int, kind: StatusEffects.Kind, magnitude: int, rounds: int) -> void:
	var container := _status_container_for(target_index)
	if container == null:
		return
	container.apply(kind, magnitude, rounds)
	status_applied.emit(target_index, int(kind), magnitude, rounds)


# 묶음(StatusEffects.PACKAGES) 하나를 대상에게 통째로 건다.
# 대상이 적인 묶음이면 지목된 몬스터(광역기면 호출부가 자리마다 한 번씩 부른다), 자기 묶음이면
# 플레이어에게 건다 — 대상을 고르는 규칙이 여기 한 곳에만 있어서, 새 묶음을 추가해도 이 함수는 그대로다
func apply_status_package(card: Card, target_index: int) -> void:
	var package_id := card.status_package
	if StatusEffects.get_package(package_id).is_empty():
		return

	var container_index := -1
	if StatusEffects.package_targets_enemy(package_id):
		var target := get_monster(target_index)
		if target == null or not target.is_alive():
			target = get_auto_target()
		if target == null:
			return
		container_index = target.index

	var container := _status_container_for(container_index)
	if container == null:
		return

	for kind in container.apply_package(package_id, card.secondary_value):
		status_applied.emit(container_index, int(kind), container.get_magnitude(kind), card.secondary_value)


func _status_container_for(target_index: int) -> StatusEffects:
	if target_index < 0:
		return player_status
	var monster := get_monster(target_index)
	return monster.status if monster != null else null


# 한 라운드가 끝났을 때(적 전원의 턴이 한 바퀴 돈 뒤) 모든 대상의 상태이상을 1라운드씩 줄인다.
# 플레이어와 몬스터를 같은 자리에서 처리해, 한쪽만 깎이거나 두 번 깎이는 어긋남이 생기지 않게 했다.
# 쓰러진 몬스터도 그대로 돌린다 — 어차피 다시 살아나지 않으므로 결과에 영향이 없고,
# 살아있는지 확인하는 분기를 넣는 쪽이 오히려 규칙을 복잡하게 만든다
func _tick_status_rounds() -> void:
	for kind in player_status.tick_round():
		status_expired.emit(-1, int(kind))
	for monster in monsters:
		for kind in monster.status.tick_round():
			status_expired.emit(monster.index, int(kind))
		if monster.is_alive() and monster.resistance.tick_round():
			monster_adapted.emit(monster.index, int(EnemyResistance.ResistanceType.NONE), false, true)
	# 동료도 카드로 상태이상을 받을 수 있으니(_apply_ally_effect) 플레이어/몬스터와 같이 여기서 깎아야
	# 한다 — 안 그러면 한 번 걸린 버프가 라운드가 지나도 안 풀린다
	for i in range(1, party.size()):
		party[i].status.tick_round()


# 장비의 피해 보너스. "카드 색깔이 지금 장착한 무기와 일치할 때"만 그 무기의 등급 보너스가 붙는다
# (검을 든 채 마법 카드를 쓰면 지팡이 보너스는 붙지 않음). 공용 카드는 무기와 무관해 항상 0.
#
# 판정 조건을 WeaponState.weapon_type_for_card()로 두는 이유: 과열 게이지가 차오르는 조건
# (WeaponState.register_card_use)이 바로 이 "카드 색 == 장착 무기"인데, 보너스도 같은 함수로
# 같은 조건을 쓰면 두 규칙이 서로 어긋날 수 없다. 결과적으로 장착 무기와 다른 색 카드를 쓰면
# 게이지도 안 오르고 보너스도 못 받아, 무기를 제대로 바꿔 쓰라는 압박이 한 방향으로 일관되게 걸린다.
#
# 연산 순서는 그대로다 — 여기서 나온 보너스를 card.value에 더한 뒤 저항 배율이 걸리므로,
# 저항이 걸린 턴에는 보너스분도 함께 반감된다
func _equipment_damage_bonus(card: Card) -> int:
	if not card.uses_weapon():
		return 0
	if WeaponState.weapon_type_for_card(card) != weapon.equipped:
		return 0

	if weapon.equipped == WeaponState.WeaponType.SWORD:
		return GameState.get_sword_damage_bonus()
	return GameState.get_staff_damage_bonus()


# ── 턴 종료 / 적 턴 ────────────────────────────────────────────────────────

# 플레이어가 턴을 넘긴다 (연출 없는 호출부 전용 — 화면 있는 전투는 아래 3단계를 직접 부른다)
func end_turn() -> void:
	if battle_over:
		return

	begin_round_resolution()
	while not battle_over and not stage_pending and has_reservations():
		var result := execute_next_reservation()
		if battle_over or stage_pending:
			break
		if bool(result.get("provokes", true)):
			take_next_monster_action()
	finish_round_resolution()


# ── 라운드 해결 3단계 ──────────────────────────────────────────────────────
# 연출이 붙는 battle_scene은 이 셋을 직접 불러 카드 한 장 / 몬스터 한 번 사이에 애니메이션을 끼워
# 넣고, 연출이 필요 없는 호출부(테스트 등)는 위 end_turn()으로 한 번에 돌린다. 규칙은 한 곳에만 있다

# 1) 라운드 시작: 동료들이 각자 한 번씩 행동한다 (예약 카드 수와 무관하게 라운드당 1회)
func begin_round_resolution() -> void:
	_resolving = true
	_resolve_companion_turn()
	# 동료 공격으로 몬스터가 전멸했으면 카드 교환을 시작하지 않고 바로 스테이지/전투 정리로 넘어간다
	if all_monsters_defeated():
		_on_stage_wiped()


# 3) 라운드 마무리: 임시 상태를 털고, 라운드 단위 카운터를 딱 한 번씩 굴린 뒤 다음 턴을 연다.
# 카드를 몇 장 냈든(교환을 몇 번 했든) 이 함수는 턴종료 1회당 1번만 불린다 —
# 상태이상 감소, 무기 봉쇄 해제, 동료 패시브 카운터가 교환 수만큼 빨라지면 안 되기 때문
func finish_round_resolution() -> void:
	_resolving = false

	if battle_over:
		reserved.clear()
		return

	# 임시 상태는 이번 라운드에서만 유효 — 결과와 무관하게 소모하고 초기화한다
	_pending_defense = 0
	_pending_dodge = false
	_pending_counter = 0
	_pending_damage_reduction_fraction = 0.0

	rounds_completed += 1
	_tick_status_rounds()
	weapon.tick_round() # 과부하 봉쇄도 라운드 단위다
	# "첫 라운드 카드 비용 0"(선제 보상)은 이 라운드로 끝난다
	_free_round_active = false
	for i in range(1, party.size()):
		party[i].tick_round()
		if party[i].consume_passive_trigger():
			_trigger_party_passive_heal(i)

	if not stage_pending:
		_return_reservations_to_hand()

	if _is_party_wiped():
		_finish_battle(true)
		return

	# 스테이지를 깬 상태면 다음 턴은 보상 선택이 끝난 뒤(advance_stage)에 열린다
	if stage_pending:
		return

	# 반격으로 적이 쓰러졌을 수 있다. 이 검사가 없으면 전멸한 상대로 다음 턴이 열린다
	if all_monsters_defeated():
		_on_stage_wiped()
		if stage_pending or battle_over:
			return

	_start_turn()


# 동료 전원이 각자 한 번씩 자동으로 공격한다 (조작 없음, 쉬는 턴 없음 — Q8 확정).
# 대상은 살아있는 몬스터 중 가중치 없이 무작위로 고른다. 몬스터가 전멸하면 남은 동료는 공격하지 않는다.
# 마나가 바닥난 동료는 공격 대신 그 턴을 회복에 쓴다 (take_next_monster_action이 몬스터에게 하는 것과 같은 방식 — §7)
func _resolve_companion_turn() -> void:
	for i in range(1, party.size()):
		var companion = party[i]
		if not companion.is_alive():
			continue
		if not companion.can_attack():
			var gained: Dictionary = companion.recover()
			companion_recovered.emit(i, gained["mana"], gained["hp"])
			continue
		var alive := alive_monsters()
		if alive.is_empty():
			return
		var target: MonsterState = alive[randi() % alive.size()]
		companion.spend_attack_mana()
		var dealt := target.take_damage(companion.roll_attack_damage())
		companion_attack_resolved.emit(i, target.index, dealt)
		if not target.is_alive():
			monster_defeated.emit(target.index)


# 적의 반격. 피해량 산출은 battle_scene.gd의 기존 방식(damage_min~damage_max 무작위)을 그대로 쓰고,
# 적용은 GameState.damage_player()로 한다.
#
# [설계 결정 — 스펙에 세부 규칙이 없어 직접 정한 부분]
# 1. 피하기(DODGE)는 이번 적 공격을 완전히 무효화한다(피해 0). 기존 battle_scene.gd의 _dodging이
#    정확히 그렇게 동작했고("몬스터 공격은 완전히 회피"), 재설계 스펙도 피하기를 "회피"로만 규정해
#    부분 경감이 아니라 전무효로 두는 게 기존 감각과 일치한다. 그래서 누적 개념 없이 bool이다 —
#    "완전히 피한다"는 두 번 겹쳐도 더 좋아질 여지가 없기 때문.
# 2. 방어(DEFEND)는 card.value만큼 피해를 깎고, 여러 장 내면 합산된다. 한 턴에 5장을 자유 순서로
#    낼 수 있는 구조라 같은 방어 카드를 두 장 낼 수 있는데, 덮어쓰기(더 큰 값만 채택)로 하면
#    플레이어가 쓴 카드 한 장이 조용히 사라져 손해를 보게 된다. 합산이 "낸 만큼 효과를 본다"는
#    직관에 맞고, 과하면 카드 수치로 조절하면 된다.
# 3. 피하기와 방어를 같이 걸면 피하기가 먼저 적용돼 어차피 피해가 0이 되고, 남은 방어값은 그대로
#    소멸한다(다음 턴으로 이월되지 않음). 둘 다 "다음 적 턴에만 적용되는 임시 상태"라는 요구사항을
#    문자 그대로 지키기 위해, 적 턴을 해결한 직후 무조건 초기화한다.
# 4. 반격(COUNTER)은 피하기처럼 이번 공격을 완전 무효화하면서, 동시에 적에게 예약해둔 만큼 되돌려준다.
#    반격 피해에는 적 저항도 장비 보너스도 붙지 않는데, 이건 특례가 아니라 일관성이다 — 반격 카드는
#    공용(NEUTRAL)이고, 공용 카드는 원래도 저항 대상이 아니며(EnemyResistance.resists) 무기 보너스도
#    받지 않는다(_equipment_damage_bonus). 즉 카드로 직접 때렸을 때와 같은 계산 결과가 나온다.
#
# [교환 규칙] 카드 한 장이 실행될 때마다 몬스터가 딱 한 번 응수한다. 누가 응수하는지는 라운드로빈이
# 아니라 도발이 정한다 — 방금 때린 놈이 곧바로 되받아치고(_resolve_provoke), 광역기는 살아남은
# 것 중 가장 약한 놈이 달려든다. 겨눈 대상을 그 카드로 쓰러뜨렸으면 그 교환에는 응수가 없다.
# 무기 전환은 카드가 아니므로 응수를 부르지 않는다.
#
# [방어/피하기/반격이 마리 수만큼 뻥튀기되지 않게 하는 규칙]
#  - 피하기/반격은 "가장 먼저 오는 공격 한 방"에만 쓰이고 그 자리에서 소모된다.
#  - 방어는 "값만큼의 피해를 흡수하는 총량 풀"로 동작한다(흡수한 만큼 풀에서 깎인다).
#  - 반격은 "때린 그 몬스터"에게 되돌려준다 (자동 타겟이 아니라 공격자).
# 셋 다 라운드가 끝날 때 finish_round_resolution()에서 한꺼번에 털린다
func take_next_monster_action() -> Dictionary:
	if battle_over or stage_pending or _is_party_wiped():
		return {"acted": false, "index": -1}

	var actor := get_monster(_pending_retaliator)
	if actor == null or not actor.is_alive():
		return {"acted": false, "index": -1}

	# 마나가 남아 있으면 공격, 바닥났으면 그 차례는 숨고르기(회복)
	if actor.can_attack():
		actor.spend_attack_mana()
		_resolve_single_attack(actor, _pick_attack_target())
	else:
		var gained := actor.recover()
		monster_recovered.emit(actor.index, gained["mana"], gained["hp"])

	return {"acted": true, "index": actor.index}


# 동료 패시브(§7 "파티 전체 5턴 회복") 발동 효과: 살아있는 파티원 전원의 체력/마력을 각각
# 최대치의 10%씩 회복한다. 플레이어는 기존 마나회복 카드와 같은 GameState 헬퍼를 재사용하고,
# 동료는 CompanionState.heal/restore_mana로 같은 비율을 적용한다
const PARTY_PASSIVE_HEAL_FRACTION := 0.1

func _trigger_party_passive_heal(source_index: int) -> void:
	var results: Array = []
	for i in range(party.size()):
		var member = party[i]
		if not member.is_alive():
			continue
		if i == 0:
			var hp_before: int = GameState.get_flag("player_hp")
			var mana_before: int = GameState.get_flag("player_mana")
			GameState.heal_player_partial(PARTY_PASSIVE_HEAL_FRACTION)
			GameState.restore_mana_partial(PARTY_PASSIVE_HEAL_FRACTION)
			results.append({
				"index": 0,
				"hp": GameState.get_flag("player_hp") - hp_before,
				"mana": GameState.get_flag("player_mana") - mana_before,
			})
		else:
			var hp_healed: int = member.heal(int(round(member.max_hp * PARTY_PASSIVE_HEAL_FRACTION)))
			var mana_healed: int = member.restore_mana(int(round(member.max_mana * PARTY_PASSIVE_HEAL_FRACTION)))
			results.append({"index": i, "hp": hp_healed, "mana": mana_healed})
	party_passive_healed.emit(source_index, results)


# 살아있는 파티원이 하나도 없는지 (몬스터 반격 도중 파티 전멸 여부를 매 마리 공격 전에 확인하는 데 쓰인다)
func _is_party_wiped() -> bool:
	for member in party:
		if member.is_alive():
			return false
	return true


# 살아있는 파티원 중 하나를 가중치 랜덤으로 고른다 (party 배열 인덱스를 반환).
# 몬스터마다 새로 추첨하므로, 같은 턴 안에서도 마리별로 다른 대상을 때릴 수 있다
func _pick_attack_target() -> int:
	var candidates: Array[int] = []
	var total_weight := 0
	for i in range(party.size()):
		if not party[i].is_alive():
			continue
		candidates.append(i)
		total_weight += TARGET_WEIGHT_PLAYER if i == 0 else TARGET_WEIGHT_COMPANION

	if total_weight <= 0: # 살아있는 후보가 전부 가중치 0일 때의 안전망 (지금은 사실상 도달 안 함)
		return candidates[randi() % candidates.size()]

	var roll := randi() % total_weight
	for i in candidates:
		var weight := TARGET_WEIGHT_PLAYER if i == 0 else TARGET_WEIGHT_COMPANION
		if roll < weight:
			return i
		roll -= weight
	return candidates[-1]


# 몬스터 한 마리의 공격을 해결한다. 피하기/반격은 여기서 소모되므로, 뒤이어 공격하는 몬스터는
# 그 보호를 받지 못한다 (위 take_next_monster_action 주석의 "뻥튀기 방지" 규칙).
# 방어/피하기/반격은 플레이어를 지키는 카드라 target이 플레이어(0번)일 때만 적용된다 —
# 동료를 때리는 공격은 이 카드들을 소모하지 않고 그대로 지나간다
func _resolve_single_attack(attacker: MonsterState, target_index: int) -> void:
	var raw_damage := calculate_monster_attack_damage(attacker)
	# 마력장벽의 % 감소를 먼저 적용한 뒤, 아래에서 플레이어의 고정값 방어(_pending_defense)를 뺀다 —
	# 순서를 반대로 하면 방어가 이미 깎은 만큼에 %를 또 곱하게 돼 방어의 값어치가 뒤바뀐다
	if _pending_damage_reduction_fraction > 0.0:
		raw_damage = int(round(raw_damage * (1.0 - _pending_damage_reduction_fraction)))
	var target = party[target_index]
	var targeting_player := target_index == 0

	var countering := targeting_player and _pending_counter > 0
	var dodging := targeting_player and _pending_dodge

	var damage_taken := 0
	var counter_damage := 0

	if countering:
		counter_damage = _pending_counter
		_pending_counter = 0 # 첫 공격에 소모
		attacker.take_damage(counter_damage)
		if not attacker.is_alive():
			monster_defeated.emit(attacker.index)
	elif dodging:
		_pending_dodge = false # 첫 공격에 소모
	else:
		var absorbed := 0
		if targeting_player:
			absorbed = min(_pending_defense, raw_damage)
			_pending_defense -= absorbed
		damage_taken = raw_damage - absorbed
		if damage_taken > 0:
			target.take_damage(damage_taken)

	enemy_attack_resolved.emit(attacker.index, target_index, damage_taken, dodging, counter_damage)


func _finish_battle(player_lost: bool) -> void:
	if battle_over:
		return
	battle_over = true
	if player_lost:
		player_defeated.emit()
	else:
		enemy_defeated.emit()


# ── 조회용 헬퍼 (UI가 붙을 때 쓰기 좋은 읽기 전용 정보) ────────────────────

# 그룹 전체가 같은 종류라 최대 체력도 마리마다 같다 (마리별 값이 필요하면 MonsterState.max_hp를 볼 것)
func get_monster_max_hp() -> int:
	return monster_data["max_hp"]


# 손패를 전부 소진했는지. 전투 씬이 "자동 턴 종료" 조건으로 쓴다.
#
# [왜 "낼 수 있는 카드가 없다"가 아니라 "손패가 비었다"인가]
# 카드가 남았는데 전부 과부하/자원부족이면 사실 그 턴에 카드를 더 낼 방법은 없다 — 과부하는 카드
# 색깔 기준이라 무기를 바꿔도 안 풀리고(WeaponState.can_use_card), 자원을 채워줄 회복 카드마저
# 못 내는 상황이기 때문이다. 그런데도 그때는 자동으로 넘기지 않는다: 도망가기가 여전히 유효한 턴
# 행동이라, 자동 종료해버리면 플레이어가 도망칠 기회를 쓰지 못한 채 적 공격을 강제로 맞게 된다.
# 반면 손패를 다 쓴 경우는 플레이어가 이미 5번의 선택을 끝낸 뒤라 "턴 종료" 클릭이 형식적이므로,
# 그것만 대신 눌러주는 것이고 선택지를 뺏지 않는다
func is_hand_exhausted() -> bool:
	return hand.is_empty()


# 이번 적 턴에 대비해 쌓아둔 방어량 (피하기 중이면 어차피 전무효라 별개로 확인할 것)
func get_pending_defense() -> int:
	return _pending_defense


func is_dodging() -> bool:
	return _pending_dodge


# 이번 적 턴에 되돌려줄 반격 피해량 (0이면 반격 대기 아님)
func get_pending_counter() -> int:
	return _pending_counter
