class_name DamageTraits
extends RefCounted

# 피해 카드에 얹히는 "부가 성질"의 표. 카드는 damage_trait에 이 표의 키만 적고, 수치는 전부 여기 있다.
#
# [왜 새 EffectType이 아니라 별도 축인가]
# 마력흡수/처형/흡혈/도박의 일격은 넷 다 "적을 때린다"는 점에서 기존 DAMAGE와 똑같고, 다른 건
# 그 위에 얹히는 한 가지 규칙뿐이다. 그래서 EffectType을 넷 더 만드는 방법은 비용이 크다:
# EffectType은 이 게임에서 타겟팅 필요 여부(_targets_an_enemy), 카드 프레임 색(_card_style_key),
# VFX 키(_vfx_key_for_card), 연출 분기(_animate_card), 아이콘, 설명문이 전부 갈라지는 축이라,
# 값을 하나 늘릴 때마다 그 여섯 곳에 "이것도 피해 카드입니다"를 다시 적어줘야 한다. 네 번 반복하면
# 같은 문장이 스물네 군데 생기고, 한 곳만 빠뜨려도 카드가 조용히 회색 프레임으로 나온다.
#
# effect는 DAMAGE 그대로 두고 성질만 옆에 달면 위의 여섯 갈래가 전부 기존 경로를 그대로 탄다 —
# 타겟팅도, 광역(is_aoe)도, 오버킬 안전장치도, 마리별 피해 팝업도 새로 만들 필요가 없다.
#
# [StatusEffects.PACKAGES와 같은 형태인 이유] 앞서 "여러 상태이상을 거는 카드"를 묶음 표로 뺀 것과
# 정확히 같은 문제(카드 한 장에 담기지 않는 여분의 수치)라, 같은 해법을 썼다. 새 성질을 추가할 때
# 수치만 다른 변형이면 이 표에 한 줄, 규칙 자체가 새로우면 표 한 줄 + 아래 두 훅 중 하나에 분기 하나다.
#
# [훅이 둘로 나뉜 이유 — 무작위와 결정적인 것을 섞지 않는다]
#  - conditional_multiplier(): 대상의 상태만 보고 정해지는 배율. 무작위가 없어 몇 번 불러도 같은 값이라,
#    피해 계산 함수(calculate_card_damage) 안에서 대상마다 그때그때 구해도 안전하다.
#  - roll_random_multiplier(): 주사위를 굴리는 배율. 대상과 무관하므로 카드 한 번 사용당 딱 한 번만
#    굴려서 재사용한다 — 피해 계산 안에서 굴리면 나중에 도박 카드에 is_aoe를 켜는 순간 마리마다
#    따로 굴려져서 "한 번의 도박"이라는 카드 설명과 어긋난다.
const TRAITS: Dictionary = {
	# 마력흡수: 대상의 (연출용) 마나를 빼앗아 플레이어 마나로 옮긴다.
	# 대상이 가진 것보다 많이 훔칠 수 없고, 플레이어 최대치를 넘는 분은 버려진다 (양쪽 다 적용부에서 clamp)
	"drain_mana": {
		"steal_mana": 4,
	},
	# 흡혈: "실제로 들어간" 피해의 비율만큼 체력을 회복한다. 카드 수치가 아니라 실제 피해를 기준으로
	# 삼는 건 기존 오버킬 규칙과 같은 이유다 — 남은 체력 2인 적을 8로 때리고 4를 회복하면
	# 화면에 보이는 숫자(2)와 회복량이 어긋난다
	"drain_hp": {
		"leech_percent": 50,
	},
	# 처형: 대상 체력이 최대치의 일정 비율 이하로 떨어져 있으면 최종 피해에 배율이 붙는다
	"execute": {
		"hp_threshold_percent": 30,
		"multiplier": 2.0,
	},
	# 도박의 일격: 확률에 걸리면 배율, 빗나가면 0배(완전 실패).
	# whiff_text가 있으면 피해가 0으로 끝났을 때 연출이 "0 피해" 대신 이 문구를 쓴다
	"gamble": {
		"chance_percent": 50,
		"multiplier": 3.0,
		"whiff_text": "빗나갔다!",
	},
}


