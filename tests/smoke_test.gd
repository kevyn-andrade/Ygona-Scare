extends SceneTree
## Smoke test para executar NO Godot 4.7.2: 
## godot --headless --path . --script res://tests/smoke_test.gd
## Valida a abertura da cena, projeção isométrica e acesso aos objetivos.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var level: PackedScene = load("res://scenes/main.tscn")
    if level == null:
        push_error("Falha ao abrir main.tscn")
        quit(1)
        return
    var game: Node2D = level.instantiate()
    root.add_child(game)
    await process_frame
    var original: Vector2 = Vector2(432.3, 265.7)
    var screen_point: Vector2 = game.iso_renderer.project(original)
    var round_trip: Vector2 = game.iso_renderer.unproject(screen_point)
    if round_trip.distance_to(original) > 0.01:
        push_error("Projecao isometrica nao e invertivel")
        quit(1)
        return
    # Regressao: os assets que substituem milhares de primitivas existem.
    if game.iso_renderer.floor_texture == null:
        push_error("Cache do piso nao foi carregado")
        quit(1)
        return
    if game.iso_renderer.wall_bands.size() < 70:
        push_error("Bandas de paredes faltando")
        quit(1)
        return
    # Lanterna completamente guardada nao emite luz.
    game.light_on = false
    game.flashlight_pose = 0.0
    if game.is_illuminated(game.monster):
        push_error("Lanterna guardada ainda ilumina")
        quit(1)
        return
    # Guardar a lanterna nao destrói a carga ja acumulada.
    game.energy = 100.0
    game._update_light(0.016)
    if game.energy < 99.9:
        push_error("Carga de bateria perdida ao guardar a lanterna")
        quit(1)
        return
    var origin: Vector2 = game.tile(26,32)
    var targets: Array = [Vector2i(10,11),Vector2i(43,8),Vector2i(11,26),Vector2i(44,27),Vector2i(26,29),Vector2i(26,34)]
    for point in targets:
        var destination: Vector2 = game.map.cell_center(point.x,point.y)
        if game.map.route(origin,destination).is_empty():
            push_error("Objetivo inacessivel: %s" % point)
            quit(1)
            return
    print("YGONA SCARE: CENA, PROJECAO, CACHE, LANTERNA E ROTAS OK")
    quit(0)
