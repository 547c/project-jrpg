class_name StatusEffects
extends RefCounted

# 한 대상(플레이어 또는 몬스터 한 마리)에게 걸려 있는 버프/디버프 목록.
#
# 플레이어와 몬스터가 같은 클래스를 하나씩 들고 있다 — 어느 쪽에 걸리느냐만 다르고 "무엇이
# 얼마나 몇 라운드 걸려 있는가"라는 성질은 같아서, 양쪽에 비슷한 코드를 두 벌 두지 않으려는 것이다.
# 그래서 이 클래스는 "누구에게 걸렸는지"를 전혀 모르고, 배율을 꺼내 쓰는 쪽(BattleTurnManager)이
# 자기 대상의 것을 골라 읽는다.
#
# [라운드의 정의] "적 전원의 턴이 한 바퀴 도는 것"이 한 라운드다. 감소 시점은 적 턴이 전부 끝난
# 직후 한 번(BattleTurnManager._resolve_enemy_turn 끝)이라, 몬스터가 몇 마리든 라운드가 도는
# 속도는 같다 — 마리 수에 따라 버프가 빨리 닳으면 다인전에서 버프 카드의 값어치가 달라져 버린다.
#
# [수치 표현] magnitude는 "퍼센트"(20 = 20%)로 저장하고, 배율이 필요한 쪽에서 1.0 ± magnitude/100으로
# 환산한다. 카드 데이터(Card.value)가 퍼센트로 적혀 있어 그대로 담을 수 있고, 화면에 "+20%"처럼
# 그대로 보여줄 수 있어서다.

# 상태이상 종류. 지금 쓰는 건 ATTACK_UP/ATTACK_DOWN 둘뿐이지만, 나머지도 계산 훅과 배지 표시까지
# 미리 이어둬서 해당 카드만 만들면 바로 동작한다 (인프라를 먼저 완성해두려는 이번 단계의 목적)
enum Kind {
	ATTACK_UP,     # 주는 피해 증가 (플레이어 자기버프)
	ATTACK_DOWN,   # 주는 피해 감소 (몬스터에게 거는 디버프)
	DEFENSE_DOWN,  # 받는 피해 증가 (몬스터 방어력 약화)
	RESIST_DOWN,   # 속성 저항의 감쇄 폭 자체를 완화 (몬스터 저항 약화)
}

# 화면/로그에 쓸 짧은 이름
const KIND_LABEL := {
	Kind.ATTACK_UP: "공격력↑",
	Kind.ATTACK_DOWN: "공격력↓",
	Kind.DEFENSE_DOWN: "방어력↓",
	Kind.RESIST_DOWN: "저항↓",
}

# 종류 -> {"magnitude": int(퍼센트), "rounds": int(남은 라운드)}
# 같은 종류를 여러 개 겹쳐 들 수 없게 딕셔너리로 둔다 — 이 자료구조 자체가 "중첩 없음" 규칙이다
var _effects: Dictionary = {}


# 상태이상을 건다. 이미 같은 종류가 걸려 있으면 새로 쌓지 않고 기존 것을 갱신한다.
#
# [갱신 규칙 — 둘 다 최댓값] 수치도 라운드도 max로 잡는다. "다시 걸었더니 오히려 약해지거나
# 빨리 풀리는" 상황을 없애려는 것 — 약한 디버프를 덧씌워 강한 디버프를 지우는 플레이가 가능하면
# 플레이어가 카드 순서를 신경 써야 하는데, 그건 이 시스템이 주려는 재미가 아니다.
# (중첩은 여전히 없다. 20%를 두 번 걸어도 40%가 되지 않고 20%인 채 라운드만 다시 찬다)
func apply(kind: Kind, magnitude: int, rounds: int) -> void:
	if magnitude <= 0 or rounds <= 0:
		return

	if _effects.has(kind):
		var existing: Dictionary = _effects[kind]
		existing["magnitude"] = maxi(int(existing["magnitude"]), magnitude)
		existing["rounds"] = maxi(int(existing["rounds"]), rounds)
		return

	_effects[kind] = {"magnitude": magnitude, "rounds": rounds}


func has(kind: Kind) -> bool:
	return _effects.has(kind)


# 걸려 있는 수치(퍼센트). 없으면 0이라 호출부가 "없을 때"를 따로 분기하지 않아도 된다
func get_magnitude(kind: Kind) -> int:
	if not _effects.has(kind):
		return 0
	return int(_effects[kind]["magnitude"])


func get_rounds(kind: Kind) -> int:
	if not _effects.has(kind):
		return 0
	return int(_effects[kind]["rounds"])


# 이 종류를 "증가" 배율로 환산 (없으면 1.0). 예: ATTACK_UP 20% -> 1.2
func get_increase_multiplier(kind: Kind) -> float:
	return 1.0 + get_magnitude(kind) / 100.0


# 이 종류를 "감소" 배율로 환산 (없으면 1.0). 예: ATTACK_DOWN 20% -> 0.8.
# 100%를 넘겨 음수가 되지 않게 0에서 막는다 (피해가 마이너스가 되어 회복되는 일이 없도록)
func get_decrease_multiplier(kind: Kind) -> float:
	return maxf(0.0, 1.0 - get_magnitude(kind) / 100.0)


# 한 라운드가 끝났을 때 호출. 모든 상태이상의 남은 라운드를 1씩 줄이고 0이 된 것을 제거한다.
# 제거된 종류 목록을 반환해 호출부가 "무엇이 풀렸는지" 알릴 수 있게 한다
func tick_round() -> Array:
	var expired: Array = []
	for kind in _effects.keys():
		var effect: Dictionary = _effects[kind]
		effect["rounds"] = int(effect["rounds"]) - 1
		if effect["rounds"] <= 0:
			expired.append(kind)
	for kind in expired:
		_effects.erase(kind)
	return expired


func clear() -> void:
	_effects.clear()


func is_empty() -> bool:
	return _effects.is_empty()


# 걸려 있는 종류들 (배지 표시용)
func active_kinds() -> Array:
	return _effects.keys()


# "공격력↑ +20% (2)" 같은 한 줄 요약들 — 화면에 그대로 쓸 수 있는 형태
func describe_all() -> Array[String]:
	var lines: Array[String] = []
	for kind in _effects.keys():
		var effect: Dictionary = _effects[kind]
		var sign_text := "+" if kind == Kind.ATTACK_UP else "-"
		lines.append("%s %s%d%% (%d)" % [KIND_LABEL[kind], sign_text, int(effect["magnitude"]), int(effect["rounds"])])
	return lines
