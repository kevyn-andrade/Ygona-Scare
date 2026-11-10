extends Node2D
## YGONA SCARE — Godot 4.7, vista 2.5D isometrica a 45 graus.
## Logica de colisao em grade + projecao artistica independente.
## Heroina feminina com animacao de tirar/guardar lanterna no decote.

const WIDTH: float = 1152.0
const HEIGHT: float = 720.0
const TILE: int = 32
const PLAYER_WALK: float = 154.0
const PLAYER_RUN: float = 240.0
const CFG = preload("res://scripts/game_config.gd")
const DrawLayer = preload("res://scripts/draw_layer.gd")

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

var status: String = "menu"   # menu | intro | playing | reading | paused | dead | won
var real_time: float = 0.0    # relogio visual: corre mesmo com a simulacao parada
var intro_time: float = 0.0
var death_time: float = 0.0
var reading: Dictionary = {}  # carta/bilhete aberto na tela

# Abertura: casa ainda iluminada, quarto trancado, queda de energia.
var power_on: bool = true
var house_light: float = 1.0
var blackout_clock: float = 0.0
var monster_dormant: float = 0.0
var letter_read: bool = false
var note_read: bool = false
var foyer_key_owned: bool = false
var foyer_door_open: bool = false
var ghost_unlocked: bool = false
var vultos: Array = []
var vulto_timer: float = 2.5

# Entidade: risada e habilidades liberadas pelos fragmentos.
var laugh_cooldown: float = 0.0
var light_jam: float = 0.0
var jam_delay: float = -1.0
var jam_cooldown: float = 12.0
var teleport_cooldown: float = 8.0
var pulse_phase: float = 0.0

var world_layer: Node2D
var mask_layer: Node2D
var mask_viewport: SubViewport
var darkness_rect: ColorRect
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
	_setup_layers()
	_create_objects()
	_reset_opening()
	_initial_positions()
	music.start()
	queue_redraw()

func _setup_layers() -> void:
	# Ordem de desenho: Mundo -> Escuridao -> (este no) brilhos, HUD e telas.
	world_layer = DrawLayer.new()
	world_layer.name = "Mundo"
	world_layer.show_behind_parent = true
	world_layer.painter = func(layer: CanvasItem) -> void:
		iso_renderer.cv = layer
		iso_renderer.draw_world()
	add_child(world_layer)
	iso_renderer.cv = world_layer
	# Mascara de luz em meia resolucao (a filtragem linear ja suaviza as bordas).
	mask_viewport = SubViewport.new()
	mask_viewport.name = "MascaraDeLuz"
	mask_viewport.size = Vector2i(int(WIDTH*0.5), int(HEIGHT*0.5))
	mask_viewport.disable_3d = true
	mask_viewport.transparent_bg = false
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(mask_viewport)
	mask_layer = DrawLayer.new()
	mask_layer.painter = func(layer: CanvasItem) -> void:
		iso_renderer.draw_light_mask(layer)
	mask_layer.scale = Vector2(0.5,0.5)
	mask_viewport.add_child(mask_layer)
	darkness_rect = ColorRect.new()
	darkness_rect.name = "Escuridao"
	darkness_rect.show_behind_parent = true
	darkness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkness_rect.size = Vector2(WIDTH, HEIGHT)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/darkness.gdshader")
	mat.set_shader_parameter("mask", mask_viewport.get_texture())
	mat.set_shader_parameter("lift", IsoRenderer.WALL_HEIGHT/HEIGHT)
	darkness_rect.material = mat
	add_child(darkness_rect)

func _reset_opening() -> void:
	power_on = true
	house_light = 1.0
	blackout_clock = 0.0
	monster_dormant = 0.0
	letter_read = false
	note_read = false
	foyer_key_owned = false
	foyer_door_open = false
	ghost_unlocked = false
	vultos = []
	vulto_timer = 2.5
	map.set_blocked(ManorMap.FOYER_DOOR, true)

