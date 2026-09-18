extends Control

const UiTranslator := preload("res://systems/ui_translator.gd")
const TWINKLE_SHADER := preload("res://ui/title_screen_twinkle.gdshader")
const LOGO_SHINE_SHADER := preload("res://ui/title_screen_logo_shine.gdshader")
const BUTTON_SHINE_SHADER := preload("res://ui/title_screen_button_shine.gdshader")

class ButtonFx:
	var button: Button
	var glow: TextureRect
	var material: ShaderMaterial
	var width := 0.0
	var proximity := 0.0
	var slide := 0.0
	var phase := 0.0

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
@export_group("로고 / 메뉴 빛")
@export var logo_shine_enabled := true
@export var logo_glints_enabled := true
@export var button_shine_enabled := true
@export var button_glow_enabled := true

# 패럴랙스로 배경을 밀어도 가장자리가 비지 않을 만큼만 키워 둔다 (parallax_strength 14px ≈ 2.4%)
const BASE_ZOOM := 1.035
const PARALLAX_SMOOTHING := 3.0
const LOGO_UV_RECT := Vector4(0.0397, 0.0864, 0.4761, 0.3488)
const SHINE_CYCLE := 7.0
const BUTTON_SWEEP_DELAYS := [1.5, 1.75]
const PROXIMITY_RANGE := 160.0
const HOVER_SLIDE := 5.0
const FX_SMOOTHING := 9.0
const GLOW_PAD := Vector2(40, 14)

@onready var _parallax_root: Control = $ParallaxRoot
@onready var _background: TextureRect = $ParallaxRoot/Background/TextureRect
@onready var _play_button: Button = $ParallaxRoot/PlayButton
@onready var _load_button: Button = $ParallaxRoot/LoadButton
@onready var _load_hint: Label = $ParallaxRoot/LoadHint
@onready var _subtitle: Label = $ParallaxRoot/Subtitle
@onready var _settings_button: Button = $SettingsButton
@onready var _settings_overlay: Control = $SettingsOverlay
@onready var _settings_close_button: Button = $SettingsOverlay/Panel/CloseButton
@onready var _record_button: Button = $SettingsOverlay/Panel/RecordButton
@onready var _language_button: Button = $SettingsOverlay/Panel/LanguageButton

var _elapsed := 0.0
var _parallax := Vector2.ZERO
var _motes: CPUParticles2D
var _logo_material: ShaderMaterial
var _menu_base_positions := {}
var _button_fx: Array[ButtonFx] = []


func _ready() -> void:
	UiTranslator.bind(self, _layout_button_fx)
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
	for node: Control in [_subtitle, _play_button, _load_button, _load_hint]:
		_menu_base_positions[node] = node.position
	if twinkle_enabled:
		_add_background_overlay(TWINKLE_SHADER).set_shader_parameter("strength", twinkle_strength)
	if logo_shine_enabled or logo_glints_enabled:
		_build_logo_layer()
	if motes_enabled:
		_build_motes()
	if button_shine_enabled or button_glow_enabled:
		_build_button_fx()
	_apply_background_transform()


func _process(delta: float) -> void:
	_elapsed += delta
	if parallax_enabled:
		var half := size * 0.5
		var from_center := (get_local_mouse_position() - half) / maxf(1.0, half.x)
		var target := -from_center.limit_length(1.0) * parallax_strength
		_parallax = _parallax.lerp(target, 1.0 - exp(-PARALLAX_SMOOTHING * delta))
	_update_button_fx(delta)
	_apply_background_transform()


func _apply_background_transform() -> void:
	var zoom := BASE_ZOOM
	if ken_burns_enabled:
		# 코사인이라 양 끝에서 느려진다 — 확대가 멈췄다 되돌아가는 지점이 티나지 않는다
		zoom += ken_burns_amount * (0.5 - 0.5 * cos(TAU * _elapsed / ken_burns_period))
	_background.pivot_offset = _background.size * 0.5
	_background.scale = Vector2.ONE * zoom
	_parallax_root.position = _parallax

	# 메뉴 글자까지 같이 확대하면 픽셀 폰트가 뭉개지니, 배경 확대로 로고가 밀려나는 만큼만 옮겨서 따라가게 한다
	var pivot := _parallax_root.size * 0.5
	for node: Control in _menu_base_positions:
		var base: Vector2 = _menu_base_positions[node]
		var anchor := base + Vector2(0, node.size.y * 0.5)
		node.position = base + (anchor - pivot) * (zoom - 1.0)
	for fx in _button_fx:
		fx.button.position.x += fx.slide


