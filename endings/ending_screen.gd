extends Node2D

# 모든 엔딩 화면이 공유하는 스크립트. 씬마다 아래 두 export로 성격을 지정한다:
# - ending_id: 도감(GameState.seen_endings)에 남길 id. systems/ending_data.gd의 ENDINGS[].id와 일치해야 한다
# - is_final:  false면 1부 중간 요약 화면 → 진행 상황을 그대로 둔 채 마을로 복귀("계속하기")
#              true면 2부 최종 엔딩 → 진행 상황을 리셋하고 타이틀로 복귀("게임 종료").
#              리셋해도 엔딩 도감(seen_endings)과 슬롯 세이브 파일은 남는다

const CONTINUE_SCENE_PATH := "res://world/village.tscn"
const CONTINUE_SPAWN_POINT := "VillageSpawn"

@export var ending_id: String = ""
@export var is_final: bool = false

@onready var _continue_button: Button = $UI/VBox/ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	GameState.mark_ending_seen(ending_id) # 이 화면이 뜬 순간 도감에 영구 기록


# 최종 엔딩이면 진행 상황을 리셋하고 타이틀로, 아니면 진행 상황을 유지한 채 마을로 돌아간다
func _on_continue_pressed() -> void:
	if is_final:
		GameState.reset_progress()
		SceneManager.return_to_title()
		return

	SceneManager.change_scene(CONTINUE_SCENE_PATH, CONTINUE_SPAWN_POINT)
