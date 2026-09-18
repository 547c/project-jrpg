shader_type canvas_item;
render_mode blend_add;

// 로고 글자는 이미 흰색이라 더해도 밝아지지 않는다. 그래서 빛은 글자 테두리 바깥 하늘 쪽으로 번지게 그린다
uniform vec4 logo_rect = vec4(0.0397, 0.0864, 0.4761, 0.3488);
uniform float texel_per_px = 4.69;
uniform float cycle = 7.0;
uniform float sweep_time : hint_range(0.2, 5.0) = 1.7;
uniform float band_width : hint_range(2.0, 60.0) = 22.0;
uniform float slant : hint_range(-2.0, 2.0) = 0.55;
uniform float shine_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec3 shine_color : source_color = vec3(1.0, 0.84, 0.55);
uniform float glint_strength : hint_range(0.0, 2.0) = 1.0;
uniform float glint_cell : hint_range(8.0, 80.0) = 26.0;
uniform float glint_period : hint_range(1.0, 30.0) = 9.0;
uniform float glint_life : hint_range(0.01, 0.5) = 0.07;
uniform vec3 glint_color : source_color = vec3(1.0, 0.97, 0.9);

#define GLYPH(uv) smoothstep(0.7, 0.9, dot(texture(TEXTURE, uv).rgb, vec3(0.299, 0.587, 0.114)))

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
	COLOR = vec4(0.0);
	if (all(greaterThan(UV, logo_rect.xy)) && all(lessThan(UV, logo_rect.zw))) {
		vec2 px_uv = TEXTURE_PIXEL_SIZE * texel_per_px;
		vec2 px = (UV - logo_rect.xy) / px_uv;
		vec2 span = (logo_rect.zw - logo_rect.xy) / px_uv;
		vec3 light = vec3(0.0);

		float t = mod(TIME, cycle) / sweep_time;
		if (shine_strength > 0.0 && t < 1.0) {
			float margin = 3.0 * band_width;
			float head = mix(-margin, span.x + span.y * slant + margin, smoothstep(0.0, 1.0, t));
			float d = px.x + px.y * slant - head;
			float band = exp(-d * d / (band_width * band_width));
			if (band > 0.01) {
				float ring = 0.0;
				for (int i = 0; i < 8; i++) {
					float a = float(i) * 0.7853982 + 0.39;
					vec2 dir = vec2(cos(a), sin(a)) * px_uv;
					ring += 0.5 * GLYPH(UV + dir * 3.0) + 0.3 * GLYPH(UV + dir * 6.0) + 0.2 * GLYPH(UV + dir * 10.0);
				}
				float halo = max(GLYPH(UV), min(1.0, ring / 8.0 * 1.8));
				float core = exp(-d * d / (0.1 * band_width * band_width));
				vec2 inside = min(px, span - px);
				float beam = 0.06 * smoothstep(0.0, 30.0, min(inside.x, inside.y));
				light += shine_color * (halo * (0.9 * band + 0.6 * core) + beam * band) * shine_strength;
			}
		}

		if (glint_strength > 0.0) {
			vec2 cell = floor(px / glint_cell);
			vec2 h = hash2(cell);
			float gt = fract(TIME / (glint_period * (0.8 + 0.4 * h.y)) + h.x * 7.13);
			if (gt < glint_life) {
				vec2 centre = floor((cell + 0.2 + 0.6 * h) * glint_cell) + 0.5;
				vec2 cuv = logo_rect.xy + centre * px_uv;
				float near = GLYPH(cuv)
					+ GLYPH(cuv + vec2(4.0, 0.0) * px_uv) + GLYPH(cuv - vec2(4.0, 0.0) * px_uv)
					+ GLYPH(cuv + vec2(0.0, 4.0) * px_uv) + GLYPH(cuv - vec2(0.0, 4.0) * px_uv);
				if (near > 0.5) {
					float env = sin(3.1415927 * gt / glint_life);
					float arm = 1.0 + 4.0 * env;
					vec2 q = abs(floor(px) + 0.5 - centre);
					float star = 0.0;
					if (q.y < 0.5) star = max(star, 1.0 - q.x / (arm + 1.0));
					if (q.x < 0.5) star = max(star, 1.0 - q.y / (arm + 1.0));
					light += glint_color * max(star, 0.0) * env * glint_strength;
				}
			}
		}

		COLOR = vec4(min(light, vec3(1.0)), 1.0);
	}
}
