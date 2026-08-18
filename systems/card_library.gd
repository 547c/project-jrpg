class_name CardLibrary
extends RefCounted

# 게임에 존재하는 "모든" 카드의 목록 (ItemData가 아이템 카탈로그인 것과 같은 역할).
# 새 카드를 추가할 땐 battle/cards/에 .tres를 만들고 여기 CARD_PATHS에 한 줄만 늘리면 된다.
#
# [카드 id] Card 리소스 자체에는 id 필드가 없다 — 화면에 보여줄 card_name만 있다. 그래서 세이브에
# 남길 안정적인 키가 필요한데, card_name을 키로 쓰면 나중에 카드 이름을 다듬는 순간 기존 세이브의
# 잠금해제 기록이 통째로 날아간다. 그래서 .tres 파일명을 그대로 id로 삼는다 (파일명은 화면에 안 나오니
# 이름을 바꿔도 안전하고, 이미 StarterDeck이 경로로 카드를 참조하고 있어 매핑도 자연스럽다).
#
# [소유/잠금해제와의 관계] 여기 있다고 해서 손패에 나오는 게 아니다. 실제로 덱에 들어가는 카드는
# GameState.unlocked_cards에 있는 것뿐이고(StarterDeck.build()가 걸러낸다), 이 목록은 "잠금해제
# 화면에 무엇을 보여줄 수 있는가"에 해당한다
const CARDS_DIR := "res://battle/cards/"

const CARD_PATHS: Dictionary = {
	# ── 기본 제공(티어1) — 게임 시작부터 잠금해제되어 있다 ──
	"wooden_sword_slash": CARDS_DIR + "wooden_sword_slash.tres",
	"magic_bolt": CARDS_DIR + "magic_bolt.tres",
	"guard": CARDS_DIR + "guard.tres",
	"dodge_roll": CARDS_DIR + "dodge_roll.tres",
	"heal_light": CARDS_DIR + "heal_light.tres",
	"mana_draught": CARDS_DIR + "mana_draught.tres",
	# ── 스킬포인트로 잠금해제하는 상위 카드(티어2/3) ──
	"flash_slash": CARDS_DIR + "flash_slash.tres",
	"fireball": CARDS_DIR + "fireball.tres",
	"super_regen": CARDS_DIR + "super_regen.tres",
	"triple_helix": CARDS_DIR + "triple_helix.tres",
	"explosion": CARDS_DIR + "explosion.tres",
	"counter_slash": CARDS_DIR + "counter_slash.tres",
	# ── 버프/디버프 카드 (상태이상 인프라의 첫 사례) ──
	"battle_spirit": CARDS_DIR + "battle_spirit.tres",
	"threaten": CARDS_DIR + "threaten.tres",
	# ── 스킬포인트로 잠금해제하는 티어1 카드 (기본 제공 6종과 달리 처음엔 잠겨 있다.
	# 티어1이라 UNLOCK_COST_BY_TIER상 비용은 1점으로 가장 싸다) ──
	"stab": CARDS_DIR + "stab.tres",
	"ice_arrow": CARDS_DIR + "ice_arrow.tres",
	# ── 스킬포인트로 잠금해제하는 티어2 카드 (비용 3점) ──
	"spin_slash": CARDS_DIR + "spin_slash.tres",
	"lightning_spear": CARDS_DIR + "lightning_spear.tres",
	"reflect_shield": CARDS_DIR + "reflect_shield.tres",
	# ── 스킬포인트로 잠금해제하는 티어3 카드 (비용 5점) ──
	"swift": CARDS_DIR + "swift.tres",
	"meteor_drop": CARDS_DIR + "meteor_drop.tres",
	"time_rift": CARDS_DIR + "time_rift.tres",
	"judgment": CARDS_DIR + "judgment.tres",
	"phoenix_blessing": CARDS_DIR + "phoenix_blessing.tres",
}

# 게임 시작 시(그리고 reset_progress 후) 이미 갖고 있는 카드. 기존 6종을 그대로 둬서
# 스킬포인트를 한 점도 안 써도 지금까지와 똑같이 전투가 굴러가게 한다
const DEFAULT_UNLOCKED: Array[String] = [
	"wooden_sword_slash",
	"magic_bolt",
	"guard",
	"dodge_roll",
	"heal_light",
	"mana_draught",
]

