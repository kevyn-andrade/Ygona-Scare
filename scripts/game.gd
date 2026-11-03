extends Node2D
## YGONA SCARE — Godot 4.7, vista 2.5D isometrica a 45 graus.
## Logica de colisao em grade + projecao artistica independente.
## Heroina feminina com animacao de tirar/guardar lanterna no decote.

const WIDTH: float = 1152.0
const HEIGHT: float = 720.0
const TILE: int = 32
const PLAYER_WALK: float = 154.0
const PLAYER_RUN: float = 240.0
const LIGHT_HALF_ANGLE: float = 0.53

var map: ManorMap
var camera: Vector2 = Vector2.ZERO
var iso_renderer: IsoRenderer
var flashlight_pose: float = 0.0
var player: Vector2
var previous_player: Vector2 = Vector2.ZERO
var previous_monster: Vector2 = Vector2.ZERO
var draw_player: Vector2 = Vector2.ZERO
var draw_monster: Vector2 = Vector2.ZERO
var show_fps: bool = false
var direction: Vector2 = Vector2.RIGHT
var look: Vector2 = Vector2.UP
var monster: Vector2
var monster_state: String = "RONDA"
var monster_goal: Vector2 = Vector2.ZERO
var monster_path: Array = []
var path_index: int = 0
var repath_timer: float = 0.0
var search_timer: float = 0.0
var noise_timer: float = 0.0
var alert_position: Vector2 = Vector2.ZERO
var patrol_index: int = 0
var patrols: Array = []
var monster_lit: bool = false
var monster_active: bool = true
var in_hiding: bool = false
var hiding_spot: Vector2 = Vector2.ZERO

var status: String = "menu"   # menu | playing | paused | dead | won
var time_passed: float = 0.0
var energy: float = 100.0
var endurance: float = 100.0
var light_on: bool = false
var ghost_mode: bool = false
var moving: bool = false
var running: bool = false
var hint: String = ""
var hint_timer: float = 0.0
var scare_flash: float = 0.0
var last_room: String = ""
var footstep_clock: float = 0.0
var shake: float = 0.0

var fragment_owned: Array = [false, false, false]
var library_open: bool = false
var library_sequence: Array = []
var library_clue: bool = false
var key_owned: bool = false
var musicbox_open: bool = false
var mirror_open: bool = false
var mirror_sequence: Array = []
var mirror_clue: bool = false
var distractions: int = 3
var batteries: Array = []
var hiding_places: Array = []
var portals: Array = []
var thrown_bottles: Array = []
var ritual_running: bool = false
var ritual_left: float = 15.0
var monster_banished: bool = false

var scene_objects: Array = []
var prompt_object: Dictionary = {}

@onready var music = $Audio

func _ready() -> void:
    map = ManorMap.new()
    iso_renderer = IsoRenderer.new(self)
    _create_objects()
    _initial_positions()
    music.start()
    queue_redraw()

func _initial_positions() -> void:
    player = tile(26, 32)
    monster = tile(26, 11)
    previous_player = player
    previous_monster = monster
    draw_player = player
    draw_monster = monster
    camera = _camera_target()
    look = Vector2.UP
    patrols = [tile(26, 13), tile(41, 10), tile(42, 27), tile(27, 23), tile(11, 25), tile(10, 9), tile(26, 13)]
    patrol_index = 0
    monster_goal = patrols[0]

func _camera_target() -> Vector2:
    # A camera e a mira operam no espaco projetado da vista 45 graus.
    var candidate: Vector2 = iso_renderer.project(draw_player)-Vector2(WIDTH*0.50, HEIGHT*0.51)
    var limit: Vector2 = iso_renderer.max_scroll()
    return Vector2(clampf(candidate.x,0.0,maxf(0.0,limit.x)),clampf(candidate.y,0.0,maxf(0.0,limit.y)))

