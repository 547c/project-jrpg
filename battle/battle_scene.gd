class_name BattleScene
extends Node2D

const UiTranslator := preload("res://systems/ui_translator.gd")

# 몬스터 조우 시 SceneManager가 전환해 들어오는 전용 전투 씬 (포켓몬 스타일 구도).
# 왼쪽 아래 = 플레이어(뒷모습), 오른쪽 위 = 몬스터.
#
# [역할 분담] 전투 규칙은 전부 BattleTurnManager가 갖고 있고, 이 씬은 "보여주기 + 입력 받기"만 한다:
# - 매니저: 손패/덱, 카드 효과, 마나 소모, 무기 과열 게이지, 적 저항, 몬스터 HP, 적 반격, 승패 판정
# - 이 씬: 스프라이트/애니메이션/팝업/HP바, 버튼 입력, 그리고 매니저가 다루지 않는
#          전투 "바깥" 처리(승리 보상 골드·처치 카운트, 도망가기, 게임오버 화면 전환)
# 규칙 계산을 여기서 중복하지 않도록 주의할 것 — 예를 들어 적 반격 피해는 매니저가 이미
# GameState.damage_player()로 적용하므로, 여기서는 그 결과를 애니메이션으로 보여주기만 한다.
#
# HUD/일시정지 억제를 위해 "battle_box" 그룹에 등록한다.

const PLAYER_SPRITE_PATH := "res://assets/graphics/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Idle_Base/Idle_Up-Sheet.png"
const PLAYER_FRAME_SIZE := 64
const FRAME_COUNT := 4
const IDLE_FPS := 4.0

const MONSTER_IDLE_FPS := 4.0
const MONSTER_DEATH_FPS := 8.0

# 카드 초상화용 얼굴 크롭 (Idle_Down-Sheet.png 기준 — 전투 중 실제로 보여주는 Idle_Up과는 다른 시트지만
# HUD 카드와 동일한 얼굴 그래픽을 쓰기 위해 정면 얼굴이 나온 Idle_Down에서 잘라온다)
const PLAYER_PORTRAIT_SHEET_PATH := "res://assets/graphics/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/Idle_Base/Idle_Down-Sheet.png"
const PLAYER_PORTRAIT_REGION := Rect2(23, 16, 18, 17)

# 플레이어를 몬스터보다 크게 그려 "카메라에 더 가까이 있다"는 원근을 만든다.
# PLAYER_FOOT_FROM_CENTER는 시트를 실제로 측정한 값이다 — Idle_Up 프레임(64px)에서 캐릭터의
# 발끝은 y=47 근처이고 프레임 중심은 y=32라, 스프라이트 원점에서 발까지가 약 15.5px이다.
# (이 값을 쓰지 않고 "프레임 높이의 절반"으로 잡으면 캐릭터가 프레임 안에서 위쪽에 그려져 있는
#  만큼 그림자가 발보다 한참 아래에 깔려 캐릭터가 공중에 뜬 것처럼 보인다 — 실제로 그랬다)
const PLAYER_SCALE := 3.4
const PLAYER_FOOT_FROM_CENTER := 15.5
const PLAYER_BODY_WIDTH := 16.0 # 시트에서 잰 캐릭터 실제 폭 (그림자 크기를 여기에 맞춘다)
const MONSTER_SCALE := 3.2

const HP_TWEEN_DURATION := 0.4
const DAMAGE_POPUP_RISE := 34.0
const DAMAGE_POPUP_DURATION := 0.85
const DAMAGE_POPUP_FONT_SIZE := 30
const DAMAGE_COLOR := Color(0.95, 0.2, 0.15, 1)
const HEAL_COLOR := Color(0.25, 0.85, 0.35, 1)
const DODGE_COLOR := Color(0.5, 0.85, 1.0, 1)
const MANA_COLOR := Color(0.45, 0.65, 1.0, 1)
const GUARD_COLOR := Color(0.8, 0.8, 0.55, 1)
const HIT_TINT := Color(1.0, 0.35, 0.35, 1)
const HIT_TINT_DURATION := 0.12
const SHAKE_AMOUNT := 7.0
const SHAKE_STEP_DURATION := 0.05
const SHAKE_STEPS := 3
const LUNGE_DISTANCE := 26.0
const LUNGE_OUT_DURATION := 0.08
const LUNGE_BACK_DURATION := 0.12
const VICTORY_HEAL_FRACTION := 0.25
const FLEE_HP_THRESHOLD := 0.5 # 최대 HP의 이 비율 이상일 때만 도망 가능
const FLEE_GOLD_PENALTY_MIN := 1 # 도망 성공 시 소모할 골드 범위 (무한 도망-재시작 리롤 방지)
const FLEE_GOLD_PENALTY_MAX := 10

# 몬스터 처치 시 장비가 떨어질 확률 (나머지 85%는 꽝 — 골드만 받는다).
# 몬스터는 일정 시간 뒤 리젠되어 반복해서 잡을 수 있으므로, 상자(50%)보다 훨씬 낮게 잡았다.
# 한 등급에 장비가 3종뿐이고 장비는 소모되지 않아 한 번씩만 모으면 되므로, 15%면 대략 일곱 번에
# 한 번 떨어져 한 등급을 다 모으는 데 스무 번 남짓 — 파밍이 의미는 있되 끝없이 늘어지지 않는 수준
const EQUIPMENT_DROP_CHANCE := 0.15

# ── 카드 발동 이펙트 (assets/vfx/Free — 불꽃/스파크 계열, 64x64 칸, 9색 행 공통 팔레트) ──
# 시트 전체가 같은 팔레트를 공유한다: 행0=빨강 1=보라 2=하늘색 3=초록 4=주황 5=회백 6=적갈 7=진홍 8=암보라.
# 카드 프레임 색 체계(_card_style_key: 빨강=물리/파랑=마법/초록=회복·마나/회색=방어·회피)와 맞춰 골랐고,
# 회복과 마나는 카드 프레임은 같은 초록이라도 실제 타격 이펙트는 모양과 색을 다르게 해 구분되게 했다.
# (조사 결과: 15개 Part 폴더 전체가 이 팔레트/그리드를 공유해서, 새 이펙트가 필요해지면 같은 방식으로
#  아무 Part에서나 골라 추가하면 된다)
const VFX_FRAME_SIZE := 64
const VFX_DISPLAY_SCALE := 2.6
const VFX_ROW_RED := 0
const VFX_ROW_VIOLET := 1
const VFX_ROW_SKY := 2
const VFX_ROW_GREEN := 3
const VFX_ROW_ORANGE := 4
const VFX_ROW_GREY := 5
const VFX_ROW_CRIMSON := 7

# key -> {path, row, frames, fps}. fps*프레임=재생 시간: 물리(0.3s, 툭 치는 느낌)/마법·회복·마나·방어
# (~0.45~0.5s, 화려하게 펼쳐짐)/회피(0.2s, 스치듯 빠르게)로 카드 성격에 맞춰 길이를 다르게 뒀다
const VFX_CONFIG := {
	# 회전하는 표창 모양이 커지며 터진다 — 무기가 스치고 지나간 자국처럼 보여 물리 공격에 맞다
	"physical": {"path": "res://assets/vfx/Free/Part 6/283.png", "row": VFX_ROW_CRIMSON, "frames": 9, "fps": 30.0},
	# 방사형으로 뻗어나가는 별 모양 — 마법탄이 적중해 터지는 느낌
	"magic": {"path": "res://assets/vfx/Free/Part 14/652.png", "row": VFX_ROW_VIOLET, "frames": 16, "fps": 34.0},
	# 잔잔히 커지는 고리 — "부드러운 빛"에 해당하는, 이 팩에서 가장 폭발적이지 않은 모양
	"heal": {"path": "res://assets/vfx/Free/Part 10/475.png", "row": VFX_ROW_GREEN, "frames": 12, "fps": 26.0},
	# 소용돌이치는 문(포탈) 모양 — 마나를 끌어오는 느낌을 내려고 회복과는 다른 모양을 골랐다
	"mana": {"path": "res://assets/vfx/Free/Part 1/03.png", "row": VFX_ROW_SKY, "frames": 13, "fps": 26.0},
	# 회복과 같은 고리 텍스처를 회색으로만 바꿔 재사용 — 방어는 "빛"이 아니라 "막"이 둘러지는
	# 느낌이라 강철색이 더 어울리고, 모양을 공유해도 색이 다르면 헷갈리지 않는다
	"defend": {"path": "res://assets/vfx/Free/Part 10/475.png", "row": VFX_ROW_GREY, "frames": 12, "fps": 26.0},
	# 짧은 대각선 스트릭 — 실제 이동이 아니라 "잔상"으로 회피를 표현
	"dodge": {"path": "res://assets/vfx/Free/Part 8/377.png", "row": VFX_ROW_GREY, "frames": 8, "fps": 40.0},
	# 대각선으로 그어지는 검기 자국 — "physical"(표창 폭발)과 달리 순간적으로 스쳐 지나가는 궤적이라
	# 섬광의 "번쩍이고 빠르게 베어낸다"는 컨셉에 맞다. 주황 행이 이 시트에서 가장 노란빛에 가깝다
	"physical_flash": {"path": "res://assets/vfx/Free/Part 5/222.png", "row": VFX_ROW_ORANGE, "frames": 9, "fps": 45.0},
	# 크게 부풀었다 흩어지는 뭉게구름 폭발 — "magic"(별 모양 폭발)보다 훨씬 크고 화염 덩어리처럼
	# 뭉실하게 터져서 파이어볼의 "불꽃 덩어리를 던진다"는 묘사에 어울린다
	"magic_fire": {"path": "res://assets/vfx/Free/Part 10/484.png", "row": VFX_ROW_RED, "frames": 12, "fps": 28.0},
	# X자로 부딪혀 번쩍이는 충돌 자국 — "defend"(부드러운 고리)와 달리 무기와 무기가 맞부딪히는
	# 순간을 표현해, 그냥 막기(Guard)와는 다른 "받아넘긴다"는 느낌을 낸다
	"counter": {"path": "res://assets/vfx/Free/Part 5/232.png", "row": VFX_ROW_GREY, "frames": 9, "fps": 32.0},
	# 안쪽으로 말려 들어가는 나선 — 바깥에서 안으로 감기며 한 점에 모이는 모양이라 "마력을 응축한다"는
	# 차징에 맞다 (실제로 시트를 훑어 프레임별 반지름을 재보니 이 시트가 가장 확실하게 수렴한다)
	"charge_fire": {"path": "res://assets/vfx/Free/Part 3/123.png", "row": VFX_ROW_ORANGE, "frames": 12, "fps": 65.0},
	# 네 조각이 사방에서 날아와 가운데서 마름모로 합쳐지는 모양 — 나선(charge_fire)보다 훨씬 크고
	# 무겁게 "끌어모으는" 인상이라 익스플로전의 2단 차징에 쓴다. 1단계는 보라, 2단계는 같은 시트의
	# 빨강 행을 더 크게 띄워서 "색이 달아오르며 더 강해진다"는 단계감을 낸다
	"charge_heavy_1": {"path": "res://assets/vfx/Free/Part 15/700.png", "row": VFX_ROW_VIOLET, "frames": 22, "fps": 70.0},
	"charge_heavy_2": {"path": "res://assets/vfx/Free/Part 15/700.png", "row": VFX_ROW_RED, "frames": 22, "fps": 60.0},
	# 크게 부풀었다 파편으로 산산이 흩어지는 폭발 — magic_fire(뭉게구름)와 달리 조각이 사방으로
	# 튀어나가 "훨씬 큰 한 방"으로 읽힌다. fps를 낮춰(24) 재생 시간을 늘려 묵직하게 터지게 했고,
	# 재생할 때 스케일도 따로 키워 띄운다(EXPLOSION_VFX_SCALE_MULT)
	"explosion_big": {"path": "res://assets/vfx/Free/Part 2/71.png", "row": VFX_ROW_RED, "frames": 10, "fps": 24.0},
	# "magic"(마력탄)과 완전히 같은 별 모양 폭발 시트를 행만 하늘색(VFX_ROW_SKY)으로 바꿔 재사용한다 —
	# 이 팩은 15개 Part 폴더 전체가 같은 9색 팔레트를 공유해서, 모양은 그대로 두고 행만 바꾸면 색만
	# 갈아입는다. 얼음화살이 "차가운 냉기"라 보라색 마력탄과는 다른 시안 계열로 확실히 구분된다
	"magic_ice": {"path": "res://assets/vfx/Free/Part 14/652.png", "row": VFX_ROW_SKY, "frames": 16, "fps": 34.0},
	# "physical"(표창 폭발)과 완전히 같은 시트/색 — 회전베기는 모양이 아니라 "같은 타격을 두 번
	# 잇따라 재생한다"는 연출로 차별화하므로, 새 그림 대신 기존 물리 이펙트를 그대로 재사용한다.
	# SFX만 다른 키(physical_spin)로 따로 둬서 물리 공격 중에서도 소리로 구분되게 했다
	"physical_spin": {"path": "res://assets/vfx/Free/Part 6/283.png", "row": VFX_ROW_CRIMSON, "frames": 9, "fps": 30.0},
	# 뾰족하게 솟았다가 파편으로 갈라지는 날카로운 쐐기 모양 — 이 팩에서 가장 "직선적으로 내리꽂는"
	# 느낌이 나는 시트라 번개창의 "번개를 창처럼 내리꽂는다"는 묘사에 맞다. 회백(흰색) 행을 써서
	# 노랗게 차징하는 섬광과는 톤을 다르게 하면서도 "밝고 강렬한 빛"이라는 인상은 유지한다
	"magic_lightning": {"path": "res://assets/vfx/Free/Part 11/507.png", "row": VFX_ROW_GREY, "frames": 12, "fps": 40.0},
	# X자로 갈라지는 뾰족한 균열이 생겼다가 파편으로 부서지는 6프레임 —
	# 시공균열은 이 애니메이션을 중간(균열이 완성된 프레임)에서 pause()로 얼려뒀다가 한꺼번에
	# 마저 재생해 "얼어붙었다 부서진다"를 만든다. 그래서 fps를 낮게(18) 잡아 얼기 전 형성 과정이
	# 눈에 들어오게 했다. 색은 시간/한기 느낌의 하늘색
	"time_crack": {"path": "res://assets/vfx/Free/Part 7/323.png", "row": VFX_ROW_SKY, "frames": 6, "fps": 18.0},
	# 세로로 곧게 뻗은 빛줄기가 내리꽂혀 바닥에서 터지는 모양 — 시트 전체를 프레임별 세로/가로 비율로
	# 훑어 가장 세로로 긴 형태(비율 11.2)를 찾아 골랐다. 실제로는 여기에 stretch로 세로를 더 늘려
	# 화면을 관통하는 기둥처럼 보이게 한다.
	# 색은 회백(신성한 흰빛)에서 0번 행으로 바꿨다 — 이 행은 줄기 중심이 노랗고 가장자리만 붉어
	# "낙뢰"에 가장 가깝다 (4번 주황 행은 전체가 탁한 주황이라 번개 느낌이 덜했다)
	"light_pillar": {"path": "res://assets/vfx/Free/Part 15/701.png", "row": VFX_ROW_RED, "frames": 14, "fps": 30.0},
	# ── 몬스터 공격 이펙트 (종류별로 하나씩) ────────────────────────────────
	# 카드처럼 정교하게 고르진 않았고, 아직 아무 카드도 안 쓰는 시트 중에서 각 몬스터의 인상에
	# 맞는 모양을 하나씩 골랐다. 색 행은 그 몬스터의 톤에 맞춰 고른다.
	# 휘어진 초승달이 발톱 자국처럼 갈라지는 모양 — 오크의 우악스러운 근접 공격
	"enemy_orc": {"path": "res://assets/vfx/Free/Part 1/06.png", "row": VFX_ROW_CRIMSON, "frames": 15, "fps": 30.0},
	# 사방으로 뻗어나가는 뾰족한 균열 — 스켈레톤의 마르고 날카로운 인상. 뼈 색(회백)을 쓴다
	"enemy_skeleton": {"path": "res://assets/vfx/Free/Part 4/195.png", "row": VFX_ROW_GREY, "frames": 14, "fps": 32.0},
	# 갈고리처럼 감겼다 풀리는 곡선 다발 — 미라의 붕대가 휘감기는 느낌. 사막 톤의 주황을 쓴다
	"enemy_mummy": {"path": "res://assets/vfx/Free/Part 6/295.png", "row": VFX_ROW_ORANGE, "frames": 9, "fps": 26.0},
}

# 몬스터 종류별 공격 이펙트. 표에 없는 종류는 오크 것을 쓴다(_enemy_attack_vfx_key).
# 유적 보스는 스프라이트를 미라에서 빌려 쓰므로 이펙트도 미라 것을 그대로 물려받는다
const MONSTER_ATTACK_VFX := {
	"ORC": "enemy_orc",
	"SKELETON": "enemy_skeleton",
	"MUMMY": "enemy_mummy",
	"RUINS_BOSS": "enemy_mummy",
}

# key -> 400 Sounds pack 경로. 물리/방어는 Weapons(금속·타격), 마법/마나는 복고풍 신스(폭발감/충전감),
# 회복은 Musical Effects의 은은한 비브라폰 차임, 회피는 Other의 휙 스치는 소리
const VFX_SFX := {
	"physical": "res://assets/sfx/400 Sounds pack/Weapons/sword_slice.wav",
	"magic": "res://assets/sfx/400 Sounds pack/Retro/explosion_quick.wav",
	"heal": "res://assets/sfx/400 Sounds pack/Musical Effects/vibraphone_chime_positive.wav",
	"mana": "res://assets/sfx/400 Sounds pack/Retro/power_up.wav",
	"defend": "res://assets/sfx/400 Sounds pack/Weapons/sword_clash.wav",
	"dodge": "res://assets/sfx/400 Sounds pack/Other/whoosh_2.wav",
	# sword_slice보다 더 가볍고 짧은 타격음 — 섬광의 "번쩍하고 스치는" 속도감에 맞춘다
	"physical_flash": "res://assets/sfx/400 Sounds pack/Weapons/sword_light.wav",
	# 마법 공격 3종을 폭발음 크기 순으로 줄세운다: 마력탄=quick < 파이어볼=medium < 익스플로전=large.
	# (파이어볼이 원래 large를 쓰고 있었는데, 익스플로전이 "훨씬 큰 한 방"이 되려면 가장 큰 소리를
	#  익스플로전에 양보해야 세 카드의 무게 차이가 소리만 듣고도 구분된다)
	"magic_fire": "res://assets/sfx/400 Sounds pack/Retro/explosion_medium.wav",
	"explosion_big": "res://assets/sfx/400 Sounds pack/Retro/explosion_large.wav",
	# sword_clash와 같은 계열이지만 다른 샘플(_2) — 방어(Guard)와 소리가 겹치지 않으면서도
	# "금속이 부딪힌다"는 같은 계열감은 유지한다
	"counter": "res://assets/sfx/400 Sounds pack/Weapons/sword_clash_2.wav",
	# 오르골 특유의 여리고 영롱한 음색 — "신비롭게 두 자원이 차오른다"는 인상에 맞고, 다른 카드가
	# 아직 안 쓴 악기라 회복(비브라폰)/마나(파워업)와도 확실히 구분된다
	"restore_both": "res://assets/sfx/400 Sounds pack/Musical Effects/music_box_chime_positive.wav",
	# 색만 바꾼 VFX라 소리까지 새로 고를 필요는 없다는 판단 — 마력탄과 같은 타격음을 그대로 쓴다
	"magic_ice": "res://assets/sfx/400 Sounds pack/Retro/explosion_quick.wav",
	# sword_slice/sword_light은 이미 다른 카드(베기/섬광)가 쓰고 있어 제외하고, 칼을 뽑는 듯한
	# 날카로운 스윽 소리로 "회전하며 두 번 벤다"의 첫/두 번째 타격 모두에 쓴다
	"physical_spin": "res://assets/sfx/400 Sounds pack/Weapons/sword_unsheath.wav",
	# 번개 전용 사운드가 팩에 없어 마법 계열 타격음을 그대로 재사용 — 대신 화면 히트 플래시로
	# "전기가 튀는" 느낌을 시각적으로 보강한다
	"magic_lightning": "res://assets/sfx/400 Sounds pack/Retro/explosion_quick.wav",
	# 몬스터 공격음: 카드(검/마법)와 계열을 다르게 해 "적이 때렸다"가 소리만으로 구분되게 한다 —
	# 플레이어 카드는 전부 무기/폭발 계열이라, 몬스터는 타격/뼈 계열(Combat and Gore)에서 골랐다
	"enemy_orc": "res://assets/sfx/400 Sounds pack/Combat and Gore/punch_2.wav",
	"enemy_skeleton": "res://assets/sfx/400 Sounds pack/Combat and Gore/bone_snap.wav",
	"enemy_mummy": "res://assets/sfx/400 Sounds pack/Combat and Gore/crunch_quick.wav",
}

# 카드 이름 -> VFX 키 강제 지정. DAMAGE처럼 같은 효과·색을 공유하는 카드들도 이 표에 있으면
# _vfx_key_for_card()가 효과 기반 기본값(physical/magic) 대신 이 값을 쓴다 — 이름에 매달아 두는 건
# Card에 별도 id 필드가 없어서다. 카드 이름을 바꿀 계획이 생기면 이 표도 같이 고쳐야 한다
const CARD_NAME_VFX_OVERRIDE := {
	"섬광": "physical_flash",
	"파이어볼": "magic_fire",
	"익스플로전": "explosion_big",
	"얼음화살": "magic_ice",
	"회전베기": "physical_spin",
	"번개창": "magic_lightning",
}

# 도박의 일격 전용 연출 수치. 성공은 이 덱에서 가장 큰 단발 한 방(30)이라 흔들림/이펙트를 과장하고,
# 실패는 같은 이펙트를 작고 흐리게 띄워 "나가긴 했는데 헛쳤다"로 읽히게 한다 (아무것도 안 나오면
# 카드가 씹힌 것처럼 보인다)
const GAMBLE_HIT_VFX_SCALE := 1.6
const GAMBLE_HIT_SHAKE_AMOUNT := 9.0
const GAMBLE_HIT_SHAKE_STEPS := 8
const GAMBLE_HIT_FLASH_TINT := Color(1.0, 0.85, 0.45, 1)
const GAMBLE_WHIFF_VFX_SCALE := 0.55
const GAMBLE_WHIFF_VFX_ALPHA := 0.45

# 번개창 전용: 화면 전체가 짧게 번쩍이는 히트 플래시 색 (섬광의 HitFlash 로직을 그대로 재사용하고
# 색과 재생 시점만 다르게 준다)
const LIGHTNING_FLASH_TINT := Color(1.0, 0.98, 0.72, 1)

# ── 원거리 마법 차징 연출 (파이어볼 / 익스플로전) ────────────────────────────
# 섬광의 "차징 → 돌진" 구조를 그대로 빌려오되, 원거리 마법이라 캐릭터는 제자리에 선 채
# 앞쪽 허공에 마력이 모였다가 날아가는 형태로 바꿨다.
#
# 차징 이펙트가 뜨는 위치: 플레이어 발밑이 아니라 "몬스터를 향한 앞쪽 허공"이라야 손에서
# 모으는 것처럼 보이므로, 몬스터 방향으로 이만큼 띄운 지점에 띄운다
const CAST_CHARGE_FORWARD := 56.0
const CAST_CHARGE_RISE := 26.0 # 살짝 위(가슴~손 높이)로도 올린다 — 낮으면 큰 차징이 캐릭터를 덮는다

# 파이어볼: 짧게 한 번 응축하고 곧바로 터진다
const FIREBALL_CHARGE_DURATION := 0.18
const FIREBALL_CHARGE_SCALE := 1.1
const FIREBALL_CHARGE_SFX := "res://assets/sfx/400 Sounds pack/Retro/power_up_2.wav"

# 익스플로전: 낮은 톤으로 한 번(1단계), 더 크고 높은 톤으로 한 번 더(2단계) 모았다가 발사한다.
# 같은 차징 사운드를 pitch_scale만 올려 두 번 울리면 "삥- 삥-" 하고 음이 올라가는 긴박감이 난다
# (SFXPlayer.play가 pitch_scale 인자를 이미 받고, 풀 방식이라 겹쳐 울려도 서로 안 끊긴다)
# (스케일은 화면에 실제로 띄워보고 맞춘 값이다 — 1.3/2.0으로 잡았더니 2단계 차징이 화면 위와
#  아래 카드 영역까지 삐져나갔다. 1.0→1.5면 "확실히 커졌다"는 단계감은 그대로면서 전장 안에 담긴다)
const EXPLOSION_CHARGE1_DURATION := 0.3
const EXPLOSION_CHARGE1_SCALE := 1.0
const EXPLOSION_CHARGE1_PITCH := 0.75
const EXPLOSION_CHARGE1_SFX := "res://assets/sfx/400 Sounds pack/Musical Effects/synth_bass_chime_quick.wav"
const EXPLOSION_CHARGE2_DURATION := 0.36
const EXPLOSION_CHARGE2_SCALE := 1.5
const EXPLOSION_CHARGE2_PITCH := 1.25
const EXPLOSION_CHARGE2_SFX := "res://assets/sfx/400 Sounds pack/Retro/grow_big.wav"
const EXPLOSION_TRAVEL_DURATION := 0.16 # 응축된 덩어리가 몬스터까지 날아가는 시간
const EXPLOSION_VFX_SCALE_MULT := 2.0   # 폭발 이펙트를 기본 배율보다 이만큼 더 키워 띄운다
const EXPLOSION_SHAKE_AMOUNT := 16.0    # 섬광/삼중나선(기본 7)보다 훨씬 세게 흔든다
const EXPLOSION_SHAKE_STEPS := 6
# 큰 폭발음에 저역 충격음을 겹쳐 몸통을 채운다 (한 파일로는 "쿵" 하는 저음이 부족했다)
const EXPLOSION_IMPACT_SFX := "res://assets/sfx/400 Sounds pack/Weapons/harsh_thud.wav"

# 섬광 전용: 베기 전에 노랗게 "차징"하는 짧은 깜빡임
const FLASH_SLASH_CHARGE_TINT := Color(1.0, 0.92, 0.35, 1)
const FLASH_SLASH_CHARGE_DURATION := 0.1

# 섬광 전용: 일반 _lunge()의 고정 26px 대신, 몬스터 코앞(부딪히지 않을 만큼만 띄운 지점)까지
# 실제로 달려갔다가 돌아온다. HIT_GAP은 두 스프라이트 테두리 사이에 남길 최소 간격
const FLASH_SLASH_DASH_DURATION := 0.16
const FLASH_SLASH_RETURN_DURATION := 0.15
const FLASH_SLASH_HIT_GAP := 12.0

# 섬광 전용: 돌진 궤적에 남기는 반투명 잔상 (스프라이트 복제본을 경로상에 몇 장 뿌리고 각각 페이드).
# 몬스터 코앞까지 달려가면서 실제 이동 거리가 카드마다(몬스터 위치마다) 달라지므로, 개수를 고정하지
# 않고 "대략 이 간격마다 한 장" 기준으로 거리에 비례해 늘어나게 한다 — 거리가 짧아도 최소 개수는
# 보장하고, 너무 많아지지 않게 상한도 둔다
const DASH_AFTERIMAGE_TARGET_SPACING := 45.0
const DASH_AFTERIMAGE_MIN_COUNT := 3
const DASH_AFTERIMAGE_MAX_COUNT := 7
const DASH_AFTERIMAGE_ALPHA := 0.6
const DASH_AFTERIMAGE_FADE_DURATION := 0.22
const DASH_AFTERIMAGE_STAGGER := 0.02

# 섬광 전용: 타격 순간 화면 전체가 짧게 번쩍이는 풀스크린 플래시
const HIT_FLASH_DURATION := 0.05

# ── 삼중나선 전용 3연타 컷신 ─────────────────────────────────────────────────
# 섬광의 돌진/잔상/화면플래시를 재사용하되, "번쩍하고 나면 이미 반대편에 가 있는" 순간이동으로
# 바꾼 버전. 색은 섬광(노랑)과 겹치지 않게 흰색에 가까운 청록으로, 이동은 트윈 없이 즉시 좌표만
# 바꿔 "시간이 멈춘 것 같은" 속도감을 낸다
const TRIPLE_HELIX_TINT := Color(0.85, 1.0, 1.0, 1)
const TRIPLE_HELIX_FLASH_IN_DURATION := 0.05  # 화면이 완전히 덮일 때까지
const TRIPLE_HELIX_FLASH_OUT_DURATION := 0.09 # 걷히면서 새 위치의 캐릭터가 드러남
const TRIPLE_HELIX_FLASH_ALPHA := 0.92        # 순간이동을 완전히 가릴 만큼 진하게 (섬광의 히트플래시 0.55보다 훨씬 진함)
const TRIPLE_HELIX_HIT_GAP := 12.0
const TRIPLE_HELIX_SET_GAP := 0.22 # 한 타격이 끝나고 다음 번쩍임이 시작되기 전까지 정지하는 시간
const TRIPLE_HELIX_RETURN_DURATION := 0.15
const TRIPLE_HELIX_HIT_SFX := [
	"res://assets/sfx/400 Sounds pack/Weapons/sword_slice.wav",
	"res://assets/sfx/400 Sounds pack/Weapons/sword_light.wav",
	"res://assets/sfx/400 Sounds pack/Combat and Gore/swipe.wav",
]

