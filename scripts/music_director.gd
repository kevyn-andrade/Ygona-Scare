extends Node
## Trilhas originais em camadas. A intensidade depende dos fragmentos;
## a canção de Afrodite depende da distância, com transições contínuas.

var ambient_players: Array = []
var stalker: AudioStreamPlayer
var heart: AudioStreamPlayer
var theme: AudioStreamPlayer     # caixinha de musica de fundo (tema original)
var theme_reverse: AudioStreamPlayer   # a mesma melodia, de tras para frente
var theme_clock: float = 0.0
var pitch_dip: float = 0.0
var stutter_left: float = 0.0
var stutter_tick: float = 0.0
var stutter_anchor: float = 0.0
var stutter_cooldown: float = 0.0
const THEME_BUS: String = "Caixinha"
var fx_crush: AudioEffectDistortion
var fx_phaser: AudioEffectPhaser
var fx_filter: AudioEffectLowPassFilter
var fx_delay: AudioEffectDelay
var fx_reverb: AudioEffectReverb
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
    stalker.name = "Tema_de_Afrodite"
    stalker.stream = _load_loop("res://assets/audio/afrodite_theme.wav")
    stalker.volume_db = -65.0
    add_child(stalker)
    theme = AudioStreamPlayer.new()
    theme.name = "Caixinha_de_Musica"
    theme.stream = _load_loop("res://assets/audio/lullaby.wav") if ResourceLoader.exists("res://assets/audio/lullaby.wav") else null
    theme.volume_db = -60.0
    _setup_theme_bus()
    theme.bus = THEME_BUS
    add_child(theme)
    theme_reverse = AudioStreamPlayer.new()
    theme_reverse.name = "Caixinha_Invertida"
    theme_reverse.stream = _load_loop("res://assets/audio/lullaby_reverse.wav") if ResourceLoader.exists("res://assets/audio/lullaby_reverse.wav") else null
    theme_reverse.volume_db = -60.0
    theme_reverse.bus = THEME_BUS
    add_child(theme_reverse)
    # Coracao em canal proprio: bate muitas vezes e nao pode cortar a risada.
    heart = AudioStreamPlayer.new()
    heart.name = "Coracao"
    heart.stream = load("res://assets/audio/heartbeat.wav") if ResourceLoader.exists("res://assets/audio/heartbeat.wav") else null
    add_child(heart)
    for i in range(4):
        var fx = AudioStreamPlayer.new()
        fx.name = "Efeitos_%s" % i
        add_child(fx)
        effects.append(fx)

func _load_loop(path: String) -> AudioStream:
    var stream = load(path)
    if stream is AudioStreamWAV:
        # Ligar o laco por codigo exige dizer onde ele termina: com loop_end = 0
        # (o padrao) o trecho em laco fica vazio e o som para no mesmo instante.
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
    return stream

func start() -> void:
    current_stage = 0
    enabled = true
    for ap in ambient_players:
        ap.volume_db = -65.0
        ap.play()
    stalker.volume_db = -65.0
    stalker.play()
    if theme.stream != null and not theme.playing:
        theme.play()
    if theme_reverse.stream != null and not theme_reverse.playing:
        theme_reverse.play()

func stop() -> void:
    for ap in ambient_players:
        ap.stop()
    stalker.stop()
    theme.stop()
    theme_reverse.stop()
    heart.stop()
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

func _setup_theme_bus() -> void:
    ## Barramento proprio da caixinha, com a cadeia de efeitos que a apodrece.
    if AudioServer.get_bus_index(THEME_BUS) == -1:
        var idx: int = AudioServer.bus_count
        AudioServer.add_bus(idx)
        AudioServer.set_bus_name(idx, THEME_BUS)
        AudioServer.set_bus_send(idx, "Master")
        fx_crush = AudioEffectDistortion.new()
        fx_crush.mode = AudioEffectDistortion.MODE_LOFI
        fx_crush.drive = 0.0
        fx_phaser = AudioEffectPhaser.new()
        fx_phaser.depth = 0.1
        fx_filter = AudioEffectLowPassFilter.new()
        fx_filter.cutoff_hz = 18000.0
        fx_delay = AudioEffectDelay.new()
        fx_delay.tap1_delay_ms = 310.0
        fx_delay.tap2_active = false
        fx_delay.feedback_active = true
        fx_delay.feedback_delay_ms = 430.0
        fx_delay.feedback_lowpass = 2600.0
        fx_reverb = AudioEffectReverb.new()
        fx_reverb.room_size = 0.85
        fx_reverb.damping = 0.35
        fx_reverb.wet = 0.1
        # Limitador no fim: pode ficar feio, mas nunca estoura a saida.
        var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
        limiter.ceiling_db = -5.0
        limiter.pre_gain_db = 0.0
        for fx in [fx_crush, fx_phaser, fx_filter, fx_delay, fx_reverb, limiter]:
            AudioServer.add_bus_effect(idx, fx)
    else:
        var bus: int = AudioServer.get_bus_index(THEME_BUS)
        fx_crush = AudioServer.get_bus_effect(bus, 0)
        fx_phaser = AudioServer.get_bus_effect(bus, 1)
        fx_filter = AudioServer.get_bus_effect(bus, 2)
        fx_delay = AudioServer.get_bus_effect(bus, 3)
        fx_reverb = AudioServer.get_bus_effect(bus, 4)