func _create_objects() -> void:
    scene_objects = [
        {"id":"book1", "kind":"book", "label":"Livro marcado I", "at":tile(6, 6), "number":1},
        {"id":"book2", "kind":"book", "label":"Livro marcado II", "at":tile(10, 6), "number":2},
        {"id":"book3", "kind":"book", "label":"Livro marcado III", "at":tile(14, 6), "number":3},
        {"id":"lib_clue", "kind":"clue", "label":"Inscrição espectral", "at":tile(12, 11)},
        {"id":"fragment1", "kind":"fragment", "label":"Fragmento: Fotografia", "at":tile(10, 11), "idx":0},
        {"id":"brass_key", "kind":"key", "label":"Chave de latão", "at":tile(43, 8)},
        {"id":"musicbox", "kind":"box", "label":"Caixa de música", "at":tile(11, 26)},
        {"id":"fragment2", "kind":"fragment", "label":"Fragmento: Canção", "at":tile(13, 25), "idx":1},
        {"id":"seal1", "kind":"seal", "label":"Selo I", "at":tile(39, 23), "number":1},
        {"id":"seal2", "kind":"seal", "label":"Selo II", "at":tile(43, 23), "number":2},
        {"id":"seal3", "kind":"seal", "label":"Selo III", "at":tile(48, 23), "number":3},
        {"id":"mirror_clue", "kind":"clue", "label":"Escrita de outro mundo", "at":tile(44, 29)},
        {"id":"fragment3", "kind":"fragment", "label":"Fragmento: Reflexo", "at":tile(44, 27), "idx":2},
        {"id":"altar", "kind":"altar", "label":"Altar do ritual", "at":tile(26, 29)},
        {"id":"exit", "kind":"exit", "label":"Porta da frente", "at":tile(26, 34)}
    ]
    batteries = [
        {"at":tile(16, 8),"taken":false}, {"at":tile(24, 20),"taken":false},
        {"at":tile(39, 9),"taken":false}, {"at":tile(6, 28),"taken":false},
        {"at":tile(48, 28),"taken":false}, {"at":tile(28, 12),"taken":false},
        {"at":tile(16, 30),"taken":false}, {"at":tile(39, 30),"taken":false}
    ]
    hiding_places = [tile(5, 27), tile(14, 29), tile(48, 11), tile(38, 29)]
    portals = [
        {"a":tile(4, 12), "b":tile(4, 21)},
        {"a":tile(49, 12), "b":tile(49, 21)},
        {"a":tile(16, 29), "b":tile(21, 29)}
    ]

func tile(x: int, y: int) -> Vector2:
    return Vector2((float(x) + 0.5) * TILE, (float(y) + 0.5) * TILE)

func _restart_entirely() -> void:
    fragment_owned = [false,false,false]
    library_open = false
    library_sequence = []
    library_clue = false
    key_owned = false
    musicbox_open = false
    mirror_open = false
    mirror_sequence = []
    mirror_clue = false
    distractions = 3
    thrown_bottles = []
    ritual_running = false
    monster_banished = false
    ritual_left = 15.0
    for bat in batteries:
        bat["taken"] = false
    time_passed = 0.0
    _respawn()
    status = "playing"
    music.start()
    notify("Explore a mansão. ESPAÇO: tirar/guardar a lanterna do decote. A luz imobiliza a Ygona.", 6.0)

func _respawn() -> void:
    _initial_positions()
    energy = 100.0
    endurance = 100.0
    light_on = false
    flashlight_pose = 0.0
    ghost_mode = false
    in_hiding = false
    monster_active = true
    monster_lit = false
    monster_state = "RONDA"
    repath_timer = 0.0
    monster_path = []
    ritual_running = false
    ritual_left = 15.0
    scare_flash = 0.0
    status = "playing"
    notify("Você despertou no vestíbulo. Use ESPAÇO para tirar a lanterna do decote.", 5.0)

func notify(message: String, seconds: float = 3.2) -> void:
    hint = message
    hint_timer = seconds

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    var key = event.keycode
    if status == "menu":
        if key == KEY_ENTER or key == KEY_KP_ENTER:
            _restart_entirely()
        return
    if status == "dead":
        if key == KEY_R or key == KEY_ENTER:
            _respawn()
        elif key == KEY_ESCAPE:
            status = "menu"
        return
    if status == "won":
        if key == KEY_R or key == KEY_ENTER:
            _restart_entirely()
        elif key == KEY_ESCAPE:
            status = "menu"
        return
    if key == KEY_ESCAPE:
        status = "playing" if status == "paused" else "paused"
        return
    if status != "playing":
        return
    if key == KEY_F3:
        show_fps = not show_fps
    elif key == KEY_F:
        if not light_on:
            notify("Acenda a lanterna com ESPAÇO.")
        else:
            ghost_mode = not ghost_mode
            music.sfx("ghost")
            if ghost_mode:
                _make_noise(player, 330.0)
            notify("Modo espectral: procure costuras nas paredes." if ghost_mode else "Modo normal: observe a criatura para imobilizá-la.")
    elif key == KEY_SPACE:
        light_on = not light_on
        music.sfx("click")
        if light_on and energy < 2.0:
            light_on = false
            notify("Bateria vazia. Aguarde no escuro ou encontre uma pilha.")
        elif not light_on:
            ghost_mode = false
            notify("Lanterna apagada: energia se recupera lentamente.")
    elif key == KEY_E:
        _interact()
    elif key == KEY_Q:
        _throw_bottle()
    elif key == KEY_H:
        notify("WASD mover | MOUSE mirar | F espectral | ESPAÇO tirar/guardar lanterna | SHIFT correr | E interagir | Q distrair", 6.5)

