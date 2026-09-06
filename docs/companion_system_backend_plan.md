# 동료 시스템 Phase 1 — 백엔드 골격 설계안

`docs/companion_system_options.md`의 "6. 결정 (2026-09-06 확정 — C안)"을 전제로 한 Phase 1 설계 조사.
이 문서는 **설계안과 결정 필요 목록**까지만 다룬다. 구현은 결정이 끝난 뒤 별도로 진행한다.

Phase 1의 범위는 `CompanionState` 클래스 신설 + 플레이어 쪽 리팩터링 범위 판단이다.
전투 통합(피격 대상 일반화, 자동 행동, 패시브/액티브 발동)은 Phase 3이고, 여기서는
**Phase 3이 무리 없이 올라탈 수 있는 형태인지**만 기준으로 삼는다.

---

## 1. 조사 요약 — Phase 1에 직접 걸리는 사실들

### 1-1. 아군/적군 비대칭이 이미 코드에 명문화돼 있다

`battle/battle_turn_manager.gd:10-14`가 상태 보관 분담을 못 박아 두었다:

| 대상 | 보관 위치 | 생존 범위 |
|---|---|---|
| 플레이어 HP/마나 | `GameState.flags` | 전투 밖까지 유지, 세이브 포함 |
| 몬스터 전체 상태 | 매니저의 `monsters: Array[MonsterState]` | 전투 종료 시 소멸 |

**중요한 예외가 이미 있다**: 플레이어의 *전투 한정* 상태는 이미 매니저가 들고 있다 —
`player_status: StatusEffects`(`:41`), `_pending_defense` / `_pending_dodge` / `_pending_counter`.
즉 실제 규칙은 "플레이어는 GameState"가 아니라 **"영속 값은 GameState, 전투 한정 값은 매니저"**다.
이 구분선이 Phase 1 설계의 기준선이 된다.

### 1-2. `-1 = 플레이어` 인덱스 관례가 이미 존재한다

타겟 인덱스 공간이 초보적인 형태로 이미 있다:

- `status_applied(target_index)` — 주석에 "target_index가 -1이면 플레이어 자신" (`:26-27`)
- `apply_status(target_index, ...)` (`:477`), `_status_container_for(target_index)` (`:510-513`) —
  `target_index < 0`이면 `player_status`, 아니면 `monsters[i].status`
- `play_card(card, target_index = -1)` (`:216`) — 여기서 -1은 의미가 다르다(자동 타겟)

→ **동료를 이 인덱스 공간에 어떻게 끼워 넣을지가 Phase 1의 숨은 결정 지점**이다(§6 Q4).

### 1-3. 피격 대상 하드코딩 3곳

| 위치 | 내용 | Phase 3에서 해야 할 일 |
|---|---|---|
| `:614` | `if GameState.get_flag("player_hp") <= 0: break` — 플레이어가 죽으면 남은 몬스터가 안 때림 | "때릴 대상이 아무도 없으면 중단"으로 일반화 |
| `:639` | `_resolve_single_attack(attacker)` — **누구를 때릴지 인자가 아예 없다** | 대상 인자 추가 + 적 AI 타겟 선택 |
| `:661` | `GameState.damage_player(damage_taken)` | 대상의 `take_damage()` 호출로 교체 |

추가로 `:559-560`의 승패 판정(`player_hp <= 0` → `_finish_battle(true)`)이
**"파티 전원 다운"으로 바뀌어야 한다** — 확정 스펙의 핵심이자, 목록에 빠져 있던 4번째 지점이다.

### 1-4. 참조 규모 (실측, 스테일 워크트리 `.claude/worktrees/` 제외)

| 대상 | 개수 |
|---|---|
| `player_hp` 참조 | **43** (battle_scene 19, game_state 13, battle_turn_manager 6, save_manager 3, save_slot_menu 1, hud 1) |
| `damage_player`/`heal_player_*` 호출부 | **9** (battle_turn_manager 5, battle_scene 1, inventory_menu 1, game_over_screen 1, campfire 1) |
| `battle_scene.gd`의 `_player_sprite` 참조 | **64** (Phase 3 연출 범위, Phase 1과 무관) |

