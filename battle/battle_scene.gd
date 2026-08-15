class_name BattleScene
extends Node2D

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
}

# 카드 이름 -> VFX 키 강제 지정. DAMAGE처럼 같은 효과·색을 공유하는 카드들도 이 표에 있으면
# _vfx_key_for_card()가 효과 기반 기본값(physical/magic) 대신 이 값을 쓴다 — 이름에 매달아 두는 건
# Card에 별도 id 필드가 없어서다. 카드 이름을 바꿀 계획이 생기면 이 표도 같이 고쳐야 한다
const CARD_NAME_VFX_OVERRIDE := {
	"섬광": "physical_flash",
	"파이어볼": "magic_fire",
	"익스플로전": "explosion_big",
}

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

const HAND_BUTTON_COUNT := 5

# 턴 진행 상태: ACTION=플레이어 입력 대기, BUSY=연출 재생 중(입력 무시), OVER=전투 종료
enum Mode { ACTION, BUSY, OVER }

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
const SKILL_ICON_REGION := {
	Card.EffectType.DAMAGE: Rect2(160, 1472, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE), # fb742 — 핏방울 검 슬래시
	Card.EffectType.DEFEND: Rect2(128, 1184, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE), # fb597 — 민무늬 은색 방패
	Card.EffectType.DODGE: Rect2(128, 1440, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE),  # fb725 — 바람 소용돌이
	Card.EffectType.HEAL_HP: Rect2(64, 1312, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE), # fb659 — 빨간 하트
	Card.EffectType.RESTORE_MANA: Rect2(192, 1408, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE), # fb711 — 파란 마나 물방울
	# 아래 둘은 기존 아이콘을 그대로 빌려 쓴다 — 전용 아이콘 고르기는 카드 UI 단계에서 할 일이라
	# 여기서는 "아이콘이 비어 카드가 깨져 보이는 것"만 막는 게 목적이다.
	# 반격은 막는 동작이 먼저라 방패를, 초재생은 체력 회복이 주효과라 하트를 쓴다
	Card.EffectType.COUNTER: Rect2(128, 1184, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE),      # fb597 (방어와 공유)
	Card.EffectType.RESTORE_BOTH: Rect2(64, 1312, RAVEN_ICON_SIZE, RAVEN_ICON_SIZE),  # fb659 (치유와 공유)
}
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

@onready var _actors: Node2D = $View/Actors
@onready var _hit_flash: ColorRect = $View/HitFlash
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
var _monster_data: Dictionary = {}
var _variant: Dictionary = {} # 필드 MonsterEncounter가 뽑은 시각 변종 (SceneManager가 그대로 전달)
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
# 몬스터 idle 프레임 안에서 실제 그림이 시작되는 y (원본 픽셀). 저항 배지를 머리 바로 위에
# 붙이기 위해 _setup_sprites()에서 시트를 직접 재서 채운다
var _monster_art_top_offset: float = 0.0

# 매니저 시그널로 받은 "방금 무슨 일이 있었는지"를 담아두는 버퍼. 시그널은 매니저 안에서 동기적으로
# 발생하는데 연출은 그 뒤에 이어서 재생해야 하므로, 콜백은 기록만 하고 실제 애니메이션은
# _play_card_flow()/_end_turn_flow()가 담당한다
var _last_card_damage: int = 0
var _last_enemy_damage: int = 0
var _last_enemy_dodged: bool = false
var _last_counter_damage: int = 0
var _outcome: String = "" # "" / "victory" / "defeat"


func _ready() -> void:
	add_to_group("battle_box")
	_build_battle_ui_resources()

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


# 과열 게이지 프레임, 카드 스킬/저항 아이콘, 카드 프레임 스타일박스를 한 번만 잘라서 캐시해둔다
# (기존 _build_portrait()/_build_frames()와 같은 방식 — AtlasTexture로 시트 일부만 잘라 쓴다)
func _build_battle_ui_resources() -> void:
	var gauge_sheet := load(GAUGE_SHEET_PATH) as Texture2D
	_sword_gauge_frames = _build_gauge_frames(gauge_sheet, GAUGE_ROW_Y[WeaponState.WeaponType.SWORD])
	_staff_gauge_frames = _build_gauge_frames(gauge_sheet, GAUGE_ROW_Y[WeaponState.WeaponType.STAFF])

	var raven_sheet := load(RAVEN_SHEET_PATH) as Texture2D
	for effect in SKILL_ICON_REGION:
		_skill_icon_textures[effect] = _atlas(raven_sheet, SKILL_ICON_REGION[effect])
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


# SceneManager가 전투 씬을 트리에 넣은 직후 호출. 몬스터 종류/시각 변종(필드에서 뽑힌 것과 동일)을
# 받아 스프라이트/구도를 세팅하고, 전투 매니저를 만들어 첫 턴을 연다
func start_with(monster_type: String, variant: Dictionary) -> void:
	_monster_type = monster_type
	_monster_data = BattleData.MONSTERS[monster_type]
	_variant = variant

	MusicManager.play("Battle 1")

	_setup_sprites()
	_layout_actors()

	_manager = BattleTurnManager.new(monster_type, StarterDeck.build())
	_manager.turn_started.connect(_on_turn_started)
	_manager.card_played.connect(_on_card_played)
	_manager.enemy_turn_resolved.connect(_on_enemy_turn_resolved)
	_manager.player_defeated.connect(_on_player_defeated)
	_manager.enemy_defeated.connect(_on_enemy_defeated)

	_monster_hp_bar.max_value = _monster_data["max_hp"]
	_monster_hp_bar.value = _monster_data["max_hp"]
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
	# 몬스터별 전용 등장 문구가 있으면 그걸, 없으면 기본 "N 출현!"을 쓴다.
	# 첫 턴 저항도 이미 굴려진 상태라, 등장 문구 뒤에 이어 붙여 1턴부터 저항을 알 수 있게 한다
	_message.text = _monster_data.get("appear_text", "%s 출현!" % _monster_data["name"])
	var first_resist := _resistance_announcement()
	if first_resist != "":
		_message.text += "\n" + first_resist


