extends CanvasLayer

# 전투 패배 시 전체 화면을 덮는 게임오버 화면 (autoload). BattleBox가 show_game_over()로 띄운다.
# [다시 시작]: 절반 회복 + 마을 스폰으로 이동, [불러오기]: 세이브 로드(없으면 안내 후 재시작).

const VILLAGE_SCENE_PATH := "res://world/village.tscn"
const VILLAGE_SPAWN_POINT := "VillageSpawn"

@onready var _root: Control = $Root
@onready var _restart_button: Button = $Root/VBox/RestartButton
@onready var _load_button: Button = $Root/VBox/LoadButton
@onready var _toast: Label = $Root/VBox/Toast


func _ready() -> void:
	_root.visible = false
	_toast.visible = false
	_restart_button.pressed.connect(_on_restart)
	_load_button.pressed.connect(_on_load)


# 게임오버 화면을 띄운다
func show_game_over() -> void:
	_toast.visible = false
	_root.visible = true


func _on_restart() -> void:
	_root.visible = false
	_restart_to_village()


func _on_load() -> void:
	if SaveManager.has_save():
		_root.visible = false
		SaveManager.load_game()
	else:
		_show_toast_then_restart()


# 절반만 회복시키고 마을 스폰 지점으로 이동 (재시작 페널티)
func _restart_to_village() -> void:
	GameState.heal_player_half()
	SceneManager.change_scene(VILLAGE_SCENE_PATH, VILLAGE_SPAWN_POINT)


# 저장 파일이 없을 때: 안내를 잠깐 보여준 뒤 재시작 로직으로 대체 진행
func _show_toast_then_restart() -> void:
	_toast.text = "저장된 게임이 없습니다"
	_toast.visible = true
	await get_tree().create_timer(1.2).timeout
	_toast.visible = false
	_root.visible = false
	_restart_to_village()
