class_name BancoAudioDelusio
extends RefCounted

## Banco central de efeitos sonoros plug-and-play de "Delusio".
## Procura primeiro um arquivo em res://assets/audio/sfx/<id>.(ogg|wav|mp3).
## Enquanto o arquivo final não existir, sintetiza e armazena em cache um AudioStreamWAV procedural.

const PASTA_SFX: String = "res://assets/audio/sfx/"
const MIX_RATE: int = 22050

const IDS_SFX: Array[StringName] = [
	# Jogador
	&"passo_terra",
	&"passo_madeira",
	&"lanterna_ligar",
	&"lanterna_desligar",
	&"lanterna_bloqueada",
	&"hotbar_troca",
	&"janela_entrar",
	&"janela_sair",
	# Interatíveis
	&"porta_abrir",
	&"porta_fechar",
	&"armario_entrar",
	&"armario_sair",
	&"batimento_cardiaco",
	&"fusivel_queda",
	&"fusivel_religar",
	&"tarefa_agua",
	&"tarefa_cerca",
	&"tarefa_bomba",
	&"tarefa_cocho",
	&"fita_silver_tape",
	&"vazamento_agua_loop",
	&"item_coletar",
	&"papel_abrir",
	&"papel_fechar",
	&"rastro_inspecionar",
	&"cama_dormir",
	&"radio_estatica",
	&"radio_clique",
	# Monstros e Eventos
	&"rondante_passo",
	&"rondante_vocalizacao",
	&"rondante_garras",
	&"rondante_atordoado",
	&"rondante_bater_chao",
	&"silhueta_presenca",
	&"silhueta_ameaca",
	&"silhueta_investida",
	&"silhueta_recuo",
	&"evento_porta_janela",
	&"evento_madeira_celeiro",
	&"evento_galhos_atras",
	# UI e Loop Endless
	&"ui_hover",
	&"ui_click",
	&"pilula_consumir",
	&"segunda_chance_salvo",
	&"noite_sobrevivida",
	&"game_over_impacto"
]

static var _cache: Dictionary = {}


static func limpar_cache() -> void:
	_cache.clear()


static func resolver_bus(bus: StringName) -> StringName:
	if AudioServer.get_bus_index(bus) != -1:
		return bus
	return &"Master"


static func obter_sfx(id: StringName) -> AudioStream:
	if _cache.has(id):
		return _cache[id] as AudioStream

	for ext: String in [".ogg", ".wav", ".mp3"]:
		var caminho: String = "%s%s%s" % [PASTA_SFX, String(id), ext]
		if ResourceLoader.exists(caminho):
			var stream: AudioStream = load(caminho) as AudioStream
			if stream != null:
				_cache[id] = stream
				return stream

	var wav: AudioStreamWAV = _sintetizar_sfx(id)
	_cache[id] = wav
	return wav


static func tocar_2d(
	dono: Node,
	id: StringName,
	volume_db: float = 0.0,
	pitch_var: float = 0.05,
	bus: StringName = &"SFX"
) -> AudioStreamPlayer:
	if dono == null or not is_instance_valid(dono) or not dono.is_inside_tree():
		return null

	var stream: AudioStream = obter_sfx(id)
	if stream == null:
		return null

	var player_audio := AudioStreamPlayer.new()
	player_audio.name = "SFX2D_%s" % String(id)
	player_audio.stream = stream
	player_audio.volume_db = volume_db
	player_audio.pitch_scale = randf_range(maxf(0.5, 1.0 - pitch_var), 1.0 + pitch_var)
	player_audio.bus = resolver_bus(bus)
	var nome_id: String = String(id)
	if nome_id.begins_with("ui_") or nome_id.begins_with("papel_"):
		player_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	dono.add_child(player_audio)
	player_audio.finished.connect(player_audio.queue_free)
	player_audio.play()
	return player_audio


static func tocar_3d(
	dono: Node,
	id: StringName,
	pos_global: Vector3,
	volume_db: float = 0.0,
	max_distance: float = 22.0,
	pitch_var: float = 0.07,
	bus: StringName = &"SFX"
) -> AudioStreamPlayer3D:
	if dono == null or not is_instance_valid(dono) or not dono.is_inside_tree():
		return null

	var stream: AudioStream = obter_sfx(id)
	if stream == null:
		return null

	var player_3d := AudioStreamPlayer3D.new()
	player_3d.name = "SFX3D_%s" % String(id)
	player_3d.stream = stream
	player_3d.volume_db = volume_db
	player_3d.max_distance = max_distance
	player_3d.pitch_scale = randf_range(maxf(0.5, 1.0 - pitch_var), 1.0 + pitch_var)
	player_3d.bus = resolver_bus(bus)
	dono.add_child(player_3d)
	player_3d.global_position = pos_global
	player_3d.finished.connect(player_3d.queue_free)
	player_3d.play()
	return player_3d


