class_name BattleTurnManager
extends RefCounted

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
# 몬스터 한 마리가 플레이어를 때린 결과. 다인전에서는 살아있는 마리 수만큼 순차로 발생한다
# (예전 단일 전투의 enemy_turn_resolved를 마리별로 쪼갠 것 — attacker_index가 누가 때렸는지 알려준다)
signal enemy_attack_resolved(attacker_index: int, damage_taken: int, dodged: bool, counter_damage: int)
# 마나가 바닥나 공격 대신 숨을 고른 몬스터. mana_gained/hp_gained는 실제로 회복된 양
# (hp_gained가 0이면 이번엔 체력 회복이 안 붙은 것)
signal monster_recovered(index: int, mana_gained: int, hp_gained: int)
signal monster_defeated(index: int) # 마리 하나가 쓰러짐 (전투는 아직 안 끝났을 수 있음)
signal player_defeated
signal enemy_defeated # 살아있는 몬스터가 하나도 남지 않음 = 전투 승리

const HAND_SIZE := 5

var deck: Deck
var hand: Hand
var weapon: WeaponState

# 이번 전투에 등장한 몬스터들 (1~3마리, 전부 같은 종류). 자리 순서가 곧 MonsterState.index다
var monsters: Array[MonsterState] = []

var monster_type: String = "" # 그룹 전체가 같은 종류라 스칼라로 둔다
var monster_data: Dictionary = {} # 그 종류의 스탯 표 (마리별 값은 MonsterState.monster_data로 접근)

var turn_number: int = 0
var battle_over: bool = false

# 방금 낸 카드가 마리별로 입힌 실제 피해 (자리 번호 -> 피해량). 피해가 0인 대상은 담지 않는다.
# 광역기는 여러 자리가 채워지고 단일 대상 카드는 한 자리만 채워지므로, 연출은 이걸 그대로 훑어
# 몬스터마다 제 숫자를 띄우면 된다 (0 피해에 "-0"을 띄우지 않는 기존 규칙도 그대로 유지된다)
var last_hit_damage: Dictionary = {}

# 방어/피하기 카드가 만드는 "다음 적 턴 한정" 임시 상태. 적 턴을 해결하는 즉시 소모되고 0/false로 돌아간다.
# (스펙에 세부 규칙이 없어 아래처럼 설계했다 — 근거는 _resolve_enemy_turn() 주석 참고)
var _pending_defense: int = 0
var _pending_dodge: bool = false
var _pending_counter: int = 0 # 반격(COUNTER) 카드로 예약해둔 반격 피해량. 0이면 반격 대기 아님


# monster_type_은 BattleData.MONSTERS의 키("ORC" 등), variants는 등장할 마리 수만큼의 시각 변종
# (BattleData.build_group_variants가 만든 것 — 배열 길이가 곧 마리 수다), cards는 이번 전투에 쓸 카드 목록.
# Deck이 생성 시 알아서 섞으므로 여기서 따로 셔플하지 않는다.
#
# variants가 비어 있으면 변종 하나를 즉석에서 뽑아 1마리 전투로 만든다 — 헤드리스 테스트처럼
# 필드를 거치지 않고 매니저만 직접 만드는 호출부가 마리 수를 신경 쓰지 않아도 되게 하기 위함
func _init(monster_type_: String, variants: Array, cards: Array[Card]) -> void:
	monster_type = monster_type_
	monster_data = BattleData.MONSTERS[monster_type_]

	var group: Array = variants
	if group.is_empty():
		group = [BattleData.pick_variant(monster_type_)]

	for i in range(group.size()):
		monsters.append(MonsterState.new(i, monster_type_, group[i]))

	# 같은 종류가 여러 마리면 이름에 번호를 붙여 메시지에서 구분되게 한다 (한 마리면 그냥 "오크")
	if monsters.size() > 1:
		for monster in monsters:
			monster.display_name = "%s %d" % [monster.monster_data["name"], monster.index + 1]

	deck = Deck.new(cards)
	hand = Hand.new()
	weapon = WeaponState.new()


# 전투를 시작하고 첫 턴을 연다 (_init과 분리해 둬서, 바깥이 시그널을 먼저 연결한 뒤 시작할 수 있다).
# 시작 직전에 장비 보너스를 한 번 재계산해, 전투에 들어갈 때의 방패 최대 체력 보너스가
# 확실히 player_max_hp에 반영된 상태로 싸우게 한다 (장착 시점에도 이미 반영되지만, 전투 진입을
# 기준점으로 한 번 더 맞춰두면 어떤 경로로 들어와도 어긋나지 않는다)
func start() -> void:
	GameState.refresh_equipment_bonuses()
	_start_turn()


