class_name Radio
extends Interactable

## Rádio interativo com legendas estilo Animal Crossing / Lethal Company
## e áudio posicional 3D sincronizado com efeito typewriter e repetição contínua.

signal transmissao_iniciada(dia: int)
signal legenda_atualizada(texto_completo: String, caracteres_visiveis: int)
signal proximidade_alterada(fator_visibilidade: float)
signal transmissao_finalizada()
signal radio_desligado()

enum EstadoTransmissao { INATIVO = 0, DIGITANDO = 1, PAUSA_ENTRE_FRASES = 2, PAUSA_REPETICAO = 3 }

@export_category("Configurações do Player de Áudio")
@export var audio_player: AudioStreamPlayer3D
@export_range(2.0, 50.0, 0.5) var alcance_audicao_legenda: float = 22.0

@export_category("Voz Sintética e Efeito Typewriter")
## Arraste aqui os clipes curtos de fala sintética (ex: audioJornal (1), (2), (3) em .mp3/.ogg/.wav).
@export var sons_jornal: Array[AudioStream] = []
@export_range(0.01, 0.2, 0.005) var velocidade_texto: float = 0.04
@export_range(0.2, 5.0, 0.1) var pausa_padrao_entre_frases: float = 1.4
@export_range(0.5, 1.5, 0.01) var pitch_min: float = 0.95
@export_range(0.5, 1.5, 0.01) var pitch_max: float = 1.08

@export_category("Repetição Contínua do Boletim")
@export var repetir_transmissao: bool = false
@export_range(0.5, 15.0, 0.5) var pausa_entre_repeticoes: float = 3.0

@export_category("Transmissões por Dia (Legendas)")
## Lista configurável no Inspector. Cada item aceita: "dia" (int), "pausa_entre_frases" (float), "frases" (Array[String]).
@export var transmissoes_dias: Array[Dictionary] = [
	{
		"dia": 1,
		"pausa_entre_frases": 1.4,
		"frases": [
			"[RÁDIO]: Bom dia, ouvintes da Rádio Vale Verde.",
			"[RÁDIO]: A previsão para hoje é de céu limpo na nossa região rústica, ideal para o trabalho no campo.",
			"[RÁDIO]: Lembramos aos produtores locais que a feira de grãos acontece no próximo sábado.",
			"[RÁDIO]: Em outras notícias... As autoridades locais pedem atenção aos moradores do setor norte.",
			"[RÁDIO]: Uma mulher foi dada como desaparecida após não retornar para casa na noite de terça-feira.",
			"[RÁDIO]: A polícia acredita que seja um caso isolado, mas recomenda que portas e janelas sejam trancadas ao anoitecer.",
			"[RÁDIO]: Tenham um bom dia de trabalho e cuide de sua terra."
		]
	},
	{
		"dia": 2,
		"pausa_entre_frases": 1.6,
		"frases": [
			"[RÁDIO]: Bom dia, ouvintes da Rádio Vale Verde... aqui quem fala é a equipe do turno da manhã.",
			"[RÁDIO]: Informamos que a feira de grãos deste sábado foi adiada por tempo indeterminado.",
			"[RÁDIO]: As buscas no setor norte continuam sem pistas da moradora desaparecida.",
			"[RÁDIO]: Evitem circular próximos às cercas e celeiros após o entardecer e mantenham as portas trancadas."
		]
	},
	{
		"dia": 3,
		"pausa_entre_frases": 1.7,
		"frases": [
			"[RÁDIO]: ...estática... Rádio Vale Verde em boletim de emergência.",
			"[RÁDIO]: As linhas de comunicação com o setor norte foram interrompidas durante a madrugada.",
			"[RÁDIO]: Moradores relataram vultos imóveis observando as janelas das propriedades rurais.",
			"[RÁDIO]: Não aponte a lanterna diretamente para fora se notar movimento na escuridão."
		]
	},
	{
		"dia": 4,
		"pausa_entre_frases": 1.8,
		"frases": [
			"[RÁDIO]: ...gravação automática da Rádio Vale Verde... frequência local.",
			"[RÁDIO]: Não há mais equipe de plantão no estúdio. As estradas seguem fechadas.",
			"[RÁDIO]: Conclua o que resta em sua terra e retorne para dentro antes que caia a noite.",
			"[RÁDIO]: Fim da transmissão."
		]
	}
]

