extends Node2D
## YGONA SCARE — Godot 4.7, vista 2.5D isometrica a 45 graus.
## Logica de colisao em grade + projecao artistica independente.
## Heroina com animacao de tirar/guardar lanterna no decote; os artefatos sao
## os silicones das mulheres sacrificadas no altar da entidade.

const WIDTH: float = 1152.0
const HEIGHT: float = 720.0
const TILE: int = 32
const PLAYER_WALK: float = 154.0
const PLAYER_RUN: float = 240.0
const CFG = preload("res://scripts/game_config.gd")
const DrawLayer = preload("res://scripts/draw_layer.gd")

## As tres mulheres sacrificadas no altar da Ygona (personagens ficticias).
## Os "fragmentos" do codigo sao os silicones delas, guardados como trofeu.
const VICTIMS: Array = [
	{"name":"DALVA", "lines":[
		"Ainda está morno. Pulsa devagar na sua mão.",
		"",
		"Na borda, riscado a unha:  D A L V A",
		"",
		"Ela lia em voz alta para a casa vazia.",
		"A Ygona gostou da voz. Deitou-a no altar",
		"e guardou isto entre os livros, como marcador.",
		"",
		"Você o guarda no decote, junto da lanterna."]},
	{"name":"MARLENE", "lines":[
		"Este treme sozinho, no compasso da caixa de música.",
		"",
		"Na borda, riscado a unha:  M A R L E N E",
		"",
		"Ela cantava para não ouvir a risada.",
		"A Ygona a deitou no altar no meio do refrão",
		"e trancou isto onde a canção nunca termina.",
		"",
		"Você o aperta no decote, ao lado do outro."]},
	{"name":"SORAIA", "lines":[
		"Frio como vidro. Do outro lado dele, alguém respira.",
		"",
		"Na borda, riscado a unha:  S O R A I A",
		"",
		"Ela só queria se ver bonita.",
		"A Ygona a deitou no altar diante do espelho",
		"e escondeu isto atrás do próprio reflexo.",
		"",
		"Não cabe mais nada no decote. Leve as três ao altar."]}
]
const WHISPERS: Array = [
	"devolva...", "ela tirou de mim", "não apague a luz", "ela está rindo",
	"atrás de você", "ainda estamos no altar", "meu nome era Dalva",
	"eu ainda estava cantando", "não olhe o espelho", "ela conta os seus passos",
	"leve a gente daqui", "ela gosta quando você corre"
]

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
var deaths: int = 0
var blood_trail: Array = []       # pingos que a entidade deixa pelo caminho
var trail_anchor: Vector2 = Vector2.ZERO
var ghost_writings: Array = []    # frases das vitimas, visiveis so na luz espectral
var dread: float = 0.0            # 0..1: proximidade da entidade (coracao/vinheta)
var heart_clock: float = 0.0
var heart_pulse: float = 0.0
var whisper: Dictionary = {}
var whisper_timer: float = 12.0
var aim_override: Vector2 = Vector2.ZERO   # testes: mira fixa, ignora o mouse