static func _especificacao_sfx(id: StringName) -> Dictionary:
	match id:
		&"passo_terra":
			return {"dur": 0.14, "f0": 95.0, "f1": 50.0, "tom": 0.28, "ruido": 0.72, "lp": 0.22, "atk": 0.008, "dec": 20.0, "ganho": 0.34}
		&"passo_madeira":
			return {"dur": 0.12, "f0": 155.0, "f1": 85.0, "harm": 2.1, "tom": 0.70, "ruido": 0.30, "lp": 0.34, "atk": 0.004, "dec": 26.0, "ganho": 0.36}
		&"lanterna_ligar":
			return {"dur": 0.08, "f0": 980.0, "f1": 1650.0, "tom": 0.65, "ruido": 0.45, "lp": 0.75, "atk": 0.002, "dec": 48.0, "pulso2": 0.032, "f2": 1950.0, "ganho": 0.34}
		&"lanterna_desligar":
			return {"dur": 0.075, "f0": 1450.0, "f1": 720.0, "tom": 0.65, "ruido": 0.40, "lp": 0.65, "atk": 0.002, "dec": 52.0, "pulso2": 0.028, "f2": 620.0, "ganho": 0.32}
		&"lanterna_bloqueada":
			return {"dur": 0.18, "f0": 210.0, "f1": 140.0, "tom": 0.75, "ruido": 0.25, "lp": 0.40, "atk": 0.004, "dec": 18.0, "pulso2": 0.08, "f2": 130.0, "ganho": 0.34}
		&"hotbar_troca":
			return {"dur": 0.055, "f0": 620.0, "f1": 840.0, "tom": 0.75, "ruido": 0.25, "lp": 0.70, "atk": 0.002, "dec": 58.0, "ganho": 0.24}
		&"janela_entrar":
			return {"dur": 0.24, "f0": 260.0, "f1": 185.0, "harm": 1.6, "tom": 0.50, "ruido": 0.50, "lp": 0.25, "atk": 0.015, "dec": 11.0, "ganho": 0.28}
		&"janela_sair":
			return {"dur": 0.20, "f0": 190.0, "f1": 240.0, "harm": 1.5, "tom": 0.48, "ruido": 0.52, "lp": 0.26, "atk": 0.012, "dec": 13.0, "ganho": 0.26}
		&"porta_abrir":
			return {"dur": 0.46, "f0": 190.0, "f1": 310.0, "harm": 1.47, "tom": 0.62, "ruido": 0.38, "lp": 0.28, "mod_freq": 11.0, "atk": 0.025, "dec": 5.5, "ganho": 0.32}
		&"porta_fechar":
			return {"dur": 0.34, "f0": 240.0, "f1": 92.0, "harm": 1.4, "tom": 0.55, "ruido": 0.45, "lp": 0.30, "atk": 0.01, "dec": 10.0, "pulso2": 0.16, "f2": 110.0, "ganho": 0.36}
		&"armario_entrar":
			return {"dur": 0.30, "f0": 170.0, "f1": 120.0, "harm": 1.5, "tom": 0.50, "ruido": 0.50, "lp": 0.24, "atk": 0.015, "dec": 9.0, "ganho": 0.30}
		&"armario_sair":
			return {"dur": 0.28, "f0": 130.0, "f1": 210.0, "harm": 1.5, "tom": 0.50, "ruido": 0.50, "lp": 0.26, "atk": 0.015, "dec": 9.5, "ganho": 0.30}
		&"batimento_cardiaco":
			return {"dur": 0.45, "f0": 62.0, "f1": 38.0, "tom": 0.96, "ruido": 0.04, "lp": 0.14, "atk": 0.008, "dec": 16.0, "pulso2": 0.19, "f2": 50.0, "ganho": 0.46}
		&"fusivel_queda":
			return {"dur": 0.55, "f0": 420.0, "f1": 52.0, "harm": 1.5, "tom": 0.58, "ruido": 0.42, "lp": 0.35, "mod_freq": 28.0, "atk": 0.005, "dec": 5.2, "ganho": 0.42}
		&"fusivel_religar":
			return {"dur": 0.24, "f0": 240.0, "f1": 680.0, "harm": 2.0, "tom": 0.68, "ruido": 0.32, "lp": 0.55, "atk": 0.003, "dec": 14.0, "pulso2": 0.08, "f2": 820.0, "ganho": 0.38}
		&"tarefa_agua":
			return {"dur": 0.48, "f0": 290.0, "f1": 520.0, "tom": 0.16, "ruido": 0.84, "lp": 0.38, "mod_freq": 9.0, "atk": 0.03, "dec": 5.0, "ganho": 0.30}
		&"tarefa_cerca":
			return {"dur": 0.26, "f0": 720.0, "f1": 420.0, "tom": 0.35, "ruido": 0.65, "lp": 0.58, "atk": 0.005, "dec": 15.0, "pulso2": 0.11, "f2": 640.0, "ganho": 0.32}
		&"tarefa_bomba":
			return {"dur": 0.38, "f0": 320.0, "f1": 160.0, "harm": 2.35, "tom": 0.72, "ruido": 0.28, "lp": 0.50, "atk": 0.005, "dec": 11.0, "pulso2": 0.16, "f2": 480.0, "ganho": 0.35}
		&"tarefa_cocho":
			return {"dur": 0.35, "f0": 240.0, "f1": 140.0, "tom": 0.18, "ruido": 0.82, "lp": 0.30, "mod_freq": 15.0, "atk": 0.015, "dec": 7.5, "ganho": 0.30}
		&"fita_silver_tape":
			return {"dur": 0.32, "f0": 1400.0, "f1": 900.0, "tom": 0.12, "ruido": 0.88, "lp": 0.72, "mod_freq": 22.0, "atk": 0.01, "dec": 8.5, "ganho": 0.30}
		&"vazamento_agua_loop":
			return {"dur": 0.85, "f0": 340.0, "f1": 360.0, "tom": 0.08, "ruido": 0.92, "lp": 0.34, "mod_freq": 6.5, "atk": 0.01, "dec": 0.0, "loop": true, "ganho": 0.26}
		&"item_coletar":
			return {"dur": 0.18, "f0": 520.0, "f1": 880.0, "harm": 1.5, "tom": 0.75, "ruido": 0.25, "lp": 0.65, "atk": 0.004, "dec": 18.0, "ganho": 0.32}
		&"papel_abrir":
			return {"dur": 0.22, "f0": 900.0, "f1": 1400.0, "tom": 0.08, "ruido": 0.92, "lp": 0.62, "mod_freq": 18.0, "atk": 0.012, "dec": 12.0, "ganho": 0.26}
		&"papel_fechar":
			return {"dur": 0.16, "f0": 1100.0, "f1": 650.0, "tom": 0.08, "ruido": 0.92, "lp": 0.52, "atk": 0.008, "dec": 16.0, "ganho": 0.24}
		&"rastro_inspecionar":
			return {"dur": 0.30, "f0": 210.0, "f1": 135.0, "harm": 1.41, "tom": 0.58, "ruido": 0.42, "lp": 0.28, "atk": 0.015, "dec": 8.5, "ganho": 0.30}
		&"cama_dormir":
			return {"dur": 0.55, "f0": 180.0, "f1": 110.0, "harm": 1.5, "tom": 0.65, "ruido": 0.35, "lp": 0.18, "atk": 0.05, "dec": 4.2, "ganho": 0.32}
		&"radio_estatica":
			return {"dur": 0.60, "f0": 1200.0, "f1": 900.0, "tom": 0.12, "ruido": 0.88, "lp": 0.64, "mod_freq": 32.0, "atk": 0.02, "dec": 3.8, "ganho": 0.32}
		&"radio_clique":
			return {"dur": 0.07, "f0": 780.0, "f1": 440.0, "tom": 0.60, "ruido": 0.40, "lp": 0.60, "atk": 0.002, "dec": 50.0, "ganho": 0.30}
		&"rondante_passo":
			return {"dur": 0.22, "f0": 72.0, "f1": 36.0, "harm": 1.5, "tom": 0.62, "ruido": 0.38, "lp": 0.15, "atk": 0.006, "dec": 14.0, "ganho": 0.46}
		&"rondante_vocalizacao":
			return {"dur": 0.72, "f0": 138.0, "f1": 78.0, "harm": 1.33, "tom": 0.68, "ruido": 0.32, "lp": 0.22, "mod_freq": 19.0, "atk": 0.04, "dec": 3.4, "ganho": 0.44}
		&"rondante_garras":
			return {"dur": 0.30, "f0": 620.0, "f1": 190.0, "harm": 1.65, "tom": 0.45, "ruido": 0.55, "lp": 0.48, "atk": 0.004, "dec": 11.0, "ganho": 0.45}
		&"rondante_atordoado":
			return {"dur": 0.52, "f0": 310.0, "f1": 115.0, "harm": 1.41, "tom": 0.72, "ruido": 0.28, "lp": 0.32, "mod_freq": 24.0, "atk": 0.015, "dec": 4.8, "ganho": 0.40}
		&"rondante_bater_chao":
			return {"dur": 0.36, "f0": 88.0, "f1": 34.0, "harm": 1.5, "tom": 0.66, "ruido": 0.34, "lp": 0.14, "atk": 0.004, "dec": 8.5, "ganho": 0.48}
		&"silhueta_presenca":
			return {"dur": 0.65, "f0": 95.0, "f1": 88.0, "harm": 1.49, "tom": 0.78, "ruido": 0.22, "lp": 0.16, "mod_freq": 4.5, "atk": 0.10, "dec": 3.2, "ganho": 0.34}
		&"silhueta_ameaca":
			return {"dur": 0.58, "f0": 145.0, "f1": 215.0, "harm": 1.414, "tom": 0.74, "ruido": 0.26, "lp": 0.26, "mod_freq": 14.0, "atk": 0.04, "dec": 3.8, "ganho": 0.38}
		&"silhueta_investida":
			return {"dur": 0.50, "f0": 260.0, "f1": 620.0, "harm": 1.414, "tom": 0.68, "ruido": 0.32, "lp": 0.42, "mod_freq": 26.0, "atk": 0.01, "dec": 4.5, "ganho": 0.44}
		&"silhueta_recuo":
			return {"dur": 0.42, "f0": 380.0, "f1": 96.0, "harm": 1.5, "tom": 0.56, "ruido": 0.44, "lp": 0.24, "atk": 0.015, "dec": 6.2, "ganho": 0.34}
		&"evento_porta_janela":
			return {"dur": 0.32, "f0": 195.0, "f1": 115.0, "harm": 1.5, "tom": 0.58, "ruido": 0.42, "lp": 0.24, "atk": 0.005, "dec": 12.0, "pulso2": 0.14, "f2": 165.0, "ganho": 0.38}
		&"evento_madeira_celeiro":
			return {"dur": 0.44, "f0": 150.0, "f1": 98.0, "harm": 1.72, "tom": 0.62, "ruido": 0.38, "lp": 0.22, "mod_freq": 13.0, "atk": 0.02, "dec": 6.0, "ganho": 0.36}
		&"evento_galhos_atras":
			return {"dur": 0.34, "f0": 880.0, "f1": 420.0, "tom": 0.22, "ruido": 0.78, "lp": 0.52, "atk": 0.004, "dec": 13.0, "pulso2": 0.13, "f2": 720.0, "ganho": 0.38}
		&"ui_hover":
			return {"dur": 0.045, "f0": 720.0, "f1": 840.0, "tom": 0.85, "ruido": 0.15, "lp": 0.65, "atk": 0.002, "dec": 70.0, "ganho": 0.22}
		&"ui_click":
			return {"dur": 0.075, "f0": 480.0, "f1": 290.0, "harm": 1.5, "tom": 0.82, "ruido": 0.18, "lp": 0.55, "atk": 0.002, "dec": 45.0, "ganho": 0.28}
		&"pilula_consumir":
			return {"dur": 0.20, "f0": 380.0, "f1": 640.0, "harm": 1.5, "tom": 0.68, "ruido": 0.32, "lp": 0.42, "atk": 0.008, "dec": 15.0, "pulso2": 0.075, "f2": 780.0, "ganho": 0.34}
		&"segunda_chance_salvo":
			return {"dur": 0.52, "f0": 180.0, "f1": 440.0, "harm": 1.5, "tom": 0.85, "ruido": 0.15, "lp": 0.45, "atk": 0.012, "dec": 5.5, "pulso2": 0.20, "f2": 587.0, "ganho": 0.42}
		&"noite_sobrevivida":
			return {"dur": 0.65, "f0": 261.6, "f1": 392.0, "harm": 1.5, "tom": 0.92, "ruido": 0.08, "lp": 0.38, "atk": 0.03, "dec": 3.8, "pulso2": 0.22, "f2": 523.25, "ganho": 0.36}
		&"game_over_impacto":
			return {"dur": 0.85, "f0": 110.0, "f1": 36.0, "harm": 1.414, "tom": 0.72, "ruido": 0.28, "lp": 0.18, "mod_freq": 8.0, "atk": 0.005, "dec": 3.0, "ganho": 0.50}
		_:
			return {"dur": 0.16, "f0": 320.0, "f1": 240.0, "tom": 0.75, "ruido": 0.25, "lp": 0.40, "atk": 0.005, "dec": 16.0, "ganho": 0.30}


