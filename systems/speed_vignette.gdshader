shader_type canvas_item;

// 달리는 동안만 켜지는 화면 가장자리 비네트+블러. 오버월드 카메라 줌아웃(player.gd)과 짝을 이루는
// 속도감 연출이라 여기서도 은은하게 — 액션 게임처럼 화면 전체를 흔들거나 어둡게 조이지 않는다.
//
// strength는 GDScript(systems/speed_vignette.gd)가 Tween으로 0<->1을 오가며 서서히 켜고 끈다.
// 이 셰이더 자체는 strength=0일 때 화면을 그대로 되돌려 그리므로(연산은 계속 돌아도) 평소엔
// 완전히 안 보인다 — 켜질 때만 SpeedVignette가 노드를 visible=true로 바꾼다.
//
// [왜 UI에는 안 닿는가]
// 이 셰이더가 붙는 ColorRect는 systems/speed_vignette.tscn(CanvasLayer layer=3) 하나뿐이고,
// HUD(layer 5)/대화창/메뉴는 전부 그보다 위 레이어에서 따로 합성된다. Godot은 CanvasLayer를
// 레이어 순서대로 각자 완결된 상태로 그리므로, 이 레이어가 SCREEN_TEXTURE로 훔쳐보는 화면에는
// 아직 UI가 없다 — 정의상 UI를 건드릴 수가 없다.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.6; // 이 반경 안쪽은 전혀 손대지 않는다
uniform float outer_radius : hint_range(0.0, 1.5) = 1.05; // 이 반경 바깥이 최대 강도
uniform float blur_amount : hint_range(0.0, 8.0) = 4.0; // 가장자리 블러 반경(px 단위)
uniform float darken : hint_range(0.0, 1.0) = 0.4; // 가장자리 최대 어둡기

void fragment() {
	// 화면비를 보정해서 비네트가 타원이 아니라 원형으로 균일하게 퍼지게 한다
	vec2 centered = (SCREEN_UV - 0.5) * 2.0;
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(centered);
	float edge = smoothstep(inner_radius, outer_radius, dist) * strength;

	vec4 sharp = texture(screen_texture, SCREEN_UV);

	// Godot 셰이더는 fragment()에서 조기 return을 허용하지 않아, edge가 0이어도 블러 샘플링
	// 자체는 항상 돈다 — 다만 mix()가 그 결과를 전부 버리고 sharp만 쓰므로 화면은 그대로다
	// (조금 더 도는 연산 자체를 아예 없애고 싶다면 SpeedVignette.gd가 visible=false로 이 노드를
	// 통째로 꺼두는 쪽을 쓴다 — 실제 렌더 비용 절감은 거기서 이뤄진다)
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

	vec4 result = mix(sharp, blurred, edge);
	result.rgb *= mix(1.0, 1.0 - darken, edge);
	COLOR = result;
}
