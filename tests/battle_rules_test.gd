extends Node

# 개편한 전투 규칙(레드라인 / 템포 체인 / 도발 / 적응 / 스테이지)을 화면 없이 검증한다.
#   godot --headless res://tests/battle_rules_test.tscn
# 실패가 하나라도 있으면 종료 코드 1로 나간다

var _passed := 0
var _failed := 0


func _ready() -> void:
	seed(12345)
	_prepare_player()

	_test_redline_bonus()
	_test_overload_lock()
	_test_tempo_chain()
	_test_provoke_single_target()
	_test_provoke_aoe_picks_weakest()
	_test_kill_skips_retaliation()
	_test_adaptation()
	_test_adaptation_vs_redline()
	_test_queue_planning()
	_test_switch_is_free_tempo()
	_test_stage_progression()
	_test_stage_reward_effects()
	_test_round_invariants()

	print("\n=== 결과: %d 통과 / %d 실패 ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# ── 검증 헬퍼 ──────────────────────────────────────────────────────────────

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("[OK] %s %s" % [label, detail])
	else:
		_failed += 1
		print("[FAIL] %s %s" % [label, detail])


func _check_eq(label: String, actual, expected) -> void:
	_check(label, actual == expected, "(실제 %s / 기대 %s)" % [str(actual), str(expected)])


func _prepare_player() -> void:
	GameState.active_companions.clear()
	GameState.set_flag("player_max_hp", 200)
	GameState.set_flag("player_hp", 200)
	GameState.set_flag("player_max_mana", 200)
	GameState.set_flag("player_mana", 200)


func _make_card(name_: String, color: int, value: int, mana := 0, aoe := false, mark := 0) -> Card:
	var card := Card.new()
	card.card_name = name_
	card.color = color
	card.effect = Card.EffectType.DAMAGE
	card.value = value
	card.mana_cost = mana
	card.is_aoe = aoe
	card.switch_mark = mark
	return card


# 테스트용 전투: 스테이지 구성을 직접 덮어써 원하는 마리 수/편성으로 고정한다
func _make_battle(cards: Array[Card], monster_counts: Array = [1], elite_flags: Array = []) -> BattleTurnManager:
	_prepare_player()
	var manager := BattleTurnManager.new("ORC", [], cards)
	var stages: Array[Dictionary] = []
	for i in range(monster_counts.size()):
		var variants: Array[Dictionary] = []
		var elites: Array[bool] = []
		for slot in range(int(monster_counts[i])):
			variants.append(BattleData.pick_variant("ORC"))
			var flags: Array = elite_flags[i] if i < elite_flags.size() else []
			elites.append(bool(flags[slot]) if slot < flags.size() else false)
		stages.append({"variants": variants, "elites": elites})
	manager.stages = stages
	manager._spawn_stage(0)
	return manager


func _hand_card(manager: BattleTurnManager, card: Card) -> Card:
	manager.hand.cards.append(card)
	return card


# ── 1. 레드라인 ────────────────────────────────────────────────────────────

func _test_redline_bonus() -> void:
	print("\n-- 레드라인 --")
	var manager := _make_battle([] as Array[Card])
	var monster := manager.get_monster(0)
	monster.hp = 999
	monster.max_hp = 999

	var slash := _make_card("테스트베기", Card.CardColor.PHYSICAL, 10)
	manager.weapon.equipped = WeaponState.WeaponType.SWORD

	manager.weapon.sword_gauge = WeaponState.REDLINE_THRESHOLD - WeaponState.GAUGE_STEP
	_hand_card(manager, slash)
	var before := monster.hp
	manager.play_card(slash, 0)
	_check_eq("레드라인 아래 — 보너스 없음", before - monster.hp, 10)

	var slash2 := _make_card("테스트베기2", Card.CardColor.PHYSICAL, 10)
	manager.weapon.sword_gauge = WeaponState.REDLINE_THRESHOLD
	_hand_card(manager, slash2)
	before = monster.hp
	manager.play_card(slash2, 0)
	_check_eq("레드라인 — +50%", before - monster.hp, 15)

	# 달군 무기를 손에서 놓으면 보너스도 사라진다 (검 75인 채 지팡이로 마법 카드)
	var bolt := _make_card("테스트마법", Card.CardColor.MAGIC, 10)
	manager.weapon.sword_gauge = WeaponState.REDLINE_THRESHOLD
	manager.weapon.staff_gauge = 0
	manager.weapon.equipped = WeaponState.WeaponType.STAFF
	_hand_card(manager, bolt)
	before = monster.hp
	manager.play_card(bolt, 0)
	_check_eq("다른 무기 카드엔 보너스 없음", before - monster.hp, 10)


func _test_overload_lock() -> void:
	print("\n-- 과부하 봉쇄 --")
	var manager := _make_battle([] as Array[Card])
	manager.get_monster(0).hp = 999
	manager.weapon.equipped = WeaponState.WeaponType.SWORD
	manager.weapon.sword_gauge = 75

	var card := _make_card("막타", Card.CardColor.PHYSICAL, 5)
	_hand_card(manager, card)
	manager.play_card(card, 0)

	_check("100 도달 시 봉쇄", manager.weapon.is_overheated(WeaponState.WeaponType.SWORD))
	_check_eq("봉쇄 라운드", manager.weapon.sword_lock_rounds, WeaponState.OVERLOAD_LOCK_ROUNDS)
	_check_eq("과부하 직후 게이지 0", manager.weapon.sword_gauge, 0)

	var blocked := _make_card("봉쇄된검", Card.CardColor.PHYSICAL, 5)
	_hand_card(manager, blocked)
	_check("봉쇄 중 그 계열 카드 금지", not manager.can_play_card(blocked))

	var magic := _make_card("지팡이카드", Card.CardColor.MAGIC, 5)
	_hand_card(manager, magic)
	_check("다른 계열은 그대로 사용 가능", manager.can_play_card(magic))

	manager.weapon.tick_round()
	manager.weapon.tick_round()
	_check("2라운드 뒤 봉쇄 해제", not manager.weapon.is_overheated(WeaponState.WeaponType.SWORD))


# ── 2. 템포 체인 ───────────────────────────────────────────────────────────

func _test_tempo_chain() -> void:
	print("\n-- 템포 체인 (표식) --")
	var manager := _make_battle([] as Array[Card])
	var monster := manager.get_monster(0)
	monster.hp = 999
	manager.weapon.equipped = WeaponState.WeaponType.STAFF

	var marker := _make_card("표식카드", Card.CardColor.MAGIC, 6, 0, false, 5)
	_hand_card(manager, marker)
	manager.play_card(marker, 0)
	_check_eq("표식이 걸렸다", monster.status.get_magnitude(StatusEffects.Kind.MARK), 5)

	var hp_before := monster.hp
	_check("전환 예약 가능", manager.reserve_switch())
	var result := manager.execute_next_reservation()
	_check_eq("전환으로 표식 폭발", hp_before - monster.hp, 5)
	_check("표식은 터진 뒤 사라진다", monster.status.get_magnitude(StatusEffects.Kind.MARK) == 0)
	_check("전환은 응수를 부르지 않는다", not bool(result["provokes"]))
	_check_eq("전환 결과 무기", int(manager.weapon.equipped), int(WeaponState.WeaponType.SWORD))


func _test_switch_is_free_tempo() -> void:
	print("\n-- 전환은 교환 횟수에 포함되지 않는다 --")
	var manager := _make_battle([] as Array[Card], [2])
	for monster in manager.monsters:
		monster.hp = 999
		monster.mana = 100

	var card_a := _make_card("A", Card.CardColor.PHYSICAL, 3)
	var card_b := _make_card("B", Card.CardColor.PHYSICAL, 3)
	_hand_card(manager, card_a)
	_hand_card(manager, card_b)
	manager.reserve_card(card_a, 0)
	manager.reserve_switch()
	manager.reserve_card(card_b, 0)

	var actions := 0
	manager.begin_round_resolution()
	while manager.has_reservations():
		var result := manager.execute_next_reservation()
		if bool(result.get("provokes", true)):
			if manager.take_next_monster_action()["acted"]:
				actions += 1
	manager.finish_round_resolution()
	_check_eq("카드 2장 + 전환 1회 → 응수 2회", actions, 2)


# ── 3. 도발 ────────────────────────────────────────────────────────────────

func _test_provoke_single_target() -> void:
	print("\n-- 도발: 때린 놈이 반격 --")
	var manager := _make_battle([] as Array[Card], [3])
	for monster in manager.monsters:
		monster.hp = 999
		monster.mana = 100

	var card := _make_card("찌르기", Card.CardColor.PHYSICAL, 4)
	_hand_card(manager, card)
	manager.play_card(card, 2)
	var acted := manager.take_next_monster_action()
	_check_eq("2번을 때리면 2번이 반격", int(acted["index"]), 2)

	var card2 := _make_card("찌르기2", Card.CardColor.PHYSICAL, 4)
	_hand_card(manager, card2)
	manager.play_card(card2, 0)
	_check_eq("0번을 때리면 0번이 반격", int(manager.take_next_monster_action()["index"]), 0)


func _test_provoke_aoe_picks_weakest() -> void:
	print("\n-- 도발: 광역이면 최약체 --")
	var manager := _make_battle([] as Array[Card], [3])
	for monster in manager.monsters:
		monster.hp = 999
		monster.mana = 100
	manager.get_monster(1).hp = 40 # 광역 피해를 맞고도 가장 약한 상태로 남게

	var aoe := _make_card("광역", Card.CardColor.MAGIC, 6, 0, true)
	_hand_card(manager, aoe)
	manager.play_card(aoe, -1)
	_check_eq("광역 뒤엔 체력이 가장 낮은 놈이 반격", int(manager.take_next_monster_action()["index"]), 1)


func _test_kill_skips_retaliation() -> void:
	print("\n-- 도발: 처치하면 그 교환은 반격 없음 --")
	var manager := _make_battle([] as Array[Card], [2])
	for monster in manager.monsters:
		monster.mana = 100
	manager.get_monster(1).hp = 3

	var finisher := _make_card("마무리", Card.CardColor.PHYSICAL, 20)
	_hand_card(manager, finisher)
	manager.play_card(finisher, 1)
	_check("겨눈 대상이 죽었다", not manager.get_monster(1).is_alive())
	_check("그 교환에는 반격이 없다", not bool(manager.take_next_monster_action()["acted"]))

	# 죽이지 못한 다음 카드는 정상적으로 반격을 부른다
	var jab := _make_card("툭", Card.CardColor.PHYSICAL, 1)
	_hand_card(manager, jab)
	manager.play_card(jab, 0)
	_check_eq("다음 카드는 정상 반격", int(manager.take_next_monster_action()["index"]), 0)

	# 아무도 겨누지 않은 카드(방어)는 누구도 도발하지 않는다
	var guard := Card.new()
	guard.card_name = "방어테스트"
	guard.color = Card.CardColor.NEUTRAL
	guard.effect = Card.EffectType.DEFEND
	guard.value = 4
	_hand_card(manager, guard)
	manager.play_card(guard, -1)
	_check("비공격 카드는 반격을 부르지 않는다", not bool(manager.take_next_monster_action()["acted"]))


# ── 4. 적응 ────────────────────────────────────────────────────────────────

func _test_adaptation() -> void:
	print("\n-- 적응 --")
	var manager := _make_battle([] as Array[Card])
	var monster := manager.get_monster(0)
	monster.hp = 999
	monster.max_hp = 999

	var hit1 := _make_card("물리1", Card.CardColor.PHYSICAL, 10)
	_hand_card(manager, hit1)
	var before := monster.hp
	manager.play_card(hit1, 0)
	_check_eq("첫 타는 온전한 피해", before - monster.hp, 10)
	_check_eq("적응 예고", int(monster.resistance.pending_type()), int(EnemyResistance.ResistanceType.PHYSICAL))
	_check_eq("아직 적응 전", int(monster.resistance.current), int(EnemyResistance.ResistanceType.NONE))

	var hit2 := _make_card("물리2", Card.CardColor.PHYSICAL, 10)
	_hand_card(manager, hit2)
	before = monster.hp
	manager.play_card(hit2, 0)
	_check_eq("두 번째 타격도 적응 전 피해", before - monster.hp, 10)
	_check_eq("두 번 연속 맞고 적응", int(monster.resistance.current), int(EnemyResistance.ResistanceType.PHYSICAL))

	var hit3 := _make_card("물리3", Card.CardColor.PHYSICAL, 10)
	manager.weapon.sword_gauge = 0 # 적응만 보려고 레드라인이 끼어들지 않게 게이지를 비운다
	_hand_card(manager, hit3)
	before = monster.hp
	manager.play_card(hit3, 0)
	_check_eq("적응한 속성은 반감", before - monster.hp, 5)

	var magic := _make_card("마법", Card.CardColor.MAGIC, 10)
	_hand_card(manager, magic)
	before = monster.hp
	manager.play_card(magic, 0)
	_check_eq("반대 속성은 온전히 들어간다", before - monster.hp, 10)
	_check_eq("반대 속성에 맞아 적응이 깨진다", int(monster.resistance.current), int(EnemyResistance.ResistanceType.NONE))


func _test_adaptation_vs_redline() -> void:
	print("\n-- 적응 × 레드라인 --")
	var manager := _make_battle([] as Array[Card])
	var monster := manager.get_monster(0)
	monster.hp = 999
	monster.max_hp = 999
	monster.resistance.current = EnemyResistance.ResistanceType.PHYSICAL

	manager.weapon.equipped = WeaponState.WeaponType.SWORD
	manager.weapon.sword_gauge = WeaponState.REDLINE_THRESHOLD

	var card := _make_card("뜨거운일격", Card.CardColor.PHYSICAL, 10)
	_hand_card(manager, card)
	var before := monster.hp
	manager.play_card(card, 0)
	# 레드라인(공격자측 x1.5) 뒤에 적응(방어자측 x0.5) = 0.75배. 안 뜨거울 때(5)보다는 낫지만
	# 적응 안 한 상대에게 쏟을 때(15)의 절반이라, "뜨거울 때 누구를 때리는가"가 판단거리가 된다
	_check_eq("적응한 상대에겐 레드라인도 함께 반감", before - monster.hp, 8)


# ── 5. 예약 큐 / 계획 ──────────────────────────────────────────────────────

func _test_queue_planning() -> void:
	print("\n-- 예약 큐 계획 --")
	var manager := _make_battle([] as Array[Card])
	manager.get_monster(0).hp = 999
	GameState.set_flag("player_mana", 10)

	var a := _make_card("비싼카드A", Card.CardColor.MAGIC, 4, 6)
	var b := _make_card("비싼카드B", Card.CardColor.MAGIC, 4, 6)
	_hand_card(manager, a)
	_hand_card(manager, b)

	_check("첫 장은 예약 가능", manager.reserve_card(a, 0))
	_check("계획상 마나가 모자라면 두 번째는 막힌다", not manager.can_play_card(b))
	_check_eq("계획 마나 표시", manager.display_mana(), 4)
	_check_eq("실제 마나는 아직 그대로", int(GameState.get_flag("player_mana")), 10)

	_check("취소하면 다시 예약 가능해진다", manager.cancel_reservation(0))
	_check_eq("취소 뒤 계획 마나 복구", manager.display_mana(), 10)
	_check("취소한 카드는 손패로 돌아온다", manager.hand.cards.has(a))
	_check("이제 두 번째 카드도 가능", manager.can_play_card(b))

	# 전환을 큐에 끼우면 그 뒤 카드의 게이지 계산이 전환 기준으로 바뀐다
	manager.weapon.equipped = WeaponState.WeaponType.SWORD
	manager.weapon.sword_gauge = 75
	manager.weapon.staff_gauge = 0
	manager.reserve_switch()
	_check_eq("전환 예약 뒤 계획상 장착 무기", int(manager.planned_equipped()), int(WeaponState.WeaponType.STAFF))


# ── 6. 스테이지 ────────────────────────────────────────────────────────────

func _test_stage_progression() -> void:
	print("\n-- 스테이지 진행 --")
	var manager := _make_battle([] as Array[Card], [1, 2, 1], [[], [false, true], []])
	var cleared: Array[int] = []
	var finished := [false]
	manager.stage_cleared.connect(func(index: int, _count: int) -> void: cleared.append(index))
	manager.enemy_defeated.connect(func() -> void: finished[0] = true)

	_check_eq("스테이지 수", manager.stage_count(), 3)
	_check_eq("1스테이지 마리 수", manager.monsters.size(), 1)

	_wipe_stage(manager)
	_check("1스테이지를 깨도 전투는 안 끝난다", not manager.battle_over)
	_check("보상 대기 상태", manager.stage_pending)
	_check_eq("stage_cleared 발생", cleared.size(), 1)

	manager.advance_stage()
	_check_eq("2스테이지 마리 수", manager.monsters.size(), 2)
	_check("엘리트가 섞여 있다", manager.get_monster(1).is_elite)
	_check("엘리트는 체력이 더 높다", manager.get_monster(1).max_hp > manager.get_monster(0).max_hp,
		"(%d vs %d)" % [manager.get_monster(1).max_hp, manager.get_monster(0).max_hp])

	_wipe_stage(manager)
	manager.advance_stage()
	_check_eq("마지막 스테이지", manager.stage_index, 2)
	_check("마지막 스테이지 표시", manager.is_final_stage())

	_wipe_stage(manager)
	_check("마지막을 깨면 전투 종료", manager.battle_over)
	_check("승리 시그널", finished[0])


func _wipe_stage(manager: BattleTurnManager) -> void:
	# 실제 카드로 전멸시켜 전멸 판정 경로를 그대로 탄다
	var nuke := _make_card("전멸일격", Card.CardColor.NEUTRAL, 9999, 0, true)
	manager.hand.cards.append(nuke)
	manager.play_card(nuke, -1)


func _test_stage_reward_effects() -> void:
	print("\n-- 스테이지 보상 --")
	# 손패 감소를 확인하려면 실제로 뽑을 카드가 덱에 있어야 한다
	var deck_cards: Array[Card] = []
	for i in range(10):
		deck_cards.append(_make_card("덱카드%d" % i, Card.CardColor.NEUTRAL, 1))
	var manager := _make_battle(deck_cards, [1, 1])

	# 냉각: 게이지/봉쇄 초기화
	manager.weapon.sword_gauge = 100
	manager.weapon.sword_lock_rounds = 2
	manager.apply_stage_reward({"effect": {"cool_weapons": true, "next_hand_delta": -1}})
	_check_eq("냉각 — 게이지 0", manager.weapon.sword_gauge, 0)
	_check("냉각 — 봉쇄 해제", not manager.weapon.is_overheated(WeaponState.WeaponType.SWORD))

	# 대가: 다음 스테이지 손패 감소 + 몬스터 강화
	manager.apply_stage_reward({"effect": {"next_hp_mult": 2.0, "next_damage_mult": 2.0}})
	_wipe_stage(manager)
	manager.advance_stage()
	var base_hp: int = BattleData.MONSTERS["ORC"]["max_hp"]
	_check_eq("대가 — 다음 스테이지 몬스터 체력 2배", manager.get_monster(0).max_hp, int(round(base_hp * 2.0 * BattleStages.hp_scale_for(1, "ORC"))))
	_check_eq("대가 — 손패 1장 감소", manager.hand.cards.size(), maxi(1, BattleTurnManager.HAND_SIZE - 1))

	# 각인: 지목한 카드만 위력 증가
	var engraved := _make_battle([] as Array[Card])
	engraved.get_monster(0).hp = 999
	engraved.apply_stage_reward({"effect": {"card_power": 0.5}, "card_name": "각인대상"})
	var boosted := _make_card("각인대상", Card.CardColor.NEUTRAL, 10)
	var plain := _make_card("평범한카드", Card.CardColor.NEUTRAL, 10)
	engraved.hand.cards.append(boosted)
	engraved.hand.cards.append(plain)
	var before := engraved.get_monster(0).hp
	engraved.play_card(boosted, 0)
	_check_eq("각인된 카드 +50%", before - engraved.get_monster(0).hp, 15)
	before = engraved.get_monster(0).hp
	engraved.play_card(plain, 0)
	_check_eq("다른 카드는 그대로", before - engraved.get_monster(0).hp, 10)


# ── 7. 라운드 단위 불변식 ──────────────────────────────────────────────────

func _test_round_invariants() -> void:
	print("\n-- 라운드 단위 불변식 --")
	var manager := _make_battle([] as Array[Card], [2])
	for monster in manager.monsters:
		monster.hp = 999
		monster.mana = 100
	manager.weapon.sword_lock_rounds = 2
	manager.player_status.apply(StatusEffects.Kind.ATTACK_UP, 20, 3)

	var rounds_before := manager.rounds_completed
	for i in range(4):
		var card := _make_card("연타%d" % i, Card.CardColor.MAGIC, 2)
		manager.hand.cards.append(card)
		manager.reserve_card(card, 0)
	manager.end_turn()

	_check_eq("교환을 4번 해도 라운드는 1", manager.rounds_completed, rounds_before + 1)
	_check_eq("상태이상은 라운드당 1만 감소", manager.player_status.get_rounds(StatusEffects.Kind.ATTACK_UP), 2)
	_check_eq("무기 봉쇄도 라운드당 1만 감소", manager.weapon.sword_lock_rounds, 1)
