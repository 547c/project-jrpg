extends Node

# 짧은 일회성 효과음(상자 열기, 아이템/골드 획득, UI 클릭, 문/포탈 전환 등)을 재생하는 공용 autoload.
# 발소리(player.gd)나 대화 bleep(typewriter.gd)처럼 이미 있는 AudioStreamPlayer 재생 방식을 그대로
# 따르되, 이 소리들은 서로 다른 여러 곳(상자+골드 획득처럼 거의 동시)에서 겹쳐 울릴 수 있어
# 플레이어 하나를 재사용하는 대신 작은 풀(POOL_SIZE)을 라운드로빈으로 돌려 서로 끊기지 않게 한다.
# 호출부는 SFXPlayer.play("res://assets/sfx/.../파일.wav")만 부르면 되고, 새 AudioStreamPlayer를
# 직접 만들거나 관리할 필요가 없다 — "공용 함수 하나로 묶기"의 핵심이 이 함수 하나다.

const POOL_SIZE := 4
# 발소리(-14dB)보다는 도드라지되 대화 bleep/음악을 압도하지 않는 선. 필요하면 호출부에서 개별 조정
const DEFAULT_VOLUME_DB := -6.0

var _players: Array[AudioStreamPlayer] = []
var _next_index: int = 0


func _ready() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


# stream_path의 효과음을 재생. 풀에서 순서대로 플레이어를 하나씩 돌려써서, 짧은 시간 안에
# 여러 소리가 겹쳐도(최대 POOL_SIZE개까지 동시) 서로 잘리지 않는다
func play(stream_path: String, volume_db: float = DEFAULT_VOLUME_DB, pitch_scale: float = 1.0) -> void:
	var stream := load(stream_path) as AudioStream
	if stream == null:
		return

	var player := _players[_next_index]
	_next_index = (_next_index + 1) % _players.size()

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
