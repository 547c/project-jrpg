extends Node

# 플래그 값이 실제로 바뀔 때 방출되는 단일 시그널 (대화/NPC 등이 구독해 자동 반응)
signal flag_changed(flag_name: String, value)

# 씬 전환에도 유지되는 게임 상태. 모든 플래그의 초기값을 미리 정의해 둔다
var flags: Dictionary = {
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
}


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
