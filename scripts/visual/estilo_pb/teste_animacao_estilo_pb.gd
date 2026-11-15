extends SceneTree

const LIMITE_PIXELS_DIFERENTES := 50
const LIMITE_DELTA_MEDIO := 0.0001


func _initialize() -> void:
	call_deferred("_executar")


func _capturar() -> Image:
	RenderingServer.force_draw(false)
	await process_frame
	return root.get_texture().get_image()


func _comparar(a: Image, b: Image) -> Dictionary:
	var diferentes := 0
	var delta_total := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var cor_a := a.get_pixel(x, y)
			var cor_b := b.get_pixel(x, y)
			var delta: float = abs(cor_a.r - cor_b.r) + abs(cor_a.g - cor_b.g) + abs(cor_a.b - cor_b.b)
			if delta > 0.01:
				diferentes += 1
			delta_total += delta
	return {
		"pixels_diferentes": diferentes,
		"delta_medio": delta_total / float(a.get_width() * a.get_height()),
	}


func _executar() -> void:
	var cena := load("res://scenes/demos/estilo_pb/demo_estilo_pb.tscn") as PackedScene
	if cena == null:
		push_error("Não foi possível carregar a cena demo do estilo PB.")
		quit(1)
		return
	root.add_child(cena.instantiate())
	await process_frame
	await process_frame
	var antes := await _capturar()
	await create_timer(0.73).timeout
	var depois := await _capturar()
	var diferenca := _comparar(antes, depois)
	print("Faixa animada após 730 ms: %s" % diferenca)
	if diferenca.pixels_diferentes < LIMITE_PIXELS_DIFERENTES or diferenca.delta_medio < LIMITE_DELTA_MEDIO:
		push_error("A faixa animada não produziu alteração visível; execute este teste com um renderer gráfico, sem --headless.")
		quit(1)
	else:
		print("OK: tempo do shader moveu a faixa e alterou a imagem renderizada.")
		quit(0)
