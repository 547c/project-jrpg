shader_type canvas_item;

// 나뭇잎·풀이 바람에 살랑이는 효과 (나무 프리팹과 식생 프리팹이 함께 쓴다).
// 별도 애니메이션 프레임 없이, 스프라이트 사각형의 위쪽 두 꼭짓점만 좌우로 밀어 통짜 그림을
// 기울인다(전단). 아래쪽(뿌리)은 UV.y가 1이라 전혀 움직이지 않는다.
//
// Sprite2D의 사각형은 꼭짓점이 4개뿐이라 꼭짓점 사이는 어차피 선형 보간된다 — 그래서 pow 같은
// 비선형 가중치를 줘도 의미가 없고, 위 0 / 아래 1의 선형 기울기가 곧 자연스러운 흔들림이 된다.
//
// [타일맵에는 이 방식을 그대로 쓸 수 없다]
// 이 셰이더가 성립하는 건 "스프라이트 하나 = 오브젝트 하나"라서 UV.y가 곧 그 오브젝트 안에서의
// 높이이기 때문이다. 타일맵에 걸면 UV가 타일(칸) 단위로 끊겨, 여러 칸에 걸친 덤불은 칸 경계마다
// 어긋나 찢어져 보인다. 자세한 배경은 docs/map_objects.md의 "타일 레이어에 흔들림" 항목 참고

uniform float sway_strength = 1.7; // 잎 끝의 최대 흔들림 (픽셀)
uniform float sway_speed = 1.1;
// 개체마다 흔들리는 위상을 어긋나게 하는 계수. 월드 좌표에서 뽑으므로 인스턴스마다 머티리얼을
// 따로 만들지 않아도 제각각 흔들린다
uniform float phase_by_position = 0.05;

void vertex() {
	float phase = (MODEL_MATRIX[3].x + MODEL_MATRIX[3].y) * phase_by_position;
	float top = 1.0 - UV.y; // 위쪽(잎) 1 -> 아래쪽(뿌리) 0
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_strength * top;
}
