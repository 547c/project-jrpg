class_name ItemData
extends RefCounted

# 아이템 정의. 새 아이템을 추가할 땐 여기에 항목만 늘리면 됨.
# icon_path/icon_region: GUI 팩(medieval.png)에서 아이콘으로 쓸 영역을 오려낼 좌표
# 아이콘은 items 팩의 개별 16x16 PNG를 그대로 씀(region은 전체 프레임 Rect2(0,0,16,16)).
# consumable: false면 인벤토리에서 클릭해도 소비/효과가 없음(열쇠처럼 유지형 아이템용, 기본값 true)
const ICON_REGION_16 := Rect2(0, 0, 16, 16)
const ITEMS_DIR := "res://assets/items/Free RPG asset Pack/separate files/"

# ── 장비 슬롯 ──────────────────────────────────────────────────────────────
# 한 슬롯에는 한 번에 하나만 장착된다. GameState가 슬롯별로 장착 중인 item_id를 들고 있다
const SLOT_SWORD := "sword"
const SLOT_STAFF := "staff"
const SLOT_SHIELD := "shield"
const EQUIPMENT_SLOTS: Array[String] = [SLOT_SWORD, SLOT_STAFF, SLOT_SHIELD]

# ── 장비 등급 ──────────────────────────────────────────────────────────────
const TIER_NONE := "none" # 미장착(또는 장비가 아닌 아이템)일 때의 등급
const TIER_WOOD := "wood"
const TIER_BONE := "bone"
const TIER_GOLD := "gold"

# 등급별 스탯 테이블. 장비 스탯은 전부 여기서만 정의하므로 밸런스 조정 시 이 딕셔너리만 고치면 된다.
# - sword_damage: 검 장착 시 물리(PHYSICAL) 카드 피해에 더할 값
# - staff_damage: 지팡이 장착 시 마법(MAGIC) 카드 피해에 더할 값
# - max_hp: 방패 장착 시 최대 체력에 더할 값 (상시 패시브)
# 각 슬롯은 자기 항목만 쓴다 (검은 sword_damage만, 방패는 max_hp만 의미가 있음)
const TIER_STATS: Dictionary = {
	TIER_NONE: {"sword_damage": 0, "staff_damage": 0, "max_hp": 0},
	TIER_WOOD: {"sword_damage": 1, "staff_damage": 1, "max_hp": 5},
	TIER_BONE: {"sword_damage": 2, "staff_damage": 2, "max_hp": 10},
	TIER_GOLD: {"sword_damage": 4, "staff_damage": 4, "max_hp": 20},
}

# 낮은 등급부터 나열한 순서 (지역/몬스터별 "최대 등급" 비교에 사용)
const TIER_ORDER: Array[String] = [TIER_WOOD, TIER_BONE, TIER_GOLD]

# "최대 등급 이하에서 하나 뽑기"를 할 때 쓰는 등급별 가중치.
# 한 단계 올라갈 때마다 확률이 대략 절반으로 줄어, 상한이 높은 지역일수록 상위 등급이
# 나오긴 하지만 여전히 하위 등급이 더 흔하게 나온다
# (예: 상한이 금이면 나무 60% / 뼈 30% / 금 10%)
const TIER_DROP_WEIGHT: Dictionary = {
	TIER_WOOD: 6,
	TIER_BONE: 3,
	TIER_GOLD: 1,
}