# ── 매니저 시그널 수신 (기록만; 연출은 아래 flow 함수들이 담당) ──────────────

func _on_turn_started(_turn_number: int) -> void:
	_show_turn_message()


# "N번째 턴" 안내 + (저항이 걸린 턴이면) 저항 안내를 인포창에 띄운다.
# 턴 시작 시그널은 적 반격 연출보다 먼저 날아오는데 그 연출이 인포창을 덮어쓰므로, 연출이 끝난
# 뒤에도 한 번 더 불러줘야 플레이어가 이번 턴 저항을 실제로 읽을 수 있다 (_end_turn_flow 참고)
func _show_turn_message() -> void:
	if _manager == null:
		return
	var text := "%d번째 턴 — 카드를 사용하세요." % _manager.turn_number
	var resist_text := _resistance_announcement()
	if resist_text != "":
		text += "\n" + resist_text
	_message.text = text


# "오크가 물리 면역을 얻었다! 데미지 50% 감소" 같은 안내. 감소 퍼센트는 실제 규칙값
# (EnemyResistance.RESIST_DAMAGE_MULTIPLIER)에서 계산하므로, 밸런스를 바꿔도 문구가 따라간다.
# 저항이 없는 턴이면 빈 문자열
func _resistance_announcement() -> String:
	var resistance: int = _manager.resistance.current
	var kind := ""
	match resistance:
		EnemyResistance.ResistanceType.PHYSICAL:
			kind = "물리"
		EnemyResistance.ResistanceType.MAGIC:
			kind = "마법"
		_:
			return ""

	var cut_percent := int(round((1.0 - EnemyResistance.RESIST_DAMAGE_MULTIPLIER) * 100.0))
	var name_: String = _monster_data["name"]
	return "%s%s %s 면역을 얻었다! 데미지 %d%% 감소" % [name_, _subject_particle(name_), kind, cut_percent]


# 한글 이름 뒤에 붙일 주격 조사를 고른다 (받침 있으면 "이", 없으면 "가").
# "오크가 / 스켈레톤이"처럼 몬스터마다 달라서, "이(가)"로 얼버무리지 않고 제대로 고른다
func _subject_particle(word: String) -> String:
	if word.is_empty():
		return "가"
	var last := word.unicode_at(word.length() - 1)
	if last < 0xAC00 or last > 0xD7A3: # 한글 음절이 아니면(숫자/영문 등) 무난한 쪽으로
		return "가"
	return "이" if (last - 0xAC00) % 28 != 0 else "가"


func _on_card_played(_card: Card, damage_dealt: int) -> void:
	_last_card_damage = damage_dealt


func _on_enemy_turn_resolved(damage_taken: int, dodged: bool, counter_damage: int) -> void:
	_last_enemy_damage = damage_taken
	_last_enemy_dodged = dodged
	_last_counter_damage = counter_damage


func _on_enemy_defeated() -> void:
	_outcome = "victory"


func _on_player_defeated() -> void:
	_outcome = "defeat"


# ── 플레이어 입력 ──────────────────────────────────────────────────────────

# 손패 버튼 클릭: 해당 슬롯의 카드를 낸다 (낼 수 없는 카드면 버튼이 이미 비활성이라 눌리지 않음)
func _on_card_pressed(index: int) -> void:
	if _mode != Mode.ACTION or _manager == null:
		return
	if index >= _manager.hand.cards.size():
		return
	var card: Card = _manager.hand.cards[index]
	if not _manager.can_play_card(card):
		return
	_play_card_flow(card)


# 카드 한 장을 내고 그 결과를 연출로 보여준다. 규칙 적용은 전부 매니저가 이미 끝낸 상태이므로
# 여기서는 HP/마나를 다시 건드리지 않고 화면만 따라간다
func _play_card_flow(card: Card) -> void:
	_mode = Mode.BUSY
	_set_inputs_enabled(false)

	var hp_before: int = GameState.get_flag("player_hp")
	var mana_before: int = GameState.get_flag("player_mana")
	var monster_hp_before: int = _manager.monster_hp
	_last_card_damage = 0

	if not _manager.play_card(card):
		_mode = Mode.ACTION
		await _refresh_all()
		return

	await _animate_card(card, hp_before, mana_before, monster_hp_before)

	await _refresh_all()

	if _outcome == "victory":
		_finish_victory()
		return

	# 손패를 전부 소진했으면 "턴 종료"를 누를 일만 남으므로 대신 눌러준다.
	# (어떤 조건에서 자동으로 넘기고 어떤 조건에서 안 넘기는지는 is_hand_exhausted() 주석 참고)
	# 마지막 카드 연출이 끝나자마자 적이 달려들면 급하게 느껴져서, 안내 문구와 함께 한 박자 둔다
	if _manager.is_hand_exhausted():
		_message.text = "손패를 모두 사용했다 — 턴을 넘긴다."
		await _wait(0.5)
		await _end_turn_flow()
		return

	_mode = Mode.ACTION
	_set_inputs_enabled(true)


