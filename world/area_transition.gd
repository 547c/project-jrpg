extends Area2D

@export var destination_scene_path: String = ""
@export var destination_spawn_point: String = ""

# 마을/숲/동굴/술집/사막/유적의 모든 포탈이 이 스크립트 하나를 공유하므로, 여기서 한 번만
# 소리를 갈라주면 모든 트리거에 자동 적용된다. 술집(건물) 출입만 "문 여닫는" 느낌으로, 그 외
# 야외 지역 간 이동(마을<->숲/동굴/사막/유적)은 "포탈을 넘는" 느낌의 whoosh로 구분한다
const TAVERN_SCENE_PATH := "res://world/tavern.tscn"
const DOOR_SOUND := "res://assets/sfx/400 Sounds pack/Environment/door_open.wav"
const WHOOSH_SOUND := "res://assets/sfx/400 Sounds pack/Other/whoosh_1.wav"


# body_entered 시그널을 콜백에 연결하고, SceneManager가 일괄 제어할 수 있도록 "area_transitions" 그룹에 등록
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("area_transitions")


# 겹친 대상이 플레이어일 때만 목적지 씬으로 전환.
# 씬 전환 억제 구간(방금 로드된 직후)에는 오래된 겹침 판정을 무시한다
func _on_body_entered(body: Node2D) -> void:
	if SceneManager.is_transition_suppressed():
		return
	if body.is_in_group("player"):
		SFXPlayer.play(DOOR_SOUND if destination_scene_path == TAVERN_SCENE_PATH else WHOOSH_SOUND)
		SceneManager.change_scene(destination_scene_path, destination_spawn_point)