# ── 신속 전용 컷신 ("순간이동 → 정적 → 연속 폭발") ──────────────────────────
# 삼중나선의 "화면을 덮은 프레임에 좌표만 즉시 바꿔 순간이동을 가린다"는 트릭을 그대로 쓰되,
# 구조를 뒤집었다: 삼중나선은 [번쩍+이동+타격]을 3세트 반복하는데, 신속은 이동을 한 번만 하고
# (몬스터 등 뒤 고정) 거기서 "정적 → 연타 → 마무리 흔들림"으로 한 호흡에 몰아친다.
# 색도 삼중나선(청록)과 겹치지 않게 순은백색으로 구분한다
const SWIFT_TINT := Color(1.0, 1.0, 1.0, 1)
const SWIFT_FLASH_IN_DURATION := 0.06  # 화면이 완전히 덮일 때까지
const SWIFT_FLASH_OUT_DURATION := 0.10 # 걷히면서 등 뒤에 선 모습이 드러남
const SWIFT_FLASH_ALPHA := 0.94        # 순간이동을 완전히 가릴 만큼 진하게
const SWIFT_HIT_GAP := 12.0            # 몬스터 등 뒤에 설 때 남길 간격

# "베기 직전의 정적". 티어3 궁극기라 이 대목을 충분히 끌어 긴장을 쌓는다 —
# 화면을 살짝 눌러(어둡게) 시간이 멎은 듯한 인상을 주고, 그 상태로 잠시 멈춘다.
# 별도 비네트 셰이더 없이 기존 HitFlash(풀스크린 ColorRect)에 어두운 색을 넣어 재사용한다
const SWIFT_DIM_COLOR := Color(0.03, 0.03, 0.08, 1)
const SWIFT_DIM_ALPHA := 0.42
const SWIFT_DIM_IN_DURATION := 0.10
const SWIFT_PAUSE_HOLD := 0.42 # 정적을 버티는 시간 (짧으면 스치듯 지나가 긴장이 안 생긴다)

const SWIFT_HIT_COUNT := 5
const SWIFT_HIT_INTERVAL := 0.09 # 5회 x 0.09 = 약 0.45초의 연타
const SWIFT_HIT_SHAKE := 4.0     # 연타마다 작게 (기본 7보다 약하게)
const SWIFT_HIT_SHAKE_STEPS := 1
const SWIFT_FINAL_SHAKE := 18.0  # 마무리 한 방은 크게
const SWIFT_FINAL_SHAKE_STEPS := 5
const SWIFT_FINAL_HOLD := 0.35   # 마무리 흔들림을 보여주는 시간
const SWIFT_RETURN_DURATION := 0.18
# 연타 이펙트가 한 점에 겹쳐 뭉치지 않도록 몬스터 몸 주위로 조금씩 흩어 뿌린다
const SWIFT_HIT_OFFSETS := [
	Vector2(-16, -10), Vector2(14, 6), Vector2(-8, 14), Vector2(18, -14), Vector2(0, 0),
]
const SWIFT_HIT_SFX := [
	"res://assets/sfx/400 Sounds pack/Combat and Gore/swipe.wav",
	"res://assets/sfx/400 Sounds pack/Weapons/sword_light.wav",
]

# ── 유성낙하 전용 컷신 ("점프 → 화면 밖 → 정적 → 낙하 강타") ────────────────
# 섬광/삼중나선/신속이 쓰던 "화면 플래시로 위치 이동을 가린다"는 트릭은 그대로지만, 가로 이동이
# 아니라 세로다: 위로 튀어올라 화면 밖으로 사라진 뒤, 플래시가 덮인 사이 몬스터 머리 위 공중에
# 다시 나타나 그대로 내리꽂는다. 연타가 아니라 단발 강타라 데미지도 한 번에 표시한다
const METEOR_JUMP_DURATION := 0.15
const METEOR_JUMP_EXIT_Y := -80.0 # 화면(0~648) 위로 완전히 빠져나가는 y
const METEOR_HANG_DURATION := 0.3 # 사라진 뒤 "뭔가 떨어질 것 같은" 정적
const METEOR_TINT := Color(1, 1, 1, 1) # 순백 — 낙하 직전의 강한 섬광
const METEOR_FLASH_IN_DURATION := 0.06
const METEOR_FLASH_OUT_DURATION := 0.12
const METEOR_FLASH_ALPHA := 0.96
const METEOR_DROP_HEIGHT := 260.0 # 몬스터 위 이 높이에서 떨어진다
const METEOR_DROP_DURATION := 0.08 # 거의 순간적으로 내리꽂는다
# 지금까지 만든 것 중 가장 큰 흔들림 (기본 7 < 익스플로전 16 < 신속 마무리 18 < 여기 26)
const METEOR_IMPACT_SHAKE := 26.0
const METEOR_IMPACT_SHAKE_STEPS := 7
const METEOR_IMPACT_HOLD := 0.4 # 착지 여운
const METEOR_RETURN_DURATION := 0.2
const METEOR_VFX_SCALE := 2.2 # 착지 타격 이펙트를 크게 띄운다
const METEOR_JUMP_SFX := "res://assets/sfx/400 Sounds pack/Other/whoosh_1.wav" # 회피(whoosh_2)와 다른 샘플
# 낙하 충격은 저역 "쿵"(harsh_thud)에 중간 폭발음을 겹쳐 무게를 만든다
# (익스플로전이 harsh_thud + explosion_large라 그보다 한 단계 낮은 medium을 써서 서로 구분된다)
const METEOR_IMPACT_SFX := [
	"res://assets/sfx/400 Sounds pack/Weapons/harsh_thud.wav",
	"res://assets/sfx/400 Sounds pack/Retro/explosion_medium.wav",
]
# 낙하 지점 예고 마커: 몬스터 발밑에서 붉게 맥동하는 타원 ("여기로 떨어진다"는 예고).
# 그림자(Polygon2D 타원)를 만드는 기존 방식을 그대로 빌려 코드로 생성한다 — 전용 에셋이 필요 없다
const METEOR_MARKER_COLOR := Color(0.95, 0.25, 0.2, 0.5)
const METEOR_MARKER_RX := 46.0
const METEOR_MARKER_RY := 14.0
const METEOR_MARKER_PULSE := 0.3 # 한 번 커졌다 작아지는 데 걸리는 시간

# ── 시공균열 전용 컷신 ("시간 정지 → 일괄 해제") ────────────────────────────
# 지금까지의 컷신이 전부 "캐릭터를 어디로 옮기느냐"였다면 이건 화면 자체를 멈추는 연출이다.
# 캐릭터는 파이어볼/익스플로전처럼 제자리에 선 채, 몬스터 주위에 생긴 균열이 재생 도중 얼어붙고
# (AnimatedSprite2D.pause) 정적을 버틴 뒤 한꺼번에 풀려나며 터진다.
const TIME_RIFT_FREEZE_COLOR := Color(0.34, 0.42, 0.55, 1) # 차갑고 탁한 블루그레이
const TIME_RIFT_FREEZE_ALPHA := 0.4
const TIME_RIFT_FREEZE_IN_DURATION := 0.3 # 서서히 덮인다
const TIME_RIFT_HOLD := 0.55              # 얼어붙은 채 버티는 정적
# 균열이 "완성된" 프레임에서 멈춘다. 이 시트는 6프레임이고 2번 프레임이 X자가 가장 또렷한 지점이라
# 거기서 pause()를 건다 (0~1은 아직 생기는 중, 3부터는 부서지기 시작)
const TIME_RIFT_FREEZE_FRAME := 2
const TIME_RIFT_CRACK_SCALE := 1.6
# 몬스터 주위 세 곳에 균열을 흩어 놓는다 (한 점에 겹치면 그냥 큰 이펙트 하나로 보인다)
const TIME_RIFT_CRACK_OFFSETS := [Vector2(-34, -22), Vector2(30, 10), Vector2(-4, 30)]
# 해제 순간 밝은 시안으로 번쩍이며 걷힌다
const TIME_RIFT_RELEASE_TINT := Color(0.75, 1.0, 1.0, 1)
const TIME_RIFT_RELEASE_ALPHA := 0.9
const TIME_RIFT_RELEASE_IN_DURATION := 0.05
const TIME_RIFT_RELEASE_OUT_DURATION := 0.22
const TIME_RIFT_BURST_FPS := 46.0 # 얼렸던 균열을 풀 때는 훨씬 빠르게 돌려 "쨍그랑" 터지게 한다
const TIME_RIFT_SHAKE := 22.0
const TIME_RIFT_SHAKE_STEPS := 6
const TIME_RIFT_IMPACT_HOLD := 0.45
# 정적 구간에 까는 불안한 지속음. 피치를 낮춰 더 기괴하게 끌고, 해제 순간엔 유리 깨지는 소리를 얹는다
const TIME_RIFT_FREEZE_SFX := "res://assets/sfx/400 Sounds pack/Musical Effects/horror_sting.wav"
const TIME_RIFT_FREEZE_SFX_PITCH := 0.6
const TIME_RIFT_RELEASE_SFX := [
	"res://assets/sfx/400 Sounds pack/Materials/glass_ping_big.wav",
	"res://assets/sfx/400 Sounds pack/Retro/explosion_medium.wav",
]

# ── 천벌 전용 컷신 ("예고 마커 → 화이트아웃 → 빛기둥") ──────────────────────
# 유성낙하의 "예고 마커 → 화이트아웃 → 내리꽂기" 뼈대를 그대로 쓰되, 원거리 마법이라 캐릭터는
# 제자리에 선 채 하늘에서 빛기둥만 떨어진다. 마커도 붉은 낙하 표식이 아니라 금빛 심판의 원이다
const JUDGMENT_MARKER_COLOR := Color(1.0, 0.92, 0.45, 0.5) # 밝은 노란빛
const JUDGMENT_MARKER_RX := 52.0
const JUDGMENT_MARKER_RY := 17.0
const JUDGMENT_MARKER_PULSE := 0.11
# 진폭을 키워가며 맥동한다 — 6단계 x 0.11초 = 약 0.66초 동안 차오르는 느낌
const JUDGMENT_MARKER_GROW := [0.5, 0.85, 0.7, 1.15, 0.95, 1.5]
const JUDGMENT_CHARGE_DURATION := 0.5

# 화이트아웃은 지금까지 중 가장 강하다 (삼중나선 0.92 < 신속 0.94 < 유성낙하 0.96 < 여기 1.0)
const JUDGMENT_WHITEOUT_ALPHA := 1.0
const JUDGMENT_WHITEOUT_IN_DURATION := 0.1
const JUDGMENT_WHITEOUT_OUT_DURATION := 0.28

const JUDGMENT_BEAM_SCALE := 1.4
const JUDGMENT_BEAM_STRETCH := Vector2(1.0, 4.2) # 세로로만 늘려 화면을 관통하는 기둥으로
# 이 시트는 빛줄기가 프레임 아래쪽에서 터지는 구성이라, 스프라이트의 "아래 끝"을 몬스터 발밑에
# 맞춰야 기둥이 하늘에서 내려와 적을 때리는 그림이 된다. 중심을 몬스터에 두면 기둥이 발밑을 지나
# 하단 UI까지 뚫고 내려가 어색했다 — 그래서 고정 오프셋 대신 스프라이트 높이의 절반을 계산해 올린다
const JUDGMENT_BEAM_FOOT_SINK := 6.0 # 발밑보다 살짝 더 내려 꽂아 지면에 닿은 느낌을 준다
# 노란 낙뢰 톤으로 한 번 더 밀어준다 (0번 행이 이미 노란 중심이지만 붉은 기가 남아 있어,
# 살짝 노랑을 얹으면 "번개"에 더 가까워진다)
const JUDGMENT_BEAM_TINT := Color(1.0, 0.96, 0.55, 1)

# 착탄 순간 화이트아웃이 걷히는 그 위로 파란 기운이 아주 짧게 스친다 — 번개가 친 직후의 잔광.
# 흰 화이트아웃과 섞이지 않게 별도 오버레이(_bolt_flash)를 쓴다
const JUDGMENT_BOLT_TINT := Color(0.35, 0.62, 1.0, 1)
const JUDGMENT_BOLT_ALPHA := 0.45
const JUDGMENT_BOLT_IN_DURATION := 0.02
const JUDGMENT_BOLT_OUT_DURATION := 0.06 # 인+아웃 합쳐 0.08초
const JUDGMENT_SHAKE := 26.0
const JUDGMENT_SHAKE_STEPS := 8 # 유성낙하와 진폭은 비슷하되 더 길게 울리게 한다
const JUDGMENT_IMPACT_HOLD := 0.5

# 낮고 웅장한 차징(브라스를 피치 다운) + 착탄은 큰 폭발 + 저역 쿵에 성스러운 브라스 차임을 얹는다
# ── 불사조의 축복 전용 연출 ────────────────────────────────────────────────
# 초재생(치유+마나 이펙트 동시 재생)을 뼈대로 삼되, 티어3답게 더 화려하게 간다:
# 이펙트를 좌우+중앙 세 겹으로 겹치고, 스펠북 티어3 카드에 쓴 반짝임 파티클을 캐릭터 주위에
# 깃털처럼 흩날리게 얹는다. 캐릭터는 이동하지 않는다
const PHOENIX_HEAL_OFFSETS := [Vector2(-22, -8), Vector2(22, -8), Vector2(0, -30)]
const PHOENIX_VFX_SCALE := 1.35
const PHOENIX_STAGGER := 0.07 # 세 겹을 조금씩 늦춰 띄워 한 덩어리로 뭉치지 않게
const PHOENIX_GLOW_TINT := Color(1.0, 0.86, 0.45, 1) # 불사조의 금빛
const PHOENIX_HOLD := 0.55
# 흩날리는 깃털 파티클 (스펠북 티어3 반짝임과 같은 방식으로 텍스처를 코드로 만들어 쓴다)
const PHOENIX_FEATHER_COUNT := 26
const PHOENIX_FEATHER_LIFETIME := 1.5
const PHOENIX_FEATHER_SPREAD := Vector2(46, 58)
const PHOENIX_SFX := [
	# 브라스(트럼펫 같은 팡파르)는 유치하게 들린다는 피드백이 있어 피아노+시타르로 갔다 —
	# 길게 상승하는 그랜드 피아노 화음이 웅장함을, 시타르 차임이 신비로운 여운을 담당한다
	"res://assets/sfx/400 Sounds pack/Musical Effects/grand_piano_positive_long.wav",
	"res://assets/sfx/400 Sounds pack/Musical Effects/sitar_chime_positive.wav",
]

const JUDGMENT_CHARGE_SFX := "res://assets/sfx/400 Sounds pack/Musical Effects/brass_level_start.wav"
const JUDGMENT_CHARGE_SFX_PITCH := 0.7
# 이 팩에는 천둥/번개 전용 샘플이 아예 없어서(400개를 이름으로 전부 훑어 확인) 낙뢰를 조합으로 만든다:
# 날카로운 노이즈 파열(white_noise_short) = 번개가 갈라지는 "쩍" + 큰 폭발음과 저역 쿵 = 뒤따르는 천둥.
# 원래 있던 brass_chime_positive(트럼펫 같은 팡파르)는 "낙뢰"와 맞지 않아 뺐다
const JUDGMENT_IMPACT_SFX := [
	"res://assets/sfx/400 Sounds pack/Other/white_noise_short.wav",
	"res://assets/sfx/400 Sounds pack/Retro/explosion_large.wav",
	"res://assets/sfx/400 Sounds pack/Weapons/harsh_thud.wav",
]

const HAND_BUTTON_COUNT := 5

# 턴 진행 상태: ACTION=플레이어 입력 대기, BUSY=연출 재생 중(입력 무시), OVER=전투 종료
# ACTION: 평소 조작 가능 / BUSY: 연출 재생 중 / OVER: 승패 확정 /
# TARGETING: 피해 카드를 고른 뒤 "누구를 때릴지" 클릭을 기다리는 중 (몬스터가 2마리 이상일 때만 들어간다)
enum Mode { ACTION, BUSY, OVER, TARGETING }

# ── 무기 과열 게이지 / 적 저항 / 카드 배경·프레임·아이콘용 에셋 (조사 리포트에서 확정한 매핑) ──
# GUI/06.png의 대각선 게이지 스프라이트 시트: 색상 행마다 5프레임(0/25/50/75/100%)이 가로로 나열되어
# 있다. 프레임 크기·간격은 픽셀 단위로 직접 측정한 값 (첫 프레임 x=3, 프레임 간격 48px, 폭 42px×높이 7px)
#
# [세로 게이지] 이 시트는 가로 막대만 들어 있어서, 잘라낸 프레임을 코드에서 90도 돌려 세로로 쓴다.
# GUI/04.png에 세로 전용 막대가 따로 있긴 한데 색이 초록/파랑/노랑뿐이라 "검=빨강, 지팡이=파랑"이라는
# 기존 색 약속을 지킬 수 없어서, 색이 맞는 이 시트를 돌려 쓰는 쪽을 택했다. 반시계 방향으로 돌리면
# 가로 막대의 "가득 찬 왼쪽"이 아래로 가서, 게이지가 아래에서 위로 차오르는 자연스러운 방향이 된다
const GAUGE_SHEET_PATH := "res://assets/GUI/06.png"
const GAUGE_FRAME_X_START := 3
const GAUGE_FRAME_X_STEP := 48
const GAUGE_FRAME_WIDTH := 42
const GAUGE_FRAME_HEIGHT := 7
const GAUGE_FRAME_COUNT := 5
# 검=주황/빨강 행(y=69), 지팡이=파랑 행(y=21) — 사용자가 확정한 색상 매핑
const GAUGE_ROW_Y := {
	WeaponState.WeaponType.SWORD: 69,
	WeaponState.WeaponType.STAFF: 21,
}

# Free - Raven Fantasy Icons 시트(32x32 격자, 한 칸 32px). 카드 스킬 아이콘과 적 저항 방패 아이콘을
# 여기서 잘라온다. 좌표는 시트를 직접 눈으로 훑어 찾은 값 (fb742/597/725/659/711 = 조사 리포트에서
# 확정한 5장, fb859/856 = 53행의 저항 방패 8색 중 물리=빨강/마법=하늘색)
const RAVEN_SHEET_PATH := "res://assets/items/Free - Raven Fantasy Icons/Full Spritesheet/32x32.png"
const RAVEN_ICON_SIZE := 32
# 카드 효과별 스킬 아이콘 좌표는 CardLibrary가 갖고 있다 — 스펠북 컬렉션 목록도 같은 아이콘을
# 써야 해서 전투 씬이 아니라 카드 카탈로그 쪽으로 옮겼다
const SKILL_ICON_REGION := CardLibrary.SKILL_ICON_REGION
# 카드가 icon_key로 직접 고른 아이콘의 좌표표. 효과별 기본 아이콘(SKILL_ICON_REGION)보다 우선한다 —
# 같은 DAMAGE라도 흡혈/처형/도박의 일격이 손패에서 서로 구분돼야 해서 생긴 축이다
const CARD_ICON_REGION := CardLibrary.CARD_ICON_REGION
const RESIST_ICON_REGION := {
	EnemyResistance.ResistanceType.PHYSICAL: Rect2(320, 1696, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE), # fb859 — 빨강 저항 방패
	EnemyResistance.ResistanceType.MAGIC: Rect2(224, 1696, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE),     # fb856 — 하늘색 저항 방패
	EnemyResistance.ResistanceType.NONE: Rect2(128, 1184, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE),      # fb597 — 민무늬 방패
}
# 저항 없음(NONE)은 같은 방패 그림을 회색으로 죽이고 반투명하게 깔아 "지금은 아무 저항도 없다"를
# 나타낸다. 시트에 회색 저항 방패가 따로 없어서 색을 빼는 쪽을 택했다 — 빨강/파랑으로 또렷한
# 저항 상태와, 흐릿한 무저항 상태가 색과 진하기 양쪽으로 확실히 구분된다
const RESIST_BADGE_MODULATE := {
	EnemyResistance.ResistanceType.PHYSICAL: Color(1, 1, 1, 1),
	EnemyResistance.ResistanceType.MAGIC: Color(1, 1, 1, 1),
	EnemyResistance.ResistanceType.NONE: Color(0.55, 0.55, 0.6, 0.5),
}
const RESIST_BADGE_GAP := 14.0 # 몬스터 그림 꼭대기 위로 이만큼 띄운다 (실측 간격 약 8px)

# ── 버프/디버프 배지 ────────────────────────────────────────────────────────
# 전용 아이콘 에셋이 없어 짧은 텍스트("공격력↑ 20%")로 대신한다 — 저항 배지처럼 대상 위에 띄우되,
# 정교한 아이콘 디자인은 나중에 다듬을 자리다 (StatusEffects.KIND_LABEL만 갈아끼우면 된다).
# 걸린 게 없으면 아예 숨긴다 (저항 배지와 달리 "없음" 상태를 계속 보여줄 이유가 없다)
# 몬스터 배지는 발밑 "아래"에 둔다. 몬스터 줄이 화면 위쪽(y의 19%)에 붙어 있어서 머리 위로 올리면
# 화면 가장자리와 우상단 HUD 카드에 끼여 읽기 어려웠다 — 아래쪽은 플레이어 줄까지 비어 있어 넉넉하다
const STATUS_BADGE_GAP := 6.0
const PLAYER_STATUS_BADGE_GAP := 62.0 # 플레이어는 머리 위 (위쪽에 가리는 UI가 없다)
const STATUS_BADGE_FONT_SIZE := 11
const BUFF_COLOR := Color(0.55, 0.95, 0.55, 1)
const DEBUFF_COLOR := Color(1.0, 0.6, 0.45, 1)

# ── 다인전 배치 ──────────────────────────────────────────────────────────────
# 몬스터 줄의 세로 위치(뷰포트 높이 대비). 단일 전투 때 쓰던 값을 그대로 유지해, 1마리 전투의
# 구도가 다인전 도입 전과 똑같이 보이게 한다
const MONSTER_ROW_Y_FRACTION := 0.19
const MONSTER_GAP := 16.0 # 옆 몬스터와 벌릴 최소 간격(스프라이트 폭에 더해진다)
# HUD 몬스터 카드(.tscn의 MonsterCard) 치수. 세로로 쌓을 위치를 계산하는 데 쓰고,
# 스프라이트가 카드 열을 침범하지 않게 하는 오른쪽 한계선도 이 폭에서 나온다
const MONSTER_CARD_WIDTH := 231.0
const MONSTER_CARD_HEIGHT := 75.0
const MONSTER_CARD_TOP := 16.0
const MONSTER_CARD_GAP := 6.0
const MONSTER_CARD_MARGIN := 24.0 # 카드 열과 몬스터 스프라이트 사이 여백
# 쓰러진 몬스터의 HUD 카드에 씌우는 색조 (지우지 않고 흐리게 남겨 자리 번호가 계속 맞게)
const DEFEATED_CARD_MODULATE := Color(0.45, 0.45, 0.5, 0.75)

# ── 몬스터 마나바 (HUD 카드 안, HP바 바로 아래) ──────────────────────────────
# HP바처럼 정교할 필요는 없고 "줄었다/찼다"만 읽히면 되므로, .tscn을 고치는 대신 코드로 만들어
# 붙인다 (0번 카드에 붙여두면 나머지 카드는 duplicate()로 그대로 물려받는다).
# 색은 HP(빨강)와 확실히 갈리는 보랏빛 파랑 — 플레이어 마나바(하늘색)와도 톤이 달라 헷갈리지 않는다
const MONSTER_MANA_BAR_RECT := Rect2(80, 27, 145, 9)
const MONSTER_MANA_BAR_BG := Color(0.08, 0.07, 0.13, 0.85)
const MONSTER_MANA_BAR_FILL := Color(0.45, 0.38, 0.9, 1.0)

# ── 피격 시 화면 가장자리 붉은 물듦 ─────────────────────────────────────────
# 화면 전체를 덮는 HitFlash와 달리 가장자리만 물들여야 해서, 가운데가 투명하고 바깥으로 갈수록
# 붉어지는 방사형 그라디언트를 코드로 만들어 쓴다 (셰이더 없이 GradientTexture2D의 radial 채우기).
# 중앙이 비어 있어 전투 장면을 가리지 않으면서 "맞았다"는 감각만 준다
const EDGE_FLASH_COLOR := Color(0.75, 0.05, 0.06)
# "가장자리가 살짝 물드는" 정도를 노린 값. 처음엔 0.55/0.42로 잡았는데 실제로 찍어 보니 붉은 기가
# 화면 절반까지 올라와 카드 UI까지 덮여서, 세기를 낮추고 투명한 중앙을 넓혔다
const EDGE_FLASH_ALPHA := 0.34
const EDGE_FLASH_IN_DURATION := 0.06
const EDGE_FLASH_OUT_DURATION := 0.34
const EDGE_FLASH_INNER_STOP := 0.6 # 이 반지름까지는 완전히 투명 (가운데를 비워두는 범위)

# ── 몬스터 행동 연출 ────────────────────────────────────────────────────────
const ENEMY_ATTACK_VFX_SCALE := 0.9 # 카드 이펙트보다 살짝 작게 — 적 공격이 화면을 다 덮지 않도록
const ENEMY_RECOVER_VFX_SCALE := 1.0
const ENEMY_RECOVER_HOLD := 0.55 # 회복 연출을 보여주는 시간

# 몬스터 돌진: 기존 _lunge(제자리에서 26px 툭)로는 "제자리에서 화면만 흔들린다"는 인상이 그대로라,
# 섬광 카드의 돌진과 같은 방식(실제 이동 + 잔상)으로 플레이어 코앞까지 달려들었다가 돌아가게 한다.
# 정지 지점 계산은 _flash_slash_dash_target과 같은 "두 스프라이트 테두리 사이 간격" 방식을 쓴다
const ENEMY_CHARGE_GAP := 18.0
const ENEMY_CHARGE_IN_DURATION := 0.16
# 복귀는 던져두고(await 없이) 다음 연출로 넘어간다. 이 값이 아래 피격 연출의 대기 시간(최소 0.3초)보다
# 짧아야, 다음 몬스터가 움직이기 전에 이미 제자리로 돌아가 있다
const ENEMY_CHARGE_BACK_DURATION := 0.22
const ENEMY_CHARGE_TINT := Color(1.0, 0.55, 0.55, 1.0) # 잔상 색 (붉게 물든 적의 궤적)

# ── 타겟 선택 표시 ───────────────────────────────────────────────────────────
# 발밑 원(선택 가능 표시)과 머리 위 화살표. 전용 아이콘 에셋이 없어 그림자(_setup_shadow)와 같은
# 방식으로 폴리곤을 직접 만들어 쓴다 — 에셋이 생기면 _build_target_marker()만 갈아끼우면 된다
const TARGET_RING_RX := 46.0
const TARGET_RING_RY := 15.0
const TARGET_RING_FILL := Color(1.0, 0.85, 0.25, 0.22)
const TARGET_RING_LINE := Color(1.0, 0.88, 0.35, 0.95)
const TARGET_RING_LINE_WIDTH := 3.0
const TARGET_ARROW_COLOR := Color(1.0, 0.88, 0.35, 0.95)
const TARGET_ARROW_HALF_WIDTH := 14.0
const TARGET_ARROW_HEIGHT := 20.0
# 화살표 아래 끝을 몬스터 그림 꼭대기에서 이만큼 위에 둔다. 저항 배지(RESIST_BADGE_GAP + 아이콘 절반)
# 보다 더 위로 올려, 둘이 겹쳐 읽기 어려워지지 않게 한 값
const TARGET_ARROW_GAP := 38.0
const TARGET_ARROW_BOB := 6.0 # 화살표가 위아래로 까딱이는 폭
const TARGET_ARROW_BOB_DURATION := 0.45
const TARGET_RING_PULSE_DURATION := 0.6
const TARGET_RING_PULSE_ALPHA := 0.45 # 맥동할 때 원 테두리가 옅어지는 정도

