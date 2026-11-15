shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D textura_original : source_color, filter_nearest, repeat_enable;
uniform sampler2D mascara_detalhes : filter_nearest, repeat_enable;
uniform bool tem_textura = false;
uniform bool tem_mascara_detalhes = false;
uniform bool usar_extracao_automatica = true;
uniform vec4 cor_base : source_color = vec4(1.0);
uniform vec2 tamanho_textura = vec2(512.0, 512.0);
uniform float escala_amostragem : hint_range(0.25, 8.0, 0.05) = 1.0;
uniform bool escala_automatica = true;
uniform float limiar_luminancia : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float forca_linhas : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float limiar_borda : hint_range(0.0, 2.0, 0.01) = 0.5;
uniform float contraste_mascara : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float alpha_cutout_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform bool usar_alpha = false;
uniform float intensidade_rim : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float largura_rim : hint_range(0.01, 1.0, 0.01) = 0.12;
uniform bool realcar_areas_claras = false;
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);

varying vec2 uv_base;

vec3 cor_linear(vec2 uv) {
	return texture(textura_original, uv).rgb * cor_base.rgb;
}

vec3 cor_perceptual(vec2 uv) {
	vec3 rgb = max(cor_linear(uv), vec3(0.0));
	// sqrt aproxima a curva sRGB e torna visíveis diferenças em tons escuros.
	return sqrt(rgb);
}

float luminancia(vec3 rgb) {
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 uv_material = UV * uv1_scale.xy + uv1_offset.xy;
	uv_base = uv_material;
	vec4 texel = tem_textura ? texture(textura_original, uv_material) * cor_base : cor_base;
	ALPHA = usar_alpha ? texel.a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutout_threshold;

	float borda = 0.0;
	if (usar_extracao_automatica && tem_textura) {
		float raio_texels = escala_automatica ? clamp(max(tamanho_textura.x, tamanho_textura.y) / 256.0, 1.0, 6.0) : 1.0;
		vec2 px = (raio_texels * escala_amostragem) / max(tamanho_textura, vec2(1.0));
		vec3 tl = cor_perceptual(uv_material + vec2(-px.x, -px.y));
		vec3 tc = cor_perceptual(uv_material + vec2(0.0, -px.y));
		vec3 tr = cor_perceptual(uv_material + vec2(px.x, -px.y));
		vec3 ml = cor_perceptual(uv_material + vec2(-px.x, 0.0));
		vec3 mr = cor_perceptual(uv_material + vec2(px.x, 0.0));
		vec3 bl = cor_perceptual(uv_material + vec2(-px.x, px.y));
		vec3 bc = cor_perceptual(uv_material + vec2(0.0, px.y));
		vec3 br = cor_perceptual(uv_material + vec2(px.x, px.y));
		vec3 gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
		vec3 gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
		// A magnitude RGB também detecta separações cromáticas isoluminantes.
		float gradiente = sqrt(dot(gx, gx) + dot(gy, gy));
		float valor = luminancia(max(cor_linear(uv_material), vec3(0.0)));
		float linha_contorno = smoothstep(limiar_borda, limiar_borda + 0.08, gradiente);
		float linha_valor = realcar_areas_claras ? smoothstep(limiar_luminancia - 0.035, limiar_luminancia + 0.035, valor) : 0.0;
		borda = max(linha_contorno, linha_valor) * forca_linhas;
	}
	if (tem_mascara_detalhes) {
		float detalhe = texture(mascara_detalhes, uv_material).r * contraste_mascara;
		borda = max(borda, detalhe);
	}
	float alinhamento_normal = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - clamp(alinhamento_normal, 0.0, 1.0), 1.0 / max(largura_rim, 0.01));
	float branco = clamp(max(borda, rim * intensidade_rim), 0.0, 1.0);
	ALBEDO = vec3(branco);
}
