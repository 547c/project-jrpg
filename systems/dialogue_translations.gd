extends RefCounted

# 대사 번역 테이블. dialogue_data.gd는 손대지 않고(한국어가 계속 원본/기본값),
# 여기서 노드 id를 키로 번역만 얹는다. 키가 없으면 dialogue_box가 한국어 원문으로 그대로 폴백한다.
#
# 키 형식:
#   "<node_id>"             일반 text
#   "<node_id>:narration"   지문
#   "<node_id>:cold|neutral|warm|trusted"  text_by_affinity_tier 노드의 구간별 대사
#   "<node_id>:true|false"  text_if_flag / text_false 노드의 분기별 대사
#
# 현재는 시스템 검증용 샘플만 채워져 있다 (전체 260개 노드 번역은 이후 단계).

const EN: Dictionary = {
	"elara_greeting:cold": "...What is it.",
	"elara_greeting:neutral": "Ah, it's you. Here about the well, I imagine.",
	"elara_greeting:warm": "You've come. Seeing you puts my mind at ease.",
	"elara_greeting:trusted": "I'm glad you're here. These days your face alone is a comfort.",

	"elara_well": "Yes, you'd be wondering about that. The village has been in quite a state these past few days.",
	"elara_well_incident": "It was three nights ago... just past midnight, I believe. The whole village shook with a great CRASH! More than a few of us were startled awake. Myself included.",

	"rohan_quest_status:true": "You cleared out every last orc? ...Impressive. That was no small task.",
	"rohan_quest_status:false": "They're still out there in the forest. Don't push yourself — be careful.",

	"guardian_entrance:narration": "(An old stone altar sits at the entrance. Long-withered flowers and a few faded bowls still rest upon it. From deeper within, a faint but unmistakable blue light seeps out.)",

	"elara_grind_advice_1:narration": "(Her expression turns serious the moment she sees you.)",
	"elara_grind_advice_1": "...So you've spoken with all of them. I can tell just by looking at you.",
}

const TABLES: Dictionary = {
	"en": EN,
}


# 현재 언어의 번역을 반환. 번역이 없거나 한국어면 빈 문자열 — 호출부가 원문으로 폴백한다
static func get_line(key: String) -> String:
	if key == "":
		return ""
	var table: Dictionary = TABLES.get(LocaleManager.current_locale(), {})
	return table.get(key, "")
