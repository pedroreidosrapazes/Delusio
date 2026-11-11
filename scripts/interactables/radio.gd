class_name Radio
extends Interactable

## Rádio interativo que reproduz notícias diárias.

@export_category("Configurações do Player de Áudio")
@export var audio_player: AudioStreamPlayer3D 

@export_category("Transmissões de Áudio do Rádio")
@export var audios_dias: Array[AudioStream]

func _ready() -> void:
	add_to_group("radio")
	prompt_interacao = "Desligar Rádio"
	_garantir_audio_player()

func _garantir_audio_player() -> void:
	if audio_player != null:
		return
	
	# 1. Tenta encontrar por nomes comuns
	audio_player = get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	if audio_player == null:
		audio_player = get_node_or_null("AudioPlayer") as AudioStreamPlayer3D
	
	# 2. Busca qualquer AudioStreamPlayer3D existente nos nós filhos
	if audio_player == null:
		for filho in get_children():
			if filho is AudioStreamPlayer3D:
				audio_player = filho
				break
				
	# 3. Fallback: cria dinamicamente se não existir
	if audio_player == null:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "AudioStreamPlayer3D"
		audio_player.bus = &"Master"
		audio_player.max_distance = 25.0
		add_child(audio_player)

func tocar_noticia(dia: int) -> void:
	_garantir_audio_player()
		
	if audio_player == null:
		print("ERRO no Rádio: Nenhum nó AudioStreamPlayer3D disponível!")
		return

	var indice = dia - 1
	if indice >= 0 and indice < audios_dias.size():
		if audios_dias[indice] != null:
			audio_player.stream = audios_dias[indice]
			audio_player.play()
			print("Rádio: Tocando transmissão do Dia ", dia)
		else:
			print("Rádio: Nenhum arquivo de áudio atribuído para o Dia ", dia)
	else:
		print("Rádio: Sem transmissões cadastradas para o Dia ", dia)

func parar_radio() -> void:
	if audio_player and audio_player.is_playing():
		audio_player.stop()

func _executar_interacao(_jogador: Node3D) -> void:
	if audio_player and audio_player.is_playing():
		audio_player.stop()
		print("Rádio desligado.")
	else:
		print("Rádio indisponível fora do horário de transmissão.")
