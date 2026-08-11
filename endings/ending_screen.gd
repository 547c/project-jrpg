extends Node2D

# 세 엔딩(good/neutral/bad)이 공유하는 스크립트. 지금은 "최종 엔딩"이 아니라 "1부 중간 요약" 화면이라,
# 진행 상황을 리셋하지 않고 그대로 유지한 채 "계속하기"로 마을(VillageSpawn)로 복귀한다.
# (실제 최종 엔딩 — 리셋 + 타이틀 복귀 — 은 2부 완료 시점으로 미룬다)

const CONTINUE_SCENE_PATH := "res://world/village.tscn"
const CONTINUE_SPAWN_POINT := "VillageSpawn"

# 세 엔딩 씬이 이 스크립트를 공유하므로, 어떤 엔딩인지는 씬 파일 경로에서 도출한다
# ("res://endings/ending_good.tscn" -> "part1_good"). 도감(GameState.seen_endings)에 쓰는 id이자
# systems/ending_data.gd의 ENDINGS[].id와 일치해야 한다
const ENDING_ID_PREFIX := "part1_"

@onready var _continue_button: Button = $UI/VBox/ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	GameState.mark_ending_seen(_resolve_ending_id()) # 이 화면이 뜬 순간 도감에 영구 기록


# 씬 파일 이름에서 엔딩 id를 만든다 (ending_good.tscn -> part1_good). 판별 실패 시 빈 문자열
# (mark_ending_seen이 빈 id를 무시하므로 안전)
func _resolve_ending_id() -> String:
	var kind := scene_file_path.get_file().get_basename().trim_prefix("ending_")
	if kind == "":
		return ""
	return ENDING_ID_PREFIX + kind


# 진행 상황(플래그/호감도/인벤토리 등)을 그대로 둔 채 마을로 돌아간다 — reset_progress() 호출하지 않음
func _on_continue_pressed() -> void:
	SceneManager.change_scene(CONTINUE_SCENE_PATH, CONTINUE_SPAWN_POINT)