func _reset_entity_tricks() -> void:
	laugh_cooldown = 0.0
	light_jam = 0.0
	jam_delay = -1.0
	jam_cooldown = CFG.JAM_COOLDOWN_MIN
	teleport_cooldown = CFG.TELEPORT_COOLDOWN*0.5

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
		{"id":"exit", "kind":"exit", "label":"Porta da frente", "at":tile(26, 34)},
		# Abertura (GDD 2.3 / 3.7): carta da maldicao, bilhete, vaso com a chave, porta.
		{"id":"letter", "kind":"letter", "label":"Ler a carta", "at":tile(22, 32)+Vector2(7,7)},
		{"id":"note", "kind":"note", "label":"Ler o bilhete", "at":tile(28, 28)},
		{"id":"vase", "kind":"vase", "label":"Examinar o vaso de flores", "at":tile(32, 33)+Vector2(7,7)},
		{"id":"foyer_door", "kind":"door", "label":"Porta do salão", "at":tile(ManorMap.FOYER_DOOR.x, ManorMap.FOYER_DOOR.y)},
		# Luz especial entra depois do basico (GDD 4.1): lente no caminho do salao.
		{"id":"lens", "kind":"lens", "label":"Pegar a lente estranha", "at":tile(26, 22)}
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
	ritual_left = CFG.RITUAL_SECONDS
	for bat in batteries:
		bat["taken"] = false
	time_passed = 0.0
	pulse_phase = 0.0
	_reset_opening()
	_respawn()
	music.start()
	if CFG.INTRO_ENABLED:
		status = "intro"
		intro_time = 0.0
	else:
		_begin_play()

func _begin_play() -> void:
	status = "playing"
	music.sfx("wrong", -9.0, 0.6)   # a porta batendo atras dela
	notify("A porta se trancou. Olhe ao redor — E interage.", 5.0)

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
	ritual_left = CFG.RITUAL_SECONDS
	scare_flash = 0.0
	_reset_entity_tricks()
	if not power_on:
		monster_dormant = 3.0
	status = "playing"
	if not power_on:
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
	if status == "intro":
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_E]:
			_begin_play()
		return
	if status == "reading":
		if key in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			_close_reading()
		return
	if status == "dead":
		if death_time < CFG.JUMPSCARE_SECONDS:
			return
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
		if not ghost_unlocked:
			notify("A lanterna só tem a luz comum. Por enquanto.", 2.5)
		elif not light_on:
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
		previous_player = player
		previous_monster = monster
		music.update_audio(delta, collected_count(), player.distance_to(monster), status == "reading" and monster_present())
		return
	previous_player = player
	previous_monster = monster
	time_passed += delta
	hint_timer = maxf(0.0, hint_timer - delta)
	laugh_cooldown = maxf(0.0, laugh_cooldown - delta)
	light_jam = maxf(0.0, light_jam - delta)
	scare_flash = maxf(0.0, scare_flash - delta)
	shake = maxf(0.0, shake - delta)
	_update_aim()
	# ~0.70 s para tirar/guardar: gesto com inicio, retirada e extensao.
	flashlight_pose = move_toward(flashlight_pose, 1.0 if light_on else 0.0, delta*1.45)
	_update_player(delta)
	_update_light(delta)
	_update_objects(delta)
	_update_opening(delta)
	if monster_present():
		_update_monster(delta)
		if status == "playing":
			_update_abilities(delta)
	_update_ritual(delta)
	_check_auto_batteries()
	prompt_object = _nearest_interaction()
	music.update_audio(delta, collected_count(), player.distance_to(monster), monster_present())

func monster_present() -> bool:
	# A entidade so entra em cena depois que a luz da casa acaba.
	return not monster_banished and not power_on and monster_dormant <= 0.0

func danger_closeness() -> float:
	if not monster_present():
		return 0.0
	return clampf(1.0 - player.distance_to(monster)/CFG.PULSE_DANGER_RANGE, 0.0, 1.0)

func fragment_pulse(idx: int) -> float:
	## 0..1: brilho atual do fragmento. Pulsa de tempos em tempos e fica mais
	## forte e mais frequente com a entidade por perto (risco x recompensa).
	if fragment_owned[idx]:
		return 0.0
	var phase: float = fposmod(pulse_phase + float(idx)*0.37, 1.0)
	var envelope: float = pow(maxf(0.0, 1.0 - phase*2.6), 1.6) * minf(1.0, phase*40.0)
	return envelope * lerpf(CFG.PULSE_MIN_STRENGTH, 1.0, danger_closeness())

func laugh(volume_db: float = -5.0) -> void:
	if laugh_cooldown > 0.0:
		return
	laugh_cooldown = CFG.LAUGH_COOLDOWN
	music.sfx("laugh", volume_db, randf_range(0.86, 1.0))

func _update_opening(dt: float) -> void:
	pulse_phase += dt / lerpf(CFG.PULSE_PERIOD, CFG.PULSE_PERIOD_NEAR, danger_closeness())
	if power_on:
		house_light = 1.0
		_update_vultos(dt)
		return
	vultos = []
	if blackout_clock < 1.7:
		# As lampadas piscam cada vez mais fracas antes de morrer de vez.
		blackout_clock += dt
		var on: bool = fposmod(blackout_clock*11.0, 1.0) < 0.72 - blackout_clock*0.42
		house_light = (1.0 - blackout_clock*0.35) if on else 0.12
	else:
		house_light = move_toward(house_light, 0.0, dt*3.0)
	if monster_dormant > 0.0:
		monster_dormant -= dt
		if monster_dormant <= 0.0 and not monster_banished:
			# Descoberta por som (GDD 2.2): a risada vem antes da entidade.
			laugh_cooldown = 0.0
			laugh(-9.0)
			notify("...você ouviu isso? Quando ouvir a risada, acenda a luz.", 5.5)

