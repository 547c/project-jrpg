class_name PlayerCombatant
extends RefCounted

# 플레이어를 CompanionState와 같은 인터페이스로 다루기 위한 얇은 어댑터.
# 상태를 복사해 들고 있지 않고 전부 GameState/매니저로 위임한다 — 그래서 write-back도
# 동기화 불변식도 생기지 않는다 (설계 근거: docs/companion_system_backend_plan.md §3 C안)

var display_name: String = "플레이어"
var status: StatusEffects # 매니저의 player_status를 그대로 가리킨다 (복사 아님)


func _init(status_: StatusEffects) -> void:
	status = status_


func is_alive() -> bool:
	return GameState.get_flag("player_hp") > 0


func take_damage(amount: int) -> int:
	var before: int = GameState.get_flag("player_hp")
	GameState.damage_player(amount)
	return before - GameState.get_flag("player_hp")


func heal(amount: int) -> int:
	var max_hp: int = GameState.get_flag("player_max_hp")
	if max_hp <= 0:
		return 0
	var before: int = GameState.get_flag("player_hp")
	GameState.heal_player_partial(float(amount) / max_hp)
	return GameState.get_flag("player_hp") - before
