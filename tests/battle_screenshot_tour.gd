extends Node

# 실제 전투 씬을 창으로 띄워 개편한 시스템이 화면에 나오는 장면을 순서대로 캡처한다.
#   godot res://tests/battle_screenshot_tour.tscn -- <저장 폴더>
# 각 장면을 빨리 보여주려고 손패/게이지/몬스터 체력 같은 "상태"만 맞추고, 예약·턴 진행·보상 선택은
# 전부 UI 버튼이 부르는 씬 함수를 그대로 호출해 실제 흐름과 연출을 탄다

var _out_dir := ""
var _scene: BattleScene


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	seed(4242)
	GameState.active_companions.clear()
	GameState.battle_deck.clear()
	GameState.set_flag("player_base_max_hp", 46)
	GameState.set_flag("player_max_hp", 46)
	GameState.set_flag("player_hp", 46)
	GameState.set_flag("player_max_mana", 40)
	GameState.set_flag("player_mana", 40)
	for card_id in ["stab", "ice_arrow", "lightning_spear", "fireball", "flash_slash", "spin_slash"]:
		if not GameState.unlocked_cards.has(card_id):
			GameState.unlocked_cards.append(card_id)

	_scene = (load("res://battle/battle_scene.tscn") as PackedScene).instantiate() as BattleScene
	get_tree().root.add_child.call_deferred(_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_scene.start_with("ORC", [])
	var manager := _scene._manager

	# 보여주기 좋은 편성으로 2~3스테이지를 고정한다 (1스테이지는 이미 섰다)
	manager.stages = [
		manager.stages[0],
		{"variants": [BattleData.pick_variant("ORC"), BattleData.pick_variant("ORC")], "elites": [false, true]},
		{"variants": [BattleData.pick_variant("ORC"), BattleData.pick_variant("ORC"), BattleData.pick_variant("ORC")], "elites": [false, true, true]},
	]
	await _wait_action()
	await _wait_seconds(1.6) # 첫 손패 뒤집기 연출이 끝난 뒤에 찍는다
	_beef_up_monsters(40)
	_refresh_ui()
	await _wait_seconds(0.3)
	await _shot("01_stage1_start")

	# ── 도발 + 전환이 끼어든 예약 큐 ─────────────────────────────────
	_set_hand(["wooden_sword_slash", "magic_bolt", "ice_arrow", "guard", "stab"])
	var target := manager.monsters.size() - 1
	manager.reserve_card(_hand("마력탄"), target)
	_scene._on_weapon_pressed()
	manager.reserve_card(_hand("베기"), target)
	_refresh_ui()
	await _shot("02_provoke_ring_and_switch_queue")

	# ── 레드라인: 검 게이지 50 이상 (바가 주황으로 맥동) ─────────────────
	_clear_queue()
	manager.weapon.equipped = WeaponState.WeaponType.SWORD
	manager.weapon.sword_gauge = 50
	_refresh_ui()
	await _wait_seconds(0.25)
	await _shot("03_redline_gauge")

	# ── 과부하 → 봉쇄: 75에서 한 장 더 지르고 턴 종료 ─────────────────────
	manager.weapon.sword_gauge = 75
	_set_hand(["wooden_sword_slash", "stab", "guard", "heal_light", "dodge_roll"])
	manager.reserve_card(_hand("베기"), 0)
	_refresh_ui()
	_scene._on_end_turn_pressed()
	await _wait_until(func() -> bool: return manager.weapon.sword_lock_rounds > 0, 15.0)
	await _wait_seconds(0.4)
	await _shot("04_overload_moment")
	await _wait_action()
	await _shot("05_sword_locked")

	# ── 적응: 같은 속성으로 두 번 → 방패 아이콘 ─────────────────────────
	manager.weapon.cool_everything()
	manager.weapon.equipped = WeaponState.WeaponType.STAFF
	_beef_up_monsters(40)
	_set_hand(["magic_bolt", "ice_arrow", "guard", "heal_light", "dodge_roll"])
	manager.reserve_card(_hand("마력탄"), 0)
	_refresh_ui()
	_scene._on_end_turn_pressed()
	await _wait_action()
	await _shot("06_adaptation_pending")

	_set_hand(["ice_arrow", "guard", "heal_light", "dodge_roll", "stab"])
	manager.reserve_card(_hand("얼음화살"), 0)
	_refresh_ui()
	_scene._on_end_turn_pressed()
	await _wait_until(func() -> bool: return manager.get_monster(0).resistance.current != EnemyResistance.ResistanceType.NONE, 15.0)
	await _wait_seconds(0.3)
	await _shot("07_adapted_popup")
	await _wait_action()
	await _shot("08_adapted_badge")

	# ── 표식 폭발: 표식 건 뒤 전환 ───────────────────────────────────────
	_set_hand(["ice_arrow", "guard", "heal_light", "dodge_roll", "stab"])
	manager.reserve_card(_hand("얼음화살"), manager.monsters.size() - 1)
	_scene._on_weapon_pressed()
	_refresh_ui()
	await _shot("09_mark_then_switch_queued")
	_scene._on_end_turn_pressed()
	await _wait_action()

	# ── 스테이지 돌파 → 보상 선택 ────────────────────────────────────────
	for monster in manager.monsters:
		if monster.is_alive():
			monster.hp = 1
	_scene._refresh_monster_hp_bars()
	var nuke := (CardLibrary.get_card("wooden_sword_slash").duplicate() as Card)
	nuke.is_aoe = true
	nuke.card_name = "베기"
	manager.weapon.cool_everything()
	manager.hand.cards = [nuke] as Array[Card]
	manager.reserve_card(nuke, -1)
	_refresh_ui()
	_scene._on_end_turn_pressed()
	await _wait_until(func() -> bool: return _scene._reward_overlay != null and is_instance_valid(_scene._reward_overlay), 20.0)
	await _wait_seconds(0.4)
	await _shot("10_stage_reward_choice")

	_scene._on_reward_picked(0)
	await _wait_until(func() -> bool: return manager.stage_index == 1, 10.0)
	await _wait_action()
	await _wait_seconds(0.5)
	await _shot("11_stage2_elite")

	# ── 남은 스테이지를 끝까지 밀어 최종 승리 처리까지 확인한다 ──────────────
	while not manager.battle_over:
		for monster in manager.monsters:
			if monster.is_alive():
				monster.hp = 1
		var sweep := (CardLibrary.get_card("wooden_sword_slash").duplicate() as Card)
		sweep.is_aoe = true
		manager.weapon.cool_everything()
		manager.hand.cards = [sweep] as Array[Card]
		manager.reserve_card(sweep, -1)
		_refresh_ui()
		var stage_before := manager.stage_index
		_scene._on_end_turn_pressed()
		await _wait_until(func() -> bool:
			return manager.battle_over or (_scene._reward_overlay != null and is_instance_valid(_scene._reward_overlay)), 20.0)
		if manager.battle_over:
			break
		_scene._on_reward_picked(0)
		await _wait_until(func() -> bool: return manager.stage_index > stage_before, 10.0)
		await _wait_action()
	await _wait_until(func() -> bool: return _scene._mode == BattleScene.Mode.OVER and _scene._close_button.visible, 20.0)
	await _wait_seconds(0.6)
	await _shot("12_final_victory")

	print("TOUR DONE")
	get_tree().quit(0)


# ── 헬퍼 ───────────────────────────────────────────────────────────────────

func _set_hand(ids: Array) -> void:
	var cards: Array[Card] = []
	for id in ids:
		cards.append(CardLibrary.get_card(id).duplicate() as Card)
	_scene._manager.hand.cards = cards


func _hand(card_name: String) -> Card:
	for card in _scene._manager.hand.cards:
		if card.card_name == card_name:
			return card
	return null


func _clear_queue() -> void:
	while _scene._manager.has_reservations():
		_scene._manager.cancel_reservation(0)
	_refresh_ui()


func _beef_up_monsters(hp: int) -> void:
	for monster in _scene._manager.monsters:
		if not monster.is_alive():
			continue
		monster.max_hp = hp
		monster.hp = hp
		monster.mana = 100
		if monster.index < _scene._monster_hp_bars.size():
			_scene._monster_hp_bars[monster.index].max_value = hp
			_scene._monster_field_hp_bars[monster.index].max_value = hp
	_scene._refresh_monster_hp_bars()


func _refresh_ui() -> void:
	_scene._refresh_reservation_markers()
	_scene._refresh_play_queue()
	_scene._refresh_all()


func _wait_action() -> void:
	await _wait_until(func() -> bool: return _scene._mode == BattleScene.Mode.ACTION and not _scene._manager.stage_pending, 30.0)
	await _wait_seconds(0.3)


func _wait_until(condition: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while not condition.call():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed > timeout:
			push_warning("tour wait timed out")
			return false
	return true


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(shot_name + ".png")
	image.save_png(path)
	print("shot: ", path)
