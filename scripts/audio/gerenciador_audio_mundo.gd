class_name GerenciadorAudioMundo
extends Node

## Gerenciador central da trilha sonora dinâmica (OST-1 a OST-8) e do vento ambiente em world.tscn.

enum EstadoMusica {
	DIA = 0,
	TARDE = 1,
	CASA_VIGILIA = 2,
	NOITE_EXTERNA = 3,
	CACADA = 4,
	QUEDA_FUSIVEL = 5,
	GAME_OVER = 6
}

const OST_DIA: Array[String] = [
	"res://assets/audio/musicas/ost_7/OST-7 - Esboco 06 Export 2.mp3",
	"res://assets/audio/musicas/ost_3/OST-3 v6.mp3",
	"res://assets/audio/musicas/ost_1/OST-1 - Esboco 05 Export 2.mp3"
]
const OST_TARDE: String = "res://assets/audio/musicas/ost_2/OST-2 - Esboco 02 Export 2.mp3"
const OST_CASA_VIGILIA: String = "res://assets/audio/musicas/ost_5/OST-5 - Esboco 06 Export 2.mp3"
const OST_NOITE_EXTERNA: String = "res://assets/audio/musicas/ost_4/OST-4 - Esboco 06 Export 1.mp3"
const OST_CACADA: String = "res://assets/audio/musicas/ost_6/OST-6 - Esboco 06 Export 1.mp3"
const OST_CURTO_CIRCUITO: String = "res://assets/audio/musicas/ost_8/OST-8 - Curto-circuito.mp3"
const OST_GAME_OVER: String = "res://assets/audio/musicas/ost_8/OST-8 - Versao completa.mp3"
const SFX_VENTO_AMBIENTE: String = "res://assets/audio/sfx/sfx_vento_ambiente.mp3"

const VOLUME_MUSICA_ATIVO_DB: float = -3.0
const VOLUME_SILENCIO_DB: float = -46.0
const INTERVALO_AVALIACAO: float = 0.25

var estado_musica_atual: int = -1
var caminho_faixa_atual: String = ""
var volume_vento_alvo_db: float = -16.0

var _canal_a: AudioStreamPlayer = null
var _canal_b: AudioStreamPlayer = null
var _canal_ativo_eh_a: bool = true
var _audio_vento: AudioStreamPlayer = null
var _tween_crossfade: Tween = null
var _timer_avaliacao: float = 0.0
var _cache_musicas: Dictionary = {}
var _sinais_conectados: bool = false


func _ready() -> void:
	add_to_group("gerenciador_audio_mundo")
	_garantir_players()
	_iniciar_vento_ambiente()
	call_deferred("_conectar_sistemas")
	avaliar_estado_musical(true)
	_atualizar_volume_vento(0.0, true)


func _exit_tree() -> void:
	if _tween_crossfade != null and _tween_crossfade.is_valid():
		_tween_crossfade.kill()
	if _canal_a != null:
		_canal_a.stop()
	if _canal_b != null:
		_canal_b.stop()
	if _audio_vento != null:
		_audio_vento.stop()
	_cache_musicas.clear()
	BancoAudioDelusio.limpar_cache()


func _garantir_players() -> void:
	var bus_musica: StringName = BancoAudioDelusio.resolver_bus(&"Musica")
	var bus_ambiente: StringName = BancoAudioDelusio.resolver_bus(&"Ambiente")

	if _canal_a == null:
		_canal_a = AudioStreamPlayer.new()
		_canal_a.name = "MusicaCanalA"
		_canal_a.bus = bus_musica
		_canal_a.volume_db = VOLUME_SILENCIO_DB
		add_child(_canal_a)

	if _canal_b == null:
		_canal_b = AudioStreamPlayer.new()
		_canal_b.name = "MusicaCanalB"
		_canal_b.bus = bus_musica
		_canal_b.volume_db = VOLUME_SILENCIO_DB
		add_child(_canal_b)

	if _audio_vento == null:
		_audio_vento = AudioStreamPlayer.new()
		_audio_vento.name = "AudioVentoAmbiente"
		_audio_vento.bus = bus_ambiente
		_audio_vento.volume_db = volume_vento_alvo_db
		add_child(_audio_vento)


