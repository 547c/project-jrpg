class_name SpawnPoint
extends Marker2D

@export var spawn_point_name: String = ""
@export var is_initial_spawn: bool = false # 메인 씬 최초 부팅 시 사용할 스폰 지점인지 (씬당 하나만 true여야 함)


# 씬에 들어올 때 SceneManager가 검색할 수 있도록 "spawn_points" 그룹에 등록
func _ready() -> void:
	add_to_group("spawn_points")
