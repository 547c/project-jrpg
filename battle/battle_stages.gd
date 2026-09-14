class_name BattleStages
extends RefCounted

# 전투 하나를 3~4개의 스테이지로 쪼갠 "전투 편성표"와, 스테이지 사이에 고르는 보상 목록.
#
# [왜 스테이지인가] 한 판이 한 무리로 끝나면 과열 게이지·체력·마나를 아낄 이유가 없어서, 결국
# 매 전투가 "가진 걸 다 쏟아붓는" 한 번의 폭발로 수렴한다. 스테이지를 이어 붙이고 자원을 넘겨받게
# 하면 "지금 태울까, 다음 무리를 위해 남길까"라는 판단이 매 라운드 생긴다 — Slay the Spire의
# 체력이 여정 전체의 자원인 구조를 전투 한 판 안으로 압축한 것에 가깝다.
#
# 자원은 스테이지 사이에 자동으로 회복되지 않는다. 회복/조정은 오직 아래 보상 선택으로만 일어나고,
# 모든 보상에는 반드시 대가가 붙는다 (Monster Train의 "이득에 값을 치르는" 선택과 같은 결).

const MIN_STAGES := 3
const MAX_STAGES := 4
const MAX_MONSTERS_PER_STAGE := 3

# 스테이지 몬스터는 "한 무리를 이루는 졸개"라 필드 단독 조우 때의 체력/위력을 그대로 주지 않는다.
# 스테이지가 3~4개로 이어지는데 원래 수치를 두면 한 판에 필드 전투 서너 번을 연달아 치르는 셈이라,
# 카드 1장 = 반격 1회라는 교환 구조에서 버틸 수가 없다 (원래 수치로 시뮬레이션하면 승률 0%).
# 뒤 스테이지로 갈수록 올라가 긴장이 마지막에 몰리게 했다 — 튜닝 결과 패배의 대부분이 3~4스테이지에서 난다.
# (static var인 건 tests/battle_sim.gd가 스윕할 때 덮어쓰기 위해서다)
static var STAGE_HP_SCALE: Array[float] = [0.3, 0.35, 0.4, 0.45]
static var STAGE_DAMAGE_SCALE: Array[float] = [0.4, 0.5, 0.55, 0.65]


# 몬스터 종류별 스테이지 난이도 계수 (체력/공격력 배율에 함께 곱한다). 필드에서 오크는 기본 덱을 든
# 초반 캐릭터가, 미라는 카드를 대부분 풀어둔 후반 캐릭터가 만나는 적이라, 같은 배율을 쓰면 오크 전투만
# 유독 가혹해진다 (시뮬레이션 기준 같은 배율에서 오크 Lv1 승률 7% vs 미라 Lv8 81%)
static var TYPE_DIFFICULTY: Dictionary = {"ORC": 0.8, "SKELETON": 0.8, "MUMMY": 1.15}


static func hp_scale_for(index: int, monster_type: String = "") -> float:
	return STAGE_HP_SCALE[clampi(index, 0, STAGE_HP_SCALE.size() - 1)] * float(TYPE_DIFFICULTY.get(monster_type, 1.0))


static func damage_scale_for(index: int, monster_type: String = "") -> float:
	return STAGE_DAMAGE_SCALE[clampi(index, 0, STAGE_DAMAGE_SCALE.size() - 1)] * float(TYPE_DIFFICULTY.get(monster_type, 1.0))


# 이번 전투의 스테이지 편성을 만든다. 각 항목은
# {"variants": Array[Dictionary], "elites": Array[bool]} 이고 배열 길이가 곧 마리 수다.
#
# first_variant는 필드에서 부딪힌 그 개체의 모습 — 첫 스테이지 0번 자리에 그대로 이어 붙여야
# "방금 만난 그 몬스터"로 읽힌다 (기존 단일 전투 규칙을 스테이지 1에 유지).
static func build_plan(monster_type: String, first_variant: Dictionary = {}) -> Array[Dictionary]:
	# 보스처럼 항상 혼자 나오는 종류는 스테이지로 쪼개지 않는다 — "혼자 버티는 벽"이라는 설계라
	# 여러 무리로 늘리면 의미가 달라진다
	if monster_type in BattleData.SOLO_ONLY_TYPES:
		return [{
			"variants": [first_variant if not first_variant.is_empty() else BattleData.pick_variant(monster_type)],
			"elites": [false],
		}]

	var stage_count := randi_range(MIN_STAGES, MAX_STAGES)
	var stages: Array[Dictionary] = []
	for i in range(stage_count):
		var is_last := i == stage_count - 1
		var count := _roll_stage_count(i, is_last)
		var elite_count := _roll_elite_count(i, is_last, count)

		var variants: Array[Dictionary] = []
		var elites: Array[bool] = []
		for slot in range(count):
			if i == 0 and slot == 0 and not first_variant.is_empty():
				variants.append(first_variant)
			else:
				variants.append(BattleData.pick_variant(monster_type))
			# 엘리트는 뒷자리(화면 안쪽)부터 채워 넣는다 — 앞줄이 전부 엘리트라 첫인상이 과해지지 않게
			elites.append(slot >= count - elite_count)

		stages.append({"variants": variants, "elites": elites})
	return stages


