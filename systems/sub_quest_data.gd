class_name SubQuestData
extends RefCounted

# 의뢰(서브 퀘스트) 생성기. 메인 퀘스트와 달리 고정 카탈로그가 없고 의뢰판을 열 때마다 즉석에서 만든다.
# 진행 상태는 여기가 아니라 GameState.active_sub_quest가 들고 있다 (세이브에 담겨야 하므로).

const MONSTER_TYPES: Array[String] = ["ORC", "SKELETON", "MUMMY"]

const BOARD_SIZE := 3
const REFRESH_COST := 5

const TWO_TYPE_CHANCE := 0.30
const COUNT_MIN := 2
const COUNT_MAX := 5

const GOLD_PER_MONSTER_MIN := 15
const GOLD_PER_MONSTER_MAX := 25
const XP_PER_MONSTER_MIN := 6
const XP_PER_MONSTER_MAX := 10
const AFFINITY_MIN := 3
const AFFINITY_MAX := 8

const BONUS_ITEM_CHANCE := 0.25
const BONUS_EQUIPMENT_CHANCE := 0.15
const BONUS_ITEM_POOL: Array[String] = ["hp_potion", "mana_potion", "gift"]

# 보너스 장비의 등급 상한. 총 마릿수가 많을수록 높은 등급까지 열리고, 그 안에서의 등급 추첨은
# 기존 몬스터 드롭/상자와 같은 가중치(ItemData.TIER_DROP_WEIGHT)를 그대로 쓴다
const EQUIPMENT_TIER_STEPS: Array = [
	{"max_total": 5, "tier": ItemData.TIER_WOOD},
	{"max_total": 8, "tier": ItemData.TIER_BONE},
]
const EQUIPMENT_TIER_TOP := ItemData.TIER_GOLD

const GIVER := "엘라라"


static func generate_board(size: int = BOARD_SIZE) -> Array:
	var board: Array = []
	for i in range(size):
		board.append(generate_one())
	return board


static func generate_one() -> Dictionary:
	var types := MONSTER_TYPES.duplicate()
	types.shuffle()
	var type_count := 2 if randf() < TWO_TYPE_CHANCE else 1

	var targets: Dictionary = {}
	var progress: Dictionary = {}
	var total := 0
	for i in range(type_count):
		var monster_type: String = types[i]
		var amount := randi_range(COUNT_MIN, COUNT_MAX)
		targets[monster_type] = amount
		progress[monster_type] = 0
		total += amount

	var quest: Dictionary = {
		"id": "bounty_%d_%d" % [Time.get_ticks_msec(), randi() % 100000],
		"targets": targets,
		"progress": progress,
		"gold": total * randi_range(GOLD_PER_MONSTER_MIN, GOLD_PER_MONSTER_MAX),
		"xp": total * randi_range(XP_PER_MONSTER_MIN, XP_PER_MONSTER_MAX),
		"affinity": randi_range(AFFINITY_MIN, AFFINITY_MAX),
		"bonus_item": "",
		"bonus_equipment": "",
	}

	if randf() < BONUS_ITEM_CHANCE:
		quest["bonus_item"] = BONUS_ITEM_POOL[randi() % BONUS_ITEM_POOL.size()]
	if randf() < BONUS_EQUIPMENT_CHANCE:
		quest["bonus_equipment"] = ItemData.pick_random_equipment_up_to(equipment_tier_cap(total))

	return quest


static func equipment_tier_cap(total: int) -> String:
	for step in EQUIPMENT_TIER_STEPS:
		if total <= int(step["max_total"]):
			return String(step["tier"])
	return EQUIPMENT_TIER_TOP


static func total_target(quest: Dictionary) -> int:
	var total := 0
	for amount in quest.get("targets", {}).values():
		total += int(amount)
	return total


static func total_progress(quest: Dictionary) -> int:
	var total := 0
	for amount in quest.get("progress", {}).values():
		total += int(amount)
	return total


static func is_complete(quest: Dictionary) -> bool:
	if quest.is_empty():
		return false
	var targets: Dictionary = quest.get("targets", {})
	var progress: Dictionary = quest.get("progress", {})
	for monster_type in targets.keys():
		if int(progress.get(monster_type, 0)) < int(targets[monster_type]):
			return false
	return true


static func monster_name(monster_type: String) -> String:
	var data: Dictionary = BattleData.MONSTERS.get(monster_type, {})
	return String(data.get("name", monster_type))


static func title(quest: Dictionary) -> String:
	return "%s 토벌 의뢰" % describe_targets(quest)


# "오크 3마리" / "오크 3마리 + 스켈레톤 2마리"
static func describe_targets(quest: Dictionary) -> String:
	var parts: Array[String] = []
	for monster_type in quest.get("targets", {}).keys():
		parts.append("%s %d마리" % [monster_name(monster_type), int(quest["targets"][monster_type])])
	return " + ".join(parts)


# "오크 1/3 · 스켈레톤 0/2" — 퀘스트로그의 진행도 줄
static func describe_progress(quest: Dictionary) -> String:
	var parts: Array[String] = []
	var progress: Dictionary = quest.get("progress", {})
	for monster_type in quest.get("targets", {}).keys():
		parts.append("%s %d/%d" % [
			monster_name(monster_type),
			int(progress.get(monster_type, 0)),
			int(quest["targets"][monster_type]),
		])
	return " · ".join(parts)


static func describe_rewards(quest: Dictionary) -> String:
	var parts: Array[String] = [
		"골드 %d" % int(quest.get("gold", 0)),
		"경험치 %d" % int(quest.get("xp", 0)),
		"%s 호감도 +%d" % [GIVER, int(quest.get("affinity", 0))],
	]
	var bonus := describe_bonus(quest)
	if bonus != "":
		parts.append(bonus)
	return " · ".join(parts)


static func describe_bonus(quest: Dictionary) -> String:
	var names: Array[String] = []
	for key in ["bonus_item", "bonus_equipment"]:
		var item_id: String = String(quest.get(key, ""))
		if item_id != "" and ItemData.ITEMS.has(item_id):
			names.append(String(ItemData.ITEMS[item_id]["name"]))
	if names.is_empty():
		return ""
	return "보너스: " + ", ".join(names)
