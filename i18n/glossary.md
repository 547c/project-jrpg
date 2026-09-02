# Translation Glossary (KO -> EN)

Draft for review before full localization. Source: `docs/world.md`
(already-translated lore doc), existing samples in
`systems/dialogue_translations.gd` and `i18n/ui_strings.csv`, and terms
found directly in `systems/dialogue_data.gd` / `docs/part1_story_script_draft.md`.

## Already established (docs/world.md / existing samples) — use as-is

| Korean | English (established) | Seen in |
|---|---|---|
| 맥 | Vein(s) | docs/world.md |
| 감시자 | Watcher(s) | docs/world.md |
| 물지기 | Warden | docs/world.md |
| 수호신 (표면 세계 위장 신화 속 명칭) | Guardian spirit | docs/world.md |
| 지하 세계 | the underground (world) | docs/world.md |
| 돌 제단 | stone altar | docs/world.md, dialogue_translations.gd |
| 진실 | the Truth | docs/world.md |
| 오르시아 | Orsia | docs/world.md, dialogue_data.gd |
| 유적 | ruins | docs/world.md |
| 필터룸 | Filter Room | docs/world.md |
| 수호자 (동굴 보스) | Guardian | dialogue_data.gd, systems/game_state.gd (get_objective_text) |
| 계속하기 | Continue | ui_strings.csv |
| 저장하기 / 불러오기 | Save / Load | ui_strings.csv |
| 퀘스트 / 메인 퀘스트 / 서브 퀘스트 | Quests / Main / Side | ui_strings.csv |
| 의뢰인 | Client | ui_strings.csv |

## New terms needing a translation decision

| 한국어 원문 | 제안 영어 번역 | 등장 위치 |
|---|---|---|
| 결절점 | nodal point | docs/part1_story_script_draft.md, dialogue_data.gd (유서프 고백: "결절점에 이상이 생기면") |
| 결절점 불안정 | nodal instability | docs/part1_story_script_draft.md (숲/동굴/사막 몬스터 흉포화 사유) |
| 문지기 (유적 보스 "???") | the Gatekeeper | world/ruins_boss.gd, dialogue_data.gd |
| 폭주한 근원체 (RUINS_BOSS 내부 이름) | Runaway Wellspring | systems/battle_data.gd |
| 우물지기 (마을의 평범한 우물 관리인 — 물지기와 혼동 주의) | well-keeper | dialogue_data.gd (elara_well_incident 등) |
| 생명의 근원 | the source of life | dialogue_data.gd, docs/part1_story_script_draft.md |
| 봉인 (물지기를 가두는 계약/구속) | the binding / seal | dialogue_data.gd (씬5, 씬12: "봉인 해제") |
| 봉인 해제 (필터룸 선택지) | Release the binding | dialogue_data.gd |
| 낙원 (시대) | the paradise age | docs/part1_story_script_draft.md |
| 회수 (감시자들이 맥을 빼돌리는 행위, 유서프 고백에서 은어처럼 사용) | "collection" (used as their euphemism, keep quoted) | dialogue_data.gd (씬9) |
| 필터 ("장치"로 위장된 물지기의 정체, 유서프/카밀 대사에서 반복) | the "filter" | dialogue_data.gd |
| 신뢰의 기로 (씬13 제목) | Threshold of Trust | docs/part1_story_script_draft.md |
| 잊혀진 진실 (Part2 챕터 타이틀) | The Forgotten Truth | world/dock.gd (PART2_SUBTITLE) |
| 문지기 대치 대사: "허가되지 않은 자. 물러가라." | "Unauthorized. Withdraw." | world/ruins_boss.gd |
| 오크 (몬스터) | Orc | systems/battle_data.gd, 의뢰판/퀘스트로그 몬스터 이름 |
| 스켈레톤 (몬스터) | Skeleton | systems/battle_data.gd, 의뢰판/퀘스트로그 몬스터 이름 |
| 미라 (몬스터) | Mummy | systems/battle_data.gd, 의뢰판/퀘스트로그 몬스터 이름 |

## NPC names (reference only — already used as-is, romanized, no translation needed)

Elara, Rohan, Yusuf, Mia, Kamil, Nadim, Kasim.
