extends Node

# 개편한 전투를 화면 없이 수백 판 돌려 밸런스를 재는 도구.
#   godot --headless res://tests/battle_sim.tscn -- <판수> <몬스터타입> <체력> <마나>
# 승률만이 아니라 "무엇이 실제로 일어났는지"(과부하 횟수, 적응 횟수, 표식 폭발, 처치로 넘긴 반격)를
# 같이 세서, 시스템이 서로 맞물려 돌아가는지를 수치로 확인한다

const MAX_ROUNDS := 60

var _wins := 0
var _losses := 0
var _rounds_total := 0
var _stages_cleared := 0
var _stage_count_total := 0
var _hp_left_total := 0
var _overloads := 0
var _redline_hits := 0
var _adaptations := 0
var _breaks := 0
var _mark_hits := 0
var _skipped_retaliations := 0
var _cards_played := 0
var _switches := 0
var _loss_stage_histogram: Dictionary = {}
var _damage_taken := 0
var _hits_taken := 0
var _monster_rests := 0
var _single_stage := false
var _trace := false
var _timeouts := 0


# 레벨별 대표 캐릭터. 체력/마나는 GameState의 성장치(레벨당 +3/+3)를 그대로 따르고, 해금 카드는
# 그 레벨쯤이면 스킬포인트로 풀었을 법한 수준으로 잡았다 (레벨업 1회 = 3점, 티어1 1점 / 티어2 3점)
const LEVEL_UNLOCKS := {
	1: [],
	3: ["stab", "ice_arrow", "threaten"],
	5: ["stab", "ice_arrow", "threaten", "flash_slash", "fireball", "spin_slash", "lightning_spear", "blood_drain", "haste"],
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var battles := int(args[0]) if args.size() > 0 else 200
	var monster_type: String = args[1] if args.size() > 1 else "ORC"
	var level := int(args[2]) if args.size() > 2 else 1
	var mode: String = args[3] if args.size() > 3 else ""
	_single_stage = mode == "single"
	_trace = mode == "trace"

	# 튜닝 스윕용 덮어쓰기: hp=0.4,0.5,0.6,0.7 dmg=0.6,0.7,0.8,0.9 atk=40,55
	for arg in args.slice(4):
		var pair: PackedStringArray = String(arg).split("=")
		if pair.size() != 2:
			continue
		var values: Array[float] = []
		for part in pair[1].split(","):
			values.append(float(part))
		match pair[0]:
			"hp":
				BattleStages.STAGE_HP_SCALE = values
			"dmg":
				BattleStages.STAGE_DAMAGE_SCALE = values
			"red":
				WeaponState.REDLINE_THRESHOLD = int(values[0])
				WeaponState.REDLINE_DAMAGE_BONUS = values[1]
				WeaponState.OVERLOAD_LOCK_ROUNDS = int(values[2])
			"tfs":
				BattleStages.TYPE_DIFFICULTY = {"ORC": values[0], "SKELETON": values[1], "MUMMY": values[2]}
			"tf":
				BattleStages.TYPE_DIFFICULTY[monster_type] = values[0]
			"adapt":
				EnemyResistance.HITS_TO_ADAPT = int(values[0])
				EnemyResistance.RESIST_DAMAGE_MULTIPLIER = values[1]
			"atk":
				MonsterState.ATTACK_COST_MIN = int(values[0])
				MonsterState.ATTACK_COST_MAX = int(values[1])
				MonsterState.LOW_MANA_THRESHOLD = int(values[0])

	var hp := 25 + 3 * (level - 1)
	var mana := 20 + 3 * (level - 1)

	seed(20260913)
	GameState.active_companions.clear()
	GameState.battle_deck.clear()
	GameState.unlocked_cards = CardLibrary.DEFAULT_UNLOCKED.duplicate()
	var unlocks: Array = CardLibrary.all_ids() if level >= 8 else LEVEL_UNLOCKS.get(level, LEVEL_UNLOCKS[5] if level > 5 else LEVEL_UNLOCKS[3] if level >= 3 else [])
	for card_id in unlocks:
		if not GameState.unlocked_cards.has(card_id):
			GameState.unlocked_cards.append(card_id)

	for i in range(battles):
		_run_battle(monster_type, hp, mana)

	_report(battles, "%s Lv%d" % [monster_type, level], hp, mana)
	get_tree().quit(0)


func _run_battle(monster_type: String, hp: int, mana: int) -> void:
	GameState.set_flag("player_base_max_hp", hp)
	GameState.set_flag("player_max_hp", hp)
	GameState.set_flag("player_hp", hp)
	GameState.set_flag("player_max_mana", mana)
	GameState.set_flag("player_mana", mana)

	var manager := BattleTurnManager.new(monster_type, [], StarterDeck.build())
	manager.weapon_overloaded.connect(func(_w: int) -> void: _overloads += 1)
	manager.monster_adapted.connect(func(_i: int, _t: int, adapted: bool, broken: bool) -> void:
		if adapted:
			_adaptations += 1
		if broken:
			_breaks += 1
	)
	manager.stage_cleared.connect(func(_index: int, _count: int) -> void: _stages_cleared += 1)
	manager.enemy_attack_resolved.connect(func(_a: int, _t: int, dmg: int, _d: bool, _c: int) -> void:
		_hits_taken += 1
		_damage_taken += dmg
	)
	manager.monster_recovered.connect(func(_i: int, _m: int, _h: int) -> void: _monster_rests += 1)
	if _single_stage:
		# 기준선: 스테이지 없이 필드 조우 한 무리(원래 체력)만 상대하는 예전 방식
		var variants: Array[Dictionary] = []
		for i in range(BattleData.roll_group_size(monster_type)):
			variants.append(BattleData.pick_variant(monster_type))
		var elites: Array[bool] = []
		elites.resize(variants.size())
		elites.fill(false)
		manager.stages = [{"variants": variants, "elites": elites}]
		manager._spawn_stage(0)
	manager.start()
	_stage_count_total += manager.stage_count()

	var rounds := 0
	var guard := 0
	while not manager.battle_over and rounds < MAX_ROUNDS:
		guard += 1
		if guard > MAX_ROUNDS * 4:
			push_error("SIM STUCK: stage=%d pending=%s rounds=%d hand=%d alive=%d" % [
				manager.stage_index, str(manager.stage_pending), rounds,
				manager.hand.cards.size(), manager.alive_monsters().size()])
			break
		if manager.stage_pending:
			_take_reward(manager)
			manager.advance_stage()
			continue
		rounds += 1
		_plan_round(manager)
		if _trace:
			_print_trace(manager, rounds)
		_resolve_round(manager)

	_rounds_total += rounds
	if manager.battle_over and not _is_defeated():
		_wins += 1
		_stages_cleared += 1 # 마지막 스테이지
		_hp_left_total += int(GameState.get_flag("player_hp"))
	else:
		_losses += 1
		if not _is_defeated():
			_timeouts += 1
		_loss_stage_histogram[manager.stage_index] = int(_loss_stage_histogram.get(manager.stage_index, 0)) + 1


func _is_defeated() -> bool:
	return int(GameState.get_flag("player_hp")) <= 0


# 한 라운드 계획: 표식이 있으면 전환으로 터뜨리고, 낼 수 있는 카드를 가치순으로 예약한다
func _plan_round(manager: BattleTurnManager) -> void:
	if manager.has_marks() and manager.can_reserve_switch():
		manager.reserve_switch()

	for i in range(8):
		var card := _pick_card(manager)
		if card == null:
			break
		if not manager.reserve_card(card, _pick_target(manager, card)):
			break
		# 표식을 새로 걸었으면 이번 라운드 안에 터뜨리는 쪽이 이득이다
		if manager.has_marks() and manager.can_reserve_switch() and randf() < 0.7:
			manager.reserve_switch()


func _pick_card(manager: BattleTurnManager) -> Card:
	# 카드 1장 = 반격 1회 구조라 값어치 없는 카드를 내는 건 공짜 피격을 사는 셈이다 — 실제 플레이어처럼 거른다
	var best: Card = null
	var best_score := 0.5
	var fallback: Card = null
	for card in manager.hand.cards:
		if not manager.can_play_card(card):
			continue
		var score := _score_card(manager, card)
		if score > best_score:
			best_score = score
			best = card
		elif score == OVERLOAD_ONLY and (fallback == null or card.value > fallback.value):
			fallback = card
	# 다른 수가 없으면 과부하를 각오하고 지른다 — 달아오른 게이지를 0으로 되돌리는 유일한 길이기도 하다
	if best == null and manager.reserved.is_empty():
		return fallback
	return best


const OVERLOAD_ONLY := -1.0


# 적응한 속성으로 때리는 건 값어치가 반이고, 레드라인 구간이면 그 무기 카드가 더 세다 —
# AI도 그 둘을 보고 고르게 해야 시스템이 실제로 굴러갔을 때의 수치가 나온다
func _score_card(manager: BattleTurnManager, card: Card) -> float:
	if card.effect != Card.EffectType.DAMAGE:
		# 체력이 절반 아래면 회복/방어 카드에 값어치를 준다
		var hp_ratio := float(GameState.get_flag("player_hp")) / maxf(1.0, float(GameState.get_flag("player_max_hp")))
		if card.effect == Card.EffectType.RESTORE_MANA and int(GameState.get_flag("player_mana")) < 6 and hp_ratio > 0.4:
			return 6.0
		if hp_ratio < 0.6 and card.effect in [Card.EffectType.HEAL_HP, Card.EffectType.RESTORE_BOTH, Card.EffectType.DEFEND, Card.EffectType.DODGE, Card.EffectType.COUNTER]:
			return 9.0
		return 0.0 # 필요 없을 때 내면 공짜 반격만 산다

	var score := float(card.value)
	var target := _weakest(manager)
	var planned: WeaponState = manager.display_weapon()
	var redline := planned.is_redline_for_card(card)
	if redline:
		score *= 1.5
	if target != null:
		var element := EnemyResistance.type_for_color(card.color)
		if target.resistance.resists(card.color):
			score *= EnemyResistance.RESIST_DAMAGE_MULTIPLIER
		elif element != EnemyResistance.ResistanceType.NONE and target.resistance.pending_type() == element:
			score *= 0.8
		# 이 카드로 과부하가 나는데 막타도 못 치면 손해 — 봉쇄 2라운드가 그 한 방보다 비싸다
		if redline and card.uses_weapon() and planned.get_gauge(planned.equipped) + WeaponState.GAUGE_STEP >= WeaponState.GAUGE_MAX:
			if float(card.value) * 1.5 < float(target.hp):
				return OVERLOAD_ONLY
	if card.switch_mark > 0 and manager.can_reserve_switch():
		score += card.switch_mark
	if card.is_aoe and manager.alive_monsters().size() > 1:
		score *= 1.6
	return score


func _pick_target(manager: BattleTurnManager, card: Card) -> int:
	if card.is_aoe or card.effect != Card.EffectType.DAMAGE:
		return -1
	var target := _weakest(manager)
	return target.index if target != null else -1


func _weakest(manager: BattleTurnManager) -> MonsterState:
	var best: MonsterState = null
	for monster in manager.alive_monsters():
		if best == null or monster.hp < best.hp:
			best = monster
	return best


func _resolve_round(manager: BattleTurnManager) -> void:
	manager.begin_round_resolution()
	while not manager.battle_over and not manager.stage_pending and manager.has_reservations():
		var result := manager.execute_next_reservation()
		if result["kind"] == BattleTurnManager.ENTRY_SWITCH:
			_switches += 1
			for hit in result.get("detonations", []):
				_mark_hits += 1
		elif bool(result.get("played", false)):
			_cards_played += 1
			if bool(result.get("redline", false)):
				_redline_hits += 1

		if manager.battle_over or manager.stage_pending:
			break
		if not bool(result.get("provokes", true)):
			continue
		if not bool(manager.take_next_monster_action()["acted"]):
			_skipped_retaliations += 1
	manager.finish_round_resolution()


# 보상은 상황을 보고 고른다 (체력이 급하면 회복, 무기가 막혔으면 냉각, 아니면 무작위)
func _take_reward(manager: BattleTurnManager) -> void:
	var offers := BattleStages.roll_offers(manager.stage_reward_context())
	if offers.is_empty():
		return

	var hp_ratio := float(GameState.get_flag("player_hp")) / maxf(1.0, float(GameState.get_flag("player_max_hp")))
	var picked: Dictionary = offers[randi() % offers.size()]
	for offer in offers:
		var effect: Dictionary = offer["effect"]
		if hp_ratio < 0.5 and effect.has("heal_fraction"):
			picked = offer
			break
		if manager.weapon.is_overheated(WeaponState.WeaponType.SWORD) or manager.weapon.is_overheated(WeaponState.WeaponType.STAFF):
			if effect.has("cool_weapons"):
				picked = offer
				break
	manager.apply_stage_reward(picked)


func _report(battles: int, monster_type: String, hp: int, mana: int) -> void:
	var total := float(maxi(1, battles))
	print("\n=== %s · 체력 %d / 마나 %d · %d판 ===" % [monster_type, hp, mana, battles])
	print("승률            : %.1f%% (%d승 %d패)" % [_wins / total * 100.0, _wins, _losses])
	print("평균 라운드      : %.1f" % (_rounds_total / total))
	print("평균 스테이지 수 : %.2f (깬 스테이지 평균 %.2f)" % [_stage_count_total / total, _stages_cleared / total])
	if _wins > 0:
		print("승리 시 남은 체력: %.1f / %d" % [float(_hp_left_total) / _wins, hp])
	print("판당 카드        : %.1f장, 전환 %.1f회" % [_cards_played / total, _switches / total])
	print("판당 레드라인 타격: %.2f회, 과부하 %.2f회" % [_redline_hits / total, _overloads / total])
	print("판당 적응        : %.2f회 (붕괴 %.2f회)" % [_adaptations / total, _breaks / total])
	print("판당 표식 폭발   : %.2f회" % (_mark_hits / total))
	print("판당 처치로 넘긴 반격: %.2f회" % (_skipped_retaliations / total))
	print("판당 피격        : %.1f회 / 피해 %.1f / 몬스터 휴식 %.1f회" % [_hits_taken / total, _damage_taken / total, _monster_rests / total])
	print("교착(타임아웃)   : %d판" % _timeouts)
	if not _loss_stage_histogram.is_empty():
		var parts: Array[String] = []
		for key in _loss_stage_histogram.keys():
			parts.append("%d스테이지 %d패" % [int(key) + 1, int(_loss_stage_histogram[key])])
		print("패배 지점        : %s" % ", ".join(parts))


func _print_trace(manager: BattleTurnManager, rounds: int) -> void:
	var hand: Array[String] = []
	for card in manager.hand.cards:
		hand.append("%s%s" % [card.card_name, "" if manager.can_play_card(card) else "x"])
	var queue: Array[String] = []
	for entry in manager.reserved:
		queue.append("전환" if entry["kind"] == BattleTurnManager.ENTRY_SWITCH else String(entry["card"].card_name))
	var mons: Array[String] = []
	for monster in manager.monsters:
		mons.append("%d/%d%s%s" % [monster.hp, monster.max_hp, "E" if monster.is_elite else "", ["", "P", "M"][monster.resistance.current]])
	print("S%d R%d hp=%d mana=%d gauge=%d/%d lock=%d/%d | 손패 %s | 큐 %s | 몹 %s" % [
		manager.stage_index + 1, rounds, GameState.get_flag("player_hp"), GameState.get_flag("player_mana"),
		manager.weapon.sword_gauge, manager.weapon.staff_gauge, manager.weapon.sword_lock_rounds, manager.weapon.staff_lock_rounds,
		", ".join(hand), ", ".join(queue), ", ".join(mons)])
