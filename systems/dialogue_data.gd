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
#         },
#     ],
# }
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
		"is_decisive": false,
		"options": [
			{"label": "[우물에 대해 묻는다]", "next_id": "elara_well"},
			{"label": "[마을에 대해 묻는다]", "next_id": "elara_village"},
			{"label": "[그냥 안부를 묻는다]", "next_id": "elara_smalltalk"},
			{"label": "[다른 사람들에 대해 묻는다]", "next_id": "elara_gossip", "show_if_flag": "met_rohan"},
			{"label": "[다녀왔다고 말한다]", "next_id": "elara_ending_check", "show_if_flag": "guardian_event_done"},
		],
	},
	{
		"id": "elara_well",
		"speaker": "엘라라",
		"text": "사흘 전부터 한 방울도 안 나와. 이런 적은... 내 평생 처음이야.",
		"is_decisive": false,
		"options": [
			{"label": "[심각한 건가요?]", "next_id": "elara_well_serious"},
			{"label": "[제가 도와드릴게요]", "next_id": "elara_well_help"},
		],
	},
	{
		"id": "elara_well_serious",
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
		"speaker": "엘라라",
		"text": "낸들 알겠나. 다만... 이런 일은 늘 조용히 찾아오지, 경고도 없이.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_well_help",
		"speaker": "엘라라",
		"text": "고맙구나. 숲의 로한을 먼저 만나보게. 동굴 근처에서 뭔가 봤다더군.",
		"is_decisive": false,
		"next_id": "elara_well_lore",
	},
	{
		"id": "elara_well_lore",
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
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_village",
		"speaker": "엘라라",
		"text": "작은 곳이지. 하지만 백 년 넘게 이 자리를 지켜왔어.",
		"is_decisive": false,
		"options": [
			{"label": "[오래됐네요]", "next_id": "elara_village_old"},
			{"label": "[평화로워 보여요]", "next_id": "elara_village_peace"},
		],
	},
	{
		"id": "elara_village_old",
		"speaker": "엘라라",
		"text": "그만큼 많은 걸 봐왔지. 좋은 일도, 나쁜 일도.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_village_peace",
		"speaker": "엘라라",
		"text": "평화... 그래, 지금까진 그랬지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_smalltalk",
		"speaker": "엘라라",
		"text": "안부라... 다정하기도 하지. 몸은 성한가?",
		"is_decisive": false,
		"options": [
			{"label": "[괜찮아요, 걱정 마세요]", "next_id": "elara_smalltalk_fine"},
			{"label": "[사실 좀 지쳤어요]", "next_id": "elara_smalltalk_tired"},
		],
	},
	{
		"id": "elara_smalltalk_fine",
		"speaker": "엘라라",
		"text": "다행이군. 젊은이가 튼튼해야 마을도 든든하지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "elara_smalltalk_tired",
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
		"is_decisive": false,
		"options": [
			{"label": "[동굴에 대해 묻는다]", "next_id": "rohan_cave"},
			{"label": "[숲에 대해 묻는다]", "next_id": "rohan_forest"},
			{"label": "[사냥은 잘 되냐고 묻는다]", "next_id": "rohan_smalltalk"},
			{"label": "[오크 처치를 돕겠다고 한다]", "next_id": "rohan_quest_accept", "start_quest": "forest_orcs", "show_if_quest_inactive": "forest_orcs"},
			{"label": "[오크는 어떻게 되어가요?]", "next_id": "rohan_quest_status", "show_if_quest_active": "forest_orcs"},
			{"label": "[다른 사람들에 대해 묻는다]", "next_id": "rohan_gossip", "show_if_flag": "met_elara"},
		],
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
		"is_decisive": false,
		"options": [
			{"label": "[위험한가요?]", "next_id": "rohan_cave_danger"},
			{"label": "[뭘 봤나요?]", "next_id": "rohan_cave_saw"},
		],
	},
	{
		"id": "rohan_cave_danger",
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
		"speaker": "로한",
		"text": "숲에서 오래 살다 보면... 직감 말곤 믿을 게 없어질 때가 있지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_cave_saw",
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
		"speaker": "로한",
		"text": "...아니. 이건 자네 몫이야. 난 마을을 지켜야지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_opinion_talk",
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
		"speaker": "로한",
		"text": "위험한 건 위험한 거야. 대화로 풀릴 거였으면 애초에 이런 일이 안 생겼겠지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_forest",
		"speaker": "로한",
		"text": "조심해서 다녀. 요즘 숲이 심상치 않아.",
		"is_decisive": false,
		"options": [
			{"label": "[구체적으로 뭐가 이상한가요?]", "next_id": "rohan_forest_detail"},
			{"label": "[알겠어요]", "next_id": ""},
		],
	},
	{
		"id": "rohan_forest_detail",
		"speaker": "로한",
		"text": "나무들이... 말라가고 있어. 원래 이 계절엔 이러지 않는데.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_smalltalk",
		"speaker": "로한",
		"text": "사냥? ...요즘은 예전만 못해. 짐승들도 뭔가 눈치챈 건지 다들 숨어버렸어.",
		"is_decisive": false,
		"options": [
			{"label": "[짐승들이 왜 숨었을까요?]", "next_id": "rohan_smalltalk_animals"},
			{"label": "[그럼 뭘 드시고 사세요?]", "next_id": "rohan_smalltalk_food"},
		],
	},
	{
		"id": "rohan_smalltalk_animals",
		"speaker": "로한",
		"text": "글쎄. 짐승은 사람보다 먼저 위험을 아는 법이지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "rohan_smalltalk_food",
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
		"is_decisive": false,
		"options": [
			{"label": "[동굴 이야기를 묻는다]", "next_id": "yusuf_cave_hint"},
			{"label": "[당신은 누구세요?]", "next_id": "yusuf_who"},
			{"label": "[뭘 팔고 있어요?]", "next_id": "yusuf_wares"},
			{"label": "[스켈레톤 처치를 돕겠다고 한다]", "next_id": "yusuf_quest_accept", "start_quest": "cave_skeletons", "show_if_quest_inactive": "cave_skeletons"},
			{"label": "[스켈레톤은 어떻게 되어가요?]", "next_id": "yusuf_quest_status", "show_if_quest_active": "cave_skeletons"},
			{"label": "[다른 사람들에 대해 묻는다]", "next_id": "yusuf_gossip", "show_if_flag": "met_elara"},
		],
	},
	{
		"id": "yusuf_quest_accept",
		"speaker": "유서프",
		"text": "오, 도와준다니 든든하군! 동굴 입구 쪽에 스켈레톤 셋이 얼쩡거리고 있어. 놈들을 처리해주면 내가 섭섭지 않게 사례하지.",
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
		"is_decisive": false,
		"options": [
			{"label": "[무슨 뜻이죠?]", "next_id": "yusuf_cave_hint2"},
			{"label": "[알 것 같아요, 고마워요]", "next_id": ""},
		],
	},
	{
		"id": "yusuf_cave_hint2",
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
		"speaker": "유서프",
		"text": "이곳저곳 떠돌다 보면... 비슷한 이야기를 몇 번 들었지.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_who",
		"speaker": "유서프",
		"text": "그냥... 이곳저곳 떠도는 상인이지. 그 이상은... 훗날 알게 될 걸세.",
		"is_decisive": false,
		"options": [
			{"label": "[수상한데요?]", "next_id": "yusuf_who_suspicious"},
			{"label": "[알겠어요, 안 물어볼게요]", "next_id": ""},
		],
	},
	{
		"id": "yusuf_who_suspicious",
		"speaker": "유서프",
		"text": "수상하다니, 섭섭한걸. ...뭐, 완전히 틀린 말은 아니지만.",
		"is_decisive": false,
		"options": [],
	},
	{
		"id": "yusuf_wares",
		"speaker": "유서프",
		"text": "이것저것 있지. 다른 마을에서 가져온 물건들이야.",
		"is_decisive": false,
		"options": [
			{"label": "[다른 마을은 어떤가요?]", "next_id": "yusuf_other_villages"},
			{"label": "[딱히 필요한 건 없어요]", "next_id": ""},
		],
	},
	{
		"id": "yusuf_other_villages",
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
		],
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
			{"label": "[요즘 어때?]", "next_id": "mia_smalltalk_ok"},
		],
	},
	{
		"id": "mia_smalltalk_ok",
		"speaker": "미아",
		"text": "이제 무섭지 않아요. 당신 덕분에요.",
		"text_if_flag": "earned_mia_trust",
		"text_false": "...그냥 그래요.",
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
