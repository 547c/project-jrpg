extends Node

# 플래그 값이 실제로 바뀔 때 방출되는 단일 시그널 (대화/NPC 등이 구독해 자동 반응)
signal flag_changed(flag_name: String, value)

# 퀘스트 상태(수락/진행/완료)가 바뀔 때 방출 (HUD/퀘스트로그가 구독해 갱신)
signal quest_changed(quest_id: String)

# 서브퀘스트 완료로 quest_level이 오를 때 방출 (LevelUpPopup이 구독해 "퀘스트 완료 + 레벨업"을
# 하나의 안내창으로 함께 보여줌). 현재 구조상 퀘스트 완료는 항상 레벨업을 동반하므로 별도 시그널로
# 나누지 않고 퀘스트 제목까지 한 번에 담아 방출한다
signal quest_completed_with_level_up(quest_title: String, hp_gain: int, mana_gain: int)

# 골드가 바뀔 때 방출 (HUD 카드가 구독해 실시간 갱신)
signal gold_changed(new_gold: int)

# 인벤토리 아이템이 추가/제거될 때 방출 (item_id 인자로 전달)
signal inventory_changed(item_id: String)

# NPC 호감도가 실제로 바뀔 때 방출 (npc_id, 새 값). 대화 톤/게이팅이 이 값을 참조한다
signal affinity_changed(npc_id: String, new_value: int)

# 골드(flags 딕셔너리와 별개의 독립 필드 — set_flag 경로를 타지 않음)
var gold: int = 0

# 아이템 인벤토리 (아이템 ID -> 보유 개수). 상점 구매/전투 드롭 등으로 채워짐
var inventory: Dictionary = {}

# NPC 호감도 (npc_id -> 0~100). 나중에 새 NPC가 추가돼도 키만 늘리면 되도록 확장 가능한 구조.
# get/change로만 접근하며, 정의되지 않은 npc_id는 AFFINITY_DEFAULT로 간주한다
const DEFAULT_AFFINITY: Dictionary = {
	"elara": 30,
	"rohan": 30,
	"yusuf": 30,
	"mia": 30,
	"kamil": 20, # 임무로 만난 거리감 있는 관계 — 다른 NPC보다 낮게 시작
	"nadim": 30, # 사막 정착지의 지도자/생존자 (2부 초반)
	"kasim": 30, # 정체를 숨긴 무기 상인 (술집 상주)
}
const AFFINITY_DEFAULT := 30
const AFFINITY_MIN := 0
const AFFINITY_MAX := 100
# 미아 전용: 그녀의 신뢰(earned_mia_trust)를 얻기 전까지는 호감도가 이 값을 넘지 못한다
const MIA_AFFINITY_LOCKED_CAP := 40

var affinity: Dictionary = DEFAULT_AFFINITY.duplicate()

# 이미 표시된 적 있는 대화 노드 id 모음 (DialogueBox가 "다시 듣기" 옵션을 회색+하단정렬로 구분하는 데 사용)
var seen_dialogue_nodes: Array = []

# --- 엔딩 도감(영구 기록) ---
# 지금까지 도달한 엔딩 id 모음. 슬롯 세이브와 성격이 다른 "계정 단위 영구 기록"이라
# SaveManager의 슬롯 파일이 아니라 전용 파일(ENDING_RECORDS_PATH)에 따로 저장하고,
# reset_progress()(새 게임/엔딩 후 리셋)에서도 절대 지우지 않는다
const ENDING_RECORDS_PATH := "user://ending_records.json"

signal endings_changed # 새 엔딩이 기록될 때 방출 (도감 UI가 열려 있다면 갱신용)

var seen_endings: Array = []