플레이어 상태를 건드리는 실질 진입점은 43개가 아니라 **9개 함수 호출**이다. 이 차이가 §3 판단의 핵심이다.

### 1-5. 전투 중에는 인벤토리/HUD가 잠긴다

`battle_scene.gd:821`이 `battle_box` 그룹에 등록하고, `player.gd:_is_input_blocked()`와 `hud.gd`가
이 그룹을 보고 입력/표시를 막는다. → **전투 중 GameState.flags의 플레이어 HP를 바꾸는 외부 경로가 현재는 없다.**
(포션은 `inventory_menu.gd:229`, 캠프파이어는 `campfire.gd:128` — 둘 다 전투 밖 전용)

### 1-6. 세이브 하위호환은 사실상 공짜

- `save_manager.gd:32-50`이 GameState 필드를 납작하게 통째 저장한다.
- `restore_flags()`(`game_state.gd:274`)는 **기본값 리셋 → 저장값 덮어쓰기** 순서라, 구버전 세이브에
  없는 키는 자동으로 기본값이 된다.
- 최상위 키는 `restore_X(data.get("키", 기본값))` 패턴 — `unlocked_cards`/`battle_deck`이 선례이고,
  `save_manager.gd:76-81`에 "이 키가 없는 구버전 세이브" 처리 주석까지 이미 달려 있다.
- **복원 순서 의존성 선례**도 있다: 덱은 잠금해제 목록보다 뒤에 복원해야 한다(`:79-81`). 동료도 같은 제약이 생긴다(§5).

### 1-7. 재사용 가능한 기존 자산

- 호감도: `DEFAULT_AFFINITY`(`game_state.gd:51`)에 `yusuf`/`elara`/`rohan` 이미 존재
- 초상화: `dialogue_box.gd:41` `PORTRAITS`에 유서프 항목 존재
- 리스트형 데이터는 flags가 아니라 전용 var로 두는 관례가 명문화돼 있다(`game_state.gd:72-74`, `unlocked_cards` 주석)

---

## 2. `CompanionState` 설계안

`MonsterState`를 본뜨되, **의도적으로 뺀 것**이 설계의 절반이다.

```
class_name CompanionState
extends RefCounted

# ── 정체성 ────────────────────────────────
index: int              # 파티 슬롯 번호 (0부터). 스프라이트/HUD 카드 매칭 키
companion_id: String    # "yusuf" — affinity / PORTRAITS / CompanionData 공용 키
data: Dictionary        # CompanionData.COMPANIONS[companion_id] (스탯표 참조)
display_name: String    # tr()된 표시 이름

# ── 전투 수치 ──────────────────────────────
max_hp: int
hp: int
status: StatusEffects   # 플레이어/몬스터와 같은 클래스 재사용

# ── 능력 ──────────────────────────────────
active_cooldown: int    # 0이면 액티브 사용 가능
passive_counter: int    # 패시브 주기 카운터 (유서프: 5턴마다)

# ── 메서드 ────────────────────────────────
is_alive() -> bool                 # hp > 0
take_damage(amount) -> int         # 실제 깎인 양 반환
heal(amount) -> int                # 실제 회복량 반환
roll_attack_damage() -> int        # data의 damage_min~max 무작위
can_use_active() -> bool           # is_alive() and active_cooldown == 0
start_active_cooldown() -> void
tick_round() -> void               # 쿨다운 -1, 패시브 카운터 +1
consume_passive_trigger() -> bool  # 주기 도달 시 true 반환 + 카운터 리셋
```

### 설계 근거

**`take_damage`/`heal`이 "실제 변화량"을 반환하는 규약을 그대로 따른다.**
`MonsterState:76-94`의 이유(화면 팝업 숫자와 HP바 변화가 어긋나지 않게)가 동료에게도 그대로 적용된다.

**`is_down`을 bool 필드로 두지 않고 `is_alive()`로 파생시킨다.**
`hp`와 별도 bool을 함께 들면 둘이 어긋날 수 있다. 이 코드베이스는 이미 파생값 이중 보관으로
한 번 데인 적이 있다 — `player_max_hp`/`player_base_max_hp` 경고 주석(`game_state.gd:123-127`)이 그 흔적이다.
"다운"은 상태가 아니라 `hp <= 0`의 다른 이름일 뿐이다.