const ITEMS: Dictionary = {
	"mana_potion": {
		"name": "마나포션",
		"description": "마나 50% 회복",
		"icon_path": ITEMS_DIR + "mana_potion.png",
		"icon_region": ICON_REGION_16,
		"mana_restore_fraction": 0.5,
	},
	"hp_potion": {
		"name": "체력포션",
		"description": "체력 50% 회복",
		"icon_path": ITEMS_DIR + "hp_potion.png",
		"icon_region": ICON_REGION_16,
		"hp_restore_fraction": 0.5,
	},
	"gift": {
		"name": "작은 선물",
		"description": "누군가에게 선물하면 기뻐할 것이다",
		"icon_path": ITEMS_DIR + "wooden_box.png",
		"icon_region": ICON_REGION_16,
	},
	"ruins_key": {
		"name": "유적의 열쇠",
		"description": "이걸로 사막 유적의 문을 열 수 있을 것 같다", # 인벤토리에서 마우스를 올리면 뜨는 힌트
		"icon_path": ITEMS_DIR + "necklace_02.png", # 사막 팩에 열쇠 이미지가 없어 장식된 부적 아이콘 재사용
		"icon_region": ICON_REGION_16,
		"consumable": false, # 유적 입구에서 사용해도 소진되지 않는 유지형 아이템
	},

	# ── 장비 (검/지팡이/방패 × 나무/뼈/금 3등급) ────────────────────────────
	# 전부 consumable: false — 인벤토리에서 클릭해도 소모되지 않는다.
	# slot/tier는 장착 로직(GameState)과 스탯 조회(TIER_STATS)가 읽는 필드다
	"wooden_sword": {
		"name": "나무검",
		"description": "물리 피해 +1",
		"icon_path": ITEMS_DIR + "stone sword.png", # 가장 투박한 검 아이콘 (파일명은 stone이지만 무광 회색이라 최하급용으로 씀)
		"icon_region": ICON_REGION_16,
		"consumable": false,
		"slot": SLOT_SWORD,
		"tier": TIER_WOOD,
	},
	"bone_sword": {
		"name": "뼈검",
		"description": "물리 피해 +2",
		"icon_path": ITEMS_DIR + "sword_01.png",
		"icon_region": ICON_REGION_16,
		"consumable": false,
		"slot": SLOT_SWORD,
		"tier": TIER_BONE,
	},
	"gold_sword": {
		"name": "금검",
		"description": "물리 피해 +4",
		"icon_path": ITEMS_DIR + "sword_02.png",
		"icon_region": ICON_REGION_16,
		"consumable": false,
		"slot": SLOT_SWORD,
		"tier": TIER_GOLD,
	},
	"wooden_staff": {
		"name": "나무 지팡이",
		"description": "마법 피해 +1",
		"icon_path": ITEMS_DIR + "wand_01.png",
		"icon_region": ICON_REGION_16,
		"consumable": false,
		"slot": SLOT_STAFF,
		"tier": TIER_WOOD,
	},
	"bone_staff": {
		"name": "뼈 지팡이",
		"description": "마법 피해 +2",
		# 아이템 팩에 지팡이 아이콘이 둘뿐이라(wand_01/02) 중간 등급은 마법 매개체 느낌의
		# 두루마리로 대체했다 (ruins_key가 목걸이 아이콘을 빌려 쓴 것과 같은 처리)
		"icon_path": ITEMS_DIR + "scroll_leather.png",
		"icon_region": ICON_REGION_16,
		"consumable": false,
		"slot": SLOT_STAFF,
		"tier": TIER_BONE,
	},
	"gold_staff": {
		"name": "금 지팡이",
		"description": "마법 피해 +4",
		"icon_path": ITEMS_DIR + "wand_02.png",
		"icon_region": ICON_REGION_16,
		"consumable": false,
		"slot": SLOT_STAFF,
		"tier": TIER_GOLD,
	},
	"wooden_shield": {
		"name": "나무 방패",
		"description": "최대 체력 +5",
		"icon_path": ITEMS_DIR + "wooden_shield.png",
		"icon_region": ICON_REGION_16,
		"consumable": false,
		"slot": SLOT_SHIELD,
		"tier": TIER_WOOD,
	},
	"bone_shield": {
		"name": "뼈 방패",
		"description": "최대 체력 +10",
		"icon_path": ITEMS_DIR + "shield_02.png",
		"icon_region": ICON_REGION_16,
		"consumable": false,
		"slot": SLOT_SHIELD,
		"tier": TIER_BONE,
	},
	"gold_shield": {
		"name": "금 방패",
		"description": "최대 체력 +20",
		"icon_path": ITEMS_DIR + "shield_01.png",
		"icon_region": ICON_REGION_16,
		"consumable": false,
		"slot": SLOT_SHIELD,
		"tier": TIER_GOLD,
	},
}


# 이 아이템이 장비인지 (slot이 정의돼 있으면 장비)
static func is_equipment(item_id: String) -> bool:
	return get_slot(item_id) != ""


