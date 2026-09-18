shader_type canvas_item;

// 글자 채움과 외곽선을 따로 물들인다 — 채움은 흰빛으로, 어두운 외곽선은 금빛 테로 달아오른다
uniform float cycle = 7.0;
uniform float sweep_delay = 1.5;
uniform float sweep_time : hint_range(0.1, 3.0) = 0.9;
uniform float text_width = 120.0;
uniform float band_width : hint_range(2.0, 40.0) = 12.0;
uniform float slant : hint_range(-2.0, 2.0) = 0.45;
uniform float proximity : hint_range(0.0, 1.0) = 0.0;
uniform float active : hint_range(0.0, 1.0) = 1.0;
uniform vec3 highlight : source_color = vec3(1.0, 0.98, 0.9);
uniform vec3 rim : source_color = vec3(1.0, 0.72, 0.3);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float band = 0.0;
	float t = (mod(TIME, cycle) - sweep_delay) / sweep_time;
	if (t > 0.0 && t < 1.0) {
		float margin = 3.0 * band_width;
		float head = mix(-margin, text_width + 40.0 * slant + margin, t);
		float d = local_pos.x + local_pos.y * slant - head;
		band = exp(-d * d / (band_width * band_width));
	}
	float fill = step(0.3, dot(COLOR.rgb, vec3(0.299, 0.587, 0.114)));
	float lift = clamp(band + proximity * 0.3, 0.0, 1.0) * active;
	COLOR.rgb = mix(COLOR.rgb, mix(rim, highlight, fill), lift * mix(0.85, 0.7, fill));
}
