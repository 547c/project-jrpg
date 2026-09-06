class_name CompanionState
extends RefCounted

const CompanionData = preload("res://battle/companion_data.gd")

# 전투에 참여한 동료 한 명의 상태. MonsterState를 본뜨되, 몬스터 전용 개념(mana 리듬,
# resistance, rewarded)은 의도적으로 뺐다 — 근거는 docs/companion_system_backend_plan.md §2.
# HP는 전투 사이에도 유지되는 영속 값이라(§8 Q1), 생성 시 GameState.companion_hp에서 이어받는다.

var index: int = 0
var companion_id: String = ""
var data: Dictionary = {}
var display_name: String = ""

var max_hp: int = 0
var hp: int = 0
var status: StatusEffects

var active_cooldown: int = 0
var passive_counter: int = 0


func _init(index_: int, companion_id_: String) -> void:
	index = index_
	companion_id = companion_id_
	data = CompanionData.COMPANIONS[companion_id_]
	max_hp = data["max_hp"]
	hp = clampi(int(GameState.companion_hp.get(companion_id_, max_hp)), 0, max_hp)
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


func can_use_active() -> bool:
	return is_alive() and active_cooldown <= 0


func start_active_cooldown() -> void:
	active_cooldown = data["active"]["cooldown"]


# 라운드 하나가 끝날 때 호출 (BattleTurnManager._resolve_enemy_turn과 같은 주기).
# 쿨다운을 줄이고 패시브 카운터를 올린다 — 실제 발동 판정은 consume_passive_trigger()가 한다
func tick_round() -> void:
	active_cooldown = max(0, active_cooldown - 1)
	passive_counter += 1


# 패시브 발동 주기에 도달했으면 카운터를 리셋하고 true를 반환한다
func consume_passive_trigger() -> bool:
	if passive_counter < int(data["passive"]["period"]):
		return false
	passive_counter = 0
	return true
