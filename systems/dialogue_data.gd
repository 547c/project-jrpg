class_name DialogueData
extends RefCounted

# 대화 노드 구조 예시:
# {
#     "id": String,
#     "speaker": String,
#     "text": String,
#     "narration": String,          # 기본 "". 괄호로 된 행동 묘사(지문) — 이탤릭으로 별도 표시됨.
#                                    # text 없이 narration만 있는 노드(순수 지문)도 가능.
#     "is_decisive": bool,          # 기본 false. UI 강조(금색 테두리) 용도 — 이 노드가 결정적 질문임을 표시
#     "options": [
#         {
#             "label": String,
#             "next_id": String,
#             "flag_to_set": String, # 이 옵션을 선택하면 설정할 flag, 없으면 ""(생략 가능)
#             "flag_value": bool,    # flag_to_set이 있을 때 설정할 값
#             "show_if_flag": String, # 이 flag가 true일 때만 옵션을 보여줌, 없으면 ""(항상 표시, 생략 가능)
#             "show_if_seen": String, # 이 node_id를 이미 본 적 있을 때만 옵션을 보여줌 (생략 가능)
#             "show_if_not_seen": String, # 이 node_id를 아직 안 봤을 때만 옵션을 보여줌 — show_if_seen과
#                                    # 짝지으면 "본 적 있으면 A 대신 B" 식으로 옵션을 서로 대체할 수 있음 (생략 가능)
#             "required_affinity": { "npc_id": String, "min": int },
#                                    # 지정 시, 해당 NPC 호감도가 min 이상일 때만 선택 가능. 미만이면
#                                    # 옵션은 보이되 빨간색으로 표시되고 클릭해도 안내만 뜨고 진행되지 않음 (생략 가능)
#             "affinity_change": { "npc_id": String, "amount": int },
#                                    # 지정 시, 이 옵션을 선택하면 해당 NPC 호감도를 amount만큼 증감 (생략 가능)
#             "next_id_by_affinity": { "npc_id": String, "thresholds": [int, ...], "next_ids": [String, ...] },
#                                    # 지정 시, next_id 대신 현재 호감도로 다음 노드를 고른다
#                                    # (next_ids.size() == thresholds.size() + 1). 낮은 threshold부터 비교해
#                                    # 처음 "호감도 < threshold"인 구간의 next_id를 쓰고, 전부보다 크면 마지막
#                                    # next_id(최상위 구간)를 쓴다. 예: thresholds=[40,70], next_ids=[A,B,C]
#                                    # -> <40: A, 40~69: B, 70+: C. 고정 4단계(cold/neutral/warm/trusted)
#                                    # 명칭에 안 맞는 커스텀 구간이 필요할 때 씀 (생략 가능, 있으면 next_id보다 우선)
#         },
#     ],
# }
#
# 옵션의 next_id가 이미 방문한 노드(GameState.seen_dialogue_nodes)면, DialogueBox가 그 옵션을
# 회색으로 표시하고 목록 맨 아래로 정렬한다 (다시 들을 수 있지만 시각적으로 구분됨) — 데이터에 별도 표기 불필요.
#
# 노드에 "affinity_change_on_show": { "npc_id": String, "amount": int }를 넣으면, 옵션 선택과 무관하게
# 그 노드가 화면에 표시되는 순간 호감도가 바뀐다 (선택지 없이 이어지는 서술형 노드에 쓰는 용도 —
# 옵션 선택 시 효과를 주고 싶으면 옵션의 "affinity_change"를 대신 사용).
#
# 노드에 "text_by_affinity_tier": { "npc_id": String, "cold": String, "neutral": String, "warm": String,
# "trusted": String }를 넣으면, 해당 NPC의 현재 호감도 구간(GameState.get_affinity_tier)에 맞는 문구를
# 보여준다 (구간별 문구가 없으면 "text"로 폴백). 이진 분기인 text_if_flag와 달리 4단계 분기용.
#
# 결정적 선택은 "노드를 보여주는 순간"이 아니라 "옵션을 고르는 순간" flag가 설정된다.
# 즉 결정적 노드는 보통 options에 2개(각각 다른 flag_value)를 넣어, 그중 하나를
# 고르는 행위 자체가 곧 그 선택이 되도록 구성한다.
#
# 노드에 "options"가 없거나 비어 있을 때:
# - 노드 최상위에 "next_id": String이 있으면(분기 없는 단순 다음 대사) "[계속]" 버튼을 자동으로 보여준다.
# - 없으면(진짜 종료 대사) 기본 "닫기" 버튼을 보여준다.
# 매 노드마다 종료/계속용 옵션을 직접 넣을 필요는 없다.
#
# 노드에 "text_if_flag": String을 넣으면, 그 flag가 true일 때 "text"를,
# false일 때 "text_false"를 보여준다 (조건부 대사용, 둘 다 없으면 생략 가능).

# 테스트용 예시 대화 트리 (실제 대사는 아직 없음, 구조 검증 목적)
const TEST_DIALOGUE: Array = [
	{
		"id": "start",
		"speaker": "Test NPC",
		"text": "[테스트 대사 1] 분기 선택지 예시",
		"is_decisive": false,
		"options": [
			{"label": "[테스트 선택 A]", "next_id": "branch_a"},
			{"label": "[테스트 선택 B]", "next_id": "branch_b"},
		],
	},
	{
		"id": "branch_a",
		"speaker": "Test NPC",
		"text": "[테스트 대사 2A] 선택 A로 이어지는 대사",
		"is_decisive": false,
		"options": [
			{"label": "[계속]", "next_id": "decisive_example"},
		],
	},
	{
		"id": "branch_b",
		"speaker": "Test NPC",
		"text": "[테스트 대사 2B] 선택 B로 이어지는 대사",
		"is_decisive": false,
		"options": [
			{"label": "[계속]", "next_id": "decisive_example"},
		],
	},
	{
		"id": "decisive_example",
		"speaker": "Test NPC",
		"text": "[테스트 결정적 대사] 아래 두 선택지 중 하나를 고르면 그 자체가 flag를 정함",
		"is_decisive": true,
		"options": [
			{"label": "[결정적 선택 A]", "next_id": "", "flag_to_set": "test_flag_example", "flag_value": true},
			{"label": "[결정적 선택 B]", "next_id": "", "flag_to_set": "test_flag_example", "flag_value": false},
		],
	},
]

