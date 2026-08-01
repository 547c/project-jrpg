extends NPC

# 유서프 전용 설정: 대화 트리/시작 노드/met 플래그를 고정한 뒤 기본 NPC 초기화를 이어서 실행
func _ready() -> void:
	dialogue_tree = DialogueData.YUSUF_DIALOGUE
	dialogue_start_id = "yusuf_greeting"
	met_flag_name = "met_yusuf"
	super._ready()