# 카드 종류별 연출. 데미지는 매니저가 계산한 최종 피해(_last_card_damage)를 그대로 표시하고,
# 회복량은 GameState 값의 전후 차이로 실제 적용된 만큼만 보여준다.
# 이펙트/사운드는 여기서 카드별로 직접 부르지 않고 _vfx_key_for_card()로 종류를 정한 뒤
# _play_card_vfx()에서 이펙트+사운드를 함께 재생한다 — 화면 흔들림만 DAMAGE에서 따로 켠다
func _animate_card(card: Card, hp_before: int, mana_before: int, monster_hp_before: int) -> void:
	match card.effect:
		Card.EffectType.DAMAGE:
			if card.card_name == "삼중나선":
				# 삼중나선은 팝업/HP바를 스스로 3단계로 나눠 보여주는 완전히 독립된 컷신이라,
				# 아래 공통 꼬리(단일 팝업+HP바 트윈)를 타지 않고 여기서 바로 끝낸다
				await _play_triple_helix_cutscene(card, monster_hp_before)
				return
			if card.card_name == "파이어볼":
				# 원거리 마법이라 캐릭터는 제자리에 선 채, 앞쪽 허공에 불꽃을 짧게 응축했다가 터뜨린다
				await _play_charge_stage("charge_fire", FIREBALL_CHARGE_SFX, 1.0, FIREBALL_CHARGE_SCALE, FIREBALL_CHARGE_DURATION)
				_shake_actors()
				_flash_hit(_monster_sprite)
				_play_card_vfx(card, _monster_sprite)
			elif card.card_name == "익스플로전":
				# 2단 차징: 낮은 톤으로 한 번, 더 크고 높은 톤으로 한 번 더 모은 뒤 발사한다
				await _play_charge_stage("charge_heavy_1", EXPLOSION_CHARGE1_SFX, EXPLOSION_CHARGE1_PITCH, EXPLOSION_CHARGE1_SCALE, EXPLOSION_CHARGE1_DURATION)
				await _play_charge_stage("charge_heavy_2", EXPLOSION_CHARGE2_SFX, EXPLOSION_CHARGE2_PITCH, EXPLOSION_CHARGE2_SCALE, EXPLOSION_CHARGE2_DURATION)
				await _launch_projectile(_cast_charge_origin(), _monster_sprite.position, "charge_heavy_2", 0.9, EXPLOSION_TRAVEL_DURATION)
				_shake_actors(EXPLOSION_SHAKE_AMOUNT, EXPLOSION_SHAKE_STEPS)
				_flash_hit(_monster_sprite)
				SFXPlayer.play(EXPLOSION_IMPACT_SFX) # 큰 폭발음 위에 저역 "쿵"을 겹친다
				_play_card_vfx(card, _monster_sprite, EXPLOSION_VFX_SCALE_MULT)
				await _wait(0.18) # 폭발이 부풀어오르는 동안 숫자를 잠깐 참았다가 띄운다
			elif card.card_name == "섬광":
				# 섬광은 그냥 살짝 찌르는(_lunge) 대신, 몬스터 코앞까지 실제로 달려가서 때리고
				# 곧바로 원위치로 돌아온다 — 베기 전에 노랗게 짧게 번쩍이는 "차징"도 함께 넣는다
				await _flash_charge(_player_sprite)
				var dash_start := _player_sprite.position
				var dash_target := _flash_slash_dash_target(dash_start, _monster_sprite.position)
				# 잔상은 돌진과 같은 시간 동안 나란히 재생돼야 "지나간 궤적"처럼 보이므로
				# await 없이 던져서 돌진과 병렬로 돈다
				_spawn_dash_afterimages(_player_sprite, dash_start, dash_target, FLASH_SLASH_CHARGE_TINT)
				var dash_tween := create_tween()
				dash_tween.tween_property(_player_sprite, "position", dash_target, FLASH_SLASH_DASH_DURATION)
				await dash_tween.finished
				_shake_actors()
				_flash_hit(_monster_sprite)
				_play_card_vfx(card, _monster_sprite)
				_screen_flash(FLASH_SLASH_CHARGE_TINT, HIT_FLASH_DURATION)
				# 원위치 복귀는 await 없이 던진다 — 메시지/팝업이 뜨는 동안 뒤에서 자연스럽게 돌아가면 되고,
				# 계속 몬스터 앞에 머물러 있으면 다음 턴 배치가 어색해지므로 짧게(0.15s) 돌아온다
				var return_tween := create_tween()
				return_tween.tween_property(_player_sprite, "position", dash_start, FLASH_SLASH_RETURN_DURATION)
				# 이펙트가 스치고 지나간 뒤에야 숫자가 뜨는 "찰나의 딜레이"
				await _wait(0.12)
			else:
				await _lunge(_player_sprite, _monster_sprite.position)
				_shake_actors()
				_flash_hit(_monster_sprite)
				_play_card_vfx(card, _monster_sprite)
			_show_popup(_monster_sprite.position, "-%d" % _last_card_damage, DAMAGE_COLOR)
			_animate_hp_bar(_monster_hp_bar, _manager.monster_hp)
			_update_monster_hp_text()
			_message.text = "%s! %d 피해!" % [card.card_name, _last_card_damage]
			await _wait(0.35)
		Card.EffectType.HEAL_HP:
			var healed: int = GameState.get_flag("player_hp") - hp_before
			_flash_hit(_player_sprite)
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, "+%d" % healed, HEAL_COLOR)
			_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
			_message.text = "%s — 체력 %d 회복!" % [card.card_name, healed]
			await _wait(0.4)
		Card.EffectType.RESTORE_MANA:
			var restored: int = GameState.get_flag("player_mana") - mana_before
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, "+%d MP" % restored, MANA_COLOR)
			_message.text = "%s — 마나 %d 회복!" % [card.card_name, restored]
			await _wait(0.4)
		Card.EffectType.DEFEND:
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, "방어 %d" % _manager.get_pending_defense(), GUARD_COLOR)
			_message.text = "%s — 다음 공격 피해를 %d 줄인다." % [card.card_name, _manager.get_pending_defense()]
			await _wait(0.35)
		Card.EffectType.DODGE:
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, "회피 준비", DODGE_COLOR)
			_message.text = "%s — 다음 공격을 흘려낸다." % card.card_name
			await _wait(0.35)
		Card.EffectType.COUNTER:
			# 실제 반격 타격(2단계)은 _play_counter_vfx()가 적 턴에 따로 재생한다 — 여기서는
			# "받아넘길 준비를 했다"는 1단계 연출만 보여준다
			_play_card_vfx(card, _player_sprite)
			_show_popup(_player_sprite.position, "반격 준비", GUARD_COLOR)
			_message.text = "%s — 다음 공격을 받아넘기고 반격한다." % card.card_name
			await _wait(0.35)
		Card.EffectType.RESTORE_BOTH:
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
			_message.text = "%s — 체력 %d, 마나 %d 회복!" % [card.card_name, healed, mana_restored]
			await _wait(0.4)


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
		Card.EffectType.COUNTER:
			return "counter" # 낼 때는 "받아넘길 준비" — 실제 반격 타격은 적 턴에 따로 재생한다
		Card.EffectType.RESTORE_BOTH:
			return "heal"
		_:
			return ""


