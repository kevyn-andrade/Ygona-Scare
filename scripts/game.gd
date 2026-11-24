extends Node2D
## AFRODITE SCARE — Godot 4.7, vista 2.5D isometrica a 45 graus.
## Logica de colisao em grade + projecao artistica independente.
## Heroina com animacao de tirar/guardar lanterna no decote; os artefatos sao
## os silicones das mulheres sacrificadas no altar da entidade.
## Lore: uma seita tentou trazer a deusa Afrodite por bruxaria. O ritual ficou
## incompleto, e o que atravessou e uma Afrodite pela metade, rachada e podre,
## que guarda as oferendas (os silicones) para tentar se completar.
## Devolve-las ao altar desfaz a invocacao.

const WIDTH: float = 1152.0
const HEIGHT: float = 720.0
const TILE: int = 32
const PLAYER_WALK: float = 154.0
const PLAYER_RUN: float = 240.0
const CFG = preload("res://scripts/game_config.gd")
## Altar do ritual, no vestibulo: um bloco afastado da porta do salao (26,27).
const ALTAR_CELL: Vector2i = Vector2i(26, 30)
const DrawLayer = preload("res://scripts/draw_layer.gd")

## As tres mulheres que a seita sacrificou a Afrodite (personagens ficticias).
## Os "fragmentos" do codigo sao os silicones delas, guardados como trofeu.
const VICTIMS: Array = [
	{"name":"DALVA", "lines":[
		"Ainda está morno. Pulsa devagar na sua mão.",
		"",
		"Na borda, riscado a unha:  D A L V A",
		"",
		"Ela lia em voz alta para a casa vazia.",
		"A seita a ofereceu a Afrodite pela voz,",
		"e a deusa guardou isto entre os livros, como marcador.",
		"",
		"Você o guarda no decote, junto da lanterna."]},
	{"name":"MARLENE", "lines":[
		"Este treme sozinho, no compasso da caixa de música.",
		"",
		"Na borda, riscado a unha:  M A R L E N E",
		"",
		"Ela cantava para não ouvir a risada.",
		"A seita a deitou no altar no meio do refrão,",
		"e Afrodite trancou isto onde a canção nunca termina.",
		"",
		"Você o aperta no decote, ao lado do outro."]},
	{"name":"SORAIA", "lines":[
		"Frio como vidro. Do outro lado dele, alguém respira.",
		"",
		"Na borda, riscado a unha:  S O R A I A",
		"",
		"Ela só queria se ver bonita.",
		"Foi oferecida a Afrodite diante do espelho,",
		"e a deusa escondeu isto atrás do próprio reflexo.",
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

# Menu de pausa: continuar, reiniciar, volume e menu inicial.
const PAUSE_ITEMS: Array = ["CONTINUAR", "REINICIAR JOGO", "VOLUME", "MENU INICIAL"]
const PAUSE_VOLUME: int = 2
const SETTINGS_PATH: String = "user://ajustes.cfg"
var pause_index: int = 0
var pause_confirm: int = -1       # item que espera a segunda confirmacao (reiniciar / menu)
var master_volume: float = 1.0    # 0..1, aplicado ao barramento Master e salvo em SETTINGS_PATH
var dragging_volume: bool = false
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
var blackout_delay: float = -1.0  # >= 0: porta aberta, a luz ainda segura por este tempo
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
var jumpscare_rect: ColorRect     # chiado/distorcao por cima de tudo durante o susto
var apparition: Dictionary = {}   # Afrodite falsa parada no escuro: {"at","seen","ttl"}
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
var win_chime: float = 0.0        # > 0: o sino de vitoria toca quando o grito dela acabar
var dawn: float = 0.0             # 0..1: a casa clareia depois que o ritual a leva

var scene_objects: Array = []
var prompt_object: Dictionary = {}
var solid_bodies: Array = []      # Rect2 (mundo) dos moveis fixos que a protagonista nao atravessa
var spectral_inside: bool = false # ela esta dentro de uma Parede Espectral
var spectral_hinted: Dictionary = {}

@onready var music = $Audio

func _ready() -> void:
	map = ManorMap.new()
	iso_renderer = IsoRenderer.new(self)
	_setup_layers()
	_create_objects()
	_build_solids()
	_reset_opening()
	_initial_positions()
	_load_settings()
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
	# Jumpscare: sinal de TV morrendo por cima de tudo (inclusive do rosto).
	var top: CanvasLayer = CanvasLayer.new()
	top.name = "Susto"
	top.layer = 50
	add_child(top)
	jumpscare_rect = ColorRect.new()
	jumpscare_rect.name = "Chiado"
	jumpscare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jumpscare_rect.size = Vector2(WIDTH, HEIGHT)
	var js_mat: ShaderMaterial = ShaderMaterial.new()
	js_mat.shader = load("res://shaders/jumpscare.gdshader")
	jumpscare_rect.material = js_mat
	jumpscare_rect.visible = false
	top.add_child(jumpscare_rect)

func _reset_opening() -> void:
	power_on = true
	house_light = 1.0
	blackout_clock = 0.0
	blackout_delay = -1.0
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
		{"id":"altar", "kind":"altar", "label":"Altar de Afrodite", "at":altar_at()},
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
	# Costuras Espectrais (E, gastam carga): ligam comodos atraves das paredes
	# grossas. A ponta do quarto fica acima da cabeceira, fora da cama.
	portals = [
		{"a":tile(4, 12), "b":tile(4, 19)},
		{"a":tile(49, 12), "b":tile(49, 21)},
		{"a":tile(16, 29), "b":tile(21, 29)}
	]
	ghost_writings = [
		{"at":tile(26, 20), "text":"DEVOLVA O QUE É NOSSO"},
		{"at":tile(9, 21), "text":"ELA RI ANTES DE CORTAR"},
		{"at":tile(42, 13), "text":"TRÊS DE NÓS NO ALTAR"},
		{"at":tile(27, 10), "text":"ELA NÃO PISCA"}
	]
	# As tres continuam penduradas no salao, onde a seita as deixou secar.
	hanged = [{"at":tile(22, 12), "idx":0}, {"at":tile(30, 17), "idx":1}, {"at":tile(23, 23), "idx":2}]
	mannequins = []
	for cell in [Vector2i(36,19), Vector2i(42,19), Vector2i(49,19), Vector2i(36,31), Vector2i(45,31)]:
		mannequins.append({"at":tile(cell.x, cell.y), "home":tile(cell.x, cell.y), "moved":false, "raise":0.0})
	drag_marks = [
		[tile(22,12)+Vector2(0,10), tile(23,16), tile(25,20)+Vector2(6,0), tile(26,24), tile(26,27), altar_at()+Vector2(0,-22)],
		[tile(30,17)+Vector2(0,10), tile(29,20), tile(27,23)+Vector2(4,0), tile(26,26)+Vector2(8,0), altar_at()+Vector2(8,-22)],
		[tile(11,26), tile(15,26), tile(18,25)+Vector2(0,8), tile(21,25), tile(24,26)]
	]
	handprints = [
		{"at":tile(24,21), "rot":2.6}, {"at":tile(25,22)+Vector2(9,0), "rot":2.9}, {"at":tile(27,25), "rot":-2.7},
		{"at":tile(28,18), "rot":2.2}, {"at":tile(20,26), "rot":1.5}, {"at":altar_at()+Vector2(-14,32), "rot":0.4},
		{"at":altar_at()+Vector2(13,34), "rot":-0.5}, {"at":tile(13,24), "rot":1.2}, {"at":tile(40,25), "rot":-1.9},
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

func altar_at() -> Vector2:
	return tile(ALTAR_CELL.x, ALTAR_CELL.y)

func _box_at(at: Vector2, half: Vector2) -> Rect2:
	return Rect2(at - half, half * 2.0)

func _build_solids() -> void:
	## Pegada (no plano do mundo) de tudo que e solido: a protagonista esbarra
	## nos moveis em vez de atravessa-los. A entidade continua so com as paredes.
	solid_bodies = []
	for obj in iso_renderer.furniture:
		var half: Vector2 = Vector2(float(obj["w"]), float(obj["d"]))*0.5
		if obj["kind"] == "altar":
			half += Vector2(3, 3)       # o plinto e mais largo que o corpo do altar
		solid_bodies.append(_box_at(obj["at"], half))
	for spot in hiding_places:
		solid_bodies.append(_box_at(spot, Vector2(14, 12)))       # guarda-roupas
	for item in scene_objects:
		match str(item["kind"]):
			"book": solid_bodies.append(_box_at(item["at"], Vector2(7, 6)))      # atris
			"box": solid_bodies.append(_box_at(item["at"], Vector2(12, 9)))      # caixa de musica
	solid_bodies.append(_box_at(tile(26, 34), Vector2(20, 10)))   # porta da frente

func player_bodies() -> Array:
	## Solidos para a protagonista neste instante: moveis, manequins e as
	## penduradas. O que ja a estiver tocando fica de fora, para ela nunca
	## ficar presa (ex.: um manequim que parou encostado).
	var bodies: Array = solid_bodies.duplicate()
	for m in mannequins:
		bodies.append(_box_at(m["at"], Vector2(8, 6)))
	if not monster_banished:
		for h in hanged:
			bodies.append(_box_at(h["at"], Vector2(6, 6)))
	var me: Rect2 = _box_at(player, Vector2(9, 9))
	return bodies.filter(func(r: Rect2) -> bool: return not r.intersects(me))

func spectral_open() -> bool:
	## Paredes Espectrais ficam atravessaveis (e lilases) enquanto a luz
	## espectral esta realmente saindo da lanterna.
	return ghost_mode and light_active() and not in_hiding

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
	win_chime = 0.0
	dawn = 0.0
	ritual_left = CFG.RITUAL_SECONDS
	for bat in batteries:
		bat["taken"] = false
	time_passed = 0.0
	pulse_phase = 0.0
	deaths = 0
	spectral_hinted = {}
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
		m["raise"] = 0.0
	spectral_inside = false
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
	if status == "paused" and event is InputEventMouse:
		_pause_mouse(event)
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	if status == "paused":
		_pause_key(event.keycode)    # aceita repeticao: segurar ← → ajusta o volume
		return
	if event.echo:
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
	if status != "playing":
		return
	if key == KEY_ESCAPE:
		_open_pause()
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
			notify("Modo espectral: paredes lilases se atravessam andando; costuras roxas levam (E) a outro cômodo. Ela não te segue." if ghost_mode else "Modo normal: observe a criatura para imobilizá-la.", 5.0 if ghost_mode else 3.2)
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
		notify("SETAS ↑ ↓ ← → mover | MOUSE mirar | F espectral | ESPAÇO tirar/guardar lanterna | SHIFT correr | E interagir | Q distrair", 6.5)

# --------------------------- MENU DE PAUSA ---------------------------------
func _open_pause() -> void:
	status = "paused"
	pause_index = 0
	pause_confirm = -1
	dragging_volume = false
	music.sfx("click", -12.0, 0.9)

func _pause_key(key: int) -> void:
	if key == KEY_ESCAPE:
		if pause_confirm >= 0:
			pause_confirm = -1          # desiste de reiniciar / sair
		else:
			status = "playing"
		return
	if key in [KEY_UP, KEY_W]:
		_pause_select(pause_index - 1)
	elif key in [KEY_DOWN, KEY_S]:
		_pause_select(pause_index + 1)
	elif key in [KEY_LEFT, KEY_A] and pause_index == PAUSE_VOLUME:
		set_master_volume(master_volume - 0.1)
	elif key in [KEY_RIGHT, KEY_D] and pause_index == PAUSE_VOLUME:
		set_master_volume(master_volume + 0.1)
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		_pause_activate(pause_index)

func _pause_select(index: int) -> void:
	var wrapped: int = posmod(index, PAUSE_ITEMS.size())
	if wrapped != pause_index:
		pause_index = wrapped
		pause_confirm = -1
		music.sfx("click", -16.0, 1.4)

func _pause_activate(index: int) -> void:
	match index:
		0:
			status = "playing"
		1, 3:
			# Reiniciar e voltar ao menu perdem o progresso: pedem confirmacao.
			if pause_confirm != index:
				pause_confirm = index
				music.sfx("click", -10.0, 0.7)
				return
			pause_confirm = -1
			if index == 1:
				_restart_entirely()
			else:
				status = "menu"
		PAUSE_VOLUME:
			# ENTER no volume alterna entre mudo e o volume cheio.
			set_master_volume(0.0 if master_volume > 0.0 else 1.0)

func _pause_mouse(event: InputEventMouse) -> void:
	var at: Vector2 = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if dragging_volume:
				dragging_volume = false
				_save_settings()
			return
		if _volume_bar_rect().grow(6.0).has_point(at):
			pause_index = PAUSE_VOLUME
			dragging_volume = true
			_volume_from_mouse(at.x, false)
			return
		for i in range(PAUSE_ITEMS.size()):
			if _pause_rect(i).has_point(at):
				_pause_select(i)
				_pause_activate(i)
				return
	elif event is InputEventMouseButton and event.pressed and pause_index == PAUSE_VOLUME:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_master_volume(master_volume + 0.05)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_master_volume(master_volume - 0.05)
	elif event is InputEventMouseMotion:
		if dragging_volume:
			_volume_from_mouse(at.x, false)
			return
		for i in range(PAUSE_ITEMS.size()):
			if _pause_rect(i).has_point(at):
				_pause_select(i)

func _volume_from_mouse(x: float, save: bool) -> void:
	var bar: Rect2 = _volume_bar_rect()
	set_master_volume(clampf((x - bar.position.x)/bar.size.x, 0.0, 1.0), save)

func _pause_rect(i: int) -> Rect2:
	return Rect2(WIDTH*0.5 - 210.0, 262.0 + float(i)*64.0, 420.0, 50.0)

func _volume_bar_rect() -> Rect2:
	var r: Rect2 = _pause_rect(PAUSE_VOLUME)
	return Rect2(r.position.x + 150.0, r.position.y + 19.0, 200.0, 12.0)

func set_master_volume(value: float, save: bool = true) -> void:
	master_volume = clampf(snappedf(value, 0.01), 0.0, 1.0)
	var bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))
	if save:
		_save_settings()

func _load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var volume: float = 1.0
	if cfg.load(SETTINGS_PATH) == OK:
		volume = float(cfg.get_value("audio", "volume", 1.0))
	set_master_volume(volume, false)

func _save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "volume", master_volume)
	cfg.save(SETTINGS_PATH)

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
	_update_spectral()
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

func foyer_sealed() -> bool:
	## Antes de destrancar a porta do salao so o vestibulo tem luz: o resto da
	## casa fica no escuro, como fora do halo e da lanterna durante o jogo.
	return power_on and not foyer_door_open

func foyer_light_level() -> float:
	## Valor da mascara de luz que deixa o vestibulo com o mesmo escuro
	## residual (HOUSE_LIGHT_DARKNESS) que ele tinha com a casa toda acesa.
	## O shader faz alfa = DARKNESS*(1 - smoothstep(0, 0.6, m)); aqui inverte.
	var lit: float = clampf(1.0 - CFG.HOUSE_LIGHT_DARKNESS/CFG.DARKNESS, 0.0, 1.0)
	return 0.6*(0.5 - sin(asin(1.0 - 2.0*lit)/3.0))

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
		if blackout_delay >= 0.0:
			# Porta aberta: a casa fica acesa mais um instante antes do apagao.
			blackout_delay -= dt
			if blackout_delay < 0.0:
				_trigger_blackout()
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
	# Com a porta do salao trancada, so o vestibulo tem luz (ver draw_light_mask).
	var darkness: float = CFG.DARKNESS if foyer_sealed() else lerpf(CFG.DARKNESS, CFG.HOUSE_LIGHT_DARKNESS, clampf(house_light,0.0,1.0))
	# Depois do ritual, todos os comodos clareiam um tom, aos poucos.
	dawn = move_toward(dawn, 1.0 if monster_banished else 0.0, delta/maxf(0.01, CFG.BANISHED_FADE))
	darkness = lerpf(darkness, minf(darkness, CFG.BANISHED_DARKNESS), smoothstep(0.0, 1.0, dawn))
	darkness_rect.material.set_shader_parameter("darkness", darkness)
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
	var scaring: bool = status == "dead" and death_time < CFG.JUMPSCARE_SECONDS
	jumpscare_rect.visible = scaring
	if scaring:
		# Entra no maximo e so alivia um pouco no fim, antes do corte para o preto.
		jumpscare_rect.material.set_shader_parameter("amount", 1.0 - 0.35*smoothstep(0.55, 1.0, death_time/CFG.JUMPSCARE_SECONDS))
		jumpscare_rect.material.set_shader_parameter("clock", fposmod(real_time, 600.0))
	if status != "playing":
		glitch = maxf(0.0, glitch - delta*2.5)
		subliminal = maxf(0.0, subliminal - delta)
	music.update_theme(delta, collected_count(), dread if haunted else 0.0, music_duck if status == "playing" else 0.0, status in ["menu", "intro", "won"], (clampf(glitch + (0.6 if light_jam > 0.0 else 0.0), 0.0, 1.0)) if haunted else 0.0)
	queue_redraw()

func _update_aim() -> void:
	## A lanterna obedece SO ao mouse. As setas movem o corpo e nunca giram o
	## facho: da para andar para um lado e iluminar o outro.
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
		# Ja dentro de uma Parede Espectral, ela sempre consegue sair, mesmo
		# que a luz espectral apague no meio do caminho.
		var phasing: bool = spectral_open() or map.touches_spectral(player, 9.0)
		player = map.slide(player, direction * (PLAYER_RUN if running else PLAYER_WALK) * dt, 9.0, phasing, player_bodies())
		if running:
			_make_noise(player, 180.0)
		footstep_clock += dt
		if footstep_clock > (0.25 if running else 0.42):
			footstep_clock = 0.0
			# SFX discretos e ocasionais, não um som por frame.
			if randi() % 3 == 0:
				music.sfx("step")

func _update_spectral() -> void:
	## Paredes Espectrais: som ao atravessar e um aviso na primeira vez que ela
	## chega perto de cada uma (a fumaca roxa denuncia a parede "rala").
	var inside: bool = map.touches_spectral(player, 9.0)
	if inside and not spectral_inside:
		music.sfx("ghost", -9.0, 1.3)
		if not spectral_hinted.has("crossed"):
			spectral_hinted["crossed"] = true
			notify("Você atravessa a parede lilás. Afrodite não consegue segui-la por aqui.", 5.0)
	spectral_inside = inside
	if spectral_open():
		return
	for i in range(ManorMap.SPECTRAL_PASSAGES.size()):
		var center: Vector2 = map.passage_center(ManorMap.SPECTRAL_PASSAGES[i])
		if player.distance_to(center) > 64.0:
			continue
		var key: String = ("perto_%d" if ghost_unlocked else "fumaca_%d") % i
		if spectral_hinted.has(key):
			continue
		spectral_hinted[key] = true
		if ghost_unlocked:
			notify("Fumaça roxa vaza desta parede. Com a luz espectral (F) acesa, dá para atravessá-la andando.", 6.0)
		else:
			notify("Uma fumaça roxa escapa pelas frestas desta parede. Ela parece... não estar inteira aqui.", 5.5)

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
	## Uma Afrodite falsa, parada, num ponto que a jogadora ainda nao iluminou.
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
		# O braco sobe devagar para apontar quando ela chega perto (ou depois
		# que o manequim saiu do lugar) e so baixa quando ela vai embora.
		var point_at: bool = in_workshop and (bool(m["moved"]) or away < 210.0)
		m["raise"] = move_toward(float(m.get("raise", 0.0)), 1.0 if point_at else 0.0, dt*(1.3 if point_at else 0.6))
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
	# O facho espectral atravessa as Paredes Espectrais (elas ficam translucidas).
	return not map.has_wall_between(player, point, spectral_open())

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
	music.sfx("static", -3.0)
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
	if win_chime > 0.0:
		win_chime -= dt
		if win_chime <= 0.0:
			music.sfx("win")
	if not ritual_running:
		return
	ritual_left = maxf(0.0, ritual_left - dt)
	if status != "playing":
		return
	if ritual_left <= 0.0:
		ritual_running = false
		monster_banished = true
		monster_active = false
		# Ela grita de dor enquanto e arrastada de volta; o sino de vitoria
		# vem logo depois, quando o grito se apaga.
		music.sfx("shriek", -2.0, randf_range(0.97, 1.03))
		win_chime = 1.2
		shake = 0.45
		notify("ELAS LEVARAM AFRODITE DE VOLTA AO MAR. A PORTA ESTÁ ABERTA!", 8.0)
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
		notify("Você atravessou a parede. Afrodite não usa essas passagens.")
		return
	if kind == "letter":
		letter_read = true
		music.sfx("click", -10.0, 1.3)
		_open_reading("CARTA SOBRE A MESA", [
			"A quem entrar nesta casa:",
			"",
			"Uma seita tentou trazer Afrodite por bruxaria.",
			"O ritual não terminou: o que veio é só metade dela,",
			"rachada, podre, procurando o resto.",
			"Três mulheres foram deitadas no altar como oferenda.",
			"De cada uma, ela guardou os silicones",
			"e os escondeu pela mansão.",
			"",
			"Enquanto houver luz sobre ela, não dará um passo.",
			"No escuro, ela anda — e ri antes de vir.",
			"QUANDO OUVIR A RISADA, ACENDA A LUZ.",
			"",
			"Os silicones pulsam de tempos em tempos, como se ainda",
			"respirassem. ACHE OS TRÊS e devolva-os ao altar:",
			"o ritual se desfaz. É a única saída.",
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
			music.sfx("creak", -2.0, 0.82)    # a porta pesada rangendo ao abrir
			# A luz ainda segura um instante: da para espiar o salao antes do apagao.
			if CFG.BLACKOUT_DELAY > 0.0:
				blackout_delay = CFG.BLACKOUT_DELAY
			else:
				_trigger_blackout()
		return
	if kind == "lens":
		ghost_unlocked = true
		music.sfx("ghost")
		scare_flash = 0.25
		notify("Uma lente de outro mundo encaixou na lanterna. F: luz espectral — revela o oculto, mas NÃO paralisa Afrodite.", 7.5)
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
			notify("A caixa tocou sozinha. Afrodite ouviu! Pegue o silicone.", 5.0)
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
		notify("SILICONE %s/3 no decote. Afrodite sentiu falta da oferenda!" % total, 5.5)
		# A leitura congela a simulacao: um folego antes da perseguicao.
		_open_reading("SILICONE DE %s — %s/3" % [VICTIMS[index]["name"], total], VICTIMS[index]["lines"])
		reading_scare = true
		return
	if kind == "altar":
		if monster_banished:
			notify("A invocação se desfez. Vá até a porta da frente!")
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
	notify("Objeto arremessado: Afrodite ouviu um barulho!", 2.2)

func _objective() -> String:
	if monster_banished:
		return "A INVOCAÇÃO SE DESFEZ — alcance a porta da frente!"
	if ritual_running:
		return "SOBREVIVA AO RITUAL: %s s" % int(ceil(ritual_left))
	if collected_count() == 3:
		return "Tire os 3 silicones do decote e devolva-os ao ALTAR do vestíbulo."
	if power_on:
		if foyer_door_open:
			return "A porta do salão se abriu."
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
	_world_txt(Vector2(25,29),"AFRODITE SCARE",21,Color("e2c8b7"))
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
		_world_txt(Vector2(WIDTH-215,90),"AFRODITE ESTÁ PRÓXIMA",11,Color("dba4ae"))
	_world_txt(Vector2(26,HEIGHT-49),_objective(),16,Color("e9e0ce"))
	var helper = "SETAS ↑ ↓ ← → MOVER  |  MOUSE MIRAR  |  SHIFT CORRER  |  ESPAÇO TIRAR/GUARDAR LANTERNA  |  E INTERAGIR"
	if ghost_unlocked:
		helper += "  |  F ESPECTRAL"
	_world_txt(Vector2(26,HEIGHT-20),helper,11,Color("a6a8b8"))
	if hint_timer > 0.0 and status != "paused":
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
		_world_txt(Vector2(24,125),"AFRODITE NÃO SE MOVE ENQUANTO VOCÊ OLHA!",13,Color("c9dff5"))
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

func _draw_pause_menu() -> void:
	_center_text("PAUSADO",205,57,Color("ead7c5"))
	_center_text("A criatura espera do outro lado da porta...",240,16,Color("9295a8"))
	var font: Font = ThemeDB.fallback_font
	for i in range(PAUSE_ITEMS.size()):
		var r: Rect2 = _pause_rect(i)
		var chosen: bool = i == pause_index
		var asking: bool = i == pause_confirm
		var fill: Color = Color("5d4056") if chosen else Color(0.10,0.09,0.14,0.92)
		if asking:
			fill = Color("6e2a36")
		draw_rect(r,fill)
		draw_rect(r,Color("b59ab0") if chosen else Color("4b4458"),false,1.0)
		var label: String = str(PAUSE_ITEMS[i])
		if asking:
			label = ("REINICIAR? " if i == 1 else "SAIR PARA O MENU? ") + "ENTER CONFIRMA"
		var text_col: Color = Color("fff2e5") if chosen else Color("bdb4c6")
		if i == PAUSE_VOLUME:
			_world_txt(r.position+Vector2(24,32),label,19,text_col)
			var bar: Rect2 = _volume_bar_rect()
			_draw_bar(bar.position,bar.size.x,bar.size.y,master_volume,Color("c9a0d6") if chosen else Color("8a7a96"))
			var knob: Vector2 = Vector2(bar.position.x+bar.size.x*master_volume,bar.get_center().y)
			draw_circle(knob,7.0 if chosen else 5.5,Color("fff2e5") if chosen else Color("bdb4c6"))
			var pct: String = "MUDO" if master_volume <= 0.001 else "%d%%" % int(round(master_volume*100.0))
			_world_txt(Vector2(bar.end.x+14.0,r.position.y+32.0),pct,15,text_col)
		else:
			var tw: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
			_world_txt(Vector2(r.get_center().x-tw*0.5,r.position.y+32.0),label,19,text_col)
	var help: String = "↑ ↓ ESCOLHER  •  ENTER CONFIRMAR  •  ← → VOLUME  •  ESC VOLTAR AO JOGO"
	if pause_confirm >= 0:
		help = "ENTER DE NOVO PARA CONFIRMAR  •  ESC CANCELA"
	_center_text(help,560,14,Color("8e93a5"))

func _draw_overlay() -> void:
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.02,0.025,0.045,0.86))
	if status == "menu":
		# A cara dela atras do titulo, quase apagada, piscando no escuro.
		var peek: float = 0.10+0.05*sin(real_time*0.9)
		if fposmod(real_time,7.0) > 6.86:
			peek = 0.55
		_entity_face(Vector2(WIDTH/2,168),0.92,Color("f0457c"),0.12)
		draw_rect(Rect2(0,0,WIDTH,430),Color(0.02,0.025,0.045,1.0-peek))
		_center_text("AFRODITE SCARE",195,56,Color("ead7c5"))
		_center_text("SE VOCÊ DESVIAR O OLHAR, ELA SE MOVE",241,18,Color("c1a5b1"))
		_center_text("Uma seita tentou invocar Afrodite. O ritual ficou pela metade — e ela também.",314,22,Color("d4cbd5"))
		_center_text("Ache os silicones das três sacrificadas, devolva-os ao altar e saia da mansão.",346,19,Color("aeb9d5"))
		_center_text("Fora da luz, tudo é escuro — e é no escuro que ela anda. Quando ouvir a risada, acenda a luz.",378,16,Color("aeb9d5"))
		draw_rect(Rect2(WIDTH/2-199,437,398,58),Color("5d4056"))
		_center_text("PRESSIONE ENTER PARA JOGAR",477,23,Color("fff2e5"))
		_center_text("SETAS ↑ ↓ ← → MOVER  •  MOUSE MIRAR  •  ESPAÇO TIRAR/GUARDAR  •  F ESPECTRAL",553,16,Color("b1a9b9"))
		_center_text("E INTERAGIR  •  SHIFT CORRER  •  Q DISTRAIR  •  H AJUDA  •  F3 FPS",586,14,Color("8e93a5"))
		_center_text("VISTA ISOMÉTRICA 45°  •  GODOT 4.7  •  ÁUDIO ORIGINAL",676,13,Color("7e8292"))
	elif status == "paused":
		_draw_pause_menu()
	elif status == "dead":
		_entity_face(Vector2(WIDTH/2,170),0.62,Color("ef6374"),0.25)
		draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.02,0.0,0.01,0.55))
		_center_text("AFRODITE DEITOU VOCÊ NO ALTAR",327,45,Color("f4a9ac"))
		_center_text("Os silicones no seu decote ela ainda não achou. Você continua com eles.",393,20,Color("d8c5c9"))
		_center_text("Pressione R para reaparecer no vestíbulo",451,22,Color("fff0db"))
		_center_text("ESC para voltar ao menu",493,16,Color("9c98a8"))
	elif status == "won":
		draw_arc(Vector2(WIDTH/2,198),83,0,TAU,60,Color("e1c68a"),3)
		_center_text("INVOCAÇÃO DESFEITA",217,48,Color("f1dfb7"))
		_center_text("Dalva, Marlene e Soraia têm de volta o que era delas. Afrodite voltou ao mar.",302,23,Color("dbd1cf"))
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
	# Manequins que sairam do lugar: duas brasas miudas no escuro, logo fora do halo.
	if not in_hiding:
		for m in mannequins:
			var md: float = draw_player.distance_to(m["at"])
			if not bool(m["moved"]) or md > 300.0 or md < CFG.AMBIENT_RADIUS*0.8 or is_illuminated(m["at"]):
				continue
			var ma: float = clampf((300.0-md)/140.0,0.0,1.0)*(0.30+0.12*sin(real_time*3.0+float(m["home"].x)))
			var mh: Vector2 = iso_renderer.screen(m["at"])+Vector2(0,-73)
			draw_circle(mh+Vector2(-2.6,0),1.1,Color(1.0,.38,.22,ma))
			draw_circle(mh+Vector2(2.6,0),1.1,Color(1.0,.38,.22,ma))
	# Paredes e Costuras Espectrais com a luz comum: so um fiapo de fumaca roxa
	# e um brilho miudo denunciam onde a parede "nao esta inteira".
	if not spectral_open():
		for i in range(ManorMap.SPECTRAL_PASSAGES.size()):
			var center: Vector2 = map.passage_center(ManorMap.SPECTRAL_PASSAGES[i])
			if draw_player.distance_to(center) < 560.0:
				_spectral_wisp(iso_renderer.screen(center)+Vector2(0,-IsoRenderer.WALL_HEIGHT-3), float(i)*2.7, 1.0, view)
		for portal in portals:
			for end in [portal["a"], portal["b"]]:
				if draw_player.distance_to(end) < 460.0:
					_spectral_wisp(iso_renderer.screen(end)+Vector2(0,-9), end.x*0.011+end.y*0.007, 0.65, view)
	# A aparicao falsa tem os mesmos olhos. Nao da para saber qual e qual.
	if not apparition.is_empty() and not in_hiding and not is_illuminated(apparition["at"]):
		var fake: Vector2 = iso_renderer.screen(apparition["at"])+Vector2(0,-85)
		var fa: float = clampf((CFG.APPARITION_SECONDS-float(apparition["ttl"]))/1.2,0.0,1.0)*0.9
		draw_circle(fake+Vector2(-5,0),5.0,Color(1.0,.15,.36,fa*0.22))
		draw_circle(fake+Vector2(5,0),5.0,Color(1.0,.15,.36,fa*0.22))
		draw_circle(fake+Vector2(-5,0),2.0,Color(1.0,.30,.48,fa))
		draw_circle(fake+Vector2(5,0),2.0,Color(1.0,.30,.48,fa))

