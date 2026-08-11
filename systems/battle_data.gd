class_name BattleData
extends RefCounted

# 플레이어 공격 한 번의 데미지 범위 (매 턴 이 범위에서 무작위로 뽑음)
const PLAYER_ATTACK_DAMAGE_MIN := 3
const PLAYER_ATTACK_DAMAGE_MAX := 5

# 마나로 사용하는 스킬 3종. 표시 순서(강타→회복→피하기)는 딕셔너리 삽입 순서를 따른다.
# - STRIKE: 이번 공격 데미지 damage_mult배 (몬스터 반격 있음)
# - HEAL:   자신 HP를 최대치의 heal_fraction만큼 회복 (공격은 안 함, 몬스터 반격 있음)
# - DODGE:  몬스터 공격은 완전히 회피(데미지 0)하면서 동시에 정상 공격의 damage_mult배(감쇄)로 반격.
#   완전히 동일한 데미지면 항상 다른 스킬보다 우월해지므로 화력을 낮춰 트레이드오프를 유지한다
const SKILLS: Dictionary = {
	"STRIKE": {"name": "강타", "mana_cost": 4, "damage_mult": 2},
	"HEAL": {"name": "회복", "mana_cost": 6, "heal_fraction": 0.48},
	"DODGE": {"name": "피하기", "mana_cost": 2, "damage_mult": 0.7},
}

# 몬스터 종류별 전투 데이터. damage_min/damage_max: 몬스터 반격 한 번의 피해 범위 (매 반격마다 무작위).
# gold_min/gold_max: 처치 시 드롭하는 골드 범위 (스켈레톤이 오크보다 강한 만큼 보상도 더 많음).
# portrait_region: 전투 카드 초상화용으로 Idle 시트의 첫 프레임에서 머리만 잘라낸 영역
# (변종마다 그림은 달라도 캔버스 비율은 같은 팩 컨벤션이라, 어떤 변종이 뽑히든 같은 좌표를 재사용한다).
# 스탯은 변종과 무관하게 타입 하나로 통일 — 변종은 pick_variant()가 다루는 순수 시각 정보
const MONSTERS: Dictionary = {
	"ORC": {
		"name": "오크",
		"max_hp": 30,
		"damage_min": 5,
		"damage_max": 5,
		"gold_min": 5,
		"gold_max": 8,
		"portrait_region": Rect2(6, 0, 19, 15),
	},
	"SKELETON": {
		"name": "스켈레톤",
		"max_hp": 40,
		"damage_min": 6,
		"damage_max": 7,
		"gold_min": 8,
		"gold_max": 12,
		"portrait_region": Rect2(5, 1, 17, 14),
	},
	# 미라(2부 사막): 오크/스켈레톤보다 강함. 스프라이트는 유료 Desert 팩(Idle/Run/Death 모두 64x64)이라
	# 프레임 크기가 무료 팩 몹(Idle 32)과 달라 아래 MONSTER_VARIANTS에서 변형별로 크기를 지정한다
	"MUMMY": {
		"name": "미라",
		"max_hp": 45,
		"damage_min": 7,
		"damage_max": 8,
		"gold_min": 12,
		"gold_max": 16,
		"portrait_region": Rect2(24, 33, 16, 16), # 64x64 Idle 프레임에서 미라 머리(하단 정렬 캐릭터의 상부)만 크롭
	},
}

# 몬스터 애니메이션 시트가 있는 폴더. 대부분 무료 팩(Mobs) 아래지만, 미라는 유료 Desert 팩 아래라
# 변형마다 "base"로 다른 루트를 지정할 수 있게 한다 (미지정 시 MOB_SHEET_BASE 사용)
const MOB_SHEET_BASE := "res://assets/graphics/Pixel Crawler - Free Pack/Entities/Mobs/"
const MUMMY_SHEET_BASE := "res://assets/graphics/Pixel Crawler - Desert/Enemy/"

# 무료 팩 몹의 기본 프레임 크기 (Idle 32x32x4, Run 64x64x6). 변종이 값을 지정하지 않으면 이 기본값을 씀.
# 미라(Desert)처럼 프레임 크기가 다른 변종은 MONSTER_VARIANTS에서 idle/run_frame_size·count를 직접 지정한다.
# Death는 원래부터 변종마다 캔버스/개수가 달라 MONSTER_VARIANTS에 변종별로 따로 기록해왔다
const MOB_IDLE_FRAME_SIZE := 32
const MOB_IDLE_FRAME_COUNT := 4
const MOB_RUN_FRAME_SIZE := 64
const MOB_RUN_FRAME_COUNT := 6

