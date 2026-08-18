class_name Card
extends Resource

# 전투 카드 한 장의 정의 (docs 전투 재설계 v2 스펙 기준).
# Resource를 상속하므로 카드마다 .tres 파일 하나로 따로 저장/편집할 수 있고,
# 새 카드를 추가할 때 코드를 고칠 필요 없이 battle/cards/ 아래에 .tres만 늘리면 된다.
#
# 이 파일은 "카드가 무엇인지"만 기술한다 — 드로우/사용/과열 게이지 같은 전투 로직과
# 카드 UI는 아직 만들지 않았고, 이 데이터를 읽어가는 쪽에서 다루게 된다.


# 카드 색깔. 장착 무기와의 궁합을 결정한다 (스펙 3항)
# - PHYSICAL(🔴): 검을 장착했을 때 위력이 극대화된다
# - MAGIC(🔵): 지팡이를 장착했을 때 위력이 극대화된다
# - NEUTRAL(🟢): 무기 상태와 무관 (회복/방어/회피 — 턴당 공격 횟수를 자연스럽게 제한하는 역할)
# (Godot 내장 Color 타입과 이름이 겹치지 않도록 CardColor로 둔다)
#
# [비용과 색깔은 분리돼 있다] 처음에는 "마나는 마법 카드만 쓴다"는 규칙이었지만, 지금은 공용 카드도
# 마나/체력을 비용으로 낼 수 있다 — 색깔은 무기 궁합만 정하고, 비용은 mana_cost/hp_cost가 따로 정한다
enum CardColor { PHYSICAL, MAGIC, NEUTRAL }

# 카드 등급. 높을수록 강한 대신 덱에서 덜 자주 뽑히게 할 용도다.
# 실제 뽑기 확률 가중치는 카드가 아니라 Deck이 갖고 있다(Deck.TIER_DRAW_WEIGHT) — 이 파일은
# "카드가 무엇인지"만 기술하고 뽑기 규칙은 뽑는 쪽이 소유한다는 기존 역할 분담을 그대로 따른다.
# 지금은 모든 카드가 TIER_1이고, 티어2/3 카드 콘텐츠와 티어별 시각 연출은 아직 없다
enum CardTier { TIER_1, TIER_2, TIER_3 }

# 카드가 실제로 일으키는 효과의 종류. value의 의미가 이 값에 따라 달라진다.
# [주의] 이미 저장된 .tres들이 이 순서를 정수로 들고 있으므로, 새 값은 반드시 끝에만 추가할 것 —
# 중간에 끼워 넣으면 기존 카드들의 효과가 통째로 밀려서 다른 효과로 바뀐다
enum EffectType {
	DAMAGE,        # 적에게 피해
	HEAL_HP,       # 체력 회복
	RESTORE_MANA,  # 마나 회복
	DEFEND,        # 다음 피격 시 받는 피해 감소
	DODGE,         # 회피 (성공/실패라 수치가 필요 없음)
	COUNTER,       # 다음 적 공격을 완전 무효화하고, 그 즉시 적에게 value만큼 반격
	RESTORE_BOTH,  # 체력과 마나를 동시에 회복 (체력=value, 마나=secondary_value)
	# 아래 둘은 버프/디버프 계열 — value=퍼센트, secondary_value=지속 라운드로 읽는다
	# (effect마다 value의 의미가 달라지는 기존 규칙을 그대로 따른 것)
	BUFF_ATTACK_SELF,    # 자신의 주는 피해 증가 (대상 불필요)
	DEBUFF_ATTACK_ENEMY, # 대상 몬스터의 주는 피해 감소
	# 여러 상태이상을 한꺼번에 거는 카드. 무엇을 얼마나 거는지는 status_package가 가리키는
	# StatusEffects.PACKAGES 항목에 있고, 지속 라운드만 secondary_value로 정한다
	STATUS_PACKAGE,
	# 다음에 내는 카드 1장의 마나/체력 비용을 0으로 만든다 (이번 턴 한정, 1회성).
	# 수치가 필요 없어 value/secondary_value를 쓰지 않는다 — "얼마나"가 아니라 "한 장"이 전부다
	FREE_NEXT_CARD,
}

# 화면에 표시할 카드 이름
@export var card_name: String = ""

@export var color: CardColor = CardColor.PHYSICAL

# 카드 등급. 기존 카드 .tres들은 이 값을 저장하고 있지 않아 전부 기본값(TIER_1)으로 읽힌다
@export var tier: CardTier = CardTier.TIER_1

# 효과 종류 (value의 의미를 결정)
@export var effect: EffectType = EffectType.DAMAGE