# 카드 프레임/뒷면 전용 시트(assets/GUI/card_template.png). 칸 크기 68x109, 색상별 앞면(테두리)·
# 뒷면(다이아몬드 문양) 좌표를 직접 픽셀 단위로 조사해 확정한 값이다 (주황 칸은 이번엔 안 씀).
# 카드 색은 CardColor가 아니라 "효과"를 기준으로 고른다 — 물리 공격만 빨강이고 마법 공격은 파랑,
# 회복류(체력/마나)는 초록, 방어·회피처럼 무기와 무관한 카드는 회색으로 묶는다
const CARD_SHEET_PATH := "res://assets/GUI/card_template.png"
const CARD_FRONT_REGION := {
	"grey": Rect2(54, 33, 68, 109),
	"red": Rect2(54, 162, 68, 109),
	"blue": Rect2(166, 162, 68, 109),
	"green": Rect2(54, 290, 68, 109),
}
# 5장 전부 동일한 회색 뒷면으로 통일한다 — 뒤집기 전에 카드 색으로 종류가 미리 드러나면 안 되기 때문
const CARD_BACK_REGION := Rect2(54, 434, 68, 109)

# 같은 시트의 안 쓰던 부속 요소들. 참고 이미지처럼 "원형 아이콘 테두리 + 이름 배너 + 모서리 배지"
# 구조를 만들어 카드가 텍스트만 덩그러니 있는 느낌을 없앤다. 셋 다 카드 4색(회색/빨강/파랑/초록)이
# 전부 갖춰져 있어 카드 색과 1:1로 맞출 수 있다
const CARD_ICON_FRAME_REGION := { # 아이콘 뒤에 깔리는 원형 테두리 (20x20)
	"grey": Rect2(294, 647, 20, 20),
	"red": Rect2(294, 711, 20, 20),
	"blue": Rect2(294, 775, 20, 20),
	"green": Rect2(294, 743, 20, 20),
}
const CARD_NAME_BANNER_REGION := { # 카드 이름 뒤에 깔리는 띠 (46x11)
	"grey": Rect2(369, 483, 46, 11),
	"red": Rect2(369, 547, 46, 11),
	"blue": Rect2(369, 611, 46, 11),
	"green": Rect2(369, 579, 46, 11),
}
# 비용을 넣을 마름모 배지 (16x16). 카드 색과 무관하게 자원 색으로 고정한다 —
# 마나=파랑, 체력=빨강으로 HP바/마나바와 같은 색이라 숫자만 봐도 무슨 자원인지 바로 안다
const CARD_MANA_BADGE_REGION := Rect2(432, 768, 16, 16)
const CARD_HP_BADGE_REGION := Rect2(432, 704, 16, 16)

const CARD_SIZE := Vector2(138, 256) # HandArea의 각 카드 슬롯 크기 (.tscn의 Card1~5 offset과 일치시켜야 함).
# 폭은 그대로 두고 높이만 221->256으로 키웠다 — flavor_text 박스가 들어갈 자리를 만들어야 했는데,
# 폭을 키우면 손패 5장이 가로로 화면 밖까지 밀려날 위험이 있어(HandArea가 딱 그 폭에 맞춰져 있음)
# 세로로만 늘리는 쪽이 안전했다
const CARD_ENABLED_MODULATE := Color(1, 1, 1, 1)
const CARD_DISABLED_MODULATE := Color(0.5, 0.5, 0.5, 0.85) # 과열/마나부족 카드를 흐리게 (기존 disabled 느낌 유지)

# ── 카드 티어 시각 연출 (_apply_card_tier_visuals) ──────────────────────────
# TierGlow는 카드 프레임과 같은 텍스처를 카드보다 조금 크게 띄워, 실제 카드 밑에서 테두리
# 바깥으로 삐져나온 부분만 "발광 테두리"처럼 보이게 하는 값싼 트릭이다 (전용 아웃라인 셰이더 없이도
# 이 픽셀아트 프레임 모양 그대로 광채가 도는 것처럼 보인다)
const TIER_GLOW_MARGIN := 10.0
const TIER2_GLOW_COLOR := Color(1.0, 0.85, 0.45, 1) # 옅은 금색
const TIER2_GLOW_ALPHA_MIN := 0.12
const TIER2_GLOW_ALPHA_MAX := 0.34
const TIER2_GLOW_PULSE_DURATION := 1.1 # 은은하게 천천히 맥동
const TIER3_GLOW_COLOR := Color(1.0, 0.76, 0.15, 1) # 더 진하고 강한 금빛
const TIER3_GLOW_ALPHA_MIN := 0.28
const TIER3_GLOW_ALPHA_MAX := 0.62
const TIER3_GLOW_PULSE_DURATION := 0.7 # 티어2보다 빠르고 강하게 맥동

# 티어3 전용 반짝임 파티클. "카드 주변에 떠다니는 작은 반짝임 몇 개" 정도로 절제한다
const TIER3_SPARKLE_AMOUNT := 6
const TIER3_SPARKLE_LIFETIME := 1.6
const TIER3_SPARKLE_COLOR := Color(1.0, 0.92, 0.55, 1)

# ── 카드 드로우 뒤집기 연출 ──────────────────────────────────────────────────
const DRAW_STAGGER := 0.08 # 카드마다 뒤집기 시작을 이만큼씩 늦춰 순서대로 펼쳐지는 느낌을 낸다
const FLIP_HALF_DURATION := 0.15 # 뒷면->접힘, 접힘->앞면 각 구간 길이 (왕복 총 0.3초)

# ── 카드 마우스 호버 연출 ────────────────────────────────────────────────────
const HOVER_SCALE := 1.15
const HOVER_RISE := 14.0 # 확대와 함께 위로 떠오르는 픽셀 수
const HOVER_DURATION := 0.12

# ── 배너 스타일 버튼(턴 종료/무기 변경/도망가기) 호버/눌림 피드백 ──────────────
# 오브젝티브 박스 배경은 원래 정적 표시용이라 상태별 텍스처가 따로 없어, modulate/scale로 대신한다
const BANNER_BUTTON_HOVER_MODULATE := Color(1.15, 1.15, 1.15, 1.0)
const BANNER_BUTTON_PRESS_MODULATE := Color(0.85, 0.85, 0.85, 1.0)
const BANNER_BUTTON_PRESS_SCALE := 0.96
const BANNER_BUTTON_FEEDBACK_DURATION := 0.08

@onready var _view: CanvasLayer = $View
@onready var _actors: Node2D = $View/Actors
@onready var _hit_flash: ColorRect = $View/HitFlash
# 화이트아웃(_hit_flash)이 걷히는 동안 그 위에 겹쳐 스치는 두 번째 오버레이.
# 같은 노드를 쓰면 진행 중인 페이드 트윈과 서로 덮어써서 둘 다 망가지므로 별도 노드로 뒀다
@onready var _bolt_flash: ColorRect = $View/BoltFlash
@onready var _player_sprite: AnimatedSprite2D = $View/Actors/PlayerSprite
@onready var _monster_sprite: AnimatedSprite2D = $View/Actors/MonsterSprite
@onready var _player_shadow: Polygon2D = $View/PlayerShadow
@onready var _monster_shadow: Polygon2D = $View/MonsterShadow
@onready var _hud: Control = $View/HUD
@onready var _player_portrait: TextureRect = $View/HUD/PlayerCard/Portrait
@onready var _player_hp_bar: ProgressBar = $View/HUD/PlayerCard/HPBar
@onready var _player_hp_bar_label: Label = $View/HUD/PlayerCard/HPBarLabel
@onready var _player_mana_bar: ProgressBar = $View/HUD/PlayerCard/ManaBar
@onready var _player_mana_bar_label: Label = $View/HUD/PlayerCard/ManaBarLabel
@onready var _player_gold_label: Label = $View/HUD/PlayerCard/GoldLabel
# 아래 MonsterCard 계열 참조는 전부 "0번 몬스터"의 것이다. 마리 수만큼 복제한 나머지 카드는
# _monster_card_panels/_monster_hp_bars 배열로 접근한다 (0번은 이 노드들과 같은 객체)
@onready var _monster_card: Control = $View/HUD/MonsterCard
@onready var _monster_portrait: TextureRect = $View/HUD/MonsterCard/Portrait
@onready var _monster_hp_bar: ProgressBar = $View/HUD/MonsterCard/HPBar
@onready var _monster_hp_bar_label: Label = $View/HUD/MonsterCard/HPBarLabel
@onready var _monster_gold_label: Label = $View/HUD/MonsterCard/GoldLabel
@onready var _message: Label = $View/HUD/BottomBar/InfoPanel/InfoRow/MessageLabel
@onready var _resist_badge: Sprite2D = $View/Actors/ResistBadge
@onready var _main_column: Control = $View/HUD/BottomBar/MainControls
@onready var _sword_gauge_rect: TextureRect = $View/HUD/BottomBar/MainControls/WeaponColumn/SwordGauge
@onready var _staff_gauge_rect: TextureRect = $View/HUD/BottomBar/MainControls/WeaponColumn/StaffGauge
@onready var _hand_row: Control = $View/HUD/BottomBar/MainControls/HandArea
@onready var _weapon_button: Button = $View/HUD/BottomBar/MainControls/WeaponColumn/WeaponButton
@onready var _end_turn_button: Button = $View/HUD/BottomBar/MainControls/LeftButtons/EndTurnButton
@onready var _flee_button: Button = $View/HUD/BottomBar/MainControls/LeftButtons/FleeButton
@onready var _close_button: Button = $View/HUD/BottomBar/CloseButton

var _monster_type: String = ""
var _monster_data: Dictionary = {} # 종류 단위 스탯 표 (마리 수와 무관 — 그룹 전체가 같은 종류)
var _variants: Array = [] # 마리별 시각 변종 (SceneManager가 그대로 전달, 0번 = 필드에서 부딪힌 개체)

# 0번 몬스터의 변종. 마리별 값이 필요한 곳은 전부 _variants[index]나 _monster_frame_size()를 쓰고,
# 이 별칭은 "마리와 무관한 기본값"이 필요한 자리(범위를 벗어난 조회의 대비값)에서만 남아 있다
var _variant: Dictionary = {}

# 마리별 화면 요소. 각 배열의 index는 MonsterState.index와 1:1로 대응한다.
# 0번은 .tscn에 원래 있던 노드를 그대로 쓰고, 1번부터는 그 노드를 duplicate()해서 만든다
var _monster_sprites: Array[AnimatedSprite2D] = []
var _monster_shadows: Array[Polygon2D] = []
var _resist_badges: Array[Sprite2D] = []
# 마리별 버프/디버프 텍스트 배지 (_build_status_badges가 코드로 만들어 붙인다)
var _status_badges: Array[Label] = []
var _player_status_badge: Label
var _monster_card_panels: Array[Control] = []
var _monster_hp_bars: Array[ProgressBar] = []
var _monster_hp_labels: Array[Label] = []
var _monster_mana_bars: Array[ProgressBar] = []
# 피격 시 화면 가장자리를 붉게 물들이는 오버레이 (코드로 만들어 붙인다 — _build_edge_flash 참고)
var _edge_flash: TextureRect
# 마리별 idle 프레임 안에서 실제 그림이 시작되는 y (저항 배지를 머리 위에 붙일 때 쓰는 보정값)
var _monster_art_tops: Array[float] = []
# 매니저가 "쓰러졌다"고 알려준 뒤 아직 사망 연출을 재생하지 않은 자리 번호들.
# 시그널은 매니저 안에서 동기적으로 날아오는데 연출은 카드 연출이 끝난 뒤에 이어야 해서 버퍼에 모은다
var _pending_deaths: Array[int] = []

# 타겟 선택 대기 중인 카드와, 그때 각 몬스터 밑/위에 띄우는 표시 노드들.
# 표시는 Actors의 자식이라 화면 흔들림에도 몬스터와 함께 따라간다
var _pending_target_card: Card = null
var _target_markers: Array[Node2D] = []
# 맥동/까딱임 트윈. 노드를 지우기 전에 반드시 먼저 죽여야 한다 —
# 루프 트윈이 살아있는 채로 대상 노드를 free하면 "Infinite loop detected" 오류가 난다
# (_clear_impact_marker에서 한 번 겪은 문제라 같은 순서를 지킨다)
var _target_marker_tweens: Array[Tween] = []

var _mode: int = Mode.BUSY

var _manager: BattleTurnManager
var _hand_buttons: Array[Button] = []
var _card_wrappers: Array[Control] = []
var _card_frames: Array[TextureRect] = []
var _card_icons: Array[TextureRect] = []
var _card_names: Array[Label] = []
var _card_descs: Array[Label] = []
var _card_icon_frames: Array[TextureRect] = []
var _card_name_banners: Array[TextureRect] = []
var _card_mana_badges: Array[TextureRect] = []
var _card_mana_labels: Array[Label] = []
var _card_hp_badges: Array[TextureRect] = []
var _card_hp_labels: Array[Label] = []
var _card_flavor_boxes: Array[Panel] = []
var _card_flavor_labels: Array[Label] = []
var _card_tier_glows: Array[TextureRect] = []
var _card_tier_sparkles: Array[CPUParticles2D] = []
# 카드칸은 매 턴 같은 wrapper를 재사용하므로, 이전에 걸어둔 루프 트윈을 추적해뒀다가 다시 칠하기
# 전에 반드시 죽여야 한다 — 안 그러면 populate가 불릴 때마다(호버/재사용 등으로 잦다) 같은
# modulate:a 위에 루프 트윈이 계속 쌓여 서로 싸우며 깜빡인다
var _card_tier_glow_tweens: Array[Tween] = []
# 카드 5칸의 원래 위치. 호버로 카드를 띄웠다가 정확히 제자리로 되돌리기 위해 기억해둔다.
# HandArea는 컨테이너가 아니라 평범한 Control이라 자식 위치를 다시 정렬하지 않으므로,
# .tscn에 적힌 offset이 곧 최종 위치이고 _ready() 시점에 읽어도 안전하다
var _card_base_positions: Array[Vector2] = []

# _build_battle_ui_resources()가 한 번 채워 넣는 캐시 (게이지 프레임 텍스처, 스킬/저항 아이콘, 카드 앞뒤 텍스처)
var _sword_gauge_frames: Array[Texture2D] = []
var _staff_gauge_frames: Array[Texture2D] = []
var _skill_icon_textures: Dictionary = {}
var _card_icon_textures: Dictionary = {} # icon_key -> AtlasTexture (효과별 기본값보다 우선)
var _resist_icon_textures: Dictionary = {}
var _card_front_textures: Dictionary = {} # "grey"/"red"/"blue"/"green" -> AtlasTexture
var _card_icon_frame_textures: Dictionary = {}
var _card_name_banner_textures: Dictionary = {}
var _card_back_texture: AtlasTexture
var _card_mana_badge_texture: AtlasTexture
var _card_hp_badge_texture: AtlasTexture
var _vfx_frames: Dictionary = {} # "physical"/"magic"/"heal"/"mana"/"defend"/"dodge" -> SpriteFrames
var _tier_sparkle_texture: ImageTexture # 티어3 카드 파티클용 (한 번만 절차적으로 만들어 재사용)

# 마지막으로 뒤집기 연출을 재생한 턴 번호. _manager.turn_number와 다르면 "방금 새로 뽑은 손패"라는
# 뜻이라 뒤집기를 재생하고, 같으면 카드 한 장을 냈다거나 하는 중간 갱신이라 곧바로 반영한다
var _last_drawn_turn_number: int = 0

# 매니저 시그널로 받은 "방금 무슨 일이 있었는지"를 담아두는 버퍼. 시그널은 매니저 안에서 동기적으로
# 발생하는데 연출은 그 뒤에 이어서 재생해야 하므로, 콜백은 기록만 하고 실제 애니메이션은
# _play_card_flow()/_end_turn_flow()가 담당한다
# 진행 중인 화면 흔들림 트윈 (_shake_actors가 겹쳐 호출될 때 이전 것을 죽이기 위해 들고 있는다)
var _shake_tween: Tween
# 유성낙하의 낙하 지점 예고 마커와 그 맥동 트윈 (착지 순간 함께 정리한다)
var _impact_marker: Polygon2D
var _impact_marker_tween: Tween
# 방금 낸 카드가 실제로 겨냥한 자리 번호들 (광역이면 시전 시점에 살아있던 전원, 아니면 한 자리).
# 시전 "전에" 확정해 두는 이유는, 맞고 쓰러진 몬스터도 연출 대상에는 남아 있어야 하기 때문이다
var _card_targets: Array[int] = []
# 그 대상들의 시전 직전 체력 (자리 번호 -> 체력). 마리별 실제 감소량을 내는 데 쓴다
var _hp_before_by_index: Dictionary = {}
# 이번 적 턴에 벌어진 공격들을 순서대로 담아둔다 (다인전에서는 살아있는 마리 수만큼 쌓인다).
# 각 항목: {"attacker": int, "damage": int, "dodged": bool, "counter": int}
var _enemy_attacks: Array[Dictionary] = []
var _outcome: String = "" # "" / "victory" / "defeat"


func _ready() -> void:
	UiTranslator.bind(self)
	add_to_group("battle_box")
	_build_battle_ui_resources()
	_build_edge_flash()

	for i in range(HAND_BUTTON_COUNT):
		var wrapper := _hand_row.get_node("Card%d" % (i + 1)) as Control
		wrapper.pivot_offset = CARD_SIZE / 2.0 # 뒤집기/호버 스케일이 카드 중심을 기준으로 일어나게
		_card_wrappers.append(wrapper)
		_card_base_positions.append(wrapper.position)
		_card_frames.append(wrapper.get_node("Frame") as TextureRect)
		_card_icons.append(wrapper.get_node("Icon") as TextureRect)
		_card_names.append(wrapper.get_node("NameLabel") as Label)
		_card_descs.append(wrapper.get_node("DescLabel") as Label)
		_card_icon_frames.append(wrapper.get_node("IconFrame") as TextureRect)
		_card_name_banners.append(wrapper.get_node("NameBanner") as TextureRect)
		_card_mana_badges.append(wrapper.get_node("ManaBadge") as TextureRect)
		_card_mana_labels.append(wrapper.get_node("ManaLabel") as Label)
		_card_hp_badges.append(wrapper.get_node("HpBadge") as TextureRect)
		_card_hp_labels.append(wrapper.get_node("HpLabel") as Label)
		_card_flavor_boxes.append(wrapper.get_node("FlavorBox") as Panel)
		_card_flavor_labels.append(wrapper.get_node("FlavorLabel") as Label)

		var glow := wrapper.get_node("TierGlow") as TextureRect
		glow.modulate.a = 0.0
		_card_tier_glows.append(glow)
		_card_tier_sparkles.append(_setup_tier_sparkles(wrapper.get_node("TierSparkles") as CPUParticles2D))
		_card_tier_glow_tweens.append(null)

		var btn := wrapper.get_node("Button") as Button
		_hand_buttons.append(btn)
		btn.pressed.connect(_on_card_pressed.bind(i))
		# 호버 판정은 카드 전체를 덮는 Button이 이미 하고 있으므로 그 시그널을 그대로 빌려 쓴다
		btn.mouse_entered.connect(_on_card_hover.bind(i, true))
		btn.mouse_exited.connect(_on_card_hover.bind(i, false))

	_weapon_button.pressed.connect(_on_weapon_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_flee_button.pressed.connect(_on_flee_pressed)
	_close_button.pressed.connect(_on_close_pressed)

	_wire_banner_button_feedback(_weapon_button)
	_wire_banner_button_feedback(_end_turn_button)
	_wire_banner_button_feedback(_flee_button)
	_wire_banner_button_feedback(_close_button)


# 과열 게이지 프레임, 카드 스킬/저항 아이콘, 카드 프레임 스타일박스를 한 번만 잘라서 캐시해둔다
# (기존 _build_portrait()/_build_frames()와 같은 방식 — AtlasTexture로 시트 일부만 잘라 쓴다)
func _build_battle_ui_resources() -> void:
	var gauge_sheet := load(GAUGE_SHEET_PATH) as Texture2D
	_sword_gauge_frames = _build_gauge_frames(gauge_sheet, GAUGE_ROW_Y[WeaponState.WeaponType.SWORD])
	_staff_gauge_frames = _build_gauge_frames(gauge_sheet, GAUGE_ROW_Y[WeaponState.WeaponType.STAFF])

	var raven_sheet := load(RAVEN_SHEET_PATH) as Texture2D
	for effect in SKILL_ICON_REGION:
		_skill_icon_textures[effect] = _atlas(raven_sheet, SKILL_ICON_REGION[effect])
	for icon_key in CARD_ICON_REGION:
		_card_icon_textures[icon_key] = _atlas(raven_sheet, CARD_ICON_REGION[icon_key])
	for resistance in RESIST_ICON_REGION:
		_resist_icon_textures[resistance] = _atlas(raven_sheet, RESIST_ICON_REGION[resistance])

	var card_sheet := load(CARD_SHEET_PATH) as Texture2D
	for key in CARD_FRONT_REGION:
		_card_front_textures[key] = _atlas(card_sheet, CARD_FRONT_REGION[key])
		_card_icon_frame_textures[key] = _atlas(card_sheet, CARD_ICON_FRAME_REGION[key])
		_card_name_banner_textures[key] = _atlas(card_sheet, CARD_NAME_BANNER_REGION[key])
	_card_back_texture = _atlas(card_sheet, CARD_BACK_REGION)
	_card_mana_badge_texture = _atlas(card_sheet, CARD_MANA_BADGE_REGION)
	_card_hp_badge_texture = _atlas(card_sheet, CARD_HP_BADGE_REGION)

	for key in VFX_CONFIG:
		_vfx_frames[key] = _build_vfx_frames(VFX_CONFIG[key])

	_tier_sparkle_texture = _build_sparkle_texture()


# VFX_CONFIG 항목 하나로 재생 한 번짜리 SpriteFrames를 만든다. 같은 시트를 카드마다 새로 열지 않도록
# load()는 캐시되지만, SpriteFrames 자체는 한 번만 만들어 재사용한다 — 실제 재생은 _play_card_vfx()가
# 매번 이 SpriteFrames를 참조하는 새 AnimatedSprite2D를 만들어서 하므로 여러 장 동시 재생도 안전하다
func _build_vfx_frames(cfg: Dictionary) -> SpriteFrames:
	var sheet := load(cfg["path"]) as Texture2D
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("play")
	frames.set_animation_speed("play", cfg["fps"])
	frames.set_animation_loop("play", false)
	var row: int = cfg["row"]
	for i in range(cfg["frames"]):
		frames.add_frame("play", _atlas(sheet, Rect2(i * VFX_FRAME_SIZE, row * VFX_FRAME_SIZE, VFX_FRAME_SIZE, VFX_FRAME_SIZE)))
	return frames


# 티어3 카드 파티클용 작은 십자 반짝임(sparkle)을 코드로 직접 그려 만든다. 전용 에셋을 찾는 대신
# 5x5 흰 픽셀 이미지를 만들어 CPUParticles2D.color로 금색을 입힌다 — 이렇게 하면 시트 조사 없이도
# 어떤 색 티어든 재사용 가능한 중립 스프라이트가 된다
func _build_sparkle_texture() -> ImageTexture:
	var size := 5
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mid := size / 2
	for x in range(size):
		img.set_pixel(x, mid, Color(1, 1, 1, 1))
	for y in range(size):
		img.set_pixel(mid, y, Color(1, 1, 1, 1))
	img.set_pixel(mid - 1, mid - 1, Color(1, 1, 1, 0.6))
	img.set_pixel(mid + 1, mid - 1, Color(1, 1, 1, 0.6))
	img.set_pixel(mid - 1, mid + 1, Color(1, 1, 1, 0.6))
	img.set_pixel(mid + 1, mid + 1, Color(1, 1, 1, 0.6))
	return ImageTexture.create_from_image(img)


# 카드칸 하나의 CPUParticles2D를 티어3 스파클 설정으로 한 번만 채운다 (emitting은 꺼둔 채로 —
# 실제로 켜고 끄는 건 _apply_card_tier_visuals()가 카드 티어에 따라 담당한다)
func _setup_tier_sparkles(particles: CPUParticles2D) -> CPUParticles2D:
	particles.emitting = false
	particles.amount = TIER3_SPARKLE_AMOUNT
	particles.lifetime = TIER3_SPARKLE_LIFETIME
	particles.preprocess = TIER3_SPARKLE_LIFETIME # 켜지자마자 이미 떠다니고 있던 것처럼 시작
	particles.randomness = 0.5
	particles.local_coords = true
	particles.texture = _tier_sparkle_texture
	particles.position = CARD_SIZE / 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = CARD_SIZE / 2.0 + Vector2(TIER_GLOW_MARGIN, TIER_GLOW_MARGIN)
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, -6)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 8.0
	particles.scale_amount_min = 1.2
	particles.scale_amount_max = 2.4
	particles.color = TIER3_SPARKLE_COLOR
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0),
	])
	particles.color_ramp = ramp
	return particles


# sheet에서 y행의 게이지 프레임 5장(0/25/50/75/100%)을 왼쪽부터 잘라, 각각 반시계로 90도 돌린
# 세로 막대 텍스처로 만들어 반환한다. AtlasTexture는 시트의 영역을 가리키기만 할 뿐 회전은 못 하므로,
# 픽셀을 실제로 돌려서 별도 ImageTexture로 굽는다 (프레임 5장 x 무기 2종 = 10장뿐이라 부담 없음)
func _build_gauge_frames(sheet: Texture2D, y: int) -> Array[Texture2D]:
	var sheet_image := sheet.get_image()
	var frames: Array[Texture2D] = []
	for i in range(GAUGE_FRAME_COUNT):
		var x := GAUGE_FRAME_X_START + i * GAUGE_FRAME_X_STEP
		var slice := sheet_image.get_region(Rect2i(x, y, GAUGE_FRAME_WIDTH, GAUGE_FRAME_HEIGHT))
		slice.rotate_90(COUNTERCLOCKWISE)
		frames.append(ImageTexture.create_from_image(slice))
	return frames


func _atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas


# SceneManager가 전투 씬을 트리에 넣은 직후 호출. 몬스터 종류와 마리별 시각 변종(필드에서 뽑힌 것과
# 동일한 개체가 0번)을 받아 스프라이트/구도를 세팅하고, 전투 매니저를 만들어 첫 턴을 연다.
#
# variants가 비어 있으면 한 마리로 취급한다 — 필드를 거치지 않고 전투 씬만 직접 띄우는 호출부
# (디버그/테스트 씬)가 마리 수를 신경 쓰지 않아도 되게 하기 위함
func start_with(monster_type: String, variants: Array) -> void:
	_monster_type = monster_type
	_monster_data = BattleData.MONSTERS[monster_type]
	_variants = variants if not variants.is_empty() else [BattleData.pick_variant(monster_type)]
	_variant = _variants[0] # 컷신들이 읽는 임시 별칭 (0번 몬스터)

	MusicManager.play("Battle 1")

	_setup_sprites()
	_layout_actors()

	_manager = BattleTurnManager.new(monster_type, _variants, StarterDeck.build())
	_manager.turn_started.connect(_on_turn_started)
	_manager.card_played.connect(_on_card_played)
	_manager.enemy_attack_resolved.connect(_on_enemy_attack_resolved)
	_manager.monster_recovered.connect(_on_monster_recovered)
	_manager.monster_defeated.connect(_on_monster_defeated)
	_manager.player_defeated.connect(_on_player_defeated)
	_manager.enemy_defeated.connect(_on_enemy_defeated)

	for i in range(_monster_hp_bars.size()):
		_monster_hp_bars[i].max_value = _monster_data["max_hp"]
		_monster_hp_bars[i].value = _monster_data["max_hp"]
	_refresh_monster_mana_bars()
	_player_hp_bar.max_value = GameState.get_flag("player_max_hp")
	_player_hp_bar.value = GameState.get_flag("player_hp")

	_player_gold_label.text = str(GameState.gold)
	_monster_gold_label.text = "%d~%d" % [_monster_data["gold_min"], _monster_data["gold_max"]]

	_close_button.visible = false
	_main_column.visible = true

	_manager.start() # 첫 턴 시작 (저항 롤 + 손패 5장 드로우)

	# _refresh_hand_buttons()가 _mode도 함께 반영하므로, 갱신 전에 먼저 ACTION으로 바꿔야
	# 첫 턴 손패가 비활성인 채로 시작하지 않는다. 뒤집기 연출이 도는 동안은 카드 말고도
	# 무기/턴종료/도망 버튼까지 잠가둬 애니메이션 중 조작이 끼어들지 않게 한다
	_mode = Mode.ACTION
	_set_inputs_enabled(false)
	await _refresh_all() # 손패가 새로 뽑힌 첫 턴이라 여기서 뒤집기 연출까지 끝날 때까지 기다린다
	_set_inputs_enabled(true)
	# 몬스터별 전용 등장 문구가 있으면 그걸, 없으면 기본 "N 출현!"을 쓴다 (여러 마리면 마리 수도 함께).
	# 첫 턴 저항도 이미 굴려진 상태라, 등장 문구 뒤에 이어 붙여 1턴부터 저항을 알 수 있게 한다
	_message.text = _appear_text()
	var first_resist := _resistance_announcement()
	if first_resist != "":
		_message.text += "\n" + first_resist


