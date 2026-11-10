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
    Input.warp_mouse(Vector2(700, 150))
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
    game._die()
    game.death_time = 0.45
    await _shot("12_jumpscare", 2)
    quit(0)