# 효과의 크기. effect에 따라 해석이 달라진다:
# DAMAGE=피해량 / HEAL_HP=회복할 체력 / RESTORE_MANA=회복할 마나 /
# DEFEND=감소시킬 피해량 / DODGE=사용하지 않음(0) / COUNTER=반격 피해량 /
# RESTORE_BOTH=회복할 체력 /
# BUFF_ATTACK_SELF·DEBUFF_ATTACK_ENEMY=효과 크기(퍼센트, 20이면 20%)
@export var value: int = 0

# value 하나로는 모자란 효과에서 쓰는 두 번째 수치.
# RESTORE_BOTH=회복할 마나 / 버프·디버프 계열=지속 라운드 수.
# 그 외 효과에서는 읽지 않는다.
# (효과 목록을 배열로 바꿔 "여러 효과를 가진 카드"를 일반적으로 표현하는 방법도 있었지만, 그건
#  카드 한 장 = 효과 하나라는 기존 구조와 그걸 전제로 쓰인 UI/연출 분기를 전부 갈아엎어야 한다.
#  두 자원을 같이 회복하는 카드 하나 때문에 그러기보다, value의 의미가 effect마다 다르다는 기존
#  규칙을 그대로 한 칸 늘리는 쪽이 변경 범위가 훨씬 작다)
@export var secondary_value: int = 0

# 카드의 짧은 분위기 문구. 효과 설명("마법 피해 6")은 수치에서 자동으로 만들어지지만,
# 이건 손으로 쓴 문장이라 자동 생성과 섞이지 않게 별도 필드로 둔다
@export_multiline var flavor_text: String = ""

# 사용 시 소모할 마나. 색깔과 무관하게 어떤 카드든 가질 수 있다
# (예: 공용 카드인 방어/피하기도 마나를 쓴다)
@export var mana_cost: int = 0

# 사용 시 양쪽 무기 과열 게이지를 이 값으로 "즉시 세팅"하는 페널티 (0이면 아무 일도 없음).
# register_card_use()의 기존 ±25 누적과는 완전히 다른 경로다 — 누적이 아니라 강제 대입이라,
# "강력한 대신 무기가 확 달아오르는" 카드를 데이터만으로 만들 수 있다 (불사조의 축복 = 75).
#
# [주의] 0을 "효과 없음"으로 쓰기 때문에 이 필드로는 "양쪽 게이지를 0으로 식히는" 카드를 표현할 수
# 없다. 그런 카드가 필요해지면 별도 필드(예: on_use_cool_gauge)를 두거나 이 필드를 -1 기본값으로
# 바꿔야 한다 — 지금은 페널티 쪽만 필요해서 단순한 규칙을 택했다
@export_range(0, 100) var on_use_set_gauge: int = 0

# 회복 수치가 이 값 이상이면 "완전 회복"으로 간주해 설명문에 숫자 대신 그렇게 쓴다.
# (회복은 최대치에서 clamp되므로, 최대치보다 확실히 큰 값을 넣는 게 곧 완전 회복이다)
const FULL_RESTORE_VALUE := 999

# effect가 DAMAGE일 때 그 위에 얹히는 부가 성질의 이름 (DamageTraits.TRAITS의 키. 빈 값이면 순수 피해).
# 흡혈/처형처럼 "때리는 건 같고 한 가지 규칙만 더 붙는" 카드를 위한 것이며, 수치는 전부 그 표에 있다.
# 왜 이런 카드들에 새 EffectType을 주지 않았는지는 damage_traits.gd 첫머리 주석 참고
@export var damage_trait: String = ""

# 이 카드가 쓸 아이콘의 이름 (CardLibrary.CARD_ICON_REGION의 키. 비워두면 효과별 기본 아이콘).
# 아이콘은 원래 효과 종류로만 갈렸는데, 같은 DAMAGE라도 흡혈과 처형은 손패에서 서로 구분돼야 해서
# 카드가 직접 고를 수 있게 열어뒀다. 실제 시트 좌표는 카탈로그(CardLibrary)에 있고 여기엔 이름만 둔다
@export var icon_key: String = ""

# effect가 STATUS_PACKAGE일 때 적용할 묶음의 이름 (StatusEffects.PACKAGES의 키).
# 수치는 그 표에 있고 여기서는 어느 묶음인지만 가리킨다 — 카드 이름 대신 별도 필드를 쓰는 이유는
# CardLibrary가 카드 id를 따로 두는 것과 같다: 표시용 이름을 키로 삼으면 이름을 다듬는 순간 깨진다
@export var status_package: String = ""