func _physics_process(delta: float) -> void:
    if status != "playing":
        music.update_audio(delta, collected_count(), player.distance_to(monster), false)
        return
    previous_player = player
    previous_monster = monster
    time_passed += delta
    hint_timer = maxf(0.0, hint_timer - delta)
    scare_flash = maxf(0.0, scare_flash - delta)
    shake = maxf(0.0, shake - delta)
    _update_aim()
    # ~0.70 s para tirar/guardar: gesto com inicio, retirada e extensao.
    flashlight_pose = move_toward(flashlight_pose, 1.0 if light_on else 0.0, delta*1.45)
    _update_player(delta)
    _update_light(delta)
    _update_objects(delta)
    if not monster_banished:
        _update_monster(delta)
    _update_ritual(delta)
    _check_auto_batteries()
    prompt_object = _nearest_interaction()
    music.update_audio(delta, collected_count(), player.distance_to(monster), not monster_banished)

func _process(delta: float) -> void:
    # Simulacao fixa a 60 Hz; desenho em qualquer taxa de quadros do monitor.
    # Evita o movimento aos saltos quando o display e de 75/120/144 Hz.
    if status == "playing":
        var fraction: float = clampf(Engine.get_physics_interpolation_fraction(),0.0,1.0)
        draw_player = previous_player.lerp(player,fraction)
        draw_monster = previous_monster.lerp(monster,fraction)
    camera = camera.lerp(_camera_target(),minf(1.0,delta*8.2))
    queue_redraw()

func _update_aim() -> void:
    var aim_pos: Vector2 = iso_renderer.unproject(get_viewport().get_mouse_position() + camera)
    var to_mouse = aim_pos - player
    if to_mouse.length() > 7.0:
        look = to_mouse.normalized()

func _update_player(dt: float) -> void:
    if in_hiding:
        moving = false
        running = false
        endurance = minf(100.0, endurance + dt * 21.0)
        return
    var motion = Vector2.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        motion.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        motion.y += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        motion.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        motion.x += 1.0
    moving = motion.length_squared() > 0.0
    running = moving and Input.is_key_pressed(KEY_SHIFT) and endurance > 1.0
    if running:
        endurance = maxf(0.0, endurance - dt * 27.0)
    else:
        endurance = minf(100.0, endurance + dt * 17.5)
    if moving:
        # Mapeia W/S para cima/baixo visuais e A/D para esquerda/direita.
        # A logica no plano continua em coordenadas ortogonais.
        # Compensa a proporcao 2:1 dos losangos para W/A/S/D terem velocidades
        # visualmente comparaveis nas direcoes vertical e horizontal.
        motion = Vector2(motion.x + motion.y*2.0, -motion.x + motion.y*2.0)
        direction = motion.normalized()
        player = map.slide(player, direction * (PLAYER_RUN if running else PLAYER_WALK) * dt, 9.0)
        if running:
            _make_noise(player, 180.0)
        footstep_clock += dt
        if footstep_clock > (0.25 if running else 0.42):
            footstep_clock = 0.0
            # SFX discretos e ocasionais, não um som por frame.
            if randi() % 3 == 0:
                music.sfx("step")

func _update_light(dt: float) -> void:
    if light_on:
        var use = 8.2 if ghost_mode else 0.95
        if monster_lit:
            use += 0.65
        energy = maxf(0.0, energy - dt * use)
        if energy <= 0.0:
            light_on = false
            ghost_mode = false
            notify("A lanterna apagou! Esconda-se ou espere recarregar.")
            music.sfx("wrong")
    else:
        # Nao derruba instantaneamente a carga de 100% para 45% ao guardar.
        if energy < 45.0:
            energy = minf(45.0, energy + dt * 7.5)

