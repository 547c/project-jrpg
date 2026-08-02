extends Control

@onready var _play_button: Button = $PlayButton


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)


# PLAY 버튼을 누르면 SceneManager가 마을 씬으로 교체하고 (처음이면) 오프닝 컷신부터 진행
func _on_play_pressed() -> void:
	SceneManager.start_game()
