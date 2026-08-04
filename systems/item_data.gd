class_name ItemData
extends RefCounted

# 아이템 정의. 새 아이템을 추가할 땐 여기에 항목만 늘리면 됨.
# icon_path/icon_region: GUI 팩(medieval.png)에서 아이콘으로 쓸 영역을 오려낼 좌표
const ITEMS: Dictionary = {
	"mana_potion": {
		"name": "마나포션",
		"description": "마나 50% 회복",
		"icon_path": "res://assets/GUI/MedievalUiMega/medieval.png",
		"icon_region": Rect2(389, 807, 22, 37),
		"mana_restore_fraction": 0.5,
	},
	"hp_potion": {
		"name": "체력포션",
		"description": "체력 50% 회복",
		"icon_path": "res://assets/GUI/MedievalUiMega/medieval.png",
		"icon_region": Rect2(325, 807, 22, 37),
		"hp_restore_fraction": 0.5,
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