func _update_vultos(dt: float) -> void:
	for v in vultos:
		var to_v: Vector2 = v["at"] - player
		# Somem mais depressa quando encarados: nunca da para ver direito.
		var stare: bool = absf(look.angle_to(to_v)) < 0.55
		v["ttl"] = float(v["ttl"]) - dt*(3.2 if stare else 1.0)
	vultos = vultos.filter(func(v): return float(v["ttl"]) > 0.0)
	vulto_timer -= dt
	if vulto_timer > 0.0:
		return
	vulto_timer = randf_range(2.6, 5.0)
	for attempt in range(8):
		var at: Vector2 = tile(randi_range(19, 33), randi_range(28, 34))
		var to_at: Vector2 = at - player
		if to_at.length() > 130.0 and absf(look.angle_to(to_at)) > 0.75:
			vultos.append({"at":at, "ttl":1.5, "life":1.5})
			return

func _trigger_blackout() -> void:
	power_on = false
	blackout_clock = 0.0
	monster_dormant = CFG.WAKE_DELAY
	music.sfx("blackout", -3.0)
	shake = 0.35
	notify("A luz acabou. ESPAÇO: tirar a lanterna do decote.", 6.0)

func _update_abilities(dt: float) -> void:
	var n: int = collected_count()
	var dist: float = monster.distance_to(player)
	if n >= CFG.ABILITY_BLACKOUT_AT:
		if jam_delay >= 0.0:
			jam_delay -= dt
			if jam_delay < 0.0:
				light_jam = CFG.JAM_SECONDS + 0.35*float(n - CFG.ABILITY_BLACKOUT_AT)
				music.sfx("click", -4.0, 0.7)
				notify("A lanterna falhou!", 1.4)
		else:
			jam_cooldown -= dt
			if jam_cooldown <= 0.0 and light_on and not in_hiding and dist < CFG.JAM_RANGE:
				# A risada avisa: ha um instante para recuar antes do apagao.
				jam_cooldown = randf_range(CFG.JAM_COOLDOWN_MIN, CFG.JAM_COOLDOWN_MAX)
				jam_delay = CFG.JAM_WARNING
				laugh_cooldown = 0.0
				laugh(-3.0)
	if n >= CFG.ABILITY_TELEPORT_AT:
		teleport_cooldown -= dt
		if teleport_cooldown <= 0.0 and not monster_lit and monster_state in ["PERSEGUINDO", "BUSCANDO"] \
				and dist > CFG.TELEPORT_MIN_DIST and dist < CFG.TELEPORT_MAX_DIST:
			teleport_cooldown = CFG.TELEPORT_COOLDOWN if _monster_blink() else 2.0

func _monster_blink() -> bool:
	## Teletransporte curto: salta pelo proprio caminho ate um ponto fora da luz,
	## sem nunca surgir colada na jogadora.
	var path: Array = map.route(monster, player)
	for i in range(path.size()-1, 0, -1):
		var cell: Vector2i = path[i]
		var spot: Vector2 = map.cell_center(cell.x, cell.y)
		var d: float = spot.distance_to(player)
		if d < CFG.TELEPORT_KEEP or is_illuminated(spot):
			continue
		if d > monster.distance_to(player) - 96.0:
			return false
		monster = spot
		previous_monster = spot
		draw_monster = spot
		monster_path = []
		repath_timer = 0.0
		music.sfx("ghost", -8.0, 0.75)
		return true
	return false

func _process(delta: float) -> void:
	# Simulacao fixa a 60 Hz; desenho em qualquer taxa de quadros do monitor.
	# Evita o movimento aos saltos quando o display e de 75/120/144 Hz.
	real_time += delta
	if status == "intro":
		intro_time += delta
		var total: float = 0.0
		for seconds in CFG.INTRO_SCENES:
			total += float(seconds)
		if intro_time >= total:
			_begin_play()
	elif status == "dead":
		death_time += delta
	darkness_rect.material.set_shader_parameter("darkness", lerpf(CFG.DARKNESS, CFG.HOUSE_LIGHT_DARKNESS, clampf(house_light,0.0,1.0)))
	world_layer.queue_redraw()
	mask_layer.queue_redraw()
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
		var use = CFG.DRAIN_GHOST if ghost_mode else CFG.DRAIN_NORMAL
		if monster_lit:
			use += CFG.DRAIN_LIT_EXTRA
		energy = maxf(0.0, energy - dt * use)
		if energy <= 0.0:
			light_on = false
			ghost_mode = false
			notify("A lanterna apagou! Esconda-se ou espere recarregar.")
			music.sfx("wrong")
	else:
		# Nao derruba instantaneamente a carga de 100% para 45% ao guardar.
		if energy < CFG.RECHARGE_CAP:
			energy = minf(CFG.RECHARGE_CAP, energy + dt * CFG.RECHARGE_RATE)