# 모든 플래그의 초기값 (reset_progress()가 이 값들로 되돌리는 기준이 되기도 함)
const DEFAULT_FLAGS: Dictionary = {
	"resolved_guardian_peacefully": false, # 결정적 플래그: 가디언을 평화적으로 정화했는가
	"earned_mia_trust": false,             # 결정적 플래그: 미아의 신뢰를 얻었는가
	"met_elara": false,                    # 엘라라(장로)를 만났는가
	"met_rohan": false,                    # 로한(사냥꾼)을 만났는가
	"met_yusuf": false,                    # 유수프(상인)를 만났는가
	"met_mia": false,                      # 미아(아이)를 만났는가
	"met_mia_decisive": false,             # 미아의 결정적 노드(mia_approach_press)를 통과했는가
	"met_kamil": false,                    # 카밀(감시자 동료)을 만났는가
	"met_nadim": false,                    # 나딤(사막 정착지 지도자)을 만났는가
	"met_kasim": false,                    # 카심(무기 상인)을 만났는가
	"part1_reported": false,               # 1부 결과를 엘라라에게 보고 완료했는가 (elara_ending_trigger 도달 시 true)
	"boat_available": false,               # 부두의 배를 이용할 수 있는가 (카밀의 출항 확인 후 true)
	"ruins_available": false,              # 사막 유적 입구를 이용할 수 있는가 (나딤이 위치를 알려준 뒤 true)
	"visited_village": false,              # 마을을 방문했는가
	"visited_forest": false,               # 숲을 방문했는가
	"visited_cave": false,                 # 동굴을 방문했는가
	"seen_opening": false,                 # 오프닝 인트로를 이미 봤는가 (재부팅 시 반복 방지)
	"guardian_event_done": false,          # 동굴 수호자 조우 이벤트를 이미 겪었는가
	"player_hp": 16,                       # 플레이어 현재 체력
	# 최대 체력은 두 값으로 나뉜다:
	# - player_base_max_hp: 레벨업으로만 오르는 "기본" 최대 체력 (_apply_level_up이 올림)
	# - player_max_hp: 실제로 쓰이는 최대 체력 = 기본 + 방패 보너스 (파생값이라 직접 쓰지 말 것)
	# 방패 보너스를 player_max_hp에 직접 더하면 장착/해제와 레벨업이 얽혀 값이 어긋나므로,
	# 항상 refresh_equipment_bonuses()가 기본값으로부터 다시 계산해 넣는다
	"player_base_max_hp": 16,              # 레벨업 누적분만 담은 기본 최대 체력
	"player_max_hp": 16,                   # 플레이어 최대 체력 (기본 + 방패 보너스, 자동 계산됨)
	"player_mana": 18,                     # 플레이어 현재 마나 (스킬 사용 자원)
	"player_max_mana": 18,                 # 플레이어 최대 마나 (현재는 회복 수단 없음 — 추후 상점 예정)
	"orcs_defeated": 0,                    # 숲 오크(Orc Crew) 처치 카운트
	"forest_quest_complete": false,        # 오크 3마리 처치 시 true
	"skeletons_defeated": 0,               # 동굴 스켈레톤(Skeleton Crew) 처치 카운트
	"cave_quest_complete": false,          # 스켈레톤 3마리 처치 시 true
	"mummies_defeated": 0,                 # 사막 미라 처치 카운트
	"desert_mummies_complete": false,      # 미라 3마리 처치 시 true (나딤 상태 대사 분기용)
	"ruins_key_complete": false,           # 유적 열쇠 획득 시 true (나딤 상태 대사 분기용)
	# 슬롯별로 현재 장착 중인 장비의 item_id ("" = 미장착). 인벤토리 보유 개수와는 별개로,
	# "무엇을 들고 있는가"만 기록한다 (장착해도 인벤토리에서 사라지지 않음)
	"equipped_sword": "",                  # 장착 중인 검
	"equipped_staff": "",                  # 장착 중인 지팡이
	"equipped_shield": "",                 # 장착 중인 방패
	"truth_discovered": false,             # 유적 내부 기록(벽화)에서 진실을 발견했는가 (ruins_lore_2 도달 시 true)
	"ruins_boss_defeated": false,          # 유적 보스(폭주한 근원체)를 처치했는가 (2부 결정적 선택의 조건)
	"truth_revealed": false,               # 2부 결정적 플래그: 진실을 세상에 알렸는가 (false면 비밀로 묻음)
	"part2_complete": false,               # 2부를 완료했는가 (카밀과의 결정적 선택을 마쳤을 때 true)
	"quest_level": 0,                      # 완료한 서브퀘스트 개수
}

# 씬 전환에도 유지되는 게임 상태. DEFAULT_FLAGS를 복사해 시작한다
var flags: Dictionary = DEFAULT_FLAGS.duplicate()

# 퀘스트의 초기 상태 (reset/새 게임의 기준). current/target은 int, active/complete는 bool
const DEFAULT_QUESTS: Dictionary = {
	"forest_orcs": {
		"title": "숲의 오크 소탕",
		"giver": "로한",
		"active": false,
		"current": 0,
		"target": 3,
		"complete": false,
	},
	"cave_skeletons": {
		"title": "동굴의 스켈레톤",
		"giver": "유서프",
		"active": false,
		"current": 0,
		"target": 3,
		"complete": false,
	},
	"desert_mummies": {
		"title": "사막의 미라 처치",
		"giver": "나딤",
		"active": false,
		"current": 0,
		"target": 3,
		"complete": false,
	},
	"ruins_key": {
		"title": "유적의 열쇠 찾기",
		"giver": "나딤",
		"active": false,
		"current": 0,
		"target": 1,
		"complete": false,
	},
}

