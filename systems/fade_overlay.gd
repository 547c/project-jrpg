extends CanvasLayer

# 씬 전환 시 화면을 검게 덮었다 걷어내는 공용 페이드 오버레이 (autoload, 항상 최상단 레이어).
# fade_out()/fade_in()을 await해서 쓰면, 완전히 까매진/투명해진 뒤에야 다음 코드가 이어진다.

const DEFAULT_DURATION := 0.35

@onready var _rect: ColorRect = $Rect


func _ready() -> void:
	_rect.color = Color(0, 0, 0, 0)


# 화면을 서서히 검게 덮음 (완전히 까매질 때까지 대기)
func fade_out(duration: float = DEFAULT_DURATION) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, duration)
	await tween.finished


# 검은 화면을 서서히 걷어냄 (완전히 투명해질 때까지 대기)
func fade_in(duration: float = DEFAULT_DURATION) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 0.0, duration)
	await tween.finished
