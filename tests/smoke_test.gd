extends SceneTree
## Smoke test para executar NO Godot 4.7.2: 
## godot --headless --path . --script res://tests/smoke_test.gd
## Valida a abertura da cena, projeção isométrica e acesso aos objetivos.

func _initialize() -> void:
    call_deferred("_run")

func _walk(game: Node2D, keys: Array, frames: int) -> void:
    ## Segura as teclas e roda o movimento da protagonista quadro a quadro.
    for key in keys:
        var down: InputEventKey = InputEventKey.new()
        down.keycode = key
        down.pressed = true
        Input.parse_input_event(down)
    for i in range(frames):
        game._update_player(1.0/60.0)
    for key in keys:
        var up: InputEventKey = InputEventKey.new()
        up.keycode = key
        up.pressed = false
        Input.parse_input_event(up)

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
    # Quinas do vestibulo fechadas.
    if not game.map.is_wall_cell(18,27) or not game.map.is_wall_cell(34,27):
        push_error("Faltam os blocos de quina do vestibulo")
        quit(1)
        return
    # Com a porta trancada so o vestibulo tem luz; o resto da casa fica escuro.
    if not game.foyer_sealed() or game.foyer_light_level() <= 0.05 or game.foyer_light_level() >= 0.6:
        push_error("O vestibulo deveria comecar isolado no escuro (nivel %s)" % game.foyer_light_level())
        quit(1)
        return
    # Abrir a porta com a chave: a casa fica acesa mais um instante e so entao apaga.
    game.foyer_key_owned = true
    game.player = game.tile(26,28)+Vector2(0,-6)
    game._interact()
    if not game.foyer_door_open or not game.power_on or game.foyer_sealed():
        push_error("Abrir a porta deveria acender a casa por um instante antes do apagao")
        quit(1)
        return
    for i in range(int(game.CFG.BLACKOUT_DELAY*60.0)-6):
        game._update_opening(1.0/60.0)
    if not game.power_on:
        push_error("O apagao veio antes de BLACKOUT_DELAY")
        quit(1)
        return
    for i in range(12):
        game._update_opening(1.0/60.0)
    if game.power_on:
        push_error("O apagao deveria vir logo depois de BLACKOUT_DELAY")
        quit(1)
        return
    game.player = origin
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
    # A lanterna obedece so ao mouse: andar com as setas nao gira o facho.
    game.status = "playing"
    game.player = game.tile(26,20)
    game._update_aim()
    var aim_before: Vector2 = game.look
    game.moving = true
    game.direction = aim_before.orthogonal()
    for i in range(30):
        game._update_aim()
    game.moving = false
    if game.look.distance_to(aim_before) > 0.001:
        push_error("A lanterna deveria seguir so o mouse, nao a direcao do passo")
        quit(1)
        return
    # Colisao: ela esbarra no altar em vez de atravessa-lo.
    Input.use_accumulated_input = false
    game.in_hiding = false
    game.light_on = false
    game.flashlight_pose = 0.0
    game.ghost_mode = false
    game.player = game.tile(26,32)
    _walk(game, [KEY_RIGHT, KEY_UP], 40)
    if game.player.y < 970.0:
        push_error("A protagonista atravessou o altar: %s" % game.player)
        quit(1)
        return
    # Paredes Espectrais: fechadas com a luz comum...
    var hall_side: Vector2 = Vector2(19.6*32.0, 21.0*32.0)
    game.energy = 100.0
    game.light_jam = 0.0
    game.light_on = true
    game.flashlight_pose = 1.0
    game.player = hall_side
    _walk(game, [KEY_LEFT, KEY_UP], 60)
    if game.player.x < 610.0:
        push_error("A Parede Espectral deveria bloquear com a luz comum: %s" % game.player)
        quit(1)
        return
    # ...atravessaveis com a luz espectral acesa...
    game.ghost_mode = true
    game.player = hall_side
    _walk(game, [KEY_LEFT, KEY_UP], 60)
    if game.player.x > 560.0 or game.map.room_name(game.player) != "QUARTO":
        push_error("A luz espectral deveria abrir a Parede Espectral: %s" % game.player)
        quit(1)
        return
    # ...e, se a luz espectral apagar no meio, ela ainda consegue sair.
    game.ghost_mode = false
    game.player = game.tile(18,20)+Vector2(0,10)
    _walk(game, [KEY_LEFT, KEY_UP], 20)
    if game.map.touches_spectral(game.player, 9.0):
        push_error("A protagonista ficou presa dentro da Parede Espectral: %s" % game.player)
        quit(1)
        return
    game.light_on = false
    game.flashlight_pose = 0.0
    # Afrodite nunca usa as Paredes Espectrais; espera na boca da passagem.
    for passage in ManorMap.SPECTRAL_PASSAGES:
        for cell in passage:
            if not game.map.is_wall_cell(cell.x, cell.y) or game.map.is_wall_cell(cell.x, cell.y, true):
                push_error("Celula espectral com estado errado: %s" % cell)
                quit(1)
                return
    var around: Array = game.map.route(game.tile(19,20), game.tile(17,20))
    if around.is_empty() or around.any(func(c): return game.map.is_spectral_cell(c.x, c.y)):
        push_error("A rota da entidade passou por uma Parede Espectral")
        quit(1)
        return
    var to_mouth: Array = game.map.route(game.tile(23,20), game.tile(18,20))
    if to_mouth.is_empty() or to_mouth[-1] != Vector2i(19,20):
        push_error("A entidade deveria esperar na boca da passagem: %s" % [to_mouth])
        quit(1)
        return
    var targets: Array = [Vector2i(10,11),Vector2i(43,8),Vector2i(11,26),Vector2i(44,27),Vector2i(26,29),Vector2i(26,34)]
    for point in targets:
        var destination: Vector2 = game.map.cell_center(point.x,point.y)
        if game.map.route(origin,destination).is_empty():
            push_error("Objetivo inacessivel: %s" % point)
            quit(1)
            return
    print("AFRODITE SCARE: CENA, PROJECAO, CACHE, LANTERNA, MIRA, COLISAO, PAREDES ESPECTRAIS, ABERTURA, PULSOS, SILICONES, PAVOR, ASSOMBRACOES E ROTAS OK")
    quit(0)