# 퀘스트 완료 시 함께 세워줄 기존 호환 플래그 매핑 (guardian 게이팅 등 옛 코드가 계속 동작하도록)
const QUEST_COMPLETE_FLAGS: Dictionary = {
	"forest_orcs": "forest_quest_complete",
	"cave_skeletons": "cave_quest_complete",
	"desert_mummies": "desert_mummies_complete",
	"ruins_key": "ruins_key_complete",
}

# 현재 퀘스트 상태 (DEFAULT_QUESTS의 깊은 복사로 시작)
var quests: Dictionary = DEFAULT_QUESTS.duplicate(true)


# 플래그 값을 설정하고, 이전 값과 다를 때만 flag_changed 시그널을 방출
func set_flag(flag_name: String, value) -> void:
	var old_value = flags.get(flag_name, false)
	if old_value == value:
		return
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)


# 플래그 값을 반환. 정의되지 않은 플래그는 false로 간주
func get_flag(flag_name: String):
	return flags.get(flag_name, false)


# 해당 이름의 플래그가 정의되어 있는지 여부를 반환
func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name)


# 모든 플래그를 DEFAULT_FLAGS 값으로 되돌림. 엔딩 후 타이틀로 돌아가 새 게임을 시작할 때 사용.
# DEFAULT_FLAGS에 없는 임시/동적 키(예: 몬스터 조우별 "defeated_<id>")도 함께 지워서
# 새 게임에서는 이전 플레이의 처치 기록이 남아있지 않게 한다
func reset_progress() -> void:
	for flag_name in flags.keys().duplicate():
		if not DEFAULT_FLAGS.has(flag_name):
			flags.erase(flag_name)

	for flag_name in DEFAULT_FLAGS.keys():
		set_flag(flag_name, DEFAULT_FLAGS[flag_name])

	reset_quests()

	gold = 0
	gold_changed.emit(gold)

	inventory.clear()

	reset_affinity()
	seen_dialogue_nodes.clear()
	# seen_endings(엔딩 도감)는 의도적으로 건드리지 않는다 — 새 게임을 시작해도 유지되는 영구 기록


# 저장 데이터로부터 flags를 복원. 먼저 기본값으로 되돌려(임시 키 정리 포함) 저장 당시 없던 값이
# 남지 않게 한 뒤, 저장된 값을 덮어쓴다. JSON 파싱은 숫자를 float로 주므로 DEFAULT_FLAGS 타입에 맞춰 보정
func restore_flags(data: Dictionary) -> void:
	reset_progress()
	for key in data.keys():
		var value = data[key]
		if DEFAULT_FLAGS.has(key):
			var default_value = DEFAULT_FLAGS[key]
			if default_value is int:
				value = int(value)
			elif default_value is bool:
				value = bool(value)
		set_flag(String(key), value)

	# 구버전 세이브 호환: 장비 시스템 이전에 저장된 파일에는 player_base_max_hp가 없다.
	# 그때의 player_max_hp는 순수 레벨업 누적치(= 기본값)였으므로 그대로 기본값으로 삼는다
	if not data.has("player_base_max_hp"):
		set_flag("player_base_max_hp", get_flag("player_max_hp"))

	# 불러온 장비 상태에 맞춰 최대 체력을 다시 계산 (저장된 값과 어긋나 있어도 여기서 바로잡힌다)
	refresh_equipment_bonuses()


# player_hp를 amount만큼 깎되 0 밑으로 내려가지 않게 함
func damage_player(amount: int) -> void:
	set_flag("player_hp", max(0, get_flag("player_hp") - amount))


# 마나를 amount만큼 소모하되 0 밑으로 내려가지 않게 함. 마나는 (현재) 재충전 수단이 없는 순수 소모 자원
func spend_mana(amount: int) -> void:
	set_flag("player_mana", max(0, get_flag("player_mana") - amount))


# 현재 마나로 amount만큼의 비용을 감당할 수 있는지 (스킬 사용 가능 여부 판정)
func can_afford_mana(amount: int) -> bool:
	return get_flag("player_mana") >= amount


# player_hp를 player_max_hp까지 전부 회복 (전투 패배 후 복구용)
func heal_player_full() -> void:
	set_flag("player_hp", get_flag("player_max_hp"))


