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