func _update_objects(dt: float) -> void:
    for bottle in thrown_bottles:
        bottle["ttl"] = float(bottle["ttl"]) - dt
    thrown_bottles = thrown_bottles.filter(func(b): return float(b["ttl"]) > 0.0)

func _check_auto_batteries() -> void:
    for battery in batteries:
        if not battery["taken"] and player.distance_to(battery["at"]) < 23.0:
            battery["taken"] = true
            energy = minf(100.0, energy + 45.0)
            music.sfx("pickup")
            notify("Pilha encontrada: +45% de carga.")

func light_range() -> float:
    if not light_on or energy <= 0.0:
        return 0.0
    var base = 295.0 if ghost_mode else 334.0
    return base * lerpf(0.62, 1.0, clampf(energy / 38.0, 0.0, 1.0))

func is_illuminated(point: Vector2) -> bool:
    if not light_on or flashlight_pose < 0.86 or energy <= 0.0:
        return false
    var delta = point - player
    var dist = delta.length()
    if dist > light_range() or dist < 0.01:
        return false
    if absf(look.angle_to(delta)) > LIGHT_HALF_ANGLE:
        return false
    return not map.has_wall_between(player, point)

func _make_noise(at: Vector2, radius: float) -> void:
    if monster_banished or monster_state == "PERSEGUINDO":
        return
    if monster.distance_to(at) <= radius:
        alert_position = at
        noise_timer = 5.0
        monster_state = "INVESTIGANDO"

func _update_monster(dt: float) -> void:
    monster_lit = is_illuminated(monster) and not in_hiding and not ghost_mode
    if monster_lit:
        monster_state = "CONGELADO"
        return
    var dist = monster.distance_to(player)
    var seen = (not in_hiding) and dist < (250.0 + collected_count() * 48.0) and not map.has_wall_between(monster, player)
    var ghost_noise = ghost_mode and light_on and dist < 345.0 and not in_hiding
    if seen or ghost_noise:
        monster_state = "PERSEGUINDO"
        alert_position = player
        search_timer = 5.0 + float(collected_count())
    elif monster_state == "CONGELADO":
        # Volta a procurar o jogador que estava iluminando a criatura.
        monster_state = "BUSCANDO"
        alert_position = player
        search_timer = 3.0
    elif monster_state == "PERSEGUINDO":
        monster_state = "BUSCANDO"
    elif monster_state == "BUSCANDO":
        search_timer -= dt
        if search_timer <= 0.0:
            monster_state = "RONDA"
    elif monster_state == "INVESTIGANDO":
        noise_timer -= dt
        if noise_timer <= 0.0:
            monster_state = "RONDA"
    if monster_state == "RONDA":
        if monster.distance_to(patrols[patrol_index]) < 26.0:
            patrol_index = (patrol_index + 1) % patrols.size()
        monster_goal = patrols[patrol_index]
    elif monster_state in ["BUSCANDO", "INVESTIGANDO", "PERSEGUINDO"]:
        monster_goal = alert_position
    repath_timer -= dt
    if repath_timer <= 0.0:
        repath_timer = 0.37 if monster_state == "PERSEGUINDO" else 0.95
        monster_path = map.route(monster, monster_goal)
        path_index = 1 if monster_path.size() > 1 else 0
    if monster_path.size() > path_index:
        var cell: Vector2i = monster_path[path_index]
        var step_to = map.cell_center(cell.x, cell.y)
        if step_to.distance_to(monster) < 8.0:
            path_index += 1
        else:
            var speed = 85.0 + float(collected_count()) * 10.0
            if monster_state == "PERSEGUINDO":
                speed = 173.0 + float(collected_count()) * 19.0 + (28.0 if ritual_running else 0.0)
            elif monster_state == "BUSCANDO":
                speed = 127.0 + float(collected_count()) * 11.0
            monster = map.slide(monster, monster.direction_to(step_to) * speed * dt, 10.0)
    # Uma captura só ocorre com contato físico, nunca à distância.
    if not in_hiding and monster.distance_to(player) < 21.0:
        _die()

func _die() -> void:
    status = "dead"
    music.sfx("stinger")
    scare_flash = 1.2
    shake = 0.6
    notify("A entidade encontrou você.", 3.0)

