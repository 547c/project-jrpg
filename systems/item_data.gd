class_name ItemData
extends RefCounted

# 아이템 정의. 새 아이템을 추가할 땐 여기에 항목만 늘리면 됨.
# icon_path/icon_region: GUI 팩(medieval.png)에서 아이콘으로 쓸 영역을 오려낼 좌표
# 아이콘은 items 팩의 개별 16x16 PNG를 그대로 씀(region은 전체 프레임 Rect2(0,0,16,16)).
# consumable: false면 인벤토리에서 클릭해도 소비/효과가 없음(열쇠처럼 유지형 아이템용, 기본값 true)
const ICON_REGION_16 := Rect2(0, 0, 16, 16)
const ITEMS_DIR := "res://assets/items/Free RPG asset Pack/separate files/"

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
}


# ITEMS에서 item_id의 icon_region으로 오려낸 AtlasTexture를 만들어 반환 (정의가 없으면 null)
static func build_icon(item_id: String) -> AtlasTexture:
	if not ITEMS.has(item_id):
		return null

	var item: Dictionary = ITEMS[item_id]
	var atlas := AtlasTexture.new()
	atlas.atlas = load(item["icon_path"]) as Texture2D
	atlas.region = item["icon_region"]
	return atlas
