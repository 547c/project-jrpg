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
# - 몬스터 HP: 이 매니저의 로컬 변수(monster_hp). battle_scene.gd도 _monster_hp를 로컬로 들고 있었다 —
#   전투가 끝나면 사라지는 값이라 GameState에 넣을 이유가 없다.

signal turn_started(turn_number: int)
signal card_played(card: Card, damage_dealt: int) # 데미지 카드가 아니면 damage_dealt는 0
signal weapon_switched(weapon: WeaponState.WeaponType)
signal enemy_turn_resolved(damage_taken: int, dodged: bool)
signal player_defeated
signal enemy_defeated

const HAND_SIZE := 5

var deck: Deck
var hand: Hand
var weapon: WeaponState
var resistance: EnemyResistance

var monster_type: String = ""
var monster_data: Dictionary = {}
var monster_hp: int = 0

var turn_number: int = 0
var battle_over: bool = false

# 방어/피하기 카드가 만드는 "다음 적 턴 한정" 임시 상태. 적 턴을 해결하는 즉시 소모되고 0/false로 돌아간다.
# (스펙에 세부 규칙이 없어 아래처럼 설계했다 — 근거는 _resolve_enemy_turn() 주석 참고)
var _pending_defense: int = 0
var _pending_dodge: bool = false


# monster_type_은 BattleData.MONSTERS의 키("ORC" 등), cards는 이번 전투에 쓸 카드 목록.
# Deck이 생성 시 알아서 섞으므로 여기서 따로 셔플하지 않는다
func _init(monster_type_: String, cards: Array[Card]) -> void:
	monster_type = monster_type_
	monster_data = BattleData.MONSTERS[monster_type_]
	monster_hp = monster_data["max_hp"]

	deck = Deck.new(cards)
	hand = Hand.new()
	weapon = WeaponState.new()
	resistance = EnemyResistance.new()


# 전투를 시작하고 첫 턴을 연다 (_init과 분리해 둬서, 바깥이 시그널을 먼저 연결한 뒤 시작할 수 있다).
# 시작 직전에 장비 보너스를 한 번 재계산해, 전투에 들어갈 때의 방패 최대 체력 보너스가
# 확실히 player_max_hp에 반영된 상태로 싸우게 한다 (장착 시점에도 이미 반영되지만, 전투 진입을
# 기준점으로 한 번 더 맞춰두면 어떤 경로로 들어와도 어긋나지 않는다)
func start() -> void:
	GameState.refresh_equipment_bonuses()
	_start_turn()


# ── 턴 시작 ────────────────────────────────────────────────────────────────
# 적 저항을 새로 굴리고, 무기 전환 횟수를 리셋하고, 손패를 5장으로 새로 채운다.
# (남은 손패는 Hand.draw_new_hand()가 알아서 버린 더미로 보낸 뒤 새로 뽑는다)
func _start_turn() -> void:
	turn_number += 1
	resistance.roll_new_turn()
	weapon.reset_turn()
	hand.draw_new_hand(deck, HAND_SIZE)
	turn_started.emit(turn_number)


# ── 플레이어 행동 ──────────────────────────────────────────────────────────

# 이 카드를 지금 낼 수 있는지. 손에 있어야 하고, 무기가 과부하가 아니어야 하고(WeaponState),
# 마법 카드라면 마나가 충분해야 한다. UI가 카드 버튼을 회색 처리할 때도 이 함수를 쓰면 된다
func can_play_card(card: Card) -> bool:
	if battle_over or card == null:
		return false
	if not hand.cards.has(card):
		return false
	if not weapon.can_use_card(card):
		return false
	return GameState.can_afford_mana(card.get_mana_cost())


