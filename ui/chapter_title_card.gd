class_name ChapterTitleCard
extends Control

# 파트가 바뀌는 지점에서 검은 화면에 띄우는 "PART N / 부제" 타이틀 카드.
# 어느 파트에도 그대로 쓰도록 문구는 씬에 박지 않고 play()의 인자로만 받는다.
# 등장 -> 유지 -> 퇴장을 play() 하나가 전부 처리하므로, 호출부는 await 한 번이면 된다.

const IMPACT_SOUND := "res://assets/sfx/400 Sounds pack/Weapons/harsh_thud.wav"
const IMPACT_VOLUME_DB := -1.0 # 파트 전환의 무게감을 위해 공용 기본값(-6)보다 크게

const APPEAR_DURATION := 0.5
const APPEAR_START_SCALE := 0.88 # 살짝 작게 시작해 확대되며 나타남
const HOLD_DURATION := 1.7
const DISAPPEAR_DURATION := 0.45

@onready var _content: Control = $Content
@onready var _part_label: Label = $Content/PartLabel
@onready var _subtitle_label: Label = $Content/SubtitleLabel


func _ready() -> void:
	# 카드가 떠 있는 동안 플레이어가 (검은 화면 뒤에서) 움직이지 않도록,
	# player.gd가 이동을 막는 기준으로 삼는 그룹에 등록한다
	add_to_group("chapter_title_card")

	# play()가 실제 문구를 채우고 보여주기 전까지는 항상 완전히 안 보이는 상태로 시작한다.
	# 씬 파일에 박힌 에디터 placeholder 텍스트(예: "PART 1")가, 호출부가 화면을 걷어내는
	# 시점과 play()가 텍스트를 채우는 시점 사이의 짧은 틈에 그대로 노출되는 걸 막기 위함 —
	# 호출 순서에 기대지 않고 이 노드 스스로 항상 안전한 상태로 시작하게 한다
	_content.modulate.a = 0.0


# 문구를 채우고 등장 -> 유지 -> 퇴장까지 재생. 끝날 때까지 await로 기다릴 수 있다
func play(part_text: String, subtitle: String) -> void:
	_part_label.text = part_text
	_subtitle_label.text = subtitle

	# 가운데를 기준으로 확대되도록 피벗을 잡는다. size는 레이아웃이 한 번 돈 뒤에야 확정되므로
	# 그 전에 읽으면 피벗이 0이 되어 왼쪽 위에서 커지는 것처럼 보인다
	await get_tree().process_frame
	_content.pivot_offset = _content.size / 2.0
	_content.scale = Vector2.ONE * APPEAR_START_SCALE
	_content.modulate.a = 0.0

	SFXPlayer.play(IMPACT_SOUND, IMPACT_VOLUME_DB)

	var appear := create_tween().set_parallel()
	appear.tween_property(_content, "scale", Vector2.ONE, APPEAR_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	appear.tween_property(_content, "modulate:a", 1.0, APPEAR_DURATION)
	await appear.finished

	await get_tree().create_timer(HOLD_DURATION).timeout

	var disappear := create_tween()
	disappear.tween_property(_content, "modulate:a", 0.0, DISAPPEAR_DURATION)
	await disappear.finished
