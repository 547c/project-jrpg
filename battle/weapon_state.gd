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

# ── 레드라인 (과열을 이득으로 뒤집는 구간) ──────────────────────────────────
# 게이지가 이 선을 넘은 무기를 "장착한 채" 그 무기 카드를 내면 피해가 늘어난다. 즉 게이지는
# 이제 순수 페널티가 아니라 "달아오를수록 세지지만 넘기면 터지는" 자원이다.
# 100에 닿는 순간 과부하: 그 무기 계열 카드가 OVERLOAD_LOCK_ROUNDS 라운드 동안 통째로 막히고,
# 게이지는 0으로 식는다 (봉쇄가 풀리면 다시 처음부터 달군다).
#
# 선이 75가 아니라 50인 이유: 게이지가 25씩 움직이므로 75에서는 뜨거운 카드가 딱 한 장이고 그 한 장이
# 곧바로 과부하를 부른다 — "레드라인을 탄다"는 선택이 성립하지 않았다(시뮬레이션 판당 1.1회).
# 50이면 뜨거운 두 장(50→75, 75→100) 사이에 "한 장 더 지를까, 반대 무기로 식힐까"가 생긴다(판당 약 3회)
# (static var인 건 밸런스 시뮬레이터가 스윕할 때 덮어쓰기 위해서다)
static var REDLINE_THRESHOLD := 50
static var REDLINE_DAMAGE_BONUS := 0.5
static var OVERLOAD_LOCK_ROUNDS := 2

var equipped: WeaponType = WeaponType.SWORD
var sword_gauge: int = GAUGE_MIN
var staff_gauge: int = GAUGE_MIN

# 과부하로 봉쇄된 남은 라운드 수 (0이면 정상)
var sword_lock_rounds: int = 0
var staff_lock_rounds: int = 0

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


func can_switch() -> bool:
	return _switches_this_turn < MAX_SWITCHES_PER_TURN


func switches_left() -> int:
	return maxi(0, MAX_SWITCHES_PER_TURN - _switches_this_turn)


static func other_weapon(weapon: WeaponType) -> WeaponType:
	return WeaponType.STAFF if weapon == WeaponType.SWORD else WeaponType.SWORD


# 새 턴이 시작될 때 호출해 이번 턴의 무기 전환 횟수를 리셋한다 (전투 루프가 생기면 턴마다 자동으로 호출될 예정)
func reset_turn() -> void:
	_switches_this_turn = 0


func get_gauge(weapon: WeaponType) -> int:
	return sword_gauge if weapon == WeaponType.SWORD else staff_gauge


func is_overheated(weapon: WeaponType) -> bool:
	return get_lock_rounds(weapon) > 0


func get_lock_rounds(weapon: WeaponType) -> int:
	return sword_lock_rounds if weapon == WeaponType.SWORD else staff_lock_rounds


# 이 무기가 레드라인 구간인지 (게이지만 본다 — "장착 중인가"까지 따지는 건 is_redline_for_card)
func is_redline(weapon: WeaponType) -> bool:
	return get_lock_rounds(weapon) <= 0 and get_gauge(weapon) >= REDLINE_THRESHOLD


# 이 카드가 지금 레드라인 보너스를 받는지. 게이지가 오르는 조건(카드 색 == 장착 무기)과 똑같이 맞춘다 —
# 달군 무기를 손에 들고 있을 때만 뜨거워야 "무기를 바꾸면 식은 무기를 드는 것"이라는 그림이 유지된다
func is_redline_for_card(card: Card) -> bool:
	if not card.uses_weapon():
		return false
	var card_weapon := weapon_type_for_card(card)
	if card_weapon != equipped:
		return false
	return is_redline(card_weapon)


# 라운드가 끝날 때마다 봉쇄 카운터를 하나씩 깎는다 (상태이상 감소와 같은 자리에서 호출)
func tick_round() -> void:
	sword_lock_rounds = maxi(0, sword_lock_rounds - 1)
	staff_lock_rounds = maxi(0, staff_lock_rounds - 1)


