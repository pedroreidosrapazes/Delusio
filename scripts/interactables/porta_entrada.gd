class_name PortaEntrada
extends Interactable

## Porta interativa com sincronização de animações via AnimationPlayer e RayCast.

@export_category("Configurações de Animação")
@export var animation_player: AnimationPlayer
@export var animacao_abrir: String = ""
@export var animacao_fechar: String = ""

# Propriedades legadas mantidas para compatibilidade
@export var abrirPortaEntrada: String = ""
@export var fecharPortaEntrada: String = ""

var esta_aberta: bool = false
var animando: bool = false

func _ready() -> void:
	prompt_interacao = "Abrir Porta"
	_resolver_animation_player()
	_deduzir_animacoes_automaticas()

func _resolver_animation_player() -> void:
	if animation_player != null:
		return

	# 1. Procura no próprio nó
	animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		return

	# 2. Procura no nó pai (ex: portaEntrada)
	var pai := get_parent()
	if pai != null:
		animation_player = pai.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation_player != null:
			return

		# 3. Procura no nó avô (ex: Casa _final-col)
		var avo := pai.get_parent()
		if avo != null:
			animation_player = avo.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if animation_player != null:
				return
				
			# 4. Procura em qualquer filho do avô
			for filho in avo.get_children():
				if filho is AnimationPlayer:
					animation_player = filho
					return

## Dedução automática inteligente das animações do modelo com base no nome do nó
func _deduzir_animacoes_automaticas() -> void:
	# Prioriza valores exportados explícitos se definidos
	if animacao_abrir.is_empty() and not abrirPortaEntrada.is_empty():
		animacao_abrir = abrirPortaEntrada
	if animacao_fechar.is_empty() and not fecharPortaEntrada.is_empty():
		animacao_fechar = fecharPortaEntrada

	if not animacao_abrir.is_empty():
		return

	var nome_contexto := name.to_lower()
	if get_parent():
		nome_contexto += " " + get_parent().name.to_lower()

	if "quarto" in nome_contexto:
		animacao_abrir = "abrirPortaQuarto"
		animacao_fechar = "fecharPortaQuarto"
	elif "001" in nome_contexto or "banheiro" in nome_contexto:
		animacao_abrir = "abrirPortaBanheiro"
		animacao_fechar = "" # Fecha no reverso
	elif "entrada" in nome_contexto:
		animacao_abrir = "AbrirPortaEntrada"
		animacao_fechar = "" # Fecha no reverso
	else:
		# Fallback padrão
		animacao_abrir = "AbrirPortaEntrada"
		animacao_fechar = ""

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

	if animation_player.has_animation(animacao_abrir):
		return animacao_abrir

	# Procura variações com maiúsculas/minúsculas
	for anim in animation_player.get_animation_list():
		if anim.to_lower() == animacao_abrir.to_lower():
			return anim

	return ""

func _obter_animacao_fechar() -> String:
	if animation_player == null:
		return ""

	if not animacao_fechar.is_empty() and animation_player.has_animation(animacao_fechar):
		return animacao_fechar

	for anim in animation_player.get_animation_list():
		if not animacao_fechar.is_empty() and anim.to_lower() == animacao_fechar.to_lower():
			return anim

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
		push_warning("PortaEntrada: Nenhuma animação de abertura encontrada para '%s'." % animacao_abrir)

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
		# Se não houver animação dedicada de fechar, toca a de abrir em reverso
		animando = true
		prompt_interacao = "Abrir Porta"
		animation_player.play_backwards(anim_abrir)
		await animation_player.animation_finished
		esta_aberta = false
		animando = false
	else:
		push_warning("PortaEntrada: Nenhuma animação para fechar a porta.")