# Assombracoes: nada disto mata sozinho, mas tudo foi feito para dar medo.
var fear_rect: ColorRect
var apparition: Dictionary = {}   # Ygona falsa parada no escuro: {"at","seen","ttl"}
var apparition_timer: float = 20.0
var subliminal: float = 0.0       # segundos restantes do rosto-relampago
var subliminal_cooldown: float = 0.0
var glitch: float = 0.0           # rasgo de imagem (filtro de pavor)
var music_duck: float = 0.0       # 1 = a caixinha de musica se cala
var noise_timer_house: float = 9.0
var still_time: float = 0.0
var phantom_steps: int = 0
var phantom_clock: float = 0.0
var freeze_time: float = 0.0      # ha quanto tempo a luz segura a entidade
var shadow_warned: bool = false
var hide_compromised: bool = false
var reading_scare: bool = false
var mannequins: Array = []
var mannequin_noise: float = 0.0
var hanged: Array = []
var drag_marks: Array = []
var handprints: Array = []
var floor_writings: Array = []

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
	# Filtro de pavor: granulado, vinheta e distorcao por cima do mundo.
	fear_rect = ColorRect.new()
	fear_rect.name = "Medo"
	fear_rect.show_behind_parent = true
	fear_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fear_rect.size = Vector2(WIDTH, HEIGHT)
	var fear_mat: ShaderMaterial = ShaderMaterial.new()
	fear_mat.shader = load("res://shaders/fear.gdshader")
	fear_mat.set_shader_parameter("grain", CFG.FILM_GRAIN)
	fear_rect.material = fear_mat
	add_child(fear_rect)

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
		{"id":"fragment1", "kind":"fragment", "label":"Pegar o silicone de Dalva", "at":tile(10, 11), "idx":0},
		{"id":"brass_key", "kind":"key", "label":"Chave de latão", "at":tile(43, 8)},
		{"id":"musicbox", "kind":"box", "label":"Caixa de música", "at":tile(11, 26)},
		{"id":"fragment2", "kind":"fragment", "label":"Pegar o silicone de Marlene", "at":tile(13, 25), "idx":1},
		{"id":"seal1", "kind":"seal", "label":"Selo I", "at":tile(39, 23), "number":1},
		{"id":"seal2", "kind":"seal", "label":"Selo II", "at":tile(43, 23), "number":2},
		{"id":"seal3", "kind":"seal", "label":"Selo III", "at":tile(48, 23), "number":3},
		{"id":"mirror_clue", "kind":"clue", "label":"Escrita de outro mundo", "at":tile(44, 29)},
		{"id":"fragment3", "kind":"fragment", "label":"Pegar o silicone de Soraia", "at":tile(44, 27), "idx":2},
		{"id":"altar", "kind":"altar", "label":"Altar da Ygona", "at":tile(26, 29)},
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
	ghost_writings = [
		{"at":tile(26, 20), "text":"DEVOLVA O QUE É NOSSO"},
		{"at":tile(9, 21), "text":"ELA RI ANTES DE CORTAR"},
		{"at":tile(42, 13), "text":"TRÊS DE NÓS NO ALTAR"},
		{"at":tile(27, 10), "text":"ELA NÃO PISCA"}
	]
	# As tres continuam penduradas no salao, onde a Ygona as deixou secar.
	hanged = [{"at":tile(22, 12), "idx":0}, {"at":tile(30, 17), "idx":1}, {"at":tile(23, 23), "idx":2}]
	mannequins = []
	for cell in [Vector2i(36,19), Vector2i(42,19), Vector2i(49,19), Vector2i(36,31), Vector2i(45,31)]:
		mannequins.append({"at":tile(cell.x, cell.y), "home":tile(cell.x, cell.y), "moved":false})
	drag_marks = [
		[tile(22,12)+Vector2(0,10), tile(23,16), tile(25,20)+Vector2(6,0), tile(26,24), tile(26,27), tile(26,29)+Vector2(0,-22)],
		[tile(30,17)+Vector2(0,10), tile(29,20), tile(27,23)+Vector2(4,0), tile(26,26)+Vector2(8,0), tile(26,29)+Vector2(8,-22)],
		[tile(11,26), tile(15,26), tile(18,25)+Vector2(0,8), tile(21,25), tile(24,26)]
	]
	handprints = [
		{"at":tile(24,21), "rot":2.6}, {"at":tile(25,22)+Vector2(9,0), "rot":2.9}, {"at":tile(27,25), "rot":-2.7},
		{"at":tile(28,18), "rot":2.2}, {"at":tile(20,26), "rot":1.5}, {"at":tile(26,30)+Vector2(-14,0), "rot":0.4},
		{"at":tile(26,30)+Vector2(13,2), "rot":-0.5}, {"at":tile(13,24), "rot":1.2}, {"at":tile(40,25), "rot":-1.9},
		{"at":tile(8,12), "rot":0.9}, {"at":tile(43,10), "rot":2.0}
	]
	floor_writings = [
		{"at":tile(21,15), "text":"NÃO OLHE PARA TRÁS", "size":17},
		{"at":tile(22,33)+Vector2(0,10), "text":"ELA JÁ SABE QUE VOCÊ ENTROU", "size":13},
		{"at":tile(5,13), "text":"ELA LÊ JUNTO", "size":14},
		{"at":tile(37,13), "text":"AQUI ELA NOS LAVOU", "size":14},
		{"at":tile(3,31), "text":"NÃO DURMA", "size":16},
		{"at":tile(37,25), "text":"ELES ANDAM", "size":16}
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
	deaths = 0
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
	shake = 0.0
	blood_trail = []
	trail_anchor = monster
	dread = 0.0
	heart_clock = 0.0
	heart_pulse = 0.0
	whisper = {}
	whisper_timer = randf_range(CFG.WHISPER_MIN, CFG.WHISPER_MAX)
	apparition = {}
	apparition_timer = randf_range(CFG.APPARITION_MIN, CFG.APPARITION_MAX)*0.6
	subliminal = 0.0
	glitch = 0.0
	music_duck = 0.0
	noise_timer_house = randf_range(CFG.NOISE_MIN, CFG.NOISE_MAX)
	still_time = 0.0
	phantom_steps = 0
	freeze_time = 0.0
	hide_compromised = false
	for m in mannequins:
		m["at"] = m["home"]
		m["moved"] = false
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
	_update_dread(delta)
	_update_haunting(delta)
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
	# O tremor (queda de luz, silicone, susto) desloca mundo e mascara juntos.
	var jolt: Vector2 = Vector2.ZERO
	if shake > 0.0 and status == "playing":
		jolt = Vector2(randf_range(-1,1),randf_range(-1,1))*minf(shake,0.6)*18.0
	world_layer.position = jolt
	mask_layer.position = jolt*0.5
	var haunted: bool = status in ["playing", "reading", "paused"] and not power_on
	fear_rect.material.set_shader_parameter("fear", dread if haunted else 0.0)
	fear_rect.material.set_shader_parameter("glitch", clampf(glitch + (0.35 if light_jam > 0.0 else 0.0), 0.0, 1.0) if haunted else 0.0)
	fear_rect.material.set_shader_parameter("clock", fposmod(real_time, 600.0))
	if status != "playing":
		glitch = maxf(0.0, glitch - delta*2.5)
		subliminal = maxf(0.0, subliminal - delta)
	music.update_theme(delta, collected_count(), dread if haunted else 0.0, music_duck if status == "playing" else 0.0, status in ["menu", "intro", "won"], (clampf(glitch + (0.6 if light_jam > 0.0 else 0.0), 0.0, 1.0)) if haunted else 0.0)
	queue_redraw()

func _update_aim() -> void:
	if aim_override != Vector2.ZERO:
		look = aim_override.normalized()
		return
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
	for drop in blood_trail:
		drop["ttl"] = float(drop["ttl"]) - dt
	blood_trail = blood_trail.filter(func(d): return float(d["ttl"]) > 0.0)

func shadow_seconds(dist: float) -> float:
	## Quanto tempo a luz consegue segurar a entidade a esta distancia.
	return maxf(CFG.SHADOW_MIN_SECONDS, dist*0.92/CFG.SHADOW_SPEED)

func _spawn_apparition() -> bool:
	## Uma Ygona falsa, parada, num ponto que a jogadora ainda nao iluminou.
	for attempt in range(14):
		var ang: float = look.angle() + randf_range(-2.5, 2.5)
		var raw: Vector2 = player + Vector2.from_angle(ang)*randf_range(150.0, 300.0)
		var cell: Vector2i = Vector2i(int(raw.x/TILE), int(raw.y/TILE))
		if map.is_wall_cell(cell.x, cell.y):
			continue
		var spot: Vector2 = map.cell_center(cell.x, cell.y)
		if map.has_wall_between(player, spot) or is_illuminated(spot) or spot.distance_to(player) < 140.0:
			continue
		apparition = {"at":spot, "seen":0.0, "ttl":CFG.APPARITION_SECONDS}
		music_duck = 1.0      # a caixinha se cala: o silencio e o aviso
		return true
	return false

func _burst_apparition(touched: bool) -> void:
	apparition = {}
	light_jam = maxf(light_jam, 0.45)
	glitch = 1.0
	shake = 0.35
	music_duck = 0.0
	music.sfx("sting", -3.0, randf_range(0.9, 1.1))
	if touched or randf() < 0.4:
		subliminal = 0.13
		subliminal_cooldown = CFG.SUBLIMINAL_COOLDOWN

func _update_haunting(dt: float) -> void:
	## Tudo aqui e teatro: aparicoes, barulhos, passos, manequins. Nada causa
	## dano direto — serve para a jogadora nunca saber o que e verdadeiro.
	glitch = maxf(0.0, glitch - dt*2.5)
	subliminal = maxf(0.0, subliminal - dt)
	subliminal_cooldown = maxf(0.0, subliminal_cooldown - dt)
	mannequin_noise = maxf(0.0, mannequin_noise - dt)
	if power_on:
		return
	if apparition.is_empty():
		music_duck = move_toward(music_duck, 0.0, dt*0.5)
		apparition_timer -= dt
		if apparition_timer <= 0.0 and monster_present() and not in_hiding and monster_state == "RONDA" \
				and player.distance_to(monster) > CFG.APPARITION_SAFE:
			apparition_timer = randf_range(CFG.APPARITION_MIN, CFG.APPARITION_MAX) if _spawn_apparition() else 3.0
	else:
		apparition["ttl"] = float(apparition["ttl"]) - dt
		var gap: float = player.distance_to(apparition["at"])
		if is_illuminated(apparition["at"]):
			apparition["seen"] = float(apparition["seen"]) + dt
		if float(apparition["seen"]) > CFG.APPARITION_STARE or gap < 72.0:
			_burst_apparition(gap < 72.0)
		elif float(apparition["ttl"]) <= 0.0:
			apparition = {}
	# Rosto-relampago quando ela esta quase em cima.
	if dread > 0.78 and subliminal_cooldown <= 0.0 and not monster_lit:
		subliminal = 0.09
		glitch = 0.8
		subliminal_cooldown = CFG.SUBLIMINAL_COOLDOWN
	# A casa range, bate e arrasta coisas sozinha.
	noise_timer_house -= dt
	if noise_timer_house <= 0.0:
		noise_timer_house = randf_range(CFG.NOISE_MIN, CFG.NOISE_MAX)
		var which: String = ["creak", "knock", "scrape", "creak", "knock"][randi() % 5]
		music.sfx(which, randf_range(-17.0, -9.0), randf_range(0.85, 1.1))
	# Parada no escuro: passos se aproximam por tras e alguem respira na nuca.
	if not moving and not light_on and not in_hiding and monster_present():
		still_time += dt
	else:
		still_time = minf(still_time, 0.0)
		if still_time < 0.0:
			still_time += dt
	if still_time > CFG.STILL_SECONDS:
		still_time = -14.0
		phantom_steps = 4
		phantom_clock = 0.0
	if phantom_steps > 0:
		phantom_clock -= dt
		if phantom_clock <= 0.0:
			phantom_clock = 0.42
			music.sfx("step", -15.0 + float(4 - phantom_steps)*4.0, 0.7)
			phantom_steps -= 1
			if phantom_steps == 0:
				music.sfx("breath", -5.0, 1.0)
				glitch = 0.6
	# Manequins: so andam quando a luz nao esta neles, e so ate a beira do halo.
	var in_workshop: bool = map.room_name(player) == "OFICINA"
	for m in mannequins:
		var away: float = player.distance_to(m["at"])
		if not in_workshop:
			if away > 560.0:
				m["at"] = m["home"]
				m["moved"] = false
			continue
		if in_hiding or away <= CFG.MANNEQUIN_STOP or is_illuminated(m["at"]):
			continue
		var before: Vector2 = m["at"]
		m["at"] = map.slide(before, before.direction_to(player)*CFG.MANNEQUIN_SPEED*dt, 8.0)
		if before != m["at"]:
			m["moved"] = true
			if mannequin_noise <= 0.0 and away < 320.0:
				mannequin_noise = randf_range(3.5, 6.5)
				music.sfx("scrape", -15.0, randf_range(1.2, 1.5))

func _update_dread(dt: float) -> void:
	## Coracao e sussurros: o medo avisa antes dos olhos.
	heart_pulse = maxf(0.0, heart_pulse - dt*3.2)
	if not whisper.is_empty():
		whisper["ttl"] = float(whisper["ttl"]) - dt
		if float(whisper["ttl"]) <= 0.0:
			whisper = {}
	if not monster_present():
		dread = move_toward(dread, 0.0, dt)
		return
	dread = clampf(1.0 - player.distance_to(monster)/CFG.HEART_RANGE, 0.0, 1.0)
	if dread > 0.04:
		heart_clock += dt*lerpf(1.0, 2.6, dread)
		if heart_clock >= 1.0:
			heart_clock = 0.0
			heart_pulse = 1.0
			music.heartbeat(lerpf(-22.0, -5.0, dread))
	whisper_timer -= dt
	if whisper_timer <= 0.0:
		# As tres mulheres falam com quem carrega o que foi tirado delas.
		whisper_timer = randf_range(CFG.WHISPER_MIN, CFG.WHISPER_MAX)
		whisper = {"text":WHISPERS[randi() % WHISPERS.size()], "at":Vector2(randf_range(170.0,860.0),randf_range(170.0,520.0)), "ttl":3.4, "life":3.4}
		music.sfx("whisper", -13.0, randf_range(0.8,1.15))

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
		# A luz a segura, mas a sombra dela continua vindo pelo chao.
		freeze_time += dt
		if not shadow_warned and freeze_time > 1.2:
			shadow_warned = true
			notify("A sombra dela rasteja até você. Não a segure por muito tempo — recue.", 5.0)
		if freeze_time >= shadow_seconds(monster.distance_to(player)):
			freeze_time = 0.0
			light_jam = maxf(light_jam, CFG.SHADOW_JAM)
			glitch = 1.0
			shake = 0.3
			laugh_cooldown = 0.0
			laugh(-2.0)
			music.sfx("click", -4.0, 0.7)
			notify("A sombra alcançou a lanterna!", 1.6)
		return
	freeze_time = maxf(0.0, freeze_time - dt*1.5)
	var dist = monster.distance_to(player)
	if in_hiding and hide_compromised:
		monster_state = "PERSEGUINDO"
		alert_position = player
		search_timer = 5.0
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
				# Ela nao corre: avanca aos trancos, como um filme com quadros faltando.
				speed *= 1.0 + CFG.CHASE_JERK*sin(time_passed*11.0)
			elif monster_state == "BUSCANDO":
				speed = CFG.SEARCH_SPEED + n * CFG.SEARCH_SPEED_PER_FRAGMENT
			monster = map.slide(monster, monster.direction_to(step_to) * speed * dt, 10.0)
	if monster.distance_to(trail_anchor) > CFG.TRAIL_SPACING:
		trail_anchor = monster
		blood_trail.append({"at":monster+Vector2(randf_range(-7,7),randf_range(-7,7)), "ttl":CFG.TRAIL_SECONDS, "r":randf_range(3.5,7.5)})
		if blood_trail.size() > 60:
			blood_trail.pop_front()
	# Uma captura só ocorre com contato físico, nunca à distância.
	if not in_hiding and monster.distance_to(player) < 21.0:
		_die()
	elif in_hiding and hide_compromised and monster.distance_to(player) < 30.0:
		in_hiding = false
		_die()

func _die() -> void:
	status = "dead"
	death_time = 0.0
	deaths += 1
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
		notify("ELAS LEVARAM A YGONA. A PORTA DA FRENTE ESTÁ ABERTA!", 8.0)
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
		hide_compromised = false
		notify("Você saiu do esconderijo.", 1.5)
		return
	if kind == "hide":
		in_hiding = true
		hiding_spot = obj["at"]
		light_on = false
		ghost_mode = false
		# Entrar no armario com ela olhando nao adianta nada.
		hide_compromised = monster_present() and monster_state == "PERSEGUINDO" \
				and monster.distance_to(player) < CFG.HIDE_SEEN_RANGE and not map.has_wall_between(monster, player)
		if hide_compromised:
			music.sfx("sting", -8.0, 1.2)
			notify("ELA VIU VOCÊ ENTRAR. SAIA DAÍ!", 3.0)
		else:
			music.sfx("creak", -12.0, 1.25)
			notify("Fique quieta. Não respire. E para sair.")
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
			"Três mulheres foram deitadas no altar dela.",
			"De cada uma, a Ygona guardou os silicones como troféu",
			"e os escondeu pela mansão.",
			"",
			"Enquanto houver luz sobre ela, não dará um passo.",
			"No escuro, ela anda — e ri antes de vir.",
			"QUANDO OUVIR A RISADA, ACENDA A LUZ.",
			"",
			"Os silicones pulsam de tempos em tempos, como se ainda",
			"respirassem. ACHE OS TRÊS e devolva-os ao altar.",
			"É a única saída.",
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
				notify("A estante se abriu! Há algo mole e pálido entre os livros.", 4.0)
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
			notify("A caixa tocou sozinha. A Ygona ouviu! Pegue o silicone.", 5.0)
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
				notify("O espelho se partiu. O último silicone escorreu do vidro!", 5.0)
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
		notify("SILICONE %s/3 no decote. A Ygona sentiu falta do troféu!" % total, 5.5)
		# A leitura congela a simulacao: um folego antes da perseguicao.
		_open_reading("SILICONE DE %s — %s/3" % [VICTIMS[index]["name"], total], VICTIMS[index]["lines"])
		reading_scare = true
		return
	if kind == "altar":
		if monster_banished:
			notify("A maldição acabou. Vá até a porta da frente!")
		elif ritual_running:
			notify("Ritual em andamento! Sobreviva por %s segundos." % int(ceil(ritual_left)))
		elif collected_count() < 3:
			notify("O altar ainda espera por elas. Silicones: %s/3." % collected_count(), 4.0)
		else:
			ritual_running = true
			ritual_left = CFG.RITUAL_SECONDS
			monster_state = "PERSEGUINDO"
			alert_position = player
			search_timer = 25.0
			_make_noise(player, 1200.0)
			music.sfx("stinger")
			scare_flash = 0.65
			notify("VOCÊ DEVOLVEU OS SILICONES. ELAS ESTÃO VINDO — SOBREVIVA %d SEGUNDOS!" % int(CFG.RITUAL_SECONDS), 6.0)
		return
	if kind == "exit":
		if monster_banished:
			status = "won"
			music.sfx("win")
		elif collected_count() < 3:
			notify("A porta está selada. Devolva os três silicones ao altar.")
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
	if reading_scare:
		# Ao guardar a etiqueta, ela esta olhando. So por um instante.
		reading_scare = false
		subliminal = 0.11
		glitch = 1.0
		subliminal_cooldown = CFG.SUBLIMINAL_COOLDOWN
		music.sfx("sting", -7.0, 1.15)

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
		return "Tire os 3 silicones do decote e devolva-os ao ALTAR do vestíbulo."
	if power_on:
		if not letter_read:
			return "Há uma carta sobre a mesa."
		if not foyer_key_owned:
			return "A porta do salão está trancada. Procure a chave."
		return "Destranque a porta do salão."
	if collected_count() == 0:
		if not ghost_unlocked:
			return "Ache os silicones das sacrificadas. Eles pulsam de tempos em tempos."
		return "Procure os 3 silicones. Inspecione a biblioteca com a luz espectral."
	if not fragment_owned[1]:
		return "Explore a cozinha e encontre a chave da caixa de música."
	if not fragment_owned[2]:
		return "Os selos da oficina escondem o silicone de Soraia."
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
		if in_hiding and status == "playing":
			_draw_hiding()
		_draw_dread()
	_draw_hud()
	if subliminal > 0.0 and status == "playing":
		# Rosto-relampago: poucos quadros, escuro demais para ter certeza.
		_entity_face(Vector2(WIDTH*0.5+randf_range(-14,14),HEIGHT*0.5-30.0),2.3,Color("f0457c"),0.7)
		draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.03,0.0,0.01,0.42))
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
	_world_txt(Vector2(655,30),"SILICONES",14,Color("cdc7d6"))
	for i in range(3):
		var x = 782 + i*44
		if fragment_owned[i]:
			iso_renderer.gel(self,Vector2(x,37),14.0,sin(real_time*4.0+float(i)*1.9)*0.9)
		else:
			draw_arc(Vector2(x,37),14.0,PI,TAU,18,Color("5b5968"),1.5)
			draw_line(Vector2(x-14,37),Vector2(x+14,37),Color("5b5968"),1.5)
		_world_txt(Vector2(x-17,52),str(VICTIMS[i]["name"]),8,Color("d9b8c4") if fragment_owned[i] else Color("5f5c6c"))
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
		var max_width = minf(WIDTH-40.0, ThemeDB.fallback_font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+38.0)
		draw_rect(Rect2((WIDTH-max_width)*0.5,HEIGHT-137,max_width,37),Color(0.08,0.07,0.12,0.92))
		_world_txt(Vector2((WIDTH-max_width)*0.5+17,HEIGHT-113),message,16,Color("f0e2c9"))
	if status == "playing":
		if not prompt_object.is_empty():
			var prompt = "[E] " + str(prompt_object["label"])
			var panel_width = minf(620.0, ThemeDB.fallback_font.get_string_size(prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+35.0)
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
		# A cara dela atras do titulo, quase apagada, piscando no escuro.
		var peek: float = 0.10+0.05*sin(real_time*0.9)
		if fposmod(real_time,7.0) > 6.86:
			peek = 0.55
		_entity_face(Vector2(WIDTH/2,168),0.92,Color("f0457c"),0.12)
		draw_rect(Rect2(0,0,WIDTH,430),Color(0.02,0.025,0.045,1.0-peek))
		_center_text("YGONA SCARE",195,56,Color("ead7c5"))
		_center_text("SE VOCÊ DESVIAR O OLHAR, ELA SE MOVE",241,18,Color("c1a5b1"))
		_center_text("Três mulheres foram sacrificadas no altar. Ela guardou os silicones.",314,22,Color("d4cbd5"))
		_center_text("Ache os três, devolva-os ao altar e saia da mansão.",346,19,Color("aeb9d5"))
		_center_text("Fora da luz, tudo é escuro — e é no escuro que ela anda. Quando ouvir a risada, acenda a luz.",378,16,Color("aeb9d5"))
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
		_entity_face(Vector2(WIDTH/2,170),0.62,Color("ef6374"),0.25)
		draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.02,0.0,0.01,0.55))
		_center_text("A YGONA DEITOU VOCÊ NO ALTAR",327,45,Color("f4a9ac"))
		_center_text("Os silicones no seu decote ela ainda não achou. Você continua com eles.",393,20,Color("d8c5c9"))
		_center_text("Pressione R para reaparecer no vestíbulo",451,22,Color("fff0db"))
		_center_text("ESC para voltar ao menu",493,16,Color("9c98a8"))
	elif status == "won":
		draw_arc(Vector2(WIDTH/2,198),83,0,TAU,60,Color("e1c68a"),3)
		_center_text("MALDIÇÃO ROMPIDA",217,48,Color("f1dfb7"))
		_center_text("Dalva, Marlene e Soraia têm de volta o que era delas. E levaram a Ygona.",302,23,Color("dbd1cf"))
		_center_text("Tempo de fuga: %02d:%02d   •   Vezes no altar: %d" % [int(time_passed / 60.0), int(time_passed) % 60, deaths],367,23,Color("c5cbd9"))
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
			draw_circle(p,12.0+30.0*v,Color(1.0,.62,.74,.10*v))
			draw_circle(p,6.0+10.0*v,Color(1.0,.76,.84,.26*v))
		elif player.distance_to(at) < CFG.PULSE_HINT_RANGE:
			# Fora da tela: um clarao na borda aponta de onde veio o pulso.
			var edge: Vector2 = Vector2(clampf(p.x,view.position.x,view.end.x),clampf(p.y,view.position.y,view.end.y))
			draw_circle(edge,34.0,Color(1.0,.62,.74,.07*v))
			draw_circle(edge,16.0,Color(1.0,.72,.82,.16*v))
			draw_circle(edge,4.0,Color(1.0,.90,.93,.55*v))
	# Olhos da entidade no escuro: unico aviso visual quando a luz nao esta nela.
	if CFG.EYES_RANGE > 0.0 and monster_present() and not monster_lit and not in_hiding:
		var dist: float = draw_monster.distance_to(draw_player)
		if dist < CFG.EYES_RANGE and not map.has_wall_between(monster, player):
			var a: float = (1.0 - dist/CFG.EYES_RANGE)*0.95
			var head: Vector2 = iso_renderer.screen(draw_monster)+Vector2(0,-85)
			draw_circle(head+Vector2(-5,0),5.0,Color(1.0,.15,.36,a*0.22))
			draw_circle(head+Vector2(5,0),5.0,Color(1.0,.15,.36,a*0.22))
			draw_circle(head+Vector2(-5,0),2.0,Color(1.0,.30,.48,a))
			draw_circle(head+Vector2(5,0),2.0,Color(1.0,.30,.48,a))
	# A aparicao falsa tem os mesmos olhos. Nao da para saber qual e qual.
	if not apparition.is_empty() and not in_hiding and not is_illuminated(apparition["at"]):
		var fake: Vector2 = iso_renderer.screen(apparition["at"])+Vector2(0,-85)
		var fa: float = clampf((CFG.APPARITION_SECONDS-float(apparition["ttl"]))/1.2,0.0,1.0)*0.9
		draw_circle(fake+Vector2(-5,0),5.0,Color(1.0,.15,.36,fa*0.22))
		draw_circle(fake+Vector2(5,0),5.0,Color(1.0,.15,.36,fa*0.22))
		draw_circle(fake+Vector2(-5,0),2.0,Color(1.0,.30,.48,fa))
		draw_circle(fake+Vector2(5,0),2.0,Color(1.0,.30,.48,fa))

