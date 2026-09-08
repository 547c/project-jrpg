shader_type canvas_item;

// 이 노드가 그려지기 전까지 화면에 그려진 것(숲 배경+캐릭터)만 흐려진다 —
// 이 노드보다 나중에 그려지는 HUD는 이 셰이더와 무관하게 항상 또렷하다.
// Godot 4.3+에서 SCREEN_TEXTURE 내장 변수가 빠지고 hint_screen_texture 유니폼으로 대체됨
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_amount : hint_range(0.0, 6.0) = 3.0;
// 화면 네 변에서 이 비율만큼 안쪽까지가 "가장자리"로 취급되어 흐려진다. 그 안쪽은 완전히 또렷하다
uniform float edge_margin : hint_range(0.0, 0.5) = 0.22;

vec4 blur_sample(sampler2D tex, vec2 uv, vec2 step) {
	vec4 sum = vec4(0.0);
	sum += texture(tex, uv + vec2(-3.0, 0.0) * step) * 0.06;
	sum += texture(tex, uv + vec2(-2.0, 0.0) * step) * 0.09;
	sum += texture(tex, uv + vec2(-1.0, 0.0) * step) * 0.12;
	sum += texture(tex, uv) * 0.16;
	sum += texture(tex, uv + vec2(1.0, 0.0) * step) * 0.12;
	sum += texture(tex, uv + vec2(2.0, 0.0) * step) * 0.09;
	sum += texture(tex, uv + vec2(3.0, 0.0) * step) * 0.06;
	sum += texture(tex, uv + vec2(0.0, -3.0) * step) * 0.06;
	sum += texture(tex, uv + vec2(0.0, -2.0) * step) * 0.09;
	sum += texture(tex, uv + vec2(0.0, -1.0) * step) * 0.12;
	sum += texture(tex, uv + vec2(0.0, 1.0) * step) * 0.12;
	sum += texture(tex, uv + vec2(0.0, 2.0) * step) * 0.09;
	sum += texture(tex, uv + vec2(0.0, 3.0) * step) * 0.06;
	return sum / 1.24;
}

void fragment() {
	vec2 step = SCREEN_PIXEL_SIZE * blur_amount;
	vec4 sharp = texture(screen_tex, SCREEN_UV);
	vec4 blurred = blur_sample(screen_tex, SCREEN_UV, step);

	// 네 변 각각에서 가장자리까지의 거리(0=가장자리, edge_margin=그 안쪽 경계)를 재서
	// 비네트처럼 안으로 갈수록 또렷해지게 부드럽게 섞는다. x/y를 화면비로 보정해
	// 가로/세로 화면비가 달라도 여백 느낌이 고르게 나오도록 한다
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float from_left = UV.x;
	float from_right = 1.0 - UV.x;
	float from_top = UV.y * aspect;
	float from_bottom = (1.0 - UV.y) * aspect;
	float dist = min(min(from_left, from_right), min(from_top, from_bottom));
	float blur_strength = 1.0 - smoothstep(0.0, edge_margin, dist);

	COLOR = mix(sharp, blurred, blur_strength);
}
