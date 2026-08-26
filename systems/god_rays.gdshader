shader_type canvas_item;
render_mode blend_add;

// 왼쪽 위에서 스며드는 빛줄기. ShadowLayer(shadow_layer.gd)의 GROUND_LEAN/GROUND_SQUASH와 같은
// 광원 방향(왼쪽 위)을 그대로 따라간다 — 그림자가 눕는 방향과 어긋나면 "빛이 두 군데서 온다"처럼
// 보인다(shadow_layer.gd 주석 참고). blend_add로 그려서 아래 화면을 덮지 않고 밝은 부분만 더
// 밝게 얹는다(그림자의 정반대 역할).
//
// [저해상도 SubViewport + nearest 확대를 포기한 이유]
// 처음엔 이 셰이더를 화면 해상도보다 훨씬 작은 SubViewport에 그린 뒤 nearest-neighbor로
// 확대해서 픽셀아트 톤에 맞는 각진 느낌을 내려 했다(god_rays_display.gdshader가 그 마지막
// 합성 단계였다). 작은 디버그 씬에서는 잘 됐는데, 실제 village.tscn(노드가 훨씬 많고 무거운
// 진짜 게임 씬)에 넣어보니 SubViewport의 텍스처 자체는 저해상도로 정상 렌더링되는데
// (SubViewport.get_texture()를 직접 저장해서 확인함), 그걸 화면에 표시하는 TextureRect가
// 어떤 속성을 바꿔도(레이어를 100으로 올려도, 머티리얼을 빼고 새빨간 modulate를 줘도) 화면에
// 전혀 나타나지 않는 원인 불명의 문제가 있었다 — 반면 이 셰이더를 SubViewport 없이 화면
// ColorRect에 바로 걸면 같은 village.tscn에서도 정상적으로 보였다. 실제로 보이는 게 더
// 중요해서, 저해상도 확대 트릭은 포기하고 이 셰이더를 다시 화면에 직접 그린다(각진 느낌
// 대신 매끈한 그라데이션이 되지만, 노이즈/페더링/국소 배치는 그대로 유지된다).
//
// [화면 전체가 아니라 국소적인 틈새 몇 곳으로만]
// 처음엔 화면 전체를 덮는 균일한 사선 줄무늬였는데, "너무 뿌옇고 화면 전체를 덮는 필터 같다"는
// 피드백을 받았다 — 실제 나무 캐노피 틈새로 스며드는 빛은 특정 지점에서만 보이지 화면 전체에
// 고르게 깔리지 않는다. 그래서 leak_pos 여러 곳을 빛 방향으로 길쭉한 타원 마스크로 잘라, 그
// 안에서만 줄무늬가 보이게 한다. 처음엔 마을-숲 경로 3곳만 있었는데, "동굴 가는 길/마을
// 곳곳에도 뿌려달라"는 요청으로 LEAK_COUNT를 늘려 자리를 더 추가했다(god_rays.gd 참고).
//
// [간격/두께에 노이즈]
// 딱 떨어지는 균일한 간격의 줄무늬는 "인위적인 바코드"처럼 보인다는 피드백이 있어, 밴드마다
// hash11()로 위치/두께를 살짝 흔든다.
//
// [블룸과의 관계]
// 처음엔 WorldEnvironment/Glow + viewport/hdr_2d=true로 이 색을 일부러 1.0 넘게 그려 Glow
// 문턱을 넘기려 했는데, hdr_2d를 켜면 이 프로젝트의 2D 렌더링 전체가 훨씬 어두워지는 심각한
// 부작용이 있어(실제로 렌더링해서 발견) 그 접근 자체를 접었다(bloom_layer.gdshader 주석 참고).
// 지금은 색을 1.0 안쪽으로 두고, bloom_layer.gdshader(SCREEN_TEXTURE 기반, HUD보다 낮은
// layer에서만 동작)가 이미 밝은 화면 영역에 한해 알아서 옅게 번지게 해준다 — 이 셰이더는
// 그저 "빛줄기 모양"만 그리면 된다.