func collected_count() -> int:
    var count = 0
    for value in fragment_owned:
        if value:
            count += 1
    return count

func _update_ritual(dt: float) -> void:
    if not ritual_running:
        return
    ritual_left = maxf(0.0, ritual_left - dt)
    if ritual_left <= 0.0:
        ritual_running = false
        monster_banished = true
        monster_active = false
        music.sfx("win")
        notify("A YGONA FOI BANIDA. A PORTA DA FRENTE ESTÁ ABERTA!", 8.0)
        scare_flash = 0.5

func _nearest_interaction() -> Dictionary:
    if in_hiding:
        return {"id":"leave_hide", "kind":"unhide", "label":"Sair do esconderijo", "at":hiding_spot}
    var options: Array = []
    for item in scene_objects:
        var kind: String = item["kind"]
        var id: String = item["id"]
        if kind == "fragment":
            var idx: int = item["idx"]
            if fragment_owned[idx] or (idx == 0 and not library_open) or (idx == 1 and not musicbox_open) or (idx == 2 and not mirror_open):
                continue
        elif kind == "book" and library_open:
            continue
        elif id == "brass_key" and key_owned:
            continue
        elif kind == "seal" and mirror_open:
            continue
        elif kind == "clue" and (not light_on or not ghost_mode):
            continue
        options.append(item)
    for spot in hiding_places:
        options.append({"id":"hide", "kind":"hide", "label":"Esconder-se", "at":spot})
    if light_on and ghost_mode:
        for portal in portals:
            options.append({"id":"portal", "kind":"portal", "label":"Atravessar Costura Espectral", "at":portal["a"], "to":portal["b"]})
            options.append({"id":"portal", "kind":"portal", "label":"Atravessar Costura Espectral", "at":portal["b"], "to":portal["a"]})
    var best: Dictionary = {}
    var best_distance: float = 52.0
    for item in options:
        var d = player.distance_to(item["at"])
        if d < best_distance:
            best_distance = d
            best = item
    return best

