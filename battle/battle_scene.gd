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
}

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
# 마나 소모량을 넣을 마름모 배지 (16x16). 마나는 언제나 마법 자원이라 카드 색과 무관하게 파랑 고정
const CARD_MANA_BADGE_REGION := Rect2(432, 640, 16, 16)

const CARD_SIZE := Vector2(138, 221) # HandArea의 각 카드 슬롯 크기 (.tscn의 Card1~5 offset과 일치시켜야 함)
const CARD_ENABLED_MODULATE := Color(1, 1, 1, 1)
const CARD_DISABLED_MODULATE := Color(0.5, 0.5, 0.5, 0.85) # 과열/마나부족 카드를 흐리게 (기존 disabled 느낌 유지)

# ── 카드 드로우 뒤집기 연출 ──────────────────────────────────────────────────
const DRAW_STAGGER := 0.08 # 카드마다 뒤집기 시작을 이만큼씩 늦춰 순서대로 펼쳐지는 느낌을 낸다
const FLIP_HALF_DURATION := 0.15 # 뒷면->접힘, 접힘->앞면 각 구간 길이 (왕복 총 0.3초)

# ── 카드 마우스 호버 연출 ────────────────────────────────────────────────────
const HOVER_SCALE := 1.15
const HOVER_RISE := 14.0 # 확대와 함께 위로 떠오르는 픽셀 수
const HOVER_DURATION := 0.12

@onready var _actors: Node2D = $View/Actors
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
var _vfx_frames: Dictionary = {} # "physical"/"magic"/"heal"/"mana"/"defend"/"dodge" -> SpriteFrames

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

	for key in VFX_CONFIG:
		_vfx_frames[key] = _build_vfx_frames(VFX_CONFIG[key])


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


func _on_enemy_turn_resolved(damage_taken: int, dodged: bool) -> void:
	_last_enemy_damage = damage_taken
	_last_enemy_dodged = dodged


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
	_last_card_damage = 0

	if not _manager.play_card(card):
		_mode = Mode.ACTION
		await _refresh_all()
		return

	await _animate_card(card, hp_before, mana_before)

	await _refresh_all()

	if _outcome == "victory":
		_finish_victory()
		return

	_mode = Mode.ACTION
	_set_inputs_enabled(true)


# 카드 종류별 연출. 데미지는 매니저가 계산한 최종 피해(_last_card_damage)를 그대로 표시하고,
# 회복량은 GameState 값의 전후 차이로 실제 적용된 만큼만 보여준다.
# 이펙트/사운드는 여기서 카드별로 직접 부르지 않고 _vfx_key_for_card()로 종류를 정한 뒤
# _play_card_vfx()에서 이펙트+사운드를 함께 재생한다 — 화면 흔들림만 DAMAGE에서 따로 켠다
func _animate_card(card: Card, hp_before: int, mana_before: int) -> void:
	match card.effect:
		Card.EffectType.DAMAGE:
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


# card.effect(+물리/마법 구분)에 맞는 VFX/SFX 키를 고른다. _card_style_key()와 판단 기준은 같지만
# (물리=빨강/마법=파랑 계열) "회복"과 "마나"를 서로 다른 키로 나눈다는 점이 다르다 — 카드 프레임은
# 둘 다 초록으로 묶지만, 타격 이펙트까지 같으면 두 결과를 구분하기 어렵기 때문
func _vfx_key_for_card(card: Card) -> String:
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
		_:
			return ""