# 티어별 잠금해제 비용(스킬포인트). 레벨업 1회당 3점이 들어오므로 티어2는 레벨업 한 번,
# 티어3은 두 번 조금 안 되는 값을 모아야 풀 수 있는 정도의 무게다
const UNLOCK_COST_BY_TIER: Dictionary = {
	Card.CardTier.TIER_1: 1,
	Card.CardTier.TIER_2: 3,
	Card.CardTier.TIER_3: 5,
}

# 알 수 없는 카드 id의 비용 (잠금해제를 시도해도 실패하도록 하는 안전값)
const UNKNOWN_COST := -1

# ── 카드 아이콘 ────────────────────────────────────────────────────────────
# Free - Raven Fantasy Icons 시트(32x32 격자)에서 효과별로 잘라 쓴다. 원래 battle_scene.gd에
# 있던 표인데, 스펠북 컬렉션 목록도 전투 손패와 같은 아이콘을 보여줘야 해서 카탈로그로 옮겼다
# (battle_scene.gd는 CardLibrary.SKILL_ICON_REGION을 그대로 참조한다)
const RAVEN_SHEET_PATH := "res://assets/items/Free - Raven Fantasy Icons/Full Spritesheet/32x32.png"
const RAVEN_ICON_SIZE := 32
const SKILL_ICON_REGION: Dictionary = {
	Card.EffectType.DAMAGE: Rect2(160, 1472, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE), # fb742 — 핏방울 검 슬래시
	Card.EffectType.DEFEND: Rect2(128, 1184, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE), # fb597 — 민무늬 은색 방패
	Card.EffectType.DODGE: Rect2(128, 1440, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE),  # fb725 — 바람 소용돌이
	Card.EffectType.HEAL_HP: Rect2(64, 1312, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE), # fb659 — 빨간 하트
	Card.EffectType.RESTORE_MANA: Rect2(192, 1408, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE), # fb711 — 파란 마나 물방울
	# 아래 둘은 기존 아이콘을 그대로 빌려 쓴다 — 전용 아이콘 고르기는 카드 UI 단계에서 할 일이라
	# 여기서는 "아이콘이 비어 카드가 깨져 보이는 것"만 막는 게 목적이다.
	# 반격은 막는 동작이 먼저라 방패를, 초재생은 체력 회복이 주효과라 하트를 쓴다
	Card.EffectType.COUNTER: Rect2(128, 1184, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE),      # fb597 (방어와 공유)
	Card.EffectType.RESTORE_BOTH: Rect2(64, 1312, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE),  # fb659 (치유와 공유)
}


# card_id의 효과에 맞는 스킬 아이콘 텍스처. ItemData.build_icon()과 같은 방식(AtlasTexture로
# 시트 일부만 잘라 쓰기)이라 호출부는 그대로 TextureRect.texture에 넣으면 된다
static func build_icon(card_id: String) -> AtlasTexture:
	var card := get_card(card_id)
	if card == null or not SKILL_ICON_REGION.has(card.effect):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(RAVEN_SHEET_PATH) as Texture2D
	atlas.region = SKILL_ICON_REGION[card.effect]
	return atlas


# card_id에 해당하는 Card 리소스를 반환. 없는 id면 null.
# load()는 Godot이 경로 단위로 캐시하므로 같은 카드를 여러 번 물어도 파일을 다시 읽지 않는다.
# 다만 여기서 돌려주는 건 "원본" 인스턴스라 그대로 덱에 넣으면 안 된다 —
# 덱에 넣을 땐 StarterDeck.build()처럼 duplicate()해서 장마다 별개의 객체로 만들 것
static func get_card(card_id: String) -> Card:
	if not CARD_PATHS.has(card_id):
		return null
	return load(CARD_PATHS[card_id]) as Card


# card_id의 잠금해제 비용(스킬포인트). 모르는 카드거나 읽을 수 없으면 UNKNOWN_COST
static func get_unlock_cost(card_id: String) -> int:
	var card := get_card(card_id)
	if card == null:
		return UNKNOWN_COST
	return UNLOCK_COST_BY_TIER.get(card.tier, UNKNOWN_COST)


# 존재하는 모든 카드 id (잠금해제 화면이 목록을 그릴 때 쓸 용도)
static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_id in CARD_PATHS.keys():
		ids.append(String(card_id))
	return ids