func _draw_hiding() -> void:
	## De dentro do armario so se ve pelas frestas. Se ela estiver perto,
	## um olho passa devagar do outro lado, procurando.
	var gap: float = player.distance_to(monster)
	var near: float = clampf(1.0 - gap/190.0, 0.0, 1.0) if monster_present() else 0.0
	if near > 0.0:
		var ex: float = WIDTH*0.5 + sin(real_time*0.6)*260.0*(1.0-near)
		var eye: Vector2 = Vector2(ex, 352.0 + sin(real_time*1.7)*5.0)
		var size: float = 0.8 + 1.3*near
		draw_circle(eye,150.0*size,Color("8f8088"))
		for v in range(9):
			var va: float = TAU*float(v)/9.0+0.3
			draw_line(eye+Vector2.from_angle(va)*52.0*size,eye+Vector2.from_angle(va+0.2)*96.0*size,Color("5a0f1c"),2.5*size)
		draw_circle(eye,62.0*size,Color("050307"))
		# A pupila procura... e, bem de perto, para em voce.
		var search: Vector2 = Vector2(sin(real_time*2.3)*22.0,cos(real_time*1.9)*9.0)*size*(1.0-near*near)
		draw_circle(eye+search,26.0*size,Color(0.94,0.20,0.40,0.25))
		draw_circle(eye+search,11.0*size,Color("f0457c"))
		draw_circle(eye+search,4.0*size,Color("fff6f2"))
	var dark: Color = Color(0.012,0.008,0.015,1.0 if near > 0.0 else 0.94)
	var slits: Array = [296.0, 344.0, 392.0]
	var top: float = 0.0
	for y in slits:
		draw_rect(Rect2(0,top,WIDTH,y-top),dark)
		top = y+13.0
	draw_rect(Rect2(0,top,WIDTH,HEIGHT-top),dark)
	draw_rect(Rect2(0,280,300,140),dark)
	draw_rect(Rect2(WIDTH-300,280,300,140),dark)
	for y in slits:
		draw_line(Vector2(300,y),Vector2(WIDTH-300,y),Color("2a1f24"),1.0)
	if hide_compromised:
		_center_text("ELA SABE ONDE VOCÊ ESTÁ",470,22,Color("f4a9ac"))
	elif near > 0.35:
		_center_text("não respire",470,15,Color(0.75,0.62,0.68,0.5+0.4*sin(real_time*5.0)))