# 반격이 실제로 적을 때리는 순간의 연출. 이때는 카드가 손을 떠난 뒤(적 턴)라 카드 객체가 없으므로,
# 카드 기반인 _play_card_vfx() 대신 물리 타격 이펙트를 몬스터 위에 직접 재생한다
func _play_counter_vfx() -> void:
	if not _vfx_frames.has("physical"):
		return
	SFXPlayer.play(VFX_SFX["physical"])
	_spawn_vfx_sprite("physical", _monster_sprite.position)


# target 위치에 카드에 맞는 이펙트를 한 번 재생하고, 어울리는 타격음을 SFXPlayer로 함께 튼다.
# 이펙트 스프라이트는 재생이 끝나면(animation_finished) 스스로 사라진다.
# scale_mult로 기본 배율(VFX_DISPLAY_SCALE)보다 더 크게/작게 띄울 수 있다 — 익스플로전처럼
# 같은 재생 경로를 쓰되 "훨씬 크게" 보여야 하는 카드용
func _play_card_vfx(card: Card, target: Node2D, scale_mult: float = 1.0) -> void:
	var key := _vfx_key_for_card(card)
	if key == "" or not _vfx_frames.has(key):
		return

	if VFX_SFX.has(key):
		SFXPlayer.play(VFX_SFX[key])

	_spawn_vfx_sprite(key, target.position, scale_mult)


# VFX_CONFIG의 key에 해당하는 이펙트 스프라이트 하나를 pos에 재생한다 (사운드는 호출부 책임).
# _play_card_vfx()/_play_counter_vfx()가 공유하고, 초재생처럼 한 카드에서 이펙트 두 개를
# 서로 다른 위치에 동시에 띄워야 할 때도 이걸 그대로 두 번 부르면 된다
func _spawn_vfx_sprite(key: String, pos: Vector2, scale_mult: float = 1.0) -> void:
	if not _vfx_frames.has(key):
		return
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _vfx_frames[key]
	sprite.position = pos
	sprite.scale = Vector2.ONE * VFX_DISPLAY_SCALE * scale_mult
	sprite.z_index = 15
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play("play")


# 플레이어가 원거리 마법을 "모으는" 지점 — 몬스터를 향한 앞쪽 허공(가슴~손 높이).
# 캐릭터 위에 겹쳐 띄우면 자기 몸에 이펙트가 터지는 것처럼 보여서 앞으로 밀어냈다
func _cast_charge_origin() -> Vector2:
	var offset := _monster_sprite.position - _player_sprite.position
	var direction := offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
	return _player_sprite.position + direction * CAST_CHARGE_FORWARD + Vector2(0, -CAST_CHARGE_RISE)


