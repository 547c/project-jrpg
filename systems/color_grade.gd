extends CanvasLayer


func _process(_delta: float) -> void:
	visible = GraphicsToggles.color_grade_enabled and HUD._should_show_hud()
