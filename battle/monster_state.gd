class_name MonsterState
extends RefCounted

# 전투에 참여한 몬스터 "한 마리"의 상태. 다인전(1~3마리) 도입 전에는 이 정보가 전부
# BattleTurnManager의 단일 변수(monster_hp / monster_data / resistance)로 흩어져 있었는데,
# 마리 수가 늘어나면 그 셋이 항상 같은 몬스터를 가리켜야 한다는 제약이 생겨서 한 덩어리로 묶었다.
#
# [왜 Dictionary가 아니라 클래스인가] 이 파일 안에서 hp/max_hp/resistance가 서로 맞물려 돌아가고
# (take_damage는 clamp까지 책임진다), 호출부가 오타 난 키로 조용히 null을 읽는 일이 없어야 해서
# WeaponState/EnemyResistance와 같은 방식(작은 RefCounted 클래스)을 따랐다. BattleData.MONSTERS처럼
# "그냥 표"인 데이터와 달리 여기엔 행동이 붙는다.
#
# monster_data/variant는 원본 카탈로그(BattleData)의 값을 그대로 참조한다 — 마리마다 스탯이 달라지는
# 기능은 아직 없고(같은 종류만 여러 마리), 시각 변종만 마리별로 다르게 뽑힌다.

var index: int = 0 # 이 전투 안에서의 자리 번호 (0부터). 타겟 지정/스프라이트 매칭의 키
var monster_type: String = "" # BattleData.MONSTERS의 키 ("ORC" 등)
var monster_data: Dictionary = {} # 그 종류의 스탯 표 (max_hp/damage_min/gold_min/...)
var variant: Dictionary = {} # 이 개체가 표시할 시각 변종 (BattleData.pick_variant 결과)

var max_hp: int = 0
var hp: int = 0
var resistance: EnemyResistance # 마리마다 독립적으로 굴린다 (한 마리가 물리 저항이어도 옆은 아닐 수 있음)

# 이 몬스터에게 걸린 버프/디버프. 플레이어 쪽(BattleTurnManager.player_status)과 같은 클래스를 쓴다 —
# "누구에게 걸렸는가"만 다르고 규칙은 같아서, 마리마다 하나씩 들고 있으면 그걸로 끝난다
var status: StatusEffects

# ── 몬스터 마나 (연출용 "가짜" 자원) ──────────────────────────────────────
# 플레이어 마나처럼 카드 비용을 치르는 진짜 자원이 아니라, "적도 자원을 쓰며 싸운다"는 그림을
# 만들기 위한 장치다. 공격할 때마다 줄고 바닥나면 그 턴은 회복에 쓰므로, 결과적으로 적이 매 턴
# 똑같이 때리기만 하지 않고 공격/숨고르기를 오가게 된다 — 플레이어에겐 "적이 쉬는 턴"이 곧
# 반격을 몰아칠 기회가 되어 턴마다 판단할 거리가 생긴다.
#
# 밸런스에 직접 손대지 않는다는 점이 중요하다: 피해량은 여전히 monster_data의 damage_min/max가
# 정하고, 마나는 "이번 턴에 때리는가 마는가"만 가른다
const MANA_MAX := 100
const ATTACK_COST_MIN := 25
const ATTACK_COST_MAX := 40
# 이 값 미만이면 공격 대신 회복 턴. 공격 최소 비용과 같은 값이라 "다음 공격을 낼 수 없으면 쉰다"가 된다
const LOW_MANA_THRESHOLD := 25
const RECOVER_MANA_MIN := 40
const RECOVER_MANA_MAX := 60
# 회복 턴에 체력까지 함께 회복할 확률과 그 폭(최대 체력 대비)
const RECOVER_HP_CHANCE := 0.3
const RECOVER_HP_FRACTION_MIN := 0.05
const RECOVER_HP_FRACTION_MAX := 0.10

var mana: int = MANA_MAX

