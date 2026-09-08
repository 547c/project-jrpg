class_name CompanionData
extends RefCounted

# 동료 카탈로그. BattleData.MONSTERS와 같은 "그냥 표" 성격의 정적 데이터.
# 수치는 전부 플레이스홀더 — Phase 4에서 실제로 굴려보며 확정한다
# (docs/companion_system_backend_plan.md §2, §6 Q9)
const COMPANIONS: Dictionary = {
	"yusuf": {
		"name": "유서프",
		"battle_sprite_frames": preload("res://npc/yusuf_sprite_frames.tres"), # 필드와 동일한 리소스 재사용
		# HUD 카드에 넣을 얼굴 크롭. idle 프레임(32x32)을 통째로 넣으면 전신이 들어가 다른
		# 카드들과 눈높이가 안 맞는다 — 모자~수염까지만 잘라 플레이어 초상화와 같은 구도로 맞춘다
		"portrait_sheet": preload("res://assets/graphics/Pixel Crawler - Free Pack/Entities/Npc's/Wizzard/Idle/Idle-Sheet.png"),
		"portrait_region": Rect2(5, 0, 22, 20),
		# 6.8(프레임 크기 비율만 맞춘 값)로는 실제 그림이 훨씬 크게 나왔다 — 플레이어 시트는 프레임 안
		# 여백이 커서(실제 그림 102px/프레임 217.6px) 이 시트(여백 거의 없음)와 다르다.
		# CharacterShadow._measure_art()로 잰 실제 그림 높이를 플레이어와 맞춘 값
		"battle_scale": 3.1875,
		"max_hp": 30, # 플레이스홀더, Phase 4에서 확정
		"damage_min": 4, # 플레이스홀더, Phase 4에서 확정
		"damage_max": 6, # 플레이스홀더, Phase 4에서 확정
		# 몬스터 마나 리듬(MonsterState)을 거의 그대로 이식 — 필드명과 값 전부 몬스터 쪽 상수를
		# 참고한 플레이스홀더 (docs/companion_system_options.md §7)
		"mana": {
			"max_mana": 100, # 플레이스홀더 — MonsterState.MANA_MAX 참고
			"attack_cost_min": 25, # 플레이스홀더 — MonsterState.ATTACK_COST_MIN 참고
			"attack_cost_max": 40, # 플레이스홀더 — MonsterState.ATTACK_COST_MAX 참고
			"low_mana_threshold": 25, # 플레이스홀더 — MonsterState.LOW_MANA_THRESHOLD 참고
			"recover_mana_min": 40, # 플레이스홀더 — MonsterState.RECOVER_MANA_MIN 참고
			"recover_mana_max": 60, # 플레이스홀더 — MonsterState.RECOVER_MANA_MAX 참고
			"recover_hp_chance": 0.3, # 플레이스홀더 — MonsterState.RECOVER_HP_CHANCE 참고
			"recover_hp_fraction_min": 0.05, # 플레이스홀더 — MonsterState.RECOVER_HP_FRACTION_MIN 참고
			"recover_hp_fraction_max": 0.10, # 플레이스홀더 — MonsterState.RECOVER_HP_FRACTION_MAX 참고
		},
		"passive": {
			"period": 5, # 플레이스홀더, Phase 4에서 확정 (N턴마다 발동)
			"kind": "RECOVER", # 파티 전체 체력/마력 10%씩 회복 (§7)
			"amount": 0, # 플레이스홀더, Phase 4에서 확정
		},
		"active": {
			"name": "마력장벽",
			"description": "파티 전체 다음 턴 피해 30% 감소 (마나 20% 소모)",
			# Franuka RPG UI Pack의 미니 아이콘 중 방패 모양(Icon_10) — 전용 "장벽" 아이콘은 에셋에
			# 없어 가장 가까운 걸 재활용. 나중에 다른 액티브가 생기면 이 필드만 바꾸면 된다
			"icon": preload("res://assets/GUI/RPG UI Pack (Franuka)/Individual files/1x/Mini icons/Icon_10.png"),
			# 전투 시작 후 이 라운드 수가 지나야 사용 가능 — 반복 쿨다운이 아니라 1회성 게이트,
			# 그 뒤로는 마나만 있으면 계속 사용 가능 (docs/companion_system_options.md §7)
			"unlock_turn": 3,
			"mana_cost_fraction": 0.2, # 사용 시 소모하는 마나 비율 — §7
			"damage_reduction_fraction": 0.3, # 파티 전원에게 붙는 "다음 적 턴 피해 감소" 비율 — §7
		},
	},
}
