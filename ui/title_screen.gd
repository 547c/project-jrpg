extends Control

const UiTranslator := preload("res://systems/ui_translator.gd")
const TWINKLE_SHADER := preload("res://ui/title_screen_twinkle.gdshader")

# 연출은 전부 배경 PNG 위에 코드로만 얹는다 (에셋 자체는 건드리지 않는다).
# 각 항목을 따로 끌 수 있게 나눠 뒀으니, 거슬리는 게 있으면 인스펙터에서 그것만 꺼서 보면 된다
@export_group("배경 연출")
@export var parallax_enabled := true
@export var parallax_strength := 14.0
@export var ken_burns_enabled := true
@export var ken_burns_amount := 0.05
@export var ken_burns_period := 150.0
@export_group("입자 / 반짝임")
@export var motes_enabled := true
@export var mote_count := 48
@export var twinkle_enabled := true
@export var twinkle_strength := 0.75

# 패럴랙스로 배경을 밀어도 가장자리가 비지 않을 만큼만 키워 둔다 (parallax_strength 14px ≈ 2.4%)
const BASE_ZOOM := 1.035
const PARALLAX_SMOOTHING := 3.0

@onready var _background: TextureRect = $Background/TextureRect
@onready var _play_button: Button = $PlayButton
@onready var _load_button: Button = $LoadButton
@onready var _load_hint: Label = $LoadHint
@onready var _settings_button: Button = $SettingsButton
@onready var _settings_overlay: Control = $SettingsOverlay
@onready var _settings_close_button: Button = $SettingsOverlay/Panel/CloseButton
@onready var _record_button: Button = $SettingsOverlay/Panel/RecordButton
@onready var _language_button: Button = $SettingsOverlay/Panel/LanguageButton

var _elapsed := 0.0
var _parallax := Vector2.ZERO
var _twinkle_layer: TextureRect
var _motes: CPUParticles2D


func _ready() -> void:
	UiTranslator.bind(self)
	_play_button.pressed.connect(_on_play_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_record_button.pressed.connect(_on_record_pressed)
	_language_button.pressed.connect(_on_language_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_settings_close_button.pressed.connect(_on_settings_close_pressed)
	_refresh_language_button()

	# 저장된 슬롯이 하나도 없으면 불러오기 버튼을 비활성화하고 안내를 표시
	var save_exists := SaveManager.has_any_save()
	_load_button.disabled = not save_exists
	_load_hint.visible = not save_exists

	MusicManager.play("Title Theme")

	_setup_effects()


func _setup_effects() -> void:
	if twinkle_enabled:
		_build_twinkle_layer()
	if motes_enabled:
		_build_motes()
	set_process(parallax_enabled or ken_burns_enabled)
	_apply_background_transform()


func _process(delta: float) -> void:
	_elapsed += delta
	if parallax_enabled:
		var half := size * 0.5
		var from_center := (get_local_mouse_position() - half) / maxf(1.0, half.x)
		var target := -from_center.limit_length(1.0) * parallax_strength
		_parallax = _parallax.lerp(target, 1.0 - exp(-PARALLAX_SMOOTHING * delta))
	_apply_background_transform()


func _apply_background_transform() -> void:
	var zoom := BASE_ZOOM
	if ken_burns_enabled:
		# 코사인이라 양 끝에서 느려진다 — 확대가 멈췄다 되돌아가는 지점이 티나지 않는다
		zoom += ken_burns_amount * (0.5 - 0.5 * cos(TAU * _elapsed / ken_burns_period))
	_background.pivot_offset = _background.size * 0.5
	_background.scale = Vector2.ONE * zoom
	_background.position = _parallax


# 배경과 똑같은 그림을 한 장 더 겹쳐 깔고, 셰이더가 그중 "하늘의 작은 밝은 점"만 가산 합성으로
# 밝혔다 어둡게 한다. 배경의 자식이라 패럴랙스/줌을 그대로 따라간다
func _build_twinkle_layer() -> void:
	_twinkle_layer = TextureRect.new()
	_twinkle_layer.texture = _background.texture
	_twinkle_layer.expand_mode = _background.expand_mode
	_twinkle_layer.stretch_mode = _background.stretch_mode
	_twinkle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_twinkle_layer.set_anchors_preset(Control.PRESET_FULL_RECT)

	var material := ShaderMaterial.new()
	material.shader = TWINKLE_SHADER
	material.set_shader_parameter("strength", twinkle_strength)
	_twinkle_layer.material = material
	_background.add_child(_twinkle_layer)


func _build_motes() -> void:
	_motes = CPUParticles2D.new()
	_motes.texture = _build_mote_texture()
	_motes.amount = mote_count
	_motes.lifetime = 12.0
	_motes.preprocess = 12.0 # 화면을 켜자마자 이미 떠다니고 있던 것처럼 시작
	_motes.randomness = 0.6
	_motes.local_coords = false
	_motes.position = size * 0.5
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = size * 0.5
	_motes.direction = Vector2(0, -1)
	_motes.spread = 22.0
	_motes.gravity = Vector2(0, -5.0)
	_motes.initial_velocity_min = 4.0
	_motes.initial_velocity_max = 13.0
	_motes.tangential_accel_min = -3.0
	_motes.tangential_accel_max = 3.0
	_motes.scale_amount_min = 1.2
	_motes.scale_amount_max = 2.8

	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0),
	])
	_motes.color_ramp = fade

	# 노을의 따뜻한 먼지와 맥 기운의 푸른 빛이 섞이도록 입자마다 색을 다르게 뽑는다
	var hues := Gradient.new()
	hues.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	hues.colors = PackedColorArray([
		Color(1.0, 0.86, 0.62), Color(1.0, 0.95, 0.85), Color(0.62, 0.86, 1.0),
	])
	_motes.color_initial_ramp = hues

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_motes.material = material

	add_child(_motes)
	move_child(_settings_overlay, -1) # 설정 팝업은 입자보다 위에 떠 있어야 한다


func _build_mote_texture() -> ImageTexture:
	var image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0.18))
	image.set_pixel(1, 0, Color(1, 1, 1, 0.55))
	image.set_pixel(0, 1, Color(1, 1, 1, 0.55))
	image.set_pixel(2, 1, Color(1, 1, 1, 0.55))
	image.set_pixel(1, 2, Color(1, 1, 1, 0.55))
	image.set_pixel(1, 1, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(image)


# PLAY 버튼을 누르면 SceneManager가 마을 씬으로 교체하고 (처음이면) 오프닝 컷신부터 진행
func _on_play_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	SceneManager.start_game()


# LOAD 버튼: 슬롯 선택 메뉴를 불러오기 모드로 연다 (버튼이 비활성화 상태면 애초에 눌리지 않음)
func _on_load_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	SaveSlotMenu.open_load_mode()


# 기록 버튼: 엔딩 도감을 연다 (아직 본 엔딩이 없어도 잠긴 목록을 볼 수 있으므로 항상 활성)
func _on_record_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	EndingRecordMenu.open()


func _on_language_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	LocaleManager.toggle_locale()
	_refresh_language_button()


func _on_settings_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_settings_overlay.visible = true


func _on_settings_close_pressed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_settings_overlay.visible = false


func _refresh_language_button() -> void:
	_language_button.text = LocaleManager.next_locale_label()
