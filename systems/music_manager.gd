extends Node

# 배경음악 매니저 (autoload). AudioStreamPlayer 두 개(PlayerA/PlayerB)를 번갈아 사용해
# 트랙 전환마다 FADE_DURATION초 동안 크로스페이드한다. play()에 이미 재생 중인 트랙명을 다시
# 넘기면 아무것도 하지 않아(재시작 없이) 끊김 없이 유지된다. Autoload라 씬이 바뀌어도
# 노드 자체가 파괴되지 않으므로 재생이 끊기지 않는다 — 트랙이 바뀔 때만 크로스페이드로 전환한다.

const DEFAULT_VOLUME_DB := -20.0 # 기본(0dB)보다 낮게
const MUTE_VOLUME_DB := -80.0 # 사실상 무음으로 취급하는 페이드 하한
const FADE_DURATION := 1.0

# 전용 오디오 버스로 음소거를 처리 (크로스페이드 트윈이 만지는 volume_db와 완전히 독립적이라
# 페이드 도중 음소거를 켜고 꺼도 서로 간섭하지 않음). 리소스 파일 없이 코드에서 직접 버스를 만든다
const MUSIC_BUS_NAME := "Music"

const TRACK_DIR := "res://assets/bgm/xDeviruchi - 16 bit Fantasy & Adventure (2025)/Loopable + one shots/ogg/"
const TRACKS: Dictionary = {
	"Falling Apart (Prologue)": TRACK_DIR + "01 - Falling Apart (Prologue).ogg",
	"Title Theme": TRACK_DIR + "02 - Title Theme.ogg",
	"Definitely Our Town": TRACK_DIR + "03 - Definitely Our Town.ogg",
	"Silent Forest": TRACK_DIR + "04 - Silent Forest.ogg",
	"Battle 1": TRACK_DIR + "05 - Battle 1.ogg",
	"Victory!": TRACK_DIR + "06 - Victory!.ogg",
	"Frozen Abyss": TRACK_DIR + "12 - Frozen Abyss.ogg",
	"Decisive Battle 1 - Don't Be Afraid": TRACK_DIR + "13 - Decisive Battle 1 - Don't Be Afraid.ogg",
}

# "Victory!"는 짧은 원샷 축하곡이라 반복하지 않음. 나머지는 전부 루프
const NON_LOOPING_TRACKS: Array[String] = ["Victory!"]

@onready var _player_a: AudioStreamPlayer = $PlayerA
@onready var _player_b: AudioStreamPlayer = $PlayerB

var _active_player: AudioStreamPlayer
var _current_track: String = ""
var _fade_tween: Tween
var _muted: bool = false


func _ready() -> void:
	_player_a.volume_db = MUTE_VOLUME_DB
	_player_b.volume_db = MUTE_VOLUME_DB
	_active_player = _player_a

	if AudioServer.get_bus_index(MUSIC_BUS_NAME) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, MUSIC_BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
	_player_a.bus = MUSIC_BUS_NAME
	_player_b.bus = MUSIC_BUS_NAME


# 지정한 트랙을 재생. 이미 같은 트랙이 재생 중이면 아무것도 안 함(끊김 없이 유지).
# 다른 트랙이면 두 플레이어를 번갈아 써서 FADE_DURATION초짜리 크로스페이드로 부드럽게 전환한다
func play(track_name: String) -> void:
	if not TRACKS.has(track_name):
		push_warning("MusicManager: unknown track '%s'" % track_name)
		return
	if track_name == _current_track and _active_player.playing:
		return

	_current_track = track_name

	var outgoing := _active_player
	var incoming := _player_b if outgoing == _player_a else _player_a

	incoming.stream = _load_stream(track_name)
	incoming.volume_db = MUTE_VOLUME_DB
	incoming.play()

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(incoming, "volume_db", DEFAULT_VOLUME_DB, FADE_DURATION)
	if outgoing.playing:
		_fade_tween.tween_property(outgoing, "volume_db", MUTE_VOLUME_DB, FADE_DURATION)
		_fade_tween.chain().tween_callback(outgoing.stop)

	_active_player = incoming


# 재생 중인 배경음을 부드럽게 페이드 아웃하며 정지
func stop() -> void:
	_current_track = ""
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	var outgoing := _active_player
	_fade_tween = create_tween()
	_fade_tween.tween_property(outgoing, "volume_db", MUTE_VOLUME_DB, FADE_DURATION)
	_fade_tween.tween_callback(outgoing.stop)


# 음악을 음소거 (재생/크로스페이드 상태는 그대로 유지되고, Music 버스만 무음 처리됨)
func mute() -> void:
	_muted = true
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS_NAME), true)


# 음소거 해제
func unmute() -> void:
	_muted = false
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS_NAME), false)


# 현재 상태를 뒤집음 (일시정지 메뉴의 "음악 끄기/켜기" 버튼용)
func toggle_mute() -> void:
	if _muted:
		unmute()
	else:
		mute()


func is_muted() -> bool:
	return _muted


# 트랙 리소스를 로드. 이 팩(Loopable + one shots)의 곡들은 파일 전체가 이미 이음매 없이 반복되도록
# 만들어져 있어, Godot가 임의의 루프 포인트 메타데이터를 import 시 자동으로 읽어오진 않으므로
# AudioStreamOggVorbis의 loop 속성을 코드에서 직접 켜는 것으로 수동 처리한다 (Victory!만 예외)
func _load_stream(track_name: String) -> AudioStream:
	var stream := load(TRACKS[track_name]) as AudioStream
	var should_loop: bool = not NON_LOOPING_TRACKS.has(track_name)
	if stream is AudioStreamOggVorbis:
		stream.loop = should_loop
	return stream
