shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 cor_contorno : source_color = vec4(1.0);
uniform sampler2D textura_alpha : source_color, filter_nearest, repeat_enable;
uniform bool tem_textura_alpha = false;
uniform bool usar_alpha = false;
uniform float alpha_cor_base = 1.0;
uniform float alpha_cutout_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);
uniform float espessura_contorno : hint_range(0.001, 0.15, 0.001) = 0.025;
uniform float intensidade_faixa : hint_range(0.0, 8.0, 0.05) = 2.5;
uniform float largura_faixa : hint_range(0.005, 0.5, 0.005) = 0.08;
uniform float velocidade_faixa : hint_range(-3.0, 3.0, 0.01) = 0.45;
uniform float escala_faixa : hint_range(0.1, 12.0, 0.1) = 1.0;
uniform float intensidade_glow : hint_range(0.0, 6.0, 0.05) = 1.0;

varying vec3 pos_local;

void vertex() {
	pos_local = VERTEX;
	VERTEX += NORMAL * espessura_contorno;
}

void fragment() {
	vec2 uv_material = UV * uv1_scale.xy + uv1_offset.xy;
	float alpha_textura = tem_textura_alpha ? texture(textura_alpha, uv_material).a : 1.0;
	ALPHA = usar_alpha ? alpha_textura * alpha_cor_base : 1.0;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutout_threshold;
	float fase = fract(pos_local.y * escala_faixa - TIME * velocidade_faixa);
	float distancia_faixa = min(fase, 1.0 - fase);
	float faixa = 1.0 - smoothstep(largura_faixa * 0.5, largura_faixa, distancia_faixa);
	float brilho_faixa = 1.0 + faixa * intensidade_faixa * intensidade_glow;
	// Em unshaded, mantenha o pulso HDR em ALBEDO para o Glow do ambiente capturá-lo.
	ALBEDO = cor_contorno.rgb * brilho_faixa;
}