# 아이템이 들어가는 장비 슬롯을 반환 (장비가 아니거나 정의가 없으면 빈 문자열)
static func get_slot(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return ""
	return ITEMS[item_id].get("slot", "")


# item_id의 장비 등급을 반환. 장비가 아니거나 미장착("")이면 TIER_NONE —
# 덕분에 호출부가 "장착 안 했을 때"를 따로 분기하지 않고 그대로 TIER_STATS에 넘길 수 있다
static func get_tier(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return TIER_NONE
	return ITEMS[item_id].get("tier", TIER_NONE)


# 등급에 해당하는 스탯 묶음을 반환 (모르는 등급이면 전부 0인 TIER_NONE 스탯)
static func get_tier_stats(tier: String) -> Dictionary:
	return TIER_STATS.get(tier, TIER_STATS[TIER_NONE])


# item_id 하나로 곧장 스탯을 조회하는 단축 함수 (get_tier + get_tier_stats)
static func get_stats_for(item_id: String) -> Dictionary:
	return get_tier_stats(get_tier(item_id))


# ── 장비 드롭 추첨 ─────────────────────────────────────────────────────────
# 무작위 선택을 데이터 모듈에 두는 것은 BattleData.pick_variant()와 같은 방식이다.
# "꽝(장비 없음)" 판정은 호출부(상자/전투)가 각자의 확률로 먼저 하고, 여기서는
# "뽑기로 결정됐을 때 무엇이 나오는가"만 담당한다

# 등급의 서열(0=나무, 1=뼈, 2=금). 등급이 아니면 -1
static func get_tier_rank(tier: String) -> int:
	return TIER_ORDER.find(tier)


# 정확히 그 등급인 장비 id 목록 (검/지팡이/방패 3종)
static func get_equipment_ids(tier: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in ITEMS:
		var item: Dictionary = ITEMS[item_id]
		if item.has("slot") and item.get("tier", TIER_NONE) == tier:
			result.append(item_id)
	return result


# 해당 등급 이하의 모든 장비 id 목록 (지역 상한 안에서 후보를 모을 때 사용)
static func get_equipment_ids_up_to(max_tier: String) -> Array[String]:
	var max_rank := get_tier_rank(max_tier)
	var result: Array[String] = []
	if max_rank < 0:
		return result
	for tier in TIER_ORDER:
		if get_tier_rank(tier) <= max_rank:
			result.append_array(get_equipment_ids(tier))
	return result


# 정확히 그 등급의 장비 중 하나를 균등 확률로 뽑는다 (검/지팡이/방패가 같은 확률).
# 해당 등급 장비가 없으면 빈 문자열
static func pick_random_equipment(tier: String) -> String:
	var ids := get_equipment_ids(tier)
	if ids.is_empty():
		return ""
	return ids[randi() % ids.size()]


# max_tier 이하의 장비 중 하나를 뽑는다. 먼저 TIER_DROP_WEIGHT로 등급을 고르고,
# 그 등급 안에서 종류(검/지팡이/방패)를 균등하게 고른다. 상한이 잘못됐으면 빈 문자열
static func pick_random_equipment_up_to(max_tier: String) -> String:
	var max_rank := get_tier_rank(max_tier)
	if max_rank < 0:
		return ""

	var total_weight := 0
	for tier in TIER_ORDER:
		if get_tier_rank(tier) <= max_rank:
			total_weight += int(TIER_DROP_WEIGHT.get(tier, 0))
	if total_weight <= 0:
		return ""

	var roll := randi() % total_weight
	var accumulated := 0
	for tier in TIER_ORDER:
		if get_tier_rank(tier) > max_rank:
			continue
		accumulated += int(TIER_DROP_WEIGHT.get(tier, 0))
		if roll < accumulated:
			return pick_random_equipment(tier)
	return ""


# ITEMS에서 item_id의 icon_region으로 오려낸 AtlasTexture를 만들어 반환 (정의가 없으면 null)
static func build_icon(item_id: String) -> AtlasTexture:
	if not ITEMS.has(item_id):
		return null

	var item: Dictionary = ITEMS[item_id]
	var atlas := AtlasTexture.new()
	atlas.atlas = load(item["icon_path"]) as Texture2D
	atlas.region = item["icon_region"]
	return atlas