@export_category("Fallback de Áudio Longo (Opcional)")
@export var audios_dias: Array[AudioStream] = []

var _inicializado: bool = false
var _estado: int = EstadoTransmissao.INATIVO
var _dia_atual_transmissao: int = 1
var _fila_frases: Array[String] = []
var _indice_frase: int = 0
var _texto_atual: String = ""
var _caracteres_visiveis: int = 0
var _tempo_acumulado_char: float = 0.0
var _tempo_pausa_restante: float = 0.0
var _pausa_atual: float = 1.4
var _indice_som_atual: int = 0
var _ultima_proximidade: float = -1.0
var _volume_base_db: float = 0.0
var _tween_fade_voz: Tween
var _modo_audio_legado: bool = false
var _cursor_clipe_longo: float = 0.0


func _ready() -> void:
	inicializar_radio()


## Garante inicialização mesmo quando o script é anexado dinamicamente via set_script().
func inicializar_radio() -> void:
	if _inicializado:
		return
	_inicializado = true
	add_to_group("radio")
	set_process(true)
	prompt_interacao = "Desligar Rádio"
	_garantir_audio_player()
	_garantir_sons_jornal_fallback()


func _garantir_audio_player() -> void:
	if audio_player == null:
		audio_player = get_node_or_null("AudioPlayer") as AudioStreamPlayer3D
	if audio_player == null:
		audio_player = get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	if audio_player == null:
		for filho in get_children():
			if filho is AudioStreamPlayer3D:
				audio_player = filho
				break

	if audio_player == null:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "AudioPlayer"
		audio_player.bus = &"Master"
		audio_player.max_distance = alcance_audicao_legenda
		add_child(audio_player)
	else:
		if audio_player.max_distance <= 0.0 or audio_player.max_distance < alcance_audicao_legenda:
			audio_player.max_distance = alcance_audicao_legenda

	_volume_base_db = audio_player.volume_db


func _garantir_sons_jornal_fallback() -> void:
	if not _obter_sons_validos().is_empty():
		return

	var candidatos: Array[String] = [
		"res://audioJornal (2).mp3",
		"res://assets/audio/audioJornal (2).mp3",
		"res://audioJornal (1).mp3",
		"res://audioJornal (3).mp3",
		"res://assets/audio/audiojornal_1.wav",
		"res://assets/audio/audiojornal_2.wav",
		"res://assets/audio/audiojornal_1.ogg",
		"res://assets/audio/audiojornal_2.ogg",
		"res://assets/audio/audiojornal_1.mp3",
		"res://assets/audio/audiojornal_2.mp3"
	]

	for caminho in candidatos:
		if ResourceLoader.exists(caminho):
			var recurso := load(caminho) as AudioStream
			if recurso != null:
				sons_jornal.append(recurso)


func esta_transmitindo() -> bool:
	return _estado != EstadoTransmissao.INATIVO or _modo_audio_legado


func obter_texto_atual() -> String:
	return _texto_atual


func obter_caracteres_visiveis() -> int:
	return _caracteres_visiveis


func obter_fator_proximidade_atual() -> float:
	return _calcular_fator_proximidade()


## Chamado pelo GameManager.gd ao iniciar um novo dia.
func tocar_noticia(dia: int) -> void:
	inicializar_radio()
	_interromper_transmissao_interna(false)

	if audio_player == null:
		push_warning("Radio: Nenhum nó AudioStreamPlayer3D disponível.")
		return

	_dia_atual_transmissao = dia
	var dados_dia := _obter_dados_dia(dia)
	var frases_brutas: Array = dados_dia.get("frases", [])
	_fila_frases.clear()
	for f in frases_brutas:
		var texto := str(f).strip_edges()
		if not texto.is_empty():
			_fila_frases.append(texto)

	if _fila_frases.is_empty():
		var indice_legado := dia - 1
		if indice_legado >= 0 and indice_legado < audios_dias.size() and audios_dias[indice_legado] != null:
			_modo_audio_legado = true
			audio_player.volume_db = _volume_base_db
			audio_player.pitch_scale = 1.0
			audio_player.stream = audios_dias[indice_legado]
			audio_player.play()
			print("Rádio: Tocando transmissão legada do Dia ", dia)
		else:
			print("Rádio: Sem transmissões cadastradas para o Dia ", dia)
		return

	_pausa_atual = float(dados_dia.get("pausa_entre_frases", pausa_padrao_entre_frases))
	_indice_frase = 0
	interacao_ativa = true
	prompt_interacao = "Desligar Rádio"

	transmissao_iniciada.emit(dia)
	_atualizar_proximidade_ouvinte(true)
	_iniciar_frase_atual()
	print("Rádio: Iniciando boletim sincronizado do Dia ", dia)


