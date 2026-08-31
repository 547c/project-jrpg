extends Node

# 플래그 값이 실제로 바뀔 때 방출되는 단일 시그널 (대화/NPC 등이 구독해 자동 반응)
signal flag_changed(flag_name: String, value)

# 퀘스트 상태(수락/진행/완료)가 바뀔 때 방출 (HUD/퀘스트로그가 구독해 갱신)
signal quest_changed(quest_id: String)

# 서브퀘스트를 완료했을 때 방출 (LevelUpPopup이 구독해 안내창을 띄움).
# 경험치 도입 전에는 "퀘스트 완료 = 레벨업"이라 하나의 시그널이었지만, 이제 레벨업은 경험치 누적으로
# 따로 일어나므로 둘을 분리했다 — 퀘스트를 깨도 레벨이 안 오를 수 있고, 몬스터만 잡아도 레벨이 오른다
signal quest_completed_notice(quest_title: String, xp_gained: int)

# 의뢰(서브 퀘스트) 상태가 바뀔 때 (수락/진행/완료/의뢰판 갱신). 퀘스트로그·의뢰판이 구독해 다시 그린다
signal sub_quest_changed

# 의뢰를 완료해 보상을 지급한 직후. 안내창이 메인 퀘스트 완료와 같은 방식으로 큐에 담아 띄운다
signal sub_quest_completed(title: String, reward_text: String)

# 경험치가 쌓여 레벨이 올랐을 때 방출 (한 번에 여러 레벨이 오르면 레벨마다 한 번씩).
# gain 값들은 그 레벨업으로 실제로 늘어난 양이라 안내창이 그대로 보여주면 된다
signal player_leveled_up(new_level: int, hp_gain: int, mana_gain: int, skill_point_gain: int)

# 경험치가 변할 때 방출 (HUD의 XP 진행바가 구독해 갱신). 레벨업으로 xp가 깎이는 경우에도 방출된다
signal xp_changed(current_xp: int, xp_to_next: int)

# 골드가 바뀔 때 방출 (HUD 카드가 구독해 실시간 갱신)
signal gold_changed(new_gold: int)

# 인벤토리 아이템이 추가/제거될 때 방출 (item_id 인자로 전달)
signal inventory_changed(item_id: String)

# 카드가 새로 잠금해제될 때 방출 (덱빌더/잠금해제 UI가 구독해 갱신).
# 스킬포인트 잔량은 flags의 "skill_points"라 flag_changed로 이미 알 수 있으므로 따로 시그널을 두지 않는다
signal card_unlocked(card_id: String)

# 전투 덱 구성이 바뀔 때 방출 (덱 구성 UI가 구독해 갱신)
signal battle_deck_changed

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

# 잠금해제된 카드 id 모음 (CardLibrary.CARD_PATHS의 키). 여기 있는 카드만 실제로 덱에 들어간다
# (StarterDeck.build()가 이 목록으로 걸러낸다). 개수가 아니라 "가졌다/아니다"뿐이라
# 인벤토리(개수 딕셔너리)보다 seen_dialogue_nodes(id 배열) 쪽 패턴이 맞아 그쪽을 따랐다
var unlocked_cards: Array = CardLibrary.DEFAULT_UNLOCKED.duplicate()