# 엘라라(장로) 대화 트리
const ELARA_DIALOGUE: Array = [
	{
		"id": "elara_greeting",
		"speaker": "엘라라",
		"text": "오, 자네로군. 우물 일 때문에 왔겠지.",
		"text_by_affinity_tier": {
			"npc_id": "elara",
			"cold": "...무슨 일이지.",
			"neutral": "오, 자네로군. 우물 일 때문에 왔겠지.",
			"warm": "왔는가. 자네를 보면 마음이 놓이는군.",
			"trusted": "자네가 와줘서 다행이야. 요즘 자네 얼굴을 보면 든든해.",
		},
		"is_decisive": false,
		"options": [
			{"label": "[우물에 대해 묻는다]", "next_id": "elara_well"},
			{"label": "[마을에 대해 묻는다]", "next_id": "elara_village"},
			{"label": "[그냥 안부를 묻는다]", "next_id": "elara_smalltalk"},
			{"label": "[다른 사람들에 대해 묻는다]", "next_id": "elara_gossip", "show_if_flag": "met_rohan"},
			{"label": "[다녀왔다고 말한다]", "next_id": "elara_ending_check", "show_if_flag": "guardian_event_done"},
			{
				"label": "[궁금한 게 있어요, 장로님]",
				"next_id": "elara_secret_intro",
				"required_affinity": {"npc_id": "elara", "min": 60},
				"show_if_not_seen": "elara_secret_end",
			},
			{
				"label": "[그 기록에 대해서 더 생각해봤나]",
				"next_id": "elara_secret_followup",
				"show_if_seen": "elara_secret_end",
			},
			{
				"label": "[선물을 준다]",
				"give_gift": {"npc_id": "elara", "amount": 9, "next_id_success": "elara_gift_thanks", "next_id_fail": "elara_gift_none"},
			},
		],
	},
	{
		"id": "elara_gift_thanks",
		"speaker": "엘라라",
		"text": "이런 걸... 나한테? 허허, 고맙구나. 늙은이 마음이 다 따뜻해지는군.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_gift_none",
		"speaker": "엘라라",
		"narration": "(막상 건넬 것이 없다)",
		"text": "줄 게 없네요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_well",
		"speaker": "엘라라",
		"text": "사흘 전부터 한 방울도 안 나와. 이런 적은... 내 평생 처음이야.",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[심각한 건가요?]", "next_id": "elara_well_serious"},
			{"label": "[제가 도와드릴게요]", "next_id": "elara_well_help"},
		],
	},
	{
		"id": "elara_well_serious",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "심각하냐고? 물이 없으면 마을이 죽어. 그 정도로 심각해.",
		"is_decisive": false,
		"options": [
			{"label": "[왜 하필 지금인가요?]", "next_id": "elara_well_why"},
			{"label": "[알겠어요, 해결해볼게요]", "next_id": ""},
		],
	},
	{
		"id": "elara_well_why",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "낸들 알겠나. 다만... 이런 일은 늘 조용히 찾아오지, 경고도 없이.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_well_help",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "고맙구나. 숲의 로한을 먼저 만나보게. 동굴 근처에서 뭔가 봤다더군.",
		"is_decisive": false,
		"next_id": "elara_well_lore",
	},
	{
		"id": "elara_well_lore",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "...자네도 들어봤을지 모르겠군. 이 물줄기가, 실은 이 마을만의 것이 아니라는 걸.",
		"is_decisive": false,
		"options": [
			{"label": "[무슨 말씀이세요?]", "next_id": "elara_well_lore2"},
			{"label": "[알겠어요, 가볼게요]", "next_id": ""},
		],
	},
	{
		"id": "elara_well_lore2",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "오래전부터... 세상 곳곳의 물줄기가 하나둘 말라간다고 하더군. 다행히 우리 마을은 여태 무사했는데... 결국 이렇게 됐어.",
		"is_decisive": false,
		"options": [
			{"label": "[걱정되네요]", "next_id": "elara_well_lore3"},
			{"label": "[제가 알아볼게요]", "next_id": ""},
		],
	},
	{
		"id": "elara_well_lore3",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "너무 겁먹진 말게. 자네라면... 뭔가 다를 것 같은 예감이 드는군.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_ending_check",
		"speaker": "엘라라",
		"text": "...끝났나 보군. 그래, 결과는 어떻게 됐나?",
		"is_decisive": false,
		"options": [
			{"label": "[자세히 이야기한다]", "next_id": "elara_ending_reflect"},
			{"label": "[그냥 결과만 말한다]", "next_id": "elara_ending_trigger"},
		],
	},
	{
		"id": "elara_ending_reflect",
		"speaker": "엘라라",
		"text": "...그런가. 자네가 겪은 일이, 그 물줄기의 비밀에 조금은 가까워진 걸지도 모르겠군.",
		"is_decisive": false,
		"next_id": "elara_ending_trigger",
	},
	{
		"id": "elara_ending_trigger",
		"speaker": "엘라라",
		"text": "...그래. 이제 좀 지켜봐야겠군.",
		"set_flag_on_show": "part1_reported", # 엘라라 보고 완료 — 이후 objective가 2부(유서프→부두)로 넘어감
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_village",
		"speaker": "엘라라",
		"text": "작은 곳이지. 하지만 백 년 넘게 이 자리를 지켜왔어.",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[오래됐네요]", "next_id": "elara_village_old"},
			{"label": "[평화로워 보여요]", "next_id": "elara_village_peace"},
		],
	},
	{
		"id": "elara_village_old",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "그만큼 많은 걸 봐왔지. 좋은 일도, 나쁜 일도.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_village_peace",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "평화... 그래, 지금까진 그랬지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_smalltalk",
		"speaker": "엘라라",
		"text": "안부라... 다정하기도 하지. 몸은 성한가?",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[괜찮아요, 걱정 마세요]", "next_id": "elara_smalltalk_fine"},
			{"label": "[사실 좀 지쳤어요]", "next_id": "elara_smalltalk_tired"},
		],
	},
	{
		"id": "elara_smalltalk_fine",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "다행이군. 젊은이가 튼튼해야 마을도 든든하지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_smalltalk_tired",
		"affinity_change_on_show": {"npc_id": "elara", "amount": 1, "once": true},
		"speaker": "엘라라",
		"text": "쉬엄쉬엄하게. 우물이 급하다고 자네까지 쓰러지면 안 되지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_gossip",
		"speaker": "엘라라",
		"text": "[다른 사람들에 대해 물어본다]",
		"is_decisive": false,
		"options": [
			{"label": "[로한은 어떤 사람인가요?]", "next_id": "elara_about_rohan", "show_if_flag": "met_rohan"},
			{"label": "[유서프는 믿을 만한가요?]", "next_id": "elara_about_yusuf", "show_if_flag": "met_yusuf"},
			{"label": "[미아는 왜 저렇게 겁이 많나요?]", "next_id": "elara_about_mia", "show_if_flag": "met_mia"},
		],
	},
	{
		"id": "elara_about_rohan",
		"speaker": "엘라라",
		"text": "무뚝뚝하지만 마을을 아끼는 사람이야. 숲을 그만큼 잘 아는 이도 없지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_about_yusuf",
		"speaker": "엘라라",
		"text": "믿을 만하냐고... 글쎄. 유서프는 아는 게 너무 많아서 탈이지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_about_mia",
		"speaker": "엘라라",
		"text": "그 아이는... 얼마 전에 무서운 걸 봤다더군. 다그치지 말게.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_secret_intro",
		"speaker": "엘라라",
		"text": "궁금한 거라... 흠, 자네라면 얘기해도 괜찮을 것 같군.",
		"is_decisive": false,
		"options": [
			{"label": "[무슨 이야기예요?]", "next_id": "elara_secret_1"},
			{"label": "[아니에요, 다음에 물어볼게요]", "next_id": ""},
		],
	},
	{
		"id": "elara_secret_1",
		"speaker": "엘라라",
		"text": "실은... 전대 장로님께 물려받은 게 하나 있어. 아주 오래된 기록이지.",
		"is_decisive": false,
		"next_id": "elara_secret_2",
	},
	{
		"id": "elara_secret_2",
		"speaker": "엘라라",
		"text": "이런 일이... 처음이 아니라는 기록이야. 아주 먼 옛날, 물줄기가 말랐던 적이 또 있었다더군.",
		"is_decisive": false,
		"options": [
			{"label": "[그때는 어떻게 됐나요?]", "next_id": "elara_secret_3"},
			{"label": "[왜 지금까지 숨기셨어요?]", "next_id": "elara_secret_alt"},
		],
	},
	{
		"id": "elara_secret_3",
		"speaker": "엘라라",
		"text": "기록엔... 그냥 '지나갔다'고만 적혀 있어. 어떻게 해결했는지는 안 적혀 있더군. 아니면... 적을 수 없었던 걸지도.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "elara", "amount": 3},
		"next_id": "elara_secret_end",
	},
	{
		"id": "elara_secret_alt",
		"speaker": "엘라라",
		"text": "자네도 알잖나, 사람들은 겁부터 먹어. 확실하지도 않은 걸로 마을을 불안하게 만들고 싶지 않았어.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "elara", "amount": 3},
		"next_id": "elara_secret_end",
	},
	{
		"id": "elara_secret_end",
		"speaker": "엘라라",
		"text": "...아무튼, 이런 얘긴 자네니까 하는 걸세. 다른 이들껜 아직은 비밀로 해주게.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_secret_followup",
		"speaker": "엘라라",
		"text": "그 기록에 대해서 더 생각해봤나?",
		"is_decisive": false,
		"options": [
			{"label": "[아니요, 아직요]", "next_id": ""},
			{"label": "[혹시 다른 단서는 없었나요?]", "next_id": "elara_secret_followup2"},
		],
	},
	{
		"id": "elara_secret_followup2",
		"speaker": "엘라라",
		"text": "글쎄... 기록 마지막 장에 이상한 문양이 하나 그려져 있긴 했어. 무슨 뜻인지는 나도 몰라.",
		"is_decisive": false,
		"options": [],
	},
]

