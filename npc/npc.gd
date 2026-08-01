class_name NPC
extends Area2D

@export var dialogue_tree: Array = DialogueData.TEST_DIALOGUE.duplicate(true) # 이 NPC가 재생할 대화 트리 (지금은 테스트용 기본값)
@export var dialogue_start_id: String = "start" # 대화를 시작할 노드 id
@export var met_flag_name: String = "" # 대화가 시작되면 true로 설정할 GameState 플래그 이름 (예: "met_elara"), 없으면 ""

@onready var _interact_prompt: Label = $InteractPrompt

var _player_in_range: bool = false # 플레이어가 상호작용 범위 안에 있는지 여부


# 감지 영역 시그널을 연결하고 안내 문구를 초기 상태로 숨김
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_interact_prompt.hide()


# 플레이어가 범위에 들어오면 "말 걸기" 안내를 표시
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_interact_prompt.show()


# 플레이어가 범위를 벗어나면 안내를 숨김
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_interact_prompt.hide()


# 범위 안에서 상호작용 입력이 들어오면 대화를 시작
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		_start_dialogue()


# 씬에서 DialogueBox를 찾아 이 NPC의 대화 트리로 대화를 시작하고, 이 NPC를 만났음을 GameState에 기록
func _start_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if dialogue_box == null:
		return

	if met_flag_name != "":
		GameState.set_flag(met_flag_name, true)

	if not dialogue_box.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	_interact_prompt.hide()
	dialogue_box.start_dialogue(dialogue_tree, dialogue_start_id)


# 대화가 끝났을 때, 플레이어가 아직 범위 안이면 안내 문구를 다시 표시
func _on_dialogue_ended() -> void:
	if _player_in_range:
		_interact_prompt.show()
