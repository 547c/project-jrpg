# UI 전면 개편 (나무판자 → Franuka RPG UI Pack)

> 2026-08-16 시작. 기존 medieval.png 목재 텍스처를 쓰는 화면 11개를
> Franuka 팩으로 전면 교체. 타이틀 화면은 나중에 별도로 크게 갈아엎을
> 예정이라 이번 범위에서 제외.

## 원칙
화면마다 **성격에 맞는 서로 다른 프레임/톤**을 쓴다 (예전에 나무판자로
전부 통일했다가 단조로워졌던 실수 반복 금지). 단, 장식 없는 "중립
유틸리티 버튼" 3종(`Button_04A`/`Button_01B`/`Button_02B`)은 여러
화면에 재사용 — 이건 의도적 디자인 시스템.

## 이미 완료됨 (기준선, 겹치면 안 됨)
- **스펠북**: `Spellbook.png`, `Button_01A`, `Button_02A`, `BGbox_01A`(팝업)
- **퀘스트로그**: `BGbox_07A`(아이비), `BannerMedium_04A`(제목),
  `BannerSmall_06A`(탭 필), `Divider_07`(금 다이아몬드)

## 화면별 확정 매핑

| # | 화면 | 파일 | 조합 | 상태 |
|---|---|---|---|---|
| 1 | 일시정지 (pause_menu.tscn) | `BGbox_02B`(청록 단순틀) + `BannerSmall_02B` + `Button_05A`(파랑) | ✅ |
| 2 | 저장/불러오기 (save_slot_menu.tscn) | `BGbox_01C`(금 이중테두리) + `BannerMedium_02C`(금 리본) + `Button_04A`(슬롯) + `Button_02B`(닫기) | ✅ |
| 3 | HUD (hud.tscn — 목표패널/버튼3개/스탯카드) | `BannerMedium_05A`(목표) + `Slider01_Box`+`Bar`(스탯) + `Button_02D`(버튼 3개) | ⬜ |
| 4 | 레벨업 팝업 (level_up_popup.tscn) | `BGbox_03A`(금 브라켓+보석) + `BannerMedium_01C`(금 육각 배너) + `Button_03C`(원형 금 OK) | ⬜ |
| 5 | 엔딩기록 (ending_record_menu.tscn) | `BGbox_04B`(낡은 천 주머니) + `BannerMedium_02A` + `Divider_02` + `Button_04A` | ⬜ |
| 6 | 게임오버 (game_over_screen.tscn) | `BGbox_01B`(강철/청회색, 어둡게 톤다운) + `Button_06A`(짙은 적색) — 또는 프레임 없이 버튼만 쓰는 미니멀 안 | ⬜ |
| 7 | 컷신 스킵 확인 (cutscene_box.tscn) | `BGbox_08A`(가장 작은 이중테두리) + `Button_01B`(예) + `Button_04A`(아니요) | ⬜ |
| 8 | 인벤토리 (inventory_menu.tscn) | `BGbox_06A`(금속 클램프) + `Item slots Slot_02_*`(청록, 장비별 실루엣 9종) + `Button_05A` | ⬜ |
| 9 | 대화창 선택지 (dialogue_box.tscn) | `BGbox_02A`(주황-갈색 단순틀) + `Button_01B` — NPC 패널은 기존 커스텀 유지, 화살표도 medieval.png 그대로(팩에 대체품 없음) | ⬜ |
| 10 | 잡화/무기상점 (shop_menu.tscn, weapon_shop_menu.tscn) | `BGbox_05A`(적갈 목판) + `BannerSmall_02A` + `Button_02B`(구매) + `Button_01D`(페이지네이션) | ⬜ |

## 진행 방식
2~3개씩 묶어서 순서대로 진행 (한 번에 다 하면 검증 어려움). 각 배치
끝날 때마다 이 표의 상태를 ✅로 갱신.

## 참고
목업은 파이썬 근사 스케일링이라 실제 Godot `StyleBoxTexture` margin은
화면 적용 시 재측정 필요 (퀘스트로그 때 `BGbox_07A` patch 28처럼).

## 실측한 9-slice margin (2026-08-18, 1·2번 작업분)

늘렸을 때 가장자리 장식이 반복/뭉개지지 않는 최소값을 텍스처마다 픽셀 단위로
재서 정했다. 재는 방법: "중앙 열들이 서로 완전히 같아야 가로로 늘려도 안전하고,
중앙 행들이 서로 같아야 세로로 안전하다"는 기준으로 최소 margin을 찾고,
실제 목표 크기로 렌더해서 눈으로 확인.

| 텍스처 | 원본 | margin (L,T,R,B) | axis stretch |
|---|---|---|---|
| `BGbox_02B` | 96x96 | 32, 32, 32, 32 | TILE 양방향 |
| `BGbox_01C` | 96x96 | 32, 32, 32, 32 | TILE 양방향 |
| `BannerSmall_02B` | 96x32 | 28, 14, 28, 14 | 가로 TILE |
| `BannerMedium_02C` | 96x64 | 28, 30, 28, 30 | 가로 TILE |
| `Button_05A` | 96x32 | **18, 14, 50, 14** | STRETCH |
| `Button_04A` | 96x32 | **18, 14, 50, 14** | STRETCH |
| `Button_02B` | 64x32 | 22, 12, 22, 12 | STRETCH |

**버튼 좌우가 비대칭인 이유**: `Button_04A`/`05A`는 가운데(원본 x 46~49)에
긁힌 자국 픽셀이 박혀 있다. 대칭 margin을 쓰면 그 자국이 늘어나 버튼 전체를
가로지르는 띠가 되거나(STRETCH), 일정 간격으로 반복돼 물방울무늬처럼 보인다(TILE).
깨끗한 열은 18~45번뿐이라 왼쪽 18 / 오른쪽 50으로 잡아 그 구간만 늘어나게 했다.
세로 14는 같은 이유(깨끗한 행이 14~17번뿐)다.

**배너 높이**: 두 배너 다 글자가 리본 아래 접힌 부분에 걸리길래, 늘어나는
중앙 행이 리본 본체 안(단색)이라는 걸 확인하고 배너를 원본보다 키웠다
(Small 32→48, Medium 64→72). `content_margin`은 늘린 뒤의 본체 범위에 맞춰
계산해서 글자가 정확히 리본 가운데 오도록 했다.
