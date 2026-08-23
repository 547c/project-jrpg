shader_type canvas_item;

// 화면 전체를 덮는 검은 막에 플레이어 주변만 원형으로 구멍을 뚫어 시야를 만든다.
// 좌표는 전부 "화면 픽셀" 기준 — 스크립트가 월드 좌표를 카메라/줌이 반영된 화면 좌표로 바꿔 넘긴다.

const int MAX_GLOWS = 8;

uniform vec2 screen_size = vec2(1152.0, 648.0);
uniform vec2 player_pos = vec2(576.0, 324.0);
uniform float inner_radius = 120.0; // 이 안쪽은 어둠이 전혀 없음
uniform float outer_radius = 330.0; // 이 바깥은 완전한 검은색

// 몬스터 글로우. 지금 필드에 없는(리젠 대기 중) 몬스터 자리는 스크립트가 화면 밖 좌표로 채워
// 기여가 자연히 0이 되게 하므로, 셰이더에서 개수를 따로 분기하지 않는다
uniform vec2 glow_positions[MAX_GLOWS];
uniform float glow_radius = 90.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec3 glow_color : source_color = vec3(0.55, 0.78, 1.0);
uniform float glow_tint_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 px = UV * screen_size;

	float darkness = smoothstep(inner_radius, outer_radius, distance(px, player_pos));

	// 글로우가 겹쳐도 과하게 밝아지지 않도록 합이 아니라 가장 강한 값만 취한다
	float glow = 0.0;
	for (int i = 0; i < MAX_GLOWS; i++) {
		glow = max(glow, 1.0 - smoothstep(0.0, glow_radius, distance(px, glow_positions[i])));
	}

	// 글로우는 어둠을 완전히 걷어내지 않고 일부만 덜어낸다 — 멀리서도 "흐릿하게는 보이는" 정도
	float alpha = darkness * (1.0 - glow * glow_strength);
	// 덜어낸 자리에 옅은 빛을 얹어 "어둠 속에서 빛나는 무언가"로 읽히게 한다.
	// darkness를 곱해서, 플레이어 시야 안(이미 밝은 곳)에는 빛 얼룩이 남지 않게 한다
	vec3 col = glow_color * (glow * darkness * glow_tint_strength);

	COLOR = vec4(col, alpha);
}