**`mana`를 넣지 않는다.** 몬스터 마나는 "공격/숨고르기를 오간다"는 리듬을 만드는 연출용 장치다
(`monster_state.gd:29-36`). 동료는 확정 스펙상 *매 턴 자동 공격*이고 액티브는 *쿨다운*으로 리듬이 생긴다.
같은 역할의 자원을 둘 두면 튜닝 축만 늘어난다. → 다만 "동료도 쉬는 턴이 있어야 한다"면 결정 사항(§6 Q8).

**`resistance`(EnemyResistance)를 넣지 않는다.** 저항은 *플레이어 카드의 속성*에 대한 감쇄 규칙이고,
확정 스펙상 플레이어 카드는 여전히 적만 타겟한다. 동료를 때리는 건 몬스터의 평타뿐이라 속성 개념이 없다.

**`rewarded`를 넣지 않는다.** 보상은 몬스터 처치에만 붙는다.

### 카탈로그: `CompanionData` 신설

`BattleData.MONSTERS`와 같은 "그냥 표" 성격의 정적 데이터. 최소 필드:

```
COMPANIONS = {
  "yusuf": {
    "name": "유서프",
    "max_hp": ?,
    "damage_min": ?, "damage_max": ?,
    "passive": { "period": 5, "kind": ?, "amount": ? },
    "active":  { "cooldown": ?, "kind": "MANA_BARRIER", "amount": ? },
  },
}
```

수치는 전부 미정(§6 Q9). Phase 1에서는 **키 구조만 확정**하고 값은 플레이스홀더로 두는 게 맞다 —
밸런싱은 Phase 4에서 실제로 굴려 보며 잡는 게 정상 순서다.

### 결정 분기: CompanionState의 생존 범위

이게 §2에서 가장 중요한 갈림길이다.

| | 전투 한정 (MonsterState형) | 영속 (플레이어형) |
|---|---|---|
| HP 출처 | 전투 시작 시 항상 max_hp | GameState에 저장된 값에서 시작 |
| 전투 종료 후 | 객체째 소멸 | HP를 GameState에 write-back |
| 세이브 | 추가분 없음 | `companion_hp` 키 추가 |
| 체감 | 동료는 매 전투 리셋되는 "장치" | 동료도 플레이어처럼 관리 대상 |
| 위험 | "다운, 부활 없음"이 전투 안에서만 의미 | 회복 수단이 없으면 **영구 전멸**(§6 Q3) |

확정 스펙은 "개별 HP를 갖는다(공유 아님)"까지만 말하고 영속성은 언급하지 않았다. → **Q1**.

---

## 3. 플레이어 쪽 리팩터링 범위 — 3안 비교

핵심 질문: 동료가 개체 객체를 갖는데 플레이어만 납작한 flags로 남으면,
"파티원 하나를 때린다"는 코드가 **대상마다 다른 모양**을 상대해야 한다. 이걸 어떻게 없앨 것인가.

### A안 — 최소 변경 (플래그 몇 개만 추가)

`GameState.flags`를 플레이어의 집으로 그대로 두고, 매니저에 다운 상태만 추가한다.
`player_status`가 이미 매니저에 사는 것과 같은 취급(§1-1의 실제 규칙에 부합).

- 손대는 파일: `battle_turn_manager.gd`(대상 일반화 + 승패 판정), `battle_scene.gd`(패배 연출 분기)
- `GameState.damage_player()`가 플레이어의 쓰기 경로로 유지 → **나머지 43개 참조와 9개 호출부 전부 무손상**
- 타겟팅 코드는 `if 대상이 플레이어 → GameState.damage_player() / else → companion.take_damage()`로 분기

| 장점 | 리스크 최소, Phase 1 작업량 최소, 세이브 영향 0 |
|---|---|
| 단점 | "파티원"을 다루는 모든 코드에 플레이어 특례 분기가 영구히 남는다 |
| 엘라라/로한 추가 시 | **재작업 없음** — 동료가 몇 명이든 분기 구조는 동일 |

### B안 — 전면 리팩터링 (`PlayerState` 추출)

