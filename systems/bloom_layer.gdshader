shader_type canvas_item;

// 화면에서 이미 밝은 부분만 골라 옅게 흐려 다시 더해주는 저비용 2D 블룸.
//
// [Godot의 WorldEnvironment/Glow를 그냥 켜지 않은 이유]
// 처음엔 실제로 WorldEnvironment.glow_enabled + project.godot의 viewport/hdr_2d=true 조합으로
// 시도했다. 이 프로젝트는 3D 콘텐츠가 없는 순수 2D라 Glow가 적용되려면 숨겨진 Camera3D로 3D
// 렌더 경로를 억지로 깨워야 했는데(bloom_controller.gd에 있던 방식), hdr_2d=true를 켜면 2D
// 콘텐츠 전체가 "제대로 보정되지 않은 선형(linear) 색공간"으로 다뤄지면서 흰색/검은색이 아닌
// 모든 중간 색이 실제로 렌더링해서 확인해보니 원래보다 훨씬 어둡게 나오는 심각한 부작용이
// 있었다(예: (0.12,0.16,0.09) 배경이 (0.01,0.02,0.008) 수준으로 찌그러짐) — 즉 게임 전체의
// 색이 다 어두워지는 회귀였다. 그 문제를 감수할 가치가 없어 Glow 자체를 포기했다.
//
// [SCREEN_TEXTURE 기반으로 다시 만든 이유]
// 이 방식은 speed_vignette.gdshader와 완전히 같은 안전장치를 그대로 얻는다 — 이 셰이더가 붙는
// ColorRect는 HUD(layer 6)보다 낮은 layer 5에서 그려지므로, 여기서 SCREEN_TEXTURE로 훔쳐보는
// 화면에는 정의상 아직 HUD가 없다. hdr_2d도 필요 없어 위 색 어두워짐 문제도 아예 생기지 않는다.
// 블러도 speed_vignette.gdshader와 같은 9탭 수동 블러를 그대로 재사용한다(이미 이 렌더러에서
// 검증된 방식).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float threshold : hint_range(0.0, 1.0) = 0.75; // 이 밝기(휘도) 이상만 번진다
uniform float intensity : hint_range(0.0, 2.0) = 0.45; // 번지는 양 — "너무 약하다"는 피드백으로 0.35에서 소폭 상향
uniform float blur_amount : hint_range(0.0, 16.0) = 3.0; // 블러 반경(px 단위)

void fragment() {
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

	float luminance = dot(blurred.rgb, vec3(0.299, 0.587, 0.114));
	float mask = smoothstep(threshold, 1.0, luminance);
	vec3 glow = blurred.rgb * mask * intensity;

	COLOR = vec4(sharp.rgb + glow, sharp.a);
}
