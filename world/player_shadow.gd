class_name PlayerShadow
extends AnimatedSprite2D

# 플레이어 전용 "제대로 된" 실루엣 그림자. NPC가 계속 쓰는 타원 그림자(character_shadow.gd)와
# 달리, 플레이어의 sprite_frames를 그대로 공유해 매 프레임 같은 애니메이션/프레임/좌우반전을
# 따라간 뒤 검게 칠하고, 프롭(tree/vegetation/rock)과 같은 방식(ShadowLayer.lay_on_ground)으로
# 바닥에 눕힌다.
#
# [왜 NPC는 그대로 두는가]
# 이번 요청은 플레이어 한정이라 NPC가 쓰는 CharacterShadow(타원)는 손대지 않는다. 다만 "실제
# 프레임의 발밑 위치를 잰다"는 로직 자체는 CharacterShadow._measure_art()가 이미 갖고 있고
# (idle 프레임의 불투명 픽셀 범위로 재는 방식) 텍스처만 보고 계산하는 순수 함수라, 중복
# 구현하지 않고 그대로 가져다 쓴다 — 재사용해도 CharacterShadow/NPC 쪽 동작에는 전혀 영향이 없다.
#
# [원점 보정이 프롭 때처럼 필요했다]
# 플레이어(CharacterBody2D)의 원점은 발밑이 아니라 AnimatedSprite2D가 centered=true인 프레임
# 중심 근처에 있다(콜리전은 발밑 크기인데 스프라이트 자체는 프레임 중심 기준이라 실제 발
# 위치와는 어긋난다) — CharacterShadow가 idle 프레임을 재서 이 어긋남을 보정하는 것과 똑같은
# 이유로, 여기서도 같은 측정값(art.end.y)을 "발밑 y"로 써서 ShadowLayer.lay_on_ground()에 넘긴다.
#
# [스케일을 되돌려서 넘기는 이유]
# _measure_art()는 결과를 sprite.scale이 이미 곱해진 "플레이어 기준 좌표"로 돌려준다(NPC 쪽
# 그림자는 그 좌표를 그대로 최종 위치에 쓰므로 문제가 없다). 반면 lay_on_ground()의 offset
# 계산은 스케일이 적용되기 "전"(텍스처 원본 픽셀) 좌표계에서 이뤄지는 값이라, 여기서는 스케일을
# 다시 나눠 원본 기준으로 되돌린 뒤 lay_on_ground()의 extra_scale 인자로 따로 넘겨 그 안에서
# 다시 곱하게 한다. player.tscn의 AnimatedSprite2D는 position=0이라 이 역산이 정확히 들어맞는다
# (프롭은 scale=1이라 애초에 이 문제 자체가 없었다).
#
# [왜 매 프레임 다시 눕히지 않는가]
# 플레이어의 idle/walk/run 애니메이션은 전부 같은 64px 프레임 캔버스를 쓴다(NPC 일부처럼
# 32px/64px가 섞여 있지 않다) — 그래서 attach() 시점에 idle 프레임 하나로 잰 발밑 위치가
# 모든 애니메이션에 그대로 들어맞고, 프롭처럼 한 번만 눕혀두면 된다. 이후 애니메이션/프레임이
# 바뀌어도 회전이 없으므로(캐릭터가 화면에서 스스로 도는 일은 없다) transform을 다시 계산할
# 필요가 없다 — 낙엽 그림자(leaf_emitter.gd)와 달리 매 프레임 재계산하지 않는 이유다.

var _target: Node2D
var _source: AnimatedSprite2D


static func attach(character: Node2D, sprite: AnimatedSprite2D) -> PlayerShadow:
	var layer := ShadowLayer.find_layer(character)
	if layer == null:
		return null

	var art := CharacterShadow._measure_art(sprite)
	if art.size.x <= 0.0 or sprite.scale.y == 0.0:
		return null

	var shadow := PlayerShadow.new()
	shadow.name = "%sShadow" % character.name
	shadow.sprite_frames = sprite.sprite_frames # 같은 리소스를 그대로 공유(복제 아님)
	shadow.centered = sprite.centered
	# 완전 불투명 검정으로 그린다 — 실제 반투명함은 ShadowLayer의 self_modulate 알파 하나로만
	shadow.modulate = Color(0, 0, 0, 1)
	shadow._target = character
	shadow._source = sprite

	var foot_y_raw := art.end.y / sprite.scale.y
	ShadowLayer.lay_on_ground(shadow, Vector2.ZERO, foot_y_raw, sprite.scale.y)

	layer.add_child(shadow)
	shadow._sync_from_source()
	shadow._follow_target()
	return shadow


func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_source):
		queue_free()
		return
	_sync_from_source()
	_follow_target()


# 실제 스프라이트가 지금 재생 중인 애니메이션/프레임/좌우반전을 그대로 따라간다. 값이 바뀐
# 프레임에만 실제로 대입한다(애니메이션 프레임 대입 자체가 공짜는 아니라서)
func _sync_from_source() -> void:
	if animation != _source.animation:
		animation = _source.animation
	if frame != _source.frame:
		frame = _source.frame
	if flip_h != _source.flip_h:
		flip_h = _source.flip_h


func _follow_target() -> void:
	global_position = _target.global_position
	# 플레이어는 전투로 넘어가는 동안 잠시 숨겨진다 — 그림자만 남아 있지 않도록 함께 따라간다
	visible = _target.visible
