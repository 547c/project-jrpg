shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec3 warm_tint : source_color = vec3(1.04, 1.0, 0.94);
uniform float contrast : hint_range(0.5, 1.5) = 1.05;
uniform float strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 sharp = texture(screen_texture, SCREEN_UV);
	vec3 graded = (sharp.rgb - 0.5) * contrast + 0.5;
	graded *= warm_tint;
	COLOR = vec4(mix(sharp.rgb, graded, strength), sharp.a);
}
