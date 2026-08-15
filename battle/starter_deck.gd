class_name StarterDeck
extends RefCounted

# 전투 시작 시 플레이어에게 주어지는 기본 덱 구성. 카드 정의 자체는 battle/cards/*.tres에 있고,
# 여기서는 "무엇을 몇 장 넣을지"만 정한다 — 덱을 바꾸고 싶으면 이 목록만 손대면 된다.
# (나중에 장비/진행도에 따라 덱이 달라지면 build()에 인자를 받게 확장하면 됨)
#
# 기본 14장(잠금해제 전) / 전부 풀면 26장 구성: 공격 카드가 과반이라 매 턴 뭔가 할 수 있고,
# 회복/방어/피하기가 섞여 있어 무기 과열이 걸렸을 때 쓸 공용 카드가 손에 남도록 했다.
#
# [티어2/3 장 수] 뽑힐 확률 자체는 Deck.TIER_DRAW_WEIGHT(티어1=100, 티어2=45, 티어3=15)가 이미
# 낮춰주므로, 여기서 장 수까지 줄여 이중으로 희귀하게 만들지 않는다 — 대신 같은 "역할"의 티어1
# 카드와 비슷한 장 수를 넣어, 표본이 너무 적어 그 카드만 유독 안 나오는 것처럼 보이는 일이 없게 했다.
# 역할 대응: 섬광~베기(물리 공격), 파이어볼/익스플로전~마력탄(마법 공격), 초재생~치유의 빛+마나
# 회복(둘 다 회복), 삼중나선~베기(물리 공격, 더 무거움), 카운터 슬래쉬~방어(공용 방어형)
#
# [잠금해제와의 관계] 여기 적힌 건 "그 카드를 갖고 있다면 몇 장 넣을지"다. 실제로 덱에 들어갈지는
# GameState.unlocked_cards가 정하며, 잠기지 않은 카드만 build()가 통과시킨다. 그래서 티어2/3 항목을
# 미리 적어둬도 스킬포인트로 풀기 전까지는 덱에 한 장도 들어가지 않는다
const DECK_LIST: Array = [
	{"id": "wooden_sword_slash", "count": 5}, # 물리 공격 (마나 불필요)
	{"id": "magic_bolt", "count": 3},         # 마법 공격 (마나 4)
	{"id": "guard", "count": 2},              # 방어
	{"id": "heal_light", "count": 2},         # 체력 회복
	{"id": "mana_draught", "count": 1},       # 마나 회복
	{"id": "dodge_roll", "count": 1},         # 피하기
	{"id": "flash_slash", "count": 3},        # [티어2] 물리 공격 (마나 2)
	{"id": "fireball", "count": 2},           # [티어2] 마법 공격 (마나 6)
	{"id": "super_regen", "count": 2},        # [티어2] 체력+마나 동시 회복
	{"id": "triple_helix", "count": 2},       # [티어3] 물리 공격 (체력 3 소모)
	{"id": "explosion", "count": 1},          # [티어3] 마법 공격 (마나 10)
	{"id": "counter_slash", "count": 2},      # [티어3] 반격 (마나 5)
]


# 덱 한 벌을 새로 만들어 반환. 잠금해제되지 않은 카드는 건너뛴다.
# 같은 카드를 여러 장 넣을 때 duplicate()로 각각 별개의 인스턴스를 만드는 이유는, Godot이 같은
# 경로의 리소스를 캐시해 돌려주기 때문이다 — 그대로 넣으면 5장이 전부 동일한 객체가 되어
# 손패에서 특정 한 장을 지우는 동작이 헷갈릴 수 있다
static func build() -> Array[Card]:
	var cards: Array[Card] = []
	for entry in DECK_LIST:
		var card_id: String = entry["id"]
		if not GameState.is_card_unlocked(card_id):
			continue
		var prototype := CardLibrary.get_card(card_id)
		if prototype == null:
			continue
		for i in range(int(entry["count"])):
			cards.append(prototype.duplicate() as Card)
	return cards
