shader_type canvas_item;

uniform vec2 scroll_speed = vec2(0.6, 0.35);
uniform float distort_amount = 0.6;
uniform float sparkle_cell_size = 24.0;
uniform float sparkle_speed = 1.2;
uniform float sparkle_strength = 0.6;

varying vec2 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	vec2 offset = vec2(
		sin(TIME * scroll_speed.x + UV.y * 20.0),
		cos(TIME * scroll_speed.y + UV.x * 20.0)
	) * distort_amount * TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, UV + offset);

	vec2 grid = world_pos / sparkle_cell_size;
	vec2 cell = floor(grid);
	vec2 cell_uv = fract(grid);

	vec2 point_pos = vec2(hash21(cell), hash21(cell + 17.3));
	float dot_shape = smoothstep(0.15, 0.0, length(cell_uv - point_pos));

	float phase = hash21(cell + 5.1) * TAU;
	float twinkle = pow(sin(TIME * sparkle_speed + phase) * 0.5 + 0.5, 10.0);

	float sparkle = dot_shape * twinkle * sparkle_strength;

	COLOR = vec4(tex.rgb + sparkle, tex.a);
}