플레이어도 `CompanionState`와 같은 모양의 객체로 만들고, 전투 시작 시 GameState에서 읽어와
전투 중에는 객체가 권위를 갖고, 종료 시 write-back.

- 손대는 파일: `battle_turn_manager.gd` 전 플레이어 경로, `battle_scene.gd`(19개 참조), `game_state.gd`(동기화 API)
- **write-back 동기화 위험**: 전투 중 `GameState.flags.player_hp`가 낡은 값이 된다.
  현재는 전투 중 외부 쓰기 경로가 없어서(§1-5) *잠재적* 위험에 그치지만,
  전투 중 포션 사용 / 전투 중 HUD 표시 / 전투 중 자동 저장 중 **하나만 생겨도 즉시 실재 버그**가 된다.
  이 코드베이스는 파생값 이중 보관으로 이미 한 번 데였다(`game_state.gd:123-127`).

| 장점 | 파티원 3종이 완전히 같은 모양 → 타겟팅/피해 코드가 균일 |
|---|---|
| 단점 | 작업량 최대, 동기화 불변식이 새로 생김, Phase 1에서 얻는 실익 대비 위험이 큼 |
| 엘라라/로한 추가 시 | 재작업 없음 |

### C안 — 어댑터 (권고안)

플레이어 상태의 **집은 GameState 그대로 두되**, `CompanionState`와 같은 인터페이스를 노출하는
얇은 래퍼 `PlayerCombatant`를 두고 내부에서 `GameState`로 위임한다.

```
class_name PlayerCombatant
extends RefCounted

# 상태를 복사해 들고 있지 않다 — 전부 GameState로 위임한다.
# 그래서 write-back도, 동기화 불변식도 생기지 않는다.
is_alive()          -> GameState.get_flag("player_hp") > 0
take_damage(amount) -> GameState.damage_player(amount) 후 실제 감소량 반환
heal(amount)        -> GameState.heal_player_partial(...) 후 실제 회복량 반환
status              -> 매니저의 player_status를 가리킴
display_name        -> 플레이어 이름
```

매니저는 `party: Array`를 들고, 0번이 `PlayerCombatant`, 1번 이후가 `CompanionState`가 된다.
`_resolve_single_attack(attacker, target)`은 대상이 무엇인지 몰라도 `target.take_damage()`만 부르면 된다.

| 장점 | B안의 균일성 + A안의 안전성. 상태 복사본이 없으니 desync가 원천적으로 불가능 |
|---|---|
| 단점 | 클래스 하나 추가. `take_damage`가 "실제 변화량"을 돌려주려면 GameState 호출 전후를 재야 함(사소) |
| 손대는 파일 | `battle_turn_manager.gd` + 신규 파일 2개. `game_state.gd`는 **무손상** |
| 엘라라/로한 추가 시 | 재작업 없음 |

### 판단

**C안을 권고한다.** 근거:

1. 확정 스펙의 패배 조건("파티 전원 HP 0")은 *본질적으로 파티원을 순회하는 코드*를 요구한다.
   A안이면 그 순회가 매번 플레이어 특례를 안고 가고, 그 분기가 Phase 3(적 AI 타겟 선택)과
   Phase 5(4인 파티)에서 계속 복제된다.
2. B안의 유일한 추가 이득은 "플레이어 HP도 객체가 소유한다"인데, 그 대가가 동기화 불변식이다.
   전투 중 외부 쓰기가 막혀 있는 지금은 **이득 없이 위험만 사는 거래**다.
3. C안은 A안 대비 추가 비용이 클래스 하나뿐이고, 나중에 B안으로 갈 필요가 생겨도
   호출부는 이미 인터페이스로 말하고 있어 **내부만 갈아끼우면 된다.**

세 안 모두 **엘라라/로한 추가 시 재작업이 없다**는 점은 같다. 파티 규모 확장은 배열 길이 문제이지
구조 문제가 아니기 때문이다. 차이는 "그때까지 특례 분기를 몇 군데 더 복제해 두었을 것인가"다.

---

## 4. GameState의 동료 관리 설계안

