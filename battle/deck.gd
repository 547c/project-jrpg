class_name Deck
extends RefCounted

# 전투 중 카드가 오가는 두 더미(뽑을 더미/버린 더미)를 관리한다.
# 프로젝트 안에 "다 떨어지면 다시 채운다"류의 기존 패턴(몬스터 조우 리젠, 발소리 사운드 풀 등)이
# 있는지 먼저 찾아봤지만, 그것들은 전부 "매번 무작위로 하나를 고르기만 하고 소모되지 않는" 방식이라
# (예: player.gd의 FOOTSTEP_*_FILES 풀, BattleData.pick_variant) 여기서 쓸 "뽑으면 줄어들고
# 바닥나면 다시 채워야 하는" 소모형 패턴과는 다르다. 그래서 로그라이크 덱빌더(예: Slay the Spire)의
# 표준 관행을 새로 도입한다: 뽑을 더미가 모자라면 버린 더미를 뽑을 더미로 합쳐 셔플한 뒤 계속 뽑는다.
# 이렇게 하면 "카드가 아예 사라지는" 일 없이 전체 카드 수가 항상 보존된다.

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


# 카드 한 장을 뽑아 반환. 뽑을 더미가 비어 있으면 버린 더미를 합쳐 셔플한 뒤 뽑고,
# 그래도 카드가 하나도 없으면(전체 소진) null을 반환한다
func draw_one() -> Card:
	if draw_pile.is_empty():
		_reshuffle_discard_into_draw_pile()
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_back()


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