# 로한(사냥꾼) 대화 트리
const ROHAN_DIALOGUE: Array = [
	{
		"id": "rohan_locked_greeting",
		"speaker": "로한",
		"text": "...넌 누구지? 처음 보는 얼굴이군. 볼일 있으면 나중에.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_greeting",
		"speaker": "로한",
		"text": "거기 서. ...아, 마을에서 온 사람이군.",
		"text_by_affinity_tier": {
			"npc_id": "rohan",
			"cold": "...뭐야. 볼일 있으면 빨리 말해.",
			"neutral": "거기 서. ...아, 마을에서 온 사람이군.",
			"warm": "왔군. 요즘 자네 발소리는 구별이 되더라고.",
			"trusted": "왔나. 자네랑 얘기하는 게 요즘 낙이야, 이거.",
		},
		"is_decisive": false,
		"options": [
			{"label": "[동굴에 대해 묻는다]", "next_id": "rohan_cave"},
			{"label": "[숲에 대해 묻는다]", "next_id": "rohan_forest"},
			{"label": "[사냥은 잘 되냐고 묻는다]", "next_id": "rohan_smalltalk"},
			{"label": "[오크 처치를 돕겠다고 한다]", "next_id": "rohan_quest_accept", "start_quest": "forest_orcs", "show_if_quest_inactive": "forest_orcs"},
			{"label": "[오크는 어떻게 되어가요?]", "next_id": "rohan_quest_status", "show_if_quest_active": "forest_orcs"},
			{"label": "[다른 사람들에 대해 묻는다]", "next_id": "rohan_gossip", "show_if_flag": "met_elara"},
			{
				"label": "[뭔가 고민이 있어 보여요]",
				"next_id": "rohan_secret_intro",
				"required_affinity": {"npc_id": "rohan", "min": 60},
				"show_if_not_seen": "rohan_secret_end",
			},
			{
				"label": "[오크 얘기, 또 생각났나 보군]",
				"next_id": "rohan_secret_followup",
				"show_if_seen": "rohan_secret_end",
			},
			{
				"label": "[선물을 준다]",
				"give_gift": {"npc_id": "rohan", "amount": 9, "next_id_success": "rohan_gift_thanks", "next_id_fail": "rohan_gift_none"},
			},
		],
	},
	{
		"id": "rohan_gift_thanks",
		"speaker": "로한",
		"text": "...나한테 선물을? 흠. ...고맙군. 이런 거, 오랜만이라 좀 어색하네.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_gift_none",
		"speaker": "로한",
		"narration": "(막상 건넬 것이 없다)",
		"text": "줄 게 없네요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_quest_accept",
		"speaker": "로한",
		"text": "고맙군. 숲에 오크 세 마리가 설치고 있어. 놈들을 처치해주면 마을이 한결 안전해질 거야. 조심하고.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_quest_status",
		"speaker": "로한",
		"text_if_flag": "forest_quest_complete",
		"text": "오크를 전부 처리했다고? ...대단하군. 정말 고생 많았어.",
		"text_false": "아직 놈들이 숲에 남아있군. 무리하지 말고 조심해.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_cave",
		"speaker": "로한",
		"text": "저 안에 뭔가 있어. 며칠 전부터 이상한 기운이 느껴져.",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[위험한가요?]", "next_id": "rohan_cave_danger"},
			{"label": "[뭘 봤나요?]", "next_id": "rohan_cave_saw"},
		],
	},
	{
		"id": "rohan_cave_danger",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "몰라. 하지만 내 직감은 조심하라고 말하고 있어.",
		"is_decisive": false,
		"options": [
			{"label": "[직감을 믿는 편인가요?]", "next_id": "rohan_cave_instinct"},
			{"label": "[알겠어요, 조심할게요]", "next_id": ""},
		],
	},
	{
		"id": "rohan_cave_instinct",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "숲에서 오래 살다 보면... 직감 말곤 믿을 게 없어질 때가 있지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_cave_saw",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "똑똑히는 못 봤어. 그림자 같은 게 물길을 막고 있는 것 같더군.",
		"is_decisive": false,
		"options": [
			{"label": "[없애야겠네요]", "next_id": "rohan_opinion_fight"},
			{"label": "[먼저 얘기를 해봐야겠어요]", "next_id": "rohan_opinion_talk"},
		],
	},
	{
		"id": "rohan_opinion_fight",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "그래, 내 생각도 그래. 위험한 건 없애는 게 맞지.",
		"is_decisive": false,
		"options": [
			{"label": "[당신도 같이 가줄 건가요?]", "next_id": "rohan_opinion_fight_join"},
			{"label": "[알겠어요]", "next_id": ""},
		],
	},
	{
		"id": "rohan_opinion_fight_join",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "...아니. 이건 자네 몫이야. 난 마을을 지켜야지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_opinion_talk",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "...흠. 그것도 나쁘지 않은 생각이군. 나라면 안 그러겠지만.",
		"is_decisive": false,
		"options": [
			{"label": "[왜 그렇게 생각해요?]", "next_id": "rohan_opinion_why"},
			{"label": "[알겠어요]", "next_id": ""},
		],
	},
	{
		"id": "rohan_opinion_why",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "위험한 건 위험한 거야. 대화로 풀릴 거였으면 애초에 이런 일이 안 생겼겠지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_forest",
		"speaker": "로한",
		"text": "조심해서 다녀. 요즘 숲이 심상치 않아.",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[구체적으로 뭐가 이상한가요?]", "next_id": "rohan_forest_detail"},
			{"label": "[알겠어요]", "next_id": ""},
		],
	},
	{
		"id": "rohan_forest_detail",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "나무들이... 말라가고 있어. 원래 이 계절엔 이러지 않는데.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_smalltalk",
		"speaker": "로한",
		"text": "사냥? ...요즘은 예전만 못해. 짐승들도 뭔가 눈치챈 건지 다들 숨어버렸어.",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[짐승들이 왜 숨었을까요?]", "next_id": "rohan_smalltalk_animals"},
			{"label": "[그럼 뭘 드시고 사세요?]", "next_id": "rohan_smalltalk_food"},
		],
	},
	{
		"id": "rohan_smalltalk_animals",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "글쎄. 짐승은 사람보다 먼저 위험을 아는 법이지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_smalltalk_food",
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 1, "once": true},
		"speaker": "로한",
		"text": "걱정 마. 굶어 죽을 정도는 아니니까.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_gossip",
		"speaker": "로한",
		"text": "[다른 사람들에 대해 물어본다]",
		"is_decisive": false,
		"options": [
			{"label": "[엘라라는 어떤 분인가요?]", "next_id": "rohan_about_elara", "show_if_flag": "met_elara"},
			{"label": "[유서프를 아세요?]", "next_id": "rohan_about_yusuf", "show_if_flag": "met_yusuf"},
		],
	},
	{
		"id": "rohan_about_elara",
		"speaker": "로한",
		"text": "장로님은... 이 마을에서 제일 오래 버틴 분이야. 함부로 대하지 마.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_about_yusuf",
		"speaker": "로한",
		"text": "그 상인? 나쁜 사람은 아닌데... 뭘 숨기고 있는 느낌이야.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_secret_intro",
		"speaker": "로한",
		"text": "...티가 나나. 하긴, 요즘 계속 그 생각뿐이라.",
		"is_decisive": false,
		"options": [
			{"label": "[무슨 생각이요?]", "next_id": "rohan_secret_1"},
			{"label": "[말하기 싫으면 안 해도 돼요]", "next_id": ""},
		],
	},
	{
		"id": "rohan_secret_1",
		"speaker": "로한",
		"text": "오크들 말이야. 처음엔 그냥 사나워진 줄 알았는데... 요즘 보면 뭔가 이상해.",
		"is_decisive": false,
		"next_id": "rohan_secret_2",
	},
	{
		"id": "rohan_secret_2",
		"speaker": "로한",
		"text": "눈빛이... 짐승의 눈빛이 아니야. 뭔가에 쫓기는 것 같은, 그런 눈이더군.",
		"is_decisive": false,
		"options": [
			{"label": "[오크들도 피해자라는 건가요?]", "next_id": "rohan_secret_3"},
			{"label": "[그래도 위험한 건 위험한 거잖아요]", "next_id": "rohan_secret_alt"},
		],
	},
	{
		"id": "rohan_secret_3",
		"speaker": "로한",
		"text": "...그럴지도 모르지. 근데 이런 말 마을에서 함부로 못 해. '괴물 편드는 놈'이라는 소리 듣기 딱 좋으니까.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 3},
		"next_id": "rohan_secret_end",
	},
	{
		"id": "rohan_secret_alt",
		"speaker": "로한",
		"text": "맞아. 그건 그거고. 그래도... 가끔은 마음이 편치 않아.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "rohan", "amount": 2},
		"next_id": "rohan_secret_end",
	},
	{
		"id": "rohan_secret_end",
		"speaker": "로한",
		"text": "아무튼. 자네한테만 하는 말이야. 알겠지?",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_secret_followup",
		"speaker": "로한",
		"text": "오크 얘기, 또 생각났나 보군.",
		"is_decisive": false,
		"options": [
			{"label": "[오크들이 왜 그렇게 됐을까요?]", "next_id": "rohan_secret_followup2"},
			{"label": "[아니, 그냥 안부 물으러 왔어요]", "next_id": ""},
		],
	},
	{
		"id": "rohan_secret_followup2",
		"speaker": "로한",
		"text": "낸들 알겠나. 근데... 숲 저 안쪽, 자네가 아직 안 가본 데서 뭔가 이상한 냄새가 나더군. 타는 냄새 같기도 하고.",
		"is_decisive": false,
		"options": [],
	},
]

