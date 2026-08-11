extends Node2D

# 세 엔딩(good/neutral/bad)이 공유하는 스크립트. 지금은 "최종 엔딩"이 아니라 "1부 중간 요약" 화면이라,
# 진행 상황을 리셋하지 않고 그대로 유지한 채 "계속하기"로 마을(VillageSpawn)로 복귀한다.
# (실제 최종 엔딩 — 리셋 + 타이틀 복귀 — 은 2부 완료 시점으로 미룬다)

const CONTINUE_SCENE_PATH := "res://world/village.tscn"
const CONTINUE_SPAWN_POINT := "VillageSpawn"

@onready var _continue_button: Button = $UI/VBox/ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)


# 진행 상황(플래그/호감도/인벤토리 등)을 그대로 둔 채 마을로 돌아간다 — reset_progress() 호출하지 않음
func _on_continue_pressed() -> void:
	SceneManager.change_scene(CONTINUE_SCENE_PATH, CONTINUE_SPAWN_POINT)
