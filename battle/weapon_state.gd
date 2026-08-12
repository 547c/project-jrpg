class_name WeaponState
extends RefCounted

# 전투 중 장착 무기와 무기별 "과열 게이지"를 관리한다 (전투 재설계 스펙 4항/4-2항 기준).
# 검/지팡이 각각 독립된 게이지(0~100)를 갖고, "지금 장착한 무기"와 색깔이 일치하는 카드를 쓸 때마다
# 그 무기 게이지가 25%씩 쌓인다. 4연속 사용(25*4=100)이면 과부하가 되어 그 무기 카드를 더 이상
# 쓸 수 없게 되고, 반대로 그 카드를 쓰는 순간 "쉬고 있던" 다른 무기 게이지가 25만큼 식는다.
# 그래서 한쪽 무기만 계속 쓰면 스스로 막히고, 번갈아 써야 양쪽 다 계속 굴러가는 구조가 된다.
#
# 이 파일은 게이지 상태와 "지금 쓸 수 있는가" 판정만 다룬다. 실제 카드 효과 적용(데미지/회복 등)과
# 전투 턴 루프, UI는 아직 없다 — register_card_use()는 게이지만 갱신하고, can_use_card()는
# 검증만 한다. 둘 다 "카드를 실제로 쓸지"는 호출부(아직 없는 전투 루프)가 can_use_card()로
# 먼저 확인한 뒤 register_card_use()를 부르는 순서를 전제로 한다.

enum WeaponType { SWORD, STAFF }

const GAUGE_MIN := 0
const GAUGE_MAX := 100
const GAUGE_STEP := 25 # 카드 한 번 사용 = 25% (4연속 사용 = 100% = 과부하)

const MAX_SWITCHES_PER_TURN := 3 # 턴당 최대 무기 전환 횟수 — 무한 "딸깍"으로 저항/과열을 완전히 무력화하지 못하게 막는 안전판

var equipped: WeaponType = WeaponType.SWORD
var sword_gauge: int = GAUGE_MIN
var staff_gauge: int = GAUGE_MIN

var _switches_this_turn: int = 0


# 장착 무기를 바꾼다. 성공했으면 턴도, 다른 자원도 소모하지 않는 완전 무료 행동이고(게이지 등
# 다른 상태는 전혀 건드리지 않음), 대신 턴당 MAX_SWITCHES_PER_TURN(3)번까지만 허용된다.
# 이미 3번 전환했다면 4번째 시도부터는 조용히 무시되고(equipped 그대로) false를 반환한다.
# 성공 시에만 true를 반환하므로, 호출부가 반환값으로 실제 전환 여부를 알 수 있다.
# "턴"이라는 개념 자체는 아직 전투 루프에 없어서, 새 턴이 시작될 때 reset_turn()을 호출해
# 이 횟수를 0으로 되돌려야 한다 — 지금은 아직 턴 루프가 없어 헤드리스 테스트가 직접 호출해 검증한다
func switch_weapon(weapon: WeaponType) -> bool:
	if _switches_this_turn >= MAX_SWITCHES_PER_TURN:
		return false
	equipped = weapon
	_switches_this_turn += 1
	return true


# 새 턴이 시작될 때 호출해 이번 턴의 무기 전환 횟수를 리셋한다 (전투 루프가 생기면 턴마다 자동으로 호출될 예정)
func reset_turn() -> void:
	_switches_this_turn = 0


func get_gauge(weapon: WeaponType) -> int:
	return sword_gauge if weapon == WeaponType.SWORD else staff_gauge


func is_overheated(weapon: WeaponType) -> bool:
	return get_gauge(weapon) >= GAUGE_MAX


# card.color(PHYSICAL/MAGIC)에 대응하는 무기 타입을 반환한다. NEUTRAL 카드는 대응 무기가 없으므로
# 호출 전에 card.uses_weapon()으로 걸러야 한다 — 여기서는 매핑만 담당
static func weapon_type_for_card(card: Card) -> WeaponType:
	return WeaponType.SWORD if card.color == Card.CardColor.PHYSICAL else WeaponType.STAFF


# 이 카드를 "지금" 사용할 수 있는지 검증만 한다 (실제 카드 사용/전투 루프는 아직 없음).
# uses_weapon()이 true인 카드는, 그 카드에 대응하는 무기가 과부하(게이지 100) 상태면 쓸 수 없다.
# 장착 여부와 무관하게 그 색깔 자체가 막힌다 — 예: 검이 과부하면 지팡이로 바꿔 들어도
# 물리 카드는 여전히 못 쓴다(과부하는 "그 무기 계열 카드"를 막는 것이지 장착 상태를 막는 게 아님).
# 공용(NEUTRAL) 카드는 무기 게이지와 무관하므로 이 함수 기준으로는 항상 사용 가능
func can_use_card(card: Card) -> bool:
	if not card.uses_weapon():
		return true
	return not is_overheated(weapon_type_for_card(card))


# 카드 사용 결과로 게이지를 갱신한다. 카드 효과(데미지/회복 등) 적용은 이 함수의 책임이 아니다.
# - 카드 색깔이 "현재 장착 무기"와 일치할 때만 그 무기 게이지가 +25 쌓인다(최대 100)
# - 이때 반대편(장착하지 않은) 무기 게이지는 -25 식는다(최소 0, 음수로 내려가지 않음)
# - 색깔이 장착 무기와 다르거나(예: 검 장착 중 마법 카드), 공용 카드면 게이지는 전혀 바뀌지 않는다.
#   (과부하 상태에서 호출되더라도 값은 그저 100에서 clamp될 뿐 별도 예외를 던지지 않는다 —
#   "쓸 수 없어야 한다"는 판단은 can_use_card()의 몫이라 여기서 다시 막지 않는다)
func register_card_use(card: Card) -> void:
	if not card.uses_weapon():
		return

	var card_weapon := weapon_type_for_card(card)
	if card_weapon != equipped:
		return

	var other := _other_weapon(equipped)
	_add_gauge(equipped, GAUGE_STEP)
	_add_gauge(other, -GAUGE_STEP)


func _add_gauge(weapon: WeaponType, delta: int) -> void:
	var clamped: int = clampi(get_gauge(weapon) + delta, GAUGE_MIN, GAUGE_MAX)
	if weapon == WeaponType.SWORD:
		sword_gauge = clamped
	else:
		staff_gauge = clamped


static func _other_weapon(weapon: WeaponType) -> WeaponType:
	return WeaponType.STAFF if weapon == WeaponType.SWORD else WeaponType.SWORD