func _draw_dread() -> void:
	# Sussurro das vitimas: aparece num canto e some antes de dar para ler direito.
	if not whisper.is_empty() and status == "playing":
		var k: float = float(whisper["ttl"])/float(whisper["life"])
		var wa: float = sin(clampf(k,0.0,1.0)*PI)*0.55
		var at: Vector2 = whisper["at"]
		at += Vector2(sin(real_time*1.3)*4.0,(1.0-k)*-14.0)
		draw_string(ThemeDB.fallback_font,at,str(whisper["text"]),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(.80,.62,.70,wa))
	# Vinheta de sangue que bate junto com o coracao quando ela esta perto.
	var strength: float = dread*(0.10+0.30*heart_pulse)
	if strength < 0.01:
		return
	var c: Color = Color(0.55,0.02,0.07,strength)
	var z: Color = Color(0.55,0.02,0.07,0.0)
	var depth: float = 170.0
	var cols: PackedColorArray = PackedColorArray([c,c,z,z])
	draw_polygon(PackedVector2Array([Vector2(0,0),Vector2(WIDTH,0),Vector2(WIDTH,depth),Vector2(0,depth)]),cols)
	draw_polygon(PackedVector2Array([Vector2(0,HEIGHT),Vector2(WIDTH,HEIGHT),Vector2(WIDTH,HEIGHT-depth),Vector2(0,HEIGHT-depth)]),cols)
	draw_polygon(PackedVector2Array([Vector2(0,0),Vector2(0,HEIGHT),Vector2(depth,HEIGHT),Vector2(depth,0)]),cols)
	draw_polygon(PackedVector2Array([Vector2(WIDTH,0),Vector2(WIDTH,HEIGHT),Vector2(WIDTH-depth,HEIGHT),Vector2(WIDTH-depth,0)]),cols)

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
func _entity_face(center: Vector2, zoom: float, eyes: Color, gape: float = 1.0) -> void:
	## Rosto da Ygona: caveira comprida, orbitas ocas chorando preto e um sorriso
	## cortado ate as orelhas. "gape" (0..1) desloca o maxilar.
	## Aparicao ficticia e abstrata: nao reproduz o rosto de nenhuma pessoa real.
	draw_set_transform(center,0.0,Vector2(zoom,zoom))
	var jaw: float = 78.0*clampf(gape,0.0,1.0)
	var bone: Color = Color("8f8088")
	for i in range(17):
		var sx: float = -160.0 + float(i)*20.0
		draw_line(Vector2(sx*0.55,-120),Vector2(sx*1.15+sin(real_time*7.0+float(i))*6.0,190+fposmod(float(i)*37.0,60.0)),Color("17101c"),9.0)
	draw_circle(Vector2(0,-8),128.0,Color("0c070f"))
	# Maxilar pendurado, depois o cranio por cima.
	draw_colored_polygon(PackedVector2Array([Vector2(-66,70),Vector2(66,70),Vector2(46,122+jaw),Vector2(0,138+jaw),Vector2(-46,122+jaw)]),Color("75666e"))
	draw_colored_polygon(PackedVector2Array([Vector2(-92,-40),Vector2(-78,-92),Vector2(-40,-118),Vector2(0,-124),Vector2(40,-118),Vector2(78,-92),Vector2(92,-40),Vector2(84,30),Vector2(62,90),Vector2(26,112),Vector2(0,116),Vector2(-26,112),Vector2(-62,90),Vector2(-84,30)]),bone)
	for side in [-1.0, 1.0]:
		# Bochechas fundas.
		draw_colored_polygon(PackedVector2Array([Vector2(84*side,-2),Vector2(54*side,12),Vector2(44*side,74),Vector2(64*side,86)]),Color("5a4953"))
	# Rachaduras e o sinal entalhado na testa.
	var crack: Color = Color("2a1c26")
	draw_polyline(PackedVector2Array([Vector2(-12,-124),Vector2(-24,-96),Vector2(-10,-74),Vector2(-18,-58)]),crack,2.4)
	draw_line(Vector2(-24,-96),Vector2(-46,-84),crack,1.8)
	draw_polyline(PackedVector2Array([Vector2(34,-119),Vector2(42,-94),Vector2(30,-80)]),crack,2.0)
	draw_polyline(PackedVector2Array([Vector2(-11,-104),Vector2(11,-104),Vector2(0,-84),Vector2(-11,-104)]),Color("5a0f1c"),2.6)
	draw_line(Vector2(0,-110),Vector2(0,-80),Color("5a0f1c"),2.0)
	for side in [-1.0, 1.0]:
		var eye: Vector2 = Vector2(46.0*side,-30.0)
		# Orbitas ocas e caidas, com veias em volta.
		for v in range(7):
			var va: float = TAU*float(v)/7.0+side*0.4
			draw_line(eye+Vector2.from_angle(va)*30.0,eye+Vector2.from_angle(va+0.25)*(50.0+fposmod(float(v)*13.0,9.0)),Color("5a0f1c"),2.0)
		draw_circle(eye,39.0,Color("050307"))
		draw_circle(eye+Vector2(-2.0*side,15),30.0,Color("050307"))
		# No fundo, uma pupila minuscula que nunca desvia.
		var pupil: Vector2 = eye+Vector2(-4.0*side,5)
		draw_circle(pupil,17.0,Color(eyes.r,eyes.g,eyes.b,0.16))
		draw_circle(pupil,7.0,eyes)
		draw_circle(pupil,2.4,Color("fff6f2"))
		# Lagrimas pretas escorrendo.
		var run: float = 62.0+14.0*sin(real_time*2.6+side*1.7)
		draw_line(eye+Vector2(-6.0*side,36),eye+Vector2(-9.0*side,44+run),Color("050307"),8.0)
		draw_line(eye+Vector2(12.0*side,38),eye+Vector2(14.0*side,40+run*0.55),Color("050307"),4.0)
		draw_line(eye+Vector2(-42.0*side,-46),eye+Vector2(30.0*side,-34),Color("0c070f"),10.0)
		# O sorriso foi cortado ate as orelhas e mal costurado.
		var corner: Vector2 = Vector2(70.0*side,40)
		var ear: Vector2 = Vector2(100.0*side,2)
		draw_line(corner,ear,Color("3d0812"),7.0)
		for k in range(4):
			var st: Vector2 = corner.lerp(ear,0.18+float(k)*0.24)
			draw_line(st+Vector2(5,7),st+Vector2(-5,-7),Color("c9bcae"),1.8)
	draw_colored_polygon(PackedVector2Array([Vector2(-9,24),Vector2(0,0),Vector2(9,24)]),Color("140a11"))
	# Boca: garganta vermelha la no fundo e duas fileiras de dentes em agulha.
	var low: float = 108.0+jaw
	draw_colored_polygon(PackedVector2Array([Vector2(-70,40),Vector2(-36,34),Vector2(0,38),Vector2(36,34),Vector2(70,40),Vector2(56,82+jaw*0.6),Vector2(24,low),Vector2(0,low+6),Vector2(-24,low),Vector2(-56,82+jaw*0.6)]),Color("060204"))
	draw_circle(Vector2(0,74+jaw*0.5),16.0+jaw*0.16,Color(0.42,0.03,0.08,0.85))
	draw_circle(Vector2(0,76+jaw*0.5),7.0+jaw*0.08,Color("060204"))
	for i in range(10):
		var ix: float = -49.5 + float(i)*11.0
		draw_colored_polygon(PackedVector2Array([Vector2(ix-4,44),Vector2(ix+4,44),Vector2(ix,58+fposmod(float(i)*5.0,7.0))]),Color("9a8a80"))
	for i in range(11):
		var tx: float = -60.0 + float(i)*12.0
		var top_y: float = 35.0+absf(tx)*0.07
		var length: float = 17.0+fposmod(float(i)*37.0,13.0)
		draw_colored_polygon(PackedVector2Array([Vector2(tx-5.5,top_y),Vector2(tx+5.5,top_y),Vector2(tx+fposmod(float(i)*3.0,4.0)-2.0,top_y+length)]),Color("e9dfd2"))
	for i in range(9):
		var bx: float = -48.0 + float(i)*12.0
		var base_y: float = low+4.0-pow(absf(bx)/56.0,1.5)*(30.0+jaw*0.4)
		var blen: float = 14.0+fposmod(float(i)*29.0,11.0)
		draw_colored_polygon(PackedVector2Array([Vector2(bx-5,base_y),Vector2(bx+5,base_y),Vector2(bx,base_y-blen)]),Color("d8cbbd"))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _claw(wrist: Vector2, side: float, spread: float) -> void:
	# Mao de dedos compridos entrando pela lateral da tela.
	var bone: Color = Color("8f8088")
	draw_line(wrist+Vector2(side*260.0,60),wrist,bone.darkened(0.3),46.0)
	draw_circle(wrist,34.0,bone.darkened(0.2))
	for i in range(5):
		var ang: float = (PI if side > 0.0 else 0.0) + (float(i)-2.0)*0.30*spread*side
		var dir: Vector2 = Vector2.from_angle(ang)
		var knuckle: Vector2 = wrist+dir*70.0
		var tip: Vector2 = knuckle+dir.rotated(-0.5*side)*74.0
		draw_line(wrist+dir*18.0,knuckle,bone,15.0)
		draw_line(knuckle,tip,bone,11.0)
		draw_circle(knuckle,8.5,bone.darkened(0.15))
		draw_line(tip,tip+dir.rotated(-0.5*side)*26.0,Color("1c0a10"),7.0)