# 플레이어가 직접 짠 전투 덱 (카드 id 목록, 같은 카드를 여러 장 넣을 수 있어 중복 허용).
# 비어 있으면 "아직 한 번도 덱을 건드리지 않았다"는 뜻이고, 그때는 StarterDeck.build()가
# 기존처럼 보유 카드 전부로 덱을 자동 구성한다 (덱 구성 기능 이전 세이브와의 하위 호환)
const MAX_BATTLE_DECK_SIZE := 15
# 같은 카드를 몇 장까지 넣을 수 있는지 (전체 15장 한도와는 별개의 개별 상한).
# 강한 카드 한 종류로 덱을 도배하는 걸 막아 손패 다양성을 유지하려는 것
const MAX_COPIES_PER_CARD := 2
var battle_deck: Array = []

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
	"boat_used": false,                    # 배를 타고 사막으로 떠난 적이 있는가 (2부 타이틀 카드를 처음 한 번만 보여주는 기준)
	"ruins_available": false,              # 사막 유적 입구를 이용할 수 있는가 (나딤이 위치를 알려준 뒤 true)
	"visited_village": false,              # 마을을 방문했는가
	"visited_forest": false,               # 숲을 방문했는가
	"visited_cave": false,                 # 동굴을 방문했는가
	"seen_opening": false,                 # 오프닝 인트로를 이미 봤는가 (재부팅 시 반복 방지)
	"guardian_event_done": false,          # 동굴 수호자 조우 이벤트를 이미 겪었는가
	"guardian_dying_hint_heard": false,    # 대화 경로 결말에서 "감시자들은 지하에" 단서를 들었는가
	"heard_ancient_abundance_hint": false, # 엘라라/로한 중 누구에게서든 낙원 시대 떡밥을 들었는가
	"yusuf_full_confession": false,        # 씬9에서 유서프가 감시자 조직 경험을 전부 고백했는가 (카밀 등장 조건)
	"elara_grind_advice_given": false,      # 미아 결정적 선택 이후 엘라라의 체크인 대사(사냥 조언)를 들었는가
	"arrived_desert": false,               # 사막(desert.tscn)에 처음 도착했는가 (objective 단계 9→10 전환)
	"filter_room_done": false,             # 씬12 필터룸을 완료했는가 (truth_revealed와 별개 — 씬13 선택으로 덮이지 않음)
	"player_hp": 25,                       # 플레이어 현재 체력
	# 최대 체력은 두 값으로 나뉜다:
	# - player_base_max_hp: 레벨업으로만 오르는 "기본" 최대 체력 (_apply_level_up이 올림)
	# - player_max_hp: 실제로 쓰이는 최대 체력 = 기본 + 방패 보너스 (파생값이라 직접 쓰지 말 것)
	# 방패 보너스를 player_max_hp에 직접 더하면 장착/해제와 레벨업이 얽혀 값이 어긋나므로,
	# 항상 refresh_equipment_bonuses()가 기본값으로부터 다시 계산해 넣는다
	"player_base_max_hp": 25,              # 레벨업 누적분만 담은 기본 최대 체력
	"player_max_hp": 25,                   # 플레이어 최대 체력 (기본 + 방패 보너스, 자동 계산됨)
	"player_mana": 20,                     # 플레이어 현재 마나 (스킬 사용 자원)
	"player_max_mana": 20,                 # 플레이어 최대 마나 (현재는 회복 수단 없음 — 추후 상점 예정)
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
	# 완료한 서브퀘스트 개수. 스토리 진행 게이트(수호자 조우, 목표 단계 등)의 기준이며
	# 캐릭터의 강함과는 무관하다 — 강함은 아래 player_level이 담당한다
	"progress": 0,
	# 경험치로 오르는 캐릭터 레벨. 1에서 시작하고 상한이 없다.
	# player_xp는 "총 누적치"가 아니라 "현재 레벨 안에서 쌓인 양"이라, 레벨업할 때마다 필요치만큼
	# 빼고 남은 만큼이 다음 레벨로 이월된다 — 이렇게 두면 HUD의 진행바가 xp/필요치 그대로가 되고,
	# 한 번에 여러 레벨이 오르는 경우(보스 처치 등)도 같은 계산으로 자연스럽게 처리된다
	"player_level": 1,
	"player_xp": 0,
	# 카드 잠금해제에 쓰는 자원. 레벨업(_apply_level_up)마다 SKILL_POINTS_PER_LEVEL만큼 들어온다.
	# 어떤 카드를 풀었는지는 개수가 아니라 목록이라 flags에 담기 어색해서 unlocked_cards로 따로 뺐다
	"skill_points": 0,
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

# 지금은 쓰지 않지만 옛 세이브 파일에는 들어 있는 키들. restore_flags가 이 키들은 flags에 그대로
# 넣지 않고, 아래 마이그레이션 코드가 새 필드로 변환해 준다
const LEGACY_FLAG_KEYS: Array[String] = ["quest_level"]

# 퀘스트 완료 시 함께 세워줄 기존 호환 플래그 매핑 (guardian 게이팅 등 옛 코드가 계속 동작하도록)
const QUEST_COMPLETE_FLAGS: Dictionary = {
	"forest_orcs": "forest_quest_complete",
	"cave_skeletons": "cave_quest_complete",
	"desert_mummies": "desert_mummies_complete",
	"ruins_key": "ruins_key_complete",
}

# 현재 퀘스트 상태 (DEFAULT_QUESTS의 깊은 복사로 시작)
var quests: Dictionary = DEFAULT_QUESTS.duplicate(true)