func update_theme(dt: float, stage: int, closeness: float, duck: float, loud: bool, glitch: float = 0.0) -> void:
    ## A caixinha toca o tempo todo e apodrece junto com a casa:
    ##  - a cada silicone fica mais lenta, grave, suja e com mais eco;
    ##  - com a entidade perto, a fita mastiga, a melodia passa a tocar DE TRAS
    ##    PARA FRENTE, o som racha (bitcrush), enjoa (phaser) e afunda (filtro);
    ##  - nos sustos ("glitch") o disco engasga, repetindo o mesmo pedaco;
    ##  - "duck" (0..1) faz a fita parar: a altura despenca e vem o silencio,
    ##    que avisa que algo esta parado no escuro.
    if theme == null or theme.stream == null:
        return
    theme_clock += dt
    var c: float = clampf(closeness, 0.0, 1.0)
    var g: float = clampf(glitch, 0.0, 1.0)
    var rot: float = float(clampi(stage, 0, 3))/3.0
    var stopping: bool = duck > 0.5
    # ---- volume, e a troca gradual pela versao invertida
    var target: float = (-5.0 if loud else -10.0) + 1.0*float(stage)
    target = lerpf(target, -60.0, clampf(duck, 0.0, 1.0))
    var backwards: float = maxf(smoothstep(0.38, 0.85, c), smoothstep(0.45, 0.8, g))
    theme.volume_db = move_toward(theme.volume_db, target - 11.0*backwards, dt * (42.0 if stopping else 16.0))
    if theme_reverse != null and theme_reverse.stream != null:
        # Curva em dB: ja se ouve a melodia ao contrario bem antes de ela chegar.
        var rev_target: float = (target + 1.0 - 26.0*pow(1.0-backwards, 2.0)) if backwards > 0.02 else -60.0
        theme_reverse.volume_db = move_toward(theme_reverse.volume_db, rev_target, dt * (42.0 if stopping else 30.0))
    # ---- altura: apodrecimento, fita mastigada, mergulhos e parada de fita
    pitch_dip = move_toward(pitch_dip, 0.0, dt*0.45)
    if not stopping and c > 0.3 and randf() < dt*1.1*c:
        pitch_dip = -randf_range(0.12, 0.34)*c          # a corda da caixinha escorrega
    var warble: float = sin(theme_clock*5.3)*0.012 + sin(theme_clock*0.9)*0.02 + sin(theme_clock*13.7)*0.006*c
    var pitch: float = 1.0 - 0.05*float(clampi(stage, 0, 3)) + warble*(0.25 + 3.2*c) - 0.12*c*c + pitch_dip
    if stopping:
        pitch = 0.3
    var speed: float = 5.0 if stopping else (9.0 if pitch_dip < -0.05 else 4.0)
    theme.pitch_scale = lerpf(theme.pitch_scale, clampf(pitch, 0.3, 1.2), minf(1.0, dt*speed))
    if theme_reverse != null:
        # A invertida vai um tiquinho mais grave: as duas nunca afinam.
        theme_reverse.pitch_scale = clampf(theme.pitch_scale*0.972, 0.3, 1.2)
    # ---- disco engasgado nos sustos
    stutter_cooldown = maxf(0.0, stutter_cooldown - dt)
    if g > 0.55 and stutter_left <= 0.0 and stutter_cooldown <= 0.0 and theme.playing:
        stutter_left = 0.62
        stutter_tick = 0.0
        stutter_anchor = theme.get_playback_position()
        stutter_cooldown = 2.5
    if stutter_left > 0.0:
        stutter_left -= dt
        stutter_tick -= dt
        if stutter_tick <= 0.0:
            # Cada repeticao um pouco mais curta: o engasgo acelera.
            stutter_tick = 0.05 + 0.11*clampf(stutter_left/0.62, 0.0, 1.0)
            theme.seek(stutter_anchor)
    # ---- cadeia de efeitos
    if fx_crush == null:
        return
    var drive: float = clampf(0.10*rot + 0.62*c*c + 0.55*g, 0.0, 0.92)
    fx_crush.drive = lerpf(fx_crush.drive, drive, minf(1.0, dt*8.0))
    fx_crush.post_gain = -15.0*fx_crush.drive
    fx_phaser.depth = 0.1 + 0.3*rot + 1.6*c
    fx_phaser.rate_hz = 0.25 + 3.2*c + 5.0*g
    fx_phaser.feedback = 0.35 + 0.5*c
    fx_filter.cutoff_hz = lerpf(fx_filter.cutoff_hz, lerpf(18000.0, 1700.0, pow(c, 1.4)) * (0.35 if stopping else 1.0), minf(1.0, dt*5.0))
    fx_filter.resonance = 0.5 + 0.38*c
    fx_delay.tap1_level_db = lerpf(-30.0, -9.0, maxf(rot*0.6, c))
    fx_delay.feedback_level_db = lerpf(-26.0, -6.5, maxf(rot*0.5, c))
    fx_reverb.wet = clampf(0.10 + 0.14*rot + 0.42*c + (0.3 if stopping else 0.0), 0.0, 0.85)

func heartbeat(volume_db: float) -> void:
    if heart == null or heart.stream == null:
        return
    heart.volume_db = volume_db
    heart.play()

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