func _add_background_overlay(shader: Shader) -> ShaderMaterial:
	var layer := TextureRect.new()
	layer.texture = _background.texture
	layer.expand_mode = _background.expand_mode
	layer.stretch_mode = _background.stretch_mode
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = shader
	layer.material = material
	_background.add_child(layer)
	return material


func _build_logo_layer() -> void:
	_logo_material = _add_background_overlay(LOGO_SHINE_SHADER)
	_logo_material.set_shader_parameter("logo_rect", LOGO_UV_RECT)
	_logo_material.set_shader_parameter("cycle", SHINE_CYCLE)
	_logo_material.set_shader_parameter("shine_strength", 1.0 if logo_shine_enabled else 0.0)
	_logo_material.set_shader_parameter("glint_strength", 1.0 if logo_glints_enabled else 0.0)
	_background.resized.connect(_update_logo_scale)
	_update_logo_scale()


func _update_logo_scale() -> void:
	var texture_size := _background.texture.get_size()
	var cover := maxf(_background.size.x / texture_size.x, _background.size.y / texture_size.y)
	_logo_material.set_shader_parameter("texel_per_px", 1.0 / maxf(cover, 0.0001))


func _build_button_fx() -> void:
	var glow_texture := _build_glow_texture()
	var buttons: Array[Button] = [_play_button, _load_button]
	for i in buttons.size():
		var fx := ButtonFx.new()
		fx.button = buttons[i]
		fx.phase = i * 1.9
		if button_shine_enabled:
			fx.material = ShaderMaterial.new()
			fx.material.shader = BUTTON_SHINE_SHADER
			fx.material.set_shader_parameter("cycle", SHINE_CYCLE)
			fx.material.set_shader_parameter("sweep_delay", BUTTON_SWEEP_DELAYS[i])
			fx.button.material = fx.material
		if button_glow_enabled:
			fx.glow = TextureRect.new()
			fx.glow.texture = glow_texture
			fx.glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			fx.glow.stretch_mode = TextureRect.STRETCH_SCALE
			fx.glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			fx.glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fx.glow.show_behind_parent = true
			var additive := CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			fx.glow.material = additive
			fx.button.add_child(fx.glow)
		_button_fx.append(fx)
	_layout_button_fx()
	_update_button_fx(0.0)


func _layout_button_fx() -> void:
	for fx in _button_fx:
		var font := fx.button.get_theme_font("font")
		var font_size := fx.button.get_theme_font_size("font_size")
		fx.width = font.get_string_size(fx.button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if fx.material:
			fx.material.set_shader_parameter("text_width", fx.width)
		if fx.glow:
			fx.glow.position = -GLOW_PAD
			fx.glow.size = Vector2(fx.width, fx.button.size.y) + GLOW_PAD * 2.0


func _update_button_fx(delta: float) -> void:
	var blend := 1.0 - exp(-FX_SMOOTHING * delta) if delta > 0.0 else 1.0
	for fx in _button_fx:
		var live := not fx.button.disabled
		var target := 0.0
		if live:
			var mouse := fx.button.get_local_mouse_position()
			var nearest := mouse.clamp(Vector2.ZERO, Vector2(fx.width, fx.button.size.y))
			target = 1.0 - smoothstep(0.0, PROXIMITY_RANGE, mouse.distance_to(nearest))
		fx.proximity = lerpf(fx.proximity, target, blend)
		var hovered := live and fx.button.is_hovered()
		fx.slide = lerpf(fx.slide, HOVER_SLIDE if hovered else 0.0, blend)
		if fx.material:
			fx.material.set_shader_parameter("proximity", fx.proximity)
			fx.material.set_shader_parameter("active", 1.0 if live else 0.0)
		if fx.glow:
			fx.glow.visible = live
			var breath := 0.5 + 0.5 * sin(_elapsed * 1.6 + fx.phase)
			fx.glow.modulate.a = 0.35 + 0.3 * breath + 0.45 * fx.proximity


func _build_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.78, 0.42, 0.42), Color(1.0, 0.66, 0.32, 0.14), Color(1.0, 0.6, 0.3, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


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
