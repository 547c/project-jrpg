class_name SpawnPoint
extends Marker2D

@export var spawn_point_name: String = ""


# 씬에 들어올 때 SceneManager가 검색할 수 있도록 "spawn_points" 그룹에 등록
func _ready() -> void:
	add_to_group("spawn_points")
