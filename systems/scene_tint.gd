extends CanvasLayer

# 구역별 은은한 색조 오버레이 (autoload). 화면 전체를 덮는 반투명 ColorRect로, HUD(layer 5)보다는
# 아래에 그리고 월드(기본 layer 0)보다는 위에 그려서 게임 화면 위에 옅게 얹힌다.
# 어떤 색을 쓸지는(씬 경로 -> Color) scene_manager.gd의 SCENE_TINTS가 결정해서 apply()로 넘겨준다
# (BGM_TRACKS를 scene_manager가 갖고 MusicManager.play()만 호출하는 것과 같은 역할 분담)

@onready var _rect: ColorRect = $Rect


func _ready() -> void:
	_rect.color = Color(0, 0, 0, 0)


# 지정한 색으로 즉시 전환 (매핑에 없는 씬이면 scene_manager가 완전 투명 Color를 넘겨 오버레이를 끈다)
func apply(color: Color) -> void:
	_rect.color = color