# player_hp와 player_mana를 각각 최대치의 절반만 회복 (전투 기절 페널티용 - 완전 회복보다 약함).
# 마나는 원래 회복 수단이 없는 소모 자원이지만, 기절 복구 시에도 0인 채로 두면 초반엔 골드도 없어
# 포션을 살 수도, 스킬을 쓸 수도 없는 상태로 굳어버릴 수 있어(사실상 진행 불가) 이 경로에서만 예외로 회복시킨다
func heal_player_half() -> void:
	set_flag("player_hp", get_flag("player_max_hp") / 2)
	set_flag("player_mana", get_flag("player_max_mana") / 2)


# player_hp를 player_max_hp의 fraction 비율만큼 추가 회복 (최대치를 넘지 않게 clamp). 전투 승리 보너스 등에 사용
func heal_player_partial(fraction: float) -> void:
	var max_hp: int = get_flag("player_max_hp")
	var new_hp: int = min(max_hp, get_flag("player_hp") + int(round(max_hp * fraction)))
	set_flag("player_hp", new_hp)


# player_mana를 player_max_mana의 fraction 비율만큼 회복 (최대치를 넘지 않게 clamp). 상점 포션 등에 사용
func restore_mana_partial(fraction: float) -> void:
	var max_mana: int = get_flag("player_max_mana")
	var new_mana: int = min(max_mana, get_flag("player_mana") + int(round(max_mana * fraction)))
	set_flag("player_mana", new_mana)


const GOLD_SOUND := "res://assets/sfx/400 Sounds pack/Items/coin_collect.wav"
const ITEM_SOUND := "res://assets/sfx/400 Sounds pack/Items/gem_collect.wav"


# 골드를 amount만큼 늘림 (몬스터 처치 드롭 등). add_gold/add_item은 프로젝트 전체에서 "획득"에만
# 쓰이는 단일 통로라(소모는 spend_gold/remove_item로 이름부터 분리돼 있음), 여기 한 곳에서만
# 효과음을 틀면 상자·전투 승리·상점 구매 등 모든 획득 경로에 자동으로 적용된다.
# 반대로 restore_gold/restore_inventory(세이브 로드)는 이 함수를 거치지 않으므로 로드 시엔 안 울린다
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	if amount > 0:
		SFXPlayer.play(GOLD_SOUND)


# 골드를 amount만큼 소모. 부족하면 아무것도 하지 않고 false 반환
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# 저장 데이터로부터 골드를 그대로 복원 (add/spend와 달리 절대값을 덮어씀)
func restore_gold(amount: int) -> void:
	gold = amount
	gold_changed.emit(gold)


# 인벤토리에 아이템을 amount만큼 추가 (없으면 새로 생성, 있으면 개수를 더함).
# add_gold와 같은 이유로 여기 한 곳에서만 효과음을 틀면 모든 획득 경로에 자동 적용된다
func add_item(item_id: String, amount: int = 1) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + amount
	inventory_changed.emit(item_id)
	if amount > 0:
		SFXPlayer.play(ITEM_SOUND)


# 인벤토리에서 아이템을 amount만큼 제거. 보유 개수가 부족하면 아무것도 하지 않고 false 반환.
# 제거 후 개수가 0 이하가 되면 키 자체를 지워 인벤토리를 깔끔하게 유지
func remove_item(item_id: String, amount: int = 1) -> bool:
	var current: int = inventory.get(item_id, 0)
	if current < amount:
		return false

	var remaining := current - amount
	if remaining <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = remaining

	inventory_changed.emit(item_id)
	return true


# 해당 아이템의 보유 개수 (없으면 0)
func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)


# 해당 아이템을 하나라도 보유 중인지 여부 (유적 열쇠 등 보유 판정용)
func has_item(item_id: String) -> bool:
	return get_item_count(item_id) > 0


# ── 장비 ────────────────────────────────────────────────────────────────────
# 장착은 "무엇을 들고 있는가"만 기록하고 인벤토리 개수는 건드리지 않는다 (소유와 장착은 별개).
# 슬롯별 장착 상태는 flags에 들어있어 세이브/로드가 자동으로 따라온다

# 슬롯 이름에 대응하는 flag 이름 ("sword" -> "equipped_sword"). 모르는 슬롯이면 빈 문자열
func _equipped_flag(slot: String) -> String:
	if not ItemData.EQUIPMENT_SLOTS.has(slot):
		return ""
	return "equipped_%s" % slot


