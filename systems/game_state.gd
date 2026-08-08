extends Node

# 플래그 값이 실제로 바뀔 때 방출되는 단일 시그널 (대화/NPC 등이 구독해 자동 반응)
signal flag_changed(flag_name: String, value)

# 퀘스트 상태(수락/진행/완료)가 바뀔 때 방출 (HUD/퀘스트로그가 구독해 갱신)
signal quest_changed(quest_id: String)

# 서브퀘스트 완료로 quest_level이 오를 때 방출 (LevelUpPopup이 구독해 안내창을 띄움)
signal leveled_up(hp_gain: int, mana_gain: int)

# 골드가 바뀔 때 방출 (HUD 카드가 구독해 실시간 갱신)
signal gold_changed(new_gold: int)

# 인벤토리 아이템이 추가/제거될 때 방출 (item_id 인자로 전달)
signal inventory_changed(item_id: String)

# 골드(flags 딕셔너리와 별개의 독립 필드 — set_flag 경로를 타지 않음)
var gold: int = 0

# 아이템 인벤토리 (아이템 ID -> 보유 개수). 상점 구매/전투 드롭 등으로 채워짐
var inventory: Dictionary = {}

# 모든 플래그의 초기값 (reset_progress()가 이 값들로 되돌리는 기준이 되기도 함)
const DEFAULT_FLAGS: Dictionary = {
	"resolved_guardian_peacefully": false, # 결정적 플래그: 가디언을 평화적으로 정화했는가
	"earned_mia_trust": false,             # 결정적 플래그: 미아의 신뢰를 얻었는가
	"met_elara": false,                    # 엘라라(장로)를 만났는가
	"met_rohan": false,                    # 로한(사냥꾼)을 만났는가
	"met_yusuf": false,                    # 유수프(상인)를 만났는가
	"met_mia": false,                      # 미아(아이)를 만났는가
	"met_mia_decisive": false,             # 미아의 결정적 노드(mia_approach_press)를 통과했는가
	"visited_village": false,              # 마을을 방문했는가
	"visited_forest": false,               # 숲을 방문했는가
	"visited_cave": false,                 # 동굴을 방문했는가
	"seen_opening": false,                 # 오프닝 인트로를 이미 봤는가 (재부팅 시 반복 방지)
	"guardian_event_done": false,          # 동굴 수호자 조우 이벤트를 이미 겪었는가
	"player_hp": 16,                       # 플레이어 현재 체력
	"player_max_hp": 16,                   # 플레이어 최대 체력
	"player_mana": 18,                     # 플레이어 현재 마나 (스킬 사용 자원)
	"player_max_mana": 18,                 # 플레이어 최대 마나 (현재는 회복 수단 없음 — 추후 상점 예정)
	"orcs_defeated": 0,                    # 숲 오크(Orc Crew) 처치 카운트
	"forest_quest_complete": false,        # 오크 3마리 처치 시 true
	"skeletons_defeated": 0,               # 동굴 스켈레톤(Skeleton Crew) 처치 카운트
	"cave_quest_complete": false,          # 스켈레톤 3마리 처치 시 true
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
}

# 퀘스트 완료 시 함께 세워줄 기존 호환 플래그 매핑 (guardian 게이팅 등 옛 코드가 계속 동작하도록)
const QUEST_COMPLETE_FLAGS: Dictionary = {
	"forest_orcs": "forest_quest_complete",
	"cave_skeletons": "cave_quest_complete",
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


# 골드를 amount만큼 늘림 (몬스터 처치 드롭 등)
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


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


# 인벤토리에 아이템을 amount만큼 추가 (없으면 새로 생성, 있으면 개수를 더함)
func add_item(item_id: String, amount: int = 1) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + amount
	inventory_changed.emit(item_id)


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


# 오크 처치: 숲 오크 퀘스트의 진행도를 올림 (수락 전이면 아무 일도 안 일어남)
func increment_orcs_defeated() -> void:
	increment_quest_progress("forest_orcs")


# 스켈레톤 처치: 동굴 스켈레톤 퀘스트의 진행도를 올림 (수락 전이면 아무 일도 안 일어남)
func increment_skeletons_defeated() -> void:
	increment_quest_progress("cave_skeletons")


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
		_apply_level_up()

	quest_changed.emit(quest_id)


# 레벨업(quest_level 상승) 시 늘어나는 최대 체력/마나 폭
const LEVEL_UP_HP_GAIN := 8
const LEVEL_UP_MANA_GAIN := 10


# quest_level이 오를 때마다 호출됨. 최대 체력/마나를 늘리고 같은 폭만큼 현재치도 회복시킨 뒤(최대치 초과 방지)
# leveled_up을 방출해 LevelUpPopup 등이 사용자에게 알리게 함
func _apply_level_up() -> void:
	set_flag("player_max_hp", get_flag("player_max_hp") + LEVEL_UP_HP_GAIN)
	set_flag("player_hp", min(get_flag("player_max_hp"), get_flag("player_hp") + LEVEL_UP_HP_GAIN))
	set_flag("player_max_mana", get_flag("player_max_mana") + LEVEL_UP_MANA_GAIN)
	set_flag("player_mana", min(get_flag("player_max_mana"), get_flag("player_mana") + LEVEL_UP_MANA_GAIN))
	leveled_up.emit(LEVEL_UP_HP_GAIN, LEVEL_UP_MANA_GAIN)


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

# 별도 flag로 저장하지 않고, 기존 진행 flag들로 현재 메인 목표 단계(1~6)를 매번 계산해서 반환.
# objective 상태가 실제 진행 상황과 항상 일치하게 유지된다
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

	return 6


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
		_:
			return "우물의 결과를 엘라라에게 알리세요"


# met_rohan + met_yusuf 중 true인 개수 (0~2)
func _met_villager_count() -> int:
	var count := 0
	if get_flag("met_rohan"):
		count += 1
	if get_flag("met_yusuf"):
		count += 1
	return count


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