# 전투 시작 안내 문구. 한 마리면 기존과 똑같고, 여러 마리면 "오크 3마리가 나타났다!"로 바꿔
# 플레이어가 첫 화면에서 바로 상황을 읽게 한다 (전용 등장 문구가 있는 몬스터는 그걸 우선)
func _appear_text() -> String:
	var count := _manager.monsters.size() if _manager != null else 1
	if count > 1:
		return tr("%s %d마리가 나타났다!") % [tr(_monster_data["name"]), count]
	var custom_text: String = _monster_data.get("appear_text", "")
	if custom_text != "":
		return tr(custom_text)
	return tr("%s 출현!") % tr(_monster_data["name"])


# ── 매니저 시그널 수신 (기록만; 연출은 아래 flow 함수들이 담당) ──────────────

func _on_turn_started(_turn_number: int) -> void:
	_show_turn_message()


# "N번째 턴" 안내 + (저항이 걸린 턴이면) 저항 안내를 인포창에 띄운다.
# 턴 시작 시그널은 적 반격 연출보다 먼저 날아오는데 그 연출이 인포창을 덮어쓰므로, 연출이 끝난
# 뒤에도 한 번 더 불러줘야 플레이어가 이번 턴 저항을 실제로 읽을 수 있다 (_end_turn_flow 참고)
func _show_turn_message() -> void:
	if _manager == null:
		return
	var text := tr("%d번째 턴 — 카드를 사용하세요.") % _manager.turn_number
	var resist_text := _resistance_announcement()
	if resist_text != "":
		text += "\n" + resist_text
	_message.text = text


# "오크가 물리 면역을 얻었다! 데미지 50% 감소" 같은 안내. 감소 퍼센트는 실제 규칙값
# (EnemyResistance.RESIST_DAMAGE_MULTIPLIER)에서 계산하므로, 밸런스를 바꿔도 문구가 따라간다.
#
# 다인전에서는 마리마다 저항을 따로 굴리므로, 저항이 걸린 마리만 골라 한 줄씩 이어 붙인다.
# 아무도 저항이 없는 턴이면 빈 문자열 (여러 줄이 되면 인포창이 길어지지만, 어느 놈이 어떤 저항인지가
# 곧 이번 턴 판단의 근거라 줄여 쓰지 않는다)
func _resistance_announcement() -> String:
	if _manager == null:
		return ""

	var cut_percent := int(round((1.0 - EnemyResistance.RESIST_DAMAGE_MULTIPLIER) * 100.0))
	var lines: Array[String] = []
	for monster in _manager.alive_monsters():
		var kind := ""
		match monster.resistance.current:
			EnemyResistance.ResistanceType.PHYSICAL:
				kind = tr("물리")
			EnemyResistance.ResistanceType.MAGIC:
				kind = tr("마법")
			_:
				continue
		var name_ := monster.display_name
		var subject := name_ + _subject_particle(name_)
		lines.append(tr("%s %s 면역을 얻었다! 데미지 %d%% 감소") % [subject, kind, cut_percent])

	return "\n".join(lines)


# 한글 이름 뒤에 붙일 주격 조사를 고른다 (받침 있으면 "이", 없으면 "가").
# "오크가 / 스켈레톤이"처럼 몬스터마다 달라서, "이(가)"로 얼버무리지 않고 제대로 고른다.
# 영어 로케일에서는 이름이 이미 영문이라(한글 음절이 아니라) 자연히 빈 문자열을 반환한다
func _subject_particle(word: String) -> String:
	if word.is_empty():
		return "가"
	var last := word.unicode_at(word.length() - 1)
	if last < 0xAC00 or last > 0xD7A3: # 한글 음절이 아니면(숫자/영문 등) 조사를 붙이지 않는다
		return ""
	return "이" if (last - 0xAC00) % 28 != 0 else "가"


# 카드 사용 결과는 여기서 따로 담아두지 않는다 — 연출이 마리별로 "시전 전 체력 - 지금 체력"을
# 직접 계산하기 때문(_damage_dealt_to). 광역기는 마리마다 숫자가 달라 총합 하나로는 표현할 수 없다
func _on_card_played(_card: Card, _damage_dealt: int) -> void:
	pass


# 적 턴에는 살아있는 마리 수만큼 이 콜백이 순서대로 날아온다 — 연출은 _animate_enemy_turn()이
# 나중에 이 목록을 순서대로 재생한다 (시그널은 매니저 안에서 동기적으로 전부 끝난 뒤에야 제어가 돌아온다)
func _on_enemy_attack_resolved(attacker_index: int, target_index: int, damage_taken: int, dodged: bool, counter_damage: int) -> void:
	_enemy_attacks.append({
		"action": "attack",
		"attacker": attacker_index,
		"target": target_index,
		"damage": damage_taken,
		"dodged": dodged,
		"counter": counter_damage,
	})


# 마나가 바닥나 숨을 고른 몬스터. 공격과 같은 버퍼에 순서대로 쌓아, 적 턴 연출이 실제 진행 순서대로
# 재생되게 한다 (2마리는 때리고 1마리는 회복하는 턴도 그대로 순서를 지킨다)
func _on_monster_recovered(index: int, mana_gained: int, hp_gained: int) -> void:
	_enemy_attacks.append({
		"action": "recover",
		"attacker": index,
		"mana": mana_gained,
		"hp": hp_gained,
	})


# 마리 하나가 쓰러짐. 사망 연출은 진행 중인 카드/적턴 연출이 끝난 뒤에 재생해야 하므로 여기서는 기록만 한다
func _on_monster_defeated(index: int) -> void:
	if not _pending_deaths.has(index):
		_pending_deaths.append(index)


func _on_enemy_defeated() -> void:
	_outcome = "victory"


func _on_player_defeated() -> void:
	_outcome = "defeat"


# ── 플레이어 입력 ──────────────────────────────────────────────────────────

# 손패 버튼 클릭: 해당 슬롯의 카드를 낸다 (낼 수 없는 카드면 버튼이 이미 비활성이라 눌리지 않음).
# 대상을 골라야 하는 카드면 바로 내지 않고 타겟 선택 모드로 들어간다.
# 타겟 선택 중에 다른 카드를 눌러도 여기로 들어오는데, 그때는 고른 카드가 새 카드로 갈아끼워진다
func _on_card_pressed(index: int) -> void:
	if not _is_interactive() or _manager == null:
		return
	if index >= _manager.hand.cards.size():
		return
	var card: Card = _manager.hand.cards[index]
	if not _manager.can_play_card(card):
		return

	if _needs_target(card):
		_begin_targeting(card)
		return

	# 대상이 필요 없는 카드(회복/방어/피하기/반격 등)는 고르는 절차 없이 즉시 발동한다
	_cancel_targeting()
	_play_card_flow(card)


# 조작을 받을 수 있는 상태인지 (평소 + 타겟 선택 중). 연출 중(BUSY)이거나 전투가 끝났으면(OVER) 아니다
func _is_interactive() -> bool:
	return _mode == Mode.ACTION or _mode == Mode.TARGETING


# 이 카드가 "누구를 때릴지" 고를 필요가 있는지.
#
# 기준은 카드 색깔이 아니라 효과다 — 대상이 갈리는 건 "적에게 피해를 주는가"이지 물리/마법 여부가
# 아니기 때문이다. 회복/마나회복/체력마나회복은 자기 자신에게, 방어/피하기/반격은 "다음 적 공격"에
# 거는 상태라 어느 것도 고를 대상이 없다. 반격은 되받아칠 상대가 공격해온 몬스터로 이미 정해져 있다
# (BattleTurnManager._resolve_single_attack).
#
# 살아있는 몬스터가 하나뿐이면 고를 여지가 없으므로 선택 UI를 건너뛴다 — 1:1 전투의 조작감이
# 다인전 도입 전과 완전히 똑같이 유지된다
func _needs_target(card: Card) -> bool:
	if not _targets_an_enemy(card):
		return false
	# 광역기는 대상이 "살아있는 전원"으로 이미 정해져 있어 고를 것이 없다
	if card.is_aoe:
		return false
	return _manager != null and _manager.alive_monsters().size() > 1


# 이 카드가 "적 하나"를 겨냥하는 종류인지. 대상 선택이 필요한지를 가르는 기준이며,
# 자기 자신에게 거는 효과(회복/방어/피하기/반격/자기버프)는 여기서 전부 걸러진다.
# 새 효과 타입을 추가할 때 이 목록에 넣을지만 정하면 타겟팅 UI가 알아서 따라온다
func _targets_an_enemy(card: Card) -> bool:
	match card.effect:
		Card.EffectType.DAMAGE, Card.EffectType.DEBUFF_ATTACK_ENEMY:
			return true
		Card.EffectType.STATUS_PACKAGE:
			# 묶음이 적을 겨냥하는지 자기 자신인지는 묶음 표가 안다 (자기버프 묶음이 생겨도 여기 그대로)
			return StatusEffects.package_targets_enemy(card.status_package)
		_:
			return false


# ── 타겟 선택 ──────────────────────────────────────────────────────────────

# 카드를 손에 든 채 "누구를 때릴지" 고르는 상태로 들어간다. 이미 다른 카드로 고르는 중이었다면
# 그 선택은 버리고 새 카드 기준으로 다시 시작한다
func _begin_targeting(card: Card) -> void:
	_clear_target_markers()
	_pending_target_card = card
	_mode = Mode.TARGETING

	for monster in _manager.alive_monsters():
		_target_markers.append(_build_target_marker(monster.index))

	_message.text = tr("%s — 대상을 선택하세요.\n(빈 곳 클릭 · 우클릭 · ESC로 취소)") % tr(card.card_name)
	_refresh_hand_buttons()


# 타겟 선택을 물린다. 카드는 아직 손에 남아 있으므로 잃는 것은 없다
func _cancel_targeting() -> void:
	if _mode != Mode.TARGETING:
		return
	_clear_target_markers()
	_pending_target_card = null
	_mode = Mode.ACTION
	_show_turn_message()
	_refresh_hand_buttons()


# 고른 몬스터에게 대기 중이던 카드를 낸다
func _confirm_target(index: int) -> void:
	var card := _pending_target_card
	_clear_target_markers()
	_pending_target_card = null
	_mode = Mode.ACTION # _play_card_flow가 곧바로 BUSY로 바꾼다
	if card != null:
		_play_card_flow(card, index)


# 타겟 선택 중 마우스/키보드 입력 처리.
#
# [입력을 소비하는 기준] 몬스터를 실제로 골랐거나 취소 키를 눌렀을 때만 소비한다. 빈 곳 좌클릭은
# 취소만 하고 소비하지 않는데, 그래야 "손패의 다른 카드를 클릭"이 한 번의 클릭으로 처리된다 —
# _input이 먼저 돌아 선택을 취소하고, 이어서 그 클릭이 카드 버튼까지 전달돼 새 카드로 다시 고르게 된다.
# (Godot 입력 순서: _input → Control GUI → _unhandled_input)
func _input(event: InputEvent) -> void:
	if _mode != Mode.TARGETING:
		return

	if event.is_action_pressed("ui_cancel"):
		_cancel_targeting()
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_targeting()
		get_viewport().set_input_as_handled()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# 몬스터들은 CanvasLayer(View) 안의 Actors 밑에 있으므로, 뷰포트 좌표를 그대로 비교하면 어긋난다.
	# get_global_transform_with_canvas()가 캔버스 레이어 변환까지 포함한 "Actors 로컬 → 화면" 변환이라,
	# 그 역변환으로 클릭 지점을 Actors 로컬 좌표로 되돌린다.
	#
	# 커서 위치(get_local_mouse_position)가 아니라 "이 이벤트가 들고 온 좌표"를 쓰는 게 중요하다 —
	# 둘은 보통 같지만, 이벤트가 실제 커서와 따로 전달되는 경우(입력 주입/터치/리매핑)에는 갈라져서
	# 엉뚱한 곳을 짚게 된다
	var local: Vector2 = _actors.get_global_transform_with_canvas().affine_inverse() * event.position
	var picked := _monster_at_point(local)
	if picked >= 0:
		_confirm_target(picked)
		get_viewport().set_input_as_handled()
		return

	_cancel_targeting() # 빈 곳을 눌렀으면 취소만 하고 클릭은 흘려보낸다(위 주석 참고)


# local_point가 어느 몬스터의 선택 영역 안에 있는지 (없으면 -1).
# 영역은 스프라이트만이 아니라 머리 위 화살표와 발밑 원까지 감싸므로, 표시된 것 아무데나 눌러도 잡힌다
func _monster_at_point(local_point: Vector2) -> int:
	if _manager == null:
		return -1
	for monster in _manager.alive_monsters():
		if _target_hit_rect(monster.index).has_point(local_point):
			return monster.index
	return -1


func _target_hit_rect(index: int) -> Rect2:
	var sprite := _monster_sprite_at(index)
	var frame_size: float = _variants[index].get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE) if index < _variants.size() else BattleData.MOB_IDLE_FRAME_SIZE
	var half_width := maxf(frame_size * MONSTER_SCALE * 0.5, TARGET_RING_RX)
	var art_top := sprite.position.y - frame_size * MONSTER_SCALE * 0.5 + _monster_art_tops[index] * MONSTER_SCALE
	var top := art_top - TARGET_ARROW_GAP - TARGET_ARROW_HEIGHT
	var bottom := sprite.position.y + frame_size * MONSTER_SCALE * 0.5 - 4.0 + TARGET_RING_RY
	return Rect2(sprite.position.x - half_width, top, half_width * 2.0, bottom - top)


# 몬스터 하나의 선택 표시(발밑 원 + 머리 위 화살표)를 만들어 Actors에 붙이고, 맥동/까딱임을 걸어둔다
func _build_target_marker(index: int) -> Node2D:
	var sprite := _monster_sprite_at(index)
	var frame_size: float = _variants[index].get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE) if index < _variants.size() else BattleData.MOB_IDLE_FRAME_SIZE

	var root := Node2D.new()
	root.z_index = 1 # 몬스터보다 앞에 그려 원이 발에 가리지 않게
	_actors.add_child(root)

	# 발밑 원: 반투명 채움 + 또렷한 테두리 (그림자와 같은 타원 계산)
	var foot := sprite.position + Vector2(0, frame_size * MONSTER_SCALE * 0.5 - 4.0)
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		points.append(Vector2(cos(a) * TARGET_RING_RX, sin(a) * TARGET_RING_RY))

	var fill := Polygon2D.new()
	fill.polygon = points
	fill.color = TARGET_RING_FILL
	fill.position = foot
	root.add_child(fill)

	var outline := Line2D.new()
	outline.points = points
	outline.closed = true
	outline.width = TARGET_RING_LINE_WIDTH
	outline.default_color = TARGET_RING_LINE
	outline.position = foot
	root.add_child(outline)

	# 머리 위 화살표 (몬스터를 가리키도록 아래를 향한 삼각형)
	var art_top := sprite.position.y - frame_size * MONSTER_SCALE * 0.5 + _monster_art_tops[index] * MONSTER_SCALE
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(-TARGET_ARROW_HALF_WIDTH, -TARGET_ARROW_HEIGHT),
		Vector2(TARGET_ARROW_HALF_WIDTH, -TARGET_ARROW_HEIGHT),
		Vector2(0, 0),
	])
	arrow.color = TARGET_ARROW_COLOR
	arrow.position = Vector2(sprite.position.x, art_top - TARGET_ARROW_GAP)
	root.add_child(arrow)

	var ring_tween := create_tween().set_loops()
	ring_tween.tween_property(outline, "modulate:a", TARGET_RING_PULSE_ALPHA, TARGET_RING_PULSE_DURATION)
	ring_tween.tween_property(outline, "modulate:a", 1.0, TARGET_RING_PULSE_DURATION)
	_target_marker_tweens.append(ring_tween)

	var arrow_tween := create_tween().set_loops()
	var arrow_base := arrow.position
	arrow_tween.tween_property(arrow, "position", arrow_base + Vector2(0, TARGET_ARROW_BOB), TARGET_ARROW_BOB_DURATION)
	arrow_tween.tween_property(arrow, "position", arrow_base, TARGET_ARROW_BOB_DURATION)
	_target_marker_tweens.append(arrow_tween)

	return root


# 선택 표시를 전부 걷어낸다. 트윈을 먼저 죽이고 나서 노드를 지우는 순서를 반드시 지킬 것
# (루프 트윈이 살아있는 대상을 free하면 Godot이 "Infinite loop detected"로 멈춘다)
func _clear_target_markers() -> void:
	for tween in _target_marker_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_target_marker_tweens.clear()

	for marker in _target_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_target_markers.clear()


# 카드 한 장을 내고 그 결과를 연출로 보여준다. 규칙 적용은 전부 매니저가 이미 끝낸 상태이므로
# 여기서는 HP/마나를 다시 건드리지 않고 화면만 따라간다
# target_index는 플레이어가 고른 대상의 자리 번호. -1이면 자동으로 살아있는 첫 몬스터를 고른다
# (대상을 고를 필요가 없는 카드이거나, 몬스터가 한 마리뿐이라 선택 UI를 건너뛴 경우)
func _play_card_flow(card: Card, target_index: int = -1) -> void:
	_mode = Mode.BUSY
	_set_inputs_enabled(false)

	var hp_before: int = GameState.get_flag("player_hp")
	var mana_before: int = GameState.get_flag("player_mana")
	# play_card()에 넘기는 값과 연출이 가리키는 대상이 반드시 같아야 하므로,
	# 매니저를 부르기 "전에" 대상을 확정해 양쪽에 같은 값을 쓴다
	var target := _manager.get_monster(target_index)
	if target == null or not target.is_alive():
		target = _manager.get_auto_target()
	var resolved_index := target.index if target != null else 0
	var monster_hp_before: int = target.hp if target != null else 0
	target_index = resolved_index

	# 이 카드가 실제로 때릴 대상들(광역이면 전원)과 그 시점의 체력을 기록해 둔다.
	# 대상 판정은 매니저와 같은 함수를 써서 "때린 대상"과 "이펙트가 뜨는 대상"이 갈라지지 않게 하고,
	# 체력은 연출이 마리별 실제 감소량을 계산하는 데 쓴다 (오버킬이어도 팝업 합계가 HP바와 맞는다)
	_card_targets = _manager.resolve_target_indices(card, target_index)
	_hp_before_by_index.clear()
	for index in _card_targets:
		_hp_before_by_index[index] = _monster_hp_of(index)

	if not _manager.play_card(card, target_index):
		_mode = Mode.ACTION
		await _refresh_all()
		return

	await _animate_card(card, hp_before, mana_before, monster_hp_before, target_index)

	await _refresh_all()

	if _outcome == "victory":
		_finish_victory()
		return

	# 이번 카드로 일부만 쓰러졌으면(전멸은 아님) 여기서 그 마리들의 사망 연출을 재생한다
	await _play_pending_deaths()

	# 손패를 전부 소진했으면 "턴 종료"를 누를 일만 남으므로 대신 눌러준다.
	# (어떤 조건에서 자동으로 넘기고 어떤 조건에서 안 넘기는지는 is_hand_exhausted() 주석 참고)
	# 마지막 카드 연출이 끝나자마자 적이 달려들면 급하게 느껴져서, 안내 문구와 함께 한 박자 둔다
	if _manager.is_hand_exhausted():
		_message.text = tr("손패를 모두 사용했다 — 턴을 넘긴다.")
		await _wait(0.5)
		await _end_turn_flow()
		return

	_mode = Mode.ACTION
	_set_inputs_enabled(true)


# 카드 종류별 연출. 피해는 대상별로 "시전 전 체력 - 지금 체력"을 계산해 표시하고
# (오버킬이어도 숫자가 HP바와 어긋나지 않는다), 회복량은 GameState 값의 전후 차이로 보여준다.
# 이펙트/사운드는 여기서 카드별로 직접 부르지 않고 _vfx_key_for_card()로 종류를 정한 뒤
# _play_card_vfx()에서 이펙트+사운드를 함께 재생한다 — 화면 흔들림만 DAMAGE에서 따로 켠다
# target_index는 이 카드가 때릴 몬스터의 자리 번호 (피해 카드가 아니면 쓰이지 않는다).
# 전용 컷신 5종도 이 값을 그대로 넘겨받아, 순간이동/낙하 지점 같은 위치 계산과 팝업/HP바를
# 전부 "플레이어가 고른 그 몬스터" 기준으로 잡는다
func _animate_card(card: Card, hp_before: int, mana_before: int, monster_hp_before: int, target_index: int = 0) -> void:
	var target_sprite := _monster_sprite_at(target_index)
	match card.effect:
		Card.EffectType.DAMAGE:
			if card.card_name == "삼중나선":
				# 삼중나선은 팝업/HP바를 스스로 3단계로 나눠 보여주는 완전히 독립된 컷신이라,
				# 아래 공통 꼬리(단일 팝업+HP바 트윈)를 타지 않고 여기서 바로 끝낸다
				await _play_triple_helix_cutscene(card, monster_hp_before, target_index)
				return
			if card.card_name == "신속":
				# 신속도 같은 이유(스스로 5단계로 나눠 표시)로 공통 꼬리를 타지 않는다
				await _play_swift_cutscene(card, monster_hp_before, target_index)
				return
			if card.card_name == "유성낙하":
				# 단발 강타지만 팝업/HP바를 착지 순간에 맞춰 스스로 띄우므로 공통 꼬리를 타지 않는다
				await _play_meteor_cutscene(card, monster_hp_before, target_index)
				return
			if card.card_name == "시공균열":
				# 해제 순간에 맞춰 스스로 팝업/HP바를 띄우므로 공통 꼬리를 타지 않는다
				await _play_time_rift_cutscene(card, monster_hp_before, target_index)
				return
			if card.card_name == "천벌":
				# 빛기둥 착탄에 맞춰 스스로 팝업/HP바를 띄우므로 공통 꼬리를 타지 않는다
				await _play_judgment_cutscene(card, monster_hp_before, target_index)
				return
			if card.card_name == "파이어볼":
				# 원거리 마법이라 캐릭터는 제자리에 선 채, 앞쪽 허공에 불꽃을 짧게 응축했다가 터뜨린다
				await _play_charge_stage("charge_fire", FIREBALL_CHARGE_SFX, 1.0, FIREBALL_CHARGE_SCALE, FIREBALL_CHARGE_DURATION, target_sprite.position)
				_shake_actors()
				_flash_hit(target_sprite)
				_play_card_vfx(card, target_sprite)
			elif card.card_name == "익스플로전":
				# 2단 차징: 낮은 톤으로 한 번, 더 크고 높은 톤으로 한 번 더 모은 뒤 발사한다.
				# 광역기라 조준/탄착의 기준점은 대상들의 한가운데다 — 한 마리뿐이면 그 몬스터 위치와
				# 같아지므로 1:1 전투의 그림은 예전과 완전히 동일하다
				var blast_center := _targets_center()
				await _play_charge_stage("charge_heavy_1", EXPLOSION_CHARGE1_SFX, EXPLOSION_CHARGE1_PITCH, EXPLOSION_CHARGE1_SCALE, EXPLOSION_CHARGE1_DURATION, blast_center)
				await _play_charge_stage("charge_heavy_2", EXPLOSION_CHARGE2_SFX, EXPLOSION_CHARGE2_PITCH, EXPLOSION_CHARGE2_SCALE, EXPLOSION_CHARGE2_DURATION, blast_center)
				await _launch_projectile(_cast_charge_origin(blast_center), blast_center, "charge_heavy_2", 0.9, EXPLOSION_TRAVEL_DURATION)
				# 흔들림과 폭발음은 화면 전체에 한 번만 (마리 수만큼 겹치면 소리가 뭉개진다)
				_shake_actors(EXPLOSION_SHAKE_AMOUNT, EXPLOSION_SHAKE_STEPS)
				SFXPlayer.play(EXPLOSION_IMPACT_SFX) # 큰 폭발음 위에 저역 "쿵"을 겹친다
				for index in _card_targets:
					var hit_sprite := _monster_sprite_at(index)
					_flash_hit(hit_sprite)
					_play_card_vfx(card, hit_sprite, EXPLOSION_VFX_SCALE_MULT)
				await _wait(0.18) # 폭발이 부풀어오르는 동안 숫자를 잠깐 참았다가 띄운다
			elif card.card_name == "번개창":
				# 하늘에서 그대로 내리꽂히는 그림이라 파이어볼/익스플로전처럼 캐릭터는 움직이지 않는다.
				# 새 컷신은 아니고, 기존 히트 이펙트에 화면 플래시 한 번만 얹은 정도의 보강이다
				_shake_actors()
				_flash_hit(target_sprite)
				_play_card_vfx(card, target_sprite)
				_screen_flash(LIGHTNING_FLASH_TINT, HIT_FLASH_DURATION)
			elif card.card_name == "회전베기":
				# 새 이펙트를 만드는 대신, 같은 물리 이펙트(physical_spin — physical과 동일한 그림)를
				# 0.1초 간격으로 두 번 재생해 "회전하며 여러 방향을 벤다"는 인상을 낸다
				await _lunge(_player_sprite, target_sprite.position)
				_shake_actors()
				_flash_hit(target_sprite)
				_play_card_vfx(card, target_sprite)
				await _wait(0.1)
				_flash_hit(target_sprite)
				_play_card_vfx(card, target_sprite)
			elif card.card_name == "도박의 일격":
				# 성공/실패 어느 쪽이든 크게 휘두르는 동작은 똑같이 나간다 — 결과는 이미 정해져 있지만
				# 플레이어는 착지하는 순간에야 알게 되고, 그 한 박자가 이 카드의 재미다.
				# 갈린 뒤의 차이는 "얼마나 요란한가"로만 준다: 성공은 화면 흔들림 + 확대된 이펙트,
				# 실패는 흔들림 없이 작고 흐린 이펙트에 빗나갔다는 팝업만
				await _lunge(_player_sprite, target_sprite.position)
				if _is_whiff(card):
					var whiff_vfx := _play_card_vfx(card, target_sprite, GAMBLE_WHIFF_VFX_SCALE)
					if whiff_vfx != null:
						whiff_vfx.modulate.a = GAMBLE_WHIFF_VFX_ALPHA
					_show_popup(target_sprite.position, DamageTraits.get_whiff_text(card.damage_trait), DODGE_COLOR)
				else:
					_shake_actors(GAMBLE_HIT_SHAKE_AMOUNT, GAMBLE_HIT_SHAKE_STEPS)
					_flash_hit(target_sprite)
					_play_card_vfx(card, target_sprite, GAMBLE_HIT_VFX_SCALE)
					_screen_flash(GAMBLE_HIT_FLASH_TINT, HIT_FLASH_DURATION)
			elif card.card_name == "섬광":
				# 섬광은 그냥 살짝 찌르는(_lunge) 대신, 몬스터 코앞까지 실제로 달려가서 때리고
				# 곧바로 원위치로 돌아온다 — 베기 전에 노랗게 짧게 번쩍이는 "차징"도 함께 넣는다
				await _flash_charge(_player_sprite)
				var dash_start := _player_sprite.position
				var dash_target := _flash_slash_dash_target(dash_start, target_sprite.position, target_index)
				# 잔상은 돌진과 같은 시간 동안 나란히 재생돼야 "지나간 궤적"처럼 보이므로
				# await 없이 던져서 돌진과 병렬로 돈다
				_spawn_dash_afterimages(_player_sprite, dash_start, dash_target, FLASH_SLASH_CHARGE_TINT)
				var dash_tween := create_tween()
				dash_tween.tween_property(_player_sprite, "position", dash_target, FLASH_SLASH_DASH_DURATION)
				await dash_tween.finished
				_shake_actors()
				_flash_hit(target_sprite)
				_play_card_vfx(card, target_sprite)
				_screen_flash(FLASH_SLASH_CHARGE_TINT, HIT_FLASH_DURATION)
				# 원위치 복귀는 await 없이 던진다 — 메시지/팝업이 뜨는 동안 뒤에서 자연스럽게 돌아가면 되고,
				# 계속 몬스터 앞에 머물러 있으면 다음 턴 배치가 어색해지므로 짧게(0.15s) 돌아온다
				var return_tween := create_tween()
				return_tween.tween_property(_player_sprite, "position", dash_start, FLASH_SLASH_RETURN_DURATION)
				# 이펙트가 스치고 지나간 뒤에야 숫자가 뜨는 "찰나의 딜레이"
				await _wait(0.12)
			else:
				await _lunge(_player_sprite, target_sprite.position)
				_shake_actors()
				_flash_hit(target_sprite)
				_play_card_vfx(card, target_sprite)
			# 대상이 하나든 전원이든 같은 경로로 마리별 숫자를 띄운다 (광역기 공통 처리)
			_show_damage_popups_on_targets()
			_refresh_monster_hp_bars()
			_message.text = _damage_result_message(card)
			# 흡혈/마력흡수처럼 "때린 결과로 무언가를 가져오는" 카드는 여기서 플레이어 쪽 변화도 보여준다
			_play_damage_trait_feedback()
			await _wait(0.35)
		Card.EffectType.HEAL_HP:
			var healed: int = GameState.get_flag("player_hp") - hp_before
			_flash_hit(_player_sprite)
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, "+%d" % healed, HEAL_COLOR)
			_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
			_message.text = tr("%s — 체력 %d 회복!") % [tr(card.card_name), healed]
			await _wait(0.4)
		Card.EffectType.RESTORE_MANA:
			var restored: int = GameState.get_flag("player_mana") - mana_before
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, "+%d MP" % restored, MANA_COLOR)
			_message.text = tr("%s — 마나 %d 회복!") % [tr(card.card_name), restored]
			await _wait(0.4)
		Card.EffectType.DEFEND:
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, tr("방어 %d") % _manager.get_pending_defense(), GUARD_COLOR)
			_message.text = tr("%s — 다음 공격 피해를 %d 줄인다.") % [tr(card.card_name), _manager.get_pending_defense()]
			await _wait(0.35)
		Card.EffectType.DODGE:
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, tr("회피 준비"), DODGE_COLOR)
			_message.text = tr("%s — 다음 공격을 흘려낸다.") % tr(card.card_name)
			await _wait(0.35)
		Card.EffectType.COUNTER:
			# 실제 반격 타격(2단계)은 _play_counter_vfx()가 적 턴에 따로 재생한다 — 여기서는
			# "받아넘길 준비를 했다"는 1단계 연출만 보여준다
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, tr("반격 준비"), GUARD_COLOR)
			_message.text = tr("%s — 다음 공격을 받아넘기고 반격한다.") % tr(card.card_name)
			await _wait(0.35)
		Card.EffectType.RESTORE_BOTH:
			if card.card_name == "불사조의 축복":
				# 같은 RESTORE_BOTH지만 티어3 전용 연출이 따로 있다 (더 화려한 이펙트 + 깃털 파티클)
				await _play_phoenix_cutscene(card, hp_before, mana_before)
				return
			var healed: int = GameState.get_flag("player_hp") - hp_before
			var mana_restored: int = GameState.get_flag("player_mana") - mana_before
			if VFX_SFX.has("restore_both"):
				SFXPlayer.play(VFX_SFX["restore_both"])
			# 체력(heal)과 마나(mana) 이펙트를 좌우로 살짝 갈라 동시에 띄운다 — 겹쳐서 하나로
			# 뭉개지지 않으면서도 "두 자원이 한 번에 차오른다"는 인상을 준다
			_spawn_vfx_sprite("heal", _player_sprite.position + Vector2(-14, -6))
			_spawn_vfx_sprite("mana", _player_sprite.position + Vector2(14, -6))
			_show_popup(_player_sprite.position, "+%d / +%d MP" % [healed, mana_restored], HEAL_COLOR)
			_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
			_message.text = tr("%s — 체력 %d, 마나 %d 회복!") % [tr(card.card_name), healed, mana_restored]
			await _wait(0.4)
		Card.EffectType.BUFF_ATTACK_SELF:
			# 자기 자신에게 거는 버프 — 플레이어 위에 이펙트를 띄우고 배지를 갱신한다
			SFXPlayer.play(VFX_SFX["mana"])
			_spawn_vfx_sprite("mana", _player_sprite.position)
			_show_popup(_player_sprite.position, tr("공격력 +%d%%") % card.value, BUFF_COLOR)
			_refresh_status_badges()
			_message.text = tr("%s — %d라운드 동안 공격력 +%d%%!") % [tr(card.card_name), card.secondary_value, card.value]
			await _wait(0.45)
		Card.EffectType.DEBUFF_ATTACK_ENEMY:
			SFXPlayer.play(VFX_SFX["defend"])
			_spawn_vfx_sprite("defend", target_sprite.position)
			_flash_hit(target_sprite)
			_show_popup(target_sprite.position, tr("공격력 -%d%%") % card.value, DEBUFF_COLOR)
			_refresh_status_badges()
			_message.text = tr("%s! %s의 공격력 -%d%% (%d라운드)") % [
				tr(card.card_name), _monster_display_name(target_index), card.value, card.secondary_value]
			await _wait(0.45)
		Card.EffectType.FREE_NEXT_CARD:
			# 대상이 없고 수치도 없는 카드라, 플레이어 위에 잔상 이펙트(dodge)를 한 번 띄우는 것으로
			# "빨라졌다"만 전한다 — 실제 이득은 다음 카드의 비용 배지가 사라지는 것으로 곧바로 보인다
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, tr("코스트 0"), BUFF_COLOR)
			_message.text = tr("%s — 다음에 내는 카드 1장의 코스트가 0이 된다.") % tr(card.card_name)
			await _wait(0.4)
		Card.EffectType.STATUS_PACKAGE:
			await _play_status_package_effect(card)