func _update_objects(dt: float) -> void:
	for bottle in thrown_bottles:
		bottle["ttl"] = float(bottle["ttl"]) - dt
	thrown_bottles = thrown_bottles.filter(func(b): return float(b["ttl"]) > 0.0)

func _check_auto_batteries() -> void:
	for battery in batteries:
		if not battery["taken"] and player.distance_to(battery["at"]) < 23.0:
			battery["taken"] = true
			energy = minf(100.0, energy + CFG.BATTERY_CHARGE)
			music.sfx("pickup")
			notify("Pilha encontrada: +%d%% de carga." % int(CFG.BATTERY_CHARGE))

func light_range() -> float:
	if not light_on or energy <= 0.0:
		return 0.0
	var base = CFG.LIGHT_RANGE_GHOST if ghost_mode else CFG.LIGHT_RANGE
	return base * lerpf(CFG.CONE_MIN_RANGE, 1.0, battery_factor())

func battery_factor() -> float:
	# 1 com carga confortavel; cai ate 0 conforme a bateria acaba (GDD 3.4).
	return clampf(energy / CFG.CONE_FULL_ENERGY, 0.0, 1.0)

func light_half_angle() -> float:
	return CFG.LIGHT_HALF_ANGLE * lerpf(CFG.CONE_MIN_ANGLE, 1.0, battery_factor())

func light_active() -> bool:
	# Luz realmente saindo da lanterna (ja erguida, com carga e sem falha).
	return light_on and flashlight_pose >= 0.86 and energy > 0.0 and light_jam <= 0.0

func is_illuminated(point: Vector2) -> bool:
	if not light_active():
		return false
	var delta = point - player
	var dist = delta.length()
	if dist > light_range() or dist < 0.01:
		return false
	if absf(look.angle_to(delta)) > light_half_angle():
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
		if monster_state != "PERSEGUINDO":
			laugh(lerpf(-3.0, -14.0, clampf(dist/420.0, 0.0, 1.0)))
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
			var n = float(collected_count())
			var speed = CFG.PATROL_SPEED + n * CFG.PATROL_SPEED_PER_FRAGMENT
			if monster_state == "PERSEGUINDO":
				speed = CFG.CHASE_SPEED + n * CFG.CHASE_SPEED_PER_FRAGMENT + (28.0 if ritual_running else 0.0)
			elif monster_state == "BUSCANDO":
				speed = CFG.SEARCH_SPEED + n * CFG.SEARCH_SPEED_PER_FRAGMENT
			monster = map.slide(monster, monster.direction_to(step_to) * speed * dt, 10.0)
	# Uma captura só ocorre com contato físico, nunca à distância.
	if not in_hiding and monster.distance_to(player) < 21.0:
		_die()