```
# 리크루트 여부 — flags (대사 vocabulary가 그대로 붙는다)
DEFAULT_FLAGS += {
    "companion_yusuf_recruited": false,
}

# 현재 파티 구성 — 리스트라 전용 var (game_state.gd:72-74 관례)
var active_companions: Array = []        # ["yusuf"] — 순서가 곧 파티 슬롯

# (Q1이 "영속"일 때만) 동료별 잔여 HP
var companion_hp: Dictionary = {}        # {"yusuf": 18}

signal companions_changed                # 필드 팔로워 / 전투 HUD가 구독
```

### 근거

**리크루트 플래그를 flags에 두는 이유**: `set_flag_on_show` / `show_if_flag` 대사 어휘가 이미
23곳/13곳에서 쓰이고 있어, **대사 데이터만으로 합류 이벤트를 표현할 수 있다.** 코드 추가가 0이다.

**파티 구성을 별도 var로 빼는 이유**: `unlocked_cards` 주석(`game_state.gd:72-74`)이
"개수가 아니라 목록이라 flags에 담기 어색하다"는 판단을 이미 내려 두었다. 같은 성격이다.
게다가 **순서가 의미를 갖는다**(파티 슬롯 = 스프라이트 배치 순서).

**리크루트 플래그와 `active_companions`를 왜 둘 다 두는가**: 둘은 다른 질문에 답한다 —
"영입했는가"(되돌릴 수 없는 스토리 사실)와 "지금 파티에 있는가"(일시적으로 빠질 수 있음).
지금은 항상 같은 값이겠지만, 스토리상 동료가 잠시 이탈하는 장면 하나만 생겨도 갈라진다.
합치면 그때 세이브 마이그레이션이 필요해진다.

**API 초안** (기존 `restore_affinity` / `unlocked_cards` 계열과 같은 모양):

```
recruit_companion(id)          # 플래그 세움 + active_companions에 추가 + 시그널
is_companion_recruited(id) -> bool
get_active_companions() -> Array
restore_companions(list, hp_dict)
reset_companions()             # reset_progress()에서 호출
```

---

## 5. 세이브/로드 + 하위호환

### 추가할 것

`save_manager.gd`의 페이로드(`:32-50`)에 2줄:

```
"active_companions": GameState.active_companions,
"companion_hp": GameState.companion_hp,        # Q1이 "영속"일 때만
```

`load_game()`(`:70-82`)에 1줄:

```
GameState.restore_companions(
    data.get("active_companions", []),
    data.get("companion_hp", {}))
```

### 하위호환 — 추가 작업 없음

- **리크루트 플래그**: `restore_flags()`가 기본값 리셋 후 덮어쓰기라, 구버전 세이브에 키가 없으면
  자동으로 `false` = 미영입. 정확히 원하는 동작이다.
- **`active_companions`**: 없으면 `[]` = 동료 없음. 동료 시스템 이전 세이브의 의미와 정확히 일치한다.
- → `unlocked_cards`/`battle_deck`과 **같은 패턴이고, 마이그레이션 코드가 필요 없다.**

### 주의: 복원 순서와 검증

`battle_deck`이 `unlocked_cards`보다 뒤에 복원돼야 하는 것(`save_manager.gd:79-81`)과 같은 제약이 생긴다:

1. `companion_hp`는 `active_companions`를 확정한 **뒤에** 채우고, 파티에 없는 id는 버린다.
2. HP는 `CompanionData`의 `max_hp`로 **clamp**한다 — 카탈로그 수치를 나중에 하향 조정하면
   구세이브의 HP가 새 최대치를 넘을 수 있다(`restore_flags`가 `refresh_equipment_bonuses()`로
   같은 종류의 어긋남을 바로잡는 것과 같은 이유, `game_state.gd:305-306`).
3. `reset_progress()`(`game_state.gd:245`)에 `reset_companions()` 추가 — `battle_deck.clear()` 옆자리.
   리크루트 플래그는 `DEFAULT_FLAGS`에 있으니 기존 루프가 이미 처리한다.

### 슬롯 미리보기

`get_save_summary()`는 지금 `objective_text`/`progress`/`player_hp`/`player_max_hp`만 쓴다.
동료를 미리보기에 노출할지는 순수 UI 결정이고 Phase 1 필수가 아니다. **하지 않는 것을 권고** —
필요해지면 그때 페이로드에 키만 추가하면 되고, 그것도 하위호환이 공짜다.

