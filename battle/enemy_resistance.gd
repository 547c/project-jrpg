class_name EnemyResistance
extends RefCounted

# 몬스터 한 마리의 "적응" 상태. 예전에는 매 턴 30% 확률로 물리/마법 저항이 무작위로 켜졌지만,
# 그건 플레이어가 통제할 수 없는 주사위라 대응이 아니라 운으로 갈렸다. 지금은 전적으로 플레이어가
# 때린 순서가 만들어낸다:
#
#   같은 속성으로 연속 HITS_TO_ADAPT번 맞으면 그 속성에 적응해 피해를 RESIST_DAMAGE_MULTIPLIER배로 줄인다.
#   반대 속성으로 한 번 맞으면 적응이 깨지고 그 속성으로 연속 카운트가 새로 시작된다.
#   공용(NEUTRAL) 카드는 적응에 관여하지 않는다 (쌓지도, 깨지도 않는다).
#
# 한 번 맞은 시점부터 pending_type()이 "다음에 같은 걸로 때리면 적응한다"를 알려주므로, UI가 예고
# 아이콘을 띄워 플레이어가 미리 무기를 바꿔 피할 수 있다 — 즉 이 시스템은 피해를 막는 장치가 아니라
# "한 무기만 계속 쓰지 말라"는 압박이다.

enum ResistanceType { NONE, PHYSICAL, MAGIC }

# 적응한 속성으로 맞을 때 데미지에 곱해지는 배율
static var RESIST_DAMAGE_MULTIPLIER := 0.5

# 같은 속성 연속 몇 번에 적응하는지
static var HITS_TO_ADAPT := 2

# 적응이 저절로 풀리기까지의 라운드 수. 반대 속성으로 때리면 즉시 풀리지만, 마나가 바닥나 한 속성밖에
# 못 쓰는 상황에서 적응이 영원히 유지되면 그 판은 반감 피해로 끝없이 늘어진다 (시뮬레이션에서 교착의
# 주원인이었다). 풀린 뒤 다시 두 번 맞으면 또 적응하므로 "같은 속성만 쓰면 손해"라는 압박은 그대로다
static var ADAPT_ROUNDS := 2

var current: ResistanceType = ResistanceType.NONE

# 지금 연속으로 맞고 있는 속성과 그 횟수 (적응 예고의 근거)
var streak_type: ResistanceType = ResistanceType.NONE
var streak_count: int = 0
var rounds_left: int = 0


static func type_for_color(card_color: Card.CardColor) -> ResistanceType:
	match card_color:
		Card.CardColor.PHYSICAL:
			return ResistanceType.PHYSICAL
		Card.CardColor.MAGIC:
			return ResistanceType.MAGIC
		_:
			return ResistanceType.NONE


# 피해를 입은 직후 호출한다. 무엇이 바뀌었는지를 {"adapted": bool, "broken": bool}로 돌려줘
# 호출부가 "적응했다" / "적응이 깨졌다" 메시지를 띄울 수 있게 한다
func register_hit(card_color: Card.CardColor) -> Dictionary:
	var hit_type := type_for_color(card_color)
	if hit_type == ResistanceType.NONE:
		return {"adapted": false, "broken": false}

	var broken := false
	if current != ResistanceType.NONE and current != hit_type:
		current = ResistanceType.NONE
		broken = true

	if streak_type == hit_type:
		streak_count += 1
	else:
		streak_type = hit_type
		streak_count = 1

	var adapted := false
	if streak_count >= HITS_TO_ADAPT and current != hit_type:
		current = hit_type
		rounds_left = ADAPT_ROUNDS
		adapted = true

	return {"adapted": adapted, "broken": broken}


# 라운드가 끝날 때 한 번 호출된다. 지속시간이 다 된 적응은 풀리고 연속 카운트도 처음부터 다시 센다.
# 풀렸으면 true를 돌려줘 호출부가 "적응이 풀렸다"를 알릴 수 있게 한다
func tick_round() -> bool:
	if current == ResistanceType.NONE:
		return false
	rounds_left -= 1
	if rounds_left > 0:
		return false
	current = ResistanceType.NONE
	streak_type = ResistanceType.NONE
	streak_count = 0
	return true


# 아직 적응하진 않았지만 "한 번 더 같은 걸로 맞으면 적응할" 속성 (없으면 NONE).
# UI는 이 값으로 흐린 예고 아이콘을 띄운다
func pending_type() -> ResistanceType:
	if current != ResistanceType.NONE:
		return ResistanceType.NONE
	if streak_type == ResistanceType.NONE:
		return ResistanceType.NONE
	if streak_count < HITS_TO_ADAPT - 1:
		return ResistanceType.NONE
	return streak_type


# card_color가 현재 적응과 일치하는지. NEUTRAL은 어떤 적응과도 일치하지 않는다
func resists(card_color: Card.CardColor) -> bool:
	var hit_type := type_for_color(card_color)
	return hit_type != ResistanceType.NONE and current == hit_type


# card로 raw_damage를 입힐 때 실제로 적용될 데미지. 적응한 속성이면 감쇄가 걸리고, 그 감쇄 폭은
# "저항 약화"(StatusEffects.Kind.RESIST_DOWN) 디버프만큼 완화된다:
#   원래 감쇄 = 1 - RESIST_DAMAGE_MULTIPLIER, 실제 감쇄 = 원래 감쇄 * (1 - 약화율)
func calculate_damage(card: Card, raw_damage: int, resist_reduction_percent: int = 0) -> int:
	if not resists(card.color):
		return raw_damage

	var base_cut := 1.0 - RESIST_DAMAGE_MULTIPLIER
	var weakened := clampf(resist_reduction_percent / 100.0, 0.0, 1.0)
	var multiplier := 1.0 - base_cut * (1.0 - weakened)
	return int(round(raw_damage * multiplier))
