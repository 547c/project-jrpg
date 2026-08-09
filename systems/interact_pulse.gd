class_name InteractPulse
extends RefCounted

# 상호작용 가능한 오브젝트(NPC/캠프파이어/보물상자/잠긴 문)의 "여기 뭔가 있다" 시각 힌트.
# 평소엔 은은하게(1.0~1.15), 플레이어가 실제 상호작용 범위 안에 들어오면 더 뚜렷하게(1.0~1.35)
# modulate 밝기를 오르내리며 반복(Tween loop)한다. 각 스크립트는 InteractPulse.new(self, 대상)으로
# 만들고, 범위 진입/이탈 시 set_strong(true/false)만 호출하면 된다

const WEAK_MIN := 1.0
const WEAK_MAX := 1.15
const STRONG_MIN := 1.0
const STRONG_MAX := 1.35
const PERIOD := 1.5 # 초 (밝아졌다 어두워지는 전체 왕복 1회 기준)

var _owner: Node
var _target: CanvasItem
var _tween: Tween
var _is_strong: bool = false


# owner는 Tween을 소유할 노드(대개 대상을 담고 있는 Area2D 자신), target은 modulate를 조절할 CanvasItem
func _init(owner: Node, target: CanvasItem) -> void:
	_owner = owner
	_target = target
	_restart(false)


# 범위 밖=약하게, 범위 안=강하게 전환. 이미 같은 강도로 재생 중이면 아무것도 하지 않아
# (예: body_entered가 여러 번 겹쳐 들어와도) 매번 트윈을 재시작하며 깜빡이지 않게 한다
func set_strong(strong: bool) -> void:
	if _tween != null and _tween.is_valid() and _is_strong == strong:
		return
	_restart(strong)


func _restart(strong: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_is_strong = strong
	var min_b: float = STRONG_MIN if strong else WEAK_MIN
	var max_b: float = STRONG_MAX if strong else WEAK_MAX
	var half := PERIOD / 2.0

	_target.modulate = Color(min_b, min_b, min_b, 1.0)
	_tween = _owner.create_tween()
	_tween.set_loops()
	_tween.tween_property(_target, "modulate", Color(max_b, max_b, max_b, 1.0), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_target, "modulate", Color(min_b, min_b, min_b, 1.0), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# 오브젝트가 없어지거나(상자를 연 뒤 등) 더 이상 pulse가 필요 없을 때 완전히 정지
func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if is_instance_valid(_target):
		_target.modulate = Color(1, 1, 1, 1)
