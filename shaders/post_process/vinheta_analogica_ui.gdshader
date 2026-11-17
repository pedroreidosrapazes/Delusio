shader_type canvas_item;
render_mode unshaded;

// Vinheta pesada, granulação analógica de filme/VHS e leve aberração cromática periférica.
// Projetado para camadas de UI (Menu Principal e Menu de Pausa) estilo Survival Horror.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float intensidade_vinheta : hint_range(0.0, 2.0) = 1.20;
uniform float suavidade_vinheta : hint_range(0.1, 1.0) = 0.55;
uniform float intensidade_grao : hint_range(0.0, 0.2) = 0.045;
uniform float aberracao_cromatica : hint_range(0.0, 0.01) = 0.0020;
uniform float linhas_vhs : hint_range(0.0, 0.15) = 0.025;

void fragment() {
	vec2 uv_centrada = SCREEN_UV - vec2(0.5);
	float dist = length(uv_centrada);
	vec2 dir = dist > 0.0001 ? normalize(uv_centrada) : vec2(0.0);

	// Aberração cromática apenas nas bordas para preservar nitidez do texto central
	float mascara_borda = smoothstep(0.28, 0.85, dist);
	float deslocamento = aberracao_cromatica * mascara_borda;

	float r = texture(screen_texture, clamp(SCREEN_UV + dir * deslocamento, vec2(0.0), vec2(1.0))).r;
	float g = texture(screen_texture, SCREEN_UV).g;
	float b = texture(screen_texture, clamp(SCREEN_UV - dir * deslocamento, vec2(0.0), vec2(1.0))).b;
	vec3 cor = vec3(r, g, b);

	// Linhas horizontais sutis estilo monitor/VHS antigo
	float scanline = sin(FRAGCOORD.y * 1.5 + TIME * 4.0) * 0.5 + 0.5;
	cor -= scanline * linhas_vhs * 0.5;

	// Granulação analógica temporal (filme 16mm / fita magnética)
	float semente = dot(FRAGCOORD.xy, vec2(12.9898, 78.233)) + fract(TIME * 19.37) * 143.13;
	float ruido = fract(sin(semente) * 43758.5453);
	cor += (ruido - 0.5) * intensidade_grao;

	// Vinheta densa estilo Resident Evil clássico / RE7
	float vinheta = smoothstep(0.88, 0.88 - suavidade_vinheta, dist * intensidade_vinheta);
	cor *= clamp(vinheta, 0.06, 1.0);

	COLOR = vec4(clamp(cor, 0.0, 1.0), 1.0);
}