# 해당 슬롯에 장착 중인 item_id ("" = 미장착)
func get_equipped(slot: String) -> String:
	var flag := _equipped_flag(slot)
	if flag == "":
		return ""
	return get_flag(flag)


# 장비를 장착한다. 같은 슬롯에 이미 다른 장비가 있으면 자동으로 교체된다.
# 장비가 아닌 아이템이면 아무 일도 하지 않고 false를 반환
func equip_item(item_id: String) -> bool:
	var slot := ItemData.get_slot(item_id)
	if slot == "":
		return false

	set_flag(_equipped_flag(slot), item_id)
	if slot == ItemData.SLOT_SHIELD:
		refresh_equipment_bonuses() # 방패는 최대 체력을 바꾸므로 즉시 재계산
	return true


# 해당 슬롯의 장비를 해제한다. 모르는 슬롯이면 false
func unequip_slot(slot: String) -> bool:
	var flag := _equipped_flag(slot)
	if flag == "":
		return false

	set_flag(flag, "")
	if slot == ItemData.SLOT_SHIELD:
		refresh_equipment_bonuses()
	return true


# 장착 중인 검의 물리 피해 보너스 (미장착이면 0)
func get_sword_damage_bonus() -> int:
	return ItemData.get_stats_for(get_equipped(ItemData.SLOT_SWORD))["sword_damage"]


# 장착 중인 지팡이의 마법 피해 보너스 (미장착이면 0)
func get_staff_damage_bonus() -> int:
	return ItemData.get_stats_for(get_equipped(ItemData.SLOT_STAFF))["staff_damage"]


# 장착 중인 방패의 최대 체력 보너스 (미장착이면 0)
func get_shield_max_hp_bonus() -> int:
	return ItemData.get_stats_for(get_equipped(ItemData.SLOT_SHIELD))["max_hp"]


# player_max_hp를 "기본 최대 체력 + 방패 보너스"로 다시 계산한다.
# 장비를 바꿀 때마다, 레벨업할 때마다, 세이브를 불러온 뒤, 전투를 시작할 때 호출된다 —
# 언제 불러도 같은 결과가 나오는 순수 재계산이라 값이 어긋날 여지가 없다.
# 방패를 벗어 최대치가 줄면 현재 체력도 함께 깎아 최대치를 넘지 않게 맞춘다
func refresh_equipment_bonuses() -> void:
	var new_max: int = get_flag("player_base_max_hp") + get_shield_max_hp_bonus()
	set_flag("player_max_hp", new_max)
	if get_flag("player_hp") > new_max:
		set_flag("player_hp", new_max)


# 저장 데이터로부터 인벤토리를 그대로 복원 (JSON 숫자는 float로 오므로 int로 보정). 복원된 각 항목에 대해
# inventory_changed를 방출해 구독 중인 UI가 있다면 갱신되게 함
func restore_inventory(data: Dictionary) -> void:
	inventory.clear()
	for item_id in data.keys():
		var amount := int(data[item_id])
		if amount > 0:
			inventory[String(item_id)] = amount

	for item_id in inventory.keys():
		inventory_changed.emit(item_id)


# ── 호감도(Affinity) ────────────────────────────────────────────────────────

# npc_id의 호감도를 amount만큼 증감하고 0~100으로 clamp. 미아는 신뢰를 얻기 전엔 40을 못 넘는다.
# 값이 실제로 바뀔 때만 affinity_changed를 방출 (정의되지 않았던 npc_id도 이 호출로 등록됨)
func change_affinity(npc_id: String, amount: int) -> void:
	var current: int = get_affinity(npc_id)
	var new_value: int = clampi(current + amount, AFFINITY_MIN, AFFINITY_MAX)
	if npc_id == "mia" and not get_flag("earned_mia_trust"):
		new_value = mini(new_value, MIA_AFFINITY_LOCKED_CAP)
	if new_value == current and affinity.has(npc_id):
		return
	affinity[npc_id] = new_value
	affinity_changed.emit(npc_id, new_value)


# npc_id의 현재 호감도 (정의되지 않았으면 기본값 30)
func get_affinity(npc_id: String) -> int:
	return affinity.get(npc_id, AFFINITY_DEFAULT)


# 호감도 구간 이름: cold(0-29) / neutral(30-59) / warm(60-79) / trusted(80-100).
# 대화 톤 분기나 고티어 백스토리 해금 조건 등에 사용
func get_affinity_tier(npc_id: String) -> String:
	var value := get_affinity(npc_id)
	if value <= 29:
		return "cold"
	if value <= 59:
		return "neutral"
	if value <= 79:
		return "warm"
	return "trusted"


