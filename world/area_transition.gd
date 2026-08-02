extends Area2D

@export var destination_scene_path: String = ""
@export var destination_spawn_point: String = ""


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
		SceneManager.change_scene(destination_scene_path, destination_spawn_point)