# 스테이지 1은 가볍게 시작하고(1~2마리), 뒤로 갈수록 머릿수가 늘어난다
static func _roll_stage_count(index: int, is_last: bool) -> int:
	if index == 0:
		return 1 if randf() < 0.4 else 2
	if is_last:
		return 2 if randf() < 0.35 else 3
	return 2 if randf() < 0.6 else 3


# 엘리트는 2스테이지부터 섞이고 마지막 스테이지에 가장 많다
static func _roll_elite_count(index: int, is_last: bool, count: int) -> int:
	if index == 0:
		return 0
	if is_last:
		return mini(count, 1 if randf() < 0.55 else 2)
	return 1 if randf() < 0.6 else 0


# ── 스테이지 보상 ──────────────────────────────────────────────────────────
# 각 항목은 "이득 하나 + 대가 하나"로만 이루어진다. 이득만 있는 선택지가 하나라도 섞이면 나머지를
# 고를 이유가 사라지므로 예외를 두지 않았다.
#
# effect 키가 곧 적용 규칙이다 (BattleTurnManager.apply_stage_reward가 읽는다):
#   heal_fraction      최대 체력의 이 비율만큼 즉시 회복
#   mana_full          마나를 최대치까지 회복
#   hp_cost_fraction   최대 체력의 이 비율만큼 즉시 소모 (죽지 않도록 최소 1은 남는다)
#   cool_weapons       양쪽 과열 게이지 0 + 봉쇄 해제
#   card_power         {"bonus": float} — 지목된 카드의 위력을 이 비율만큼 올린다 (이번 전투 내내)
#   free_first_round   다음 스테이지 첫 라운드 동안 카드 비용 0
#   next_hand_delta    다음 스테이지 손패 장수 증감
#   next_hp_mult       다음 스테이지 몬스터 최대 체력 배율
#   next_damage_mult   다음 스테이지 몬스터 공격력 배율
#   next_count_delta   다음 스테이지 마리 수 증감 (최소 1)
const OFFERS: Array[Dictionary] = [
	{
		"id": "engrave",
		"title": "각인",
		"benefit": "%s의 위력 +50%% (이번 전투 내내)",
		"cost": "다음 스테이지 몬스터 체력 +20%",
		"effect": {"card_power": 0.5, "next_hp_mult": 1.2},
		"needs_card": true,
	},
	{
		"id": "first_aid",
		"title": "응급 처치",
		"benefit": "최대 체력의 40% 회복",
		"cost": "다음 스테이지 몬스터 공격력 +30%",
		"effect": {"heal_fraction": 0.4, "next_damage_mult": 1.3},
	},
	{
		"id": "coolant",
		"title": "냉각",
		"benefit": "양쪽 과열 게이지 0 · 봉쇄 해제",
		"cost": "다음 스테이지 손패 1장 감소",
		"effect": {"cool_weapons": true, "next_hand_delta": -1},
	},
	{
		"id": "stockpile",
		"title": "비축",
		"benefit": "마나 완전 회복",
		"cost": "지금 최대 체력의 12% 소모",
		"effect": {"mana_full": true, "hp_cost_fraction": 0.12},
	},
	{
		"id": "vanguard",
		"title": "선제",
		"benefit": "다음 스테이지 첫 라운드 카드 비용 0",
		"cost": "다음 스테이지 몬스터 체력 +25%",
		"effect": {"free_first_round": true, "next_hp_mult": 1.25},
	},
	{
		"id": "cull",
		"title": "솎아내기",
		"benefit": "다음 스테이지 몬스터 1마리 감소",
		"cost": "남은 몬스터 공격력 +50%",
		"effect": {"next_count_delta": -1, "next_damage_mult": 1.5},
	},
]


# 이번 선택에 띄울 3개를 고른다. context는
# {"hp_ratio": float, "mana_ratio": float, "next_count": int, "card_names": Array[String]}.
# 상황상 의미가 없는 항목(체력이 꽉 찼는데 회복, 이미 1마리인데 솎아내기)은 후보에서 빼, 고를 게
# 셋인데 실제로는 하나뿐인 선택지 화면이 나오지 않게 한다
static func roll_offers(context: Dictionary, count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for offer in OFFERS:
		if not _is_eligible(offer, context):
			continue
		pool.append(_build_offer(offer, context))

	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


static func _is_eligible(offer: Dictionary, context: Dictionary) -> bool:
	var effect: Dictionary = offer["effect"]
	if effect.has("heal_fraction") and float(context.get("hp_ratio", 1.0)) >= 0.99:
		return false
	if effect.has("mana_full") and float(context.get("mana_ratio", 1.0)) >= 0.99:
		return false
	# 체력을 대가로 내는 선택지는 빈사일 때 아예 띄우지 않는다 (고른 순간 죽을 뻔한 상황을 만들지 않게)
	if effect.has("hp_cost_fraction") and float(context.get("hp_ratio", 1.0)) <= 0.3:
		return false
	if effect.has("next_count_delta") and int(context.get("next_count", 1)) <= 1:
		return false
	if offer.get("needs_card", false) and (context.get("card_names", []) as Array).is_empty():
		return false
	return true


static func _build_offer(offer: Dictionary, context: Dictionary) -> Dictionary:
	var built := offer.duplicate(true)
	if offer.get("needs_card", false):
		var names: Array = context.get("card_names", [])
		var picked: String = names[randi() % names.size()]
		built["card_name"] = picked
		built["benefit"] = built["benefit"] % picked
	return built