# 화면에 보여줄 이름. 같은 종류가 여러 마리면 "오크 2"처럼 번호를 붙여 구분한다 —
# 여러 마리가 각자 공격/피격 메시지를 띄우는데 전부 "오크"면 누가 뭘 했는지 읽을 수 없다.
# 번호를 붙일지는 그룹 전체를 봐야 정해지므로 생성자가 아니라 매니저가 채운다
var display_name: String = ""

# 처치 보상을 이미 지급했는지. 승리 처리에서 마리별로 한 번씩만 주기 위한 표식
var rewarded: bool = false


func _init(index_: int, monster_type_: String, variant_: Dictionary) -> void:
	index = index_
	monster_type = monster_type_
	monster_data = BattleData.MONSTERS[monster_type_]
	variant = variant_
	max_hp = monster_data["max_hp"]
	hp = max_hp
	resistance = EnemyResistance.new()
	status = StatusEffects.new()
	display_name = monster_data["name"]


func is_alive() -> bool:
	return hp > 0


# 피해를 적용하고 "실제로 깎인 양"을 반환한다. 남은 체력보다 큰 피해가 들어와도 0에서 멈추므로,
# 반환값은 항상 화면에 띄울 숫자(팝업)와 HP바 감소폭에 정확히 일치한다 — 오버킬일 때 카드 수치를
# 그대로 보여주면 "24 피해!"라고 쓰고 HP는 9만 줄어드는 어긋남이 생긴다
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := hp
	hp = max(0, hp - amount)
	return before - hp


# 체력을 회복하고 실제로 회복된 양을 반환 (최대치에서 멈춘다).
# take_damage와 같은 이유로 "실제 변화량"을 돌려준다 — 화면에 띄울 숫자와 HP바 변화가 어긋나지 않게
func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := hp
	hp = min(max_hp, hp + amount)
	return hp - before


# ── 마나 (공격/회복 판단) ──────────────────────────────────────────────────

# 이번 턴에 공격할 수 있는지. 마나가 모자라면 공격 대신 회복 턴이 된다
func can_attack() -> bool:
	return mana >= LOW_MANA_THRESHOLD


# 공격 비용을 치르고 실제 소모량을 반환 (0 밑으로는 내려가지 않는다)
func spend_attack_mana() -> int:
	var cost := randi_range(ATTACK_COST_MIN, ATTACK_COST_MAX)
	var before := mana
	mana = max(0, mana - cost)
	return before - mana


# 마나를 빼앗기고 실제로 빠진 양을 반환 (가진 것보다 많이 뺏기지 않는다).
# take_damage/heal과 같은 규약 — "실제 변화량"을 돌려줘, 훔친 쪽이 그 값만큼만 얻게 한다.
# 이 마나는 연출용 자원이지만 공격/회복 판단(can_attack)에 그대로 쓰이므로, 빼앗기면 그 몬스터가
# 숨고르기 턴으로 밀려난다 — 마력흡수가 피해 말고도 적 템포를 끊는 카드가 되는 지점
func drain_mana(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := mana
	mana = max(0, mana - amount)
	return before - mana


# 회복 턴 처리: 마나를 회복하고, 확률에 걸리면 체력도 조금 회복한다.
# 실제로 회복된 양을 {"mana": int, "hp": int}로 돌려줘 호출부가 그대로 화면에 쓸 수 있게 한다
# (hp가 0이면 이번 회복엔 체력이 안 붙은 것)
func recover() -> Dictionary:
	var mana_before := mana
	mana = min(MANA_MAX, mana + randi_range(RECOVER_MANA_MIN, RECOVER_MANA_MAX))

	var healed := 0
	if randf() < RECOVER_HP_CHANCE:
		var fraction := randf_range(RECOVER_HP_FRACTION_MIN, RECOVER_HP_FRACTION_MAX)
		healed = heal(int(round(max_hp * fraction)))

	return {"mana": mana - mana_before, "hp": healed}
