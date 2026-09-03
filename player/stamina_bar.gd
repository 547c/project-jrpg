extends Node2D

# 체력/마나바와 같은 텍스처를 쓰지만, ProgressBar+StyleBoxTexture 조합은 Control 조상이
# 없는(HUD가 아니라 캐릭터에 매달린) 상황에서 fill 스타일박스가 안 그려지는 문제가 있어
# 직접 그린다. 9-slice 없이 단순 스트레치라 끝부분이 살짝 눌려 보이지만, 이 크기에서는 티가 안 난다

const BOX_TEXTURE := preload("res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Sliders & Bars/Slider01_Box.png")
const FILL_TEXTURE := preload("res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/Sliders & Bars/Slider01_Bar01.png")

const BAR_SIZE := Vector2(28.0, 10.0)

var _fraction: float = 1.0


func set_fraction(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, _fraction):
		return
	_fraction = value
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-BAR_SIZE / 2.0, BAR_SIZE)
	draw_texture_rect(BOX_TEXTURE, rect, false)
	if _fraction <= 0.0:
		return
	var fill_rect := Rect2(rect.position, Vector2(rect.size.x * _fraction, rect.size.y))
	var src_size := Vector2(FILL_TEXTURE.get_width() * _fraction, FILL_TEXTURE.get_height())
	draw_texture_rect_region(FILL_TEXTURE, fill_rect, Rect2(Vector2.ZERO, src_size))