# 차징 한 단계: 앞쪽 허공에 응축 이펙트를 띄우고 차징음을 울린 뒤, 그 단계가 끝날 때까지 기다린다
func _play_charge_stage(key: String, sfx_path: String, pitch: float, scale_mult: float, duration: float) -> void:
	if sfx_path != "":
		SFXPlayer.play(sfx_path, SFXPlayer.DEFAULT_VOLUME_DB, pitch)
	_spawn_vfx_sprite(key, _cast_charge_origin(), scale_mult)
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
	if _mode != Mode.ACTION or _manager == null:
		return
	var next_weapon = WeaponState.WeaponType.STAFF if _manager.weapon.equipped == WeaponState.WeaponType.SWORD else WeaponState.WeaponType.SWORD
	if _manager.switch_weapon(next_weapon):
		_message.text = "무기를 %s(으)로 바꿨다." % _weapon_name(next_weapon)
	else:
		_message.text = "이번 턴에는 더 이상 무기를 바꿀 수 없다."
	_refresh_all()


# [턴 종료]: 적이 반격하고 다음 턴이 열린다 (매니저가 처리). 여기서는 그 결과를 연출로 보여준다
func _on_end_turn_pressed() -> void:
	if _mode != Mode.ACTION or _manager == null:
		return
	_end_turn_flow()


func _end_turn_flow() -> void:
	_mode = Mode.BUSY
	_set_inputs_enabled(false)

	_last_enemy_damage = 0
	_last_enemy_dodged = false
	_last_counter_damage = 0

	_manager.end_turn() # 적 반격 + 승패 판정 + (안 끝났으면) 다음 턴 시작까지 전부 여기서 일어남

	await _animate_enemy_turn()

	# 여기서 _refresh_all()이 새 턴의 손패 뒤집기 연출까지 통째로 기다린다 — 그래야 바로 아래
	# _set_inputs_enabled(true)가 애니메이션 도중에 카드 내용을 앞당겨 드러내며 끼어들지 않는다
	await _refresh_all()

	if _outcome == "defeat":
		_finish_defeat()
		return

	# 적 반격 연출이 인포창을 덮어썼으므로, 이제 새 턴 안내(+이번 턴 저항)를 다시 띄운다
	_show_turn_message()

	_mode = Mode.ACTION
	_set_inputs_enabled(true)


# 적 반격 연출. 실제 피해 적용은 매니저가 이미 GameState.damage_player()로 끝냈으므로
# 여기서는 결과값(_last_enemy_damage/_last_enemy_dodged)에 맞춰 보여주기만 한다
func _animate_enemy_turn() -> void:
	await _lunge(_monster_sprite, _player_sprite.position)

	# 반격: 공격을 받아넘긴 뒤 곧바로 적을 때린다. 피해 적용은 매니저가 이미 끝냈으므로
	# 여기서는 적 HP바/숫자를 그 결과에 맞춰 따라가게만 한다 (플레이어는 피해를 안 받는다)
	if _last_counter_damage > 0:
		_show_popup(_player_sprite.position, "반격!", GUARD_COLOR)
		await _wait(0.2)
		_shake_actors()
		_flash_hit(_monster_sprite)
		_play_counter_vfx()
		_show_popup(_monster_sprite.position, "-%d" % _last_counter_damage, DAMAGE_COLOR)
		_animate_hp_bar(_monster_hp_bar, _manager.monster_hp)
		_update_monster_hp_text()
		_message.text = "공격을 받아넘겼다! %d 피해로 되돌려줬다!" % _last_counter_damage
		await _wait(0.4)
		return

	if _last_enemy_dodged:
		_show_popup(_player_sprite.position, "회피!", DODGE_COLOR)
		_message.text = "공격을 피했다!"
		await _wait(0.3)
		return

	if _last_enemy_damage <= 0:
		_show_popup(_player_sprite.position, "막았다!", GUARD_COLOR)
		_message.text = "%s의 공격을 완전히 막아냈다!" % _monster_data["name"]
		await _wait(0.3)
		return

	_shake_actors()
	_flash_hit(_player_sprite)
	_show_popup(_player_sprite.position, "-%d" % _last_enemy_damage, DAMAGE_COLOR)
	_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
	_message.text = "%s의 공격! %d 피해!" % [_monster_data["name"], _last_enemy_damage]
	await _wait(0.35)


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
	if _mode != Mode.ACTION or _flee_button.disabled:
		return
	_mode = Mode.BUSY
	_set_inputs_enabled(false)

	var penalty: int = min(randi_range(FLEE_GOLD_PENALTY_MIN, FLEE_GOLD_PENALTY_MAX), GameState.gold)
	GameState.spend_gold(penalty)
	_player_gold_label.text = str(GameState.gold)

	_message.text = "전투에서 도망쳤다! (골드 %d 소모)" % penalty
	await _wait(0.4)
	SceneManager.flee_battle()


