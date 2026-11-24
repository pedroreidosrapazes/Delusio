shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Shader de terreno estilo mid-2000s / Dread Fields:
// Mistura grama seca e terra batida/lama via Vertex Color (COLOR.r) ou Splatmap,
// com filtragem pixelada/baixa res e superfície 100% fosca.

uniform sampler2D textura_grama : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D textura_terra : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D splatmap : hint_default_black, filter_linear, repeat_disable;

uniform bool usar_splatmap = false;
uniform float escala_uv_grama : hint_range(1.0, 200.0) = 42.0;
uniform float escala_uv_terra : hint_range(1.0, 200.0) = 38.0;
uniform vec4 tonalidade_geral : source_color = vec4(0.92, 0.90, 0.85, 1.0);

group_uniforms QuebraDeTiling;
uniform float escala_ruido : hint_range(0.01, 1.0) = 0.085;
uniform float intensidade_ruido : hint_range(0.0, 0.5) = 0.22;

varying vec3 pos_mundo;

// Hash 2D leve para ruído procedural no mundo
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cor_grama = texture(textura_grama, UV * escala_uv_grama).rgb;
	vec3 cor_terra = texture(textura_terra, UV * escala_uv_terra).rgb;

	// Máscara: 0.0 = grama seca, 1.0 = terra/lama
	float peso_terra = COLOR.r;
	if (usar_splatmap) {
		peso_terra = clamp(max(peso_terra, texture(splatmap, UV).r), 0.0, 1.0);
	}

	vec3 cor_base = mix(cor_grama, cor_terra, peso_terra);

	// Ruído sutil em espaço de mundo para quebrar repetição (tiling)
	float n = noise2d(pos_mundo.xz * escala_ruido) * 0.65
			+ noise2d(pos_mundo.xz * (escala_ruido * 2.7)) * 0.35;
	float fator_escuro = 1.0 - (n * intensidade_ruido);

	ALBEDO = cor_base * tonalidade_geral.rgb * fator_escuro;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
}