# 유서프(떠돌이 상인) 대화 트리
const YUSUF_DIALOGUE: Array = [
	{
		"id": "yusuf_locked_greeting",
		"speaker": "유서프",
		"text": "오, 낯선 얼굴이군? ...아직은 자네한테 해줄 얘기가 없네. 나중에 보지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_greeting",
		"speaker": "유서프",
		"text": "오, 손님이시군! 뭐 필요한 거라도?",
		"text_by_affinity_tier": {
			"npc_id": "yusuf",
			"cold": "...뭐, 필요한 거라도?",
			"neutral": "오, 손님이시군! 뭐 필요한 거라도?",
			"warm": "오, 왔는가! 요즘 자네 얼굴 보는 게 하루의 낙이야.",
			"trusted": "왔군. ...솔직히, 자네한테는 좀 더 솔직해도 될 것 같은데.",
		},
		"is_decisive": false,
		"options": [
			{"label": "[동굴 이야기를 묻는다]", "next_id": "yusuf_cave_hint"},
			{"label": "[당신은 누구세요?]", "next_id": "yusuf_who"},
			{"label": "[뭘 팔고 있어요?]", "next_id": "yusuf_wares"},
			{"label": "[스켈레톤 처치를 돕겠다고 한다]", "next_id": "yusuf_quest_accept", "next_id_if_blocked": "yusuf_quest_not_ready", "min_quest_level": 1, "start_quest": "cave_skeletons", "show_if_quest_inactive": "cave_skeletons"},
			{"label": "[스켈레톤은 어떻게 되어가요?]", "next_id": "yusuf_quest_status", "show_if_quest_active": "cave_skeletons"},
			{"label": "[다른 사람들에 대해 묻는다]", "next_id": "yusuf_gossip", "show_if_flag": "met_elara"},
			{
				"label": "[정말 그냥 상인이 맞아요?]",
				"next_id": "yusuf_secret_stage1",
				"required_affinity": {"npc_id": "yusuf", "min": 50},
				"show_if_not_seen": "yusuf_secret_stage1c",
			},
			{
				"label": "[이제 진짜 말해줘요]",
				"next_id": "yusuf_secret_stage2",
				"required_affinity": {"npc_id": "yusuf", "min": 80},
				"show_if_seen": "yusuf_secret_stage1c",
				"show_if_not_seen": "yusuf_secret_stage2d",
				"show_if_flag": "guardian_event_done",
			},
			{
				"label": "[선물을 준다]",
				"give_gift": {"npc_id": "yusuf", "amount": 9, "next_id_success": "yusuf_gift_thanks", "next_id_fail": "yusuf_gift_none"},
			},
		],
	},
	{
		"id": "yusuf_gift_thanks",
		"speaker": "유서프",
		"text": "오, 이런! 장사꾼한테 선물을 다 주시고. 허허, 이 은혜는 잊지 않겠습니다.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_gift_none",
		"speaker": "유서프",
		"narration": "(막상 건넬 것이 없다)",
		"text": "줄 게 없네요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_quest_accept",
		"speaker": "유서프",
		"text": "오, 도와준다니 든든하군! 동굴 입구 쪽에 스켈레톤 셋이 얼쩡거리고 있어. 놈들을 처리해주면 내가 섭섭지 않게 사례하지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_quest_not_ready",
		"speaker": "유서프",
		"text": "아직 준비가 덜 된 것 같군. 먼저 힘을 좀 기르고 오게.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_quest_status",
		"speaker": "유서프",
		"text_if_flag": "cave_quest_complete",
		"text": "스켈레톤을 다 정리했다고? 역시 자네야. 약속대로 사례는 톡톡히 하지.",
		"text_false": "아직 동굴에 놈들이 남아있군. 서두르지 말고 확실하게 처리하게.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_cave_hint",
		"speaker": "유서프",
		"text": "그 안의 존재? 흠... 그건 원래 나쁜 게 아니었어. 지키는 존재였지.",
		"affinity_change_on_show": {"npc_id": "yusuf", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[무슨 뜻이죠?]", "next_id": "yusuf_cave_hint2"},
			{"label": "[알 것 같아요, 고마워요]", "next_id": ""},
		],
	},
	{
		"id": "yusuf_cave_hint2",
		"affinity_change_on_show": {"npc_id": "yusuf", "amount": 1, "once": true},
		"speaker": "유서프",
		"text": "싸워서 없애는 것만이 답은 아닐 수도 있다는 뜻이야. 잘 생각해보게.",
		"is_decisive": false,
		"options": [
			{"label": "[어떻게 그렇게 잘 아세요?]", "next_id": "yusuf_cave_hint3"},
			{"label": "[알겠어요]", "next_id": ""},
		],
	},
	{
		"id": "yusuf_cave_hint3",
		"affinity_change_on_show": {"npc_id": "yusuf", "amount": 1, "once": true},
		"speaker": "유서프",
		"text": "이곳저곳 떠돌다 보면... 비슷한 이야기를 몇 번 들었지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_who",
		"speaker": "유서프",
		"text": "그냥... 이곳저곳 떠도는 상인이지. 그 이상은... 훗날 알게 될 걸세.",
		"affinity_change_on_show": {"npc_id": "yusuf", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[수상한데요?]", "next_id": "yusuf_who_suspicious"},
			{"label": "[알겠어요, 안 물어볼게요]", "next_id": ""},
		],
	},
	{
		"id": "yusuf_who_suspicious",
		"affinity_change_on_show": {"npc_id": "yusuf", "amount": 1, "once": true},
		"speaker": "유서프",
		"text": "수상하다니, 섭섭한걸. ...뭐, 완전히 틀린 말은 아니지만.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_wares",
		"speaker": "유서프",
		"text": "이것저것 있지. 다른 마을에서 가져온 물건들이야.",
		"affinity_change_on_show": {"npc_id": "yusuf", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[물건을 산다]", "open_shop": true},
			{"label": "[다른 마을은 어떤가요?]", "next_id": "yusuf_other_villages"},
			{"label": "[딱히 필요한 건 없어요]", "next_id": ""},
		],
	},
	{
		"id": "yusuf_other_villages",
		"affinity_change_on_show": {"npc_id": "yusuf", "amount": 1, "once": true},
		"speaker": "유서프",
		"text": "여기보단... 힘든 곳도 있더군. 자네 마을은 아직 운이 좋은 편이야.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_gossip",
		"speaker": "유서프",
		"text": "[다른 사람들에 대해 물어본다]",
		"is_decisive": false,
		"options": [
			{"label": "[엘라라는 어떤 분인가요?]", "next_id": "yusuf_about_elara", "show_if_flag": "met_elara"},
			{"label": "[로한을 아세요?]", "next_id": "yusuf_about_rohan", "show_if_flag": "met_rohan"},
		],
	},
	{
		"id": "yusuf_about_elara",
		"speaker": "유서프",
		"text": "장로님? 이 마을에서 제일 지혜로운 분이지. 나도 여러 번 신세를 졌어.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_about_rohan",
		"speaker": "유서프",
		"text": "그 사냥꾼 말인가? 성격은 까칠해도 믿을 만한 사람이야.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_secret_stage1",
		"speaker": "유서프",
		"text": "...날카롭구먼. 뭐, 완전히 틀린 말은 아니야.",
		"is_decisive": false,
		"options": [
			{"label": "[역시 뭔가 있었네요]", "next_id": "yusuf_secret_stage1b"},
			{"label": "[그럼 뭔데요?]", "next_id": "yusuf_secret_stage1b"},
		],
	},
	{
		"id": "yusuf_secret_stage1b",
		"speaker": "유서프",
		"text": "난... 그냥 물건을 파는 사람이 아니야. 정확히는, 세상 곳곳을 돌아다니며 뭔가를 '지켜보는' 사람에 가깝지.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "yusuf", "amount": 2},
		"next_id": "yusuf_secret_stage1c",
	},
	{
		"id": "yusuf_secret_stage1c",
		"speaker": "유서프",
		"text": "이 정도만 말해두지. 더 궁금하면... 나를 좀 더 믿게 되면 그때 얘기하세.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_secret_stage2",
		"speaker": "유서프",
		"text": "...좋아. 이제는 말해도 될 것 같군.",
		"is_decisive": false,
		"next_id": "yusuf_secret_stage2b",
	},
	{
		"id": "yusuf_secret_stage2b",
		"speaker": "유서프",
		"text": "나는 '감시자'라고 불리는 이들 중 하나야. 세상 곳곳에서 수맥이 끊기는 걸 지켜보고, 기록하고... 가끔은, 막아보려 애쓰는 사람들이지.",
		"is_decisive": false,
		"options": [
			{"label": "[감시자요? 처음 들어봐요]", "next_id": "yusuf_secret_stage2c"},
			{"label": "[그럼 이 마을에 온 것도...]", "next_id": "yusuf_secret_stage2c"},
		],
	},
	{
		"id": "yusuf_secret_stage2c",
		"speaker": "유서프",
		"text": "맞아. 우연이 아니었어. 이 마을의 우물이 마른 게, 우리가 추적하던 큰 흐름의 일부였거든.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "yusuf", "amount": 5},
		"next_id": "yusuf_secret_stage2d",
	},
	{
		"id": "yusuf_secret_stage2d",
		"speaker": "유서프",
		"text": "자네가 우물을 되살린 건... 생각보다 훨씬 중요한 일이었을 수도 있어. 나도 아직 다는 몰라.",
		"is_decisive": false,
		"options": [
			{"label": "[더 알려줄 건 없어요?]", "next_id": "yusuf_secret_stage2e"},
			{"label": "[일단 알겠어요]", "next_id": ""},
		],
	},
	{
		"id": "yusuf_secret_stage2e",
		"speaker": "유서프",
		"text": "...바다 건너, 훨씬 심각한 곳이 있다는 것 정도는 알고 있네. 언젠가 자네가 준비되면, 그때 자세히 얘기하지.",
		"is_decisive": false,
		"options": [],
	},
]