# ── 턴 시작 ────────────────────────────────────────────────────────────────
# 살아있는 몬스터마다 저항을 따로 굴리고, 무기 전환 횟수를 리셋하고, 손패를 5장으로 새로 채운다.
# (남은 손패는 Hand.draw_new_hand()가 알아서 버린 더미로 보낸 뒤 새로 뽑는다)
#
# 저항을 마리별로 굴리는 이유는 그게 다인전의 핵심 압박이기 때문이다 — 한 마리는 물리 저항,
# 옆은 마법 저항인 상황이 나오면 "어느 쪽부터 어떤 무기로 때릴지"를 매 턴 다시 판단해야 한다.
# 쓰러진 몬스터는 굴리지 않는다 (죽은 뒤에도 저항 배지가 갱신되며 깜빡이지 않게)
func _start_turn() -> void:
	turn_number += 1
	for monster in monsters:
		if monster.is_alive():
			monster.resistance.roll_new_turn()
	weapon.reset_turn()
	hand.draw_new_hand(deck, HAND_SIZE)
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


# ── 플레이어 행동 ──────────────────────────────────────────────────────────

# 이 카드를 지금 낼 수 있는지. 손에 있어야 하고, 무기가 과부하가 아니어야 하고(WeaponState),
# 마나와 체력 비용을 모두 감당할 수 있어야 한다. UI가 카드 버튼을 회색 처리할 때도 이 함수를 쓴다
func can_play_card(card: Card) -> bool:
	if battle_over or card == null:
		return false
	if not hand.cards.has(card):
		return false
	if not weapon.can_use_card(card):
		return false
	if not GameState.can_afford_mana(card.get_mana_cost()):
		return false
	return can_afford_hp(card.get_hp_cost())


# 체력 비용을 치를 수 있는지. "남은 체력 > 비용"이라 비용을 내고도 최소 1은 남는다 —
# 같으면(체력 == 비용) 카드를 내는 순간 체력이 0이 되어 자기 카드로 죽어버리므로 그 경우도 막는다.
# 비용이 0인 카드는 체력과 무관하게 항상 통과한다
func can_afford_hp(cost: int) -> bool:
	if cost <= 0:
		return true
	return GameState.get_flag("player_hp") > cost


# 카드 한 장을 낸다. 낼 수 없는 상황이면 아무 일도 하지 않고 false를 반환한다.
# 성공하면: 비용(마나/체력) 소모 → 과열 게이지 갱신 → 효과 적용 → 손패에서 버린 더미로 이동 →
# card_played 방출. 카드는 손에 있는 한 자유로운 순서로 낼 수 있고, 5장을 다 쓰지 않고 end_turn()해도 된다.
#
# 비용을 효과보다 먼저 치르는 순서에 주의 — 체력을 회복하는 카드가 체력 비용을 갖는 경우
# "먼저 내고 그 다음 회복"이 되어야 순서가 뒤집혀 이득이 나지 않는다.
# 체력 비용으로 죽는 일은 can_play_card가 이미 막아둬서(can_afford_hp) 여기서 다시 확인하지 않는다.
#
# target_index는 피해 카드가 때릴 몬스터의 자리 번호다. -1(기본값)이면 자동 타겟(살아있는 첫 마리)을
# 고른다 — 지금은 UI가 대상을 고를 방법이 없어 호출부가 전부 기본값으로 부르고, 타겟팅 UI가 붙는
# 다음 단계에서 플레이어가 고른 값이 여기로 들어온다. 피해 카드가 아니면 이 값은 쓰이지 않는다
func play_card(card: Card, target_index: int = -1) -> bool:
	if not can_play_card(card):
		return false

	GameState.spend_mana(card.get_mana_cost()) # 비용이 0이면 그대로 통과
	var hp_cost := card.get_hp_cost()
	if hp_cost > 0:
		GameState.damage_player(hp_cost)
	weapon.register_card_use(card)
	# 게이지 강제 세팅 페널티는 누적(register_card_use) 뒤에 적용해야 한다 — 순서가 반대면
	# 세팅한 값 위에 ±25가 덮여 카드가 약속한 값과 달라진다
	if card.on_use_set_gauge > 0:
		weapon.set_both_gauges(card.on_use_set_gauge)

	var damage_dealt := _apply_card_effect(card, target_index)

	hand.cards.erase(card)
	var moved: Array[Card] = [card]
	deck.discard(moved)

	card_played.emit(card, damage_dealt)

	# 전투 종료는 "전멸"이어야 한다 — 한 마리가 쓰러져도 남은 몬스터가 있으면 계속 싸운다
	if all_monsters_defeated():
		_finish_battle(false)

	return true


# 무기 전환 (턴당 3회 제한은 WeaponState가 관리). 성공했을 때만 시그널을 쏘고 true를 반환
func switch_weapon(to: WeaponState.WeaponType) -> bool:
	if battle_over:
		return false
	if not weapon.switch_weapon(to):
		return false
	weapon_switched.emit(to)
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
		Card.EffectType.HEAL_HP:
			var max_hp: int = GameState.get_flag("player_max_hp")
			if max_hp > 0:
				GameState.heal_player_partial(float(card.value) / max_hp)
		Card.EffectType.RESTORE_MANA:
			var max_mana: int = GameState.get_flag("player_max_mana")
			if max_mana > 0:
				GameState.restore_mana_partial(float(card.value) / max_mana)
		Card.EffectType.DEFEND:
			_pending_defense += card.value
		Card.EffectType.DODGE:
			_pending_dodge = true
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

	var raw_damage: int = card.value + _equipment_damage_bonus(card)
	var final_damage: int = target.resistance.calculate_damage(card, raw_damage)
	var applied := target.take_damage(final_damage)

	if not target.is_alive():
		monster_defeated.emit(target.index)

	return applied


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

