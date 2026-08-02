class_name BattleData
extends RefCounted

# 플레이어 공격 한 번의 데미지 범위 (매 턴 이 범위에서 무작위로 뽑음)
const PLAYER_ATTACK_DAMAGE_MIN := 3
const PLAYER_ATTACK_DAMAGE_MAX := 5

# 몬스터 종류별 전투 데이터.
# sprite_path: 이 팩(Pixel Crawler - Free Pack)에는 별도의 "attack" 모션이 없어서
# Idle 스프라이트 시트(32x32 프레임 4개, 첫 프레임만 사용)를 정적으로 사용한다
const MONSTERS: Dictionary = {
	"ORC": {
		"name": "오크",
		"max_hp": 18,
		"damage": 5,
		"sprite_path": "res://assets/Pixel Crawler - Free Pack/Entities/Mobs/Orc Crew/Orc - Warrior/Idle/Idle-Sheet.png",
	},
	"SKELETON": {
		"name": "스켈레톤",
		"max_hp": 16,
		"damage": 4,
		"sprite_path": "res://assets/Pixel Crawler - Free Pack/Entities/Mobs/Skeleton Crew/Skeleton - Warrior/Idle/Idle-Sheet.png",
	},
}
