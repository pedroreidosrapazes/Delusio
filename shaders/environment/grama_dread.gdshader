shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

// Shader de vegetação retrô (Crossed Quads / Alpha Cutout) estilo mid-2000s / Dread Fields:
// - Recorte seco (ALPHA_SCISSOR_THRESHOLD = 0.5)
// - Vento frio sutil nos vértices superiores (UV.y < 0.5)
// - Ambient occlusion falso na base (UV.y próximo de 1.0)

uniform sampler2D textura_capim : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec4 cor_topo : source_color = vec4(0.95, 0.92, 0.84, 1.0);
uniform vec4 cor_base_ao : source_color = vec4(0.32, 0.30, 0.24, 1.0);
uniform float forca_ao_base : hint_range(0.0, 1.0) = 0.72;

group_uniforms VentoFrio;
uniform float velocidade_vento : hint_range(0.0, 5.0) = 1.35;
uniform float amplitude_vento : hint_range(0.0, 0.4) = 0.075;
uniform vec2 direcao_vento = vec2(1.0, 0.35);

varying float fator_altura;

void vertex() {
	// UV.y = 0.0 no topo do plano, UV.y = 1.0 na base encostada no chão
	fator_altura = clamp(1.0 - UV.y, 0.0, 1.0);

	// Balança principalmente os vértices superiores (UV.y < 0.5 tem peso bem maior)
	float peso_vento = (UV.y < 0.5) ? (fator_altura * fator_altura) : (fator_altura * 0.25);

	vec3 inst_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float fase = (NODE_POSITION_WORLD.x + inst_world.x) * 0.43
			   + (NODE_POSITION_WORLD.z + inst_world.z) * 0.37;

	float rajada = sin(TIME * velocidade_vento + fase) * 0.70
				 + sin(TIME * (velocidade_vento * 2.13) + fase * 1.7) * 0.30;

	vec2 dir = normalize(direcao_vento);
	VERTEX.x += dir.x * rajada * amplitude_vento * peso_vento;
	VERTEX.z += dir.y * rajada * amplitude_vento * peso_vento;
}

void fragment() {
	vec4 tex = texture(textura_capim, UV);

	// Escurecimento falso na base para integrar o tufo ao chão
	float ao = mix(1.0, 1.0 - forca_ao_base, clamp(UV.y, 0.0, 1.0));
	vec3 cor_ao = mix(cor_base_ao.rgb, cor_topo.rgb, fator_altura);

	ALBEDO = tex.rgb * cor_ao * ao;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
}
