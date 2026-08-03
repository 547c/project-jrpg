class_name BattleData
extends RefCounted

# 플레이어 공격 한 번의 데미지 범위 (매 턴 이 범위에서 무작위로 뽑음)
const PLAYER_ATTACK_DAMAGE_MIN := 3
const PLAYER_ATTACK_DAMAGE_MAX := 5

# 마나로 사용하는 스킬 3종. 표시 순서(강타→회복→피하기)는 딕셔너리 삽입 순서를 따른다.
# - STRIKE: 이번 공격 데미지 damage_mult배 (몬스터 반격 있음)
# - HEAL:   자신 HP를 최대치의 heal_fraction만큼 회복 (공격은 안 함, 몬스터 반격 있음)
# - DODGE:  이번 턴 몬스터 공격을 완전히 회피(데미지 0). 대신 플레이어도 공격하지 않음
const SKILLS: Dictionary = {
	"STRIKE": {"name": "강타", "mana_cost": 4, "damage_mult": 2},
	"HEAL": {"name": "회복", "mana_cost": 6, "heal_fraction": 0.3},
	"DODGE": {"name": "피하기", "mana_cost": 2},
}

# 몬스터 종류별 전투 데이터. damage_min/damage_max: 몬스터 반격 한 번의 피해 범위 (매 반격마다 무작위).
# gold_min/gold_max: 처치 시 드롭하는 골드 범위 (스켈레톤이 오크보다 강한 만큼 보상도 더 많음).
# sprite_path: 이 팩(Pixel Crawler - Free Pack)에는 별도의 "attack" 모션이 없어서
# Idle 스프라이트 시트(32x32 프레임 4개, 첫 프레임만 사용)를 정적으로 사용한다.
# portrait_region: 전투 카드 초상화용으로 sprite_path의 첫 프레임에서 머리만 잘라낸 영역
const MONSTERS: Dictionary = {
	"ORC": {
		"name": "오크",
		"max_hp": 30,
		"damage_min": 5,
		"damage_max": 5,
		"gold_min": 5,
		"gold_max": 8,
		"sprite_path": "res://assets/Pixel Crawler - Free Pack/Entities/Mobs/Orc Crew/Orc - Warrior/Idle/Idle-Sheet.png",
		"portrait_region": Rect2(6, 0, 19, 15),
	},
	"SKELETON": {
		"name": "스켈레톤",
		"max_hp": 40,
		"damage_min": 6,
		"damage_max": 7,
		"gold_min": 8,
		"gold_max": 12,
		"sprite_path": "res://assets/Pixel Crawler - Free Pack/Entities/Mobs/Skeleton Crew/Skeleton - Warrior/Idle/Idle-Sheet.png",
		"portrait_region": Rect2(5, 1, 17, 14),
	},
}