# 모든 호감도를 기본값으로 되돌리고 각 npc에 대해 affinity_changed를 방출 (새 게임/리셋용)
func reset_affinity() -> void:
	affinity = DEFAULT_AFFINITY.duplicate()
	for npc_id in affinity.keys():
		affinity_changed.emit(npc_id, affinity[npc_id])


# 저장 데이터로부터 호감도를 복원 (기본값에서 시작해 저장된 값으로 덮어씀 — 저장 당시 없던 새 NPC 키도
# 기본 4개는 항상 존재하게 유지. JSON 숫자는 float로 오므로 int로 보정)
func restore_affinity(data: Dictionary) -> void:
	affinity = DEFAULT_AFFINITY.duplicate()
	for key in data.keys():
		affinity[String(key)] = int(data[key])
	for npc_id in affinity.keys():
		affinity_changed.emit(npc_id, affinity[npc_id])


# ── 방문한 대화 노드(seen) ──────────────────────────────────────────────────

# 대화 노드를 "본 적 있음"으로 기록 (중복 없이 추가). DialogueBox가 노드를 표시할 때마다 호출한다
func mark_node_seen(node_id: String) -> void:
	if node_id != "" and not seen_dialogue_nodes.has(node_id):
		seen_dialogue_nodes.append(node_id)


# 해당 노드를 이미 본 적 있는지
func has_seen_node(node_id: String) -> bool:
	return seen_dialogue_nodes.has(node_id)


# 저장 데이터(문자열 배열)로부터 방문 노드 목록을 복원
func restore_seen_dialogue_nodes(data: Array) -> void:
	seen_dialogue_nodes.clear()
	for node_id in data:
		seen_dialogue_nodes.append(String(node_id))


# ── 엔딩 도감(영구 기록) ────────────────────────────────────────────────────
# 슬롯 세이브(SaveManager)와 완전히 독립적으로 동작한다: 전용 파일에 즉시 쓰고,
# 게임 시작 시 한 번 읽어오며, reset_progress()의 영향도 받지 않는다

# autoload로 올라올 때 저장돼 있던 엔딩 기록을 불러온다
func _ready() -> void:
	_load_ending_records()


# 엔딩에 도달했음을 영구 기록에 남기고 곧바로 파일에 저장 (이미 기록된 엔딩이면 아무 일도 안 함).
# 엔딩 화면(endings/ending_screen.gd)이 표시될 때 자동으로 호출된다
func mark_ending_seen(ending_id: String) -> void:
	if ending_id == "" or seen_endings.has(ending_id):
		return
	seen_endings.append(ending_id)
	_save_ending_records()
	endings_changed.emit()


# 해당 엔딩을 이미 본 적 있는지 (도감이 잠금/해금 표시를 정하는 데 사용)
func has_seen_ending(ending_id: String) -> bool:
	return seen_endings.has(ending_id)


# 기록된 엔딩 개수 (도감 진행도 표시용)
func seen_ending_count() -> int:
	return seen_endings.size()


# 엔딩 기록 전용 파일에 현재 목록을 저장
func _save_ending_records() -> void:
	var file := FileAccess.open(ENDING_RECORDS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"seen_endings": seen_endings}, "\t"))
	file.close()