static func get_trait(trait_id: String) -> Dictionary:
	return TRAITS.get(trait_id, {})


static func has_trait(trait_id: String) -> bool:
	return TRAITS.has(trait_id)


# 대상의 상태만으로 결정되는 배율 (처형). 무작위가 없어 여러 번 불러도 같은 값이 나온다.
# 해당 성질이 없는 카드는 1.0이라 호출부가 "성질이 있는지"를 따로 분기하지 않아도 된다
static func conditional_multiplier(trait_id: String, target_hp: int, target_max_hp: int) -> float:
	var trait_data := get_trait(trait_id)
	if not trait_data.has("hp_threshold_percent") or target_max_hp <= 0:
		return 1.0
	var threshold: float = target_max_hp * int(trait_data["hp_threshold_percent"]) / 100.0
	if float(target_hp) <= threshold:
		return float(trait_data["multiplier"])
	return 1.0


# 주사위를 굴려 나오는 배율 (도박의 일격). 카드 한 번 사용당 한 번만 부를 것.
# 성공하면 multiplier, 실패하면 0.0(피해 없음), 해당 성질이 없으면 1.0
static func roll_random_multiplier(trait_id: String) -> float:
	var trait_data := get_trait(trait_id)
	if not trait_data.has("chance_percent"):
		return 1.0
	if randi_range(1, 100) <= int(trait_data["chance_percent"]):
		return float(trait_data["multiplier"])
	return 0.0


# 훔칠 마나의 양 (해당 성질이 없으면 0). 실제로 몇 점이 오갔는지는 대상/플레이어 양쪽 한계에
# 걸리므로 적용부가 정한다 — 여기서는 카드가 약속한 값만 알려준다
static func steal_mana_amount(trait_id: String) -> int:
	return int(get_trait(trait_id).get("steal_mana", 0))


# 실제 피해 dealt에서 회복할 체력 (해당 성질이 없으면 0)
static func leech_amount(trait_id: String, dealt: int) -> int:
	var percent: int = int(get_trait(trait_id).get("leech_percent", 0))
	if percent <= 0 or dealt <= 0:
		return 0
	return int(round(dealt * percent / 100.0))


# 피해가 0으로 끝났을 때 "0 피해!" 대신 쓸 문구 (없으면 빈 문자열)
static func get_whiff_text(trait_id: String) -> String:
	var text := String(get_trait(trait_id).get("whiff_text", ""))
	return TranslationServer.translate(text) if text != "" else ""


# 카드 설명문에 덧붙일 한 줄 ("마나 4 흡수" 등). 표에 든 수치에서 만들어지므로
# 수치를 고치면 설명문도 저절로 따라간다 (StatusEffects.describe_package와 같은 방식)
static func describe(trait_id: String) -> String:
	var trait_data := get_trait(trait_id)
	if trait_data.is_empty():
		return ""

	var parts: Array[String] = []
	if trait_data.has("steal_mana"):
		parts.append(TranslationServer.translate("마나 %d 흡수") % int(trait_data["steal_mana"]))
	if trait_data.has("leech_percent"):
		parts.append(TranslationServer.translate("피해의 %d%% 흡혈") % int(trait_data["leech_percent"]))
	if trait_data.has("hp_threshold_percent"):
		parts.append(TranslationServer.translate("체력 %d%% 이하면 %s배") % [
			int(trait_data["hp_threshold_percent"]), _multiplier_text(trait_data)])
	if trait_data.has("chance_percent"):
		parts.append(TranslationServer.translate("%d%% 확률로 %s배 / 실패 시 0") % [
			int(trait_data["chance_percent"]), _multiplier_text(trait_data)])
	return ", ".join(parts)


# 배율을 사람이 읽는 숫자로 (2.0 -> "2", 1.5 -> "1.5"). 정수 배율에 ".0"이 붙어 보이지 않게
static func _multiplier_text(trait_data: Dictionary) -> String:
	var multiplier: float = float(trait_data.get("multiplier", 1.0))
	if is_equal_approx(multiplier, round(multiplier)):
		return str(int(round(multiplier)))
	return str(multiplier)
