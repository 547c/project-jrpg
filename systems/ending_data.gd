class_name EndingData
extends RefCounted

# 엔딩 도감(기록)에 표시할 엔딩 목록. 표시 순서 = 이 배열의 순서.
# 2부 엔딩이 추가되면 여기에 항목만 늘리면 되고, 도감 UI(ui/ending_record_menu.gd)는
# 이 배열을 그대로 순회해 슬롯을 만들기 때문에 UI 쪽 수정 없이 자동으로 확장된다.
# id는 GameState.seen_endings에 기록되는 값과 정확히 일치해야 한다
# (엔딩 씬은 endings/ending_screen.gd가 scene_file_path로부터 id를 도출해 기록한다).
const ENDINGS: Array = [
	{
		"id": "part1_good",
		"title": "다시, 생명이 흐르다",
		"description": "수호자를 평화롭게 돌려보내고 미아의 신뢰까지 얻었다. 맥이 다시 흐르고, 당신은 마을의 일부가 되었다.",
	},
	{
		"id": "part1_neutral",
		"title": "불완전한 평화",
		"description": "물은 돌아왔지만 무언가는 끝내 채워지지 않았다. 해결된 것과 놓친 것이 함께 남았다.",
	},
	{
		"id": "part1_bad",
		"title": "씁쓸한 승리",
		"description": "수호자는 사라졌고 우물은 여전히 말라있다. 되돌릴 수 없는 것을 잃은 채 얻은 결말.",
	},
]

# 아직 보지 못한 엔딩 슬롯에 표시할 문구
const LOCKED_TITLE := "???"
const LOCKED_DESCRIPTION := "아직 도달하지 않은 엔딩입니다"


# 전체 엔딩 개수 (도감 진행도 표시용)
static func total_count() -> int:
	return ENDINGS.size()


# id에 해당하는 엔딩 정의를 반환 (없으면 빈 Dictionary)
static func get_ending(ending_id: String) -> Dictionary:
	for ending in ENDINGS:
		if ending["id"] == ending_id:
			return ending
	return {}