# 엔딩 기록 전용 파일을 읽어 목록을 복원 (파일이 없거나 손상됐으면 빈 목록 유지)
func _load_ending_records() -> void:
	seen_endings.clear()
	if not FileAccess.file_exists(ENDING_RECORDS_PATH):
		return
	var file := FileAccess.open(ENDING_RECORDS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	for ending_id in parsed.get("seen_endings", []):
		var id := String(ending_id)
		if not seen_endings.has(id):
			seen_endings.append(id)


# 오크 처치: 숲 오크 퀘스트의 진행도를 올림 (수락 전이면 아무 일도 안 일어남)
func increment_orcs_defeated() -> void:
	increment_quest_progress("forest_orcs")


# 스켈레톤 처치: 동굴 스켈레톤 퀘스트의 진행도를 올림 (수락 전이면 아무 일도 안 일어남)
func increment_skeletons_defeated() -> void:
	increment_quest_progress("cave_skeletons")


# 미라 처치: 사막 미라 퀘스트의 진행도를 올림 (수락 전이면 아무 일도 안 일어남).
# 오크/스켈레톤과 동일하게 실제 카운트는 퀘스트의 current가 담당한다
func increment_mummies_defeated() -> void:
	increment_quest_progress("desert_mummies")


# 퀘스트를 수락(active=true)하고 quest_changed를 방출. 이미 활성/없는 퀘스트면 무시
func start_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var quest: Dictionary = quests[quest_id]
	if quest["active"]:
		return
	quest["active"] = true
	quest_changed.emit(quest_id)


# 활성이고 미완료인 퀘스트만 진행도 +1. target 도달 시 complete 처리 +
# 호환 플래그(forest/cave_quest_complete)와 quest_level도 갱신
func increment_quest_progress(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var quest: Dictionary = quests[quest_id]
	if not quest["active"] or quest["complete"]:
		return

	quest["current"] = min(quest["current"] + 1, quest["target"])
	if quest["current"] >= quest["target"]:
		quest["complete"] = true
		if QUEST_COMPLETE_FLAGS.has(quest_id):
			set_flag(QUEST_COMPLETE_FLAGS[quest_id], true)
		set_flag("quest_level", get_flag("quest_level") + 1)
		_apply_level_up(quest["title"])
		_apply_quest_completion_affinity(quest_id) # 퀘스트를 준 NPC와의 호감도 보너스

	quest_changed.emit(quest_id)


# 진행도와 무관하게 퀘스트를 즉시 완료 처리한다 (보물상자로 얻는 '열쇠 찾기'처럼 카운트가 아니라
# 단일 이벤트로 끝나는 퀘스트용). 수락 여부와 상관없이 active로 만든 뒤 target까지 채워, 완료 시의
# 부수효과(호환 플래그·레벨업·호감도)를 increment 경로와 동일하게 적용한다. 이미 완료면 아무 일도 안 함
func complete_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var quest: Dictionary = quests[quest_id]
	if quest["complete"]:
		return
	quest["active"] = true
	quest["current"] = quest["target"]
	quest["complete"] = true
	if QUEST_COMPLETE_FLAGS.has(quest_id):
		set_flag(QUEST_COMPLETE_FLAGS[quest_id], true)
	set_flag("quest_level", get_flag("quest_level") + 1)
	_apply_level_up(quest["title"])
	_apply_quest_completion_affinity(quest_id)
	quest_changed.emit(quest_id)


# 해당 퀘스트가 완료 상태인지 여부
func is_quest_complete(quest_id: String) -> bool:
	return quests.has(quest_id) and quests[quest_id]["complete"]


# 퀘스트 완료 시 그 퀘스트를 의뢰한 NPC의 호감도를 올린다 (숲 오크→로한, 동굴 스켈레톤→유서프, 사막 미라/유적 열쇠→나딤)
const QUEST_COMPLETION_AFFINITY: Dictionary = {
	"forest_orcs": {"npc_id": "rohan", "amount": 5},
	"cave_skeletons": {"npc_id": "yusuf", "amount": 5},
	"desert_mummies": {"npc_id": "nadim", "amount": 5},
	"ruins_key": {"npc_id": "nadim", "amount": 5},
}


func _apply_quest_completion_affinity(quest_id: String) -> void:
	if QUEST_COMPLETION_AFFINITY.has(quest_id):
		var bonus: Dictionary = QUEST_COMPLETION_AFFINITY[quest_id]
		change_affinity(bonus["npc_id"], bonus["amount"])


# 레벨업(quest_level 상승) 시 늘어나는 최대 체력/마나 폭
const LEVEL_UP_HP_GAIN := 8
const LEVEL_UP_MANA_GAIN := 10


# quest_level이 오를 때마다 호출됨. 최대 체력/마나를 늘리고 같은 폭만큼 현재치도 회복시킨 뒤(최대치 초과 방지)
# quest_completed_with_level_up을 방출해 LevelUpPopup이 "퀘스트 완료 + 레벨업"을 한 번에 안내하게 함
func _apply_level_up(quest_title: String) -> void:
	# 레벨업은 "기본" 최대 체력만 올리고, 실제 player_max_hp는 방패 보너스를 얹어 다시 계산한다.
	# (player_max_hp를 직접 올리면 방패를 낀 채 레벨업할 때 보너스가 기본값에 눌러붙어 중복 적용된다)
	set_flag("player_base_max_hp", get_flag("player_base_max_hp") + LEVEL_UP_HP_GAIN)
	refresh_equipment_bonuses()
	set_flag("player_hp", min(get_flag("player_max_hp"), get_flag("player_hp") + LEVEL_UP_HP_GAIN))
	set_flag("player_max_mana", get_flag("player_max_mana") + LEVEL_UP_MANA_GAIN)
	set_flag("player_mana", min(get_flag("player_max_mana"), get_flag("player_mana") + LEVEL_UP_MANA_GAIN))
	quest_completed_with_level_up.emit(quest_title, LEVEL_UP_HP_GAIN, LEVEL_UP_MANA_GAIN)


# 해당 퀘스트가 수락되어 활성 상태인지 여부
func is_quest_active(quest_id: String) -> bool:
	return quests.has(quest_id) and quests[quest_id]["active"]


# 모든 퀘스트를 기본값으로 되돌리고 각 quest_changed를 방출 (새 게임/리셋용)
func reset_quests() -> void:
	quests = DEFAULT_QUESTS.duplicate(true)
	for quest_id in quests.keys():
		quest_changed.emit(quest_id)


# 저장 데이터로부터 퀘스트의 동적 필드(active/current/complete)만 복원. 정적 필드(제목/부여자/target)는
# DEFAULT_QUESTS 값을 유지. JSON 숫자는 float로 오므로 int/bool로 보정
func restore_quests(data: Dictionary) -> void:
	reset_quests()
	for quest_id in quests.keys():
		if data.has(quest_id):
			var saved: Dictionary = data[quest_id]
			var quest: Dictionary = quests[quest_id]
			quest["active"] = bool(saved.get("active", false))
			quest["current"] = int(saved.get("current", 0))
			quest["complete"] = bool(saved.get("complete", false))
		quest_changed.emit(quest_id)


# Stage 4→5 전환에 쓰는 quest_level 임계값 (현재 퀘스트 2개 기준, guardian 게이트와 동일)
const OBJECTIVE_QUEST_LEVEL_TARGET := 2

# 별도 flag로 저장하지 않고, 기존 진행 flag들로 현재 메인 목표 단계(1~8)를 매번 계산해서 반환.
# objective 상태가 실제 진행 상황과 항상 일치하게 유지된다.
# 6~8은 2부 진행: 엘라라 보고(6) → 유서프에게 더 알아보기(7) → 부두에서 출항(8)
func get_current_objective_stage() -> int:
	if not get_flag("met_elara"):
		return 1

	if _met_villager_count() < 2:
		return 2

	# 여기부터는 met_rohan == true && met_yusuf == true
	if not get_flag("met_mia_decisive"):
		return 3

	if get_flag("quest_level") < OBJECTIVE_QUEST_LEVEL_TARGET:
		return 4

	if not get_flag("guardian_event_done"):
		return 5

	if not get_flag("part1_reported"):
		return 6

	if not get_flag("boat_available"):
		return 7

	return 8


# 현재 단계에 대응하는 안내 문구를 반환 (진행도 N은 실시간 계산해서 보간)
func get_objective_text() -> String:
	match get_current_objective_stage():
		1:
			return "엘라라를 찾아가 대화해보세요"
		2:
			return "마을 사람들과 대화하며 정보를 모으세요 (%d/2)" % _met_villager_count()
		3:
			return "술집에서 미아를 만나 결정적 정보를 얻으세요"
		4:
			return "숲과 동굴의 몬스터를 처치해 힘을 기르세요 (레벨 %d/%d)" % [get_flag("quest_level"), OBJECTIVE_QUEST_LEVEL_TARGET]
		5:
			return "동굴 깊은 곳의 수호자를 찾아가세요"
		6:
			return "우물의 결과를 엘라라에게 알리세요"
		7:
			return "유서프에게 가서 더 알아보세요"
		_:
			return "부두에서 배를 타고 떠나세요"


# met_rohan + met_yusuf 중 true인 개수 (0~2)
func _met_villager_count() -> int:
	var count := 0
	if get_flag("met_rohan"):
		count += 1
	if get_flag("met_yusuf"):
		count += 1
	return count


# 2부 결정적 선택(truth_revealed)에 따라 최종 엔딩 종류를 반환 ("reveal" / "secret").
# 카밀과의 결정적 대화가 끝났을 때 npc/kamil_npc.gd가 이 값으로 엔딩 씬을 고른다
# (1부의 check_ending()과 같은 역할·같은 형태)
func check_final_ending() -> String:
	return "reveal" if get_flag("truth_revealed") else "secret"


# 두 결정적 플래그의 조합으로 엔딩 종류를 판단해 반환 ("good" / "neutral" / "bad")
func check_ending() -> String:
	var count := 0
	if get_flag("resolved_guardian_peacefully"):
		count += 1
	if get_flag("earned_mia_trust"):
		count += 1

	match count:
		2:
			return "good"
		1:
			return "neutral"
		_:
			return "bad"
