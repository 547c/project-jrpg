class_name CompanionData
extends RefCounted

# 동료 카탈로그. BattleData.MONSTERS와 같은 "그냥 표" 성격의 정적 데이터.
# 수치는 전부 플레이스홀더 — Phase 4에서 실제로 굴려보며 확정한다
# (docs/companion_system_backend_plan.md §2, §6 Q9)
const COMPANIONS: Dictionary = {
	"yusuf": {
		"name": "유서프",
		"max_hp": 30, # 플레이스홀더, Phase 4에서 확정
		"damage_min": 4, # 플레이스홀더, Phase 4에서 확정
		"damage_max": 6, # 플레이스홀더, Phase 4에서 확정
		"passive": {
			"period": 5, # 플레이스홀더, Phase 4에서 확정 (N턴마다 발동)
			"kind": "RECOVER", # 플레이스홀더 — 마나 또는 체력 소량 회복
			"amount": 0, # 플레이스홀더, Phase 4에서 확정
		},
		"active": {
			"cooldown": 3, # 플레이스홀더, Phase 4에서 확정
			"kind": "MANA_BARRIER", # 다음 턴 받는 데미지 방어/경감
			"amount": 0, # 플레이스홀더, Phase 4에서 확정
		},
	},
}