# 상태이상 묶음 카드의 연출. 대상이 하나든 전원이든 _card_targets를 그대로 훑으므로
# 광역 묶음(봉인)과 단일 묶음(무력화)이 같은 경로를 쓴다
func _play_status_package_effect(card: Card) -> void:
	var summary := StatusEffects.describe_package(card.status_package)
	var to_self := not StatusEffects.package_targets_enemy(card.status_package)

	SFXPlayer.play(VFX_SFX["defend"])
	if to_self:
		_spawn_vfx_sprite("mana", _player_sprite.position)
		_show_popup(_player_sprite.position, summary, BUFF_COLOR)
	else:
		for index in _card_targets:
			var sprite := _monster_sprite_at(index)
			_spawn_vfx_sprite("defend", sprite.position)
			_flash_hit(sprite)
			_show_popup(sprite.position, summary, DEBUFF_COLOR)
		_shake_actors()

	_refresh_status_badges()
	if _card_targets.size() > 1 and not to_self:
		_message.text = tr("%s! %d마리에게 %s (%d라운드)") % [
			tr(card.card_name), _card_targets.size(), summary, card.secondary_value]
	else:
		_message.text = tr("%s! %s (%d라운드)") % [tr(card.card_name), summary, card.secondary_value]
	await _wait(0.5)


# card.effect(+물리/마법 구분)에 맞는 VFX/SFX 키를 고른다. _card_style_key()와 판단 기준은 같지만
# (물리=빨강/마법=파랑 계열) "회복"과 "마나"를 서로 다른 키로 나눈다는 점이 다르다 — 카드 프레임은
# 둘 다 초록으로 묶지만, 타격 이펙트까지 같으면 두 결과를 구분하기 어렵기 때문
func _vfx_key_for_card(card: Card) -> String:
	if CARD_NAME_VFX_OVERRIDE.has(card.card_name):
		return CARD_NAME_VFX_OVERRIDE[card.card_name]
	match card.effect:
		Card.EffectType.DAMAGE:
			return "magic" if card.color == Card.CardColor.MAGIC else "physical"
		Card.EffectType.HEAL_HP:
			return "heal"
		Card.EffectType.RESTORE_MANA:
			return "mana"
		Card.EffectType.DEFEND:
			return "defend"
		Card.EffectType.DODGE:
			return "dodge"
		Card.EffectType.FREE_NEXT_CARD:
			# 회피와 같은 잔상 스트릭 — 둘 다 "빨라진다"는 인상이라 그림을 나눌 이유가 없다
			return "dodge"
		Card.EffectType.COUNTER:
			return "counter" # 낼 때는 "받아넘길 준비" — 실제 반격 타격은 적 턴에 따로 재생한다
		Card.EffectType.RESTORE_BOTH:
			return "heal"
		_:
			return ""


# 반격이 실제로 적을 때리는 순간의 연출. 이때는 카드가 손을 떠난 뒤(적 턴)라 카드 객체가 없으므로,
# 카드 기반인 _play_card_vfx() 대신 물리 타격 이펙트를 직접 재생한다.
# 반격은 "때린 그 몬스터"를 되받아치므로(BattleTurnManager._resolve_single_attack), 위치는
# 호출부가 공격자 좌표를 넘겨준다 — 다인전에서 엉뚱한 몬스터 위에 반격 이펙트가 터지지 않게
func _play_counter_vfx(pos: Vector2) -> void:
	if not _vfx_frames.has("physical"):
		return
	SFXPlayer.play(VFX_SFX["physical"])
	_spawn_vfx_sprite("physical", pos)


# target 위치에 카드에 맞는 이펙트를 한 번 재생하고, 어울리는 타격음을 SFXPlayer로 함께 튼다.
# 이펙트 스프라이트는 재생이 끝나면(animation_finished) 스스로 사라진다.
# scale_mult로 기본 배율(VFX_DISPLAY_SCALE)보다 더 크게/작게 띄울 수 있다 — 익스플로전처럼
# 같은 재생 경로를 쓰되 "훨씬 크게" 보여야 하는 카드용
# 만든 이펙트 스프라이트를 돌려준다 — 대부분의 호출부는 무시하지만, 도박의 일격 실패처럼
# 재생 직후 밝기를 낮춰야 하는 연출은 이 핸들이 필요하다 (_spawn_vfx_sprite과 같은 규약)
func _play_card_vfx(card: Card, target: Node2D, scale_mult: float = 1.0) -> AnimatedSprite2D:
	var key := _vfx_key_for_card(card)
	if key == "" or not _vfx_frames.has(key):
		return null

	if VFX_SFX.has(key):
		SFXPlayer.play(VFX_SFX[key])

	return _spawn_vfx_sprite(key, target.position, scale_mult)


# VFX_CONFIG의 key에 해당하는 이펙트 스프라이트 하나를 pos에 재생한다 (사운드는 호출부 책임).
# _play_card_vfx()/_play_counter_vfx()가 공유하고, 초재생처럼 한 카드에서 이펙트 두 개를
# 서로 다른 위치에 동시에 띄워야 할 때도 이걸 그대로 두 번 부르면 된다.
# 만든 스프라이트를 돌려주므로, 시공균열처럼 재생 도중 멈췄다가(pause) 다시 돌려야 하는 연출은
# 이 핸들을 붙잡아 두면 된다 (대부분의 호출부는 반환값을 무시한다)
func _spawn_vfx_sprite(key: String, pos: Vector2, scale_mult: float = 1.0, stretch: Vector2 = Vector2.ONE) -> AnimatedSprite2D:
	if not _vfx_frames.has(key):
		return null
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _vfx_frames[key]
	sprite.position = pos
	# stretch로 축별 배율을 따로 줄 수 있다 — 천벌의 빛기둥처럼 세로로만 길게 늘려야 하는 경우용
	sprite.scale = Vector2.ONE * VFX_DISPLAY_SCALE * scale_mult * stretch
	sprite.z_index = 15
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play("play")
	return sprite


# 플레이어가 원거리 마법을 "모으는" 지점 — 겨냥한 대상을 향한 앞쪽 허공(가슴~손 높이).
# 캐릭터 위에 겹쳐 띄우면 자기 몸에 이펙트가 터지는 것처럼 보여서 앞으로 밀어냈다.
# 대상 좌표를 인자로 받는 이유: 다인전에서 어느 몬스터를 노리느냐에 따라 마법을 모으는 방향이
# 달라져야 "그쪽을 겨누고 있다"는 그림이 된다
func _cast_charge_origin(target_pos: Vector2) -> Vector2:
	var offset := target_pos - _player_sprite.position
	var direction := offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
	return _player_sprite.position + direction * CAST_CHARGE_FORWARD + Vector2(0, -CAST_CHARGE_RISE)


# 차징 한 단계: 겨냥한 대상 쪽 허공에 응축 이펙트를 띄우고 차징음을 울린 뒤, 그 단계가 끝날 때까지 기다린다
func _play_charge_stage(key: String, sfx_path: String, pitch: float, scale_mult: float, duration: float, target_pos: Vector2) -> void:
	if sfx_path != "":
		SFXPlayer.play(sfx_path, SFXPlayer.DEFAULT_VOLUME_DB, pitch)
	_spawn_vfx_sprite(key, _cast_charge_origin(target_pos), scale_mult)
	await _wait(duration)


# 응축된 마력 덩어리가 from에서 to까지 날아가는 짧은 투사체. 폭발 이펙트 시트의 한 프레임을
# 정지 이미지로 빌려 쓴다 — 날아가는 동안은 모양이 변할 필요가 없어 AnimatedSprite2D까지는 필요 없다
func _launch_projectile(from: Vector2, to: Vector2, key: String, scale_mult: float, duration: float) -> void:
	if not _vfx_frames.has(key):
		await _wait(duration)
		return
	var frames: SpriteFrames = _vfx_frames[key]
	var sprite := Sprite2D.new()
	sprite.texture = frames.get_frame_texture("play", frames.get_frame_count("play") / 2)
	sprite.position = from
	sprite.scale = Vector2.ONE * VFX_DISPLAY_SCALE * scale_mult
	sprite.z_index = 15
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "position", to, duration)
	tween.tween_callback(sprite.queue_free)
	await tween.finished


# [무기 전환]: 턴당 3회 제한은 매니저(WeaponState)가 관리하므로 여기서는 요청만 하고 결과를 표시한다
func _on_weapon_pressed() -> void:
	if not _is_interactive() or _manager == null:
		return
	# 카드 말고 다른 행동을 하면 고르던 대상은 물린다 — 무기를 바꾸면 어떤 카드를 낼지 판단 자체가
	# 달라지므로, 고른 카드를 그대로 들고 있는 쪽이 오히려 헷갈린다
	_cancel_targeting()
	var next_weapon = WeaponState.WeaponType.STAFF if _manager.weapon.equipped == WeaponState.WeaponType.SWORD else WeaponState.WeaponType.SWORD
	if _manager.switch_weapon(next_weapon):
		_message.text = tr("무기를 %s(으)로 바꿨다.") % _weapon_name(next_weapon)
	else:
		_message.text = tr("이번 턴에는 더 이상 무기를 바꿀 수 없다.")
	_refresh_all()


# [턴 종료]: 적이 반격하고 다음 턴이 열린다 (매니저가 처리). 여기서는 그 결과를 연출로 보여준다
func _on_end_turn_pressed() -> void:
	if not _is_interactive() or _manager == null:
		return
	_cancel_targeting() # 고르던 대상이 있으면 물리고 턴을 넘긴다
	_end_turn_flow()


func _end_turn_flow() -> void:
	_mode = Mode.BUSY
	_set_inputs_enabled(false)

	_enemy_attacks.clear()

	_manager.end_turn() # 적 반격 + 승패 판정 + (안 끝났으면) 다음 턴 시작까지 전부 여기서 일어남

	await _animate_enemy_turn()

	# 여기서 _refresh_all()이 새 턴의 손패 뒤집기 연출까지 통째로 기다린다 — 그래야 바로 아래
	# _set_inputs_enabled(true)가 애니메이션 도중에 카드 내용을 앞당겨 드러내며 끼어들지 않는다
	await _refresh_all()

	if _outcome == "defeat":
		_finish_defeat()
		return

	# 반격으로 적을 전멸시켰다면 승리 처리로 넘어간다 (반격은 적 턴에 일어나므로 카드 흐름이 아니라
	# 여기서 잡아야 한다). 일부만 쓰러졌으면 사망 연출만 재생하고 전투를 계속한다
	if _outcome == "victory":
		_finish_victory()
		return

	await _play_pending_deaths()

	# 적 반격 연출이 인포창을 덮어썼으므로, 이제 새 턴 안내(+이번 턴 저항)를 다시 띄운다
	_show_turn_message()

	_mode = Mode.ACTION
	_set_inputs_enabled(true)


# 적 반격 연출. 실제 피해 적용은 매니저가 이미 GameState.damage_player()로 끝냈으므로
# 여기서는 기록된 결과(_enemy_attacks)에 맞춰 보여주기만 한다.
# 다인전에서는 살아있는 마리 수만큼 항목이 쌓여 있으므로, 공격한 순서대로 한 마리씩 재생한다
func _animate_enemy_turn() -> void:
	for action in _enemy_attacks:
		if action.get("action", "attack") == "recover":
			await _animate_monster_recover(action)
		else:
			await _animate_single_enemy_attack(action)
		_refresh_monster_mana_bars()


# 마나가 바닥난 몬스터가 숨을 고르는 연출: 제자리에서 마나 소용돌이가 감돌고, 체력까지 회복했다면
# 치유 이펙트를 덧씌운다. 공격이 아니므로 화면 흔들림도 가장자리 물듦도 없다 —
# "이 턴엔 안 때린다"가 조용한 연출로 바로 읽히게
func _animate_monster_recover(action: Dictionary) -> void:
	var index: int = action["attacker"]
	var sprite := _monster_sprite_at(index)
	var name_ := _monster_display_name(index)
	var subject := name_ + _subject_particle(name_)
	var mana_gained: int = action["mana"]
	var hp_gained: int = action["hp"]

	SFXPlayer.play(VFX_SFX["mana"])
	_spawn_vfx_sprite("mana", sprite.position, ENEMY_RECOVER_VFX_SCALE)
	_show_popup(sprite.position, "+%d MP" % mana_gained, MANA_COLOR)

	if hp_gained > 0:
		# 체력까지 회복한 경우에만 치유 이펙트를 겹친다 (30% 확률이라 매번 나오지는 않는다)
		await _wait(0.18)
		_spawn_vfx_sprite("heal", sprite.position, ENEMY_RECOVER_VFX_SCALE)
		_show_popup(sprite.position + Vector2(0, -26), "+%d" % hp_gained, HEAL_COLOR)
		_refresh_monster_hp_bars()
		_message.text = tr("%s 마력을 회복했다! (체력도 %d 회복)") % [subject, hp_gained]
	else:
		_message.text = tr("%s 마력을 회복했다!") % subject

	await _wait(ENEMY_RECOVER_HOLD)


# 마리별 마나바를 현재 값으로 맞춘다 (HP바와 달리 트윈 없이 바로 반영 — 보조 정보라 조용히 따라가면 된다)
func _refresh_monster_mana_bars() -> void:
	if _manager == null:
		return
	for monster in _manager.monsters:
		if monster.index < _monster_mana_bars.size():
			_monster_mana_bars[monster.index].value = monster.mana


# 몬스터 한 마리의 공격 연출
func _animate_single_enemy_attack(attack: Dictionary) -> void:
	var attacker_index: int = attack["attacker"]
	var attacker_sprite := _monster_sprite_at(attacker_index)
	var attacker_name := _monster_display_name(attacker_index)

	# 달려들었다가 → 결과 연출 → 제자리로. 회피/방어/반격으로 막힌 경우에도 "달려들긴 했다"는
	# 그림이 남아야 해서, 결과와 무관하게 돌진과 복귀는 항상 일어난다
	var charge_origin := await _enemy_charge(attacker_sprite, attacker_index)
	await _animate_enemy_attack_result(attack, attacker_sprite, attacker_name)
	_enemy_return(attacker_sprite, charge_origin)


# 몬스터가 플레이어 코앞까지 달려든다. 잔상은 이동과 나란히 재생돼야 궤적처럼 보이므로 await 없이 던진다.
# 출발 위치를 돌려줘 호출부가 나중에 정확히 그 자리로 되돌릴 수 있게 한다
func _enemy_charge(sprite: AnimatedSprite2D, index: int) -> Vector2:
	var start := sprite.position
	var to_player := _player_sprite.position - start
	var distance := to_player.length()
	if distance < 1.0:
		return start

	var direction := to_player / distance
	var player_half_width := PLAYER_BODY_WIDTH * PLAYER_SCALE * 0.5
	var stop_distance: float = clamp(distance - _monster_half_width(index) - player_half_width - ENEMY_CHARGE_GAP, 0.0, distance)
	var target := start + direction * stop_distance

	_spawn_dash_afterimages(sprite, start, target, ENEMY_CHARGE_TINT)
	var tween := create_tween()
	tween.tween_property(sprite, "position", target, ENEMY_CHARGE_IN_DURATION)
	await tween.finished
	return start


# 돌진했던 몬스터를 원래 자리로 되돌린다 (await 없이 던져둔다 — 위 상수 주석 참고)
func _enemy_return(sprite: AnimatedSprite2D, origin: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "position", origin, ENEMY_CHARGE_BACK_DURATION)


# 돌진이 닿은 뒤의 결과 연출 (반격/회피/완전방어/피격 중 하나).
# 돌진·복귀와 분리해 둬서, 어떤 결과로 갈라지든 앞뒤 동작은 한 곳에서만 관리된다
func _animate_enemy_attack_result(attack: Dictionary, attacker_sprite: AnimatedSprite2D, attacker_name: String) -> void:
	# 반격: 공격을 받아넘긴 뒤 곧바로 그 몬스터를 때린다. 피해 적용은 매니저가 이미 끝냈으므로
	# 여기서는 적 HP바/숫자를 그 결과에 맞춰 따라가게만 한다 (플레이어는 피해를 안 받는다)
	var counter: int = attack["counter"]
	if counter > 0:
		_show_popup(_player_sprite.position, tr("반격!"), GUARD_COLOR)
		await _wait(0.2)
		_shake_actors()
		_flash_hit(attacker_sprite)
		_play_counter_vfx(attacker_sprite.position)
		_show_popup(attacker_sprite.position, "-%d" % counter, DAMAGE_COLOR)
		_refresh_monster_hp_bars()
		_message.text = tr("%s의 공격을 받아넘겼다! %d 피해로 되돌려줬다!") % [attacker_name, counter]
		await _wait(0.4)
		return

	if attack["dodged"]:
		_show_popup(_player_sprite.position, tr("회피!"), DODGE_COLOR)
		_message.text = tr("%s의 공격을 피했다!") % attacker_name
		await _wait(0.3)
		return

	var damage: int = attack["damage"]
	if damage <= 0:
		_show_popup(_player_sprite.position, tr("막았다!"), GUARD_COLOR)
		_message.text = tr("%s의 공격을 완전히 막아냈다!") % attacker_name
		await _wait(0.3)
		return

	# 실제로 얻어맞은 경우에만 풀세트 연출: 흔들림 + 몬스터 종류별 타격 이펙트 + 가장자리 붉은 물듦.
	# 이펙트를 플레이어 위에 띄우는 이유는 "적이 나를 때렸다"의 결과가 내 몸에서 터져야 읽히기 때문
	_shake_actors()
	_flash_hit(_player_sprite)
	_play_enemy_attack_vfx(_player_sprite.position)
	_play_edge_flash()
	_show_popup(_player_sprite.position, "-%d" % damage, DAMAGE_COLOR)
	_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
	_message.text = tr("%s의 공격! %d 피해!") % [attacker_name, damage]
	await _wait(0.35)


# 이번 전투 몬스터 종류에 배정된 공격 이펙트를 pos에 재생한다 (사운드도 함께).
# 종류가 표에 없으면 오크 것으로 떨어뜨려, 새 몬스터를 추가해도 이펙트가 비어 보이지 않게 한다
func _play_enemy_attack_vfx(pos: Vector2) -> void:
	var key: String = MONSTER_ATTACK_VFX.get(_monster_type, "enemy_orc")
	if not _vfx_frames.has(key):
		return
	if VFX_SFX.has(key):
		SFXPlayer.play(VFX_SFX[key])
	_spawn_vfx_sprite(key, pos, ENEMY_ATTACK_VFX_SCALE)


# 메시지에 쓸 몬스터 이름 (여러 마리면 "오크 2"처럼 번호가 붙은 이름)
func _monster_display_name(index: int) -> String:
	if _manager != null:
		var monster := _manager.get_monster(index)
		if monster != null:
			return monster.display_name
	return tr(_monster_data["name"])


# [도망가기]: HP가 최대치의 FLEE_HP_THRESHOLD 이상일 때만 가능. 승패 없이 즉시 전투를 끝내고
# (처치 카운트/퀘스트 진행 없음, HP·마나는 그대로 유지) 원래 있던 위치로 복귀한다.
# 몬스터는 씬이 통째로 다시 로드되며 자연히 트리거 전 상태로 그 자리에 남으므로 리젠 처리를 하지 않는다.
#
# 도망 성공 시 1~10 사이 무작위 골드를 소모한다(무한 도망-재시작 리롤 방지). GameState.spend_gold()는
# 상점(ui/shop_menu.gd)처럼 "잔액이 부족하면 거래 자체를 막는" all-or-nothing 방식인데, 그건 상점
# 구매가 안 해도 그만인 재량 거래이기 때문이다. 도망가기는 그렇지 않다 — HP 게이팅이 이미 "도망
# 가능 여부"를 담당하고 있고, 골드 소모는 그저 페널티일 뿐이라 돈이 없다고 탈출 자체가 막히면
# 안 된다(무일푼인 플레이어가 오히려 못 이기는 전투에 갇히는 건 이 기능의 취지에 반한다). 그래서
# 여기서는 min(무작위값, 보유 골드)로 미리 clamp해 spend_gold()가 항상 성공하도록 만든다 —
# 결과적으로 마나(spend_mana)의 "0 밑으로 안 내려가고 있는 만큼만 깎는" 방식과 같은 철학이다.
func _on_flee_pressed() -> void:
	if not _is_interactive() or _flee_button.disabled:
		return
	_cancel_targeting()
	_mode = Mode.BUSY
	_set_inputs_enabled(false)

	var penalty: int = min(randi_range(FLEE_GOLD_PENALTY_MIN, FLEE_GOLD_PENALTY_MAX), GameState.gold)
	GameState.spend_gold(penalty)
	_player_gold_label.text = str(GameState.gold)

	_message.text = tr("전투에서 도망쳤다! (골드 %d 소모)") % penalty
	await _wait(0.4)
	SceneManager.flee_battle()


# ── UI 갱신 ────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	await _refresh_hand_buttons()
	_refresh_weapon_button()
	_refresh_status_icons()
	_update_mana_bar()
	_update_player_hp_text()
	# 마리별 HP바를 매니저의 실제 값으로 다시 맞춘다. 컷신들이 중간 단계 수치(3연타의 1/3씩 등)를
	# 직접 그려 넣기 때문에, 연출이 끝난 뒤 한 번은 실제 소유자 값으로 되돌려 놔야 어긋남이 남지 않는다
	_refresh_monster_hp_bars()
	_refresh_monster_mana_bars()
	_refresh_flee_button()


# 손패 5칸을 현재 손패 내용으로 채운다. turn_number가 마지막으로 뒤집었던 턴과 다르면 "방금 새로
# 뽑은 손패"라는 뜻이므로, 내용을 채우자마자 카드 한 장을 낸 것 같은 중간 갱신과 달리 뒤집기
# 연출로 드러낸다 (연출이 끝날 때까지 이 함수도 끝나지 않는다 — 호출부가 그 뒤 순서를
# 안전하게 이어갈 수 있도록)
func _refresh_hand_buttons() -> void:
	var cards: Array = _manager.hand.cards if _manager != null else []
	var is_new_hand := _manager != null and _manager.turn_number != _last_drawn_turn_number
	if is_new_hand:
		_last_drawn_turn_number = _manager.turn_number

	for i in range(HAND_BUTTON_COUNT):
		_populate_card_slot(i, cards)

	if is_new_hand:
		await _play_draw_animation(cards)