func _die() -> void:
	status = "dead"
	death_time = 0.0
	# Jumpscare: imagem + audio da entidade (troque assets/audio/jumpscare.wav).
	music.sfx("jumpscare", 0.0)
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
	if status != "playing":
		return
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
		elif kind == "door" and foyer_door_open:
			continue
		elif kind == "lens" and ghost_unlocked:
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
	if kind == "letter":
		letter_read = true
		music.sfx("click", -10.0, 1.3)
		_open_reading("CARTA SOBRE A MESA", [
			"A quem entrar nesta casa:",
			"",
			"Ela não morreu aqui. Ela ficou.",
			"Enquanto houver luz sobre ela, não dará um passo.",
			"No escuro, ela anda — e ri antes de vir.",
			"",
			"QUANDO OUVIR A RISADA, ACENDA A LUZ.",
			"",
			"Três fragmentos do que ela foi estão espalhados pela mansão.",
			"Eles brilham de tempos em tempos. ACHE OS FRAGMENTOS",
			"e leve-os ao altar. É a única saída.",
			"",
			"P.S.: deixei um bilhete junto à porta do salão.",
			"Leia, talvez te ajude a achar a chave."])
		return
	if kind == "note":
		note_read = true
		music.sfx("click", -10.0, 1.3)
		_open_reading("BILHETE AMASSADO", [
			"Leia isto, talvez te ajude a achar a chave:",
			"",
			"ela dorme onde nada mais floresce.",
			"",
			"Olhe debaixo do vaso de flores."])
		return
	if kind == "vase":
		if foyer_key_owned:
			notify("Só terra seca e flores murchas.", 2.0)
		else:
			foyer_key_owned = true
			music.sfx("pickup")
			notify("Debaixo do vaso havia uma chave de ferro.", 4.0)
		return
	if kind == "door":
		if not foyer_key_owned:
			music.sfx("wrong")
			notify("Trancada. A chave deve estar neste cômodo." if not note_read else "Trancada. O bilhete falava de um vaso de flores.", 3.5)
		else:
			_open_foyer_door()
			music.sfx("click", -4.0, 0.8)
			_trigger_blackout()
		return
	if kind == "lens":
		ghost_unlocked = true
		music.sfx("ghost")
		scare_flash = 0.25
		notify("Uma lente de outro mundo encaixou na lanterna. F: luz espectral — revela o oculto, mas NÃO paralisa a Ygona.", 7.5)
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
			ritual_left = CFG.RITUAL_SECONDS
			monster_state = "PERSEGUINDO"
			alert_position = player
			search_timer = 25.0
			_make_noise(player, 1200.0)
			music.sfx("stinger")
			scare_flash = 0.65
			notify("RITUAL INICIADO! SOBREVIVA POR %d SEGUNDOS!" % int(CFG.RITUAL_SECONDS), 6.0)
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

func _open_foyer_door() -> void:
	foyer_door_open = true
	map.set_blocked(ManorMap.FOYER_DOOR, false)

func _open_reading(title: String, lines: Array) -> void:
	reading = {"title":title, "lines":lines}
	status = "reading"

func _close_reading() -> void:
	reading = {}
	status = "playing"

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
	if power_on:
		if not letter_read:
			return "Há uma carta sobre a mesa."
		if not foyer_key_owned:
			return "A porta do salão está trancada. Procure a chave."
		return "Destranque a porta do salão."
	if collected_count() == 0:
		if not ghost_unlocked:
			return "Ache os fragmentos. Eles brilham de tempos em tempos."
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
	# O mundo e a escuridao sao desenhados por camadas-filhas, atras deste no.
	if status == "intro":
		_draw_intro()
		return
	if status in ["playing", "reading", "paused"]:
		_draw_glows()
	_draw_hud()
	if status == "reading":
		_draw_reading()
	elif status == "dead" and death_time < CFG.JUMPSCARE_SECONDS:
		_draw_jumpscare()
	elif status != "playing":
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
	elif light_on and light_jam > 0.0:
		lit_status = "FALHANDO!"
	_world_txt(Vector2(924,31),"LUZ: " + lit_status,14,Color("b8a3ed") if ghost_mode else Color("e4d5a8"))
	var danger = player.distance_to(monster)
	if monster_present() and danger < 340.0:
		var d = 1.0-clampf(danger/340.0,0,1)
		draw_rect(Rect2(WIDTH-216,60,180,7),Color("241d2b"))
		draw_rect(Rect2(WIDTH-216,60,180*d,7),Color("d96a80"))
		_world_txt(Vector2(WIDTH-215,90),"A YGONA ESTÁ PRÓXIMA",11,Color("dba4ae"))
	_world_txt(Vector2(26,HEIGHT-49),_objective(),16,Color("e9e0ce"))
	var helper = "WASD MOVER  |  MOUSE MIRAR  |  SHIFT CORRER  |  ESPAÇO TIRAR/GUARDAR LANTERNA  |  E INTERAGIR"
	if ghost_unlocked:
		helper += "  |  F ESPECTRAL"
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
		draw_rect(Rect2((WIDTH-w)/2,114,w*ritual_left/CFG.RITUAL_SECONDS,13),Color("d88aab"))
		_world_txt(Vector2((WIDTH-w)/2+19,150),"MANTENHA-SE VIVO ATÉ O FIM DO RITUAL",14,Color("eecbdf"))
	if monster_lit and monster_present():
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
		_center_text("Fora da luz da lanterna, tudo é escuro. E é no escuro que ela anda.",350,19,Color("aeb9d5"))
		_center_text("Quando ouvir a risada, acenda a luz.",380,19,Color("aeb9d5"))
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