# 의뢰판에 걸려 있는 의뢰 3개 (수락 전 목록). 세이브에 담아 다시 열었을 때 같은 목록이 보이게 한다
var bounty_board: Array = []

# 지금 진행 중인 의뢰 하나 (비어 있으면 없음). 동시에 하나만 받을 수 있다는 규칙이 이 자료구조 자체다
var active_sub_quest: Dictionary = {}


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
	reset_sub_quests()

	gold = 0
	gold_changed.emit(gold)

	inventory.clear()

	reset_affinity()
	seen_dialogue_nodes.clear()
	# 잠금해제 목록은 비우는 게 아니라 기본 제공 6종으로 되돌린다 (새 게임도 기본 카드는 갖고 시작).
	# skill_points는 DEFAULT_FLAGS에 있어 위 플래그 루프에서 이미 0으로 돌아갔다
	unlocked_cards = CardLibrary.DEFAULT_UNLOCKED.duplicate()
	# 덱은 비워서 "아직 안 건드림" 상태로 되돌린다 (StarterDeck이 다시 자동 구성하게 됨)
	battle_deck.clear()
	battle_deck_changed.emit()
	# seen_endings(엔딩 도감)는 의도적으로 건드리지 않는다 — 새 게임을 시작해도 유지되는 영구 기록


# 저장 데이터로부터 flags를 복원. 먼저 기본값으로 되돌려(임시 키 정리 포함) 저장 당시 없던 값이
# 남지 않게 한 뒤, 저장된 값을 덮어쓴다. JSON 파싱은 숫자를 float로 주므로 DEFAULT_FLAGS 타입에 맞춰 보정
func restore_flags(data: Dictionary) -> void:
	reset_progress()
	for key in data.keys():
		# 아래 마이그레이션이 따로 처리하는 옛 키는 그대로 넣지 않는다. 넣으면 두 가지가 곤란해진다:
		# 지금은 없는 키라 set_flag가 기본값 false와 숫자를 비교하다 타입 오류를 내고,
		# 통과하더라도 쓰이지 않는 옛 키가 flags에 남아 다음 저장에까지 계속 따라다닌다
		if key in LEGACY_FLAG_KEYS:
			continue
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

	# 구버전 세이브 호환: 경험치 도입 전에는 진행도가 "quest_level"이라는 이름이었고 그 값이 곧
	# 레벨이기도 했다. 이제 둘은 별개(progress = 스토리 진행도, player_level = 경험치 레벨)이므로,
	# 옛 값은 진행도로 옮기고 레벨은 그 진행도만큼 이미 올랐던 것으로 환산해 준다
	# (예전엔 퀘스트 하나 = 레벨 하나였으므로 1 + 완료 개수가 그때의 실질 레벨과 같다)
	if data.has("quest_level") and not data.has("progress"):
		var legacy: int = int(data["quest_level"])
		set_flag("progress", legacy)
		set_flag("player_level", 1 + legacy)

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


# ── 스킬포인트 / 카드 잠금해제 ──────────────────────────────────────────────
# 포인트는 flags("skill_points")에, 잠금해제 목록은 unlocked_cards에 나눠 담긴다.
# 카드의 비용/티어 정보는 전부 CardLibrary가 갖고 있고 여기서는 "쓸 수 있는가/얼마나 남았는가"만 다룬다

func get_skill_points() -> int:
	return get_flag("skill_points")


# 스킬포인트를 amount만큼 지급 (레벨업에서 호출). 음수는 받지 않는다 —
# 차감은 잠금해제 경로(unlock_card)에서만 일어나야 잔량이 어긋나지 않기 때문
func add_skill_points(amount: int) -> void:
	if amount <= 0:
		return
	set_flag("skill_points", get_skill_points() + amount)


# 해당 카드를 이미 갖고 있는지 (기본 제공 티어1 카드 포함)
func is_card_unlocked(card_id: String) -> bool:
	return unlocked_cards.has(card_id)


# 지금 이 카드를 잠금해제할 수 있는지. "이미 가진 카드"와 "포인트 부족"과 "없는 카드"를
# 전부 여기서 한 번에 판정해, unlock_card()와 UI 버튼 활성화가 같은 기준을 쓰게 한다
func can_unlock_card(card_id: String) -> bool:
	if is_card_unlocked(card_id):
		return false
	var cost := CardLibrary.get_unlock_cost(card_id)
	if cost == CardLibrary.UNKNOWN_COST:
		return false
	return get_skill_points() >= cost