# ── UI 갱신 ────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	await _refresh_hand_buttons()
	_refresh_weapon_button()
	_refresh_status_icons()
	_update_mana_bar()
	_update_player_hp_text()
	_update_monster_hp_text()
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
			desc += "\n[과열]"
		elif not GameState.can_afford_mana(card.get_mana_cost()):
			desc += "\n[마나부족]"
		elif not _manager.can_afford_hp(card.get_hp_cost()):
			desc += "\n[체력부족]"

	_set_card_parts_visible(i, true)
	frame.texture = _card_front_textures[style_key]
	_card_icon_frames[i].texture = _card_icon_frame_textures[style_key]
	_card_name_banners[i].texture = _card_name_banner_textures[style_key]
	icon.texture = _skill_icon_textures.get(card.effect)
	name_label.text = card.card_name
	desc_label.text = desc
	# flavor_text는 수치 설명(desc_label)과 별개로 손으로 쓴 짧은 분위기 문구다. 비워둔 카드도
	# 있을 수 있으니(예: 나중에 급하게 추가한 카드) 그런 경우 박스 자체를 숨겨 빈 칸이 안 보이게 한다
	_card_flavor_boxes[i].visible = card.flavor_text != ""
	_card_flavor_labels[i].visible = card.flavor_text != ""
	_card_flavor_labels[i].text = card.flavor_text

	# 비용은 설명 문장에 끼워 넣지 않고 아래 두 모서리의 마름모 배지로 뺀다 — 참고 이미지의
	# 모서리 배지와 같은 방식이고, 좁은 설명칸도 아낀다. 왼쪽=마나(파랑), 오른쪽=체력(빨강)이고
	# 해당 비용이 0인 카드는 그 배지만 통째로 숨겨서, 배지가 보이면 곧 비용이 있다는 뜻이 된다
	var mana_cost := card.get_mana_cost()
	_card_mana_badges[i].visible = mana_cost > 0
	_card_mana_labels[i].visible = mana_cost > 0
	if mana_cost > 0:
		_card_mana_badges[i].texture = _card_mana_badge_texture
		_card_mana_labels[i].text = str(mana_cost)

	var hp_cost := card.get_hp_cost()
	_card_hp_badges[i].visible = hp_cost > 0
	_card_hp_labels[i].visible = hp_cost > 0
	if hp_cost > 0:
		_card_hp_badges[i].texture = _card_hp_badge_texture
		_card_hp_labels[i].text = str(hp_cost)

	btn.disabled = not playable or _mode != Mode.ACTION
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


func _card_style_key(card: Card) -> String:
	match card.effect:
		Card.EffectType.DAMAGE:
			return "blue" if card.color == Card.CardColor.MAGIC else "red"
		Card.EffectType.HEAL_HP, Card.EffectType.RESTORE_MANA, Card.EffectType.RESTORE_BOTH:
			return "green"
		_:
			return "grey"


# 효과 종류에 맞춰 카드 설명을 자동으로 만든다. 카드 이름 밑에 그대로 표시된다.
# 마나 소모량은 여기 넣지 않는다 — 왼쪽 아래 마름모 배지가 따로 보여주므로 좁은 설명칸을
# 아끼고, 참고 이미지처럼 수치는 모서리 배지에 모아두는 편이 읽기도 쉽다
func _card_description(card: Card) -> String:
	return _card_base_description(card)


func _card_base_description(card: Card) -> String:
	match card.effect:
		Card.EffectType.DAMAGE:
			var kind := "마법" if card.color == Card.CardColor.MAGIC else "물리"
			return "%s 피해 %d" % [kind, card.value]
		Card.EffectType.HEAL_HP:
			return "체력 %d 회복" % card.value
		Card.EffectType.RESTORE_MANA:
			return "마나 %d 회복" % card.value
		Card.EffectType.DEFEND:
			return "다음 피해 %d 감소" % card.value
		Card.EffectType.DODGE:
			return "이번 턴 완전 회피"
		Card.EffectType.COUNTER:
			return "피해 무효 + 반격 %d" % card.value
		Card.EffectType.RESTORE_BOTH:
			return "체력 %d, 마나 %d 회복" % [card.value, card.secondary_value]
		_:
			return ""


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
	if hovering and (_hand_buttons[index].disabled or _mode != Mode.ACTION):
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
	_weapon_button.text = "무기: %s" % _weapon_name(_manager.weapon.equipped)


# 무기 과열 게이지 바(검/지팡이)와 적 저항 아이콘을 갱신한다. 게이지는 0/25/50/75/100 중 가장 가까운
# 프레임을 골라 표시하고, 저항은 없음(NONE)이면 아이콘 자체를 숨긴다
func _refresh_status_icons() -> void:
	if _manager == null:
		return
	_sword_gauge_rect.texture = _sword_gauge_frames[_gauge_frame_index(_manager.weapon.sword_gauge)]
	_staff_gauge_rect.texture = _staff_gauge_frames[_gauge_frame_index(_manager.weapon.staff_gauge)]

	# 저항 배지는 "없음"일 때도 흐릿하게 항상 띄운다 — 아이콘이 사라졌다 나타났다 하면 플레이어가
	# 저항 상태를 확인하려고 매번 같은 자리를 다시 찾아봐야 하기 때문
	var resistance: int = _manager.resistance.current
	_resist_badge.texture = _resist_icon_textures.get(resistance)
	_resist_badge.modulate = RESIST_BADGE_MODULATE.get(resistance, Color.WHITE)
	_resist_badge.visible = _resist_badge.texture != null


# 게이지(0~100, GAUGE_STEP=25 단위)를 프레임 인덱스로 변환. 시트의 프레임 순서는 왼쪽(0번)이 꽉 찬
# 상태고 오른쪽(4번)으로 갈수록 비므로, 게이지가 높을수록(=꽉 찰수록) 더 낮은 인덱스를 골라야 한다
func _gauge_frame_index(gauge: int) -> int:
	var filled_steps := clampi(int(round(float(gauge) / WeaponState.GAUGE_STEP)), 0, GAUGE_FRAME_COUNT - 1)
	return GAUGE_FRAME_COUNT - 1 - filled_steps


func _weapon_name(weapon: int) -> String:
	return "검" if weapon == WeaponState.WeaponType.SWORD else "지팡이"


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