# --------------------------- BRILHOS ACIMA DO ESCURO -----------------------
func _draw_glows() -> void:
	var view: Rect2 = Rect2(34,112,WIDTH-68,HEIGHT-204)
	for item in scene_objects:
		if item["kind"] != "fragment":
			continue
		var v: float = fragment_pulse(int(item["idx"]))
		if v <= 0.02:
			continue
		var at: Vector2 = item["at"]
		var p: Vector2 = iso_renderer.screen(at)+Vector2(0,-22)
		if view.has_point(p):
			draw_circle(p,12.0+30.0*v,Color(1.0,.80,.42,.10*v))
			draw_circle(p,6.0+10.0*v,Color(1.0,.86,.55,.30*v))
			draw_circle(p,2.2+1.5*v,Color(1.0,.96,.82,.9*v))
		elif player.distance_to(at) < CFG.PULSE_HINT_RANGE:
			# Fora da tela: um clarao na borda aponta de onde veio o pulso.
			var edge: Vector2 = Vector2(clampf(p.x,view.position.x,view.end.x),clampf(p.y,view.position.y,view.end.y))
			draw_circle(edge,34.0,Color(1.0,.80,.42,.07*v))
			draw_circle(edge,16.0,Color(1.0,.84,.50,.16*v))
			draw_circle(edge,4.0,Color(1.0,.93,.74,.55*v))
	# Olhos da entidade no escuro: unico aviso visual quando a luz nao esta nela.
	if CFG.EYES_RANGE > 0.0 and monster_present() and not monster_lit and not in_hiding:
		var dist: float = draw_monster.distance_to(draw_player)
		if dist < CFG.EYES_RANGE and not map.has_wall_between(monster, player):
			var a: float = (1.0 - dist/CFG.EYES_RANGE)*0.95
			var head: Vector2 = iso_renderer.screen(draw_monster)+Vector2(0,-59)
			draw_circle(head+Vector2(-4,0),2.5,Color(.96,.46,.64,a))
			draw_circle(head+Vector2(5,0),2.5,Color(.96,.46,.64,a))

# --------------------------- CARTAS E BILHETES -----------------------------
func _draw_reading() -> void:
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.01,0.01,0.03,0.72))
	var lines: Array = reading.get("lines", [])
	var h: float = 150.0 + float(lines.size())*27.0
	var box: Rect2 = Rect2((WIDTH-640.0)*0.5,(HEIGHT-h)*0.5,640.0,h)
	draw_rect(box,Color("d9ccae"))
	draw_rect(box.grow(-7.0),Color("8a7758"),false,1.0)
	draw_rect(Rect2(box.position+Vector2(0,h-9.0),Vector2(640.0,9.0)),Color(0.35,0.1,0.12,0.25))
	var font: Font = ThemeDB.fallback_font
	var title: String = str(reading.get("title", ""))
	var tw: float = font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	draw_string(font,Vector2((WIDTH-tw)*0.5,box.position.y+42.0),title,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("6b2a35"))
	var y: float = box.position.y+86.0
	for line in lines:
		var text: String = str(line)
		var lw: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		draw_string(font,Vector2((WIDTH-lw)*0.5,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("2c2226"))
		y += 27.0
	var close: String = "[E] guardar"
	var cw: float = font.get_string_size(close,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
	draw_string(font,Vector2((WIDTH-cw)*0.5,box.end.y-22.0),close,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("7a6a55"))

# --------------------------- JUMPSCARE -------------------------------------
func _entity_face(center: Vector2, zoom: float, eyes: Color) -> void:
	draw_set_transform(center,0.0,Vector2(zoom,zoom))
	for i in range(15):
		var sx: float = -150.0 + float(i)*21.5
		draw_line(Vector2(sx*0.55,-120),Vector2(sx*1.15+sin(real_time*7.0+float(i))*6.0,170),Color("2a1836"),9.0)
	draw_circle(Vector2(0,-8),128.0,Color("120b18"))
	draw_circle(Vector2(0,0),104.0,Color("6f5362"))
	draw_circle(Vector2(0,26),88.0,Color("7d6170"))
	for side in [-1.0, 1.0]:
		var eye: Vector2 = Vector2(44.0*side,-26.0)
		draw_circle(eye,36.0,Color("0b0610"))
		draw_circle(eye,29.0,Color("efe6e2"))
		draw_circle(eye+Vector2(-3.0*side,3),15.0,eyes)
		draw_circle(eye+Vector2(-3.0*side,3),6.0,Color("08040a"))
		draw_line(eye+Vector2(-40.0*side,-44),eye+Vector2(30.0*side,-30),Color("120b18"),9.0)
	var mouth: PackedVector2Array = PackedVector2Array([Vector2(-66,34),Vector2(-34,26),Vector2(0,30),Vector2(34,26),Vector2(66,34),Vector2(46,84),Vector2(0,104),Vector2(-46,84)])
	draw_colored_polygon(mouth,Color("0d0508"))
	for i in range(7):
		var tx: float = -52.0 + float(i)*17.5
		draw_colored_polygon(PackedVector2Array([Vector2(tx-7,31),Vector2(tx+7,31),Vector2(tx,50)]),Color("e9dfd2"))
		draw_colored_polygon(PackedVector2Array([Vector2(tx-6,93-absf(tx)*0.2),Vector2(tx+6,93-absf(tx)*0.2),Vector2(tx,76-absf(tx)*0.2)]),Color("d8cbbd"))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_jumpscare() -> void:
	var k: float = clampf(death_time/CFG.JUMPSCARE_SECONDS,0.0,1.0)
	var flash: bool = fposmod(death_time*17.0,1.0) < 0.5
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.30,0.02,0.05) if (flash and k < 0.7) else Color(0.01,0.0,0.01))
	var jitter: Vector2 = Vector2(randf_range(-1,1),randf_range(-1,1))*22.0*(1.0-k)
	# A cara avanca de uma vez e continua crescendo ate estourar a tela.
	var zoom: float = 1.15 + 2.3*pow(k,0.45)
	_entity_face(Vector2(WIDTH*0.5,HEIGHT*0.5-10.0)+jitter,zoom,Color("f0457c"))
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0,0,0,smoothstep(0.82,1.0,k)))