# 카드를 잠금해제하고 비용만큼 스킬포인트를 차감한다. 성공하면 true.
# 실패 조건(이미 보유 / 포인트 부족 / 없는 카드id)에서는 아무것도 바꾸지 않고 false —
# 호출부가 결과만 보고 "부족합니다" 같은 안내를 띄울 수 있게 한다
func unlock_card(card_id: String) -> bool:
	if not can_unlock_card(card_id):
		return false
	var cost := CardLibrary.get_unlock_cost(card_id)
	set_flag("skill_points", get_skill_points() - cost)
	unlocked_cards.append(card_id)
	card_unlocked.emit(card_id)
	return true


# 저장 데이터(문자열 배열)로부터 잠금해제 목록을 복원.
# 저장 당시 없던 카드가 남지 않도록 기본값으로 되돌린 뒤 덮어쓰고, CardLibrary에 없는 id(옛 세이브에
# 남은 삭제된 카드 등)는 조용히 버린다. 기본 제공 카드는 세이브에 없더라도 항상 포함시켜야
# 구버전 세이브를 불러왔을 때 기본 카드까지 사라지는 일이 없다
func restore_unlocked_cards(data: Array) -> void:
	unlocked_cards = CardLibrary.DEFAULT_UNLOCKED.duplicate()
	for card_id in data:
		var id := String(card_id)
		if CardLibrary.CARD_PATHS.has(id) and not unlocked_cards.has(id):
			unlocked_cards.append(id)


# ── 전투 덱 구성 ────────────────────────────────────────────────────────────
# battle_deck은 "카드 id를 장 수만큼 늘어놓은 배열"이다. {id: 개수} 딕셔너리로 둘 수도 있었지만,
# 배열이면 그대로 순회해 덱을 만들 수 있어(StarterDeck.build) 변환 단계가 없고, 나중에 순서가
# 의미를 갖게 되더라도 구조를 바꿀 필요가 없다

func get_deck_size() -> int:
	return battle_deck.size()


# 덱에 들어 있는 해당 카드의 장 수
func get_deck_card_count(card_id: String) -> int:
	return battle_deck.count(card_id)


func get_deck_remaining() -> int:
	return MAX_BATTLE_DECK_SIZE - battle_deck.size()


# 덱에 카드를 한 장 넣는다. 전체 한도(15장)를 넘거나, 그 카드가 이미 개별 상한(MAX_COPIES_PER_CARD)만큼
# 들어있거나, 아직 잠금해제하지 않은 카드면 실패(false)
func add_card_to_deck(card_id: String) -> bool:
	if battle_deck.size() >= MAX_BATTLE_DECK_SIZE:
		return false
	if get_deck_card_count(card_id) >= MAX_COPIES_PER_CARD:
		return false
	if not is_card_unlocked(card_id):
		return false
	battle_deck.append(card_id)
	battle_deck_changed.emit()
	return true


# 덱에서 카드를 한 장 뺀다 (여러 장이면 하나만). 들어있지 않으면 실패(false)
func remove_card_from_deck(card_id: String) -> bool:
	var index := battle_deck.find(card_id)
	if index < 0:
		return false
	battle_deck.remove_at(index)
	battle_deck_changed.emit()
	return true


func clear_battle_deck() -> void:
	if battle_deck.is_empty():
		return
	battle_deck.clear()
	battle_deck_changed.emit()


# 저장 데이터(문자열 배열)로부터 덱 구성을 복원. 모르는 카드 id나 잠금해제되지 않은 카드는 버리고,
# 전체 한도와 카드별 상한(MAX_COPIES_PER_CARD)을 넘는 분량도 잘라낸다 — 세이브가 손상됐거나
# 카드별 상한 도입 전(구버전)에 저장된 3장 이상짜리 덱을 불러와도 전투가 깨지지 않게 하려는 것.
# (unlocked_cards가 먼저 복원돼 있어야 하므로 SaveManager에서 그 뒤에 부른다)
func restore_battle_deck(data: Array) -> void:
	battle_deck.clear()
	for card_id in data:
		if battle_deck.size() >= MAX_BATTLE_DECK_SIZE:
			break
		var id := String(card_id)
		if not CardLibrary.CARD_PATHS.has(id) or not is_card_unlocked(id):
			continue
		if get_deck_card_count(id) >= MAX_COPIES_PER_CARD:
			continue
		battle_deck.append(id)
	battle_deck_changed.emit()


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


