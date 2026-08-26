extends CanvasLayer

# 달리기 중 화면 가장자리 비네트+블러 (autoload). SceneTint(layer 2)와 HUD(layer 8) 사이에 그려서
# 월드 화면 위에는 얹히되 HUD/대화창/메뉴는 절대 건드리지 않는다 — 자세한 이유는
# speed_vignette.gdshader 주석 참고.
#
# player.gd가 달리기 시작/종료 시 set_running()만 부르면 되고, 나머지(부드러운 페이드,
# 안 쓸 때 렌더 비용 0으로 끄기)는 여기서 전담한다.

const FADE_DURATION := 0.5
const RUN_STRENGTH := 0.5 # 0.35는 거의 안 느껴진다는 피드백을 받아 올림 — 그래도 화면을 조이는 액션 게임 수준까지는 안 감

@onready var _rect: ColorRect = $Rect

var _tween: Tween
var _running: bool = false


func _ready() -> void:
	_rect.material.set_shader_parameter("strength", 0.0)
	visible = false # 평소엔 이 레이어 자체를 꺼서 SCREEN_TEXTURE 재샘플링 비용도 없앤다


# 달리기 시작/종료에 맞춰 강도를 서서히 올리고/내린다. 매 프레임 부르지 말고
# "달리는 중이냐"가 실제로 바뀐 순간에만 호출할 것 (player.gd가 그렇게 쓴다)
func set_running(running: bool) -> void:
	if running == _running:
		return
	_running = running

	if _tween != null and _tween.is_valid():
		_tween.kill()

	if running:
		visible = true
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_rect.material, "shader_parameter/strength", RUN_STRENGTH if running else 0.0, FADE_DURATION)
	if not running:
		_tween.finished.connect(_on_fade_out_finished)


# 완전히 꺼진 뒤에는 레이어 자체를 숨겨 평소 렌더 비용을 없앤다
func _on_fade_out_finished() -> void:
	visible = false
