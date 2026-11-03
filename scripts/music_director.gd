extends Node
## Trilhas originais em camadas. A intensidade depende dos fragmentos;
## a canção da Ygona depende da distância, com transições contínuas.

var ambient_players: Array = []
var stalker: AudioStreamPlayer
var effects: AudioStreamPlayer
var current_stage: int = 0
var enabled: bool = true

func _ready() -> void:
    for i in range(4):
        var ap = AudioStreamPlayer.new()
        ap.name = "Ambiente_%s" % i
        ap.stream = _load_loop("res://assets/audio/ambient_%s.wav" % i)
        ap.volume_db = -65.0
        add_child(ap)
        ambient_players.append(ap)
    stalker = AudioStreamPlayer.new()
    stalker.name = "Tema_da_Ygona"
    stalker.stream = _load_loop("res://assets/audio/ygona_theme.wav")
    stalker.volume_db = -65.0
    add_child(stalker)
    effects = AudioStreamPlayer.new()
    effects.name = "Efeitos"
    add_child(effects)

func _load_loop(path: String) -> AudioStream:
    var stream = load(path)
    if stream is AudioStreamWAV:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    return stream

func start() -> void:
    current_stage = 0
    enabled = true
    for ap in ambient_players:
        ap.volume_db = -65.0
        ap.play()
    stalker.volume_db = -65.0
    stalker.play()

func stop() -> void:
    for ap in ambient_players:
        ap.stop()
    stalker.stop()
    effects.stop()

func update_audio(dt: float, stage: int, distance: float, active: bool) -> void:
    current_stage = clampi(stage, 0, 3)
    for i in range(ambient_players.size()):
        var target: float = (-17.0 if i == current_stage else -65.0) if active else -42.0
        ambient_players[i].volume_db = move_toward(ambient_players[i].volume_db, target, dt * 14.0)
    # A música do monstro começa sutil e cresce quando a distância diminui.
    var closeness = clampf(1.0 - distance / 610.0, 0.0, 1.0) if active else 0.0
    var monster_target: float = -65.0 if closeness < 0.07 else lerpf(-38.0, -4.0, pow(closeness, 1.1))
    stalker.volume_db = move_toward(stalker.volume_db, monster_target, dt * 20.0)
    stalker.pitch_scale = lerpf(stalker.pitch_scale, 0.76 + closeness * 0.66, minf(1.0, dt * 3.0))

func sfx(which: String) -> void:
    var path = "res://assets/audio/%s.wav" % which
    if ResourceLoader.exists(path):
        effects.stream = load(path)
        effects.volume_db = -7.0
        effects.play()
