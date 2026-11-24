extends SceneTree
## Captura telas de varios momentos do jogo para revisao visual.
## Uso (abre uma janela por alguns segundos):
##   godot --path . --script res://tests/visual_check.gd -- <pasta_de_saida>

var out_dir: String = "user://shots"
var game: Node2D

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() > 0:
        out_dir = args[0]
    DirAccess.make_dir_recursive_absolute(out_dir)
    call_deferred("_run")

func _shot(name: String, frames: int = 8) -> void:
    for i in range(frames):
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
    print("captura: ", name)

func _closeup(name: String, world_at: Vector2, frames: int = 8) -> void:
    ## Recorte ampliado 4x em volta de um ponto do mundo (personagens, objetos).
    for i in range(frames):
        await process_frame
    await RenderingServer.frame_post_draw
    var img: Image = root.get_texture().get_image()
    var k: Vector2 = Vector2(img.get_size())/Vector2(1152.0,720.0)
    var c: Vector2 = (game.iso_renderer.screen(world_at)+Vector2(0,-45))*k
    var half: Vector2 = Vector2(90,90)*k
    var crop: Image = img.get_region(Rect2i(Vector2i(c-half).clamp(Vector2i.ZERO,img.get_size()),Vector2i(half*2.0)))
    crop.resize(720,720,Image.INTERPOLATE_NEAREST)
    crop.save_png(out_dir.path_join(name + ".png"))
    print("captura: ", name)