func _interact() -> void:
    var obj = _nearest_interaction()
    if obj.is_empty():
        notify("Nada para interagir por perto.", 1.6)
        return
    var kind: String = obj["kind"]
    var id: String = obj["id"]
    if kind == "unhide":
        in_hiding = false
        notify("Você saiu do esconderijo.", 1.5)
        return
    if kind == "hide":
        in_hiding = true
        hiding_spot = obj["at"]
        light_on = false
        ghost_mode = false
        notify("Fique quieto. Pressione E para sair.")
        return
    if kind == "portal":
        if energy < 9.0:
            notify("A costura exige pelo menos 9% de energia.")
            music.sfx("wrong")
            return
        player = obj["to"]
        previous_player = player
        draw_player = player
        energy -= 9.0
        ghost_mode = false
        _make_noise(player, 180.0)
        music.sfx("ghost")
        notify("Você atravessou a parede. A Ygona não usa essas passagens.")
        return
    if kind == "clue":
        if id == "lib_clue":
            library_clue = true
            notify("A parede sussurra: SEGUNDO, PRIMEIRO, TERCEIRO.", 6.0)
        elif id == "mirror_clue":
            mirror_clue = true
            notify("Símbolos no espelho: SELO II → SELO III → SELO I.", 6.0)
        music.sfx("ghost")
        return
    if kind == "book":
        var book_number: int = obj["number"]
        var answer: Array = [2, 1, 3]
        if book_number == answer[library_sequence.size()]:
            library_sequence.append(book_number)
            music.sfx("click")
            if library_sequence.size() == 3:
                library_open = true
                notify("A estante se abriu! Há um fragmento entre os livros.", 4.0)
                music.sfx("pickup")
                _make_noise(player, 460.0)
            else:
                notify("O livro fez um clique... %s/3" % library_sequence.size(), 2.3)
        else:
            library_sequence.clear()
            music.sfx("wrong")
            notify("Ordem incorreta. A parede guarda a sequência.")
        return
    if kind == "key":
        key_owned = true
        music.sfx("pickup")
        notify("Você pegou uma chave de latão. Ela deve abrir algo no quarto.", 5.0)
        return
    if kind == "box":
        if musicbox_open:
            notify("A caixa de música está vazia.")
        elif not key_owned:
            notify("Caixa de música trancada. Falta uma chave.")
            music.sfx("wrong")
        else:
            musicbox_open = true
            _make_noise(player, 750.0)
            music.sfx("stinger")
            notify("A caixa tocou sozinha. A Ygona ouviu! Pegue o fragmento.", 5.0)
            scare_flash = 0.3
        return
    if kind == "seal":
        var seal_number: int = obj["number"]
        var expected: Array = [2, 3, 1]
        if seal_number == expected[mirror_sequence.size()]:
            mirror_sequence.append(seal_number)
            music.sfx("click")
            if mirror_sequence.size() == 3:
                mirror_open = true
                music.sfx("pickup")
                _make_noise(player, 460.0)
                notify("O espelho se partiu. O último fragmento apareceu!", 5.0)
            else:
                notify("Um selo brilha: %s/3" % mirror_sequence.size())
        else:
            mirror_sequence.clear()
            music.sfx("wrong")
            notify("Os selos apagaram. Procure a ordem no mundo espectral.")
        return
    if kind == "fragment":
        var index: int = obj["idx"]
        fragment_owned[index] = true
        energy = minf(100.0, energy + 18.0)
        music.sfx("stinger")
        scare_flash = 0.45
        shake = 0.22
        _make_noise(player, 750.0)
        var total = collected_count()
        notify("FRAGMENTO %s/3. A Ygona despertou ainda mais!" % total, 5.5)
        return
    if kind == "altar":
        if monster_banished:
            notify("A maldição acabou. Vá até a porta da frente!")
        elif ritual_running:
            notify("Ritual em andamento! Sobreviva por %s segundos." % int(ceil(ritual_left)))
        elif collected_count() < 3:
            notify("O altar exige TRÊS fragmentos. Encontrados: %s/3." % collected_count(), 4.0)
        else:
            ritual_running = true
            ritual_left = 15.0
            monster_state = "PERSEGUINDO"
            alert_position = player
            search_timer = 25.0
            _make_noise(player, 1200.0)
            music.sfx("stinger")
            scare_flash = 0.65
            notify("RITUAL INICIADO! SOBREVIVA POR 15 SEGUNDOS!", 6.0)
        return
    if kind == "exit":
        if monster_banished:
            status = "won"
            music.sfx("win")
        elif collected_count() < 3:
            notify("A porta está selada. Reúna os três fragmentos.")
        else:
            notify("O selo da porta ainda existe. Volte ao ALTAR!")
        return

func _throw_bottle() -> void:
    if in_hiding:
        notify("Saia do esconderijo antes de jogar algo.")
        return
    if distractions <= 0:
        notify("Você não tem mais objetos para arremessar.", 2.0)
        return
    var at = map.ray_end(player, look.angle(), 200.0)
    distractions -= 1
    thrown_bottles.append({"at":at, "ttl":2.1})
    _make_noise(at, 850.0)
    music.sfx("stinger")
    notify("Objeto arremessado: a Ygona ouviu um barulho!", 2.2)

func _objective() -> String:
    if monster_banished:
        return "A MALDIÇÃO ACABOU — alcance a porta da frente!"
    if ritual_running:
        return "SOBREVIVA AO RITUAL: %s s" % int(ceil(ritual_left))
    if collected_count() == 3:
        return "Leve os 3 fragmentos ao ALTAR do vestíbulo."
    if collected_count() == 0:
        return "Procure 3 fragmentos. Inspecione a biblioteca com a luz espectral."
    if not fragment_owned[1]:
        return "Explore a cozinha e encontre a chave da caixa de música."
    if not fragment_owned[2]:
        return "Os selos da oficina escondem um reflexo."
    return "Explore cômodos e siga as inscrições fantasmagóricas."

# --------------------------- DESENHO --------------------------------------
func _draw() -> void:
    if iso_renderer == null or map == null:
        return
    iso_renderer.draw_world()
    _draw_hud()
    if status != "playing":
        _draw_overlay()
    if scare_flash > 0.0 and status == "playing":
        draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(.65,.1,.18,.08*scare_flash/.5))

