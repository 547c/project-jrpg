extends Node

# 플래그 값이 실제로 바뀔 때 방출되는 단일 시그널 (대화/NPC 등이 구독해 자동 반응)
signal flag_changed(flag_name: String, value)

# 모든 플래그의 초기값 (reset_progress()가 이 값들로 되돌리는 기준이 되기도 함)
const DEFAULT_FLAGS: Dictionary = {
	"resolved_guardian_peacefully": false, # 결정적 플래그: 가디언을 평화적으로 정화했는가
	"earned_mia_trust": false,             # 결정적 플래그: 미아의 신뢰를 얻었는가
	"met_elara": false,                    # 엘라라(장로)를 만났는가
	"met_rohan": false,                    # 로한(사냥꾼)을 만났는가
	"met_yusuf": false,                    # 유수프(상인)를 만났는가
	"met_mia": false,                      # 미아(아이)를 만났는가
	"visited_village": false,              # 마을을 방문했는가
	"visited_forest": false,               # 숲을 방문했는가
	"visited_cave": false,                 # 동굴을 방문했는가
	"seen_opening": false,                 # 오프닝 인트로를 이미 봤는가 (재부팅 시 반복 방지)
	"guardian_event_done": false,          # 동굴 수호자 조우 이벤트를 이미 겪었는가
	"player_hp": 16,                       # 플레이어 현재 체력
	"player_max_hp": 16,                   # 플레이어 최대 체력
	"orcs_defeated": 0,                    # 숲 오크(Orc Crew) 처치 카운트
	"forest_quest_complete": false,        # 오크 3마리 처치 시 true
	"skeletons_defeated": 0,               # 동굴 스켈레톤(Skeleton Crew) 처치 카운트
	"cave_quest_complete": false,          # 스켈레톤 3마리 처치 시 true
	"quest_level": 0,                      # 완료한 서브퀘스트 개수
}

# 씬 전환에도 유지되는 게임 상태. DEFAULT_FLAGS를 복사해 시작한다
var flags: Dictionary = DEFAULT_FLAGS.duplicate()


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


# player_hp를 amount만큼 깎되 0 밑으로 내려가지 않게 함
func damage_player(amount: int) -> void:
	set_flag("player_hp", max(0, get_flag("player_hp") - amount))


# player_hp를 player_max_hp까지 전부 회복 (전투 패배 후 복구용)
func heal_player_full() -> void:
	set_flag("player_hp", get_flag("player_max_hp"))


# player_hp를 player_max_hp의 절반만 회복 (전투 기절 페널티용 - 완전 회복보다 약함)
func heal_player_half() -> void:
	set_flag("player_hp", get_flag("player_max_hp") / 2)


# 오크 처치 수를 1 늘리고, 3마리째면 숲 퀘스트를 완료 처리하며 quest_level도 올림
func increment_orcs_defeated() -> void:
	var new_count: int = get_flag("orcs_defeated") + 1
	set_flag("orcs_defeated", new_count)
	if new_count == 3:
		set_flag("forest_quest_complete", true)
		set_flag("quest_level", get_flag("quest_level") + 1)


# 스켈레톤 처치 수를 1 늘리고, 3마리째면 동굴 퀘스트를 완료 처리하며 quest_level도 올림
func increment_skeletons_defeated() -> void:
	var new_count: int = get_flag("skeletons_defeated") + 1
	set_flag("skeletons_defeated", new_count)
	if new_count == 3:
		set_flag("cave_quest_complete", true)
		set_flag("quest_level", get_flag("quest_level") + 1)


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