func _spectral_wisp(p: Vector2, seed: float, size: float, view: Rect2) -> void:
	## Indicador discreto (acima da escuridao): brilho roxo miudo e fumaca subindo.
	if not view.has_point(p):
		return
	var beat: float = 0.5+0.5*sin(real_time*1.4+seed)
	draw_circle(p,(10.0+4.0*beat)*size,Color(0.56,0.30,0.95,0.07+0.06*beat))
	draw_circle(p,2.4*size+0.7*beat,Color(0.84,0.68,1.0,0.30+0.25*beat))
	for k in range(4):
		var f: float = fposmod(real_time*0.32+float(k)*0.25+seed*0.13,1.0)
		var q: Vector2 = p+Vector2(sin(f*5.0+float(k)*1.7+seed)*5.0*size,-f*32.0*size)
		draw_circle(q,(1.8+f*5.5)*size,Color(0.62,0.42,0.98,0.20*(1.0-f)*(0.6+0.4*beat)))

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
	## Rosto de Afrodite pela metade (ritual incompleto): rosto de deusa em marmore rachado,
	## metade ainda bela (labio pintado, cilios, sobrancelha arqueada) e metade
	## descarnada ate o osso, com a boca rasgada ate a orelha. A concha partida
	## atras da cabeca faz de aureola. "gape" (0..1) despenca o maxilar.
	## Criatura ficticia: nao reproduz o rosto de nenhuma pessoa real.
	draw_set_transform(center,0.0,Vector2(zoom,zoom))
	var jaw: float = 72.0*clampf(gape,0.0,1.0)
	var marble: Color = Color("a69b9b")
	var marble_dk: Color = Color("6c6064")
	var rot: Color = Color("3b1220")
	var vein: Color = Color(0.80,0.08,0.20,0.9)
	var hair: Color = Color("0a070d")
	# Aureola: concha de Venus apodrecida, com um pedaco arrancado.
	var fan: PackedVector2Array = PackedVector2Array([Vector2(0,-30)])
	for k in range(25):
		var a: float = PI+0.12+(PI-0.24)*float(k)/24.0
		var r: float = 205.0+18.0*float(k%2)
		if k >= 15 and k <= 18:
			r *= 0.58+0.12*float(k%2)
		fan.append(Vector2(0,-30)+Vector2.from_angle(a)*r)
	draw_colored_polygon(fan,Color("3e3036"))
	for k in range(0,25,2):
		draw_line(Vector2(0,-30),fan[k+1],Color("1e161b"),5.0)
	# Cabelo encharcado: massa escura e mechas pesadas escorrendo.
	# Massa arredondada no alto que se abre em cortina ate os ombros.
	draw_colored_polygon(iso_renderer._curve([Vector2(-118,-112),Vector2(-66,-156),Vector2(0,-168),Vector2(66,-156),Vector2(118,-112),Vector2(140,-20),Vector2(150,90),Vector2(0,120),Vector2(-150,90),Vector2(-140,-20)],6),hair)
	# Mechas pesadas e onduladas, de comprimentos diferentes, afinando na ponta.
	for i in range(19):
		var u: float = float(i)/18.0
		var sx: float = lerpf(-150.0,150.0,u)
		var hlen: float = 230.0+fposmod(float(i)*37.0,90.0)
		var wv: float = sin(real_time*1.8+float(i)*0.7)*7.0
		var flare: float = (u-0.5)*70.0
		var shade: Color = hair if i%3 != 1 else Color("150e19")
		iso_renderer.strand(self,[Vector2(sx*0.6,-130),Vector2(sx*0.95,-40),Vector2(sx+flare*0.5+sin(float(i)*2.3)*10.0+wv*0.4,60),Vector2(sx+flare+wv,-40+hlen*0.75),Vector2(sx+flare*1.2+wv*1.4,-40+hlen)],15.0,1.5,shade)
	# Boca aberta: do canto esquerdo ate rasgar a bochecha direita.
	var mouth: PackedVector2Array = PackedVector2Array([Vector2(-40,54),Vector2(0,48),Vector2(40,42),Vector2(72,26),Vector2(98,0),Vector2(84,42+jaw*0.4),Vector2(56,60+jaw*0.8),Vector2(20,70+jaw),Vector2(-14,70+jaw),Vector2(-40,58+jaw*0.3)])
	draw_colored_polygon(mouth,Color("060204"))
	draw_circle(Vector2(18,62+jaw*0.55),12.0+jaw*0.18,Color(0.42,0.03,0.08,0.85))
	# Maxilar que despenca, com os dentes de baixo em agulha.
	var J: Vector2 = Vector2(0,jaw)
	draw_colored_polygon(PackedVector2Array([Vector2(-74,56)+J,Vector2(-40,58)+J,Vector2(-14,70)+J,Vector2(20,70)+J,Vector2(56,60)+J,Vector2(80,48)+J,Vector2(66,72)+J,Vector2(36,104)+J,Vector2(0,116)+J,Vector2(-36,104)+J,Vector2(-66,72)+J]),marble)
	draw_colored_polygon(PackedVector2Array([Vector2(8,72)+J,Vector2(56,60)+J,Vector2(80,48)+J,Vector2(66,72)+J,Vector2(36,104)+J,Vector2(10,100)+J]),rot)
	for i in range(8):
		var bx: float = -30.0 + float(i)*12.0
		var base_y: float = 69.0-maxf(0.0,bx-20.0)*0.25
		draw_colored_polygon(PackedVector2Array([Vector2(bx-4.5,base_y)+J,Vector2(bx+4.5,base_y)+J,Vector2(bx,base_y-13.0-fposmod(float(i)*29.0,9.0))+J]),Color("d8cbbd"))
	# Rosto de deusa: oval, macas altas, queixo fino (a parte de cima).
	draw_colored_polygon(PackedVector2Array([Vector2(-88,-50),Vector2(-80,-100),Vector2(-46,-128),Vector2(0,-136),Vector2(46,-128),Vector2(80,-100),Vector2(88,-50),Vector2(86,0),Vector2(98,0),Vector2(72,26),Vector2(40,42),Vector2(0,48),Vector2(-40,54),Vector2(-74,56),Vector2(-84,10)]),marble)
	# Metade direita descarnada: carne viva, osso da maca e o rasgo costurado.
	draw_colored_polygon(PackedVector2Array([Vector2(10,-2),Vector2(58,-20),Vector2(88,-30),Vector2(92,0),Vector2(72,26),Vector2(40,42),Vector2(14,40)]),rot)
	for k in range(5):
		draw_line(Vector2(20+float(k)*14.0,-6-float(k)*3.0),Vector2(16+float(k)*12.0,36-float(k)*4.0),Color("6a1a28"),3.0)
	draw_polyline(PackedVector2Array([Vector2(24,-14),Vector2(58,-22),Vector2(86,-24)]),Color("cfc4b8"),6.0)
	for k in range(4):
		var st: Vector2 = Vector2(40,42).lerp(Vector2(98,0),0.15+float(k)*0.24)
		draw_line(st+Vector2(6,7),st+Vector2(-6,-7),Color("c9bcae"),2.0)
	# Dentes de cima: perfeitos do lado bonito, agulhas do lado podre.
	for i in range(11):
		var tx: float = -32.0 + float(i)*11.0
		var top_y: float = 50.0-maxf(0.0,tx)*0.12-maxf(0.0,tx-40.0)*0.35
		var length: float = 10.0 if tx < 6.0 else 16.0+fposmod(float(i)*37.0,12.0)
		draw_colored_polygon(PackedVector2Array([Vector2(tx-5,top_y),Vector2(tx+5,top_y),Vector2(tx+(0.0 if tx < 6.0 else 1.5),top_y+length)]),Color("e9dfd2"))
	# Labios carnudos e pintados, so do lado que ainda e bonito.
	draw_colored_polygon(PackedVector2Array([Vector2(-44,55),Vector2(-28,46),Vector2(-14,44),Vector2(-6,47),Vector2(2,44),Vector2(10,48),Vector2(-6,52),Vector2(-30,55)]),Color("5e0c1d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-44,57)+J,Vector2(-26,58)+J,Vector2(4,72)+J,Vector2(-12,80)+J,Vector2(-34,72)+J]),Color("6b0f22"))
	draw_line(Vector2(-30,66)+J*0.7,Vector2(-16,70)+J*0.9,Color(0.85,0.45,0.52,0.55),3.0)
	# Nariz fino de estatua.
	draw_line(Vector2(-4,-30),Vector2(-8,14),marble_dk,3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-16,18),Vector2(-6,22),Vector2(2,18),Vector2(-6,14)]),Color("4d4044"))
	# Rachaduras do marmore, acesas por dentro.
	draw_polyline(PackedVector2Array([Vector2(-14,-136),Vector2(-24,-104),Vector2(-8,-80),Vector2(-20,-60)]),Color("2a1c26"),5.0)
	draw_polyline(PackedVector2Array([Vector2(-14,-136),Vector2(-24,-104),Vector2(-8,-80),Vector2(-20,-60)]),vein,1.8)
	draw_polyline(PackedVector2Array([Vector2(-84,-20),Vector2(-62,-6),Vector2(-70,20),Vector2(-56,40)]),Color("2a1c26"),4.0)
	draw_polyline(PackedVector2Array([Vector2(-84,-20),Vector2(-62,-6),Vector2(-70,20),Vector2(-56,40)]),vein,1.4)
	# Olho esquerdo: amendoado, cilios longos, sobrancelha arqueada... e esclera preta.
	var le: Vector2 = Vector2(-44,-34)
	draw_colored_polygon(PackedVector2Array([le+Vector2(-34,4),le+Vector2(-18,-12),le+Vector2(4,-16),le+Vector2(26,-8),le+Vector2(34,2),le+Vector2(14,12),le+Vector2(-12,12)]),Color("050307"))
	draw_circle(le+Vector2(2,-1),15.0,Color(eyes.r,eyes.g,eyes.b,0.22))
	draw_circle(le+Vector2(2,-1),9.0,eyes)
	draw_line(le+Vector2(2,-8),le+Vector2(2,6),Color("050307"),3.0)
	draw_circle(le+Vector2(-1,-4),2.2,Color("fff6f2"))
	for k in range(7):
		var lb: Vector2 = le+Vector2(-30+float(k)*10.0,-10-sin(float(k)/6.0*PI)*6.0)
		draw_line(lb,lb+Vector2(-6.0+float(k)*0.6,-16.0-sin(float(k)/6.0*PI)*5.0),Color("050307"),2.6)
	draw_polyline(PackedVector2Array([le+Vector2(-40,-26),le+Vector2(-16,-44),le+Vector2(14,-46),le+Vector2(36,-34)]),Color("120c14"),7.0)
	draw_colored_polygon(PackedVector2Array([le+Vector2(-34,2),le+Vector2(-20,-22),le+Vector2(10,-28),le+Vector2(34,0),le+Vector2(26,-8),le+Vector2(4,-16),le+Vector2(-18,-12)]),Color(0.20,0.05,0.14,0.55))
	# Olho direito: orbita vazia com veias, so uma brasa la no fundo.
	var re: Vector2 = Vector2(46,-36)
	for v in range(7):
		var va: float = TAU*float(v)/7.0+0.4
		draw_line(re+Vector2.from_angle(va)*28.0,re+Vector2.from_angle(va+0.25)*(48.0+fposmod(float(v)*13.0,9.0)),Color("5a0f1c"),2.0)
	draw_circle(re,36.0,Color("050307"))
	draw_circle(re+Vector2(-2,14),28.0,Color("050307"))
	draw_circle(re+Vector2(-4,6),16.0,Color(eyes.r,eyes.g,eyes.b,0.16))
	draw_circle(re+Vector2(-4,6),6.0,eyes)
	draw_circle(re+Vector2(-4,6),2.2,Color("fff6f2"))
	# Lagrimas pretas escorrendo dos dois lados.
	for e in [le, re]:
		var run: float = 62.0+14.0*sin(real_time*2.6+e.x*0.04)
		draw_line(e+Vector2(-4,14),e+Vector2(-7,26+run),Color("050307"),8.0)
		draw_line(e+Vector2(12,14),e+Vector2(14,20+run*0.55),Color("050307"),4.0)
	# Mechas molhadas caindo por cima, uma delas cruzando a metade podre.
	# Saem da risca, contornam a testa e escorrem ondulando pelos lados do rosto.
	var sheen: Color = Color(0.24,0.21,0.29,0.55)
	for hx in [-104.0,-94.0,-84.0,74.0,88.0,100.0]:
		var sd: float = signf(hx)
		var wv: float = sin(real_time*1.6+hx)*6.0
		var tip: float = 150.0+fposmod(absf(hx)*3.7,50.0)
		iso_renderer.strand(self,[Vector2(sd*8.0,-150),Vector2(hx*0.75,-118),Vector2(hx+sd*6.0,-50),Vector2(hx-sd*4.0+wv*0.5,30),Vector2(hx+sd*10.0+wv,tip)],12.0,1.2,hair)
	for hx in [-90.0, 82.0]:
		var sd2: float = signf(hx)
		iso_renderer.strand(self,[Vector2(sd2*10.0,-150),Vector2(hx*0.75,-120),Vector2(hx+sd2*5.0,-56),Vector2(hx-sd2*3.0,10)],2.5,0.5,sheen)
	# Uma mecha cruza a metade podre do rosto.
	var wv2: float = sin(real_time*1.3)*5.0
	iso_renderer.strand(self,[Vector2(6,-150),Vector2(26,-112),Vector2(32,-60),Vector2(26+wv2*0.5,-10),Vector2(38+wv2,40)],8.0,1.0,hair)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _claw(wrist: Vector2, side: float, spread: float) -> void:
	# Mao de estatua, de dedos longos e finos que se curvam como garras,
	# com unhas pretas pontudas, entrando pela lateral da tela.
	# Tudo em curvas afinadas (sem linhas retas nem pontas quadradas).
	var marble: Color = Color("a69b9b")
	var shade: Color = marble.darkened(0.2)
	var fwd: Vector2 = Vector2(-side,0.0)           # aponta para o centro da tela
	var curl: float = 0.8+0.4*spread                # os dedos tremem, abrindo e fechando
	# Antebraco que afina ate o pulso, com uma rachadura acesa.
	iso_renderer.strand(self,[wrist+Vector2(side*320.0,90.0),wrist+Vector2(side*160.0,42.0),wrist+Vector2(side*50.0,8.0),wrist+fwd*6.0],27.0,17.0,marble.darkened(0.3))
	draw_polyline(PackedVector2Array([wrist+Vector2(side*200.0,56.0),wrist+Vector2(side*150.0,33.0),wrist+Vector2(side*118.0,37.0),wrist+Vector2(side*76.0,16.0)]),Color(0.80,0.08,0.20,0.8),2.0,true)
	# Palma oval, inclinada na direcao da mao.
	var palm: PackedVector2Array = PackedVector2Array()
	for k in range(24):
		var a: float = TAU*float(k)/24.0
		palm.append(wrist+fwd*24.0+Vector2(cos(a)*36.0,sin(a)*25.0))
	draw_colored_polygon(palm,shade)
	# Quatro dedos em leque e o polegar mais baixo; cada um com tres falanges
	# que curvam para baixo, e uma unha preta comprida no fim.
	var lengths: Array = [0.86,1.0,0.95,0.78,0.62]
	for i in range(5):
		var thumb: bool = i == 4
		var offs: float = -side*1.05*spread if thumb else (float(i)-1.5)*0.34*spread*side
		var dir: Vector2 = fwd.rotated(offs)
		var k: float = float(lengths[i])
		var base: Vector2 = wrist+fwd*(8.0 if thumb else 26.0)+dir*30.0
		var knuckle: Vector2 = base+dir*64.0*k
		var d2: Vector2 = dir.rotated(-side*0.32*curl)
		var mid: Vector2 = knuckle+d2*44.0*k
		var d3: Vector2 = d2.rotated(-side*0.34*curl)
		var tip: Vector2 = mid+d3*28.0*k
		iso_renderer.strand(self,[base,knuckle,mid,tip],8.5 if thumb else 7.5,4.2,marble,6)
		draw_circle(knuckle,5.6,marble.lightened(0.05))
		draw_circle(mid,4.6,marble.lightened(0.05))
		var nail: Vector2 = d3.rotated(-side*0.35)
		iso_renderer.strand(self,[tip-d3*5.0,tip+d3*12.0,tip+d3*22.0+nail*14.0,tip+d3*24.0+nail*34.0],4.6,0.3,Color("0a0508"),6)
		draw_circle(tip+d3*24.0+nail*32.0,2.2,Color("5c0f1d"))