# 플레이어가 턴을 넘긴다. 적이 반격하고, 승패를 판정한 뒤, 아직 안 끝났으면 다음 턴을 자동으로 연다
func end_turn() -> void:
	if battle_over:
		return

	_resolve_enemy_turn()

	if GameState.get_flag("player_hp") <= 0:
		_finish_battle(true)
		return

	# 반격으로 적이 쓰러졌을 수 있다. 이 검사가 없으면 전멸한 상대로 다음 턴이 열린다
	# (플레이어 턴에 카드로 죽인 경우는 play_card가 이미 처리하지만, 반격은 적 턴에 일어난다)
	if all_monsters_defeated():
		_finish_battle(false)
		return

	_start_turn()


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
# [다인전 설계 결정 — 동시가 아니라 "순차"] 살아있는 몬스터가 자리 순서대로 한 마리씩 공격한다.
# 동시 처리(피해를 다 더해 한 번에 적용)와 견줘 순차를 택한 이유:
#  - 방어/피하기/반격이 전부 "다음 한 방"을 전제로 만들어진 카드라, 동시 처리에서는 그 한 방이
#    무엇인지 정의할 수 없다. 순차면 "먼저 오는 공격에 쓰인다"로 규칙이 자명해진다.
#  - 화면 연출도 이미 "몬스터가 달려들어 때린다"는 1:1 모션(battle_scene의 _lunge)으로 되어 있어,
#    순차 공격이 기존 연출을 마리별로 반복하는 것만으로 자연스럽게 확장된다.
#  - 피해 총량은 어느 쪽이든 같지만, 순차면 플레이어가 "몇 마리에게 얼마씩 맞았는지"를 눈으로 읽는다.
#
# [방어/피하기/반격이 마리 수만큼 뻥튀기되지 않게 하는 규칙] 이게 순차 처리의 핵심 쟁점이라 명시한다:
#  - 피하기/반격은 "가장 먼저 오는 공격 한 방"에만 쓰이고 그 자리에서 소모된다. 한 장으로 3마리
#    공격을 전부 무효화하면 다인전이 오히려 1:1보다 쉬워지는 역전이 일어난다.
#  - 방어는 "값만큼의 피해를 흡수하는 총량 풀"로 동작한다(각 공격마다 값을 다시 빼주는 게 아니라,
#    흡수한 만큼 풀에서 깎인다). 그래서 방어 카드 한 장의 값어치가 상대 마리 수와 무관하게 일정하고,
#    1마리 전투에서는 기존과 완전히 동일하게 동작한다(값 4로 5 피해를 받으면 1만 들어옴).
#  - 반격은 "때린 그 몬스터"에게 되돌려준다 (자동 타겟이 아니라 공격자). 받아넘긴 상대를 되받아친다는
#    카드 설명 그대로이고, 여러 마리 중 누구를 치는지도 이 규칙이면 헷갈릴 여지가 없다.
func _resolve_enemy_turn() -> void:
	for monster in monsters:
		if not monster.is_alive():
			continue
		# 앞선 몬스터의 공격으로 이미 쓰러졌으면 남은 몬스터는 때리지 않는다 —
		# 죽은 플레이어를 계속 때리는 연출이 이어지지 않게
		if GameState.get_flag("player_hp") <= 0:
			break

		# 마나가 남아 있으면 공격, 바닥났으면 그 턴은 숨고르기(회복).
		# 판단은 마리마다 따로 하므로 다인전에서는 "둘은 때리고 하나는 회복하는" 턴도 나온다
		if monster.can_attack():
			monster.spend_attack_mana()
			_resolve_single_attack(monster)
		else:
			var gained := monster.recover()
			monster_recovered.emit(monster.index, gained["mana"], gained["hp"])

	# 임시 상태는 이번 적 턴에서만 유효 — 결과와 무관하게 소모하고 초기화한다
	# (피하기/반격은 위에서 이미 첫 공격에 소모됐을 수 있고, 방어는 남은 풀이 여기서 버려진다)
	_pending_defense = 0
	_pending_dodge = false
	_pending_counter = 0


# 몬스터 한 마리의 공격을 해결한다. 피하기/반격은 여기서 소모되므로, 뒤이어 공격하는 몬스터는
# 그 보호를 받지 못한다 (위 _resolve_enemy_turn 주석의 "뻥튀기 방지" 규칙)
func _resolve_single_attack(attacker: MonsterState) -> void:
	var raw_damage: int = randi_range(attacker.monster_data["damage_min"], attacker.monster_data["damage_max"])

	var countering := _pending_counter > 0
	var dodging := _pending_dodge

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
		var absorbed: int = min(_pending_defense, raw_damage)
		_pending_defense -= absorbed
		damage_taken = raw_damage - absorbed
		if damage_taken > 0:
			GameState.damage_player(damage_taken)

	enemy_attack_resolved.emit(attacker.index, damage_taken, dodging, counter_damage)


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
