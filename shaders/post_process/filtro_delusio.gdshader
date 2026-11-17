shader_type canvas_item;
render_mode unshaded;

global uniform float ajuste_brilho;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float nivel_tensao : hint_range(0.0, 1.0) = 0.05;
uniform float peso_noite : hint_range(0.0, 1.0) = 0.0;
uniform float intensidade_dither : hint_range(0.0, 1.0) = 0.35;
uniform float niveis_cor : hint_range(8.0, 64.0) = 32.0;
uniform float intensidade_grao : hint_range(0.0, 0.2) = 0.025;
uniform float forca_vinheta : hint_range(0.0, 1.5) = 0.42;
uniform float brilho_local : hint_range(0.5, 1.5) = 1.0;
uniform vec3 cor_fria_noite : source_color = vec3(0.42, 0.50, 0.62);
uniform float desfoque_fundo : hint_range(0.0, 1.0) = 0.0;

float obter_bayer4x4(ivec2 pos) {
	int x = pos.x % 4;
	int y = pos.y % 4;
	int index = x + y * 4;
	const float bayer[16] = float[16](
		0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
		12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
		3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
		15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
	);
	return bayer[index];
}

void fragment() {
	vec2 uv_centrada = SCREEN_UV - vec2(0.5);
	float dist_centro = length(uv_centrada);
	vec2 dir_radial = dist_centro > 0.0001 ? normalize(uv_centrada) : vec2(0.0);

	// Pulso de batimento cardíaco com tensão elevada
	float pulso = 0.0;
	if (nivel_tensao > 0.25) {
		pulso = max(0.0, sin(TIME * 6.0)) * (nivel_tensao - 0.25) * 1.5;
	}

	// Aberração cromática radial periférica
	float fator_aberracao = (nivel_tensao * 0.008 + pulso * 0.006) * smoothstep(0.1, 0.7, dist_centro);
	vec2 uv_r = clamp(SCREEN_UV + dir_radial * fator_aberracao, vec2(0.0), vec2(1.0));
	vec2 uv_g = SCREEN_UV;
	vec2 uv_b = clamp(SCREEN_UV - dir_radial * fator_aberracao, vec2(0.0), vec2(1.0));

	float r = 0.0;
	float g = 0.0;
	float b = 0.0;

	if (desfoque_fundo > 0.001) {
		float raio = desfoque_fundo * 0.012;
		const vec2 offsets[9] = vec2[9](
			vec2(-1.0, -1.0), vec2(0.0, -1.0), vec2(1.0, -1.0),
			vec2(-1.0,  0.0), vec2(0.0,  0.0), vec2(1.0,  0.0),
			vec2(-1.0,  1.0), vec2(0.0,  1.0), vec2(1.0,  1.0)
		);
		const float pesos[9] = float[9](
			0.0625, 0.125, 0.0625,
			0.1250, 0.250, 0.1250,
			0.0625, 0.125, 0.0625
		);
		for (int i = 0; i < 9; i++) {
			vec2 off = offsets[i] * raio;
			r += texture(screen_texture, clamp(uv_r + off, vec2(0.0), vec2(1.0))).r * pesos[i];
			g += texture(screen_texture, clamp(uv_g + off, vec2(0.0), vec2(1.0))).g * pesos[i];
			b += texture(screen_texture, clamp(uv_b + off, vec2(0.0), vec2(1.0))).b * pesos[i];
		}
	} else {
		r = texture(screen_texture, uv_r).r;
		g = texture(screen_texture, uv_g).g;
		b = texture(screen_texture, uv_b).b;
	}
	vec3 cor_base = vec3(r, g, b);

	// Dessaturação seletiva ("Mente, Terra e Sangue")
	float lum = dot(cor_base, vec3(0.299, 0.587, 0.114));

	// 1. Preservação de luz amarela/âmbar (velas, lanterna)
	float delta_amarelo = min(cor_base.r, cor_base.g) - cor_base.b;
	float mascara_amarelo = smoothstep(0.08, 0.28, delta_amarelo) * smoothstep(0.15, 0.45, cor_base.r);

	// 2. Preservação de vermelhos intensos (sangue, perigo, UI de erro)
	float delta_vermelho = cor_base.r - max(cor_base.g, cor_base.b);
	float mascara_vermelho = smoothstep(0.12, 0.32, delta_vermelho) * smoothstep(0.20, 0.50, cor_base.r);

	// 3. Preservação do contorno branco e Glow do estilo PB
	float mascara_destaque_pb = smoothstep(0.78, 0.92, lum);

	float mascara_protegida = clamp(mascara_amarelo + mascara_vermelho + mascara_destaque_pb, 0.0, 1.0);

	// Tom noturno frio com preservação de luminância e piso lunar suave nas sombras
	float lum_fria = max(dot(cor_fria_noite, vec3(0.299, 0.587, 0.114)), 0.001);
	vec3 tom_frio_normalizado = (cor_fria_noite / lum_fria) * 0.90;
	vec3 shadow_lift = cor_fria_noite * (0.045 * peso_noite * (1.0 - smoothstep(0.0, 0.35, lum)));
	vec3 cor_desaturada = lum * tom_frio_normalizado + shadow_lift;
	float drenagem = clamp(peso_noite * 0.68 + nivel_tensao * 0.45, 0.0, 0.85);
	cor_base = mix(cor_base, mix(cor_base, cor_desaturada, drenagem), 1.0 - mascara_protegida);

	// Dithering ordenado Bayer 4x4 + Quantização de cor
	float bayer_val = obter_bayer4x4(ivec2(FRAGCOORD.xy));
	float dither = (bayer_val - 0.5) * (intensidade_dither / niveis_cor);
	cor_base = floor(clamp(cor_base + vec3(dither), 0.0, 1.0) * niveis_cor + 0.5) / niveis_cor;

	// Granulação temporal
	float ruido = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233)) + fract(TIME * 23.17)) * 43758.5453);
	cor_base += (ruido - 0.5) * intensidade_grao;

	// Vinheta elíptica suave que se estreita com a tensão sem fechar o centro útil
	float vinheta_fator = forca_vinheta * (1.0 + nivel_tensao * 0.35);
	float vinheta = smoothstep(0.95, 0.38, dist_centro * vinheta_fator);
	cor_base *= mix(0.22, 1.0, clamp(vinheta, 0.0, 1.0));

	// Ajuste de brilho final global e local (com resposta perceptível nas sombras)
	float fator_ajuste = (ajuste_brilho > 0.01) ? ajuste_brilho : 1.0;
	float ganho_brilho = fator_ajuste * brilho_local;
	float lift_brilho = max(0.0, ganho_brilho - 1.0) * 0.08 * (1.0 - mascara_destaque_pb);
	cor_base = (cor_base + vec3(lift_brilho)) * ganho_brilho;

	COLOR = vec4(clamp(cor_base, 0.0, 1.0), 1.0);
}