func _draw_jumpscare() -> void:
	var k: float = clampf(death_time/CFG.JUMPSCARE_SECONDS,0.0,1.0)
	var flash: bool = fposmod(death_time*17.0,1.0) < 0.5
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.30,0.02,0.05) if (flash and k < 0.7) else Color(0.01,0.0,0.01))
	var jitter: Vector2 = Vector2(randf_range(-1,1),randf_range(-1,1))*22.0*(1.0-k)
	# A cara avanca de uma vez, o maxilar despenca e ela continua crescendo
	# ate engolir a tela, enquanto as maos fecham pelos lados.
	var zoom: float = 1.15 + 2.3*pow(k,0.45)
	_entity_face(Vector2(WIDTH*0.5,HEIGHT*0.5-30.0-70.0*k)+jitter,zoom,Color("f0457c"),clampf(k*3.5,0.0,1.0))
	var close: float = smoothstep(0.0,0.45,k)
	for side in [-1.0, 1.0]:
		_claw(Vector2(WIDTH*0.5+side*lerpf(760.0,330.0,close),HEIGHT*0.72)+jitter*0.5,side,1.0+0.5*sin(death_time*30.0))
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
		_entity_face(figure,zoom,Color("c7f3ff"),0.10)
	else:
		# No escuro so se ve o par de olhos, cada vez maior.
		for sx in [-44.0, 44.0]:
			draw_circle(figure+Vector2(sx,-26.0)*zoom,15.0*zoom,Color(0.96,0.20,0.42,0.16))
			draw_circle(figure+Vector2(sx,-26.0)*zoom,6.0*zoom,Color(1.0,0.26,0.46,0.95))
	_center_text("Ela só anda quando ninguém a vê.",672,24,Color("d9cfc4"))