func _run() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await _shot("01_menu")
    game._restart_entirely()
    game.intro_time = 2.6
    await _shot("02_intro_chegada", 3)
    game.intro_time = 7.3
    await _shot("03_intro_vislumbre", 3)
    game.intro_time = 14.0
    await _shot("04_intro_fragmentos", 3)
    game._begin_play()
    await _shot("05_vestibulo_iluminado", 20)
    game._open_reading("CARTA SOBRE A MESA", ["A quem entrar nesta casa:", "", "QUANDO OUVIR A RISADA, ACENDA A LUZ."])
    await _shot("06_carta")
    game._close_reading()
    game.foyer_key_owned = true
    game._open_foyer_door()
    # Porta aberta, casa ainda acesa (o instante antes do apagao).
    await _shot("06b_porta_aberta_luz", 10)
    game._trigger_blackout()
    game.blackout_clock = 5.0
    game.house_light = 0.0
    game.monster_dormant = 0.0
    game.hint_timer = 0.0
    await _shot("07_escuro_sem_lanterna", 20)
    # Lanterna apontada para o norte, entidade parada dentro do cone.
    game.player = game.tile(26, 24)
    game.light_on = true
    game.flashlight_pose = 1.0
    game.monster = game.tile(26, 19)
    game.aim_override = Vector2(0,-1)
    await _shot("08_cone_com_entidade", 30)
    game.energy = 6.0
    game.monster = game.tile(26, 19)
    await _shot("09_bateria_fraca", 20)
    game.energy = 100.0
    game.light_on = false
    game.flashlight_pose = 0.0
    game.monster = game.tile(29, 22)
    game.monster_state = "RONDA"
    await _shot("10_olhos_no_escuro", 6)
    # Fragmento pulsando no escuro (biblioteca).
    game.monster = game.tile(45, 5)
    game.player = game.tile(12, 12)
    game.library_open = true
    game.pulse_phase = 0.03
    await _shot("11_pulso_fragmento", 30)
    await _closeup("13_silicone_de_perto", game.tile(10, 11), 4)
    # Gesto da lanterna em quatro tempos, de perto, com a casa iluminada.
    game.power_on = true
    game.house_light = 1.0
    game.player = game.tile(26, 31)
    game.previous_player = game.player
    game.aim_override = Vector2(1,1)
    game.set_physics_process(false)
    await _shot("14_vestibulo", 40)
    var n: int = 0
    for pose in [0.0, 0.2, 0.45, 0.75, 1.0]:
        game.light_on = pose > 0.5
        game.flashlight_pose = pose
        game.previous_player = game.player
        await _closeup("14_gesto_%d" % n, game.player, 5)
        n += 1
    # Andando (dois tempos do passo) e com medo, para conferir as curvas.
    game.light_on = false
    game.flashlight_pose = 0.0
    game.moving = true
    game.time_passed = 0.2
    await _closeup("14_andando_0", game.player, 3)
    game.time_passed = 0.6
    game.aim_override = Vector2(-1,0.2)
    game.look = game.aim_override.normalized()
    game.dread = 0.9
    await _closeup("14_andando_1", game.player, 3)
    game.moving = false
    game.dread = 0.0
    game.aim_override = Vector2(1,1)
    game.look = game.aim_override.normalized()
    # A entidade de perto: congelada na luz e perseguindo.
    game.monster = game.tile(28, 31)
    game.previous_monster = game.monster
    game.power_on = false
    game.monster_dormant = 0.0
    game.house_light = 1.0
    game.monster_lit = true
    await _closeup("15_afrodite_congelada", game.monster, 5)
    game.monster_lit = false
    game.monster_state = "PERSEGUINDO"
    await _closeup("16_afrodite_perseguindo", game.monster, 5)
    # Assombracoes: salao com as penduradas, oficina com manequins, esconderijo.
    game.monster = game.tile(45, 5)
    game.previous_monster = game.monster
    game.monster_state = "RONDA"
    game.player = game.tile(26, 17)
    game.previous_player = game.player
    await _shot("19_salao_iluminado", 40)
    await _closeup("20_pendurada", game.tile(30, 17) + Vector2(0,-40), 4)
    game.house_light = 0.0
    game.light_on = true
    game.flashlight_pose = 1.0
    game.player = game.tile(27, 21)
    game.previous_player = game.player
    game.aim_override = Vector2(0.55,-1)
    game.look = game.aim_override.normalized()
    game.apparition = {"at":game.tile(27, 14), "seen":0.0, "ttl":10.0}
    game.freeze_time = 0.0
    await _shot("21_salao_no_escuro", 40)
    game.apparition = {}
    game.monster = game.tile(27, 15)
    game.previous_monster = game.monster
    game.aim_override = Vector2(0,-1)
    game.look = Vector2(0,-1)
    game.monster_lit = true
    game.freeze_time = 4.5
    await _shot("22_sombra_rastejando", 30)
    game.monster_lit = false
    game.freeze_time = 0.0
    game.monster = game.tile(45, 5)
    game.previous_monster = game.monster
    game.player = game.tile(42, 25)
    game.previous_player = game.player
    game.mannequins[1]["at"] = game.tile(42, 22)
    game.mannequins[1]["moved"] = true
    game.mannequins[0]["at"] = game.tile(39, 22)
    game.mannequins[0]["moved"] = true
    await _shot("23_oficina_manequins", 40)
    game.house_light = 1.0
    await _closeup("24_manequim", game.tile(42, 22), 4)
    game.house_light = 0.0
    game.light_on = false
    game.flashlight_pose = 0.0
    game.in_hiding = true
    game.monster = game.player + Vector2(60,0)
    game.previous_monster = game.monster
    game.dread = 0.9
    await _shot("25_esconderijo", 6)
    game.in_hiding = false
    game.dread = 0.0
    game.subliminal = 5.0
    await _shot("26_relampago", 3)
    game.subliminal = 0.0
    # Paredes Espectrais: parede comum com fumaca roxa na luz normal e bloco
    # lilas translucido na espectral; Costura do vestibulo com o fio ate o quarto.
    game.ghost_unlocked = true
    game.light_on = true
    game.flashlight_pose = 1.0
    game.energy = 100.0
    game.light_jam = 0.0
    game.ghost_mode = false
    game.player = game.tile(22, 21)
    game.previous_player = game.player
    game.draw_player = game.player
    game.aim_override = Vector2(-1,0)
    game.look = Vector2(-1,0)
    game.camera = game._camera_target()
    await _closeup("27_parede_espectral_normal", game.tile(18, 21), 10)
    game.ghost_mode = true
    await _closeup("28_parede_espectral_lilas", game.tile(18, 21), 6)
    game.player = game.tile(23, 30)
    game.previous_player = game.player
    game.draw_player = game.player
    game.aim_override = Vector2(-1,-0.2)
    game.look = game.aim_override.normalized()
    game.camera = game._camera_target()
    await _shot("29_costura_espectral", 10)
    game.ghost_mode = false
    game.light_on = false
    game.flashlight_pose = 0.0
    game.house_light = 1.0
    game.player = game.tile(26, 31)
    game.previous_player = game.player
    game.monster = game.tile(28, 31)
    game.previous_monster = game.monster
    game.ritual_running = true
    game.ritual_left = 4.0
    game.fragment_owned = [true,true,true]
    game.house_light = 0.0
    await _shot("17_ritual", 5)
    game.ritual_running = false
    # Depois do ritual a casa clareia um tom.
    game.monster_banished = true
    game.dawn = 1.0
    await _shot("30_casa_clareada", 6)
    game.monster_banished = false
    game.dawn = 0.0
    # Menu de pausa: volume selecionado e a confirmacao de reiniciar.
    game.status = "paused"
    game.pause_index = game.PAUSE_VOLUME
    await _shot("31_menu_pausa", 4)
    game.pause_index = 1
    game.pause_confirm = 1
    await _shot("32_pausa_confirmar", 3)
    game.pause_confirm = -1
    game.status = "playing"
    game.set_physics_process(true)
    game._die()
    game.death_time = 0.45
    await _shot("12_jumpscare", 2)
    game.death_time = 5.0
    await _shot("18_morte", 3)
    quit(0)