func parar_radio() -> void:
	var estava_ativo := esta_transmitindo() or (audio_player != null and audio_player.playing)
	_interromper_transmissao_interna(true)
	if estava_ativo:
		print("Rádio desligado.")


func _executar_interacao(_jogador: Node3D) -> void:
	if esta_transmitindo() or (audio_player != null and audio_player.playing):
		parar_radio()
	else:
		print("Rádio indisponível fora do horário de transmissão.")


func _process(delta: float) -> void:
	if _modo_audio_legado:
		if audio_player != null and not audio_player.playing:
			if repetir_transmissao:
				audio_player.play()
			else:
				_modo_audio_legado = false
		return

	if _estado == EstadoTransmissao.INATIVO:
		return

	_atualizar_proximidade_ouvinte(false)

	match _estado:
		EstadoTransmissao.DIGITANDO:
			_processar_digitacao(delta)
		EstadoTransmissao.PAUSA_ENTRE_FRASES:
			_tempo_pausa_restante -= delta
			if _tempo_pausa_restante <= 0.0:
				_indice_frase += 1
				if _indice_frase < _fila_frases.size():
					_iniciar_frase_atual()
				else:
					_concluir_ciclo_boletim()
		EstadoTransmissao.PAUSA_REPETICAO:
			_tempo_pausa_restante -= delta
			if _tempo_pausa_restante <= 0.0:
				_reiniciar_ciclo_boletim()


func _iniciar_frase_atual() -> void:
	if _indice_frase < 0 or _indice_frase >= _fila_frases.size():
		_concluir_ciclo_boletim()
		return

	_texto_atual = _fila_frases[_indice_frase]
	_caracteres_visiveis = mini(1, _texto_atual.length())
	_tempo_acumulado_char = 0.0
	_estado = EstadoTransmissao.DIGITANDO

	legenda_atualizada.emit(_texto_atual, _caracteres_visiveis)
	_tocar_proximo_clipe_vocal()


func _processar_digitacao(delta: float) -> void:
	var total_chars := _texto_atual.length()
	if total_chars <= 0:
		_entrar_em_pausa_frase()
		return

	_tempo_acumulado_char += delta
	var passo := maxf(0.005, velocidade_texto)

	while _tempo_acumulado_char >= passo and _caracteres_visiveis < total_chars:
		_tempo_acumulado_char -= passo
		_caracteres_visiveis += 1
		legenda_atualizada.emit(_texto_atual, _caracteres_visiveis)

	var restantes := total_chars - _caracteres_visiveis
	if restantes > 2:
		if audio_player != null and not audio_player.playing:
			_cursor_clipe_longo = 0.0
			_tocar_proximo_clipe_vocal()
	elif _caracteres_visiveis >= total_chars:
		_entrar_em_pausa_frase()


func _entrar_em_pausa_frase() -> void:
	_estado = EstadoTransmissao.PAUSA_ENTRE_FRASES
	_tempo_pausa_restante = maxf(0.2, _pausa_atual)
	_parar_voz_suavemente()


func _concluir_ciclo_boletim() -> void:
	_parar_voz_suavemente()
	if repetir_transmissao and not _fila_frases.is_empty():
		_estado = EstadoTransmissao.PAUSA_REPETICAO
		_tempo_pausa_restante = maxf(0.5, pausa_entre_repeticoes)
		transmissao_finalizada.emit()
	else:
		_estado = EstadoTransmissao.INATIVO
		transmissao_finalizada.emit()


func _reiniciar_ciclo_boletim() -> void:
	if _fila_frases.is_empty():
		_estado = EstadoTransmissao.INATIVO
		return
	_indice_frase = 0
	_cursor_clipe_longo = 0.0
	transmissao_iniciada.emit(_dia_atual_transmissao)
	_atualizar_proximidade_ouvinte(true)
	_iniciar_frase_atual()


