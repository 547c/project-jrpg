class_name EnemyResistance
extends RefCounted

# 적의 "저항 패턴" 상태 (전투 재설계 스펙 4-1항). 매 턴 시작마다 물리 저항 또는 마법 저항 중
# 하나가 무작위로 활성화되거나, 아무 저항도 없는 상태(NONE)가 된다. Card(battle/card.gd)의
# CardColor(PHYSICAL/MAGIC/NEUTRAL) 개념을 그대로 재사용해 "카드 색깔과 저항이 일치하는가"를 판정한다.
#
# 판정 로직은 roll_new_turn() 한 곳에 몰아뒀다. 확률 자체(resistance_chance/physical_share)는
# 인스턴스 변수라 몹 종류별로 값만 다르게 줘서 손쉽게 조절할 수 있고, 그걸로 부족한 특수 패턴이
# 필요하면(예: 보스가 특정 턴에 저항을 확정 예고하는 등) EnemyResistance를 상속해
# roll_new_turn() 자체를 오버라이드하면 된다 — 이 클래스를 쓰는 쪽은 항상 roll_new_turn()과
# current만 보면 되므로, 오버라이드해도 호출부 코드를 바꿀 필요가 없다.

enum ResistanceType { NONE, PHYSICAL, MAGIC }

# 카드 색깔이 현재 저항과 일치할 때 데미지에 곱해지는 배율. 이름 붙은 상수로 빼서 나중에 조정하기 쉽게 함
const RESIST_DAMAGE_MULTIPLIER := 0.5

# 매 턴 저항이 "활성화될" 전체 확률(기본 30%)과, 활성화됐을 때 PHYSICAL로 갈릴 비율(기본 50%,
# 나머지는 MAGIC). 인스턴스 변수이므로 몹마다 생성 시 값만 바꿔주면 서브클래싱 없이도 확률을 조절할 수 있다
var resistance_chance: float = 0.3
var physical_share: float = 0.5

var current: ResistanceType = ResistanceType.NONE


# 새 턴 시작 시 저항 상태를 다시 굴린다. 판정 로직의 유일한 진입점이라, 몹별 특수 패턴이
# 필요하면 이 함수 자체를 오버라이드하면 된다 (resistance_chance/physical_share만으로 부족할 때)
func roll_new_turn() -> void:
	if randf() >= resistance_chance:
		current = ResistanceType.NONE
		return
	current = ResistanceType.PHYSICAL if randf() < physical_share else ResistanceType.MAGIC


# card_color가 현재 저항과 일치하는지. NEUTRAL은 어떤 저항과도 일치하지 않는다(항상 false) —
# "저항과 무관한 카드는 배율 없음"이 이 한 줄로 자연스럽게 보장된다
func resists(card_color: Card.CardColor) -> bool:
	match card_color:
		Card.CardColor.PHYSICAL:
			return current == ResistanceType.PHYSICAL
		Card.CardColor.MAGIC:
			return current == ResistanceType.MAGIC
		_:
			return false


# card로 raw_damage를 입힐 때 실제로 적용될 데미지를 계산한다. card.color가 현재 저항과
# 일치하면 RESIST_DAMAGE_MULTIPLIER를 곱해 반올림한 값을, 아니면(무저항 카드/저항 없음/색깔
# 불일치) raw_damage를 그대로 반환한다. raw_damage를 인자로 받는 이유는 이 함수가 card.value를
# 직접 가정하지 않게 해서, 나중에 무기 보너스 등 다른 배율이 먼저 적용된 값도 그대로 넘길 수 있게 하기 위함
# resist_reduction_percent는 이 몬스터에게 걸린 "저항 약화" 디버프(StatusEffects.Kind.RESIST_DOWN)의
# 세기다. 저항 자체를 끄는 게 아니라 감쇄 폭을 완화한다:
#   원래 감쇄 = 1 - RESIST_DAMAGE_MULTIPLIER (기본 50%)
#   실제 감쇄 = 원래 감쇄 * (1 - 약화율)
# 예) 기본 50% 감쇄에 저항 약화 50%가 걸리면 감쇄가 25%로 줄어 배율이 0.75가 된다.
# 이 방식이면 약화율 100%에서 감쇄가 0(=저항 무시)이 되어 상한이 자연스럽게 맞고,
# 저항 배율 상수를 나중에 바꿔도 "약화율의 의미"가 그대로 유지된다
func calculate_damage(card: Card, raw_damage: int, resist_reduction_percent: int = 0) -> int:
	if not resists(card.color):
		return raw_damage

	var base_cut := 1.0 - RESIST_DAMAGE_MULTIPLIER
	var weakened := clampf(resist_reduction_percent / 100.0, 0.0, 1.0)
	var multiplier := 1.0 - base_cut * (1.0 - weakened)
	return int(round(raw_damage * multiplier))
