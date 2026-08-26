extends Node

# 오토로드. "지금 바람이 얼마나 센가"(0~1)를 매 프레임 계산해서 다른 시스템(나무/식생 흔들림,
# 낙엽)이 구독할 수 있게 값과 시그널 둘 다로 내놓는다.
#
# [값 vs 시그널]
# 실제로 매 프레임 바람 세기가 필요한 소비자(나무/식생/낙엽, 도합 200개 이상 될 수 있음)는
# 자기 _process()에서 wind_strength를 직접 읽는 쪽이 훨씬 싸다 — 시그널 emit 하나에 리스너
# 200개가 콜백으로 걸려있는 것과, 그 200개가 각자 필요할 때 변수 하나 읽는 것은 결과는 같아도
# 후자가 함수 호출 오버헤드가 없다. wind_changed 시그널은 "매 프레임 필요는 없고 값이 크게
# 바뀔 때만 반응하면 되는" 미래의 소비자(화면 흔들림, 바람 소리 등)를 위한 보조 통로다.
#
# [리듬 설계]
# 서로 배수 관계가 아닌 두 주기의 사인파를 더한 뒤, 그 결과에 지수를 씌워 낮은 쪽으로 눌러
# 찌그러뜨린다 — 그래야 "대부분 잔잔하다가 두 파동이 우연히 겹치는 짧은 구간에만 돌풍처럼
# 확 세지는" 비대칭 리듬이 나온다(단순히 사인파를 0~1로 정규화만 하면 세고 약한 시간이 똑같이
# 절반씩이라 "가끔 돌풍" 느낌이 안 난다). 거기에 약한 노이즈를 얹어 완전히 규칙적으로 반복되는
# 티가 덜 나게 한다.

signal wind_changed(strength: float)

const SLOW_PERIOD := 23.0 # 초 — 돌풍이 오가는 큰 주기
const FAST_PERIOD := 5.4 # 초 — 그 안에서 요동치는 잔물결 (SLOW_PERIOD와 정수배가 아니게 골라 반복이 덜 티나게 함)
const GUST_SHARPNESS := 2.6 # 클수록 "평소엔 낮게 깔려있다가 짧게만 확 솟는" 모양이 됨
const NOISE_AMOUNT := 0.08
const NOISE_SPEED := 0.6
const CHANGE_SIGNAL_THRESHOLD := 0.01 # 이만큼 이상 바뀌었을 때만 wind_changed를 쏜다(스팸 방지)
# 등록된 머티리얼에 실제로 값을 밀어넣는 것도 이만큼 이상 바뀌었을 때만 한다 — 나무/식생이
# 200개 넘게 있으면 ShaderMaterial.set_shader_parameter() 자체가(디스패치 오버헤드가 아니라
# 그 호출 자체가) 실측으로 프레임당 0.5ms 넘게 나가서, 매 프레임 하는 대신 값이 눈에 띄게
# 바뀔 때만 몰아서 갱신한다 — 0.015 정도 차이는 흔들림 폭에 몇 % 차이라 눈으로 구분 안 된다
const MATERIAL_PUSH_THRESHOLD := 0.015

var wind_strength: float = 0.0
var _last_signaled_strength: float = 0.0

var _time: float = 0.0
var _noise := FastNoiseLite.new()

# [흔들림 셰이더 머티리얼을 여기서 한꺼번에 갱신하는 이유]
# 처음엔 tree_prop.gd/vegetation_prop.gd가 각자 _process()에서 WindSystem.wind_strength를
# 읽어 자기 머티리얼에 밀어넣게 했는데, 마을에 나무/식생이 200개 넘게 있다 보니(52+172)
# 실측 결과 그 방식만으로 프레임당 0.55ms가 나갔다 — 값 자체를 읽고 셰이더 파라미터 하나
# 세팅하는 일은 극히 싸지만, 그걸 "노드 200여 개의 개별 _process() 호출"로 흩어놓으면
# 스크립트 VM의 함수 호출/디스패치 오버헤드만 200번 넘게 쌓인다. 대신 나무/식생은 자기
# 머티리얼을 여기(register_material)에 등록만 해두고, 실제 갱신은 이 _process() 하나가
# 배열을 훑으며 한 번에 처리한다 — 같은 일을 함수 호출 1번 안에서 처리하는 셈이라 훨씬 싸다.
var _materials: Array[ShaderMaterial] = []
var _last_pushed_strength: float = -1.0 # 실제로 머티리얼에 밀어넣은 마지막 값(-1은 "아직 한 번도 안 밀어넣음")


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_time = randf_range(0.0, 100.0) # 매 판마다 같은 시점에 같은 리듬으로 시작하지 않게


func _process(delta: float) -> void:
	_time += delta

	var slow := sin(_time * TAU / SLOW_PERIOD) * 0.5 + 0.5 # 0~1
	var fast := sin(_time * TAU / FAST_PERIOD) * 0.5 + 0.5 # 0~1
	var combined := (slow * 0.65 + fast * 0.35)
	var gust := pow(combined, GUST_SHARPNESS) # 낮은 쪽으로 눌러 "평소엔 잔잔" 비대칭을 만듦
	var noise := _noise.get_noise_1d(_time * NOISE_SPEED) * NOISE_AMOUNT

	wind_strength = clampf(gust + noise, 0.0, 1.0)
	# _last_signaled_strength(마지막으로 emit한 값)와 비교해야 하는데 wind_strength 자기 자신과
	# 비교하고 있었다 — wind_strength가 매 프레임 갱신되니 사실상 "한 프레임 전 값"과 비교하는
	# 셈이라 문턱을 거의 못 넘어 시그널이 사실상 처음 한 번 말고는 안 나가던 버그
	if absf(wind_strength - _last_signaled_strength) >= CHANGE_SIGNAL_THRESHOLD:
		_last_signaled_strength = wind_strength
		wind_changed.emit(wind_strength)

	if absf(wind_strength - _last_pushed_strength) >= MATERIAL_PUSH_THRESHOLD:
		_last_pushed_strength = wind_strength
		for material in _materials:
			material.set_shader_parameter("wind_strength", wind_strength)


# 나무/식생 흔들림 머티리얼을 등록한다 — 등록해두면 매 프레임 wind_strength가 자동으로
# 갱신된다(호출부가 따로 _process를 두지 않아도 됨). 씬이 없어질 때는 반드시 unregister_material로
# 짝을 맞춰 빼야 한다 — 안 그러면 이 배열이 머티리얼을 계속 참조하고 있어 씬을 오갈 때마다
# (village.tscn을 나갔다 다시 들어올 때마다) 이전 방문의 나무 머티리얼이 계속 쌓이는 누수가 된다
func register_material(material: ShaderMaterial) -> void:
	if material == null or _materials.has(material):
		return
	_materials.append(material)
	# 마지막으로 밀어넣은 값과 맞춰둔다 — 안 그러면 다음 큰 변화가 있을 때까지(MATERIAL_PUSH_THRESHOLD
	# 문턱을 넘을 때까지) 이 머티리얼만 셰이더 기본값(0)에 머물러 방금 등록된 다른 나무들과 어긋난다
	if _last_pushed_strength >= 0.0:
		material.set_shader_parameter("wind_strength", _last_pushed_strength)


func unregister_material(material: ShaderMaterial) -> void:
	_materials.erase(material)