# 카드 슬롯 하나(프레임/아이콘/이름/설명/버튼 활성 상태)를 채운다. 빈 칸은 전부 숨긴다.
# 낼 수 없는 카드(과부하/마나부족)는 설명 아래에 짧게 이유를 덧붙이고 카드 전체를 흐리게 만든다
func _populate_card_slot(i: int, cards: Array) -> void:
	var btn := _hand_buttons[i]
	var frame := _card_frames[i]
	var icon := _card_icons[i]
	var name_label := _card_names[i]
	var desc_label := _card_descs[i]

	if i >= cards.size():
		btn.disabled = true
		_set_card_parts_visible(i, false)
		_clear_card_tier_visuals(i) # 카드를 내서 칸이 비었는데 이전 카드의 티어 광채/파티클이 남으면 안 된다
		_card_wrappers[i].modulate = CARD_ENABLED_MODULATE
		_reset_card_hover(i) # 카드를 내서 칸이 비었는데 확대만 남아 있는 상태를 막는다
		return

	var card: Card = cards[i]
	var playable: bool = _manager.can_play_card(card)
	var style_key := _card_style_key(card)

	var desc := _card_description(card)
	if not playable:
		if not _manager.weapon.can_use_card(card):
			desc += tr("\n[과열]")
		elif not GameState.can_afford_mana(_manager.get_effective_mana_cost(card)):
			desc += tr("\n[마나부족]")
		elif not _manager.can_afford_hp(_manager.get_effective_hp_cost(card)):
			desc += tr("\n[체력부족]")

	_set_card_parts_visible(i, true)
	frame.texture = _card_front_textures[style_key]
	_card_icon_frames[i].texture = _card_icon_frame_textures[style_key]
	_card_name_banners[i].texture = _card_name_banner_textures[style_key]
	icon.texture = _skill_icon_for(card)
	name_label.text = tr(card.card_name)
	desc_label.text = desc
	# flavor_text는 수치 설명(desc_label)과 별개로 손으로 쓴 짧은 분위기 문구다. 비워둔 카드도
	# 있을 수 있으니(예: 나중에 급하게 추가한 카드) 그런 경우 박스 자체를 숨겨 빈 칸이 안 보이게 한다
	_card_flavor_boxes[i].visible = card.flavor_text != ""
	_card_flavor_labels[i].visible = card.flavor_text != ""
	_card_flavor_labels[i].text = tr(card.flavor_text)

	# 비용은 설명 문장에 끼워 넣지 않고 아래 두 모서리의 마름모 배지로 뺀다 — 참고 이미지의
	# 모서리 배지와 같은 방식이고, 좁은 설명칸도 아낀다. 왼쪽=마나(파랑), 오른쪽=체력(빨강)이고
	# 해당 비용이 0인 카드는 그 배지만 통째로 숨겨서, 배지가 보이면 곧 비용이 있다는 뜻이 된다.
	#
	# 가속이 걸려 있으면 "지금 실제로 드는 비용"(0)을 기준으로 하므로 배지가 통째로 사라진다 —
	# 다음 한 장이 공짜라는 사실이 손패 다섯 장에서 한눈에 보이고, 3이 적힌 배지를 보고 냈는데
	# 마나가 안 줄어드는 어긋남도 생기지 않는다
	var mana_cost := _manager.get_effective_mana_cost(card)
	_card_mana_badges[i].visible = mana_cost > 0
	_card_mana_labels[i].visible = mana_cost > 0
	if mana_cost > 0:
		_card_mana_badges[i].texture = _card_mana_badge_texture
		_card_mana_labels[i].text = str(mana_cost)

	var hp_cost := _manager.get_effective_hp_cost(card)
	_card_hp_badges[i].visible = hp_cost > 0
	_card_hp_labels[i].visible = hp_cost > 0
	if hp_cost > 0:
		_card_hp_badges[i].texture = _card_hp_badge_texture
		_card_hp_labels[i].text = str(hp_cost)

	# 타겟 선택 중에도 손패는 눌릴 수 있어야 한다 — 다른 카드를 누르면 그 카드로 다시 고르게 되므로
	btn.disabled = not playable or not _is_interactive()
	_card_wrappers[i].modulate = CARD_ENABLED_MODULATE if playable else CARD_DISABLED_MODULATE
	if not playable:
		_reset_card_hover(i) # 커서를 올려둔 채 카드가 과열/마나부족으로 바뀌면 확대를 풀어준다
	_apply_card_tier_visuals(i, card)


# card.effect(+물리/마법 구분)에 따라 프레임 색을 고른다: 물리 공격=빨강, 마법 공격=파랑,
# 회복류(체력/마나)=초록, 방어·회피처럼 무기와 무관한 카드=회색
# 카드 한 칸의 그림 요소를 한꺼번에 켜고 끈다. 마나 배지는 마나를 쓰는 카드에서만 따로 켜므로
# 여기서는 항상 끄기만 하고, 켜는 쪽은 호출부가 담당한다
func _set_card_parts_visible(i: int, shown: bool) -> void:
	_card_frames[i].visible = shown
	_card_icon_frames[i].visible = shown
	_card_name_banners[i].visible = shown
	_card_icons[i].visible = shown
	_card_names[i].visible = shown
	_card_descs[i].visible = shown
	_card_flavor_boxes[i].visible = shown
	_card_flavor_labels[i].visible = shown
	if not shown:
		_card_mana_badges[i].visible = false
		_card_mana_labels[i].visible = false
		_card_hp_badges[i].visible = false
		_card_hp_labels[i].visible = false


# 손패 카드에 그릴 아이콘. 카드가 icon_key로 직접 고른 그림이 있으면 그걸, 없으면 효과별 기본값을 쓴다.
# 고르는 규칙 자체는 CardLibrary가 갖고 있고(스펠북 목록도 같은 아이콘을 써야 하므로) 여기서는
# 미리 잘라둔 AtlasTexture 중에서 꺼내기만 한다
func _skill_icon_for(card: Card) -> AtlasTexture:
	if card.icon_key != "" and _card_icon_textures.has(card.icon_key):
		return _card_icon_textures[card.icon_key]
	return _skill_icon_textures.get(card.effect)


func _card_style_key(card: Card) -> String:
	match card.effect:
		Card.EffectType.DAMAGE:
			return "blue" if card.color == Card.CardColor.MAGIC else "red"
		Card.EffectType.HEAL_HP, Card.EffectType.RESTORE_MANA, Card.EffectType.RESTORE_BOTH:
			return "green"
		_:
			return "grey"


# 카드 설명 문장은 카드 자신이 만든다 (Card.get_effect_description) — 스펠북 컬렉션 목록도
# 같은 문장을 써야 해서 어느 한쪽 UI에 두지 않았다. 여기서는 그 위에 전투 상황에서만 붙는
# 사유([과열]/[마나부족] 등)를 덧붙이는 역할만 남는다
func _card_description(card: Card) -> String:
	return card.get_effect_description()


# 새 손패가 채워진 직후: 5장 전부 회색 뒷면으로 가려두고, 순서대로 DRAW_STAGGER만큼씩 텀을 두고
# 뒤집어 실제 내용을 드러낸다. 연출이 도는 동안은 손패 버튼을 다시 잠가 어떤 카드도 누를 수 없게
# 하고, 마지막 카드의 뒤집기가 끝나면 손패 상태를 다시 계산해 정확한 활성/비활성으로 되돌린다
func _play_draw_animation(cards: Array) -> void:
	for btn in _hand_buttons:
		btn.disabled = true

	if cards.is_empty():
		return

	var last_tween: Tween
	for i in range(cards.size()):
		last_tween = _flip_card_in(i)

	await last_tween.finished
	for i in range(HAND_BUTTON_COUNT):
		_populate_card_slot(i, cards) # 잠가뒀던 버튼 활성 상태를 실제 사용 가능 여부로 되돌림


# 카드 한 장을 "뒷면 -> 앞면" 순서로 뒤집는다. 회전 없이 가로 스케일을 1->0->1로 움직이는 것만으로
# 뒤집는 느낌을 낸다 — 완전히 접힌(스케일 0) 그 순간에 텍스처와 아이콘/이름/설명을 뒷면에서
# 앞면으로 바꿔치기하면, 옆에서 보면 카드가 홱 돌아가며 내용이 드러나는 것처럼 보인다
func _flip_card_in(index: int) -> Tween:
	var wrapper := _card_wrappers[index]
	var frame := _card_frames[index]
	var icon := _card_icons[index]
	var name_label := _card_names[index]
	var desc_label := _card_descs[index]

	# 뒷면일 때는 카드 그림(테두리/배너/아이콘/글자)을 전부 숨겨 종류가 미리 드러나지 않게 한다
	frame.visible = true
	frame.texture = _card_back_texture
	_card_icon_frames[index].visible = false
	_card_name_banners[index].visible = false
	_card_mana_badges[index].visible = false
	_card_mana_labels[index].visible = false
	_card_hp_badges[index].visible = false
	_card_hp_labels[index].visible = false
	_card_flavor_boxes[index].visible = false
	_card_flavor_labels[index].visible = false
	icon.visible = false
	name_label.visible = false
	desc_label.visible = false
	_clear_card_tier_visuals(index) # 뒷면일 때 이전 카드의 티어 광채/파티클이 비쳐 보이면 안 된다
	_reset_card_hover(index) # 이전 손패에서 커져 있던 카드가 있으면 원래 크기/위치에서 뒤집기를 시작하도록

	var tween := create_tween()
	tween.tween_interval(index * DRAW_STAGGER)
	tween.tween_property(wrapper, "scale:x", 0.0, FLIP_HALF_DURATION)
	tween.tween_callback(_reveal_card_face.bind(index))
	tween.tween_property(wrapper, "scale:x", 1.0, FLIP_HALF_DURATION)
	return tween


# 마우스가 카드에 올라오거나 벗어났을 때. 낼 수 없는 카드(과부하/마나부족/빈 칸)나 연출 중에는
# 확대하지 않는다 — 다만 "벗어남"은 어떤 상태에서도 처리해, 확대된 채 커서만 빠져나가 카드가
# 커진 상태로 굳는 일이 없게 한다 (호버 중에 카드가 비활성으로 바뀌는 경우가 실제로 있다)
func _on_card_hover(index: int, hovering: bool) -> void:
	if hovering and (_hand_buttons[index].disabled or not _is_interactive()):
		return
	_tween_card_hover(index, hovering)


func _tween_card_hover(index: int, hovering: bool) -> void:
	var wrapper := _card_wrappers[index]
	var target_pos := _card_base_positions[index]
	if hovering:
		target_pos.y -= HOVER_RISE
	# 확대된 카드가 오른쪽 이웃 카드에 가리지 않도록 위로 띄우는 동안만 z를 올린다
	# (손패는 형제 노드라 기본적으로 뒤쪽 카드가 앞쪽 위에 그려진다)
	wrapper.z_index = 1 if hovering else 0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(wrapper, "scale", Vector2.ONE * (HOVER_SCALE if hovering else 1.0), HOVER_DURATION)
	tween.tween_property(wrapper, "position", target_pos, HOVER_DURATION)


func _wire_banner_button_feedback(button: Button) -> void:
	button.mouse_entered.connect(_on_banner_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_banner_button_hover.bind(button, false))
	button.button_down.connect(_on_banner_button_pressed.bind(button))
	button.button_up.connect(_on_banner_button_released.bind(button))


func _on_banner_button_hover(button: Button, hovering: bool) -> void:
	if button.disabled:
		return
	var target := BANNER_BUTTON_HOVER_MODULATE if hovering else Color.WHITE
	create_tween().tween_property(button, "modulate", target, BANNER_BUTTON_FEEDBACK_DURATION)


func _on_banner_button_pressed(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "modulate", BANNER_BUTTON_PRESS_MODULATE, BANNER_BUTTON_FEEDBACK_DURATION)
	tween.tween_property(button, "scale", Vector2.ONE * BANNER_BUTTON_PRESS_SCALE, BANNER_BUTTON_FEEDBACK_DURATION)


func _on_banner_button_released(button: Button) -> void:
	var target := BANNER_BUTTON_HOVER_MODULATE if button.is_hovered() else Color.WHITE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(button, "modulate", target, BANNER_BUTTON_FEEDBACK_DURATION)
	tween.tween_property(button, "scale", Vector2.ONE, BANNER_BUTTON_FEEDBACK_DURATION)


# 호버 상태를 트윈 없이 즉시 되돌린다. 손패가 새로 깔리거나 칸이 비는 등 "그 카드가 더 이상 아까
# 그 카드가 아닌" 순간에 불러, 확대/떠오름이 다음 카드로 잘못 이어지지 않게 한다
func _reset_card_hover(index: int) -> void:
	var wrapper := _card_wrappers[index]
	wrapper.scale = Vector2.ONE
	wrapper.position = _card_base_positions[index]
	wrapper.z_index = 0


# 뒤집기 중간(스케일 0) 지점에 호출되어 앞면 내용을 채운다. 애니메이션이 도는 짧은 시간 동안은
# 손패 버튼이 전부 잠겨 있어 손패가 바뀌지 않으므로, 지금 손패를 다시 읽어도 안전하다.
# 채우는 내용은 _populate_card_slot과 완전히 같아야 하므로 그 함수를 그대로 재사용한다
func _reveal_card_face(index: int) -> void:
	if _manager == null:
		return
	_populate_card_slot(index, _manager.hand.cards)


# 카드 티어별 시각 연출(상위 티어 광채/파티클). _refresh_hand_buttons()가 손패를 갱신할 때마다
# 카드마다 한 번씩 부르므로, 이 함수만 채우면 손패 전체에 자동으로 반영된다.
#
# [재사용 노드 주의] 손패 5칸은 매 턴 같은 wrapper를 재사용한다 — 상위 티어 카드가 있던 자리에
# 다음 턴 티어1 카드가 들어올 수 있으므로, TIER_1은 그냥 지나치지 않고 반드시 _clear_card_tier_visuals()로
# 광채/파티클/루프 트윈을 전부 꺼야 이전 카드의 연출이 남지 않는다. 같은 이유로 TIER_2/3 분기도
# 시작하자마자 이전에 걸려 있던 루프 트윈부터 죽인다 — 안 그러면 populate가 호출될 때마다(호버 등으로
# 잦다) 트윈이 계속 쌓여 같은 modulate:a 위에서 서로 싸운다
func _apply_card_tier_visuals(i: int, card: Card) -> void:
	if card.tier == Card.CardTier.TIER_1:
		_clear_card_tier_visuals(i)
		return

	var glow := _card_tier_glows[i]
	var sparkles := _card_tier_sparkles[i]
	_kill_tier_glow_tween(i)

	glow.visible = true
	glow.texture = _card_front_textures[_card_style_key(card)]

	var color: Color
	var alpha_min: float
	var alpha_max: float
	var pulse_duration: float
	if card.tier == Card.CardTier.TIER_3:
		color = TIER3_GLOW_COLOR
		alpha_min = TIER3_GLOW_ALPHA_MIN
		alpha_max = TIER3_GLOW_ALPHA_MAX
		pulse_duration = TIER3_GLOW_PULSE_DURATION
		sparkles.emitting = true
	else: # TIER_2
		color = TIER2_GLOW_COLOR
		alpha_min = TIER2_GLOW_ALPHA_MIN
		alpha_max = TIER2_GLOW_ALPHA_MAX
		pulse_duration = TIER2_GLOW_PULSE_DURATION
		sparkles.emitting = false

	glow.modulate = Color(color.r, color.g, color.b, alpha_min)

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(glow, "modulate:a", alpha_max, pulse_duration)
	tween.tween_property(glow, "modulate:a", alpha_min, pulse_duration)
	_card_tier_glow_tweens[i] = tween


# TierGlow/TierSparkles를 완전히 끄고 진행 중이던 루프 트윈도 죽인다. 슬롯이 비었을 때, 카드가
# 뒷면으로 뒤집힐 때, 그리고 TIER_1 카드가 이 자리를 새로 차지했을 때 모두 이 함수로 정리한다
func _clear_card_tier_visuals(i: int) -> void:
	_kill_tier_glow_tween(i)
	_card_tier_glows[i].visible = false
	_card_tier_glows[i].modulate.a = 0.0
	_card_tier_sparkles[i].emitting = false


func _kill_tier_glow_tween(i: int) -> void:
	var tween: Tween = _card_tier_glow_tweens[i]
	if tween != null and tween.is_valid():
		tween.kill()
	_card_tier_glow_tweens[i] = null


func _refresh_weapon_button() -> void:
	if _manager == null:
		return
	_weapon_button.text = tr("무기: %s") % _weapon_name(_manager.weapon.equipped)


# 무기 과열 게이지 바(검/지팡이)와 적 저항 아이콘을 갱신한다. 게이지는 0/25/50/75/100 중 가장 가까운
# 프레임을 골라 표시하고, 저항은 없음(NONE)이면 아이콘 자체를 숨긴다
func _refresh_status_icons() -> void:
	if _manager == null:
		return
	_sword_gauge_rect.texture = _sword_gauge_frames[_gauge_frame_index(_manager.weapon.sword_gauge)]
	_staff_gauge_rect.texture = _staff_gauge_frames[_gauge_frame_index(_manager.weapon.staff_gauge)]

	# 저항 배지는 "없음"일 때도 흐릿하게 항상 띄운다 — 아이콘이 사라졌다 나타났다 하면 플레이어가
	# 저항 상태를 확인하려고 매번 같은 자리를 다시 찾아봐야 하기 때문.
	# 쓰러진 몬스터의 배지는 숨긴다 (시체 위에 배지만 남아 떠 있지 않게)
	for monster in _manager.monsters:
		if monster.index >= _resist_badges.size():
			continue
		var badge := _resist_badges[monster.index]
		if not monster.is_alive():
			badge.visible = false
			continue
		var resistance: int = monster.resistance.current
		badge.texture = _resist_icon_textures.get(resistance)
		badge.modulate = RESIST_BADGE_MODULATE.get(resistance, Color.WHITE)
		badge.visible = badge.texture != null

	_refresh_status_badges()


# 버프/디버프 배지 하나를 만들어 Actors에 붙인다 (Actors 자식이라 화면 흔들림도 함께 따라간다)
func _make_status_badge() -> Label:
	var label := Label.new()
	label.z_index = 12
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", STATUS_BADGE_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.visible = false
	_actors.add_child(label)
	return label


# 플레이어/몬스터에 걸린 상태이상을 각자 위에 짧은 텍스트로 표시한다.
# 걸린 게 없거나 쓰러진 대상은 숨긴다 — 화면에 남아 "아직 걸려 있다"고 오해하게 두지 않으려는 것
func _refresh_status_badges() -> void:
	if _manager == null:
		return

	if _player_status_badge == null:
		_player_status_badge = _make_status_badge()
	_apply_status_badge(_player_status_badge, _manager.player_status, _player_sprite.position, true)

	for monster in _manager.monsters:
		if monster.index >= _status_badges.size():
			continue
		var badge := _status_badges[monster.index]
		if not monster.is_alive():
			badge.visible = false
			continue
		var sprite := _monster_sprite_at(monster.index)
		var foot := sprite.position + Vector2(0, _monster_foot_offset(monster.index))
		_apply_status_badge(badge, monster.status, foot, false)


# 배지 하나에 상태이상 요약을 채운다. 여러 개가 걸려 있으면 줄바꿈으로 쌓아 보여준다
func _apply_status_badge(badge: Label, status: StatusEffects, anchor: Vector2, is_player: bool) -> void:
	if status == null or status.is_empty():
		badge.visible = false
		return

	var lines := status.describe_all()
	badge.text = "
".join(lines)
	# 버프만 걸렸으면 초록, 하나라도 디버프가 있으면 주황 (지금은 종류가 둘뿐이라 이 정도로 충분하다)
	badge.add_theme_color_override("font_color", BUFF_COLOR if status.has(StatusEffects.Kind.ATTACK_UP) else DEBUFF_COLOR)
	badge.visible = true

	# 라벨은 좌상단 기준이라 폭/높이만큼 밀어 중앙 정렬한다.
	# 플레이어는 머리 위(anchor=발 기준이 아니라 몸 중심), 몬스터는 발밑 아래에 띄운다
	badge.reset_size()
	var size := badge.size
	var top := anchor.y - PLAYER_STATUS_BADGE_GAP - size.y if is_player else anchor.y + STATUS_BADGE_GAP
	badge.position = Vector2(anchor.x - size.x * 0.5, top)


# 게이지(0~100, GAUGE_STEP=25 단위)를 프레임 인덱스로 변환. 시트의 프레임 순서는 왼쪽(0번)이 꽉 찬
# 상태고 오른쪽(4번)으로 갈수록 비므로, 게이지가 높을수록(=꽉 찰수록) 더 낮은 인덱스를 골라야 한다
func _gauge_frame_index(gauge: int) -> int:
	var filled_steps := clampi(int(round(float(gauge) / WeaponState.GAUGE_STEP)), 0, GAUGE_FRAME_COUNT - 1)
	return GAUGE_FRAME_COUNT - 1 - filled_steps


func _weapon_name(weapon: int) -> String:
	return tr("검") if weapon == WeaponState.WeaponType.SWORD else tr("지팡이")


# 연출 중에는 모든 조작을 잠근다 (손패 버튼은 _refresh_hand_buttons가 _mode도 함께 반영)
func _set_inputs_enabled(enabled: bool) -> void:
	_weapon_button.disabled = not enabled
	_end_turn_button.disabled = not enabled
	for btn in _hand_buttons:
		if not enabled:
			btn.disabled = true
	if enabled:
		_refresh_hand_buttons()
		_refresh_flee_button()
	else:
		_flee_button.disabled = true


# 현재 HP가 FLEE_HP_THRESHOLD 미만이면 도망가기 버튼을 비활성(회색) 처리
func _refresh_flee_button() -> void:
	if _mode == Mode.BUSY or _mode == Mode.OVER:
		_flee_button.disabled = true
		return
	var hp: int = GameState.get_flag("player_hp")
	var max_hp: int = GameState.get_flag("player_max_hp")
	_flee_button.disabled = hp < max_hp * FLEE_HP_THRESHOLD


func _update_mana_bar() -> void:
	var mana: int = GameState.get_flag("player_mana")
	var max_mana: int = GameState.get_flag("player_max_mana")
	_player_mana_bar.max_value = max_mana
	_player_mana_bar.value = mana
	_player_mana_bar_label.text = "Mana: %d/%d" % [mana, max_mana]


# 플레이어 HP바 위에 겹친 숫자 텍스트를 GameState 값으로 갱신
func _update_player_hp_text() -> void:
	_player_hp_bar_label.text = "HP: %d/%d" % [GameState.get_flag("player_hp"), GameState.get_flag("player_max_hp")]


# 마리별 HP바 숫자 텍스트를 매니저가 들고 있는 현재 전투 상태로 갱신
func _update_monster_hp_text() -> void:
	if _manager == null:
		return
	for monster in _manager.monsters:
		if monster.index < _monster_hp_labels.size():
			_monster_hp_labels[monster.index].text = "HP: %d/%d" % [monster.hp, monster.max_hp]


# 마리별 HP바를 현재 값으로 트윈시킨다 (숫자 텍스트도 함께 맞춘다).
# 컷신들이 0번 몬스터의 바를 직접 건드리는 것과 별개로, 공통 갱신 경로는 이쪽 하나로 모은다
func _refresh_monster_hp_bars() -> void:
	if _manager == null:
		return
	for monster in _manager.monsters:
		if monster.index < _monster_hp_bars.size():
			_animate_hp_bar(_monster_hp_bars[monster.index], monster.hp)
	_update_monster_hp_text()


# ── 승리 / 패배 ────────────────────────────────────────────────────────────

# 승리 처리: 처치 카운트 증가 + 골드 드롭 + 소량 회복(HP만), "닫기" 버튼으로 복귀 대기.
# (승패 판정 자체는 매니저가 하고, 이 함수는 전투 "바깥"의 보상 처리만 담당한다)
func _finish_victory() -> void:
	_mode = Mode.OVER

	# 아직 사망 연출이 남은 마리들을 먼저 정리한다 (마지막 한 마리는 방금 쓰러졌으므로 여기 포함된다).
	# 이미 연출이 끝난 마리는 _pending_deaths에서 빠져 있어 두 번 재생되지 않는다
	for badge in _resist_badges:
		badge.visible = false # 쓰러진 몬스터 위에 저항 배지만 남아 떠 있지 않게
	await _play_pending_deaths()

	MusicManager.play("Victory!")

	# 보상은 마리별로 각각 굴린다 — 골드도 장비 드롭도 퀘스트 카운터도 "한 마리당 한 번"이라,
	# 3마리를 잡으면 3번의 드롭 기회와 3의 퀘스트 진행이 생긴다. 여러 마리를 상대하는 위험이
	# 보상으로 되돌아오지 않으면 다인전은 그냥 손해이기 때문.
	#
	# [지급 시점] 마리가 쓰러지는 즉시가 아니라 승리한 뒤에 몰아서 준다. 도중에 주면 2마리를 잡고
	# 도망쳐도 보상이 남아, 도망(골드 소모 + HP 게이팅)이 오히려 이득인 상황이 생긴다 —
	# "전투를 끝내야 보상"이라는 기존 규칙을 그대로 유지하는 쪽을 택했다
	var total_gold := 0
	var total_xp := 0
	var dropped_items: Array[String] = []
	var defeated_count := 0
	for monster in _manager.monsters:
		if monster.is_alive() or monster.rewarded:
			continue
		monster.rewarded = true
		defeated_count += 1
		_increment_defeat_counter()
		total_gold += randi_range(monster.monster_data["gold_min"], monster.monster_data["gold_max"])
		total_xp += int(monster.monster_data.get("xp", 0))
		var dropped := _roll_equipment_drop()
		if dropped != "":
			dropped_items.append(dropped)

	GameState.add_gold(total_gold)
	_player_gold_label.text = str(GameState.gold)

	# 경험치는 마리별로 더한 총합을 한 번에 준다 — add_xp()가 필요치를 넘긴 만큼 레벨을 올려주므로
	# 여러 마리를 잡아 한 번에 두 레벨이 오르는 경우도 여기서 따로 처리할 게 없다.
	# 레벨업 안내창은 전투 중에 끼어들지 않고, 전투를 빠져나온 뒤 LevelUpPopup이 알아서 띄운다
	GameState.add_xp(total_xp)

	GameState.heal_player_partial(VICTORY_HEAL_FRACTION)
	_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
	_update_player_hp_text()
	_update_mana_bar()

	var defeated_label: String = tr(_monster_data["name"])
	if defeated_count > 1:
		defeated_label = tr("%s %d마리") % [tr(_monster_data["name"]), defeated_count]
	_message.text = tr("%s 처치!\n골드 %d · 경험치 %d 획득!\n체력을 약간 회복했다.") % [defeated_label, total_gold, total_xp]
	for item_id in dropped_items:
		_message.text += tr("\n%s을(를) 얻었다!") % ItemData.ITEMS[item_id]["name"]

	_main_column.visible = false
	_close_button.visible = true


# 몬스터 종류별 처치 카운터를 1 올린다 (퀘스트 진행/보스 플래그). 마리마다 한 번씩 호출된다 —
# 다인전에서 3마리를 잡으면 퀘스트도 3만큼 나아가야 "여러 마리를 상대한 값"이 되기 때문
func _increment_defeat_counter() -> void:
	GameState.add_sub_quest_progress(_monster_type)
	match _monster_type:
		"ORC":
			GameState.increment_orcs_defeated()
		"SKELETON":
			GameState.increment_skeletons_defeated()
		"MUMMY":
			GameState.increment_mummies_defeated()
		"RUINS_BOSS":
			GameState.set_flag("ruins_boss_defeated", true)


# 이 몬스터의 등급(BattleData.MONSTERS의 equipment_tier)에 해당하는 장비를 확률로 하나 떨군다.
# 등급이 없는 몬스터거나 꽝이면 빈 문자열을 반환하고 아무것도 주지 않는다 (골드만 받는다)
func _roll_equipment_drop() -> String:
	var tier: String = _monster_data.get("equipment_tier", "")
	if tier == "":
		return ""
	if randf() >= EQUIPMENT_DROP_CHANCE:
		return ""

	var item_id := ItemData.pick_random_equipment(tier)
	if item_id == "":
		return ""

	GameState.add_item(item_id, 1)
	return item_id


# 패배 처리: 플레이어 노드를 다시 보이게 하고 게임오버 화면으로 넘긴다 (회복/복귀는 게임오버 화면이 담당)
func _finish_defeat() -> void:
	_mode = Mode.OVER
	for badge in _resist_badges:
		badge.visible = false
	_main_column.visible = false
	_message.text = tr("정신을 잃었다...")
	SceneManager.reveal_player()
	GameOverScreen.show_game_over()


# [닫기]: 승리 후 원래 씬의 정확한 좌표로 복귀 (SceneManager가 처리)
func _on_close_pressed() -> void:
	if _mode != Mode.OVER:
		return
	_mode = Mode.BUSY
	SceneManager.return_from_battle()


# ── 스프라이트 구성 / 연출 헬퍼 (기존 로직 그대로) ─────────────────────────