func _intro_fragments(t: float) -> void:
	# 3) O altar e os tres trofeus: os silicones das mulheres sacrificadas.
	var slab: Rect2 = Rect2(WIDTH*0.5-350.0,372.0,700.0,30.0)
	draw_rect(Rect2(slab.position+Vector2(46,30),Vector2(608,96)),Color("100b10"))
	draw_rect(slab,Color("231820"))
	draw_line(slab.position,slab.position+Vector2(700,0),Color("4a3a44"),2.0)
	var wet: float = clampf(t/3.2,0.0,1.0)
	for i in range(11):
		var dx: float = slab.position.x+38.0+float(i)*62.0
		var run: float = (12.0+fposmod(float(i)*53.0,58.0))*wet
		draw_line(Vector2(dx,374.0),Vector2(dx,402.0+run),Color("4a0b17"),3.0 if i%3 == 0 else 2.0)
		draw_circle(Vector2(dx,402.0+run),2.4,Color("5c0f1d"))
	for i in range(3):
		var born: float = t-0.35-float(i)*0.95
		if born < 0.0:
			continue
		var c: Vector2 = Vector2(WIDTH*0.5+(float(i)-1.0)*230.0,368.0)
		var a: float = clampf(born/0.5,0.0,1.0)
		var pulse: float = 0.5+0.5*sin(real_time*3.0-float(i)*1.2)
		draw_circle(c+Vector2(0,-26),84.0+18.0*pulse,Color(1.0,0.58,0.72,0.06*a))
		draw_circle(c+Vector2(0,-26),56.0+8.0*pulse,Color(1.0,0.66,0.78,0.09*a))
		iso_renderer.gel(self,c,48.0,sin(real_time*4.2-float(i)*1.3)*(2.0+3.0*pulse),a)
		var victim: String = str(VICTIMS[i]["name"])
		var w: float = ThemeDB.fallback_font.get_string_size(victim,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		_world_txt(Vector2(c.x-w*0.5,292.0),victim,14,Color(0.84,0.74,0.76,a))
	_center_text("Três mulheres deitadas no altar. Ela guardou os silicones.",672,24,Color("d9cfc4"))

func _intro_locked(t: float) -> void:
	# 4) A porta bate. Corte para o jogo.
	var slam: float = clampf(t/0.25,0.0,1.0)
	draw_rect(Rect2(WIDTH*0.5-70.0,170.0,140.0,290.0),Color("0f0c14"))
	draw_rect(Rect2(WIDTH*0.5-70.0,170.0,140.0*(1.0-slam),290.0),Color(0.95,0.80,0.50,0.35))
	draw_rect(Rect2(WIDTH*0.5-70.0,170.0,140.0,290.0),Color("3a2c33"),false,3.0)
	draw_circle(Vector2(WIDTH*0.5+48.0,322.0),5.0,Color("8d7a5c"))
	_center_text("A porta se trancou atrás de você.",672,24,Color("d9cfc4"))
