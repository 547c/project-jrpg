shader_type canvas_item;

// 전경 잎(카메라 바로 앞을 스쳐 지나가는 큰 잎) 전용 블러. speed_vignette.gdshader와 같은
// 저비용 8방향 평균 블러 기법을 재사용하되, 화면 전체(SCREEN_TEXTURE)가 아니라 이 스프라이트
// 자신의 텍스처(TEXTURE)에 적용한다 — "초점이 안 맞을 만큼 카메라에 가깝다"는 느낌을 그림
// 자체를 부드럽게 만들어서 낸다(화면 전체를 흐리면 배경까지 흐려져 버려서 목적이 다르다).
//
// [modulate 대신 leaf_color 유니폼을 쓰는 이유]
// fragment()에서 COLOR를 직접 계산해 덮어쓰면, Godot이 원래 자동으로 채워주는
// texture(TEXTURE,UV)*modulate 결과는 사라진다 — 그래서 색조(랜덤 초록 틴트)와 알파(페이드)를
// 이 유니폼 하나로 직접 받아 블러 결과에 곱한다. GDScript 쪽은 sprite.modulate 대신
// material.set_shader_parameter("leaf_color", ...)로 갱신한다.

uniform float blur_amount : hint_range(0.0, 4.0) = 1.6; // 텍셀 단위 블러 반경
uniform vec4 leaf_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE * blur_amount;
	vec4 sum = texture(TEXTURE, UV);
	sum += texture(TEXTURE, UV + vec2(texel.x, 0.0));
	sum += texture(TEXTURE, UV - vec2(texel.x, 0.0));
	sum += texture(TEXTURE, UV + vec2(0.0, texel.y));
	sum += texture(TEXTURE, UV - vec2(0.0, texel.y));
	sum += texture(TEXTURE, UV + texel);
	sum += texture(TEXTURE, UV - texel);
	sum += texture(TEXTURE, UV + vec2(texel.x, -texel.y));
	sum += texture(TEXTURE, UV + vec2(-texel.x, texel.y));
	sum /= 9.0;
	COLOR = sum * leaf_color;
}