# 플레이어(뒷모습=Idle_Up)는 정적 Idle 프레임을, 몬스터는 "idle"/"death" 두 애니메이션을 갖춘
# SpriteFrames를 필드와 같은 변종(_variant)의 시트에서 구성해 AnimatedSprite2D에 채우고,
# 카드에 쓸 초상화(얼굴만 크롭한 AtlasTexture)도 함께 준비한다
# 마리 수만큼 스프라이트/그림자/저항배지/HUD 카드를 준비한다. 0번은 .tscn에 원래 있던 노드를 그대로
# 재사용하고, 1번부터는 그 노드를 duplicate()해서 형제로 붙인다 — 이렇게 하면 .tscn을 건드리지 않고도
# 마리 수가 늘어난다
func _setup_sprites() -> void:
	_player_sprite.sprite_frames = _build_frames(load(PLAYER_SPRITE_PATH) as Texture2D, PLAYER_FRAME_SIZE)
	_player_sprite.scale = Vector2.ONE * PLAYER_SCALE
	_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_sprite.play("default")
	_player_portrait.texture = _build_portrait(load(PLAYER_PORTRAIT_SHEET_PATH) as Texture2D, PLAYER_PORTRAIT_REGION)

	_monster_sprites.clear()
	_monster_shadows.clear()
	for badge in _status_badges:
		if is_instance_valid(badge):
			badge.queue_free()
	_status_badges.clear()
	_resist_badges.clear()
	_monster_card_panels.clear()
	_monster_hp_bars.clear()
	_monster_hp_labels.clear()
	_monster_art_tops.clear()

	for i in range(_variants.size()):
		var variant: Dictionary = _variants[i]
		var sprite := _monster_sprite if i == 0 else _clone_sibling(_monster_sprite) as AnimatedSprite2D
		var shadow := _monster_shadow if i == 0 else _clone_sibling(_monster_shadow) as Polygon2D
		var badge := _resist_badge if i == 0 else _clone_sibling(_resist_badge) as Sprite2D
		var card := _monster_card if i == 0 else _clone_sibling(_monster_card) as Control

		var idle_sheet := load(variant["idle_path"]) as Texture2D
		var idle_frame_size: int = variant.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)

		var monster_frames := SpriteFrames.new()
		if monster_frames.has_animation("default"):
			monster_frames.remove_animation("default")
		_add_monster_animation(monster_frames, "idle", idle_sheet, idle_frame_size, idle_frame_size, variant.get("idle_frame_count", BattleData.MOB_IDLE_FRAME_COUNT), MONSTER_IDLE_FPS, true)
		_add_monster_animation(monster_frames, "death", load(variant["death_path"]) as Texture2D, variant["death_frame_width"], variant["death_frame_height"], variant["death_frame_count"], MONSTER_DEATH_FPS, false)

		sprite.sprite_frames = monster_frames
		sprite.scale = Vector2.ONE * MONSTER_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.flip_h = true # 왼쪽의 플레이어를 바라보도록
		sprite.offset = Vector2.ZERO # duplicate()로 복제된 노드가 이전 사망 보정을 물려받지 않게
		sprite.modulate = Color.WHITE
		sprite.play("idle")

		(card.get_node("Portrait") as TextureRect).texture = _build_portrait(idle_sheet, _monster_data["portrait_region"])
		(card.get_node("GoldLabel") as Label).text = "%d~%d" % [_monster_data["gold_min"], _monster_data["gold_max"]]
		card.modulate = Color.WHITE
		_ensure_mana_bar(card)

		_monster_sprites.append(sprite)
		_monster_shadows.append(shadow)
		_resist_badges.append(badge)
		_monster_card_panels.append(card)
		_monster_hp_bars.append(card.get_node("HPBar") as ProgressBar)
		_monster_hp_labels.append(card.get_node("HPBarLabel") as Label)
		_monster_mana_bars.append(card.get_node("ManaBar") as ProgressBar)
		_monster_art_tops.append(_measure_art_top_offset(idle_sheet, idle_frame_size))
		_status_badges.append(_make_status_badge())


# 노드를 복제해 같은 부모에 붙인다 (같은 씬 트리 위치 = 같은 z 순서/좌표계를 공유하도록).
# 마리 수가 늘어난 만큼만 호출되므로 0번 원본은 그대로 남는다
func _clone_sibling(source: Node) -> Node:
	var clone := source.duplicate()
	source.get_parent().add_child(clone)
	return clone


# HUD 카드에 몬스터 마나바가 없으면 만들어 붙인다. 이미 있으면(복제로 딸려온 경우) 그대로 둔다 —
# 0번 카드에 붙인 뒤 duplicate()하면 사본에도 이미 들어 있기 때문에 중복 생성을 막아야 한다
func _ensure_mana_bar(card: Control) -> void:
	if card.has_node("ManaBar"):
		return

	var bg := StyleBoxFlat.new()
	bg.bg_color = MONSTER_MANA_BAR_BG
	bg.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = MONSTER_MANA_BAR_FILL
	fill.set_corner_radius_all(2)

	var bar := ProgressBar.new()
	bar.name = "ManaBar"
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.position = MONSTER_MANA_BAR_RECT.position
	bar.size = MONSTER_MANA_BAR_RECT.size
	bar.max_value = MonsterState.MANA_MAX
	bar.value = MonsterState.MANA_MAX
	card.add_child(bar)


# 화면 가장자리만 붉게 물드는 오버레이를 만들어 View에 붙인다 (가운데는 투명).
# HitFlash처럼 알파만 트윈하면 되도록 TextureRect 하나로 만들어 두고 재사용한다
func _build_edge_flash() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, EDGE_FLASH_INNER_STOP, 1.0])
	gradient.colors = PackedColorArray([
		Color(EDGE_FLASH_COLOR.r, EDGE_FLASH_COLOR.g, EDGE_FLASH_COLOR.b, 0.0),
		Color(EDGE_FLASH_COLOR.r, EDGE_FLASH_COLOR.g, EDGE_FLASH_COLOR.b, 0.0),
		EDGE_FLASH_COLOR,
	])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5) # 중심에서 오른쪽 끝까지가 반지름 1.0
	texture.width = 256
	texture.height = 256

	_edge_flash = TextureRect.new()
	_edge_flash.name = "EdgeFlash"
	_edge_flash.texture = texture
	_edge_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_edge_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_edge_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge_flash.modulate = Color(1, 1, 1, 0)
	_edge_flash.z_index = 20 # 배우/이펙트 위, 손패 UI 아래
	_view.add_child(_edge_flash)


# 가장자리를 붉게 확 물들였다가 서서히 걷는다 (플레이어가 실제로 피해를 입은 순간에만 호출)
func _play_edge_flash() -> void:
	if _edge_flash == null:
		return
	var tween := create_tween()
	tween.tween_property(_edge_flash, "modulate:a", EDGE_FLASH_ALPHA, EDGE_FLASH_IN_DURATION)
	tween.tween_property(_edge_flash, "modulate:a", 0.0, EDGE_FLASH_OUT_DURATION)


# 64px 프레임이 가로로 FRAME_COUNT개 나열된 Idle 시트를 SpriteFrames로 변환 (플레이어 전용, 애니메이션 이름 "default")
func _build_frames(sheet: Texture2D, frame_size: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", IDLE_FPS)
	for i in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame("default", atlas)
	return frames


# sheet를 frame_w x frame_h 프레임 frame_count개로 잘라 frames에 anim_name 애니메이션으로 등록 (몬스터 전용)
func _add_monster_animation(frames: SpriteFrames, anim_name: String, sheet: Texture2D, frame_w: int, frame_h: int, frame_count: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)


# 시트 첫 프레임에서 실제 그림이 시작되는 y를 잰다 (위쪽 투명 여백의 높이).
# 스프라이트는 프레임 안에서 대개 아래쪽에 그려져 있어, 프레임 상단을 기준으로 뭔가를 붙이면
# 그 여백만큼 떠 보인다 — 그걸 보정하기 위한 값
func _measure_art_top_offset(sheet: Texture2D, frame_size: int) -> float:
	var img := sheet.get_image()
	var w: int = min(frame_size, img.get_width())
	var h: int = min(frame_size, img.get_height())
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.04:
				return float(y)
	return 0.0


# 시트에서 region 영역만 잘라 카드 초상화용 AtlasTexture로 만듦
func _build_portrait(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas


# 뷰포트 크기에 비례해 배우 위치를 잡고(해상도 독립), 각 발밑에 타원 그림자를 그린다
func _layout_actors() -> void:
	# 하단 UI가 차지하는 영역(flavor_text 박스 추가로 카드가 더 길어져 295px까지 올라옴)에 발이
	# 가리지 않도록 배우를 위쪽으로 배치한다. 나무 판자 배경이 사라져 UI가 배경 위에 떠 있으므로,
	# 겹치면 바로 티가 난다
	var vp := get_viewport().get_visible_rect().size
	_player_sprite.position = Vector2(vp.x * 0.22, vp.y * 0.40)

	# 그림자는 "프레임 아래쪽"이 아니라 실제로 잰 발 위치에 맞춘다 (PLAYER_FOOT_FROM_CENTER 주석 참고).
	# 크기도 캐릭터 실제 폭에 비례시켜, 스케일을 바꿔도 그림자가 따로 놀지 않게 한다
	var player_foot := _player_sprite.position + Vector2(0, PLAYER_FOOT_FROM_CENTER * PLAYER_SCALE)
	var player_shadow_rx := PLAYER_BODY_WIDTH * PLAYER_SCALE * 0.62
	_setup_shadow(_player_shadow, player_foot, player_shadow_rx, player_shadow_rx * 0.3)

	_layout_monsters(vp)


# 몬스터들을 오른쪽에 가로로 나란히 세우고, 각자의 그림자/저항배지/HUD 카드를 그 자리에 맞춘다.
#
# [배치 규칙] 오른쪽 끝을 기준으로 왼쪽으로 쌓는다. 오른쪽 한계는 HUD 몬스터 카드 열을 침범하지
# 않는 선이고, 간격은 상수가 아니라 "실제 스프라이트 폭 + 여백"으로 계산한다 — 몬스터 종류마다
# idle 프레임 크기가 32(오크/스켈레톤)와 64(미라)로 두 배 차이라, 고정 간격을 쓰면 한쪽은 뜨고
# 다른 쪽은 겹친다.
#
# 3마리 + 큰 몬스터(미라)일 때는 화면이 꽤 빡빡한데, 정교한 구도(원근 배치/크기 차등 등)는
# 타겟팅 UI와 함께 다음 단계에서 다듬을 예정이라 지금은 "겹치지 않게 세운다"까지만 한다
func _layout_monsters(vp: Vector2) -> void:
	var count := _monster_sprites.size()
	if count == 0:
		return

	var right_limit := vp.x - MONSTER_CARD_WIDTH - MONSTER_CARD_MARGIN
	var widest := 0.0
	for i in range(count):
		var frame_size: float = _variants[i].get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
		widest = maxf(widest, frame_size * MONSTER_SCALE)
	var spacing := widest + MONSTER_GAP

	for i in range(count):
		var sprite := _monster_sprites[i]
		var frame_size: float = _variants[i].get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
		var half_width := frame_size * MONSTER_SCALE * 0.5
		# 마지막 마리가 오른쪽 한계에 붙고, 앞쪽 마리들이 왼쪽으로 spacing씩 물러난다
		var x := right_limit - half_width - spacing * (count - 1 - i)
		sprite.position = Vector2(x, vp.y * MONSTER_ROW_Y_FRACTION)

		var foot := sprite.position + Vector2(0, frame_size * MONSTER_SCALE * 0.5 - 4.0)
		_setup_shadow(_monster_shadows[i], foot, 40.0, 12.0)

		# 적 저항 배지를 몬스터 머리 위에 띄운다. Actors의 자식이라 피격 흔들림도 몬스터와 함께 따라간다.
		# 기준은 프레임 위쪽이 아니라 "실제로 그림이 시작되는 y"다 — 몬스터마다 프레임 안 여백이 제각각이라
		# 프레임 기준으로 잡으면 배지가 머리에서 한참 떨어져 허공에 뜬다 (플레이어 그림자와 같은 이유)
		var art_top := sprite.position.y - frame_size * MONSTER_SCALE * 0.5 + _monster_art_tops[i] * MONSTER_SCALE
		_resist_badges[i].position = Vector2(sprite.position.x, art_top - RESIST_BADGE_GAP)

		# HUD 카드는 오른쪽 위에 세로로 쌓는다 (0번이 맨 위 = 스프라이트 왼쪽부터가 아니라 자리 순서 그대로)
		var card := _monster_card_panels[i]
		card.offset_top = MONSTER_CARD_TOP + i * (MONSTER_CARD_HEIGHT + MONSTER_CARD_GAP)
		card.offset_bottom = card.offset_top + MONSTER_CARD_HEIGHT


# 타원형 그림자 폴리곤(반지름 rx*ry)을 만들어 지정 위치에 배치
func _setup_shadow(shadow: Polygon2D, center: Vector2, rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	shadow.polygon = pts
	shadow.position = center


# index 자리의 몬스터 스프라이트. 범위를 벗어나면 0번으로 떨어뜨려, 어떤 경우에도 null을 반환하지 않는다
# (연출 코드가 매번 null 검사를 하지 않아도 되도록)
func _monster_sprite_at(index: int) -> AnimatedSprite2D:
	if index < 0 or index >= _monster_sprites.size():
		return _monster_sprite
	return _monster_sprites[index]


# ── 마리별 조회 헬퍼 ────────────────────────────────────────────────────────
# 컷신들이 "0번 몬스터"를 직접 참조하는 대신 이 함수들로 대상을 짚는다. 전부 범위를 벗어나도
# 0번 값으로 떨어지므로, 호출부가 매번 null/범위 검사를 하지 않아도 된다

# index 몬스터의 idle 프레임 크기 (원본 픽셀). 변종마다 32/64로 달라서 정렬 계산에 반드시 필요하다
func _monster_frame_size(index: int) -> float:
	if index < 0 or index >= _variants.size():
		return _variant.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
	return _variants[index].get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)


# index 몬스터의 화면상 반폭 (정렬/거리 계산의 기준)
func _monster_half_width(index: int) -> float:
	return _monster_frame_size(index) * MONSTER_SCALE * 0.5


# index 몬스터의 발 위치까지의 세로 오프셋 (스프라이트 중심 기준)
func _monster_foot_offset(index: int) -> float:
	return _monster_frame_size(index) * MONSTER_SCALE * 0.5 - 4.0


# index 몬스터의 현재 체력 / 최대 체력 (매니저가 들고 있는 실제 값)
func _monster_hp_of(index: int) -> int:
	if _manager == null:
		return 0
	var monster := _manager.get_monster(index)
	return monster.hp if monster != null else 0


func _monster_max_hp_of(index: int) -> int:
	if _manager != null:
		var monster := _manager.get_monster(index)
		if monster != null:
			return monster.max_hp
	return _monster_data["max_hp"]


# index 몬스터의 HP바를 hp까지 트윈하고 숫자도 함께 맞춘다.
# 여러 번 나눠 때리는 컷신(삼중나선/신속)이 중간 단계 수치를 보여줄 때 쓰므로, 매니저의 실제 값이
# 아니라 "지금 보여줄 값"을 받는다 — 최종 동기화는 컷신 끝에서 _update_monster_hp_text()가 한다
# index 몬스터가 이번 카드로 실제로 잃은 체력. 시전 직전 기록해 둔 값과 지금 값의 차이라
# 오버킬이어도(카드 수치보다 적게 깎임) 화면에 뜨는 숫자가 HP바 감소폭과 정확히 일치한다
# 이번 카드가 겨냥한 대상들의 한가운데 좌표. 광역 연출이 "무리 전체를 덮는" 기준점으로 쓴다
# (대상이 하나면 그 몬스터 위치와 같아져, 1:1 전투에서는 기존 연출과 완전히 동일해진다)
func _targets_center() -> Vector2:
	if _card_targets.is_empty():
		return _monster_sprite.position
	var sum := Vector2.ZERO
	for index in _card_targets:
		sum += _monster_sprite_at(index).position
	return sum / float(_card_targets.size())


func _damage_dealt_to(index: int) -> int:
	if not _hp_before_by_index.has(index):
		return 0
	return int(_hp_before_by_index[index]) - _monster_hp_of(index)


# 이번 카드가 겨냥한 대상들 위에 각자의 피해 숫자를 띄우고 HP바를 갱신한다.
# 광역기면 여러 마리 위에 동시에 뜨고, 단일 대상이면 한 마리 위에만 뜬다 —
# 호출부가 광역인지 아닌지 몰라도 되도록 이 한 함수로 합쳤다.
# 피해가 0인 대상은 숫자를 생략한다 (기존 "-0" 방지 규칙과 동일)
func _show_damage_popups_on_targets() -> void:
	for index in _card_targets:
		var dealt := _damage_dealt_to(index)
		if dealt > 0:
			_show_popup(_monster_sprite_at(index).position, "-%d" % dealt, DAMAGE_COLOR)
		_set_monster_hp_display(index, _monster_hp_of(index))
	_update_monster_hp_text()


# 이번 카드가 "빗나간" 것인지 — 빗나갈 수 있는 성질을 가진 카드인데 피해가 하나도 안 들어간 경우.
# 성질 표에 문구가 있는 카드만 해당되므로, 보통 피해 카드가 저항으로 0이 나오는 경우와는 섞이지 않는다
func _is_whiff(card: Card) -> bool:
	if DamageTraits.get_whiff_text(card.damage_trait) == "":
		return false
	return _total_damage_dealt() <= 0


# 흡혈/마력흡수가 실제로 가져온 것을 플레이어 쪽에 보여준다. 매니저가 남긴 값은 이미 "실제로 오간 양"
# (대상이 가진 만큼만, 플레이어 최대치에서 잘린 뒤)이라 그대로 띄우면 자원 표시와 어긋나지 않는다.
# 아무것도 안 가져온 카드는 조용히 지나간다 — 성질이 없는 카드도 이 함수를 그냥 통과한다
func _play_damage_trait_feedback() -> void:
	var result: Dictionary = _manager.last_trait_result
	var stolen: int = int(result.get("mana_stolen", 0))
	var leeched: int = int(result.get("hp_leeched", 0))

	if stolen > 0:
		_spawn_vfx_sprite("mana", _player_sprite.position)
		_show_popup(_player_sprite.position, "+%d MP" % stolen, MANA_COLOR)
		_message.text += tr("  (마나 %d 흡수)") % stolen
	if leeched > 0:
		_spawn_vfx_sprite("heal", _player_sprite.position)
		_show_popup(_player_sprite.position, "+%d" % leeched, HEAL_COLOR)
		_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
		_message.text += tr("  (체력 %d 회복)") % leeched


# 이번 카드가 대상들에게 입힌 피해의 합 (메시지에 쓸 총계)
func _total_damage_dealt() -> int:
	var total := 0
	for index in _card_targets:
		total += _damage_dealt_to(index)
	return total


# 피해 결과 메시지. 여러 마리를 때린 광역기면 "N마리에게 총 M 피해"로 적어
# 한 마리 숫자와 헷갈리지 않게 한다
func _damage_result_message(card: Card) -> String:
	var total := _total_damage_dealt()
	# 도박의 일격처럼 "빗나갈 수 있는" 카드는 0 피해가 실패를 뜻하므로 숫자 대신 그 사실을 적는다.
	# "도박의 일격! 0 피해!"는 카드가 씹힌 것처럼 읽힌다
	if _is_whiff(card):
		return tr("%s — %s") % [tr(card.card_name), DamageTraits.get_whiff_text(card.damage_trait)]
	if _card_targets.size() > 1:
		return tr("%s! %d마리에게 총 %d 피해!") % [tr(card.card_name), _card_targets.size(), total]
	return tr("%s! %d 피해!") % [tr(card.card_name), total]


func _set_monster_hp_display(index: int, hp: int) -> void:
	if index < 0 or index >= _monster_hp_bars.size():
		return
	_animate_hp_bar(_monster_hp_bars[index], hp)
	_monster_hp_labels[index].text = "HP: %d/%d" % [hp, _monster_max_hp_of(index)]


# 몬스터가 쓰러졌을 때, 사라지기 전에 Death 애니메이션을 한 번(루프 없이) 재생하고 끝날 때까지 기다림.
# Death 캔버스는 변종마다 크기가 달라도 캐릭터의 실제 픽셀 크기는 Idle과 비슷해서, scale은 그대로 두면
# 된다. 대신 AnimatedSprite2D가 기본 centered라 캔버스가 더 큰 변종일수록 발이 아래로 밀려 캐릭터가
# 순간 가라앉아 보이므로, offset으로 캔버스 높이 차의 절반만큼 위로 당겨 보정한다
func _play_monster_death(index: int = 0) -> void:
	var sprite := _monster_sprite_at(index)
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation("death"):
		return

	var variant: Dictionary = _variants[index] if index < _variants.size() else _variant
	var idle_h: float = variant.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
	var death_h: float = variant.get("death_frame_height", idle_h)
	sprite.offset = Vector2(0, -(death_h - idle_h) / 2.0)
	sprite.play("death")
	await sprite.animation_finished


# 아직 사망 연출을 재생하지 않은 몬스터들을 처리한다 (전투가 계속되는 도중에 일부만 쓰러진 경우).
# 연출이 끝나면 스프라이트/그림자는 그 자리에 쓰러진 채 남기고, HUD 카드는 흐리게 죽여 "이미 정리된
# 상대"임을 알린다 — 카드를 아예 지우면 남은 몬스터들의 카드가 위로 밀려 올라가 자리 번호와
# 화면 순서가 어긋나 보인다
func _play_pending_deaths() -> void:
	if _pending_deaths.is_empty():
		return
	var dying := _pending_deaths.duplicate()
	_pending_deaths.clear()

	for index in dying:
		if index < _resist_badges.size():
			_resist_badges[index].visible = false
		await _play_monster_death(index)
		if index < _monster_card_panels.size():
			_monster_card_panels[index].modulate = DEFEATED_CARD_MODULATE
		if index < _monster_shadows.size():
			_monster_shadows[index].visible = false


# HP바를 목표값까지 부드럽게 트윈
func _animate_hp_bar(bar: ProgressBar, target_value: float) -> void:
	var tween := create_tween()
	tween.tween_property(bar, "value", target_value, HP_TWEEN_DURATION)


# 맞은 스프라이트를 빨갛게 틴트했다가 원래 색으로 되돌림
func _flash_hit(sprite: CanvasItem) -> void:
	sprite.modulate = HIT_TINT
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, HIT_TINT_DURATION)


# 섬광 전용 "차징" 연출: 달려들기 직전에 노랗게 번쩍였다가 원래 색으로 돌아온다 (완료까지 await)
func _flash_charge(sprite: CanvasItem) -> void:
	sprite.modulate = FLASH_SLASH_CHARGE_TINT
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, FLASH_SLASH_CHARGE_DURATION)
	await tween.finished


# 섬광 전용: sprite가 start에서 end까지 실제로 이동하는 돌진 경로 위에 반투명 스프라이트
# 복제본을 늘어놓는다. 개수는 고정하지 않고 이동 거리에 비례시켜(DASH_AFTERIMAGE_TARGET_SPACING당
# 한 장꼴) 몬스터가 가깝든 멀든 트레일 밀도가 비슷하게 유지되게 한다. end 쪽(가장 최근 위치)이
# 가장 진하고 start 쪽(가장 오래된 위치)으로 갈수록 옅어져 "과거로 흐려지는" 느낌을 낸다.
# 돌진 트윈과 병렬로(await 없이) 호출되므로 스스로도 await를 쓰는 코루틴이지만 호출부는 기다리지
# 않는다 — 각 잔상은 스스로 사라진다
func _spawn_dash_afterimages(sprite: AnimatedSprite2D, start: Vector2, end: Vector2, tint: Color) -> void:
	var distance := start.distance_to(end)
	if distance < 1.0:
		return
	var count := clampi(int(round(distance / DASH_AFTERIMAGE_TARGET_SPACING)), DASH_AFTERIMAGE_MIN_COUNT, DASH_AFTERIMAGE_MAX_COUNT)
	var frame_tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)

	for i in range(count):
		var t := float(i + 1) / (count + 1)
		var ghost := Sprite2D.new()
		ghost.texture = frame_tex
		ghost.position = start.lerp(end, t)
		ghost.scale = sprite.scale
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.modulate = Color(tint.r, tint.g, tint.b, DASH_AFTERIMAGE_ALPHA * t)
		_actors.add_child(ghost)
		var tween := create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, DASH_AFTERIMAGE_FADE_DURATION)
		tween.tween_callback(ghost.queue_free)
		await _wait(DASH_AFTERIMAGE_STAGGER)


# 섬광 전용: start에서 monster_pos 방향으로, 두 스프라이트 테두리가 FLASH_SLASH_HIT_GAP만큼
# 떨어지는 지점을 계산한다. 몬스터 폭은 변종마다 프레임 크기가 달라 대상의 변종에서 직접 읽는다
# (_layout_monsters()의 몬스터 발 위치 계산과 같은 방식).
# target_index는 그 폭을 어느 몬스터 기준으로 잴지 정한다 — 다인전에서 옆 몬스터의 크기로 재면
# 캐릭터가 대상에 파묻히거나 멀찍이 떨어져 선다
func _flash_slash_dash_target(start: Vector2, monster_pos: Vector2, target_index: int = 0) -> Vector2:
	var offset := monster_pos - start
	var distance := offset.length()
	if distance < 1.0:
		return start
	var direction := offset / distance
	var player_half_width := PLAYER_BODY_WIDTH * PLAYER_SCALE * 0.5
	var stop_distance: float = clamp(distance - _monster_half_width(target_index) - player_half_width - FLASH_SLASH_HIT_GAP, 0.0, distance)
	return start + direction * stop_distance


# 화면 전체를 color로 아주 짧게 번쩍였다가 투명하게 되돌린다 (풀스크린 히트 플래시)
func _screen_flash(color: Color, duration: float) -> void:
	_hit_flash.color = Color(color.r, color.g, color.b, 0.55)
	var tween := create_tween()
	tween.tween_property(_hit_flash, "color:a", 0.0, duration)


# 삼중나선 전용 3연타 컷신. 세트마다: 화면이 완전히 덮일 때까지 번쩍 → (가려진 프레임에) 캐릭터를
# 몬스터 앞/뒤로 순간이동 → 화면이 걷히며 이미 새 위치에서 베는 이펙트 재생 → 흔들림 → 피해 일부
# 표시. 3세트가 끝나면 원래 자리로 짧게 돌아온다.
#
# 데미지 표시는 card.value가 아니라 (호출부가 넘겨준) monster_hp_before와 대상의 현재 HP의
# 실제 차이를 3등분한다 — 마지막 한 방으로 몬스터를 잡으면 실제로 깎인 체력이 카드 수치보다 작을
# 수 있는데(HP가 음수로 안 내려가게 클램프되므로), card.value를 그대로 쓰면 표시된 피해 합이
# HP바가 실제로 줄어든 양과 안 맞아 숫자가 어긋나 보인다
func _play_triple_helix_cutscene(card: Card, monster_hp_before: int, target_index: int) -> void:
	var target_sprite := _monster_sprite_at(target_index)
	var start_pos := _player_sprite.position
	var monster_pos := target_sprite.position
	var offset := monster_pos - start_pos
	var distance := offset.length()
	var direction := offset / distance if distance > 1.0 else Vector2.RIGHT

	var front_pos := _flash_slash_dash_target(start_pos, monster_pos, target_index) # 몬스터 코앞
	var back_pos := monster_pos + direction * (_monster_half_width(target_index) + TRIPLE_HELIX_HIT_GAP) # 몬스터 등 뒤
	var hit_positions := [front_pos, back_pos, front_pos] # 앞→뒤→앞으로 번갈아 "휙휙" 도는 느낌

	var total_damage := monster_hp_before - _monster_hp_of(target_index)
	var hit_damages := _split_damage(total_damage, 3)

	var hp_step := monster_hp_before
	_message.text = "%s!" % tr(card.card_name)

	for i in range(3):
		_hit_flash.color = Color(TRIPLE_HELIX_TINT.r, TRIPLE_HELIX_TINT.g, TRIPLE_HELIX_TINT.b, 0.0)
		var flash_in := create_tween()
		flash_in.tween_property(_hit_flash, "color:a", TRIPLE_HELIX_FLASH_ALPHA, TRIPLE_HELIX_FLASH_IN_DURATION)
		await flash_in.finished

		# 화면이 가려진 바로 그 프레임에 좌표만 즉시 바꾼다 — 이동 트윈이 없어 "번쩍하고 나니
		# 이미 가 있는" 순간이동처럼 보인다
		_player_sprite.position = hit_positions[i]

		var flash_out := create_tween()
		flash_out.tween_property(_hit_flash, "color:a", 0.0, TRIPLE_HELIX_FLASH_OUT_DURATION)

		_shake_actors()
		_flash_hit(target_sprite)
		_spawn_vfx_sprite("physical", target_sprite.position)
		SFXPlayer.play(TRIPLE_HELIX_HIT_SFX[i])

		hp_step -= hit_damages[i]
		if hit_damages[i] > 0: # 신속과 같은 이유 — 몫이 0인 타격에 "-0"을 띄우지 않는다
			_show_popup(target_sprite.position, "-%d" % hit_damages[i], DAMAGE_COLOR)
		_set_monster_hp_display(target_index, hp_step)

		await flash_out.finished
		await _wait(TRIPLE_HELIX_SET_GAP)

	var return_tween := create_tween()
	return_tween.tween_property(_player_sprite, "position", start_pos, TRIPLE_HELIX_RETURN_DURATION)
	await return_tween.finished

	_update_monster_hp_text() # 실제 소유자(매니저) 값과 최종적으로 다시 맞춰둔다
	_message.text = tr("%s! %d 피해!") % [tr(card.card_name), total_damage]
	await _wait(0.2)


