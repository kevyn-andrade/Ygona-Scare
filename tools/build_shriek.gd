extends SceneTree
## Sintetiza assets/audio/shriek.wav: o grito curto de dor de Afrodite quando
## o ritual se completa e ela e arrastada de volta ao mar. Feito em GDScript
## (nao precisa de Python), no mesmo espirito de tools/build_audio.py:
##   godot --headless --path . --script res://tools/build_shriek.gd
## Depois rode "godot --headless --path . --import" para gerar o .import.
## Para usar outro grito, substitua o .wav mantendo o nome.

const RATE: int = 22050
const OUT: String = "res://assets/audio/shriek.wav"

func _initialize() -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 13
    var samples: PackedFloat32Array = _echo(_shriek(rng), 0.19, 0.36, 3)
    _save(OUT, samples)
    quit()

func _shriek(rng: RandomNumberGenerator) -> PackedFloat32Array:
    ## Voz rasgada: sobe num guincho, treme de dor e despenca num gemido.
    ## Por baixo, um sub-harmonico desafinado e aspero da a voz "de demonio".
    var dur: float = 1.3
    var n: int = int(float(RATE)*dur)
    var out: PackedFloat32Array = PackedFloat32Array()
    out.resize(n)
    var phase: float = 0.0
    var sub: float = 0.0
    var jitter: float = 0.0
    var rasp: float = 0.0
    var harmonics: Array = [[1.0,1.0],[2.0,0.72],[3.0,0.58],[4.0,0.44],[5.0,0.32],[6.0,0.22],[8.0,0.12],[11.0,0.06]]
    for i in range(n):
        var t: float = float(i)/float(RATE)
        var rise: float = minf(1.0, t/0.11)
        var fall: float = clampf((t-0.32)/0.85, 0.0, 1.0)
        var f0: float = lerpf(420.0, 980.0, 1.0-pow(1.0-rise, 3.0))
        f0 = lerpf(f0, 240.0, fall*fall)
        # Tremor de dor: vibrato que acelera e perde o controle, mais um
        # tremido irregular (a voz quebrando).
        jitter += 0.02*(rng.randf_range(-1.0, 1.0)-jitter)
        f0 *= 1.0 + (0.02+0.06*fall)*sin(TAU*(7.0+10.0*t)*t) + 0.5*jitter
        phase += f0/float(RATE)
        sub += f0*0.5*0.982/float(RATE)
        var voice: float = 0.0
        for h in harmonics:
            voice += float(h[1])*sin(TAU*phase*float(h[0]))
        var growl: float = sin(TAU*sub)*0.55 + (2.0*fposmod(sub*1.5, 1.0)-1.0)*0.25
        rasp += 0.35*(rng.randf_range(-1.0, 1.0)-rasp)
        var env: float = minf(1.0, t/0.012)*(1.0-smoothstep(0.85, dur, t))*(0.85+0.15*sin(TAU*3.2*t))
        var s: float = voice*0.26 + growl*(0.22+0.38*fall) + rasp*(0.16+0.30*fall)
        out[i] = tanh(s*env*1.9)
    return out

func _echo(src: PackedFloat32Array, delay: float, gain: float, repeats: int) -> PackedFloat32Array:
    ## Eco de corredor: a casa inteira devolve o grito.
    var step: int = int(float(RATE)*delay)
    var out: PackedFloat32Array = src.duplicate()
    out.resize(src.size()+step*repeats)
    for r in range(1, repeats+1):
        var g: float = pow(gain, float(r))
        for i in range(src.size()):
            out[i+step*r] += src[i]*g
    return out

func _save(path: String, samples: PackedFloat32Array) -> void:
    var peak: float = 0.000001
    for s in samples:
        peak = maxf(peak, absf(s))
    var bytes: PackedByteArray = PackedByteArray()
    bytes.resize(samples.size()*2)
    for i in range(samples.size()):
        bytes.encode_s16(i*2, int(clampf(samples[i]/peak*0.92, -1.0, 1.0)*32767.0))
    var wav: AudioStreamWAV = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = RATE
    wav.stereo = false
    wav.data = bytes
    var err: Error = wav.save_to_wav(ProjectSettings.globalize_path(path))
    print("%s: %.2fs (%s)" % [path, float(samples.size())/float(RATE), error_string(err)])