func _carregar_stream_loop(caminho: String) -> AudioStream:
	if _cache_musicas.has(caminho):
		return _cache_musicas[caminho] as AudioStream
	if not ResourceLoader.exists(caminho):
		return null
	var stream: AudioStream = load(caminho) as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	if stream != null:
		_cache_musicas[caminho] = stream
	return stream


func _iniciar_vento_ambiente() -> void:
	if _audio_vento == null:
		return
	var stream_vento: AudioStream = _carregar_stream_loop(SFX_VENTO_AMBIENTE)
	if stream_vento != null:
		_audio_vento.stream = stream_vento
		if DisplayServer.get_name() != "headless":
			_audio_vento.play()


func _conectar_sistemas() -> void:
	if _sinais_conectados or not is_inside_tree() or is_queued_for_deletion():
		return
	_sinais_conectados = true

	var gerente := GameManager.instance
	if gerente != null:
		if not gerente.dia_iniciado.is_connected(_ao_mudar_dia):
			gerente.dia_iniciado.connect(_ao_mudar_dia)
		if not gerente.horario_alterado.is_connected(_ao_mudar_horario):
			gerente.horario_alterado.connect(_ao_mudar_horario)
		if not gerente.noite_iniciada.is_connected(_ao_iniciar_noite):
			gerente.noite_iniciada.connect(_ao_iniciar_noite)
		if gerente.has_signal("segunda_chance_consumida") and not gerente.segunda_chance_consumida.is_connected(_ao_segunda_chance):
			gerente.segunda_chance_consumida.connect(_ao_segunda_chance)
		if gerente.has_signal("noite_sobrevivida") and not gerente.noite_sobrevivida.is_connected(_ao_noite_sobrevivida):
			gerente.noite_sobrevivida.connect(_ao_noite_sobrevivida)
		if gerente.has_signal("game_over_disparado") and not gerente.game_over_disparado.is_connected(_ao_game_over):
			gerente.game_over_disparado.connect(_ao_game_over)
		if gerente.diretor_eventos_noite != null:
			var diretor: Node = gerente.diretor_eventos_noite
			if diretor.has_signal("queda_fusivel_iniciada") and not diretor.queda_fusivel_iniciada.is_connected(_ao_queda_fusivel_iniciada):
				diretor.queda_fusivel_iniciada.connect(_ao_queda_fusivel_iniciada)
			if diretor.has_signal("queda_fusivel_encerrada") and not diretor.queda_fusivel_encerrada.is_connected(_ao_queda_fusivel_encerrada):
				diretor.queda_fusivel_encerrada.connect(_ao_queda_fusivel_encerrada)

	if get_tree() != null:
		for c in get_tree().get_nodes_in_group("casa_controlador"):
			if c != null and c.has_signal("jogador_zona_casa_alterada") and not c.jogador_zona_casa_alterada.is_connected(_ao_zona_casa_alterada):
				c.jogador_zona_casa_alterada.connect(_ao_zona_casa_alterada)

	avaliar_estado_musical(true)
	_atualizar_volume_vento(0.0, true)