static func _sintetizar_sfx(id: StringName) -> AudioStreamWAV:
	var cfg: Dictionary = _especificacao_sfx(id)
	var dur: float = maxf(0.04, float(cfg.get("dur", 0.18)))
	var f0: float = float(cfg.get("f0", 240.0))
	var f1: float = float(cfg.get("f1", 160.0))
	var harm: float = float(cfg.get("harm", 0.0))
	var peso_tom: float = clampf(float(cfg.get("tom", 0.7)), 0.0, 1.0)
	var peso_ruido: float = clampf(float(cfg.get("ruido", 0.3)), 0.0, 1.0)
	var lp: float = clampf(float(cfg.get("lp", 0.35)), 0.03, 1.0)
	var mod_freq: float = float(cfg.get("mod_freq", 0.0))
	var atk: float = maxf(0.001, float(cfg.get("atk", 0.005)))
	var dec: float = maxf(0.0, float(cfg.get("dec", 12.0)))
	var pulso2: float = float(cfg.get("pulso2", -1.0))
	var f2: float = float(cfg.get("f2", f0 * 0.9))
	var ganho: float = clampf(float(cfg.get("ganho", 0.35)), 0.05, 0.75)
	var eh_loop: bool = bool(cfg.get("loop", false))

	var total_amostras: int = maxi(64, int(roundf(dur * float(MIX_RATE))))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	if eh_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = total_amostras

	var dados := PackedByteArray()
	dados.resize(total_amostras * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(String(id)))

	var fase: float = 0.0
	var fase_harm: float = 0.0
	var fase2: float = 0.0
	var ruido_lp: float = 0.0

	for i: int in range(total_amostras):
		var t: float = float(i) / float(MIX_RATE)
		var u: float = float(i) / float(maxi(1, total_amostras - 1))
		var freq: float = lerpf(f0, f1, u)
		fase += TAU * freq / float(MIX_RATE)

		var sinal_tom: float = sin(fase)
		if harm > 0.01:
			fase_harm += TAU * (freq * harm) / float(MIX_RATE)
			sinal_tom = sinal_tom * 0.72 + sin(fase_harm) * 0.28

		var env1: float = minf(1.0, t / atk) * (exp(-dec * t) if dec > 0.0 else 1.0)
		if eh_loop:
			var margem: float = minf(0.06, dur * 0.15)
			var fade_in: float = clampf(t / maxf(0.001, margem), 0.0, 1.0)
			var fade_out: float = clampf((dur - t) / maxf(0.001, margem), 0.0, 1.0)
			env1 *= minf(fade_in, fade_out)

		var ruido_branco: float = rng.randf_range(-1.0, 1.0)
		ruido_lp = lerpf(ruido_lp, ruido_branco, lp)

		var amostra: float = (sinal_tom * peso_tom + ruido_lp * peso_ruido) * env1

		if pulso2 > 0.0 and t >= pulso2:
			var t2: float = t - pulso2
			fase2 += TAU * f2 / float(MIX_RATE)
			var env2: float = minf(1.0, t2 / atk) * exp(-dec * t2)
			amostra += (sin(fase2) * peso_tom + ruido_lp * peso_ruido * 0.6) * env2 * 0.85

		if mod_freq > 0.01:
			amostra *= 0.65 + 0.35 * sin(TAU * mod_freq * t)

		amostra *= ganho
		var amostra_int: int = int(clampf(amostra, -0.98, 0.98) * 32767.0)
		dados.encode_s16(i * 2, amostra_int)

	stream.data = dados
	return stream