uniform vec3 ray_color : source_color = vec3(1.0, 0.92, 0.65);
uniform float ray_count = 4.0;
uniform float ray_width = 0.16; // 밴드 하나의 폭 (대각 좌표 0~1 주기 대비 비율)
uniform float ray_softness = 0.7; // 가장자리를 얼마나 부드럽게 페이드할지 — 바코드처럼 안 보이게 넉넉히
uniform float band_jitter_pos = 0.35; // 밴드 위치를 주기의 이만큼(비율)까지 흔든다
uniform float band_jitter_width = 0.5; // 밴드 두께를 이 비율만큼까지 들쭉날쭉하게
uniform float base_alpha = 0.065; // 평상시 밝기 — 0.09(원본)와 0.045(1차 튜닝, "안 보인다"는 피드백) 사이
uniform float pulse_amount = 0.4; // base_alpha 대비 얼마나 더 밝아졌다 어두워졌다 할지(비율)
uniform float pulse_period = 10.0; // 초 — 아주 느리게 숨쉬듯이
uniform vec2 light_dir = vec2(0.40, 0.45); // shadow_layer.gd의 GROUND_LEAN/GROUND_SQUASH와 같은 방향

// 나무 캐노피 틈새 자리들. leak_pos는 화면 UV(0~1), leak_along/leak_across는 빛 방향/수직
// 방향으로의 반경(타원의 "장반경/단반경"에 해당) — 빛 방향으로 길쭉하게 늘여 자연스러운 틈새
// 모양을 낸다. 개수는 god_rays.gd의 LEAK_WORLD_POSITIONS 배열 길이와 정확히 맞춰야 한다
// (다르면 set_shader_parameter가 배열 길이를 그대로 밀어넣어 여기 상수 6과 어긋난다).
// Godot는 uniform 배열에 기본값을 줄 수 없어(셰이더 컴파일 에러), 실제 값은 god_rays.gd의
// _ready()/_process()에서 set_shader_parameter로 채운다
const int LEAK_COUNT = 6;
uniform vec2 leak_pos[LEAK_COUNT];
uniform float leak_along[LEAK_COUNT];
uniform float leak_across[LEAK_COUNT];

const float TAU_ = 6.28318530718;

// 값 하나로 0~1 사이 의사난수 하나를 만드는 값싼 해시 — 밴드마다 다른(하지만 매 프레임 같은)
// 위치/두께 흔들림을 주는 데만 쓰므로 진짜 난수일 필요는 없다
float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	vec2 dir = normalize(light_dir);
	vec2 perp = vec2(-dir.y, dir.x);

	// 빛 방향에 수직인 축으로 투영해 "몇 번째 띠인지"를 구하고, 밴드마다 위치/두께를 살짝 흔든다
	float coord = dot(SCREEN_UV, perp) * ray_count;
	float band_id = floor(coord);
	float pos_jitter = (hash11(band_id) - 0.5) * band_jitter_pos;
	float width_jitter = 1.0 + (hash11(band_id + 91.7) - 0.5) * band_jitter_width;
	float local = fract(coord) - 0.5 - pos_jitter;
	float center_dist = abs(local);
	float half_width = ray_width * 0.5 * width_jitter;
	float shaft = 1.0 - smoothstep(half_width, half_width + ray_softness * 0.5, center_dist);

	// 캐노피 틈새 마스크: 가장 가까운 틈새 하나만 기여하는 게 아니라, 여러 틈새 중 가장 강한
	// 것을 취한다(더해버리면 틈새가 겹치는 자리만 부자연스럽게 밝아진다)
	float leak_mask = 0.0;
	for (int i = 0; i < LEAK_COUNT; i++) {
		vec2 local_uv = SCREEN_UV - leak_pos[i];
		float along = dot(local_uv, dir) / max(leak_along[i], 0.001);
		float across = dot(local_uv, perp) / max(leak_across[i], 0.001);
		float d = length(vec2(along, across));
		leak_mask = max(leak_mask, 1.0 - smoothstep(0.55, 1.0, d));
	}

	float pulse = 1.0 + sin(TIME * TAU_ / pulse_period) * pulse_amount;
	float alpha = shaft * leak_mask * base_alpha * pulse;

	COLOR = vec4(ray_color * alpha, 1.0);
}