# 광역기 여부. true면 대상 하나가 아니라 "살아있는 몬스터 전원"에게 같은 효과가 적용된다.
#
# 효과 종류(EffectType)와 독립된 축이라 별도 필드로 뒀다 — 지금은 피해 카드 둘(익스플로전/시공균열)만
# 쓰지만, 나중에 디버프/버프 효과 타입이 생기면 그 카드도 이 필드 하나만 켜면 광역판이 된다.
# 적용을 반복하는 쪽(BattleTurnManager)이 효과 종류를 모른 채 "대상 목록"만 돌리도록 짜여 있어서,
# 새 효과 타입을 추가할 때 광역 처리를 다시 만들 필요가 없다.
#
# 대상이 전원으로 고정되므로 광역기는 타겟 선택 UI를 띄우지 않는다 (battle_scene._needs_target)
@export var is_aoe: bool = false

# 사용 시 소모할 체력. 마나 대신 체력을 대가로 치르는 카드(예: 마나 회복)에 쓴다.
# 체력이 이 값 이하면 카드 자체를 낼 수 없다 — 카드를 쓰다가 죽는 일은 없다
# (판정은 BattleTurnManager.can_play_card가 담당)
@export var hp_cost: int = 0


# 효과 종류와 수치로 카드 설명문을 자동으로 만든다 ("물리 피해 4", "체력 6 회복" 등).
# 전투 손패의 카드 설명칸과 스펠북 컬렉션 목록이 같은 문장을 써야 하므로, 어느 한쪽 UI가 아니라
# 카드 자신이 들고 있게 뒀다 — 새 EffectType을 추가할 때 고칠 자리도 여기 하나로 줄어든다.
#
# 마나/체력 비용은 일부러 넣지 않는다. 전투 카드에서는 모서리 마름모 배지가, 스펠북에서는 별도
# 비용 줄이 따로 보여주므로 여기까지 넣으면 같은 수치가 두 번 나온다
func get_effect_description() -> String:
	var text := _effect_text()
	# 광역기는 효과 종류와 상관없이 같은 꼬리표를 붙인다 — 나중에 디버프 광역 카드가 생겨도
	# 여기 한 곳만 지나가므로 표기가 저절로 일관된다
	if is_aoe and text != "":
		return "%s (광역)" % text
	return text


func _effect_text() -> String:
	match effect:
		EffectType.DAMAGE:
			var kind := "마법" if color == CardColor.MAGIC else "물리"
			var base := "%s 피해 %d" % [kind, value]
			# 부가 성질이 붙은 카드는 그 규칙까지 적어야 카드만 보고 판단할 수 있다
			var trait_text := DamageTraits.describe(damage_trait)
			if trait_text != "":
				return "%s + %s" % [base, trait_text]
			return base
		EffectType.HEAL_HP:
			return "체력 %d 회복" % value
		EffectType.RESTORE_MANA:
			return "마나 %d 회복" % value
		EffectType.DEFEND:
			return "다음 피해 %d 감소" % value
		EffectType.DODGE:
			return "이번 턴 완전 회피"
		EffectType.COUNTER:
			return "피해 무효 + 반격 %d" % value
		EffectType.BUFF_ATTACK_SELF:
			return "공격력 +%d%% (%d라운드)" % [value, secondary_value]
		EffectType.DEBUFF_ATTACK_ENEMY:
			return "대상 공격력 -%d%% (%d라운드)" % [value, secondary_value]
		EffectType.FREE_NEXT_CARD:
			return "다음 카드 1장 코스트 0"
		EffectType.STATUS_PACKAGE:
			var summary := StatusEffects.describe_package(status_package)
			if summary == "":
				return ""
			return "%s (%d라운드)" % [summary, secondary_value]
		EffectType.RESTORE_BOTH:
			# "완전 회복" 카드는 최대치보다 확실히 큰 값을 넣고 clamp에 맡기는데(불사조의 축복=999),
			# 그 숫자를 그대로 보여주면 "체력 999 회복"이라는 이상한 문구가 나온다 — 임계값을 넘으면
			# 수치 대신 완전 회복이라고 쓴다
			if value >= FULL_RESTORE_VALUE and secondary_value >= FULL_RESTORE_VALUE:
				return "체력·마나 완전 회복"
			return "체력 %d, 마나 %d 회복" % [value, secondary_value]
		_:
			return ""


# 화면에 보여줄 티어 이름 ("티어 1" 등). 저장값이 0부터라 +1 해서 사람이 읽는 번호로 바꾼다
func get_tier_label() -> String:
	return "티어 %d" % (int(tier) + 1)


func is_magic() -> bool:
	return color == CardColor.MAGIC


# 이 카드를 쓰는 데 실제로 필요한 마나
func get_mana_cost() -> int:
	return mana_cost


# 이 카드를 쓰는 데 실제로 필요한 체력
func get_hp_cost() -> int:
	return hp_cost


# 무기 상태의 영향을 받는 카드인지 (물리/마법 카드는 받고, 공용 카드는 받지 않는다).
# 과열 게이지가 차오르는 대상인지를 판단할 때도 같은 기준을 쓴다
func uses_weapon() -> bool:
	return color != CardColor.NEUTRAL
