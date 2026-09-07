class_name CompanionData
extends RefCounted

# 동료 카탈로그. BattleData.MONSTERS와 같은 "그냥 표" 성격의 정적 데이터.
# 수치는 전부 플레이스홀더 — Phase 4에서 실제로 굴려보며 확정한다
# (docs/companion_system_backend_plan.md §2, §6 Q9)
const COMPANIONS: Dictionary = {
	"yusuf": {
		"name": "유서프",
		"battle_sprite_frames": preload("res://npc/yusuf_sprite_frames.tres"), # 필드와 동일한 리소스 재사용
		# 6.8(프레임 크기 비율만 맞춘 값)로는 실제 그림이 훨씬 크게 나왔다 — 플레이어 시트는 프레임 안
		# 여백이 커서(실제 그림 102px/프레임 217.6px) 이 시트(여백 거의 없음)와 다르다.
		# CharacterShadow._measure_art()로 잰 실제 그림 높이를 플레이어와 맞춘 값
		"battle_scale": 3.1875,
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
