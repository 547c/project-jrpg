extends CanvasLayer

# 게임 전체에 약한 블룸(밝은 부분이 은은하게 번지는 효과)을 켜는 오토로드. 자세한 설계 이유
# (WorldEnvironment/Glow 대신 SCREEN_TEXTURE 셰이더를 쓰는 이유, HUD에 영향이 없는 이유)는
# bloom_layer.gdshader 주석 참고. layer=5, HUD(layer 8)보다 낮아 늘 HUD 아래에서만 작동한다.