func _ao_mudar_dia(_dia: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	avaliar_estado_musical(true)
	_atualizar_volume_vento(0.0, DisplayServer.get_name() == "headless")


func _ao_mudar_horario(_estado: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	avaliar_estado_musical(true)
	_atualizar_volume_vento(0.0, DisplayServer.get_name() == "headless")


func _ao_iniciar_noite() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	avaliar_estado_musical(true)
	_atualizar_volume_vento(0.0, DisplayServer.get_name() == "headless")


func _ao_zona_casa_alterada(_dentro: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	avaliar_estado_musical(false)
	_atualizar_volume_vento(0.0, DisplayServer.get_name() == "headless")


func _ao_queda_fusivel_iniciada(_duracao: float) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	avaliar_estado_musical(true)


func _ao_queda_fusivel_encerrada() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	avaliar_estado_musical(true)


func _ao_segunda_chance(_monstro: Node3D) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	BancoAudioDelusio.tocar_2d(self, &"segunda_chance_salvo", -2.0, 0.02)
	avaliar_estado_musical(true)


func _ao_noite_sobrevivida(_dia_concluido: int, _dias_sobr: int, _novo_rec: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	BancoAudioDelusio.tocar_2d(self, &"cama_dormir", -3.0, 0.03)
	BancoAudioDelusio.tocar_2d(self, &"noite_sobrevivida", -4.0, 0.0)


func _ao_game_over(_resumo: Dictionary) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	BancoAudioDelusio.tocar_2d(self, &"game_over_impacto", -1.0, 0.02)
	avaliar_estado_musical(true)
	_atualizar_volume_vento(0.0, DisplayServer.get_name() == "headless")


func _process(delta: float) -> void:
	_timer_avaliacao += delta
	if _timer_avaliacao >= INTERVALO_AVALIACAO:
		_timer_avaliacao = 0.0
		avaliar_estado_musical(false)
	_atualizar_volume_vento(delta, DisplayServer.get_name() == "headless")


func obter_caminho_para_estado(estado: int, dia: int = 1) -> String:
	match estado:
		EstadoMusica.DIA:
			var idx: int = posmod(dia - 1, OST_DIA.size())
			return OST_DIA[idx]
		EstadoMusica.TARDE:
			return OST_TARDE
		EstadoMusica.CASA_VIGILIA:
			return OST_CASA_VIGILIA
		EstadoMusica.NOITE_EXTERNA:
			return OST_NOITE_EXTERNA
		EstadoMusica.CACADA:
			return OST_CACADA
		EstadoMusica.QUEDA_FUSIVEL:
			return OST_CURTO_CIRCUITO
		EstadoMusica.GAME_OVER:
			return OST_GAME_OVER
		_:
			return OST_DIA[0]


func _jogador_esta_em_cacada() -> bool:
	var gerente := GameManager.instance
	if gerente == null or gerente.horario_atual != 2:
		return false

	if gerente.rondante != null and is_instance_valid(gerente.rondante) and ("ativa" in gerente.rondante) and gerente.rondante.ativa:
		if "estado_atual" in gerente.rondante:
			var est_r: int = int(gerente.rondante.estado_atual)
			if est_r == RondanteFazenda.Estado.CACADA or est_r == RondanteFazenda.Estado.ATAQUE_GARRAS:
				return true

	if gerente.silhueta != null and is_instance_valid(gerente.silhueta) and ("ativa" in gerente.silhueta) and gerente.silhueta.ativa:
		if "estado_atual" in gerente.silhueta:
			var est_s: int = int(gerente.silhueta.estado_atual)
			if est_s == Silhueta.Estado.AMEACA_LANTERNA or est_s == Silhueta.Estado.INVESTIDA:
				return true

	return false


func _jogador_dentro_casa() -> bool:
	if not is_inside_tree():
		return false
	var player: Player = _obter_player()
	var arvore := get_tree()
	if arvore != null:
		for c in arvore.get_nodes_in_group("casa_controlador"):
			if c != null and is_instance_valid(c):
				if player != null and c.has_method("contem_ponto_interno") and player.is_inside_tree():
					return bool(c.contem_ponto_interno(player.global_position))
				if "jogador_dentro_casa" in c:
					return bool(c.jogador_dentro_casa)
	return false


func _jogador_na_zona_breu() -> bool:
	var player: Player = _obter_player()
	if player != null and player.has_method("esta_na_zona_breu"):
		return player.esta_na_zona_breu()
	return false


func _obter_player() -> Player:
	if not is_inside_tree():
		return null
	var arvore := get_tree()
	if arvore != null:
		return arvore.get_first_node_in_group("player") as Player
	return null


func _determinar_estado_atual() -> int:
	var gerente := GameManager.instance
	if gerente == null:
		return EstadoMusica.DIA

	if gerente.jogo_encerrado:
		return EstadoMusica.GAME_OVER

	if gerente.diretor_eventos_noite != null and ("queda_fusivel_ativa" in gerente.diretor_eventos_noite) and bool(gerente.diretor_eventos_noite.queda_fusivel_ativa):
		return EstadoMusica.QUEDA_FUSIVEL

	if _jogador_esta_em_cacada():
		return EstadoMusica.CACADA

	match gerente.horario_atual:
		2:
			if _jogador_dentro_casa() and not _jogador_na_zona_breu():
				return EstadoMusica.CASA_VIGILIA
			return EstadoMusica.NOITE_EXTERNA
		1:
			return EstadoMusica.TARDE
		_:
			return EstadoMusica.DIA


func avaliar_estado_musical(forcar: bool = false) -> void:
	var gerente := GameManager.instance
	var dia: int = gerente.dia_atual if gerente != null else 1
	var novo_estado: int = _determinar_estado_atual()
	var novo_caminho: String = obter_caminho_para_estado(novo_estado, dia)

	if not forcar and novo_estado == estado_musica_atual and novo_caminho == caminho_faixa_atual:
		return

	estado_musica_atual = novo_estado
	_trocar_faixa(novo_caminho, 0.0 if DisplayServer.get_name() == "headless" else 1.6)


func _trocar_faixa(caminho: String, duracao_fade: float) -> void:
	if caminho == caminho_faixa_atual and _canal_atual() != null and _canal_atual().stream != null:
		return

	caminho_faixa_atual = caminho
	var stream_novo: AudioStream = _carregar_stream_loop(caminho)
	if stream_novo == null:
		return

	_garantir_players()
	var entrada: AudioStreamPlayer = _canal_b if _canal_ativo_eh_a else _canal_a
	var saida: AudioStreamPlayer = _canal_a if _canal_ativo_eh_a else _canal_b
	_canal_ativo_eh_a = not _canal_ativo_eh_a

	entrada.stream = stream_novo
	if _tween_crossfade and _tween_crossfade.is_valid():
		_tween_crossfade.kill()

	if duracao_fade <= 0.01 or not is_inside_tree() or DisplayServer.get_name() == "headless":
		if saida.playing:
			saida.stop()
		saida.volume_db = VOLUME_SILENCIO_DB
		entrada.volume_db = VOLUME_MUSICA_ATIVO_DB
		if DisplayServer.get_name() != "headless":
			entrada.play()
		return

	entrada.volume_db = VOLUME_SILENCIO_DB
	entrada.play()
	_tween_crossfade = create_tween().set_parallel(true)
	_tween_crossfade.tween_property(entrada, "volume_db", VOLUME_MUSICA_ATIVO_DB, duracao_fade).set_trans(Tween.TRANS_SINE)
	if saida.playing:
		_tween_crossfade.tween_property(saida, "volume_db", VOLUME_SILENCIO_DB, duracao_fade).set_trans(Tween.TRANS_SINE)
		_tween_crossfade.chain().tween_callback(func() -> void:
			if is_instance_valid(saida):
				saida.stop()
		)


func _canal_atual() -> AudioStreamPlayer:
	return _canal_a if _canal_ativo_eh_a else _canal_b


func _atualizar_volume_vento(delta: float, imediato: bool) -> void:
	if _audio_vento == null:
		return

	var gerente := GameManager.instance
	var alvo: float = -16.0
	if gerente != null and gerente.jogo_encerrado:
		alvo = -32.0
	elif _jogador_na_zona_breu():
		alvo = -6.0
	elif _jogador_dentro_casa():
		alvo = -24.0
	elif gerente != null and gerente.horario_atual == 2:
		alvo = -10.0
	elif gerente != null and gerente.horario_atual == 1:
		alvo = -13.0

	volume_vento_alvo_db = alvo
	if imediato or delta <= 0.0:
		_audio_vento.volume_db = alvo
	else:
		_audio_vento.volume_db = move_toward(_audio_vento.volume_db, alvo, delta * 14.0)