# 몬스터 HP바 위에 겹친 숫자 텍스트를 매니저가 들고 있는 현재 전투 상태로 갱신
func _update_monster_hp_text() -> void:
	var hp: int = _manager.monster_hp if _manager != null else _monster_data["max_hp"]
	_monster_hp_bar_label.text = "HP: %d/%d" % [hp, _monster_data["max_hp"]]


# ── 승리 / 패배 ────────────────────────────────────────────────────────────

# 승리 처리: 처치 카운트 증가 + 골드 드롭 + 소량 회복(HP만), "닫기" 버튼으로 복귀 대기.
# (승패 판정 자체는 매니저가 하고, 이 함수는 전투 "바깥"의 보상 처리만 담당한다)
func _finish_victory() -> void:
	_mode = Mode.OVER
	_resist_badge.visible = false # 쓰러진 몬스터 위에 저항 배지만 남아 떠 있지 않게
	await _play_monster_death()

	MusicManager.play("Victory!")

	match _monster_type:
		"ORC":
			GameState.increment_orcs_defeated()
		"SKELETON":
			GameState.increment_skeletons_defeated()
		"MUMMY":
			GameState.increment_mummies_defeated()
		"RUINS_BOSS":
			GameState.set_flag("ruins_boss_defeated", true)

	var gold_gained := randi_range(_monster_data["gold_min"], _monster_data["gold_max"])
	GameState.add_gold(gold_gained)
	_player_gold_label.text = str(GameState.gold)

	var dropped_equipment := _roll_equipment_drop()

	GameState.heal_player_partial(VICTORY_HEAL_FRACTION)
	_animate_hp_bar(_player_hp_bar, GameState.get_flag("player_hp"))
	_update_player_hp_text()
	_update_mana_bar()

	_message.text = "%s 처치!\n골드 %d 획득!\n체력을 약간 회복했다." % [_monster_data["name"], gold_gained]
	if dropped_equipment != "":
		_message.text += "\n%s을(를) 얻었다!" % ItemData.ITEMS[dropped_equipment]["name"]

	_main_column.visible = false
	_close_button.visible = true


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
	_resist_badge.visible = false
	_main_column.visible = false
	_message.text = "정신을 잃었다..."
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
func _setup_sprites() -> void:
	_player_sprite.sprite_frames = _build_frames(load(PLAYER_SPRITE_PATH) as Texture2D, PLAYER_FRAME_SIZE)
	_player_sprite.scale = Vector2.ONE * PLAYER_SCALE
	_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_sprite.play("default")
	_player_portrait.texture = _build_portrait(load(PLAYER_PORTRAIT_SHEET_PATH) as Texture2D, PLAYER_PORTRAIT_REGION)

	var idle_sheet := load(_variant["idle_path"]) as Texture2D

	var monster_frames := SpriteFrames.new()
	if monster_frames.has_animation("default"):
		monster_frames.remove_animation("default")
	var idle_frame_size: int = _variant.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
	_monster_art_top_offset = _measure_art_top_offset(idle_sheet, idle_frame_size)
	_add_monster_animation(monster_frames, "idle", idle_sheet, idle_frame_size, idle_frame_size, _variant.get("idle_frame_count", BattleData.MOB_IDLE_FRAME_COUNT), MONSTER_IDLE_FPS, true)
	_add_monster_animation(monster_frames, "death", load(_variant["death_path"]) as Texture2D, _variant["death_frame_width"], _variant["death_frame_height"], _variant["death_frame_count"], MONSTER_DEATH_FPS, false)

	_monster_sprite.sprite_frames = monster_frames
	_monster_sprite.scale = Vector2.ONE * MONSTER_SCALE
	_monster_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_monster_sprite.flip_h = true # 왼쪽의 플레이어를 바라보도록
	_monster_sprite.play("idle")
	_monster_portrait.texture = _build_portrait(idle_sheet, _monster_data["portrait_region"])


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
	_monster_sprite.position = Vector2(vp.x * 0.72, vp.y * 0.19)

	# 그림자는 "프레임 아래쪽"이 아니라 실제로 잰 발 위치에 맞춘다 (PLAYER_FOOT_FROM_CENTER 주석 참고).
	# 크기도 캐릭터 실제 폭에 비례시켜, 스케일을 바꿔도 그림자가 따로 놀지 않게 한다
	var player_foot := _player_sprite.position + Vector2(0, PLAYER_FOOT_FROM_CENTER * PLAYER_SCALE)
	var player_shadow_rx := PLAYER_BODY_WIDTH * PLAYER_SCALE * 0.62
	var idle_frame_size: int = _variant.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
	var monster_foot := _monster_sprite.position + Vector2(0, idle_frame_size * MONSTER_SCALE * 0.5 - 4.0)
	_setup_shadow(_player_shadow, player_foot, player_shadow_rx, player_shadow_rx * 0.3)
	_setup_shadow(_monster_shadow, monster_foot, 40.0, 12.0)

	# 적 저항 배지를 몬스터 머리 위에 띄운다. Actors의 자식이라 피격 흔들림도 몬스터와 함께 따라간다.
	# 기준은 프레임 위쪽이 아니라 "실제로 그림이 시작되는 y"다 — 몬스터마다 프레임 안 여백이 제각각이라
	# 프레임 기준으로 잡으면 배지가 머리에서 한참 떨어져 허공에 뜬다 (플레이어 그림자와 같은 이유)
	var monster_art_top := _monster_sprite.position.y - idle_frame_size * MONSTER_SCALE * 0.5 + _monster_art_top_offset * MONSTER_SCALE
	_resist_badge.position = Vector2(_monster_sprite.position.x, monster_art_top - RESIST_BADGE_GAP)