---

## 6. 결정 필요 목록

구현 착수 전에 답이 필요한 것들. **Q1~Q4가 Phase 1 구조를 직접 결정**하고, 나머지는 Phase 3/4에서
필요하지만 지금 답해 두면 설계가 흔들리지 않는다.

### Phase 1을 막는 것 (반드시 먼저)

**Q1. 동료 HP는 전투 사이에 유지되는가, 매 전투 최대치로 리셋되는가?**
→ `CompanionState`가 전투 한정 객체인지 영속 객체인지, 세이브에 `companion_hp`가 필요한지가 여기서 갈린다. (§2 마지막 표)

**Q2. 플레이어 쪽 리팩터링은 A/B/C 중 무엇으로 가는가?** (권고: **C안 — 어댑터**)
→ Phase 1의 산출물 목록이 바뀐다. (§3)

**Q3. (Q1이 "영속"이면) 동료 HP는 무엇으로 회복하는가?**
지금 스펙대로면 회복 경로가 **하나도 없다**: 부활 없음, 플레이어 카드는 적만 타겟,
캠프파이어/포션은 `heal_player_*` 즉 플레이어 전용. 그대로 두면 동료는 단조 감소해 영구 전멸한다.
후보: (a) 전투 승리 시 플레이어처럼 25% 회복(`VICTORY_HEAL_FRACTION`), (b) 캠프파이어가 파티 전체 회복,
(c) 전투마다 리셋(= Q1을 "전투 한정"으로), (d) 동료 전용 회복 아이템.

**Q4. 타겟 인덱스 공간을 어떻게 확장하는가?**
현재 `status_applied(target_index)`는 `-1 = 플레이어`, `0..n = 몬스터`다(§1-2).
후보: (a) 동료를 `-2, -3, -4`로 — 기존 시그널 소비자 무손상, 대신 의미가 불투명해짐,
(b) 아군 전용 시그널을 따로 신설 — `enemy_attack_resolved`가 이미 적 전용인 것과 같은 결,
(c) `(진영, 인덱스)` 쌍이나 문자열 키로 전면 교체 — 가장 깨끗하지만 `battle_scene.gd` 소비자 전부를 건드림.
→ 권고: **(b) 기본 + 필요한 경우에만 (a)**.

### Phase 3/4에 필요 (지금 답해두면 좋음)

**Q5. 적 AI는 플레이어와 동료 중 누구를 때리는가?** (완전 랜덤 / 가중치 / 플레이어 우선)
→ `docs/companion_system_options.md`의 "아직 안 정해진 것"에도 미해결로 남아 있는 항목.

**Q6. 플레이어가 다운된 뒤 동료가 승리하면 보상 처리는?**
XP/골드는 그대로 주는가, 승리 회복(`VICTORY_HEAL_FRACTION`, `battle_scene.gd:2552`)은 다운된 플레이어에게도 적용되는가.
적용 안 하면 HP 0인 채로 전투가 끝나 다음 전투가 즉시 다운으로 시작한다 — 처리가 필요하다.

**Q7. 동료 액티브 발동 키는 무엇인가?** 동료가 여럿이면 키도 여럿인가, 아니면 대상 선택 UI를 거치는가.
→ Phase 5(4인 파티)에서 키가 모자라지 않을 설계인지 지금 확인해 두는 게 싸다.

**Q8. 동료도 "쉬는 턴"이 있는가?** (몬스터 마나 리듬 같은 것) — 없으면 매 턴 확정 공격이다.

**Q9. 유서프 수치**: max_hp, 평타 damage_min/max, 패시브 회복량, 액티브 쿨다운/경감률.
→ Phase 1에서는 키 구조만 잡고 플레이스홀더로 두는 것을 권고.

### 기존 문서에서 아직 미해결로 남아 있는 것

**Q10. 동료의 강함을 플레이어가 성장시키는가?** (레벨/장비/전용 카드)
→ `companion_system_options.md` §5 질문 3, 여전히 미답변. "예"면 `CompanionState`에 성장 필드와
세이브 키가 더 붙고, 전용 UI가 Phase 5 이후로 추가된다. **"아니오"를 권고** — Part 2 실질 파티가
2인인데 성장 UI를 만들면 투자 대비 회수가 안 된다.