# target 위치에 카드에 맞는 이펙트를 한 번 재생하고, 어울리는 타격음을 SFXPlayer로 함께 튼다.
# 이펙트 스프라이트는 재생이 끝나면(animation_finished) 스스로 사라진다
func _play_card_vfx(card: Card, target: Node2D) -> void:
	var key := _vfx_key_for_card(card)
	if key == "" or not _vfx_frames.has(key):
		return

	if VFX_SFX.has(key):
		SFXPlayer.play(VFX_SFX[key])

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _vfx_frames[key]
	sprite.position = target.position
	sprite.scale = Vector2.ONE * VFX_DISPLAY_SCALE
	sprite.z_index = 15
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(sprite)
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play("play")


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

	_set_card_parts_visible(i, true)
	frame.texture = _card_front_textures[style_key]
	_card_icon_frames[i].texture = _card_icon_frame_textures[style_key]
	_card_name_banners[i].texture = _card_name_banner_textures[style_key]
	icon.texture = _skill_icon_textures.get(card.effect)
	name_label.text = card.card_name
	desc_label.text = desc

	# 마나 소모량은 설명 문장에 끼워 넣지 않고 왼쪽 아래 마름모 배지로 뺀다 — 참고 이미지의
	# 모서리 배지와 같은 방식이고, 좁은 설명칸도 한 줄 아낀다. 마나를 안 쓰는 카드면 배지째 숨긴다
	var mana_cost := card.get_mana_cost()
	_card_mana_badges[i].visible = mana_cost > 0
	_card_mana_labels[i].visible = mana_cost > 0
	if mana_cost > 0:
		_card_mana_badges[i].texture = _card_mana_badge_texture
		_card_mana_labels[i].text = str(mana_cost)

	btn.disabled = not playable or _mode != Mode.ACTION
	_card_wrappers[i].modulate = CARD_ENABLED_MODULATE if playable else CARD_DISABLED_MODULATE
	if not playable:
		_reset_card_hover(i) # 커서를 올려둔 채 카드가 과열/마나부족으로 바뀌면 확대를 풀어준다
	_apply_card_tier_visuals(_card_wrappers[i], card)


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
	if not shown:
		_card_mana_badges[i].visible = false
		_card_mana_labels[i].visible = false


func _card_style_key(card: Card) -> String:
	match card.effect:
		Card.EffectType.DAMAGE:
			return "blue" if card.color == Card.CardColor.MAGIC else "red"
		Card.EffectType.HEAL_HP, Card.EffectType.RESTORE_MANA:
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
	icon.visible = false
	name_label.visible = false
	desc_label.visible = false
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


# 카드 티어별 시각 연출(상위 티어 광채/파티클 등)을 붙일 지점. 아직 티어2/3 카드도, 연출도 없어
# 지금은 어느 티어든 기본 외형 그대로 두지만, card.tier로 분기할 자리는 여기 하나로 정해둔다.
# _refresh_hand_buttons()가 손패를 갱신할 때마다 카드마다 한 번씩 부르므로, 이 함수만 채우면
# 손패 전체에 자동으로 반영된다.
#
# [연출을 실제로 붙일 때 주의] 손패 5칸은 매 턴 같은 wrapper 노드를 재사용한다 — 상위 티어 카드가
# 있던 자리에 다음 턴 티어1 카드가 들어올 수 있으므로, 켜는 분기뿐 아니라 "끄는" 기본 분기도
# 반드시 함께 채워야 이전 카드의 연출이 남지 않는다
func _apply_card_tier_visuals(_wrapper: Control, card: Card) -> void:
	match card.tier:
		Card.CardTier.TIER_2, Card.CardTier.TIER_3:
			pass # TODO: 상위 티어 강조 연출 (아직 해당 티어 카드가 없음)
		_:
			pass # TIER_1 — 기본 외형


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
	# 하단 UI가 차지하는 영역(카드가 커지면서 260px까지 올라옴)에 발이 가리지 않도록 배우를
	# 위쪽으로 배치한다. 나무 판자 배경이 사라져 UI가 배경 위에 떠 있으므로, 겹치면 바로 티가 난다
	var vp := get_viewport().get_visible_rect().size
	_player_sprite.position = Vector2(vp.x * 0.22, vp.y * 0.45)
	_monster_sprite.position = Vector2(vp.x * 0.72, vp.y * 0.24)

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
func _shake_actors() -> void:
	var tween := create_tween()
	for i in range(SHAKE_STEPS):
		var offset := Vector2(randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT), randf_range(-SHAKE_AMOUNT, SHAKE_AMOUNT))
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