# 타원형 그림자 폴리곤(반지름 rx*ry)을 만들어 지정 위치에 배치
func _setup_shadow(shadow: Polygon2D, center: Vector2, rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	shadow.polygon = pts
	shadow.position = center


# 몬스터가 쓰러졌을 때, 사라지기 전에 Death 애니메이션을 한 번(루프 없이) 재생하고 끝날 때까지 기다림.
# Death 캔버스는 변종마다 크기가 달라도 캐릭터의 실제 픽셀 크기는 Idle과 비슷해서, scale은 그대로 두면
# 된다. 대신 AnimatedSprite2D가 기본 centered라 캔버스가 더 큰 변종일수록 발이 아래로 밀려 캐릭터가
# 순간 가라앉아 보이므로, offset으로 캔버스 높이 차의 절반만큼 위로 당겨 보정한다
func _play_monster_death() -> void:
	if _monster_sprite.sprite_frames == null or not _monster_sprite.sprite_frames.has_animation("death"):
		return

	var idle_h: float = _variant.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
	var death_h: float = _variant.get("death_frame_height", idle_h)
	_monster_sprite.offset = Vector2(0, -(death_h - idle_h) / 2.0)
	_monster_sprite.play("death")
	await _monster_sprite.animation_finished


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
# 떨어지는 지점을 계산한다. 몬스터 폭은 변종마다 프레임 크기가 달라 _variant에서 직접 읽는다
# (_layout_actors()의 몬스터 발 위치 계산과 같은 방식)
func _flash_slash_dash_target(start: Vector2, monster_pos: Vector2) -> Vector2:
	var offset := monster_pos - start
	var distance := offset.length()
	if distance < 1.0:
		return start
	var direction := offset / distance
	var idle_frame_size: float = _variant.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
	var monster_half_width := idle_frame_size * MONSTER_SCALE * 0.5
	var player_half_width := PLAYER_BODY_WIDTH * PLAYER_SCALE * 0.5
	var stop_distance: float = clamp(distance - monster_half_width - player_half_width - FLASH_SLASH_HIT_GAP, 0.0, distance)
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
# 데미지 표시는 card.value가 아니라 (호출부가 넘겨준) monster_hp_before와 _manager.monster_hp의
# 실제 차이를 3등분한다 — 마지막 한 방으로 몬스터를 잡으면 실제로 깎인 체력이 카드 수치보다 작을
# 수 있는데(HP가 음수로 안 내려가게 클램프되므로), card.value를 그대로 쓰면 표시된 피해 합이
# HP바가 실제로 줄어든 양과 안 맞아 숫자가 어긋나 보인다
func _play_triple_helix_cutscene(card: Card, monster_hp_before: int) -> void:
	var start_pos := _player_sprite.position
	var monster_pos := _monster_sprite.position
	var offset := monster_pos - start_pos
	var distance := offset.length()
	var direction := offset / distance if distance > 1.0 else Vector2.RIGHT
	var idle_frame_size: float = _variant.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
	var monster_half_width := idle_frame_size * MONSTER_SCALE * 0.5

	var front_pos := _flash_slash_dash_target(start_pos, monster_pos) # 몬스터 코앞
	var back_pos := monster_pos + direction * (monster_half_width + TRIPLE_HELIX_HIT_GAP) # 몬스터 등 뒤
	var hit_positions := [front_pos, back_pos, front_pos] # 앞→뒤→앞으로 번갈아 "휙휙" 도는 느낌

	var total_damage := monster_hp_before - _manager.monster_hp
	var base_dmg := total_damage / 3
	var remainder := total_damage % 3
	var hit_damages := [base_dmg, base_dmg, base_dmg + remainder] # 나머지는 마지막 일격에 몰아준다

	var hp_step := monster_hp_before
	_message.text = "%s!" % card.card_name

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
		_flash_hit(_monster_sprite)
		_spawn_vfx_sprite("physical", _monster_sprite.position)
		SFXPlayer.play(TRIPLE_HELIX_HIT_SFX[i])

		hp_step -= hit_damages[i]
		_show_popup(_monster_sprite.position, "-%d" % hit_damages[i], DAMAGE_COLOR)
		_animate_hp_bar(_monster_hp_bar, hp_step)
		_monster_hp_bar_label.text = "HP: %d/%d" % [hp_step, _monster_data["max_hp"]]

		await flash_out.finished
		await _wait(TRIPLE_HELIX_SET_GAP)

	var return_tween := create_tween()
	return_tween.tween_property(_player_sprite, "position", start_pos, TRIPLE_HELIX_RETURN_DURATION)
	await return_tween.finished

	_update_monster_hp_text() # 실제 소유자(매니저) 값과 최종적으로 다시 맞춰둔다
	_message.text = "%s! %d 피해!" % [card.card_name, total_damage]
	await _wait(0.2)


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
	var tween := create_tween()
	for i in range(steps):
		var offset := Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tween.tween_property(_actors, "position", offset, SHAKE_STEP_DURATION)
	tween.tween_property(_actors, "position", Vector2.ZERO, SHAKE_STEP_DURATION)


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
