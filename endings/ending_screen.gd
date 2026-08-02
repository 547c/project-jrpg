extends Node2D

# 세 엔딩(good/neutral/bad)이 공유하는 스크립트: 아무 키나 누르거나 클릭하면
# 진행 상태를 초기화하고 타이틀 화면으로 돌아간다


func _unhandled_input(event: InputEvent) -> void:
	if not _is_advance_input(event):
		return

	get_viewport().set_input_as_handled()
	GameState.reset_progress()
	SceneManager.return_to_title()


func _is_advance_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false