# 타입별 시각적 변종 목록 (순수 겉모습 차이 — 스탯은 위 MONSTERS로 통일 유지).
# death_frame_width/height/count: 실측한 Death-Sheet.png의 프레임 크기·개수 (변종마다 제각각이라
# 하드코딩 필요 — 캔버스는 커도 캐릭터 실제 크기는 Idle과 동일해서, 표시할 땐 프레임 크기에 반비례해
# 스케일을 보정해야 크기가 튀지 않는다. 이 보정은 monster_encounter.gd/battle_scene.gd가 담당)
const MONSTER_VARIANTS: Dictionary = {
	"ORC": [
		{"folder": "Orc Crew/Orc", "death_frame_width": 64, "death_frame_height": 64, "death_frame_count": 6},
		{"folder": "Orc Crew/Orc - Rogue", "death_frame_width": 64, "death_frame_height": 64, "death_frame_count": 6},
		{"folder": "Orc Crew/Orc - Shaman", "death_frame_width": 64, "death_frame_height": 64, "death_frame_count": 7},
		{"folder": "Orc Crew/Orc - Warrior", "death_frame_width": 96, "death_frame_height": 80, "death_frame_count": 6},
	],
	"SKELETON": [
		{"folder": "Skeleton Crew/Skeleton - Base", "death_frame_width": 96, "death_frame_height": 64, "death_frame_count": 8},
		{"folder": "Skeleton Crew/Skeleton - Mage", "death_frame_width": 64, "death_frame_height": 64, "death_frame_count": 6},
		{"folder": "Skeleton Crew/Skeleton - Rogue", "death_frame_width": 64, "death_frame_height": 64, "death_frame_count": 6},
		{"folder": "Skeleton Crew/Skeleton - Warrior", "death_frame_width": 64, "death_frame_height": 48, "death_frame_count": 6},
	],
	# 미라 3종(유료 Desert 팩). 모든 애니메이션이 64x64 프레임 (Idle x4, Run x6, Death x6)이라
	# 무료 팩 기본값(Idle 32) 대신 변종에서 직접 지정하고, base로 Desert 루트를 가리킨다
	"MUMMY": [
		{"folder": "Mummy - Base", "base": MUMMY_SHEET_BASE, "idle_frame_size": 64, "idle_frame_count": 4, "run_frame_size": 64, "run_frame_count": 6, "death_frame_width": 64, "death_frame_height": 64, "death_frame_count": 6},
		{"folder": "Mummy - Rogue", "base": MUMMY_SHEET_BASE, "idle_frame_size": 64, "idle_frame_count": 4, "run_frame_size": 64, "run_frame_count": 6, "death_frame_width": 64, "death_frame_height": 64, "death_frame_count": 6},
		{"folder": "Mummy - Warrior", "base": MUMMY_SHEET_BASE, "idle_frame_size": 64, "idle_frame_count": 4, "run_frame_size": 64, "run_frame_count": 6, "death_frame_width": 64, "death_frame_height": 64, "death_frame_count": 6},
	],
}


# monster_type의 변종 중 하나를 무작위로 골라, 애니메이션 시트 경로까지 채운 딕셔너리로 반환.
# MonsterEncounter가 스폰/리젠 때, BattleScene이 전투 진입 때 이 정보로 스프라이트를 구성해
# 필드에서 본 변종이 전투 씬까지 그대로 이어지게 한다
static func pick_variant(monster_type: String) -> Dictionary:
	var variants: Array = MONSTER_VARIANTS[monster_type]
	var variant: Dictionary = variants[randi() % variants.size()].duplicate()
	var base_path: String = variant.get("base", MOB_SHEET_BASE) + variant["folder"] + "/"
	variant["idle_path"] = base_path + "Idle/Idle-Sheet.png"
	variant["run_path"] = base_path + "Run/Run-Sheet.png"
	variant["death_path"] = base_path + "Death/Death-Sheet.png"
	# 프레임 크기·개수는 변종이 지정했으면 그 값을, 아니면 무료 팩 기본값을 채워 넣는다
	# (monster_encounter/battle_scene이 전역 상수 대신 이 값을 읽어 미라처럼 크기가 다른 몹도 올바로 자른다)
	variant["idle_frame_size"] = variant.get("idle_frame_size", MOB_IDLE_FRAME_SIZE)
	variant["idle_frame_count"] = variant.get("idle_frame_count", MOB_IDLE_FRAME_COUNT)
	variant["run_frame_size"] = variant.get("run_frame_size", MOB_RUN_FRAME_SIZE)
	variant["run_frame_count"] = variant.get("run_frame_count", MOB_RUN_FRAME_COUNT)
	return variant
