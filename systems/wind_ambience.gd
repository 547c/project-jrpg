extends Node

# 바람 소리 (오토로드). WindSystem.wind_changed를 구독해 wind_strength에 맞춰 볼륨을 실시간으로
# 바꾸며, 야외 씬(배경 낙엽이 있는 씬)에서만 틀어둔다. ForegroundLeaves/GodRays와 완전히 같은
# 기준("leaf_emitter" 그룹 노드가 지금 씬에 있는가)으로 켜고 끈다 — 전투/동굴에서는 안 들린다.
#
# [폴링이 아니라 시그널을 쓰는 이유]
# wind_system.gd 자체 주석에 이미 "화면 흔들림, 바람 소리처럼 매 프레임 정밀도가 필요 없는
# 소비자는 wind_changed 시그널을 쓰라"고 못 박혀 있다(값이 CHANGE_SIGNAL_THRESHOLD=0.01 이상
# 바뀔 때만 쏜다) — 볼륨 하나 세팅하는 비용 자체는 미미하지만, 이미 있는 그 설계를 그대로 따른다.
#
# [SFXPlayer/MusicManager와 다른 이유]
# SFXPlayer는 겹쳐 울리는 짧은 원샷용 풀이고, MusicManager는 트랙 전환용 크로스페이드 2트랙
# 구조라 — 둘 다 "하나를 계속 틀어두고 볼륨만 연속적으로 바꾸는" 이 용도와는 안 맞는다. 그냥
# AudioStreamPlayer 하나로 충분해서 SFXPlayer처럼 코드에서 직접 만든다(전용 씬 파일 없음).

const STREAM_PATH := "res://assets/sfx/wind.ogg"
const MIN_VOLUME_DB := -15.0 # 잔잔할 때(wind_strength=0) — 은은하게 들리는 수준
const MAX_VOLUME_DB := 4.0 # 돌풍일 때(wind_strength=1) — 배경음악(-20dB)보다 확실히 크게

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var stream := load(STREAM_PATH) as AudioStreamOggVorbis
	# .ogg import 기본값이 loop=false라, 반복 재생은 여기서 코드로 강제한다
	stream.loop = true
	_player.stream = stream
	_player.volume_db = MIN_VOLUME_DB
	add_child(_player)

	WindSystem.wind_changed.connect(_on_wind_changed)


func _process(_delta: float) -> void:
	var should_play := get_tree().get_first_node_in_group("leaf_emitter") != null
	if should_play and not _player.playing:
		_player.play()
	elif not should_play and _player.playing:
		_player.stop()


func _on_wind_changed(strength: float) -> void:
	_player.volume_db = lerpf(MIN_VOLUME_DB, MAX_VOLUME_DB, strength)
