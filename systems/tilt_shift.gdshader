shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float inner_band : hint_range(0.0, 1.0) = 0.32;
uniform float outer_band : hint_range(0.0, 1.0) = 0.62;
uniform float blur_amount : hint_range(0.0, 16.0) = 3.0;

void fragment() {
	float dist = abs(SCREEN_UV.y - 0.5) * 2.0;
	float edge = smoothstep(inner_band, outer_band, dist);

	vec4 sharp = texture(screen_texture, SCREEN_UV);
	vec2 texel = SCREEN_PIXEL_SIZE * blur_amount;
	vec4 blurred = sharp;
	blurred += texture(screen_texture, SCREEN_UV + vec2(texel.x, 0.0));
	blurred += texture(screen_texture, SCREEN_UV - vec2(texel.x, 0.0));
	blurred += texture(screen_texture, SCREEN_UV + vec2(0.0, texel.y));
	blurred += texture(screen_texture, SCREEN_UV - vec2(0.0, texel.y));
	blurred += texture(screen_texture, SCREEN_UV + texel);
	blurred += texture(screen_texture, SCREEN_UV - texel);
	blurred += texture(screen_texture, SCREEN_UV + vec2(texel.x, -texel.y));
	blurred += texture(screen_texture, SCREEN_UV + vec2(-texel.x, texel.y));
	blurred /= 9.0;

	COLOR = mix(sharp, blurred, edge);
}