func _world_txt(at: Vector2, message: String, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, at+Vector2(1,1),message,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0,0,color.a*0.6))
    draw_string(ThemeDB.fallback_font, at,message,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw_hud() -> void:
    if status == "menu":
        return
    # Sombras do HUD.
    draw_rect(Rect2(0,0,WIDTH,103),Color(0.025,0.035,0.06,0.77))
    draw_rect(Rect2(0,HEIGHT-78,WIDTH,78),Color(0.025,0.035,0.06,0.82))
    _world_txt(Vector2(25,29),"YGONA SCARE",21,Color("e2c8b7"))
    var loc = map.room_name(player)
    _world_txt(Vector2(25,51),loc,12,Color("9faab8"))
    _draw_bar(Vector2(25,68),190,12,energy/100.0,Color("9181ce"))
    _world_txt(Vector2(226,79),"ENERGIA %s%%" % int(energy),12,Color("bcb8d2"))
    _draw_bar(Vector2(356,68),142,12,endurance/100.0,Color("7cb2a4"))
    _world_txt(Vector2(502,79),"FÔLEGO",12,Color("a2bcb9"))
    _world_txt(Vector2(655,30),"FRAGMENTOS",14,Color("cdc7d6"))
    for i in range(3):
        var x = 797 + i*42
        var c = Color("f0cd8a") if fragment_owned[i] else Color("5b5968")
        draw_colored_polygon(PackedVector2Array([Vector2(x,16),Vector2(x+13,28),Vector2(x,40),Vector2(x-13,28)]),c)
    var lit_status: String = "ESPECTRAL" if ghost_mode else ("GUARDADA" if not light_on else "NORMAL")
    if flashlight_pose > 0.02 and flashlight_pose < 0.98:
        lit_status = "TIRANDO..." if light_on else "GUARDANDO..."
    _world_txt(Vector2(924,31),"LUZ: " + lit_status,14,Color("b8a3ed") if ghost_mode else Color("e4d5a8"))
    var danger = player.distance_to(monster)
    if not monster_banished and danger < 340.0:
        var d = 1.0-clampf(danger/340.0,0,1)
        draw_rect(Rect2(WIDTH-216,60,180,7),Color("241d2b"))
        draw_rect(Rect2(WIDTH-216,60,180*d,7),Color("d96a80"))
        _world_txt(Vector2(WIDTH-215,90),"A YGONA ESTÁ PRÓXIMA",11,Color("dba4ae"))
    _world_txt(Vector2(26,HEIGHT-49),_objective(),16,Color("e9e0ce"))
    var helper = "WASD MOVER  |  MOUSE MIRAR  |  SHIFT CORRER  |  F ESPECTRAL  |  ESPAÇO TIRAR/GUARDAR LANTERNA  |  E INTERAGIR"
    _world_txt(Vector2(26,HEIGHT-20),helper,11,Color("a6a8b8"))
    if hint_timer > 0.0:
        var message = hint
        var max_width = minf(WIDTH-80.0, float(message.length())*9.0+38.0)
        draw_rect(Rect2((WIDTH-max_width)*0.5,HEIGHT-137,max_width,37),Color(0.08,0.07,0.12,0.92))
        _world_txt(Vector2((WIDTH-max_width)*0.5+17,HEIGHT-113),message,16,Color("f0e2c9"))
    if status == "playing":
        if not prompt_object.is_empty():
            var prompt = "[E] " + str(prompt_object["label"])
            var panel_width = minf(520.0, float(prompt.length())*9.0+35.0)
            var at = Vector2((WIDTH-panel_width)/2,HEIGHT-198)
            draw_rect(Rect2(at,Vector2(panel_width,42)),Color(0.08,0.10,0.15,0.92))
            draw_rect(Rect2(at,Vector2(panel_width,42)),Color("6f6489"),false,1)
            _world_txt(at+Vector2(16,27),prompt,17,Color("efe1c6"))
    if ritual_running:
        var w = 300.0
        draw_rect(Rect2((WIDTH-w)/2,114,w,13),Color("31212f"))
        draw_rect(Rect2((WIDTH-w)/2,114,w*ritual_left/15.0,13),Color("d88aab"))
        _world_txt(Vector2((WIDTH-w)/2+19,150),"MANTENHA-SE VIVO ATÉ O FIM DO RITUAL",14,Color("eecbdf"))
    if monster_lit and not monster_banished:
        _world_txt(Vector2(24,125),"A YGONA NÃO SE MOVE ENQUANTO VOCÊ OLHA!",13,Color("c9dff5"))
    if show_fps:
        _world_txt(Vector2(962,126),"FPS: %d" % int(Engine.get_frames_per_second()),13,Color("c2efba"))
    # Mira discreta.
    if status == "playing":
        var cursor = get_viewport().get_mouse_position()
        var c = Color("b4a2e8") if ghost_mode else Color("d9d4c2")
        draw_arc(cursor,8.0,0,TAU,24,Color(c.r,c.g,c.b,0.5),1.0)
        draw_line(cursor+Vector2(-14,0),cursor+Vector2(-9,0),c,1)
        draw_line(cursor+Vector2(14,0),cursor+Vector2(9,0),c,1)

func _draw_bar(at: Vector2,w: float,h: float,fraction: float,color: Color) -> void:
    draw_rect(Rect2(at,Vector2(w,h)),Color("111824"))
    draw_rect(Rect2(at+Vector2(2,2),Vector2((w-4)*clampf(fraction,0,1),h-4)),color)
    draw_rect(Rect2(at,Vector2(w,h)),Color("6f7789"),false,1)

func _center_text(message: String, baseline_y: float, size: int,color: Color) -> void:
    var width = ThemeDB.fallback_font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
    _world_txt(Vector2((WIDTH-width)/2.0,baseline_y),message,size,color)

func _draw_overlay() -> void:
    draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.02,0.025,0.045,0.86))
    if status == "menu":
        draw_circle(Vector2(WIDTH/2,180),80,Color(0.41,0.13,0.29,0.13))
        draw_arc(Vector2(WIDTH/2,180),72,0,TAU,48,Color("866178"),2)
        _center_text("YGONA SCARE",195,56,Color("ead7c5"))
        _center_text("SE VOCÊ DESVIAR O OLHAR, ELA SE MOVE",241,18,Color("c1a5b1"))
        _center_text("Encontre três fragmentos, rompa a maldição e saia da mansão.",314,22,Color("d4cbd5"))
        _center_text("Tire a lanterna do decote e descubra passagens espectrais.",350,19,Color("aeb9d5"))
        _center_text("Cuidado: no modo espectral, a luz NÃO paralisa a Ygona.",380,19,Color("aeb9d5"))
        draw_rect(Rect2(WIDTH/2-199,437,398,58),Color("5d4056"))
        _center_text("PRESSIONE ENTER PARA JOGAR",477,23,Color("fff2e5"))
        _center_text("WASD MOVER  •  MOUSE MIRAR  •  ESPAÇO TIRAR/GUARDAR  •  F ESPECTRAL",553,16,Color("b1a9b9"))
        _center_text("E INTERAGIR  •  SHIFT CORRER  •  Q DISTRAIR  •  H AJUDA  •  F3 FPS",586,14,Color("8e93a5"))
        _center_text("VISTA ISOMÉTRICA 45°  •  GODOT 4.7  •  ÁUDIO ORIGINAL",676,13,Color("7e8292"))
    elif status == "paused":
        _center_text("PAUSADO",290,57,Color("ead7c5"))
        _center_text("ESC para continuar",342,24,Color("cfc6db"))
        _center_text("A criatura espera do outro lado da porta...",391,18,Color("9295a8"))
    elif status == "dead":
        var eyes = Vector2(WIDTH/2,208)
        draw_circle(eyes-Vector2(36,0),13,Color("ef6374"))
        draw_circle(eyes+Vector2(36,0),13,Color("ef6374"))
        _center_text("A YGONA ENCONTROU VOCÊ",327,45,Color("f4a9ac"))
        _center_text("Seus fragmentos coletados foram preservados.",393,20,Color("d8c5c9"))
        _center_text("Pressione R para reaparecer no vestíbulo",451,22,Color("fff0db"))
        _center_text("ESC para voltar ao menu",493,16,Color("9c98a8"))
    elif status == "won":
        draw_arc(Vector2(WIDTH/2,198),83,0,TAU,60,Color("e1c68a"),3)
        _center_text("MALDIÇÃO ROMPIDA",217,48,Color("f1dfb7"))
        _center_text("Você reuniu os fragmentos, baniu a Ygona e escapou.",302,23,Color("dbd1cf"))
        _center_text("Tempo de fuga: %02d:%02d" % [int(time_passed / 60.0), int(time_passed) % 60],367,23,Color("c5cbd9"))
        _center_text("Pressione R para jogar novamente",448,23,Color("fff0db"))
        _center_text("ESC para o menu",485,16,Color("979aab"))
