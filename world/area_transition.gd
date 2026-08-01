extends Area2D

@export var destination_scene_path: String = ""
@export var destination_spawn_point: String = ""


# body_entered 시그널을 콜백에 연결하고, SceneManager가 일괄 제어할 수 있도록 "area_transitions" 그룹에 등록
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("area_transitions")


# 겹친 대상이 플레이어일 때만 목적지 씬으로 전환
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		SceneManager.change_scene(destination_scene_path, destination_spawn_point)