# 미아(아이) 대화 트리
const MIA_DIALOGUE: Array = [
	{
		"id": "mia_locked_greeting",
		"speaker": "미아",
		"text": "...",
		"narration": "(낯선 사람을 경계하며 뒤로 물러선다)",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "mia_greeting",
		"speaker": "미아",
		"text": "...",
		"narration": "(플레이어를 보고 몸을 움츠린다)",
		"is_decisive": false,
		"options": [
			{"label": "[괜찮아? 무서워하지 않아도 돼]", "next_id": "mia_approach_gentle"},
			{"label": "[그날 밤 무슨 일이 있었는지 말해줘]", "next_id": "mia_approach_press"},
			{"label": "[그냥 인사만 한다]", "next_id": "mia_smalltalk", "show_if_flag": "met_mia"},
			{
				"label": "[선물을 준다]",
				"give_gift": {"npc_id": "mia", "amount": 9, "next_id_success": "mia_gift_thanks", "next_id_fail": "mia_gift_none"},
			},
		],
	},
	{
		"id": "mia_gift_thanks",
		"speaker": "미아",
		"text": "우와... 나 주는 거예요? 헤헤, 고마워요! 소중히 간직할게요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "mia_gift_none",
		"speaker": "미아",
		"narration": "(막상 건넬 것이 없다)",
		"text": "줄 게 없네요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "mia_approach_press",
		"speaker": "미아",
		"text": "미아가 눈을 크게 뜨고 물러선다.",
		"is_decisive": true,
		"options": [
			{"label": "[사실대로 말해줘, 중요한 일이야]", "next_id": "mia_scared", "flag_to_set": "earned_mia_trust", "flag_value": false},
			{"label": "[...미안, 천천히 얘기해도 돼]", "next_id": "mia_relieved", "flag_to_set": "earned_mia_trust", "flag_value": true},
		],
	},
	{
		"id": "mia_scared",
		"speaker": "미아",
		"text": "...몰라요. 아무것도 못 봤어요.",
		"set_flag_on_show": "met_mia_decisive",
		"is_decisive": false,
		"options": [
			{"label": "[미안, 다그치려던 건 아니었어]", "next_id": "mia_scared_apology"},
			{"label": "[...알겠어]", "next_id": ""},
		],
	},
	{
		"id": "mia_scared_apology",
		"speaker": "미아",
		"text": "...괜찮아요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "mia_relieved",
		"speaker": "미아",
		"text": "...고마워요. 사실은... 그날 밤에 이상한 빛을 봤어요, 동굴 쪽에서.",
		"set_flag_on_show": "met_mia_decisive",
		"is_decisive": false,
		"options": [
			{"label": "[더 자세히 말해줄 수 있어?]", "next_id": "mia_relieved_detail"},
			{"label": "[말해줘서 고마워]", "next_id": ""},
		],
	},
	{
		"id": "mia_relieved_detail",
		"speaker": "미아",
		"text": "파랗고... 슬픈 빛이었어요. 무섭다기보단... 뭔가 아파 보였어요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "mia_approach_gentle",
		"speaker": "미아",
		"text": "미아가 조금 안심한 표정을 짓는다.",
		"is_decisive": false,
		"options": [
			{"label": "[천천히 얘기해줄래?]", "next_id": "mia_approach_press"},
		],
	},
	{
		"id": "mia_smalltalk",
		"speaker": "미아",
		"text": "...",
		"narration": "(미아가 예전보다 편하게 쳐다본다)",
		"is_decisive": false,
		"options": [
			{
				"label": "[요즘 어때?]",
				"next_id": "mia_smalltalk_ok",
				"next_id_by_affinity": {
					"npc_id": "mia",
					"thresholds": [40, 70],
					"next_ids": ["mia_smalltalk_shy", "mia_smalltalk_ok", "mia_smalltalk_close"],
				},
			},
			{
				"label": "[그 꿈 이야기, 좀 더 해줄래?]",
				"next_id": "mia_dream_intro",
				"required_affinity": {"npc_id": "mia", "min": 60},
				"show_if_flag": "earned_mia_trust",
				"show_if_not_seen": "mia_dream_end",
			},
			{
				"label": "[요즘도 그 꿈을 꿔?]",
				"next_id": "mia_dream_followup",
				"show_if_seen": "mia_dream_end",
			},
		],
	},
	{
		"id": "mia_smalltalk_shy",
		"speaker": "미아",
		"text": "...그냥 그래요.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "mia", "amount": 1},
		"options": [],
	},
	{
		"id": "mia_smalltalk_ok",
		"speaker": "미아",
		"text": "이제 무섭지 않아요. 당신 덕분에요.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "mia", "amount": 2},
		"options": [],
	},
	{
		"id": "mia_smalltalk_close",
		"speaker": "미아",
		"text": "당신이 오면 좋아요. 얘기할 사람이 생긴 것 같아서.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "mia", "amount": 3},
		"options": [],
	},
	{
		"id": "mia_dream_intro",
		"speaker": "미아",
		"text": "...그거요? 사실 그날 밤 말고도, 예전부터 이상한 꿈을 꿨어요.",
		"is_decisive": false,
		"options": [
			{"label": "[어떤 꿈인데?]", "next_id": "mia_dream_1"},
			{"label": "[괜찮으면 말 안 해도 돼]", "next_id": ""},
		],
	},
	{
		"id": "mia_dream_1",
		"speaker": "미아",
		"text": "물이... 빛나는 꿈이에요. 근데 슬픈 빛이었어요. 꼭 뭔가를 찾고 있는 것처럼.",
		"is_decisive": false,
		"next_id": "mia_dream_2",
	},
	{
		"id": "mia_dream_2",
		"speaker": "미아",
		"text": "엄마는 그냥 애가 꾸는 꿈이라고 했는데... 그날 밤 진짜로 그 빛을 봤을 때, 무서웠던 것보다 익숙하다는 느낌이 더 컸어요.",
		"is_decisive": false,
		"affinity_change_on_show": {"npc_id": "mia", "amount": 4},
		"next_id": "mia_dream_end",
	},
	{
		"id": "mia_dream_end",
		"speaker": "미아",
		"text": "...이상하죠? 아무튼, 당신한테는 말할 수 있어서 다행이에요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "mia_dream_followup",
		"speaker": "미아",
		"text": "요즘도 가끔 그 꿈을 꿔요. 근데... 요즘은 배경이 달라요. 물 대신 온통 모래인 곳이에요.",
		"is_decisive": false,
		"options": [],
	},
]

