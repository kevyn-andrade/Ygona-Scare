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
    # Bateria fraca encolhe o cone (alcance e abertura).
    game.energy = 100.0
    var full_range: float = game.CFG.LIGHT_RANGE
    var full_angle: float = game.light_half_angle()
    game.energy = 8.0
    game.light_on = true
    game.flashlight_pose = 1.0
    if game.light_range() > full_range*0.7 or game.light_half_angle() > full_angle*0.8:
        push_error("Cone nao encolhe com a bateria fraca")
        quit(1)
        return
    game.light_on = false
    game.flashlight_pose = 0.0
    game.energy = 100.0
    # Abertura: vestibulo trancado, entidade ausente enquanto ha luz na casa.
    var origin: Vector2 = game.tile(26,32)
    if not game.map.route(origin,game.tile(26,20)).is_empty():
        push_error("O vestibulo deveria comecar trancado")
        quit(1)
        return
    if game.monster_present():
        push_error("A entidade nao deveria estar ativa antes da queda de luz")
        quit(1)
        return
    for point in [Vector2i(22,32),Vector2i(28,28),Vector2i(32,33),Vector2i(26,28)]:
        if game.map.route(origin,game.map.cell_center(point.x,point.y)).is_empty():
            push_error("Objeto da abertura inacessivel: %s" % point)
            quit(1)
            return
    game._open_foyer_door()
    game._trigger_blackout()
    for i in range(int((game.CFG.WAKE_DELAY+2.5)*60.0)):
        game._update_opening(1.0/60.0)
    if not game.monster_present() or game.house_light > 0.01:
        push_error("Queda de luz nao ativou a entidade / escuridao")
        quit(1)
        return
    # Fragmentos pulsam, e mais forte com a entidade por perto.
    var far_peak: float = 0.0
    var near_peak: float = 0.0
    game.monster = game.player + Vector2(2000,0)
    for i in range(100):
        game.pulse_phase = float(i)/100.0
        far_peak = maxf(far_peak,game.fragment_pulse(0))
    game.monster = game.player + Vector2(40,0)
    for i in range(100):
        game.pulse_phase = float(i)/100.0
        near_peak = maxf(near_peak,game.fragment_pulse(0))
    if far_peak < 0.2 or near_peak <= far_peak:
        push_error("Pulso dos fragmentos incorreto: %s / %s" % [far_peak,near_peak])
        quit(1)
        return
    # Teletransporte curto: aproxima, mas nunca cola na jogadora.
    game.monster = game.tile(26,11)
    game.player = game.tile(26,25)
    var before: float = game.monster.distance_to(game.player)
    if not game._monster_blink() or game.monster.distance_to(game.player) >= before or game.monster.distance_to(game.player) < game.CFG.TELEPORT_KEEP:
        push_error("Teletransporte da entidade incorreto")
        quit(1)
        return
    # Silicones das sacrificadas: um por vitima, com etiqueta legivel ao pegar.
    if game.VICTIMS.size() != 3:
        push_error("Deveriam existir tres vitimas")
        quit(1)
        return
    var silicones: Array = game.scene_objects.filter(func(o): return o["kind"] == "fragment")
    game.status = "playing"
    game.library_open = true
    game.player = silicones[0]["at"]
    game._interact()
    if game.collected_count() != 1 or game.status != "reading" or not str(game.reading["title"]).contains("DALVA"):
        push_error("Pegar o silicone deveria abrir a etiqueta da vitima")
        quit(1)
        return
    game._close_reading()
    game.fragment_owned = [false,false,false]
    game.library_open = false
    # Rastro de sangue e coracao acompanham a entidade.
    game.blood_trail = []
    game.monster = game.tile(26,13)
    game.trail_anchor = game.monster
    game.player = game.tile(26,25)
    game.light_on = false
    game.flashlight_pose = 0.0
    game.monster_state = "RONDA"
    for i in range(240):
        game._update_monster(1.0/60.0)
    if game.blood_trail.is_empty():
        push_error("A entidade nao deixou rastro")
        quit(1)
        return
    game.status = "playing"
    game.monster = game.player + Vector2(60,0)
    game._update_dread(0.016)
    if game.dread < 0.5:
        push_error("O pavor deveria crescer com a entidade perto")
        quit(1)
        return
    # Aparicao falsa: surge fora da luz e estoura quando encarada.
    game.player = game.tile(26,20)
    game.monster = game.tile(45,5)
    game.aim_override = Vector2(0,-1)
    game.look = Vector2(0,-1)
    game.light_on = false
    game.flashlight_pose = 0.0
    var spawned: bool = false
    for i in range(20):
        if game._spawn_apparition():
            spawned = true
            break
    if not spawned or game.music_duck < 0.9 or game.map.is_wall_at(game.apparition["at"]):
        push_error("A aparicao falsa nao surgiu corretamente")
        quit(1)
        return
    game.player = game.apparition["at"] + Vector2(20,0)
    game._update_haunting(0.016)
    if not game.apparition.is_empty() or game.glitch < 0.5:
        push_error("A aparicao deveria estourar ao ser tocada")
        quit(1)
        return
    # A luz nao segura a entidade para sempre: a sombra alcanca a lanterna.
    game.player = game.tile(26,24)
    game.monster = game.tile(26,20)
    game.energy = 100.0
    game.light_on = true
    game.flashlight_pose = 1.0
    game.light_jam = 0.0
    game.freeze_time = 0.0
    var jammed: bool = false
    for i in range(int((game.shadow_seconds(128.0)+1.0)*60.0)):
        game._update_monster(1.0/60.0)
        if game.light_jam > 0.0:
            jammed = true
            break
    if not jammed:
        push_error("A sombra deveria apagar a lanterna depois de um tempo")
        quit(1)
        return
    game.light_jam = 0.0
    game.light_on = false
    game.flashlight_pose = 0.0
    game.status = "playing"
    # Esconder-se com ela olhando nao funciona.
    game.player = game.hiding_places[0] + Vector2(0,30)
    game.monster = game.player + Vector2(90,0)
    game.monster_state = "PERSEGUINDO"
    game._interact()
    if not game.in_hiding or not game.hide_compromised:
        push_error("Esconderijo deveria ficar comprometido com a entidade olhando")
        quit(1)
        return
    game._interact()
    game.monster = game.tile(45,5)
    game.monster_state = "RONDA"
    game.aim_override = Vector2.ZERO
    # Regressao: laco ligado por codigo sem loop_end deixava todas as trilhas mudas.
    for player in game.music.ambient_players + [game.music.stalker, game.music.theme, game.music.theme_reverse]:
        if player.stream == null or player.stream.loop_end <= 0 or not player.playing:
            push_error("Trilha em laco sem fim definido ou parada: %s" % player.name)
            quit(1)
            return
    if game.fear_rect == null or game.music.theme.stream == null:
        push_error("Filtro de pavor ou trilha de fundo ausentes")
        quit(1)
        return
    if game.mask_viewport == null or game.darkness_rect.material == null:
        push_error("Camada de escuridao ausente")
        quit(1)
        return
    var targets: Array = [Vector2i(10,11),Vector2i(43,8),Vector2i(11,26),Vector2i(44,27),Vector2i(26,29),Vector2i(26,34)]
    for point in targets:
        var destination: Vector2 = game.map.cell_center(point.x,point.y)
        if game.map.route(origin,destination).is_empty():
            push_error("Objetivo inacessivel: %s" % point)
            quit(1)
            return
    print("AFRODITE SCARE: CENA, PROJECAO, CACHE, LANTERNA, ABERTURA, PULSOS, SILICONES, PAVOR, ASSOMBRACOES E ROTAS OK")
    quit(0)
