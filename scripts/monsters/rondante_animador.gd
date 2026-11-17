class_name RondanteAnimador
extends RefCounted

## Utilitário que unifica a malha base e todas as animações reais do Rondante
## em uma única AnimationLibrary sobre o esqueleto compartilhado RIG-Monstro/Skeleton3D.

const CENA_BASE_MONSTRO := "res://assets/monstro/animacoes/walkcycle/WALKCYCLE.blend"
const ANIM_ORIGEM_BLENDER := &"RIG-MonstroAction"

const FONTES_ANIMACOES: Dictionary = {
	&"walkcycle": {
		"path": "res://assets/monstro/animacoes/walkcycle/WALKCYCLE.blend",
		"loop": Animation.LOOP_LINEAR
	},
	&"wall_peek": {
		"path": "res://assets/monstro/animacoes/wall_peek/WALL PEEK.blend",
		"loop": Animation.LOOP_NONE
	},
	&"desnorteado": {
		"path": "res://assets/monstro/animacoes/desnorteado/Desnorteado.blend",
		"loop": Animation.LOOP_NONE
	},
	&"atacar_garras": {
		"path": "res://assets/monstro/animacoes/atacar_garras/AtacarGarras.blend",
		"loop": Animation.LOOP_NONE
	},
	&"bater_chao": {
		"path": "res://assets/monstro/animacoes/bater_chao/BaterChaoAnim.blend",
		"loop": Animation.LOOP_NONE
	}
}


static func montar_no_pivo(modelo_pivot: Node3D) -> AnimationPlayer:
	if modelo_pivot == null:
		return null

	var ap_existente := modelo_pivot.get_node_or_null("AnimationPlayerUnificado") as AnimationPlayer
	if ap_existente != null and modelo_pivot.get_node_or_null("RIG-Monstro") != null:
		return ap_existente

	var rig := modelo_pivot.get_node_or_null("RIG-Monstro") as Node3D
	if rig == null:
		if not ResourceLoader.exists(CENA_BASE_MONSTRO):
			return null
		var cena_base := load(CENA_BASE_MONSTRO) as PackedScene
		if cena_base == null:
			return null
		var inst_base := cena_base.instantiate()
		_remover_nos_extras_blender(inst_base)
		var rig_origem := inst_base.get_node_or_null("RIG-Monstro") as Node3D
		if rig_origem != null:
			inst_base.remove_child(rig_origem)
			_limpar_owner_recursivo(rig_origem)
			modelo_pivot.add_child(rig_origem)
			rig = rig_origem
		inst_base.free()

	if rig == null:
		return null

	var ap := modelo_pivot.get_node_or_null("AnimationPlayerUnificado") as AnimationPlayer
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "AnimationPlayerUnificado"
		modelo_pivot.add_child(ap)

	ap.root_node = NodePath("..")

	var lib := AnimationLibrary.new()
	for nome_anim in FONTES_ANIMACOES.keys():
		var spec: Dictionary = FONTES_ANIMACOES[nome_anim]
		var caminho: String = spec["path"]
		var modo_loop: int = int(spec["loop"])
		var anim := _extrair_animacao(caminho, modo_loop)
		if anim != null:
			lib.add_animation(nome_anim, anim)

	if ap.has_animation_library(&""):
		ap.remove_animation_library(&"")
	ap.add_animation_library(&"", lib)
	return ap


static func _extrair_animacao(caminho: String, modo_loop: int) -> Animation:
	if not ResourceLoader.exists(caminho):
		return null
	var ps := load(caminho) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate()
	var ap_src := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var anim_copia: Animation = null
	if ap_src != null:
		var nome_src := ANIM_ORIGEM_BLENDER
		if not ap_src.has_animation(nome_src):
			var lista := ap_src.get_animation_list()
			if not lista.is_empty():
				nome_src = StringName(lista[0])
		if ap_src.has_animation(nome_src):
			anim_copia = ap_src.get_animation(nome_src).duplicate(true) as Animation
			anim_copia.loop_mode = modo_loop
	inst.free()
	return anim_copia


static func _limpar_owner_recursivo(no: Node) -> void:
	no.owner = null
	for filho in no.get_children():
		_limpar_owner_recursivo(filho)


static func _remover_nos_extras_blender(raiz: Node) -> void:
	for filho in raiz.get_children():
		if filho is Camera3D or filho.name == "Cube" or filho.name == "AnimationPlayer":
			raiz.remove_child(filho)
			filho.free()
		else:
			_remover_nos_extras_blender(filho)