# 카밀(감시자 동료) 대화 트리 — 유서프가 정체를 밝힌 뒤(yusuf_secret_stage2를 본 뒤) 마을에 등장.
# "지금 갈게요"를 고르면 kamil_confirm_departure에 도달하며, 그 노드의 set_flag_on_show로 boat_available이 켜진다
const KAMIL_DIALOGUE: Array = [
	{
		"id": "kamil_greeting",
		"speaker": "카밀",
		"text": "...당신이군요. 유서프가 말한 그 사람.",
		"is_decisive": false,
		"options": [
			{"label": "[당신은 누구세요?]", "next_id": "kamil_intro_1"},
			{"label": "[왜 저를 기다렸나요?]", "next_id": "kamil_intro_1"},
			{
				"label": "[나딤을 아세요?]",
				"next_id": "kamil_sister_intro",
				"required_affinity": {"npc_id": "kamil", "min": 55},
			},
			{
				# 2부 결정적 선택: 유적 보스를 처치하고 진실까지 알아낸 뒤에만, 그리고 아직 이 갈래를 안 봤을 때만 열린다
				"label": "[유적에서 알게 된 걸 말한다]",
				"next_id": "kamil_truth_1",
				"show_if_flags": ["ruins_boss_defeated", "truth_discovered"],
				"show_if_not_seen": "kamil_truth_1",
			},
			{
				"label": "[선물을 준다]",
				"give_gift": {"npc_id": "kamil", "amount": 9, "next_id_success": "kamil_gift_thanks", "next_id_fail": "kamil_gift_none"},
			},
		],
	},
	# --- 카밀 자매 갈래 (호감도 55+) : 카밀과 나딤은 자매 ---
	{
		"id": "kamil_sister_intro",
		"speaker": "카밀",
		"text": "...그 이름을 어떻게. 아, 사막에서 만났겠군.",
		"is_decisive": false,
		"next_id": "kamil_sister_1",
	},
	{
		"id": "kamil_sister_1",
		"speaker": "카밀",
		"text": "그 애는... 제 동생입니다. 오래전에 서로 다른 길을 택했죠.",
		"is_decisive": false,
		"next_id": "kamil_sister_2",
	},
	{
		"id": "kamil_sister_2",
		"speaker": "카밀",
		"text": "저는 떠났고, 그 애는 남았어요. 그 애는 아직도 저를 원망할지도 모르겠네요.",
		"affinity_change_on_show": {"npc_id": "kamil", "amount": 3, "once": true},
		"is_decisive": false,
		"options": [],
	},
	# --- 2부 결정적 선택 갈래 (유적의 진실을 카밀에게 알린 뒤) ---
	{
		"id": "kamil_truth_1",
		"speaker": "카밀",
		"text": "...표정을 보니, 뭔가 찾은 모양이군요.",
		"is_decisive": false,
		"next_id": "kamil_truth_2",
	},
	{
		"id": "kamil_truth_2",
		"speaker": "카밀",
		"text": "'감시자의 실수'라... 예상은 했지만, 직접 들으니...",
		"is_decisive": false,
		"next_id": "kamil_truth_3",
	},
	{
		"id": "kamil_truth_3",
		"speaker": "카밀",
		"text": "이걸 세상에 알려야 할까요, 아니면... 조용히 묻어야 할까요. 결정은 당신에게 맡기겠습니다.",
		"is_decisive": true,
		"options": [
			{"label": "[진실을 세상에 알린다]", "next_id": "kamil_choice_reveal", "flag_to_set": "truth_revealed", "flag_value": true},
			{"label": "[비밀로 유지한다]", "next_id": "kamil_choice_secret", "flag_to_set": "truth_revealed", "flag_value": false},
		],
	},
	{
		"id": "kamil_choice_reveal",
		"speaker": "카밀",
		"text": "...당신의 선택을 존중합니다. 저도 더 이상 숨기지 않겠습니다.",
		"set_flag_on_show": "part2_complete", # 이 노드에 도달하면 2부 완료 — 대화 종료 시 kamil_npc가 최종 엔딩으로 전환
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "kamil_choice_secret",
		"speaker": "카밀",
		"text": "...현명한 선택일 수도 있겠군요. 저는 계속 지켜보겠습니다.",
		"set_flag_on_show": "part2_complete", # 이 노드에 도달하면 2부 완료 — 대화 종료 시 kamil_npc가 최종 엔딩으로 전환
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "kamil_gift_thanks",
		"speaker": "카밀",
		"text": "...저에게요? 뜻밖이군요. 이런 걸 받아본 게 얼마 만인지... 감사합니다.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "kamil_gift_none",
		"speaker": "카밀",
		"narration": "(막상 건넬 것이 없다)",
		"text": "줄 게 없네요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "kamil_intro_1",
		"speaker": "카밀",
		"text": "저는 카밀입니다. 유서프와 같은 일을 하고 있죠 — '감시자' 말입니다.",
		"is_decisive": false,
		"next_id": "kamil_intro_2",
	},
	{
		"id": "kamil_intro_2",
		"speaker": "카밀",
		"text": "바다 건너에 도움이 필요한 곳이 있습니다. 준비되면 말씀하세요. 배를 준비해두겠습니다.",
		"is_decisive": false,
		"options": [
			{"label": "[지금 갈게요]", "next_id": "kamil_confirm_departure"},
			{"label": "[아직 준비가 안 됐어요]", "next_id": ""},
		],
	},
	{
		"id": "kamil_confirm_departure",
		"speaker": "카밀",
		"text": "알겠습니다. 부두에서 기다리고 있겠습니다.",
		"is_decisive": false,
		"set_flag_on_show": "boat_available", # 이 노드에 도달하는 순간 부두의 배가 이용 가능해짐
		"options": [],
	},
]

