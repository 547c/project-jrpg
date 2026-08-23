extends Control

@onready var _play_button: Button = $PlayButton
@onready var _load_button: Button = $LoadButton
@onready var _record_button: Button = $RecordButton
@onready var _load_hint: Label = $LoadHint


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_record_button.pressed.connect(_on_record_pressed)

	# 저장된 슬롯이 하나도 없으면 불러오기 버튼을 비활성화하고 안내를 표시
	var save_exists := SaveManager.has_any_save()
	_load_button.disabled = not save_exists
	_load_hint.visible = not save_exists

	MusicManager.play("Title Theme")


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