# --------------------------- ABERTURA --------------------------------------
func _draw_intro() -> void:
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color("04050a"))
	var local: float = intro_time
	var scene: int = CFG.INTRO_SCENES.size()-1
	for i in range(CFG.INTRO_SCENES.size()):
		if local < float(CFG.INTRO_SCENES[i]):
			scene = i
			break
		local -= float(CFG.INTRO_SCENES[i])
	var length: float = float(CFG.INTRO_SCENES[scene])
	match scene:
		0: _intro_arrival(local/length)
		1: _intro_glimpse(local)
		2: _intro_fragments(local)
		_: _intro_locked(local)
	var fade: float = clampf(minf(local,length-local)/0.55,0.0,1.0)
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.016,0.02,0.04,1.0-fade))
	_center_text("ENTER para pular",HEIGHT-22,12,Color("5d6070"))

func _intro_arrival(k: float) -> void:
	# 1) Chegada de carro: a mansao no alto, com janelas acesas ("parecia habitada").
	draw_rect(Rect2(0,0,WIDTH,430),Color("0a0d1c"))
	draw_circle(Vector2(905,118),46,Color(0.80,0.78,0.86,0.10))
	draw_circle(Vector2(905,118),31,Color("c9c4d2"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,470),Vector2(420,405),Vector2(760,372),Vector2(WIDTH,410),Vector2(WIDTH,HEIGHT),Vector2(0,HEIGHT)]),Color("070910"))
	var house: Color = Color("0d0f1a")
	draw_rect(Rect2(660,238,300,150),house)
	draw_colored_polygon(PackedVector2Array([Vector2(640,240),Vector2(810,160),Vector2(980,240)]),house)
	draw_rect(Rect2(700,150,48,100),house)
	draw_colored_polygon(PackedVector2Array([Vector2(692,152),Vector2(724,104),Vector2(756,152)]),house)
	draw_rect(Rect2(880,176,26,60),house)
	for w in [Vector2(690,272),Vector2(752,272),Vector2(870,272),Vector2(920,272),Vector2(716,180),Vector2(690,330),Vector2(920,330)]:
		var lit: float = 0.72+0.2*sin(real_time*2.3+w.x)
		if w.x == 870.0 and fposmod(real_time,2.6) < 0.5:
			lit = 0.1   # uma janela pisca: tem alguem (ou algo) la dentro
		draw_rect(Rect2(w,Vector2(22,32)),Color(0.95,0.72,0.36,lit))
		draw_line(w+Vector2(11,0),w+Vector2(11,32),house,2.0)
	draw_rect(Rect2(796,326,30,62),Color("1b1320"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10,640),Vector2(-10,560),Vector2(798,388),Vector2(826,388),Vector2(300,HEIGHT),Vector2(0,HEIGHT)]),Color("141722"))
	var e: float = 1.0-pow(1.0-clampf(k*1.12,0.0,1.0),2.2)
	var car: Vector2 = Vector2(lerpf(-120.0,610.0,e),lerpf(628.0,452.0,e))
	var sc: float = lerpf(1.25,0.62,e)
	draw_set_transform(car,-0.21,Vector2(sc,sc))
	draw_colored_polygon(PackedVector2Array([Vector2(52,-22),Vector2(330,-70),Vector2(330,40),Vector2(52,2)]),Color(1.0,0.90,0.60,0.10))
	draw_colored_polygon(PackedVector2Array([Vector2(52,-16),Vector2(210,-38),Vector2(210,14),Vector2(52,-2)]),Color(1.0,0.93,0.70,0.13))
	draw_rect(Rect2(-58,-24,112,24),Color("2b2233"))
	draw_colored_polygon(PackedVector2Array([Vector2(-40,-24),Vector2(-26,-46),Vector2(22,-46),Vector2(36,-24)]),Color("231b2b"))
	draw_rect(Rect2(-20,-42,36,15),Color("4b5a72"))
	draw_circle(Vector2(-34,2),11,Color("08080c"))
	draw_circle(Vector2(32,2),11,Color("08080c"))
	draw_circle(Vector2(53,-12),4,Color("fff0b8"))
	draw_circle(Vector2(-57,-14),3,Color("c2344a"))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	_center_text("A mansão parecia habitada.",672,24,Color("d9cfc4"))

