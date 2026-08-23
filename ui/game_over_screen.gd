extends CanvasLayer

# 전투 패배 시 전체 화면을 덮는 게임오버 화면 (autoload). 전투 씬(battle_scene)이 show_game_over()로 띄운다.
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


# 외부(슬롯 메뉴 로드 성공 시)에서 게임오버 화면을 강제로 닫을 때 사용
func dismiss() -> void:
	_root.visible = false


func _on_restart() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_root.visible = false
	_restart_to_village()


# 불러오기는 슬롯 선택 메뉴를 띄운다 (게임오버 화면은 뒤에 유지 → 닫기 시 복귀).
# 슬롯에서 로드 성공 시 슬롯 메뉴가 이 화면을 dismiss()로 닫는다
func _on_load() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	SaveSlotMenu.open_load_mode()


# 절반만 회복시키고 마을 스폰 지점으로 이동 (재시작 페널티)
func _restart_to_village() -> void:
	GameState.heal_player_half()
	SceneManager.change_scene(VILLAGE_SCENE_PATH, VILLAGE_SPAWN_POINT)