**Q11. 유서프의 "신뢰도"를 기존 호감도로 쓰는가, 별도 축으로 빼는가?**
→ §5 질문 4, 여전히 미답변. **기존 `GameState.affinity["yusuf"]` 재사용을 권고** —
값(30 시작)도 초상화도 대사 게이팅 어휘(`required_affinity`, `text_by_affinity_tier`)도 이미 다 있다.

---

## 7. Phase 1 산출물 (Q1~Q4 확정 후)

권고안(Q2=C안) 기준으로 실제로 만들어질 것:

| 파일 | 성격 | 비고 |
|---|---|---|
| `battle/companion_state.gd` | 신규 | §2 스펙 |
| `battle/player_combatant.gd` | 신규 | GameState 위임 어댑터 |
| `battle/companion_data.gd` | 신규 | 카탈로그(수치는 플레이스홀더) |
| `systems/game_state.gd` | 수정 | 플래그 1개 + var 2개 + API 5개 + `reset_progress` 1줄 |
| `systems/save_manager.gd` | 수정 | 페이로드 2줄 + 복원 1줄 |
| `battle/battle_turn_manager.gd` | 수정 | `party` 배열 도입까지만 — 피격 대상 일반화는 Phase 3 |

`battle_scene.gd`(3,653줄)는 **Phase 1에서 건드리지 않는다.** 연출/HUD 다개체화는 Phase 3 범위이고,
`_player_sprite` 64개 참조를 Phase 1에 끌어들이면 "골격"이 아니라 전면 개편이 된다.

---

## 8. 결정 확정 (2026-09-06, 사용자 승인)

**Q1 — 동료 HP 지속성**: 영속(플레이어와 동일). 매 전투 리셋 아님.

**Q2 — 플레이어 리팩터링**: C안(어댑터, `PlayerCombatant`) 채택. 권고안 그대로.

**Q3 — 동료 HP 회복 수단**: 모닥불에서 플레이어와 함께 전원 최대치 회복(§6 후보 (b)).
`campfire.gd:128`의 전체 회복 호출을 동료까지 포함하도록 확장 — Phase 4 범위(캠프파이어는
전투 밖 로직이라 전투 통합과 분리해도 무방, 다만 유서프 능력 구현과 같은 타이밍에 처리 권장).

**Q4 — 타겟 인덱스 공간 확장**: 권고안 (b) 채택 — 아군 전용 시그널 신설, `-1/-2/-3` 같은
인덱스 오버로드는 필요해질 때만 보조적으로.

**Q10 — 동료 성장 시스템**: 권고안 "아니오" 채택. Phase 1 산출물에 성장 필드 없음.

**Q11 — 유서프 신뢰도**: 권고안대로 기존 `GameState.affinity["yusuf"]` 재사용.

**추가 결정 — 힐/셀프버프 카드의 아군 타겟 확장 (스코프 추가, Phase 3 배정)**:
사용자가 Q1 답변과 함께 새로 요청한 사항. 기존 힐 카드/셀프 버프 카드는 동료도 타겟으로 선택할 수
있게 UI를 넓힌다. **동료를 플레이어가 "조작"하게 되는 건 아니다** — 동료의 공격/패시브/액티브는
여전히 자동이고, 바뀌는 건 플레이어 카드의 타겟 범위뿐이다. 공격 카드는 계속 적 전용.
`CompanionState.heal()`이 이미 이 요구를 수용할 수 있어 **Phase 1 설계는 변경 없음**. 실제 타겟
선택 UI는 `battle_scene.gd:1202` `_targets_an_enemy()` 개편이 필요해 Phase 3에서 처리한다
(§3 판단에서 "플레이어 카드는 여전히 적만 타겟"이라 3분류 확장이 불필요하다고 했던 서술은
힐/버프 카드류에 한해 이번 결정으로 부분 번복됨 — 공격 카드에는 적용되지 않음).

→ Phase 1 구현 착수 가능. 위 결정을 바탕으로 §7 산출물 목록 그대로 진행.
