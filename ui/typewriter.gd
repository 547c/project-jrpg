class_name Typewriter
extends RefCounted

# 한 글자씩 순차 표시하는 타이핑 효과 + bleep 효과음을 담당하는 공용 헬퍼.
# DialogueBox와 CutsceneBox처럼 서로 다른 Label/AudioStreamPlayer를 쓰는 UI들이
# 동일한 타이핑 로직(세대 카운터 기반 레이스 방지 포함)을 공유하기 위해 분리함.

const TYPING_CHAR_DELAY := 0.03
const BLEEP_DIR := "res://assets/sfx/dmochas-dialogue_bleeps_pack/ogg/"
const BLEEP_COUNT := 30
const BLEEP_PITCH_MIN := 0.95
const BLEEP_PITCH_MAX := 1.05

var is_typing: bool = false

var _label: Label
var _bleep_player: AudioStreamPlayer
var _bleep_sounds: Array[AudioStream] = []

var _full_text: String = "" # 스킵 시 즉시 표시할, 이번에 보여줘야 할 전체 텍스트
var _generation: int = 0 # 타이핑 세션 번호 (새 타이핑/스킵마다 증가해 이전 코루틴을 무효화)


func _init(label: Label, bleep_player: AudioStreamPlayer) -> void:
	_label = label
	_bleep_player = bleep_player
	for i in range(1, BLEEP_COUNT + 1):
		_bleep_sounds.append(load("%sbleep%03d.ogg" % [BLEEP_DIR, i]))


# 새 텍스트의 타이핑 애니메이션을 시작. 세대 번호를 올려 이전에 진행 중이던 타이핑 코루틴을 무효화시킴
func start(full_text: String) -> void:
	_generation += 1
	_full_text = full_text
	_label.text = ""
	is_typing = true
	_type(full_text, _generation)


# 한 글자씩 순차적으로 텍스트를 표시하며, 공백이 아닌 글자마다 bleep 효과음을 재생.
# 자신의 세대(generation)가 더 이상 최신이 아니면(스킵되었거나 새 타이핑이 시작됐으면) 즉시 중단
func _type(full_text: String, generation: int) -> void:
	for i in range(full_text.length()):
		if generation != _generation:
			return
		var ch := full_text[i]
		_label.text = full_text.substr(0, i + 1)
		if ch.strip_edges() != "":
			_play_bleep()
		await (Engine.get_main_loop() as SceneTree).create_timer(TYPING_CHAR_DELAY).timeout

	if generation != _generation:
		return
	_label.text = full_text
	is_typing = false


# 타이핑 중인 텍스트를 즉시 전부 표시 (세대 번호를 올려 진행 중이던 코루틴을 무효화)
func skip() -> void:
	_generation += 1
	_label.text = _full_text
	is_typing = false


# bleep 효과음 중 하나를 무작위로 골라, 매번 살짝 다른 피치로 재생
func _play_bleep() -> void:
	if _bleep_sounds.is_empty():
		return
	_bleep_player.stream = _bleep_sounds[randi() % _bleep_sounds.size()]
	_bleep_player.pitch_scale = randf_range(BLEEP_PITCH_MIN, BLEEP_PITCH_MAX)
	_bleep_player.play()
