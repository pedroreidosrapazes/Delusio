class_name PortaEntrada
extends Interactable

## Porta interativa com suporte a AnimationPlayer.

@export var animation_player: AnimationPlayer
@export var abrirPortaEntrada: String = "abrir_porta"
@export var fecharPortaEntrada: String = "fechar_porta"

var esta_aberta: bool = false
var animando: bool = false


func _ready() -> void:
	prompt_interacao = "Abrir Porta"
	_resolver_animation_player()


func _resolver_animation_player() -> void:
	if animation_player != null:
		return

	# Tenta encontrar no próprio nó
	animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		return

	# Tenta encontrar no nó pai
	var pai := get_parent()
	if pai != null:
		animation_player = pai.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation_player != null:
			return

		# Tenta encontrar no nó avô (ex: Casa)
		var avo := pai.get_parent()
		if avo != null:
			animation_player = avo.get_node_or_null("AnimationPlayer") as AnimationPlayer


func _executar_interacao(_jogador: Node3D = null) -> void:
	if animando:
		return

	if animation_player == null:
		_resolver_animation_player()

	if esta_aberta:
		fechar_porta()
	else:
		abrir_porta()


func _obter_animacao_abrir() -> String:
	if animation_player == null:
		return ""
	if animation_player.has_animation(abrirPortaEntrada):
		return abrirPortaEntrada
	for nome in ["brirPortaEntrada", "abrirPortaEntrada", "AbrirPorta", "abrir_porta", "open"]:
		if animation_player.has_animation(nome):
			return nome
	for anim in animation_player.get_animation_list():
		var anim_lower := anim.to_lower()
		if "porta" in anim_lower or "abrir" in anim_lower or "open" in anim_lower:
			return anim
	return ""


func _obter_animacao_fechar() -> String:
	if animation_player == null:
		return ""
	if animation_player.has_animation(fecharPortaEntrada):
		return fecharPortaEntrada
	for nome in ["fecharPortaEntrada", "FecharPorta", "fechar_porta", "close"]:
		if animation_player.has_animation(nome):
			return nome
	return ""


func abrir_porta() -> void:
	if animation_player == null:
		_resolver_animation_player()
	if animation_player == null:
		push_warning("PortaEntrada: AnimationPlayer não configurado ou não encontrado.")
		return

	var anim := _obter_animacao_abrir()
	if anim != "":
		animando = true
		prompt_interacao = "Fechar Porta"
		animation_player.play(anim)
		await animation_player.animation_finished
		esta_aberta = true
		animando = false
	else:
		push_warning("PortaEntrada: Nenhuma animação de abertura encontrada no AnimationPlayer.")


func fechar_porta() -> void:
	if animation_player == null:
		_resolver_animation_player()
	if animation_player == null:
		push_warning("PortaEntrada: AnimationPlayer não configurado ou não encontrado.")
		return

	var anim_fechar := _obter_animacao_fechar()
	var anim_abrir := _obter_animacao_abrir()

	if anim_fechar != "":
		animando = true
		prompt_interacao = "Abrir Porta"
		animation_player.play(anim_fechar)
		await animation_player.animation_finished
		esta_aberta = false
		animando = false
	elif anim_abrir != "":
		animando = true
		prompt_interacao = "Abrir Porta"
		animation_player.play_backwards(anim_abrir)
		await animation_player.animation_finished
		esta_aberta = false
		animando = false
	else:
		push_warning("PortaEntrada: Nenhuma animação de fechamento/abertura encontrada no AnimationPlayer.")
