class_name Hand
extends RefCounted

# 현재 손에 쥔 카드들. 실제 카드 이동(뽑을 더미/버린 더미)은 Deck이 전담하고,
# Hand는 "지금 쥐고 있는 카드 목록"만 다루는 얇은 래퍼다.
#
# 턴 시작 시 동작(draw_new_hand)은: 이전 턴에 쓰지 않고 남은 손패가 있다면 먼저 버린 더미로 보낸 뒤,
# 새로 5장을 뽑는다. 아직 "카드 사용" 로직 자체가 없어 손패가 남는 일은 없지만, 나중에 사용 로직이
# 붙었을 때(턴마다 손패를 새로 채우는 로그라이크 덱빌더의 표준 관행) 자연스럽게 맞물리도록
# 미리 이 규칙을 넣어둔다.

const DEFAULT_HAND_SIZE := 5

var cards: Array[Card] = []


# 남은 손패를 버린 뒤 deck에서 count장을 새로 뽑아 손패를 채운다.
# deck에 카드가 부족하면(전체 소진 임박) count장보다 적게 채워질 수 있다 — size()로 실제 결과를 확인할 것
func draw_new_hand(deck: Deck, count: int = DEFAULT_HAND_SIZE) -> void:
	if not cards.is_empty():
		deck.discard(cards)
		cards.clear()
	cards = deck.draw(count)


func size() -> int:
	return cards.size()


func is_empty() -> bool:
	return cards.is_empty()