# 나딤(사막 정착지 지도자/생존자) 대화 트리 — 2부 초반. 끝에서 ruins_available를 켜 유적 입구를 연다
const NADIM_DIALOGUE: Array = [
	{
		"id": "nadim_greeting",
		"speaker": "나딤",
		"text_by_affinity_tier": {
			"npc_id": "nadim",
			"cold": "...뭐 필요한 거라도 있나.",
			"neutral": "...또 다른 이방인인가. 카밀이 데려온 건가?",
			"warm": "왔군. 자네가 오면 마음이 조금 놓여.",
			"trusted": "왔나. 요즘은... 자네 덕분에 버티고 있는 것 같아.",
		},
		"text": "...또 다른 이방인인가. 카밀이 데려온 건가?", # tier 조회 실패 시 fallback (기본 = neutral)
		"is_decisive": false,
		"options": [
			{"label": "[네, 도움이 필요하다고 들었어요]", "next_id": "nadim_intro_1"},
			{"label": "[미라 처치를 돕겠다고 한다]", "next_id": "nadim_mummy_accept", "start_quest": "desert_mummies", "show_if_flag": "ruins_available", "show_if_quest_inactive": "desert_mummies"},
			{"label": "[미라는 어떻게 되어가요?]", "next_id": "nadim_mummy_status", "show_if_quest_active": "desert_mummies"},
			{"label": "[유적의 열쇠를 찾아보겠다고 한다]", "next_id": "nadim_key_accept", "start_quest": "ruins_key", "show_if_flag": "ruins_available", "show_if_quest_inactive": "ruins_key"},
			{"label": "[열쇠는 찾았나요?]", "next_id": "nadim_key_status", "show_if_quest_active": "ruins_key"},
			{
				"label": "[미라들에 대해 어떻게 생각하세요?]",
				"next_id": "nadim_secret_intro",
				"required_affinity": {"npc_id": "nadim", "min": 55},
				"show_if_quest_active": "desert_mummies",
			},
			{
				"label": "[카밀을 아세요?]",
				"next_id": "nadim_sister_intro",
				"required_affinity": {"npc_id": "nadim", "min": 55},
			},
			{
				"label": "[선물을 준다]",
				"give_gift": {"npc_id": "nadim", "amount": 9, "next_id_success": "nadim_gift_thanks", "next_id_fail": "nadim_gift_none"},
			},
		],
	},
	{
		"id": "nadim_gift_thanks",
		"speaker": "나딤",
		"text": "...나한테? 이 삭막한 땅에서 이런 걸 받을 줄은 몰랐군. 고맙네.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "nadim_gift_none",
		"speaker": "나딤",
		"narration": "(막상 건넬 것이 없다)",
		"text": "줄 게 없네요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "nadim_mummy_accept",
		"speaker": "나딤",
		"text": "고맙네. 유적으로 가는 길목에 그 마른 것들이 셋 있어. 놈들이 있는 한 아무도 유적에 닿지 못해. 부디 조심하게.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "nadim_mummy_status",
		"speaker": "나딤",
		"text_if_flag": "desert_mummies_complete",
		"text": "미라를 전부 처리했다고? ...자네, 보통이 아니군. 정말 고맙네.",
		"text_false": "아직 그 마른 것들이 남아있군. 무리하지 말게.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "nadim_key_accept",
		"speaker": "나딤",
		"text": "열쇠 없이는 유적의 문이 열리지 않아. 이 근처 어딘가에 옛 사람들이 숨겨뒀을 걸세. 잘 찾아보게.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "nadim_key_status",
		"speaker": "나딤",
		"text_if_flag": "ruins_key_complete",
		"text": "열쇠를 찾았군. 그렇다면... 이제 정말 갈 수 있겠어.",
		"text_false": "아직 열쇠를 못 찾았나 보군. 유적의 문은 그것 없이는 꿈쩍도 안 해.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "nadim_intro_1",
		"speaker": "나딤",
		"text": "도움이라... 이미 늦었을지도 모르지만, 그래도 와줘서 고맙네.",
		"is_decisive": false,
		"next_id": "nadim_intro_2",
	},
	{
		"id": "nadim_intro_2",
		"speaker": "나딤",
		"text": "이 땅은 원래 이렇지 않았어. 몇 년 전부터 서서히 말라갔지. 당신네 마을의 우물처럼 말이야.",
		"is_decisive": false,
		"options": [
			{"label": "[여기서 무슨 일이 있었던 건가요?]", "next_id": "nadim_backstory_1"},
			{"label": "[제가 뭘 도우면 될까요?]", "next_id": "nadim_backstory_1"},
		],
	},
	{
		"id": "nadim_backstory_1",
		"speaker": "나딤",
		"text": "이 근처에... 오래된 유적이 있어. 옛 사람들이 물줄기를 다스리던 곳이라고 전해지지.",
		"affinity_change_on_show": {"npc_id": "nadim", "amount": 2, "once": true},
		"is_decisive": false,
		"next_id": "nadim_backstory_2",
	},
	{
		"id": "nadim_backstory_2",
		"speaker": "나딤",
		"text": "그 유적 안쪽에 들어간 사람이 아무도 안 돌아왔어. 그래도... 답을 찾으려면 그곳뿐이라고 생각해.",
		"is_decisive": false,
		"options": [
			{"label": "[제가 가볼게요]", "next_id": "nadim_quest_offer"},
			{"label": "[너무 위험한 거 아닌가요?]", "next_id": "nadim_quest_offer"},
		],
	},
	{
		"id": "nadim_quest_offer",
		"speaker": "나딤",
		"text": "고맙네. 조심하게. 유적 입구는 마을 동쪽에 있어.",
		"set_flag_on_show": "ruins_available", # 이 노드에 도달하는 순간 사막 유적 입구가 이용 가능해짐
		"is_decisive": false,
		"options": [],
	},
	# --- 나딤 비밀 갈래 (호감도 55+, 미라 퀘스트 진행 중일 때) ---
	{
		"id": "nadim_secret_intro",
		"speaker": "나딤",
		"text": "...그 얘기, 언젠가는 물어볼 줄 알았지.",
		"is_decisive": false,
		"options": [
			{"label": "[뭔가 알고 계신 거죠?]", "next_id": "nadim_secret_1"},
		],
	},
	{
		"id": "nadim_secret_1",
		"speaker": "나딤",
		"text": "저 미라들, 원래는... 유적을 지키던 존재였다고 들었어. 아주 오래전엔.",
		"is_decisive": false,
		"next_id": "nadim_secret_2",
	},
	{
		"id": "nadim_secret_2",
		"speaker": "나딤",
		"text": "근데 언젠가부터 저렇게 변해버렸지. 폭주하듯이, 닥치는 대로 공격하고.",
		"affinity_change_on_show": {"npc_id": "nadim", "amount": 3, "once": true},
		"is_decisive": false,
		"next_id": "nadim_secret_3",
	},
	{
		"id": "nadim_secret_3",
		"speaker": "나딤",
		"text": "카밀 같은 이들이 오기 시작한 것도... 그 무렵부터였다는 소문이 있어.",
		"is_decisive": false,
		"options": [
			{"label": "[감시자들이 뭔가 저지른 건가요?]", "next_id": "nadim_secret_4"},
			{"label": "[그냥 소문 아닐까요?]", "next_id": "nadim_secret_alt"},
		],
	},
	{
		"id": "nadim_secret_4",
		"speaker": "나딤",
		"text": "모르지. 확실한 건 아무것도 없어. 그래도... 자네가 유적에 들어가면, 뭔가 알 수 있을지도 모르겠군.",
		"affinity_change_on_show": {"npc_id": "nadim", "amount": 2, "once": true},
		"is_decisive": false,
		"next_id": "nadim_secret_end",
	},
	{
		"id": "nadim_secret_alt",
		"speaker": "나딤",
		"text": "그럴지도. 근데... 이상하게 마음에 걸려서 말이야.",
		"affinity_change_on_show": {"npc_id": "nadim", "amount": 2, "once": true},
		"is_decisive": false,
		"next_id": "nadim_secret_end",
	},
	{
		"id": "nadim_secret_end",
		"speaker": "나딤",
		"text": "이건 카밀한테는 아직 말하지 말게. 확실해지기 전까지는.",
		"is_decisive": false,
		"options": [],
	},
	# --- 나딤 자매 갈래 (호감도 55+) : 카밀과 나딤은 자매 ---
	{
		"id": "nadim_sister_intro",
		"speaker": "나딤",
		"text": "...언니 얘기를 하는군.",
		"is_decisive": false,
		"next_id": "nadim_sister_1",
	},
	{
		"id": "nadim_sister_1",
		"speaker": "나딤",
		"text": "우리는 자매였어. 언니는 떠나는 쪽을 택했고, 난 남는 쪽을 택했지.",
		"is_decisive": false,
		"next_id": "nadim_sister_2",
	},
	{
		"id": "nadim_sister_2",
		"speaker": "나딤",
		"text": "가끔은... 언니가 옳았을지도 모른다는 생각이 들어. 하지만 난 후회 안 해.",
		"affinity_change_on_show": {"npc_id": "nadim", "amount": 3, "once": true},
		"is_decisive": false,
		"options": [],
	},
]