# 예약 큐를 미리 굴려보는 시뮬레이션용 복제본. 큐에 무기 전환까지 들어가면서 "이 계획대로 가면
# 게이지가 어디까지 가는가"를 미리 계산해야 UI가 낼 수 있는 카드를 정확히 가려낼 수 있다
func copy() -> WeaponState:
	var clone := WeaponState.new()
	clone.equipped = equipped
	clone.sword_gauge = sword_gauge
	clone.staff_gauge = staff_gauge
	clone.sword_lock_rounds = sword_lock_rounds
	clone.staff_lock_rounds = staff_lock_rounds
	clone._switches_this_turn = _switches_this_turn
	return clone


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


# 양쪽 게이지를 0으로 식히고 봉쇄도 푼다 (스테이지 보상 "냉각" 전용)
func cool_everything() -> void:
	sword_gauge = GAUGE_MIN
	staff_gauge = GAUGE_MIN
	sword_lock_rounds = 0
	staff_lock_rounds = 0


# 카드 사용 결과로 게이지를 갱신한다. 카드 효과(데미지/회복 등) 적용은 이 함수의 책임이 아니다.
# - 카드 색깔이 "현재 장착 무기"와 일치할 때만 그 무기 게이지가 +25 쌓인다(최대 100)
# - 이때 반대편(장착하지 않은) 무기 게이지는 -25 식는다(최소 0, 음수로 내려가지 않음)
# - 색깔이 장착 무기와 다르거나(예: 검 장착 중 마법 카드), 공용 카드면 게이지는 전혀 바뀌지 않는다.
#   (과부하 상태에서 호출되더라도 값은 그저 100에서 clamp될 뿐 별도 예외를 던지지 않는다 —
#   "쓸 수 없어야 한다"는 판단은 can_use_card()의 몫이라 여기서 다시 막지 않는다)
func register_card_use(card: Card) -> bool:
	if not card.uses_weapon():
		return false

	var card_weapon := weapon_type_for_card(card)
	if card_weapon != equipped:
		return false

	var other := _other_weapon(equipped)
	_add_gauge(equipped, GAUGE_STEP)
	_add_gauge(other, -GAUGE_STEP)
	return _check_overload(equipped)


# 게이지를 지정한 값으로 직접 세팅한다 (누적이 아니라 대입). register_card_use()의 ±25 규칙과
# 별개로, Card.on_use_set_gauge 같은 "즉시 이만큼 달아오른다" 페널티를 표현하기 위한 통로다.
# 범위를 벗어난 값은 0~100으로 clamp된다
func set_gauge(weapon: WeaponType, value: int) -> void:
	var clamped: int = clampi(value, GAUGE_MIN, GAUGE_MAX)
	if weapon == WeaponType.SWORD:
		sword_gauge = clamped
	else:
		staff_gauge = clamped


# 검/지팡이 양쪽 게이지를 같은 값으로 세팅. 세팅값이 100이면 양쪽 다 그 자리에서 과부하된다
func set_both_gauges(value: int) -> Array[int]:
	set_gauge(WeaponType.SWORD, value)
	set_gauge(WeaponType.STAFF, value)
	var overloaded: Array[int] = []
	for weapon in [WeaponType.SWORD, WeaponType.STAFF]:
		if _check_overload(weapon):
			overloaded.append(int(weapon))
	return overloaded


# 게이지가 끝까지 찼으면 과부하시킨다: 그 무기 계열 카드를 몇 라운드 봉쇄하고 게이지는 0으로 식힌다.
# 봉쇄 중에는 게이지가 다시 오르지 않으므로(카드를 못 내니까) 풀릴 때까지 0으로 남는다
func _check_overload(weapon: WeaponType) -> bool:
	if get_gauge(weapon) < GAUGE_MAX:
		return false
	set_gauge(weapon, GAUGE_MIN)
	if weapon == WeaponType.SWORD:
		sword_lock_rounds = OVERLOAD_LOCK_ROUNDS
	else:
		staff_lock_rounds = OVERLOAD_LOCK_ROUNDS
	return true


func _add_gauge(weapon: WeaponType, delta: int) -> void:
	var clamped: int = clampi(get_gauge(weapon) + delta, GAUGE_MIN, GAUGE_MAX)
	if weapon == WeaponType.SWORD:
		sword_gauge = clamped
	else:
		staff_gauge = clamped


static func _other_weapon(weapon: WeaponType) -> WeaponType:
	return WeaponType.STAFF if weapon == WeaponType.SWORD else WeaponType.SWORD