# 퀘스트를 수락(active=true)하고 quest_changed를 방출. 이미 활성/없는 퀘스트면 무시.
# 진행도·레벨 조건을 만족하지 못하면 수락되지 않는다 — 대화 쪽에서 이미 걸러내지만, 여기서도 막아야
# 다른 경로로 들어와도 조건이 새지 않는다 (조건은 QUEST_REQUIREMENTS 한 곳에만 정의돼 있다)
func start_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var quest: Dictionary = quests[quest_id]
	if quest["active"]:
		return
	if not can_start_quest(quest_id):
		return
	quest["active"] = true
	quest_changed.emit(quest_id)


# 활성이고 미완료인 퀘스트만 진행도 +1. target 도달 시 complete 처리 +
# 호환 플래그(forest/cave_quest_complete)와 progress도 갱신
func increment_quest_progress(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var quest: Dictionary = quests[quest_id]
	if not quest["active"] or quest["complete"]:
		return

	quest["current"] = min(quest["current"] + 1, quest["target"])
	if quest["current"] >= quest["target"]:
		_finish_quest(quest_id, quest)

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
	_finish_quest(quest_id, quest)
	quest_changed.emit(quest_id)


# 퀘스트 완료 시 공통으로 일어나는 일 (increment 경로와 즉시완료 경로가 같은 처리를 타도록 한 곳에 모음):
# 완료 표시 → 호환 플래그 → 진행도 +1 → 완료 보너스 경험치 → 호감도 → 안내 시그널.
#
# 레벨업은 여기서 직접 하지 않는다 — 보너스 경험치를 add_xp()에 넘기면 그 안에서 필요치를 넘겼을 때만
# 레벨이 오른다. 그래서 "퀘스트를 깼는데 레벨은 안 오르는" 경우도, "한 번에 두 레벨 오르는" 경우도
# 자연스럽게 표현된다 (경험치 도입 전에는 퀘스트 완료가 곧 레벨업이었다)
func _finish_quest(quest_id: String, quest: Dictionary) -> void:
	quest["complete"] = true
	if QUEST_COMPLETE_FLAGS.has(quest_id):
		set_flag(QUEST_COMPLETE_FLAGS[quest_id], true)
	set_flag("progress", get_flag("progress") + 1)

	var bonus_xp: int = QUEST_COMPLETION_XP.get(quest_id, 0)
	if bonus_xp > 0:
		add_xp(bonus_xp)

	_apply_quest_completion_affinity(quest_id)
	quest_completed_notice.emit(quest["title"], bonus_xp)


# 해당 퀘스트가 완료 상태인지 여부
func is_quest_complete(quest_id: String) -> bool:
	return quests.has(quest_id) and quests[quest_id]["complete"]


# 퀘스트 완료 시 한 번 주는 보너스 경험치. 뒤로 갈수록 커져서, 다음 퀘스트의 레벨 조건을 향해
# 크게 한 걸음 나아가게 한다 (몬스터를 잡아 모으는 경험치를 보조하는 역할)
const QUEST_COMPLETION_XP: Dictionary = {
	"forest_orcs": 30,
	"cave_skeletons": 50,
	"desert_mummies": 80,
	"ruins_key": 150,
}

# 퀘스트 수락 조건: 진행도(선행 퀘스트를 몇 개 깼는가)와 레벨(얼마나 강한가)을 함께 본다.
# 진행도만으로는 "순서"만 강제되고 강함은 안 보게 되므로, 레벨 조건을 함께 걸어 경험치를 모아야
# 다음 단계로 넘어가도록 했다. 표에 없는 퀘스트(숲 오크 = 시작 퀘스트)는 조건 없이 수락 가능하다.
# prev_quest는 안내 문구에 쓸 "직전 퀘스트" (어느 걸 먼저 깨야 하는지 이름으로 알려주기 위함)
const QUEST_REQUIREMENTS: Dictionary = {
	"cave_skeletons": {"progress": 1, "level": 5, "prev_quest": "forest_orcs"},
	"desert_mummies": {"progress": 2, "level": 10, "prev_quest": "cave_skeletons"},
	"ruins_key": {"progress": 3, "level": 15, "prev_quest": "desert_mummies"},
}


# 이 퀘스트를 지금 수락할 수 있는지 (진행도와 레벨을 모두 만족해야 함).
# 조건표에 없는 퀘스트는 항상 true
func can_start_quest(quest_id: String) -> bool:
	if not QUEST_REQUIREMENTS.has(quest_id):
		return true
	var req: Dictionary = QUEST_REQUIREMENTS[quest_id]
	return get_flag("progress") >= int(req["progress"]) and get_player_level() >= int(req["level"])


# 조건 미달 시 대화창에 띄울 안내 문구 ("숲의 오크 소탕 완료 및 레벨 5 이상 필요").
# 조건이 없거나 이미 만족했으면 빈 문자열
func get_quest_requirement_text(quest_id: String) -> String:
	if not QUEST_REQUIREMENTS.has(quest_id) or can_start_quest(quest_id):
		return ""
	var req: Dictionary = QUEST_REQUIREMENTS[quest_id]
	var prev_id: String = req.get("prev_quest", "")
	var prev_title: String = quests[prev_id]["title"] if quests.has(prev_id) else "이전 퀘스트"
	return "%s 완료 및 레벨 %d 이상 필요" % [prev_title, int(req["level"])]


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


# ── 경험치 / 레벨 ──────────────────────────────────────────────────────────

# 레벨업 1회당 늘어나는 최대 체력/마나 폭
const LEVEL_UP_HP_GAIN := 3
const LEVEL_UP_MANA_GAIN := 3
# 레벨업 1회당 지급되는 스킬포인트 (티어2 카드 하나 = 3점이라, 레벨업 한 번에 티어2 하나를 풀 수 있다)
const SKILL_POINTS_PER_LEVEL := 3

# 레벨 N에서 N+1로 가는 데 필요한 경험치 = XP_BASE + (N-1) * XP_STEP.
# 레벨1→2는 10, 2→3은 15, 3→4는 20 … 으로 매 레벨 5씩 무거워진다 (상한 없음).
# 처음엔 40/20으로 시작했는데 오크(8 XP)만으로 레벨5까지 35마리가 필요할 만큼 무거워서,
# 초반 레벨업 체감을 빠르게 하려고 완만한 값으로 낮췄다
const XP_BASE := 10
const XP_STEP := 5


# level에서 다음 레벨로 가는 데 필요한 경험치. level이 1 미만이면 1레벨 기준으로 계산한다
func xp_to_next_level(level: int) -> int:
	return XP_BASE + (max(1, level) - 1) * XP_STEP


func get_player_level() -> int:
	return get_flag("player_level")


func get_player_xp() -> int:
	return get_flag("player_xp")


# 현재 레벨에서 다음 레벨까지 필요한 경험치 (HUD 진행바가 분모로 쓴다)
func get_xp_to_next() -> int:
	return xp_to_next_level(get_player_level())


# 경험치를 amount만큼 주고, 필요치를 넘을 때마다 레벨을 올린다.
#
# xp는 "현재 레벨 안에서 쌓인 양"이라 레벨업할 때마다 그 레벨의 필요치를 빼고 남은 만큼이 다음
# 레벨로 이월된다. while 루프인 이유는 한 번에 여러 레벨이 오를 수 있기 때문이다 —
# 유적 보스(100 XP)처럼 큰 덩어리를 받거나 낮은 레벨에서 여러 마리를 한꺼번에 잡는 경우가 그렇다.
#
# 실제로 오른 레벨 수를 반환한다 (호출부가 "레벨업했는지"를 알고 싶을 때 쓰라고)
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0

	set_flag("player_xp", get_player_xp() + amount)

	var levels_gained := 0
	while get_player_xp() >= get_xp_to_next():
		set_flag("player_xp", get_player_xp() - get_xp_to_next())
		set_flag("player_level", get_player_level() + 1)
		_apply_level_up()
		levels_gained += 1

	xp_changed.emit(get_player_xp(), get_xp_to_next())
	return levels_gained


# 레벨이 하나 오를 때마다 호출됨. 최대 체력/마나를 늘리고 같은 폭만큼 현재치도 회복시킨 뒤
# (최대치 초과 방지) player_leveled_up을 방출해 LevelUpPopup이 안내하게 함
func _apply_level_up() -> void:
	# 레벨업은 "기본" 최대 체력만 올리고, 실제 player_max_hp는 방패 보너스를 얹어 다시 계산한다.
	# (player_max_hp를 직접 올리면 방패를 낀 채 레벨업할 때 보너스가 기본값에 눌러붙어 중복 적용된다)
	set_flag("player_base_max_hp", get_flag("player_base_max_hp") + LEVEL_UP_HP_GAIN)
	refresh_equipment_bonuses()
	set_flag("player_hp", min(get_flag("player_max_hp"), get_flag("player_hp") + LEVEL_UP_HP_GAIN))
	set_flag("player_max_mana", get_flag("player_max_mana") + LEVEL_UP_MANA_GAIN)
	set_flag("player_mana", min(get_flag("player_max_mana"), get_flag("player_mana") + LEVEL_UP_MANA_GAIN))
	add_skill_points(SKILL_POINTS_PER_LEVEL)
	player_leveled_up.emit(get_player_level(), LEVEL_UP_HP_GAIN, LEVEL_UP_MANA_GAIN, SKILL_POINTS_PER_LEVEL)


# 해당 퀘스트가 수락되어 활성 상태인지 여부
func is_quest_active(quest_id: String) -> bool:
	return quests.has(quest_id) and quests[quest_id]["active"]


# 모든 퀘스트를 기본값으로 되돌리고 각 quest_changed를 방출 (새 게임/리셋용)
# ── 의뢰 (서브 퀘스트) ─────────────────────────────────────────────────────

func reset_sub_quests() -> void:
	bounty_board = []
	active_sub_quest = {}
	sub_quest_changed.emit()


func has_active_sub_quest() -> bool:
	return not active_sub_quest.is_empty()


# 의뢰판을 처음 열 때만 채운다 — 열 때마다 새로 뽑으면 5골드짜리 새로고침이 의미가 없어진다
func ensure_bounty_board() -> void:
	if bounty_board.is_empty():
		bounty_board = SubQuestData.generate_board()
		sub_quest_changed.emit()


func refresh_bounty_board() -> bool:
	if not spend_gold(SubQuestData.REFRESH_COST):
		return false
	bounty_board = SubQuestData.generate_board()
	sub_quest_changed.emit()
	return true


# 의뢰판의 index번째 의뢰를 수락. 이미 진행 중인 의뢰가 있으면 거절한다
func accept_sub_quest(index: int) -> bool:
	if has_active_sub_quest():
		return false
	if index < 0 or index >= bounty_board.size():
		return false
	active_sub_quest = (bounty_board[index] as Dictionary).duplicate(true)
	bounty_board.remove_at(index)
	sub_quest_changed.emit()
	return true


# 몬스터 한 마리를 잡을 때마다 호출된다 (전투 씬의 마리별 보상 루프). 목표에 없는 종류면 아무 일도 안 함.
# 목표를 다 채우면 반납 절차 없이 그 자리에서 완료 처리한다 (메인 퀘스트와 같은 규칙)
func add_sub_quest_progress(monster_type: String) -> void:
	if not has_active_sub_quest():
		return
	var targets: Dictionary = active_sub_quest.get("targets", {})
	if not targets.has(monster_type):
		return

	var progress: Dictionary = active_sub_quest["progress"]
	var target := int(targets[monster_type])
	progress[monster_type] = min(int(progress.get(monster_type, 0)) + 1, target)
	sub_quest_changed.emit()

	if SubQuestData.is_complete(active_sub_quest):
		_finish_sub_quest()


func _finish_sub_quest() -> void:
	var quest := active_sub_quest
	active_sub_quest = {}

	add_gold(int(quest.get("gold", 0)))
	change_affinity("elara", int(quest.get("affinity", 0)))

	var rewards: Array[String] = [
		"골드 +%d" % int(quest.get("gold", 0)),
		"경험치 +%d" % int(quest.get("xp", 0)),
		"%s 호감도 +%d" % [SubQuestData.GIVER, int(quest.get("affinity", 0))],
	]
	for key in ["bonus_item", "bonus_equipment"]:
		var item_id: String = String(quest.get(key, ""))
		if item_id != "" and ItemData.ITEMS.has(item_id):
			add_item(item_id, 1)
			rewards.append("%s x1" % ItemData.ITEMS[item_id]["name"])

	# 경험치는 마지막에 준다 — add_xp가 레벨업 안내를 따로 큐에 넣으므로,
	# 의뢰 완료 안내가 레벨업 안내보다 먼저 쌓이도록 순서를 맞춘다
	sub_quest_completed.emit(SubQuestData.title(quest), "\n".join(rewards))
	add_xp(int(quest.get("xp", 0)))

	sub_quest_changed.emit()


func restore_sub_quests(board: Array, active: Dictionary) -> void:
	bounty_board = board.duplicate(true)
	active_sub_quest = active.duplicate(true)
	_normalize_sub_quest_numbers(active_sub_quest)
	for quest in bounty_board:
		_normalize_sub_quest_numbers(quest)
	sub_quest_changed.emit()


# JSON은 숫자를 전부 float로 돌려주므로 목표/진행도를 int로 되돌린다 (안 하면 "3.0마리"로 표시된다)
func _normalize_sub_quest_numbers(quest: Dictionary) -> void:
	if quest.is_empty():
		return
	for key in ["targets", "progress"]:
		var table: Dictionary = quest.get(key, {})
		for monster_type in table.keys():
			table[monster_type] = int(table[monster_type])
	for key in ["gold", "xp", "affinity"]:
		if quest.has(key):
			quest[key] = int(quest[key])


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


# Stage 4→5 전환에 쓰는 progress(진행도) 임계값 (현재 퀘스트 2개 기준, guardian 게이트와 동일)
const OBJECTIVE_PROGRESS_TARGET := 2

# 별도 flag로 저장하지 않고, 기존 진행 flag들로 현재 메인 목표 단계(1~15)를 매번 계산해서 반환.
# objective 상태가 실제 진행 상황과 항상 일치하게 유지된다.
# 7~9는 1부 마무리~출항: 엘라라 보고(7) → 유서프에게 더 알아보기(8) → 부두에서 출항(9)
# 10~15는 2부: 나딤(10) → 사막 위협/열쇠(11) → 문지기(12) → 필터룸(13) → 카밀 최종 선택(14) → 완료(15)
func get_current_objective_stage() -> int:
	if not get_flag("met_elara"):
		return 1

	if _met_villager_count() < 2:
		return 2

	# 여기부터는 met_rohan == true && met_yusuf == true
	if not get_flag("met_mia_decisive"):
		return 3

	if not get_flag("elara_grind_advice_given"):
		return 4

	if get_flag("progress") < OBJECTIVE_PROGRESS_TARGET:
		return 5

	if not get_flag("guardian_event_done"):
		return 6

	if not get_flag("part1_reported"):
		return 7

	if not get_flag("boat_available"):
		return 8

	if not get_flag("arrived_desert"):
		return 9

	if not get_flag("ruins_available"):
		return 10

	if not (is_quest_complete("desert_mummies") and has_item("ruins_key")):
		return 11

	if not get_flag("ruins_boss_defeated"):
		return 12

	if not get_flag("filter_room_done"):
		return 13

	if not get_flag("part2_complete"):
		return 14

	return 15


# 현재 단계에 대응하는 안내 문구를 반환 (진행도 N은 실시간 계산해서 보간)
func get_objective_text() -> String:
	match get_current_objective_stage():
		1:
			return "엘라라를 찾아가 대화해보세요"
		2:
			return "로한과 유서프를 찾아가 대화하세요 (%d/2)" % _met_villager_count()
		3:
			return "마을 외곽에서 미아를 만나 결정적 정보를 얻으세요"
		4:
			return "엘라라에게 돌아가 알아낸 것을 전하세요"
		5:
			return "퀘스트 버튼을 눌러 받을 수 있는 퀘스트와 의뢰인을 확인한 후 레벨업하세요"
		6:
			return "동굴 깊은 곳의 수호자를 찾아가세요"
		7:
			return "우물의 결과를 엘라라에게 알리세요"
		8:
			return "유서프에게 가서 더 알아보세요"
		9:
			return "부두에서 배를 타고 떠나세요"
		10:
			return "사막 정착지에서 나딤을 찾아 대화하세요"
		11:
			return "사막의 위협을 처치하고 유적의 열쇠를 찾으세요"
		12:
			return "유적 안으로 들어가 문지기와 맞서세요"
		13:
			return "필터룸 깊숙이 들어가 진실을 확인하세요"
		14:
			return "카밀과 이야기해 다음 행보를 정하세요"
		_:
			return "선택을 마쳤습니다. 이야기는 여기서 계속됩니다."


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