# 카심(정체를 숨긴 무기 상인, 술집 상주) 대화 트리
const KASIM_DIALOGUE: Array = [
	{
		"id": "kasim_greeting",
		"speaker": "카심",
		"text": "...손님인가. 후드 밑으로 눈을 마주치긴 좀 그렇지만, 뭐, 장사는 장사니까.",
		"is_decisive": false,
		"options": [
			{"label": "[뭘 파세요?]", "next_id": "kasim_wares"},
			{"label": "[누구세요?]", "next_id": "kasim_intro_1"},
			{
				"label": "[장사는 잘 되세요?]",
				"next_id": "kasim_smalltalk_1",
				"required_affinity": {"npc_id": "kasim", "min": 50},
			},
			{
				"label": "[선물을 준다]",
				"give_gift": {"npc_id": "kasim", "amount": 9, "next_id_success": "kasim_gift_thanks", "next_id_fail": "kasim_gift_none"},
			},
		],
	},
	{
		"id": "kasim_gift_thanks",
		"speaker": "카심",
		"text": "...나한테요? 후드 속에서도 표정이 티 나나 보군. 고맙게 받지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "kasim_gift_none",
		"speaker": "카심",
		"narration": "(막상 건넬 것이 없다)",
		"text": "줄 게 없네요.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "kasim_wares",
		"speaker": "카심",
		"text": "이래 봬도 꽤 쓸만한 물건들을 갖췄지. 나무, 뼈, 금 등급까지 있네.",
		"affinity_change_on_show": {"npc_id": "kasim", "amount": 2, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[물건을 산다]", "open_weapon_shop": true},
			{"label": "[됐어요]", "next_id": ""},
		],
	},
	{
		"id": "kasim_intro_1",
		"speaker": "카심",
		"text": "카심이라고 하네. 이곳저곳 떠돌면서 장사를 하고 있지, 뭐 대단한 사연은 아니야.",
		"is_decisive": false,
		"options": [
			{"label": "[당신은 몬스터가 아닌가요?]", "next_id": "kasim_intro_2"},
			{"label": "[알겠어요]", "next_id": ""},
		],
	},
	{
		"id": "kasim_intro_2",
		"speaker": "카심",
		"text": "...하하. 눈썰미가 좋군. 뭐, 후드를 쓰고 다니는 데는 다 이유가 있는 법이지.",
		"affinity_change_on_show": {"npc_id": "kasim", "amount": 2, "once": true},
		"is_decisive": false,
		"next_id": "kasim_intro_3",
	},
	{
		"id": "kasim_intro_3",
		"speaker": "카심",
		"text": "그 이상은... 묻지 말아주게. 언젠가 때가 되면, 말할지도 모르지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "kasim_smalltalk_1",
		"speaker": "카심",
		"text": "그럭저럭. 이런 외진 마을까지 찾아오는 손님이 있을 줄은 몰랐지만.",
		"affinity_change_on_show": {"npc_id": "kasim", "amount": 1, "once": true},
		"is_decisive": false,
		"options": [
			{"label": "[작은 마을이라 심심하지 않아요?]", "next_id": "kasim_smalltalk_2"},
			{"label": "[그렇군요]", "next_id": ""},
		],
	},
	{
		"id": "kasim_smalltalk_2",
		"speaker": "카심",
		"text": "심심함이야... 오래 살다 보면 익숙해지지. 아, 이건 그냥 해본 말이야.",
		"affinity_change_on_show": {"npc_id": "kasim", "amount": 1, "once": true},
		"is_decisive": false,
		"options": [],
	},
]

# 동굴 수호자 조우 대화 트리
const GUARDIAN_DIALOGUE: Array = [
	{
		"id": "guardian_intro_1",
		"speaker": "???",
		"text": "",
		"narration": "(동굴 깊은 곳, 물이 흐르지 않는 마른 수로 앞에 무언가가 웅크리고 있다) ...(낮고 갈라진 숨소리가 동굴 벽을 울린다)",
		"is_decisive": false,
		"next_id": "guardian_intro_2",
	},
	{
		"id": "guardian_intro_2",
		"speaker": "???",
		"text": "...누구냐. ...또 나를... 없애러 왔나.",
		"is_decisive": false,
		"next_id": "guardian_intro_3",
	},
	{
		"id": "guardian_intro_3",
		"speaker": "???",
		"text": "물길은... 내가 막은 게 아니다. 나는... 지키던 것뿐인데... 무언가 잘못됐어. 나조차... 왜 이렇게 됐는지 모르겠다.",
		"is_decisive": false,
		"next_id": "guardian_decisive",
	},
	{
		"id": "guardian_decisive",
		"speaker": "???",
		"text": "",
		"narration": "(수호자가 몸을 낮춘다. 싸울 준비를 하는 것처럼도, 체념한 것처럼도 보인다)",
		"is_decisive": true,
		"options": [
			{"label": "[싸운다]", "next_id": "guardian_fight_result", "flag_to_set": "resolved_guardian_peacefully", "flag_value": false},
			{"label": "[진정하라고 말을 건다]", "next_id": "guardian_peace_1", "flag_to_set": "resolved_guardian_peacefully", "flag_value": true},
		],
	},
	{
		"id": "guardian_fight_result",
		"speaker": "???",
		"text": "...그런가. ...결국은... 이런 식으로...",
		"narration": "(짧고 격렬한 충돌 끝에, 수호자가 무너져 내린다)",
		"is_decisive": false,
		"next_id": "guardian_fight_aftermath",
	},
	{
		"id": "guardian_fight_aftermath",
		"speaker": "???",
		"text": "",
		"narration": "(물길이 다시 흐르기 시작한다. 하지만 어딘가 씁쓸한 기분이 가시지 않는다)",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "guardian_peace_1",
		"speaker": "???",
		"text": "...진정하라고? ...오랜만에 듣는 말이군. 나는... 원래 이 물길을 지키던 존재였다. 그런데 언제부턴가 힘이 빠져나가고, 대신 이상한 것이 나를 좀먹기 시작했어.",
		"is_decisive": false,
		"next_id": "guardian_peace_2",
	},
	{
		"id": "guardian_peace_2",
		"speaker": "???",
		"text": "...그대라면, 이걸 알아챌 수 있을 것 같군. 나쁜 뜻은 없었다. 그저... 버티는 게 버거웠을 뿐.",
		"narration": "(수호자의 몸에서 옅은 빛이 스며 나온다 — 미아가 보았던 그 빛과 닮았다)",
		"is_decisive": false,
		"next_id": "guardian_peace_hint",
	},
	{
		"id": "guardian_peace_hint",
		"speaker": "???",
		"text": "...누군가는 알아챌 줄 알았다. 이 땅 곳곳에서... 같은 일이 일어나고 있다는 걸. 나 혼자만의 일이 아니야.",
		"narration": "(먼 곳을 응시하는 듯한 눈빛, 더는 설명하지 않는다)",
		"is_decisive": false,
		"next_id": "guardian_peace_3",
	},
	{
		"id": "guardian_peace_3",
		"speaker": "???",
		"text": "...고맙다. 이제야... 제대로 쉴 수 있겠어.",
		"narration": "(물길이 다시 흐르기 시작한다. 동굴 안 공기가 한결 가벼워진 느낌이다)",
		"is_decisive": false,
		"options": [],
	},
]

# 게임 최초 시작 시 한 번만 보여주는 오프닝 인트로 (GameState.seen_opening으로 반복 방지)
const OPENING_DIALOGUE: Array = [
	{
		"id": "opening_1",
		"speaker": "",
		"narration": "아주 오래전, 이 땅 아래에는 셀 수 없이 많은 물줄기가 흘렀다고 한다",
		"is_decisive": false,
		"next_id": "opening_2",
	},
	{
		"id": "opening_2",
		"speaker": "",
		"narration": "사람들은 그 물줄기를 그저 '맥(脈)'이라 불렀다 — 마을과 숲, 산과 들판까지, 세상 모든 살아있는 것들이 그 물에 기대어 살았다",
		"is_decisive": false,
		"next_id": "opening_3",
	},
	{
		"id": "opening_3",
		"speaker": "",
		"narration": "그런데 어느 순간부터, 그 맥이 하나둘 마르기 시작했다. 이유를 아는 이는 아무도 없었다",
		"is_decisive": false,
		"next_id": "opening_4",
	},
	{
		"id": "opening_4",
		"speaker": "",
		"narration": "맥이 마른 땅은 서서히 병들었다. 곡식이 시들고, 짐승이 떠나고, 끝내는 사람도 살 수 없는 곳이 되어갔다고 한다",
		"is_decisive": false,
		"next_id": "opening_5",
	},
	{
		"id": "opening_5",
		"speaker": "",
		"narration": "당신이 머물고 있는 이 작은 마을은, 그런 이야기들과는 먼 곳이었다. 변두리라, 다행히도 지금까지는",
		"is_decisive": false,
		"next_id": "opening_6",
	},
	{
		"id": "opening_6",
		"speaker": "",
		"narration": "그런데 오늘 아침, 마을의 우물이 처음으로 말랐다",
		"is_decisive": false,
		"options": [],
	},
]
