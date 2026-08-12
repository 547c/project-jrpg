class_name Card
extends Resource

# 전투 카드 한 장의 정의 (docs 전투 재설계 v2 스펙 기준).
# Resource를 상속하므로 카드마다 .tres 파일 하나로 따로 저장/편집할 수 있고,
# 새 카드를 추가할 때 코드를 고칠 필요 없이 battle/cards/ 아래에 .tres만 늘리면 된다.
#
# 이 파일은 "카드가 무엇인지"만 기술한다 — 드로우/사용/과열 게이지 같은 전투 로직과
# 카드 UI는 아직 만들지 않았고, 이 데이터를 읽어가는 쪽에서 다루게 된다.


# 카드 색깔. 장착 무기와의 궁합을 결정한다 (스펙 3항)
# - PHYSICAL(🔴): 검을 장착했을 때 위력이 극대화된다. 마나를 쓰지 않는다
# - MAGIC(🔵): 지팡이를 장착했을 때 위력이 극대화된다. 사용 시 마나를 소모한다
# - NEUTRAL(🟢): 무기 상태와 무관 (회복/방어/회피 — 턴당 공격 횟수를 자연스럽게 제한하는 역할)
# (Godot 내장 Color 타입과 이름이 겹치지 않도록 CardColor로 둔다)
enum CardColor { PHYSICAL, MAGIC, NEUTRAL }

# 카드가 실제로 일으키는 효과의 종류. value의 의미가 이 값에 따라 달라진다
enum EffectType {
	DAMAGE,        # 적에게 피해
	HEAL_HP,       # 체력 회복
	RESTORE_MANA,  # 마나 회복
	DEFEND,        # 다음 피격 시 받는 피해 감소
	DODGE,         # 회피 (성공/실패라 수치가 필요 없음)
}

# 화면에 표시할 카드 이름
@export var card_name: String = ""

# 카드 색깔. 바뀌면 마나 소모량 항목의 표시 여부가 달라지므로 인스펙터를 갱신시킨다
@export var color: CardColor = CardColor.PHYSICAL:
	set(value_):
		color = value_
		notify_property_list_changed()

# 효과 종류 (value의 의미를 결정)
@export var effect: EffectType = EffectType.DAMAGE

# 효과의 크기. effect에 따라 해석이 달라진다:
# DAMAGE=피해량 / HEAL_HP=회복할 체력 / RESTORE_MANA=회복할 마나 /
# DEFEND=감소시킬 피해량 / DODGE=사용하지 않음(0)
@export var value: int = 0

# 사용 시 소모할 마나. 스펙상 마법 카드에만 해당하며, 물리/공용 카드는 마나와 무관하다.
# 직접 읽지 말고 get_mana_cost()를 쓰면 색깔에 관계없이 항상 올바른 값이 나온다
@export var mana_cost: int = 0


# 마법 카드일 때만 인스펙터에 마나 소모량을 노출한다 (물리/공용 카드에서 실수로 값을 넣는 것을 방지)
func _validate_property(property: Dictionary) -> void:
	if property.name == "mana_cost" and color != CardColor.MAGIC:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func is_magic() -> bool:
	return color == CardColor.MAGIC


# 이 카드를 쓰는 데 실제로 필요한 마나. 마법 카드가 아니면 저장된 값과 무관하게 항상 0
func get_mana_cost() -> int:
	return mana_cost if is_magic() else 0


# 무기 상태의 영향을 받는 카드인지 (물리/마법 카드는 받고, 공용 카드는 받지 않는다).
# 과열 게이지가 차오르는 대상인지를 판단할 때도 같은 기준을 쓴다
func uses_weapon() -> bool:
	return color != CardColor.NEUTRAL
