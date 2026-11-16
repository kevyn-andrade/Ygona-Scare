extends SceneTree
## Diagnostico de audio: mostra se cada canal esta tocando e o pico real do barramento.
##   godot --path . --script res://tests/audio_probe.gd

func _initialize() -> void:
    call_deferred("_run")

func _report(game: Node, label: String) -> void:
    var m = game.music
    print("--- ", label, " | status=", game.status)
    print("  driver=", AudioServer.get_driver_name(), " master_mute=", AudioServer.is_bus_mute(0), " master_db=", AudioServer.get_bus_volume_db(0))
    print("  tema: playing=", m.theme.playing, " stream=", m.theme.stream, " vol_db=", snappedf(m.theme.volume_db, 0.1), " pos=", snappedf(m.theme.get_playback_position(), 0.01), " pitch=", snappedf(m.theme.pitch_scale, 0.01))
    for ap in m.ambient_players:
        print("  ", ap.name, ": playing=", ap.playing, " vol_db=", snappedf(ap.volume_db, 0.1))
    print("  pico do master (dB): L=", snappedf(AudioServer.get_bus_peak_volume_left_db(0, 0), 0.1), " R=", snappedf(AudioServer.get_bus_peak_volume_right_db(0, 0), 0.1))

func _run() -> void:
    var game: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    for i in range(30):
        await process_frame
    _report(game, "menu, 0.5 s")
    await create_timer(4.0).timeout
    _report(game, "menu, 4.5 s")
    game._restart_entirely()
    game._begin_play()
    await create_timer(4.0).timeout
    _report(game, "jogando (casa iluminada), 4 s")
    # Distorcao: simula a entidade chegando perto, um susto e a fita parando.
    game.set_process(false)
    game.set_physics_process(false)
    for step in [[0.0, 0.0, 0.0, "longe"], [0.6, 0.0, 0.0, "perto"], [1.0, 0.0, 0.0, "colada"], [1.0, 0.0, 1.0, "colada + susto"], [0.0, 1.0, 0.0, "fita parando"]]:
        for i in range(120):
            game.music.update_theme(1.0/60.0, 2, step[0], step[1], false, step[2])
            await process_frame
        var m = game.music
        print("--- ", step[3], ": frente=", snappedf(m.theme.volume_db, 0.1), " dB  invertida=", snappedf(m.theme_reverse.volume_db, 0.1), " dB  altura=", snappedf(m.theme.pitch_scale, 0.01),
            "  drive=", snappedf(m.fx_crush.drive, 0.01), " filtro=", int(m.fx_filter.cutoff_hz), " Hz  reverb=", snappedf(m.fx_reverb.wet, 0.01),
            "  pico=", snappedf(AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Caixinha"), 0), 0.1), " dB")
    game.set_process(true)
    game.set_physics_process(true)
    for i in range(90):
        await process_frame
    # O laco precisa emendar: pula para perto do fim e confere se continua tocando.
    game.music.theme.seek(game.music.theme.stream.get_length() - 0.5)
    await create_timer(1.5).timeout
    _report(game, "depois de passar pelo fim da faixa")
    quit(0)