# 카드 한 장을 낸다. 낼 수 없는 상황이면 아무 일도 하지 않고 false를 반환한다.
# 성공하면: 마나 소모 → 과열 게이지 갱신 → 효과 적용 → 손패에서 버린 더미로 이동 → card_played 방출.
# 카드는 손에 있는 한 자유로운 순서로 낼 수 있고, 5장을 다 쓰지 않고 end_turn()해도 된다
func play_card(card: Card) -> bool:
	if not can_play_card(card):
		return false

	GameState.spend_mana(card.get_mana_cost()) # 물리/공용 카드는 get_mana_cost()가 0이라 그대로 통과
	weapon.register_card_use(card)

	var damage_dealt := _apply_card_effect(card)

	hand.cards.erase(card)
	var moved: Array[Card] = [card]
	deck.discard(moved)

	card_played.emit(card, damage_dealt)

	if monster_hp <= 0:
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
func _apply_card_effect(card: Card) -> int:
	match card.effect:
		Card.EffectType.DAMAGE:
			return _damage_monster(card)
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
	return 0


# 데미지 카드 처리: 카드의 기본 위력(value)에 장비 보너스를 더한 뒤, 그 값을 적 저항 판정에
# 통과시킨 최종값을 몬스터 HP에서 깎는다. 몬스터 HP는 battle_scene.gd와 동일하게
# 0 밑으로 내려가지 않게 max(0, ...)로 막는다
func _damage_monster(card: Card) -> int:
	var raw_damage: int = card.value + _equipment_damage_bonus(card)
	var final_damage: int = resistance.calculate_damage(card, raw_damage)
	monster_hp = max(0, monster_hp - final_damage)
	return final_damage


# 카드 색깔에 대응하는 장비의 피해 보너스 (물리 카드 -> 검, 마법 카드 -> 지팡이, 공용 카드 -> 없음).
# 지금 들고 있는 무기(WeaponState.equipped)가 아니라 "카드 색깔"을 기준으로 삼는다 —
# 물리 카드는 검의 힘으로, 마법 카드는 지팡이의 힘으로 나가는 게 직관적이고, 손에 든 무기와
# 카드 색이 다를 때 보너스가 조용히 사라지는 혼란을 피할 수 있기 때문이다.
# (보너스를 더한 뒤에 저항 배율이 걸리므로, 저항이 걸린 턴에는 보너스분도 함께 반감된다)
func _equipment_damage_bonus(card: Card) -> int:
	match card.color:
		Card.CardColor.PHYSICAL:
			return GameState.get_sword_damage_bonus()
		Card.CardColor.MAGIC:
			return GameState.get_staff_damage_bonus()
		_:
			return 0


# ── 턴 종료 / 적 턴 ────────────────────────────────────────────────────────

# 플레이어가 턴을 넘긴다. 적이 반격하고, 승패를 판정한 뒤, 아직 안 끝났으면 다음 턴을 자동으로 연다
func end_turn() -> void:
	if battle_over:
		return

	_resolve_enemy_turn()

	if GameState.get_flag("player_hp") <= 0:
		_finish_battle(true)
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
func _resolve_enemy_turn() -> void:
	var raw_damage: int = randi_range(monster_data["damage_min"], monster_data["damage_max"])

	var damage_taken := 0
	if not _pending_dodge:
		damage_taken = max(0, raw_damage - _pending_defense)

	if damage_taken > 0:
		GameState.damage_player(damage_taken)

	enemy_turn_resolved.emit(damage_taken, _pending_dodge)

	# 임시 상태는 이번 적 턴에서만 유효 — 결과와 무관하게 소모하고 초기화한다
	_pending_defense = 0
	_pending_dodge = false


func _finish_battle(player_lost: bool) -> void:
	if battle_over:
		return
	battle_over = true
	if player_lost:
		player_defeated.emit()
	else:
		enemy_defeated.emit()


# ── 조회용 헬퍼 (UI가 붙을 때 쓰기 좋은 읽기 전용 정보) ────────────────────

func get_monster_max_hp() -> int:
	return monster_data["max_hp"]


# 이번 적 턴에 대비해 쌓아둔 방어량 (피하기 중이면 어차피 전무효라 별개로 확인할 것)
func get_pending_defense() -> int:
	return _pending_defense


func is_dodging() -> bool:
	return _pending_dodge
