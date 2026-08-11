extends NPC

# 카밀(감시자 동료). 유서프가 정체를 밝히는 노드(yusuf_secret_stage2)를 본 뒤에만 마을에 등장한다.
# 그 전에는 숨김+비활성(감지/상호작용 불가) 상태로 있다가, 조건이 충족되면 즉시 나타난다
# (유서프와의 대화 직후 마을을 떠나지 않아도 바로 등장하도록 _process에서 가볍게 재확인).

const SPRITE_FRAMES := preload("res://npc/kamil_sprite_frames.tres")
const APPEAR_AFTER_SEEN := "yusuf_secret_stage2" # 이 노드를 본 뒤부터 등장

# 2부 결정적 선택의 두 결과 노드. 이 중 하나에서 대화가 끝나면 최종 엔딩으로 전환한다
# (엘라라가 elara_ending_trigger로 1부 엔딩을 띄우는 것과 같은 패턴)
const FINAL_CHOICE_NODE_IDS := ["kamil_choice_reveal", "kamil_choice_secret"]

var _active: bool = false # 현재 마을에 나타나 상호작용 가능한 상태인지


# 카밀 전용 설정을 고정한 뒤 기본 NPC 초기화를 이어서 실행하고, 등장 조건에 맞춰 표시 여부를 정한다
func _ready() -> void:
	dialogue_tree = DialogueData.KAMIL_DIALOGUE
	dialogue_start_id = "kamil_greeting"
	met_flag_name = "met_kamil"
	npc_id = "kamil"
	super._ready()

	$AnimatedSprite2D.sprite_frames = SPRITE_FRAMES
	$AnimatedSprite2D.scale = Vector2(1.45, 1.45)
	$AnimatedSprite2D.play("idle")

	_refresh_presence() # 재입장 등으로 이미 조건을 만족한 상태라면 처음부터 활성


# 비활성일 때는 배회/상호작용을 멈추고 등장 조건만 계속 확인하다가, 충족되면 활성으로 전환.
# 활성이면 기본 NPC의 배회 로직(super._process)을 그대로 수행한다
func _process(delta: float) -> void:
	if not _active:
		_refresh_presence()
		return
	super._process(delta)


# 등장 조건(APPEAR_AFTER_SEEN 노드를 봤는지)을 확인해 표시/감지 상태를 맞춘다.
# 한 번 활성화되면 다시 숨기지 않는다
func _refresh_presence() -> void:
	if _active:
		return
	if GameState.has_seen_node(APPEAR_AFTER_SEEN):
		_active = true
		visible = true
		monitoring = true # Area2D 감지 재개 → 이제부터 [E] 안내/상호작용 가능
	else:
		visible = false
		monitoring = false # 감지 꺼서 안내/상호작용 자체가 안 열리게 함


# 기본 동작(안내 문구 복원)을 그대로 수행한 뒤, 2부 결정적 선택으로 대화가 끝났다면 최종 엔딩으로 전환
func _on_dialogue_ended(last_node_id: String = "") -> void:
	super._on_dialogue_ended()
	if last_node_id in FINAL_CHOICE_NODE_IDS:
		_trigger_final_ending()


# truth_revealed 값에 대응하는 최종 엔딩 씬으로 전환
func _trigger_final_ending() -> void:
	var ending := GameState.check_final_ending()
	SceneManager.change_scene("res://endings/ending_final_%s.tscn" % ending, "")
