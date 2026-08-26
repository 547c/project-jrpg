extends CanvasLayer


func _process(_delta: float) -> void:
	visible = GraphicsToggles.tilt_shift_enabled and HUD._should_show_hud()
