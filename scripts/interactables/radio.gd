class_name Radio
extends Interactable

## Rádio interativo que reproduz notícias diárias.

@export_category("Configurações do Player de Áudio")
@export var audio_player: AudioStreamPlayer3D 

@export_category("Transmissões de Áudio do Rádio")
@export var audios_dias: Array[AudioStream]

func _ready() -> void:
	prompt_interacao = "Desligar Rádio"
	if audio_player == null:
		audio_player = get_node_or_null("AudioPlayer") as AudioStreamPlayer3D

func tocar_noticia(dia: int) -> void:
	if audio_player == null:
		audio_player = get_node_or_null("AudioPlayer") as AudioStreamPlayer3D
		
	if audio_player == null:
		print("ERRO no Rádio: Nenhum nó AudioStreamPlayer3D foi encontrado como filho do Rádio!")
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