func _intro_glimpse(t: float) -> void:
	# 2) Vislumbre: ela avanca no escuro e para sempre que o facho a encontra.
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color("05050b"))
	var advance: float = 0.0
	var lit: bool = false
	var step: float = 0.04
	var clock: float = 0.0
	while clock < t:
		lit = fposmod(clock,2.2) > 1.15
		if not lit:
			advance += step
		clock += step
	var zoom: float = 0.42+advance*0.36
	var figure: Vector2 = Vector2(WIDTH*0.5,330.0+advance*26.0)
	var sweep: float = sin(t*TAU/2.2-0.9)
	var target: Vector2 = figure+Vector2(0,20) if lit else Vector2(WIDTH*0.5+(520.0 if sweep > 0.0 else -520.0)*absf(sweep),430.0)
	var hand: Vector2 = Vector2(WIDTH*0.5,HEIGHT+30.0)
	var side: Vector2 = (target-hand).orthogonal().normalized()*(150.0 if lit else 120.0)
	draw_colored_polygon(PackedVector2Array([hand,target-side,target+side]),Color(1.0,0.92,0.66,0.16 if lit else 0.10))
	if lit:
		_entity_face(figure,zoom,Color("c7f3ff"))
	else:
		# No escuro so se ve o par de olhos, cada vez maior.
		for sx in [-44.0, 44.0]:
			draw_circle(figure+Vector2(sx,-26.0)*zoom,15.0*zoom,Color(0.96,0.30,0.52,0.9))
	_center_text("Ela só anda quando ninguém a vê.",672,24,Color("d9cfc4"))

func _intro_fragments(t: float) -> void:
	# 3) Os tres fragmentos, um de cada vez, pulsando.
	var names: Array = ["FOTOGRAFIA","CANÇÃO","REFLEXO"]
	for i in range(3):
		var born: float = t-0.35-float(i)*0.95
		if born < 0.0:
			continue
		var c: Vector2 = Vector2(WIDTH*0.5+(float(i)-1.0)*230.0,300.0)
		var a: float = clampf(born/0.5,0.0,1.0)
		var pulse: float = 0.5+0.5*sin(real_time*3.0-float(i)*1.2)
		draw_circle(c,70.0+18.0*pulse,Color(1.0,0.78,0.40,0.07*a))
		draw_circle(c,44.0+8.0*pulse,Color(1.0,0.82,0.48,0.10*a))
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,-44),c+Vector2(27,0),c+Vector2(0,44),c+Vector2(-27,0)]),Color(0.93,0.78,0.50,a))
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,-44),c+Vector2(27,0),c+Vector2(0,6)]),Color(1.0,0.93,0.74,a))
		var w: float = ThemeDB.fallback_font.get_string_size(names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		_world_txt(Vector2(c.x-w*0.5,392.0),names[i],13,Color(0.78,0.72,0.66,a))
	_center_text("Três fragmentos do que ela foi. Uma única saída.",672,24,Color("d9cfc4"))

func _intro_locked(t: float) -> void:
	# 4) A porta bate. Corte para o jogo.
	var slam: float = clampf(t/0.25,0.0,1.0)
	draw_rect(Rect2(WIDTH*0.5-70.0,170.0,140.0,290.0),Color("0f0c14"))
	draw_rect(Rect2(WIDTH*0.5-70.0,170.0,140.0*(1.0-slam),290.0),Color(0.95,0.80,0.50,0.35))
	draw_rect(Rect2(WIDTH*0.5-70.0,170.0,140.0,290.0),Color("3a2c33"),false,3.0)
	draw_circle(Vector2(WIDTH*0.5+48.0,322.0),5.0,Color("8d7a5c"))
	_center_text("A porta se trancou atrás de você.",672,24,Color("d9cfc4"))
