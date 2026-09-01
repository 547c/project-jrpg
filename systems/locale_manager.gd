extends Node

# 언어 설정 (autoload). 한국어가 기본이고 영어는 선택 번역이다.
#
# UI 문자열은 i18n/ui_strings.csv를 런타임에 직접 파싱해 TranslationServer에 등록한다 —
# 에디터의 CSV 임포트(.translation 생성)에 기대면 헤드리스 부팅에서 번역이 통째로 빠지므로,
# 임포트 산출물 없이도 항상 같은 결과가 나오도록 직접 읽는다.
# CSV의 key 자체가 한국어 원문이라, 번역이 없거나 CSV 로드가 실패해도 tr()은 한국어를 그대로 돌려준다.

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "ko"
const SUPPORTED_LOCALES: Array[String] = ["ko", "en"]

const CSV_PATH := "res://i18n/ui_strings.csv"
const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "display"
const CONFIG_KEY := "locale"

const TRANSLATION_NOTICE := "Note: this English translation was made with translation tools and may contain awkward phrasing that affects your experience."

var _locale: String = DEFAULT_LOCALE
var _notice_root: Control


func _ready() -> void:
	_load_ui_translations()
	_build_notice_popup()
	_locale = _read_saved_locale()
	TranslationServer.set_locale(_locale)


func current_locale() -> String:
	return _locale


func is_english() -> bool:
	return _locale == "en"


# 한국어 <-> 영어 전환. 한국어에서 영어로 넘어가는 순간에만 기계번역 안내를 띄운다
func toggle_locale() -> void:
	set_locale("en" if _locale == "ko" else "ko")


func set_locale(locale: String) -> void:
	if locale == _locale or not locale in SUPPORTED_LOCALES:
		return

	var was_korean := _locale == "ko"
	_locale = locale
	TranslationServer.set_locale(locale)
	_save_locale()
	locale_changed.emit(locale)

	if was_korean and locale == "en":
		_show_notice()


# 다음에 누르면 바뀔 언어의 이름 (언어 토글 버튼 라벨용 — 그 자체로 어느 언어인지 보이므로 번역하지 않는다)
func next_locale_label() -> String:
	return "English" if _locale == "ko" else "한국어"


func _read_saved_locale() -> String:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return DEFAULT_LOCALE
	var saved := str(config.get_value(CONFIG_SECTION, CONFIG_KEY, DEFAULT_LOCALE))
	return saved if saved in SUPPORTED_LOCALES else DEFAULT_LOCALE


func _save_locale() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH) # 다른 설정이 생겼을 때 덮어쓰지 않도록 기존 내용을 먼저 읽는다
	config.set_value(CONFIG_SECTION, CONFIG_KEY, _locale)
	config.save(CONFIG_PATH)


# CSV 한 줄 = key(한국어 원문) + locale별 번역. locale 열마다 Translation을 만들어 등록한다.
# ko 열도 같이 등록해야 한국어일 때 TranslationServer가 fallback locale(en)로 새지 않는다
func _load_ui_translations() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("LocaleManager: %s 를 열지 못해 UI 번역 없이 진행합니다" % CSV_PATH)
		return

	var header := file.get_csv_line()
	if header.size() < 2:
		return

	var by_column: Dictionary = {}
	for i in range(1, header.size()):
		var locale := header[i].strip_edges()
		if locale == "":
			continue
		var translation := Translation.new()
		translation.locale = locale
		by_column[i] = translation

	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty() or line[0].strip_edges() == "":
			continue
		for i in by_column:
			if i < line.size() and line[i] != "":
				by_column[i].add_message(line[0], line[i])

	for translation in by_column.values():
		TranslationServer.add_translation(translation)


func _build_notice_popup() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)

	_notice_root = Control.new()
	_notice_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notice_root.visible = false
	layer.add_child(_notice_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	_notice_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	panel.offset_left = -230.0
	panel.offset_top = -90.0
	panel.offset_right = 230.0
	panel.offset_bottom = 90.0
	_notice_root.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var label := Label.new()
	label.text = TRANSLATION_NOTICE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(label)

	var button := Button.new()
	button.text = "OK"
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(_on_notice_dismissed)
	column.add_child(button)


func _show_notice() -> void:
	if _notice_root != null:
		_notice_root.visible = true


func _on_notice_dismissed() -> void:
	SFXPlayer.play(SFXPlayer.UI_CLICK_SOUND)
	_notice_root.visible = false


func is_notice_visible() -> bool:
	return _notice_root != null and _notice_root.visible
