class_name CompanionState
extends RefCounted

const CompanionData = preload("res://battle/companion_data.gd")

# 전투에 참여한 동료 한 명의 상태. MonsterState를 본뜨되, 몬스터 전용 개념 중 resistance/rewarded는
# 뺐다 — 근거는 docs/companion_system_backend_plan.md §2. 마나 리듬은 Phase 4에서 액티브 스킬
# 비용을 위해 다시 들여왔다 (docs/companion_system_options.md §7).
# HP는 전투 사이에도 유지되는 영속 값이라(§8 Q1), 생성 시 GameState.companion_hp에서 이어받는다.
# 마나도 Phase 4c부터 같은 방식(GameState.companion_mana)으로 이어받는다 — 안 그러면 모닥불로
# 채워둔 마나가 다음 전투 시작과 동시에 만빵으로 리셋돼 회복이 의미가 없어진다.

var index: int = 0
var companion_id: String = ""
var data: Dictionary = {}
var display_name: String = ""

var max_hp: int = 0
var hp: int = 0
var status: StatusEffects

# 몬스터 마나 리듬(MonsterState)과 같은 장치 — data["mana"]의 값을 그대로 읽어 쓰므로
# 동료마다(엘라라/로한 등) 수치만 다르게 채우면 이 클래스는 손댈 필요가 없다
var max_mana: int = 0
var mana: int = 0

var passive_counter: int = 0


func _init(index_: int, companion_id_: String) -> void:
	index = index_
	companion_id = companion_id_
	data = CompanionData.COMPANIONS[companion_id_]
	max_hp = data["max_hp"]
	hp = clampi(int(GameState.companion_hp.get(companion_id_, max_hp)), 0, max_hp)
	max_mana = int(data["mana"]["max_mana"])
	mana = clampi(int(GameState.companion_mana.get(companion_id_, max_mana)), 0, max_mana)
	status = StatusEffects.new()
	display_name = tr(data["name"])


func is_alive() -> bool:
	return hp > 0


# MonsterState.take_damage와 같은 규약 — 실제로 깎인 양을 반환해 팝업/HP바가 어긋나지 않게 한다
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := hp
	hp = max(0, hp - amount)
	return before - hp


func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := hp
	hp = min(max_hp, hp + amount)
	return hp - before


func roll_attack_damage() -> int:
	return randi_range(data["damage_min"], data["damage_max"])


func restore_mana(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := mana
	mana = min(max_mana, mana + amount)
	return mana - before


# 이번 턴에 공격할 수 있는지 — MonsterState.can_attack()과 같은 판단
func can_attack() -> bool:
	return mana >= int(data["mana"]["low_mana_threshold"])


# 공격 비용을 치르고 실제 소모량을 반환 — MonsterState.spend_attack_mana()와 같은 규약
func spend_attack_mana() -> int:
	var mana_data: Dictionary = data["mana"]
	var cost := randi_range(int(mana_data["attack_cost_min"]), int(mana_data["attack_cost_max"]))
	var before := mana
	mana = max(0, mana - cost)
	return before - mana


# 회복 턴 처리 — MonsterState.recover()와 같은 규약. {"mana": int, "hp": int}로
# 실제 회복량을 돌려준다 (hp가 0이면 이번엔 체력 회복이 안 붙은 것)
func recover() -> Dictionary:
	var mana_data: Dictionary = data["mana"]
	var mana_before := mana
	mana = min(max_mana, mana + randi_range(int(mana_data["recover_mana_min"]), int(mana_data["recover_mana_max"])))

	var healed := 0
	if randf() < float(mana_data["recover_hp_chance"]):
		var fraction := randf_range(float(mana_data["recover_hp_fraction_min"]), float(mana_data["recover_hp_fraction_max"]))
		healed = heal(int(round(max_hp * fraction)))

	return {"mana": mana - mana_before, "hp": healed}


# 액티브 사용 시 소모할 마나량 (max_mana의 mana_cost_fraction 비율, 반올림)
func active_mana_cost() -> int:
	return int(round(max_mana * float(data["active"]["mana_cost_fraction"])))


# 액티브를 지금 쓸 수 있는지 — 전투 시작 후 unlock_turn 라운드가 지났고(1회성 게이트, 그 뒤로는
# 쿨다운 없음), 비용을 치를 마나가 남아 있어야 한다 (docs/companion_system_options.md §7)
func can_use_active(rounds_completed: int) -> bool:
	return is_alive() and rounds_completed >= int(data["active"]["unlock_turn"]) and mana >= active_mana_cost()


func spend_mana(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := mana
	mana = max(0, mana - amount)
	return before - mana


# 라운드 하나가 끝날 때 호출 (BattleTurnManager._resolve_enemy_turn과 같은 주기).
# 패시브 카운터를 올린다 — 실제 발동 판정은 consume_passive_trigger()가 한다
func tick_round() -> void:
	passive_counter += 1


# 패시브 발동 주기에 도달했으면 카운터를 리셋하고 true를 반환한다
func consume_passive_trigger() -> bool:
	if passive_counter < int(data["passive"]["period"]):
		return false
	passive_counter = 0
	return true
