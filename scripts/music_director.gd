extends Node
## Trilhas originais em camadas. A intensidade depende dos fragmentos;
## a canção da Ygona depende da distância, com transições contínuas.

var ambient_players: Array = []
var stalker: AudioStreamPlayer
var effects: Array = []          # pequeno pool: risada e pickup nao se cortam
var next_effect: int = 0
var loaded: Dictionary = {}
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
    for i in range(4):
        var fx = AudioStreamPlayer.new()
        fx.name = "Efeitos_%s" % i
        add_child(fx)
        effects.append(fx)

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
    for fx in effects:
        fx.stop()

func update_audio(dt: float, stage: int, distance: float, active: bool) -> void:
    current_stage = clampi(stage, 0, 3)
    for i in range(ambient_players.size()):
        # A cada fragmento a camada troca, fica mais alta e mais acelerada.
        var target: float = ((-17.0 + 2.0 * current_stage) if i == current_stage else -65.0) if active else (-30.0 if i == 0 else -65.0)
        ambient_players[i].volume_db = move_toward(ambient_players[i].volume_db, target, dt * 14.0)
        ambient_players[i].pitch_scale = lerpf(ambient_players[i].pitch_scale, 1.0 + 0.07 * current_stage, minf(1.0, dt * 2.0))
    # A música do monstro começa sutil e cresce quando a distância diminui.
    var closeness = clampf(1.0 - distance / 610.0, 0.0, 1.0) if active else 0.0
    var monster_target: float = -65.0 if closeness < 0.07 else lerpf(-38.0, -4.0, pow(closeness, 1.1))
    stalker.volume_db = move_toward(stalker.volume_db, monster_target, dt * 20.0)
    stalker.pitch_scale = lerpf(stalker.pitch_scale, 0.76 + closeness * 0.66, minf(1.0, dt * 3.0))

func sfx(which: String, volume_db: float = -7.0, pitch: float = 1.0) -> void:
    if not loaded.has(which):
        var path = "res://assets/audio/%s.wav" % which
        loaded[which] = load(path) if ResourceLoader.exists(path) else null
    if loaded[which] == null:
        return
    var fx: AudioStreamPlayer = effects[next_effect]
    next_effect = (next_effect + 1) % effects.size()
    fx.stream = loaded[which]
    fx.volume_db = volume_db
    fx.pitch_scale = pitch
    fx.play()
