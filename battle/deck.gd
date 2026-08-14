class_name Deck
extends RefCounted

# 전투 중 카드가 오가는 두 더미(뽑을 더미/버린 더미)를 관리한다.
# 프로젝트 안에 "다 떨어지면 다시 채운다"류의 기존 패턴(몬스터 조우 리젠, 발소리 사운드 풀 등)이
# 있는지 먼저 찾아봤지만, 그것들은 전부 "매번 무작위로 하나를 고르기만 하고 소모되지 않는" 방식이라
# (예: player.gd의 FOOTSTEP_*_FILES 풀, BattleData.pick_variant) 여기서 쓸 "뽑으면 줄어들고
# 바닥나면 다시 채워야 하는" 소모형 패턴과는 다르다. 그래서 로그라이크 덱빌더(예: Slay the Spire)의
# 표준 관행을 새로 도입한다: 뽑을 더미가 모자라면 버린 더미를 뽑을 더미로 합쳐 셔플한 뒤 계속 뽑는다.
# 이렇게 하면 "카드가 아예 사라지는" 일 없이 전체 카드 수가 항상 보존된다.
#
# [티어 가중치] 카드를 뽑을 때는 단순히 맨 위 한 장을 집는 게 아니라, 뽑을 더미 안의 카드들을
# 티어별 가중치(TIER_DRAW_WEIGHT)로 저울질해 한 장을 고른다. 낮은 티어일수록 가중치가 커서 더 자주,
# 높은 티어일수록 드물게 나온다. 뽑은 카드는 더미에서 빠지므로 "가중치가 붙은 비복원 추출"이고,
# 전체 카드 수 보존이라는 위 성질은 그대로 유지된다.
# 지금은 모든 카드가 TIER_1이라 가중치가 전부 같아 결과적으로 균등 추출 = 기존 동작과 동일하다.

# 티어별 뽑기 가중치. 상대적인 비(比)만 의미가 있다 — 아래 값이면 티어2는 티어1의 약 0.45배,
# 티어3은 약 0.15배 빈도로 뽑힌다. 티어2/3 카드가 실제로 추가되면 이 표의 숫자만 조정하면 되고,
# 뽑기 코드(_pick_weighted_index)는 손댈 필요가 없다
const TIER_DRAW_WEIGHT := {
	Card.CardTier.TIER_1: 100,
	Card.CardTier.TIER_2: 45,
	Card.CardTier.TIER_3: 15,
}

# 표에 없는 티어(나중에 enum만 늘리고 표를 깜빡한 경우)가 들어와도 뽑히지 않고 사라지는 일이
# 없도록, 가장 흔한 TIER_1과 같은 값으로 취급한다
const DEFAULT_TIER_DRAW_WEIGHT := 100

var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []


# cards로 뽑을 더미를 채우고 바로 섞은 채로 시작한다 (원본 배열은 복제해서 쓰므로 호출부의 배열이
# 그대로 남아있어도 안전 — 예: 카드 구성 목록을 여러 전투에 재사용하는 경우)
func _init(cards: Array[Card] = []) -> void:
	draw_pile = cards.duplicate()
	shuffle()


# 뽑을 더미를 무작위로 섞음 (Godot Array의 내장 셔플을 그대로 사용)
func shuffle() -> void:
	draw_pile.shuffle()


# 뽑을 더미 + 버린 더미를 합친 전체 보유 카드 수 (덱이 완전히 바닥났는지 판단할 때 사용)
func total_remaining() -> int:
	return draw_pile.size() + discard_pile.size()


# tier의 뽑기 가중치를 반환. 표에 없는 티어는 DEFAULT_TIER_DRAW_WEIGHT로 취급한다.
# static이라 Deck 인스턴스 없이도 조회할 수 있다 (UI에서 "이 카드가 얼마나 귀한가"를 보여줄 때 등)
static func get_tier_draw_weight(tier: int) -> int:
	return TIER_DRAW_WEIGHT.get(tier, DEFAULT_TIER_DRAW_WEIGHT)


# 카드 한 장을 뽑아 반환. 뽑을 더미가 비어 있으면 버린 더미를 합쳐 셔플한 뒤 뽑고,
# 그래도 카드가 하나도 없으면(전체 소진) null을 반환한다.
# 어느 장을 집을지는 티어 가중치로 정한다 (_pick_weighted_index 참고)
func draw_one() -> Card:
	if draw_pile.is_empty():
		_reshuffle_discard_into_draw_pile()
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_at(_pick_weighted_index())


# 뽑을 더미에서 티어 가중치에 비례한 확률로 카드 한 장의 인덱스를 고른다 (룰렛 휠 방식:
# 가중치를 누적해 총합 안에서 무작위 지점을 찍고, 그 지점이 걸린 카드를 고른다).
# 호출 전에 draw_pile이 비어 있지 않음이 보장된다(draw_one이 확인).
#
# 가중치 총합이 0 이하인 경우(모든 카드의 티어 가중치를 0으로 설정한 극단적 상황)에는 룰렛을
# 돌릴 수 없으므로 맨 뒤 카드를 집는다 — 뽑을 카드가 분명히 있는데 아무것도 못 뽑고 덱이
# 멈춰버리는 것보다, 가중치를 무시하고서라도 한 장을 내주는 쪽이 안전하다
func _pick_weighted_index() -> int:
	var last_index := draw_pile.size() - 1

	var total_weight := 0
	for card in draw_pile:
		total_weight += get_tier_draw_weight(card.tier)
	if total_weight <= 0:
		return last_index

	var roll := randi_range(1, total_weight)
	var running := 0
	for i in range(draw_pile.size()):
		running += get_tier_draw_weight(draw_pile[i].tier)
		if roll <= running:
			return i
	return last_index # 위 루프에서 반드시 반환되지만, 정수 연산 방어용으로 남겨둔다


# count장을 연속으로 뽑아 배열로 반환. 도중에 카드가 완전히 바닥나면(뽑을 더미+버린 더미 모두 빔)
# 그 시점까지 뽑은 만큼만 돌려주고 멈춘다 (요청한 수보다 적게 반환될 수 있음 — 호출부가 크기를 확인해야 함)
func draw(count: int) -> Array[Card]:
	var drawn: Array[Card] = []
	for i in range(count):
		var card := draw_one()
		if card == null:
			break
		drawn.append(card)
	return drawn


# 카드들을 버린 더미로 보낸다 (사용한 카드나, 새 손패를 뽑기 전 남은 손패를 버릴 때 사용)
func discard(cards: Array[Card]) -> void:
	discard_pile.append_array(cards)


# 버린 더미를 뽑을 더미로 옮기고 섞는다 (뽑을 더미가 바닥났을 때만 draw_one()이 호출)
func _reshuffle_discard_into_draw_pile() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle()
