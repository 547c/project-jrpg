class_name StarterDeck
extends RefCounted

# 전투 시작 시 플레이어에게 주어지는 기본 덱 구성. 카드 정의 자체는 battle/cards/*.tres에 있고,
# 여기서는 "무엇을 몇 장 넣을지"만 정한다 — 덱을 바꾸고 싶으면 이 목록만 손대면 된다.
# (나중에 장비/진행도에 따라 덱이 달라지면 build()에 인자를 받게 확장하면 됨)
#
# 14장 구성: 공격 카드가 과반이라 매 턴 뭔가 할 수 있고, 회복/방어/피하기가 섞여 있어
# 무기 과열이 걸렸을 때 쓸 공용 카드가 손에 남도록 했다.

const DECK_LIST: Array = [
	{"path": "res://battle/cards/wooden_sword_slash.tres", "count": 5}, # 물리 공격 (마나 불필요)
	{"path": "res://battle/cards/magic_bolt.tres", "count": 3},         # 마법 공격 (마나 4)
	{"path": "res://battle/cards/guard.tres", "count": 2},              # 방어
	{"path": "res://battle/cards/heal_light.tres", "count": 2},         # 체력 회복
	{"path": "res://battle/cards/mana_draught.tres", "count": 1},       # 마나 회복
	{"path": "res://battle/cards/dodge_roll.tres", "count": 1},         # 피하기
]


# 덱 한 벌을 새로 만들어 반환. 같은 .tres를 여러 장 넣을 때 duplicate()로 각각 별개의 인스턴스를
# 만드는 이유는, Godot이 같은 경로의 리소스를 캐시해 돌려주기 때문이다 — 그대로 넣으면 5장이 전부
# 동일한 객체가 되어 손패에서 특정 한 장을 지우는 동작이 헷갈릴 수 있다
static func build() -> Array[Card]:
	var cards: Array[Card] = []
	for entry in DECK_LIST:
		var prototype := load(entry["path"]) as Card
		if prototype == null:
			continue
		for i in range(int(entry["count"])):
			cards.append(prototype.duplicate() as Card)
	return cards
