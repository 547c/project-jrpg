class_name SubQuestData
extends RefCounted

# 서브 퀘스트(의뢰) 카탈로그 — 아직 내용이 없는 확장 지점이다.
#
# 메인 퀘스트(GameState.quests)는 스토리 진행에 묶여 있어 개수가 고정이고 순서도 정해져 있다.
# 반면 서브 퀘스트는 "의뢰판에서 받아 아무 때나 수행하는" 성격이라 성질이 달라서, 메인 퀘스트
# 딕셔너리에 섞지 않고 처음부터 별도 카탈로그로 자리를 잡아둔다 —
# 나중에 의뢰판을 붙일 때 GameState.quests의 구조를 건드리지 않아도 되게 하려는 것.
#
# [지금은 비어 있다] 퀘스트 화면의 "서브 퀘스트" 탭은 이 목록이 비어 있으면 안내 문구만 보여준다.
# 실제 의뢰 시스템(수락/진행/보상/의뢰판 UI)은 아직 만들지 않았고, 이 파일은 그때 채울 자리다.
#
# [채울 때의 예상 형태] 메인 퀘스트와 같은 필드 이름을 쓰면 화면 쪽 코드를 거의 그대로 재사용할 수 있다:
#   "sub_herb": {
#       "title": "약초 채집",
#       "giver": "엘라라",
#       "target": 5,
#       "description": "숲에서 약초를 모아온다.",
#   }
# 진행 상태(current/active/complete)는 카탈로그가 아니라 GameState 쪽에 저장해야 세이브에 담긴다
# (메인 퀘스트가 DEFAULT_QUESTS(정의)와 quests(상태)로 나뉘어 있는 것과 같은 이유).
const SUB_QUESTS: Dictionary = {}


# 정의된 서브 퀘스트가 하나라도 있는지. 퀘스트 화면이 "곧 추가될 예정" 안내를 띄울지
# 실제 목록을 그릴지 이 함수로 가른다 — 나중에 SUB_QUESTS만 채우면 화면 코드는 안 고쳐도 된다
static func has_any() -> bool:
	return not SUB_QUESTS.is_empty()


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in SUB_QUESTS.keys():
		ids.append(String(id))
	return ids


# id에 해당하는 서브 퀘스트 정의 (없으면 빈 Dictionary)
static func get_quest(id: String) -> Dictionary:
	return SUB_QUESTS.get(id, {})
