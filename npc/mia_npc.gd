extends NPC

# 미아 전용 설정: 대화 트리/시작 노드/met 플래그를 고정한 뒤 기본 NPC 초기화를 이어서 실행
func _ready() -> void:
	dialogue_tree = DialogueData.MIA_DIALOGUE
	dialogue_start_id = "mia_greeting"
	met_flag_name = "met_mia"
	super._ready()