func _interromper_transmissao_interna(emitir_desligado: bool) -> void:
	_estado = EstadoTransmissao.INATIVO
	_modo_audio_legado = false
	_fila_frases.clear()
	_texto_atual = ""
	_caracteres_visiveis = 0
	_ultima_proximidade = -1.0
	_cursor_clipe_longo = 0.0

	if _tween_fade_voz and _tween_fade_voz.is_valid():
		_tween_fade_voz.kill()

	if audio_player != null:
		audio_player.stop()
		audio_player.volume_db = _volume_base_db

	if emitir_desligado:
		radio_desligado.emit()


func _tocar_proximo_clipe_vocal() -> void:
	if audio_player == null:
		return

	var validos := _obter_sons_validos()
	if validos.is_empty():
		return

	if _tween_fade_voz and _tween_fade_voz.is_valid():
		_tween_fade_voz.kill()

	var novo_indice := 0
	if validos.size() > 1:
		novo_indice = randi() % validos.size()
		if novo_indice == _indice_som_atual:
			novo_indice = (_indice_som_atual + 1) % validos.size()
	_indice_som_atual = novo_indice
	var clipe: AudioStream = validos[_indice_som_atual]
	_desativar_loop_stream(clipe)

	audio_player.volume_db = _volume_base_db
	audio_player.pitch_scale = randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
	audio_player.stream = clipe

	# Se o clipe for mais longo que uma frase (~>4s), avança sequencialmente pela faixa sem pular para silêncio
	var duracao := clipe.get_length()
	var inicio := 0.0
	if duracao > 4.0:
		if _cursor_clipe_longo >= duracao - 1.5:
			_cursor_clipe_longo = 0.0
		inicio = clampf(_cursor_clipe_longo, 0.0, maxf(0.0, duracao - 1.5))
	audio_player.play(inicio)


func _parar_voz_suavemente() -> void:
	if audio_player == null or not audio_player.playing:
		return

	if audio_player.stream != null and audio_player.stream.get_length() > 4.0:
		_cursor_clipe_longo = audio_player.get_playback_position()

	if _tween_fade_voz and _tween_fade_voz.is_valid():
		_tween_fade_voz.kill()

	_tween_fade_voz = create_tween()
	_tween_fade_voz.tween_property(audio_player, "volume_db", -42.0, 0.08)
	_tween_fade_voz.tween_callback(func() -> void:
		if audio_player != null:
			audio_player.stop()
			audio_player.volume_db = _volume_base_db
	)


func _obter_sons_validos() -> Array[AudioStream]:
	var lista: Array[AudioStream] = []
	for s in sons_jornal:
		if s != null:
			lista.append(s)
	return lista


func _desativar_loop_stream(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false


func _obter_dados_dia(dia: int) -> Dictionary:
	for item in transmissoes_dias:
		if int(item.get("dia", -1)) == dia:
			return item

	var idx := dia - 1
	if idx >= 0 and idx < transmissoes_dias.size():
		return transmissoes_dias[idx]

	return {}


func _atualizar_proximidade_ouvinte(forcar_emissao: bool) -> void:
	var fator := _calcular_fator_proximidade()
	if forcar_emissao or not is_equal_approx(fator, _ultima_proximidade):
		_ultima_proximidade = fator
		proximidade_alterada.emit(fator)


func _calcular_fator_proximidade() -> float:
	var pos_ouvinte := _obter_posicao_ouvinte()
	if pos_ouvinte == Vector3.INF:
		return 1.0

	var alcance := alcance_audicao_legenda
	if audio_player != null and audio_player.max_distance > 0.0:
		alcance = maxf(alcance_audicao_legenda, audio_player.max_distance)

	if alcance <= 0.01:
		return 1.0

	var dist := global_position.distance_to(pos_ouvinte)
	if dist >= alcance:
		return 0.0

	var inicio_fade := alcance * 0.65
	if dist <= inicio_fade:
		return 1.0

	return clampf(1.0 - ((dist - inicio_fade) / maxf(0.01, alcance - inicio_fade)), 0.0, 1.0)


func _obter_posicao_ouvinte() -> Vector3:
	var tree := get_tree()
	if tree == null:
		return Vector3.INF

	var vp := get_viewport()
	if vp != null:
		var cam := vp.get_camera_3d()
		if cam != null and is_instance_valid(cam):
			return cam.global_position

	var jogador := tree.get_first_node_in_group("player") as Node3D
	if jogador != null and is_instance_valid(jogador):
		return jogador.global_position

	return Vector3.INF
