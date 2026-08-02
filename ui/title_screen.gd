extends Control

@onready var _play_button: Button = $PlayButton
@onready var _load_button: Button = $LoadButton
@onready var _load_hint: Label = $LoadHint


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_load_button.pressed.connect(_on_load_pressed)

	# 저장 파일이 없으면 불러오기 버튼을 비활성화하고 안내를 표시
	var save_exists := SaveManager.has_save()
	_load_button.disabled = not save_exists
	_load_hint.visible = not save_exists


# PLAY 버튼을 누르면 SceneManager가 마을 씬으로 교체하고 (처음이면) 오프닝 컷신부터 진행
func _on_play_pressed() -> void:
	SceneManager.start_game()


# LOAD 버튼: 저장 파일이 있으면 불러오기 (버튼이 비활성화 상태면 애초에 눌리지 않음)
func _on_load_pressed() -> void:
	if SaveManager.has_save():
		SaveManager.load_game()