func _draw_jumpscare() -> void:
	## O rosto bate na tela quase de imediato (0,12 s), ja enorme, tremendo
	## e aos saltos; o maxilar despenca em seguida e as maos fecham rapido.
	## O chiado, os rasgos e a distorcao vem do shader "jumpscare" por cima.
	var t: float = death_time
	var k: float = clampf(t/CFG.JUMPSCARE_SECONDS,0.0,1.0)
	var full: Rect2 = Rect2(0,0,WIDTH,HEIGHT)
	draw_rect(full,Color(0.006,0.0,0.004))
	# Dois quadros de escuro so com chiado: o susto vem do nada.
	if t < 0.035:
		return
	var hit: float = clampf((t-0.035)/0.12,0.0,1.0)
	var slam: float = 1.0-pow(1.0-hit,3.0)
	# Flashes curtos de vermelho-escuro enquanto ela bate na tela.
	if t < 0.22 and fposmod(t*22.0,1.0) < 0.5:
		draw_rect(full,Color(0.20,0.0,0.03))
	var zoom: float = lerpf(1.7,2.8,slam) + 0.6*smoothstep(0.15,CFG.JUMPSCARE_SECONDS,t)
	# Tremor que nao para e saltos bruscos de posicao, como quadros pulados.
	var jitter: Vector2 = Vector2(randf_range(-1,1),randf_range(-1,1))*lerpf(34.0,16.0,k)
	if randf() < 0.2:
		jitter += Vector2(randf_range(-70,70),randf_range(-35,35))
	var at: Vector2 = Vector2(WIDTH*0.5,HEIGHT*0.5-20.0-60.0*k)+jitter
	_entity_face(at,zoom,Color("ff3d73"),clampf((t-0.05)/0.25,0.0,1.0))
	# Mais escuro: so os olhos e os dentes furam a sombra.
	draw_rect(full,Color(0.0,0.0,0.0,0.18))
	var close: float = smoothstep(0.0,0.28,t)
	for side in [-1.0, 1.0]:
		_claw(Vector2(WIDTH*0.5+side*lerpf(760.0,320.0,close),HEIGHT*0.72)+jitter*0.6,side,1.0+0.5*sin(t*34.0))
	draw_rect(full,Color(0,0,0,smoothstep(0.84,1.0,k)))

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
	_center_text("Três oferendas para Afrodite. Ela guardou os silicones.",672,24,Color("d9cfc4"))

func _intro_locked(t: float) -> void:
	# 4) A porta bate. Corte para o jogo.
	var slam: float = clampf(t/0.25,0.0,1.0)
	draw_rect(Rect2(WIDTH*0.5-70.0,170.0,140.0,290.0),Color("0f0c14"))
	draw_rect(Rect2(WIDTH*0.5-70.0,170.0,140.0*(1.0-slam),290.0),Color(0.95,0.80,0.50,0.35))
	draw_rect(Rect2(WIDTH*0.5-70.0,170.0,140.0,290.0),Color("3a2c33"),false,3.0)
	draw_circle(Vector2(WIDTH*0.5+48.0,322.0),5.0,Color("8d7a5c"))
	_center_text("A porta se trancou atrás de você.",672,24,Color("d9cfc4"))
