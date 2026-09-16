shader_type canvas_item;
render_mode blend_add;

// 배경 그림 위에 겹쳐 깔고, "하늘에 박힌 작은 밝은 점"만 골라 더해 그린다. 별을 따로 그리지 않고
// 원본 픽셀을 그대로 밝혔다 어둡게 하는 방식이라 배경 에셋을 건드리지 않는다.
//
// 로고와 번개까지 같이 깜빡이면 안 되므로, 밝기만 보지 않고 "좌우가 어두운가"를 함께 본다 —
// 별은 어두운 하늘에 박힌 1~2픽셀이라 옆이 어둡고, 로고/번개는 덩어리라 옆도 밝다.
uniform float strength : hint_range(0.0, 2.0) = 0.75;
uniform float speed : hint_range(0.1, 5.0) = 1.1;
uniform float star_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float neighbor_ceiling : hint_range(0.0, 1.0) = 0.24;
uniform float sample_offset : hint_range(0.0005, 0.01) = 0.0024;
uniform float sky_limit : hint_range(0.0, 1.0) = 0.46;
uniform float cells : hint_range(16.0, 512.0) = 96.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	COLOR = vec4(0.0);
	// 하늘 아래는 계산 자체를 건너뛴다. 이 연출에서 유일하게 비싼 부분이 "거대한 원본 텍스처를
	// 픽셀마다 여러 번 읽는 것"이라, 별이 없는 구간을 빼는 것만으로 비용이 절반 아래로 떨어진다
	if (UV.y < sky_limit) {
		vec4 src = texture(TEXTURE, UV);
		float here = luma(src.rgb);
		float around = 0.5 * (
			luma(texture(TEXTURE, UV + vec2(sample_offset, 0.0)).rgb) +
			luma(texture(TEXTURE, UV - vec2(sample_offset, 0.0)).rgb));

		float bright = smoothstep(star_threshold, star_threshold + 0.2, here);
		float isolated = bright * smoothstep(neighbor_ceiling + 0.12, neighbor_ceiling, around);
		float sky = smoothstep(sky_limit, sky_limit - 0.14, UV.y);

		// 한 별의 픽셀들이 따로 놀지 않도록 위상은 칸 단위로 묶어서 뽑는다
		vec2 cell = floor(UV * cells);
		float phase = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
		float pulse = 0.3 + 0.7 * (0.5 + 0.5 * sin(TIME * speed + phase * 6.2831853));

		COLOR = vec4(src.rgb, isolated * sky * pulse * strength);
	}
}