# 여러 번 나눠 때리는 컷신에서 총 피해를 타격 수만큼 쪼갠다.
# 나머지는 뒤쪽 타격에 한 대씩 얹어 합계가 정확히 total이 되게 하면서도(팝업 합계 = HP바 감소량),
# 한 방에 몰아주지 않아 숫자가 고르게 보인다
func _split_damage(total: int, parts: int) -> Array[int]:
	var result: Array[int] = []
	if parts <= 0:
		return result
	var base := total / parts
	var remainder := total % parts
	for i in range(parts):
		result.append(base + (1 if i >= parts - remainder else 0))
	return result


# 신속 전용 컷신. 삼중나선과 같은 "화면을 덮은 프레임에 좌표만 즉시 바꾸는" 순간이동 트릭을 쓰지만
# 구조가 다르다 — 이동은 딱 한 번(몬스터 등 뒤 고정)이고, 그 뒤에 정적을 길게 끌었다가 연타로
# 몰아친 다음 큰 흔들림으로 마무리한다.
#
# 피해 표시는 삼중나선과 같은 이유로 card.value가 아니라 "실제로 깎인 체력"(monster_hp_before와
# 매니저 값의 차이)을 나눈다 — 마지막 일격이 몬스터를 잡으면 HP가 0에서 멈춰 실제 감소량이
# 카드 수치보다 작아지는데, 그때도 팝업 숫자의 합과 HP바가 어긋나지 않게 하려는 것
func _play_swift_cutscene(card: Card, monster_hp_before: int, target_index: int) -> void:
	var target_sprite := _monster_sprite_at(target_index)
	var start_pos := _player_sprite.position
	var monster_pos := target_sprite.position
	var offset := monster_pos - start_pos
	var distance := offset.length()
	var direction := offset / distance if distance > 1.0 else Vector2.RIGHT
	var back_pos := monster_pos + direction * (_monster_half_width(target_index) + SWIFT_HIT_GAP) # 몬스터를 지나친 등 뒤

	var total_damage := monster_hp_before - _monster_hp_of(target_index)
	var hit_damages := _split_damage(total_damage, SWIFT_HIT_COUNT)
	var hp_step := monster_hp_before
	_message.text = "%s!" % tr(card.card_name)

	# 1) 화면을 은백색으로 덮는다
	_hit_flash.color = Color(SWIFT_TINT.r, SWIFT_TINT.g, SWIFT_TINT.b, 0.0)
	var flash_in := create_tween()
	flash_in.tween_property(_hit_flash, "color:a", SWIFT_FLASH_ALPHA, SWIFT_FLASH_IN_DURATION)
	await flash_in.finished

	# 2) 완전히 가려진 이 프레임에 좌표만 즉시 바꾼다 (이동 트윈이 없어 순간이동으로 보인다)
	_player_sprite.position = back_pos

	# 3) 플래시가 걷히며 등 뒤에 선 모습이 드러난다
	var flash_out := create_tween()
	flash_out.tween_property(_hit_flash, "color:a", 0.0, SWIFT_FLASH_OUT_DURATION)
	await flash_out.finished

	# 4) 베기 직전의 정적 — 화면을 눌러 어둡게 한 채 잠시 멈춘다
	_hit_flash.color = Color(SWIFT_DIM_COLOR.r, SWIFT_DIM_COLOR.g, SWIFT_DIM_COLOR.b, 0.0)
	var dim_in := create_tween()
	dim_in.tween_property(_hit_flash, "color:a", SWIFT_DIM_ALPHA, SWIFT_DIM_IN_DURATION)
	await dim_in.finished
	await _wait(SWIFT_PAUSE_HOLD)

	# 5) 연타. 어둠은 연타가 도는 동안 서서히 걷혀서 "정적이 깨지며 터진다"처럼 보인다
	var dim_out := create_tween()
	dim_out.tween_property(_hit_flash, "color:a", 0.0, SWIFT_HIT_INTERVAL * SWIFT_HIT_COUNT)

	for i in range(SWIFT_HIT_COUNT):
		_shake_actors(SWIFT_HIT_SHAKE, SWIFT_HIT_SHAKE_STEPS)
		_flash_hit(target_sprite)
		_spawn_vfx_sprite("physical", target_sprite.position + SWIFT_HIT_OFFSETS[i % SWIFT_HIT_OFFSETS.size()])
		# 타격마다 음을 조금씩 올려 연타가 몰아치는 느낌을 준다
		SFXPlayer.play(SWIFT_HIT_SFX[i % SWIFT_HIT_SFX.size()], SFXPlayer.DEFAULT_VOLUME_DB, 0.95 + 0.05 * i)

		hp_step -= hit_damages[i]
		# 남은 체력이 타격 수보다 적으면(약해진 몬스터에게 마지막 일격) 일부 타격의 몫이 0이 된다.
		# 그때 "-0"을 띄우면 버그처럼 보이므로 숫자만 생략한다 — 타격 이펙트/흔들림은 그대로 둬서
		# 연타 연출 자체는 끊기지 않게 한다
		if hit_damages[i] > 0:
			_show_popup(target_sprite.position, "-%d" % hit_damages[i], DAMAGE_COLOR)
		_set_monster_hp_display(target_index, hp_step)

		await _wait(SWIFT_HIT_INTERVAL)

	# 6) 마무리 큰 흔들림
	_shake_actors(SWIFT_FINAL_SHAKE, SWIFT_FINAL_SHAKE_STEPS)
	await _wait(SWIFT_FINAL_HOLD)

	# 7) 원위치 복귀
	var return_tween := create_tween()
	return_tween.tween_property(_player_sprite, "position", start_pos, SWIFT_RETURN_DURATION)
	await return_tween.finished

	_update_monster_hp_text()
	_message.text = tr("%s! %d 피해!") % [tr(card.card_name), total_damage]
	await _wait(0.25)


# 시공균열 전용 컷신. 캐릭터는 움직이지 않고 화면 자체가 멈춘다:
# 차가운 오버레이가 서서히 덮이는 동안 몬스터 주위에 균열이 생기다가 중간 프레임에서 얼어붙고,
# 정적을 버틴 뒤 밝은 시안 플래시와 함께 한꺼번에 풀려나며 터진다.
#
# 표시 데미지는 다른 컷신들과 같은 이유로 card.value가 아니라 실제로 깎인 체력을 쓴다
# (마무리 일격이면 HP가 0에서 멈춰 실제 감소량이 카드 수치보다 작아지기 때문)
func _play_time_rift_cutscene(card: Card, _monster_hp_before: int, _target_index: int) -> void:
	_message.text = "%s!" % tr(card.card_name)

	# 1) 차갑고 탁한 블루그레이가 서서히 화면을 덮는다
	_hit_flash.color = Color(TIME_RIFT_FREEZE_COLOR.r, TIME_RIFT_FREEZE_COLOR.g, TIME_RIFT_FREEZE_COLOR.b, 0.0)
	var freeze_in := create_tween()
	freeze_in.tween_property(_hit_flash, "color:a", TIME_RIFT_FREEZE_ALPHA, TIME_RIFT_FREEZE_IN_DURATION)

	# 2) 그와 동시에 몬스터 주위에 균열을 띄우고, 완성된 프레임에서 얼린다.
	# 재생 속도가 18fps라 TIME_RIFT_FREEZE_FRAME(2번)까지 오는 데 약 0.11초 — 오버레이가 덮이는
	# 동안 균열이 자라다가 멈추는 그림이 된다
	# 광역기라 대상 하나하나를 균열로 감싼다 (한 마리면 예전과 같은 그림)
	var cracks: Array[AnimatedSprite2D] = []
	for index in _card_targets:
		var crack_origin := _monster_sprite_at(index).position
		for offset in TIME_RIFT_CRACK_OFFSETS:
			var crack := _spawn_vfx_sprite("time_crack", crack_origin + offset, TIME_RIFT_CRACK_SCALE)
			if crack != null:
				cracks.append(crack)
	# 얼리는 소리는 대상 수와 무관하게 한 번만 (마리마다 겹쳐 울리면 탁해진다)
	SFXPlayer.play(TIME_RIFT_FREEZE_SFX, SFXPlayer.DEFAULT_VOLUME_DB, TIME_RIFT_FREEZE_SFX_PITCH)

	for crack in cracks:
		while crack.frame < TIME_RIFT_FREEZE_FRAME and crack.is_playing():
			await get_tree().process_frame
		crack.pause()
		crack.frame = TIME_RIFT_FREEZE_FRAME # 프레임을 못 맞추고 끝난 경우까지 확실히 고정

	await freeze_in.finished

	# 3) 얼어붙은 채로 버티는 정적
	await _wait(TIME_RIFT_HOLD)

	# 4) 해제 — 오버레이를 밝은 시안으로 갈아끼워 번쩍인 뒤 걷고, 얼렸던 균열을 빠르게 마저 돌린다
	_hit_flash.color = Color(TIME_RIFT_RELEASE_TINT.r, TIME_RIFT_RELEASE_TINT.g, TIME_RIFT_RELEASE_TINT.b, TIME_RIFT_FREEZE_ALPHA)
	var release_in := create_tween()
	release_in.tween_property(_hit_flash, "color:a", TIME_RIFT_RELEASE_ALPHA, TIME_RIFT_RELEASE_IN_DURATION)
	await release_in.finished

	for crack in cracks:
		if is_instance_valid(crack):
			crack.speed_scale = TIME_RIFT_BURST_FPS / float(VFX_CONFIG["time_crack"]["fps"])
			crack.play("play") # 멈춰 있던 지점부터 나머지를 이어서 재생

	var release_out := create_tween()
	release_out.tween_property(_hit_flash, "color:a", 0.0, TIME_RIFT_RELEASE_OUT_DURATION)

	# 5) 강한 흔들림 + 유리 깨지는 타격음 (화면 단위 연출이라 대상 수와 무관하게 한 번)
	_shake_actors(TIME_RIFT_SHAKE, TIME_RIFT_SHAKE_STEPS)
	for index in _card_targets:
		_flash_hit(_monster_sprite_at(index))
	for sfx in TIME_RIFT_RELEASE_SFX:
		SFXPlayer.play(sfx)

	# 6) 갇혀 있던 타격이 한꺼번에 풀려나는 것이라 마리별로 나누지 않고 각자 한 번에 터뜨린다
	_show_damage_popups_on_targets()
	await _wait(TIME_RIFT_IMPACT_HOLD)

	# 7) 오버레이를 확실히 원상복귀시킨다.
	# [주의] release_out.finished를 await하면 안 된다 — 이 트윈(0.22초)은 바로 위 여운 대기
	# (0.45초)가 끝나기 훨씬 전에 이미 완료돼 있어서, 이미 발신된 시그널을 기다리다 코루틴이
	# 영영 멈춘다. 실제로 그렇게 짜서 최종 메시지가 안 뜨고 _play_card_flow가 끝나지 않았다.
	# 어차피 알파를 직접 0으로 되돌리므로 트윈 완료를 기다릴 이유도 없다
	_hit_flash.color = Color(TIME_RIFT_FREEZE_COLOR.r, TIME_RIFT_FREEZE_COLOR.g, TIME_RIFT_FREEZE_COLOR.b, 0.0)

	_message.text = _damage_result_message(card)
	await _wait(0.25)


# 낙하 지점 예고 마커(붉은 타원)를 pos에 띄우고 맥동시킨다. 정리는 _clear_impact_marker()가 한다.
# 그림자(_setup_shadow)와 같은 방식으로 타원 폴리곤을 코드로 만들어 전용 에셋 없이 처리한다
# 불사조의 축복 전용 연출. 초재생의 "치유+마나 이펙트를 좌우로 갈라 동시에" 구조를 세 겹으로
# 늘리고, 금빛 깃털 파티클을 얹었다. 회복 자체는 이미 매니저가 적용해둔 상태라 여기서는 결과를
# 보여주기만 하고, 과열 게이지 페널티도 매니저(Card.on_use_set_gauge)가 처리한 뒤라 표시만 한다
func _play_phoenix_cutscene(card: Card, hp_before: int, mana_before: int) -> void:
	var healed: int = GameState.get_flag("player_hp") - hp_before
	var mana_restored: int = GameState.get_flag("player_mana") - mana_before
	var pos := _player_sprite.position

	_message.text = "%s!" % tr(card.card_name)
	for sfx in PHOENIX_SFX:
		SFXPlayer.play(sfx)
	_spawn_feather_particles(pos)

	# 치유(초록 고리)와 마나(하늘색 소용돌이)를 번갈아 세 겹으로 겹쳐 띄운다
	for i in range(PHOENIX_HEAL_OFFSETS.size()):
		var key := "heal" if i % 2 == 0 else "mana"
		var sprite := _spawn_vfx_sprite(key, pos + PHOENIX_HEAL_OFFSETS[i], PHOENIX_VFX_SCALE)
		if sprite != null:
			sprite.modulate = PHOENIX_GLOW_TINT # 전부 금빛으로 물들여 "불사조"라는 한 덩어리로 보이게
		await _wait(PHOENIX_STAGGER)

	_flash_hit(_player_sprite)
	_show_popup(pos, "+%d / +%d MP" % [healed, mana_restored], HEAL_COLOR)
	_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
	_message.text = tr("%s — 체력과 마나를 완전히 회복했다! (무기 과열 %d%%)") % [tr(card.card_name), card.on_use_set_gauge]
	await _wait(PHOENIX_HOLD)


# 캐릭터 주위에 금빛 반짝임이 흩날리는 일회성 파티클. 스펠북 티어3 카드의 반짝임과 같은 방식으로
# 텍스처를 코드로 그려 쓰고(전용 에셋 불필요), 수명이 다하면 스스로 사라진다
func _spawn_feather_particles(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.texture = _build_sparkle_texture()
	particles.position = pos
	particles.z_index = 16
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.35 # 한꺼번에 확 퍼졌다가 남은 것들이 천천히 흩날리게
	particles.amount = PHOENIX_FEATHER_COUNT
	particles.lifetime = PHOENIX_FEATHER_LIFETIME
	particles.randomness = 0.6
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = PHOENIX_FEATHER_SPREAD
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 26) # 깃털처럼 천천히 내려앉는다
	particles.initial_velocity_min = 12.0
	particles.initial_velocity_max = 42.0
	particles.scale_amount_min = 1.4
	particles.scale_amount_max = 3.0
	particles.color = PHOENIX_GLOW_TINT
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0),
	])
	particles.color_ramp = ramp
	_actors.add_child(particles)

	# one_shot이라 방출은 알아서 끝나지만 노드는 남으므로, 마지막 입자가 사라질 시간까지 기다렸다 지운다
	var cleanup := get_tree().create_timer(PHOENIX_FEATHER_LIFETIME * 2.0)
	cleanup.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


# 천벌 전용 컷신. 유성낙하의 "예고 마커 → 화이트아웃 → 내리꽂기" 뼈대를 그대로 쓰지만 캐릭터는
# 전혀 움직이지 않는다 — 파이어볼/익스플로전처럼 제자리에서 시전하고, 하늘에서 빛기둥만 떨어진다.
#
# 표시 데미지는 다른 컷신들과 같은 이유로 card.value가 아니라 실제로 깎인 체력을 쓴다
func _play_judgment_cutscene(card: Card, monster_hp_before: int, target_index: int) -> void:
	var target_sprite := _monster_sprite_at(target_index)
	var monster_pos := target_sprite.position
	var total_damage := monster_hp_before - _monster_hp_of(target_index)
	_message.text = "%s!" % tr(card.card_name)

	# 1) 몬스터 발밑에 금빛 심판의 원이 나타나 진폭을 키워가며 맥동한다
	var foot_offset := _monster_foot_offset(target_index)
	_spawn_impact_marker(
		monster_pos + Vector2(0, foot_offset),
		JUDGMENT_MARKER_COLOR, JUDGMENT_MARKER_RX, JUDGMENT_MARKER_RY,
		JUDGMENT_MARKER_PULSE, JUDGMENT_MARKER_GROW
	)

	# 2) 낮고 웅장한 차징
	SFXPlayer.play(JUDGMENT_CHARGE_SFX, SFXPlayer.DEFAULT_VOLUME_DB, JUDGMENT_CHARGE_SFX_PITCH)
	await _wait(JUDGMENT_CHARGE_DURATION)

	# 3) 순수한 흰색으로 완전히 화이트아웃
	_hit_flash.color = Color(1, 1, 1, 0.0)
	var white_in := create_tween()
	white_in.tween_property(_hit_flash, "color:a", JUDGMENT_WHITEOUT_ALPHA, JUDGMENT_WHITEOUT_IN_DURATION)
	await white_in.finished

	# 4) 화면이 완전히 하얀 이 순간에 빛기둥을 세운다 (세로로만 크게 늘려 하늘에서 내리꽂히는 형태로).
	# 스프라이트 아래 끝이 몬스터 발밑에 오도록 높이의 절반만큼 올려 배치한다
	var beam_half_height := VFX_FRAME_SIZE * 0.5 * VFX_DISPLAY_SCALE * JUDGMENT_BEAM_SCALE * JUDGMENT_BEAM_STRETCH.y
	var beam_pos := Vector2(monster_pos.x, monster_pos.y + foot_offset + JUDGMENT_BEAM_FOOT_SINK - beam_half_height)
	var beam := _spawn_vfx_sprite("light_pillar", beam_pos, JUDGMENT_BEAM_SCALE, JUDGMENT_BEAM_STRETCH)
	if beam != null:
		beam.modulate = JUDGMENT_BEAM_TINT

	# 5) 화이트아웃이 걷히며 임팩트가 드러난다 (걷히는 트윈은 던져두고 흔들림/사운드를 바로 얹는다).
	# [주의] 이 트윈은 아래 여운 대기보다 먼저 끝나므로 finished를 await하면 안 된다 —
	# 이미 발신된 시그널을 기다리다 코루틴이 멈춘다 (시공균열에서 실제로 겪은 함정)
	var white_out := create_tween()
	white_out.tween_property(_hit_flash, "color:a", 0.0, JUDGMENT_WHITEOUT_OUT_DURATION)

	_clear_impact_marker() # 빛기둥이 떨어졌으니 예고 마커는 치운다
	_shake_actors(JUDGMENT_SHAKE, JUDGMENT_SHAKE_STEPS)
	_flash_hit(target_sprite)
	for sfx in JUDGMENT_IMPACT_SFX:
		SFXPlayer.play(sfx)

	# 흰빛이 걷히는 위로 파란 잔광이 스친다 (별도 오버레이라 화이트아웃 페이드와 안 부딪힌다).
	# await 없이 던져두고 아래 여운 대기가 흘러가게 둔다
	_bolt_flash.color = Color(JUDGMENT_BOLT_TINT.r, JUDGMENT_BOLT_TINT.g, JUDGMENT_BOLT_TINT.b, 0.0)
	var bolt := create_tween()
	bolt.tween_property(_bolt_flash, "color:a", JUDGMENT_BOLT_ALPHA, JUDGMENT_BOLT_IN_DURATION)
	bolt.tween_property(_bolt_flash, "color:a", 0.0, JUDGMENT_BOLT_OUT_DURATION)

	# 6) 단발 심판이라 데미지는 한 번에
	if total_damage > 0:
		_show_popup(monster_pos, "-%d" % total_damage, DAMAGE_COLOR)
	_set_monster_hp_display(target_index, _monster_hp_of(target_index))
	_update_monster_hp_text()
	await _wait(JUDGMENT_IMPACT_HOLD)

	# 7) 화면 색을 확실히 원상복귀 (트윈에 맡기지 않고 직접 0으로 되돌린다)
	_hit_flash.color = Color(1, 1, 1, 0.0)
	_bolt_flash.color = Color(JUDGMENT_BOLT_TINT.r, JUDGMENT_BOLT_TINT.g, JUDGMENT_BOLT_TINT.b, 0.0)
	_message.text = tr("%s! %d 피해!") % [tr(card.card_name), total_damage]
	await _wait(0.25)


# grow_scales가 비어 있으면 유성낙하처럼 "일정하게 커졌다 작아지길 무한 반복"하고,
# 값이 들어오면 천벌처럼 "그 배율들을 차례로 밟으며 점점 커지는" 한 번짜리 연출이 된다
func _spawn_impact_marker(pos: Vector2, color: Color, rx: float, ry: float, pulse: float, grow_scales: Array = []) -> void:
	_clear_impact_marker()

	var marker := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	marker.polygon = pts
	marker.color = color
	marker.position = pos
	marker.z_index = 14
	_actors.add_child(marker)
	_impact_marker = marker

	_impact_marker_tween = create_tween()
	if grow_scales.is_empty():
		# 커졌다 작아지길 반복해 "조준되고 있다"는 인상을 준다
		_impact_marker_tween.set_loops()
		_impact_marker_tween.tween_property(marker, "scale", Vector2(1.25, 1.25), pulse)
		_impact_marker_tween.tween_property(marker, "scale", Vector2(0.85, 0.85), pulse)
	else:
		# 맥동하되 진폭이 점점 커진다 — 차징이 차오르는 느낌
		marker.scale = Vector2(grow_scales[0], grow_scales[0])
		for s in grow_scales:
			_impact_marker_tween.tween_property(marker, "scale", Vector2(s, s), pulse)


# 마커와 맥동 트윈을 함께 정리한다.
# [주의] 트윈을 먼저 죽이지 않고 마커만 free하면 Godot이 "Infinite loop detected"를 뱉는다 —
# set_loops()로 무한 반복 중인 트윈의 대상이 사라져 한 바퀴가 0초에 끝나기 때문이다 (실제로 겪음)
func _clear_impact_marker() -> void:
	if _impact_marker_tween != null and _impact_marker_tween.is_valid():
		_impact_marker_tween.kill()
	_impact_marker_tween = null
	if is_instance_valid(_impact_marker):
		_impact_marker.queue_free()
	_impact_marker = null


# 유성낙하 전용 컷신. 지금까지의 컷신들과 같은 "플래시로 위치 이동을 가린다"는 트릭을 쓰되
# 방향이 세로다 — 위로 튀어올라 화면 밖으로 사라진 뒤, 플래시가 덮인 사이 몬스터 머리 위 공중에
# 다시 나타나 내리꽂는다. 연타가 아닌 단발 강타라 데미지도 한 번에 표시한다.
#
# 표시 데미지는 다른 컷신들과 같은 이유로 card.value가 아니라 실제로 깎인 체력을 쓴다 —
# 마무리 일격으로 몬스터를 잡으면 HP가 0에서 멈춰 실제 감소량이 카드 수치보다 작아지기 때문
func _play_meteor_cutscene(card: Card, monster_hp_before: int, target_index: int) -> void:
	var target_sprite := _monster_sprite_at(target_index)
	var start_pos := _player_sprite.position
	var monster_pos := target_sprite.position
	var landing_pos := _flash_slash_dash_target(start_pos, monster_pos, target_index) # 몬스터 코앞에 내려꽂힌다
	var air_pos := Vector2(landing_pos.x, landing_pos.y - METEOR_DROP_HEIGHT)

	var total_damage := monster_hp_before - _monster_hp_of(target_index)
	_message.text = "%s!" % tr(card.card_name)

	# 1) 위로 튀어올라 화면 밖으로 빠져나간다 (가속하며 솟구치도록 EASE_IN)
	SFXPlayer.play(METEOR_JUMP_SFX)
	var jump := create_tween()
	jump.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	jump.tween_property(_player_sprite, "position", Vector2(start_pos.x, METEOR_JUMP_EXIT_Y), METEOR_JUMP_DURATION)
	await jump.finished

	# 2) 화면 밖으로 나간 시점에 완전히 감춘다. 그림자도 같이 숨긴다 — 캐릭터가 사라졌는데
	# 발밑 그림자만 원래 자리에 남아 있으면 "하늘로 올라갔다"는 인상이 깨진다
	_player_sprite.visible = false
	_player_shadow.visible = false

	# 3) 정적. 몬스터 발밑에 낙하 지점 마커를 띄워 "여기로 떨어진다"를 예고한다
	var foot_offset := _monster_foot_offset(target_index)
	_spawn_impact_marker(monster_pos + Vector2(0, foot_offset), METEOR_MARKER_COLOR, METEOR_MARKER_RX, METEOR_MARKER_RY, METEOR_MARKER_PULSE)
	await _wait(METEOR_HANG_DURATION)

	# 4) 화면 전체를 강한 흰빛으로 덮는다
	_hit_flash.color = Color(METEOR_TINT.r, METEOR_TINT.g, METEOR_TINT.b, 0.0)
	var flash_in := create_tween()
	flash_in.tween_property(_hit_flash, "color:a", METEOR_FLASH_ALPHA, METEOR_FLASH_IN_DURATION)
	await flash_in.finished

	# 5) 가려진 프레임에 몬스터 머리 위 공중으로 재배치하고 다시 보이게 한다
	_player_sprite.position = air_pos
	_player_sprite.visible = true

	# 6) 플래시가 걷히는 동안(병렬) 그대로 내리꽂는다
	var flash_out := create_tween()
	flash_out.tween_property(_hit_flash, "color:a", 0.0, METEOR_FLASH_OUT_DURATION)
	var drop := create_tween()
	drop.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	drop.tween_property(_player_sprite, "position", landing_pos, METEOR_DROP_DURATION)
	await drop.finished

	# 착지 순간: 예고 마커를 치우고 가장 강한 흔들림 + 큰 타격 이펙트
	_clear_impact_marker()
	_player_shadow.visible = true
	_shake_actors(METEOR_IMPACT_SHAKE, METEOR_IMPACT_SHAKE_STEPS)
	_flash_hit(target_sprite)
	for sfx in METEOR_IMPACT_SFX:
		SFXPlayer.play(sfx)
	_spawn_vfx_sprite("explosion_big", target_sprite.position, METEOR_VFX_SCALE) # 지면이 부서지는 충격파
	_spawn_vfx_sprite("physical", target_sprite.position)                        # 그 위에 얹는 타격 자국

	# 7) 단발 강타라 데미지는 한 번에. 0이면(완전 무효화 등) 숫자를 띄우지 않는다
	if total_damage > 0:
		_show_popup(target_sprite.position, "-%d" % total_damage, DAMAGE_COLOR)
	_set_monster_hp_display(target_index, _monster_hp_of(target_index))
	_update_monster_hp_text()
	await _wait(METEOR_IMPACT_HOLD)

	# 8) 원위치 복귀
	var return_tween := create_tween()
	return_tween.tween_property(_player_sprite, "position", start_pos, METEOR_RETURN_DURATION)
	await return_tween.finished

	_message.text = tr("%s! %d 피해!") % [tr(card.card_name), total_damage]
	await _wait(0.25)


# 맞은 캐릭터 머리 위로 "-N"/"+N"/"회피!" 텍스트를 크게 띄웠다가 위로 떠오르며 사라지게 함
func _show_popup(sprite_pos: Vector2, text: String, color: Color) -> void:
	var popup := Label.new()
	popup.text = text
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_font_size_override("font_size", DAMAGE_POPUP_FONT_SIZE)
	popup.z_index = 20
	_hud.add_child(popup)
	popup.position = sprite_pos + Vector2(-16.0, -66.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - DAMAGE_POPUP_RISE, DAMAGE_POPUP_DURATION)
	tween.tween_property(popup, "modulate:a", 0.0, DAMAGE_POPUP_DURATION)
	tween.chain().tween_callback(popup.queue_free)


# 배우 컨테이너 전체를 짧게 흔들었다가 원위치 (타격감용). 그림자는 View 직속이라 함께 흔들리지 않음
func _shake_actors(amount: float = SHAKE_AMOUNT, steps: int = SHAKE_STEPS) -> void:
	# 이전 흔들림이 아직 돌고 있으면 죽이고 새로 시작한다. 신속의 연타처럼 흔들림이 끝나기 전에
	# 다음 흔들림이 들어오면 같은 _actors.position을 두 트윈이 서로 잡아당겨 떨림이 엉키고,
	# 최악의 경우 늦게 끝난 트윈이 배우를 원점이 아닌 곳에 두고 끝난다
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for i in range(steps):
		var offset := Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		_shake_tween.tween_property(_actors, "position", offset, SHAKE_STEP_DURATION)
	_shake_tween.tween_property(_actors, "position", Vector2.ZERO, SHAKE_STEP_DURATION)


# 공격하는 스프라이트를 상대 방향으로 짧게 찔렀다가 원위치로 돌아오게 함 (완료까지 await)
func _lunge(attacker: Node2D, target_pos: Vector2) -> void:
	var original := attacker.position
	var direction := target_pos - original
	if direction.length() > 0.001:
		direction = direction.normalized()
	else:
		direction = Vector2.RIGHT

	var tween := create_tween()
	tween.tween_property(attacker, "position", original + direction * LUNGE_DISTANCE, LUNGE_OUT_DURATION)
	tween.tween_property(attacker, "position", original, LUNGE_BACK_DURATION)
	await tween.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
