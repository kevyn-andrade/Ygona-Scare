extends RefCounted
class_name IsoRenderer
## YGONA SCARE: apresentacao 2.5D projetada a 45 graus (losangos 2:1).
## A simulacao, as colisoes e o pathfinding continuam em coordenadas 2D.
## Toda a arte foi desenhada para o projeto com primitivas do Godot.

const TS: int = 32
const VIEW_WIDTH: float = 1152.0
const VIEW_HEIGHT: float = 720.0
const SKEW_X: float = 0.96
const SKEW_Y: float = 0.48
const ORIGIN: Vector2 = Vector2(1210.0, 65.0)
const WALL_HEIGHT: float = 37.0

var g
var cv: CanvasItem   # camada onde o mundo e desenhado (abaixo da escuridao)
var furniture: Array = []
# Texturas estaticas: um piso inteiro + faixas isometricas das paredes.
# O Godot desenha poucas imagens por quadro, em vez de centenas de cubos.
var floor_texture: Texture2D
var floor_origin: Vector2 = Vector2.ZERO
var wall_bands: Array = []

func _init(game: Node2D) -> void:
    g = game
    furniture = [
        {"at":g.tile(10,9),"w":112.0,"d":42.0,"h":21.0,"kind":"table","c":Color("705343")},
        {"at":g.tile(5,4),"w":49.0,"d":23.0,"h":35.0,"kind":"shelf","c":Color("654b44")},
        {"at":g.tile(8,4),"w":49.0,"d":23.0,"h":35.0,"kind":"shelf","c":Color("684d44")},
        {"at":g.tile(11,4),"w":49.0,"d":23.0,"h":35.0,"kind":"shelf","c":Color("654b44")},
        {"at":g.tile(14,4),"w":49.0,"d":23.0,"h":35.0,"kind":"shelf","c":Color("684d44")},
        {"at":g.tile(39,5),"w":105.0,"d":37.0,"h":23.0,"kind":"butcher","c":Color("617076")},
        {"at":g.tile(47,6),"w":66.0,"d":36.0,"h":24.0,"kind":"butcher","c":Color("65747a")},
        {"at":g.tile(39,11),"w":82.0,"d":33.0,"h":22.0,"kind":"table","c":Color("77675d")},
        {"at":g.tile(5,22),"w":85.0,"d":74.0,"h":19.0,"kind":"bed","c":Color("6e557f")},
        {"at":g.tile(14,22),"w":64.0,"d":45.0,"h":30.0,"kind":"table","c":Color("664955")},
        {"at":g.tile(7,30),"w":75.0,"d":28.0,"h":20.0,"kind":"table","c":Color("73515d")},
        {"at":g.tile(38,27),"w":73.0,"d":36.0,"h":24.0,"kind":"table","c":Color("6c6772")},
        {"at":g.tile(49,29),"w":55.0,"d":48.0,"h":37.0,"kind":"table","c":Color("545965")},
        {"at":g.tile(44,27),"w":53.0,"d":20.0,"h":45.0,"kind":"mirror","c":Color("7b5f6f")},
        {"at":g.tile(26,29),"w":62.0,"d":36.0,"h":31.0,"kind":"altar","c":Color("876c66")},
        # Vestibulo (quarto inicial): mesa da carta e aparador do vaso.
        {"at":g.tile(22,32),"w":44.0,"d":34.0,"h":19.0,"kind":"table","c":Color("6b4f47")},
        {"at":g.tile(32,33),"w":34.0,"d":34.0,"h":15.0,"kind":"table","c":Color("5d4650")}
    ]
    _load_render_cache()

func _load_render_cache() -> void:
    var path: String = "res://assets/render_cache/cache.json"
    if not FileAccess.file_exists(path):
        push_warning("Sem cache: renderizador usara a geometria original.")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        push_warning("Cache invalido: renderizador usara a geometria original.")
        return
    var f: Dictionary = parsed["floor"]
    floor_texture = load(str(f["path"])) as Texture2D
    floor_origin = Vector2(float(f["x"]), float(f["y"]))
    for b in parsed["bands"]:
        var tex: Texture2D = load(str(b["path"])) as Texture2D
        if tex == null:
            continue
        wall_bands.append({"tex":tex,
            "offset":Vector2(float(b["x"]),float(b["y"])),
            "size":Vector2(float(b["w"]),float(b["h"])),
            "z":float(b["z"])})

func project(world: Vector2) -> Vector2:
    return ORIGIN + Vector2((world.x - world.y)*SKEW_X, (world.x + world.y)*SKEW_Y)

func unproject(screen_global: Vector2) -> Vector2:
    var p: Vector2 = screen_global - ORIGIN
    return Vector2((p.x/SKEW_X + p.y/SKEW_Y)*0.5, (p.y/SKEW_Y - p.x/SKEW_X)*0.5)

func screen(world: Vector2) -> Vector2:
    return project(world) - g.camera

func max_scroll() -> Vector2:
    return Vector2(ORIGIN.x + ManorMap.W*TS*SKEW_X + 34.0 - VIEW_WIDTH,
        ORIGIN.y + (ManorMap.W + ManorMap.H)*TS*SKEW_Y + 50.0 - VIEW_HEIGHT)

func _onscreen(pt: Vector2, margin: float = 100.0) -> bool:
    return pt.x > -margin and pt.x < VIEW_WIDTH + margin and pt.y > -margin and pt.y < VIEW_HEIGHT + margin

func poly(points: Array, color: Color) -> void:
    cv.draw_colored_polygon(PackedVector2Array(points), color)

func _diamond(x: int, y: int, color: Color) -> void:
    var ul: Vector2 = screen(Vector2(x*TS, y*TS))
    var ur: Vector2 = screen(Vector2((x+1)*TS, y*TS))
    var lr: Vector2 = screen(Vector2((x+1)*TS, (y+1)*TS))
    var ll: Vector2 = screen(Vector2(x*TS, (y+1)*TS))
    poly([ul, ur, lr, ll], color)
    cv.draw_line(ul,ur,Color(0.025,0.04,0.065,0.21),1.0)
    cv.draw_line(ur,lr,Color(0.025,0.04,0.065,0.21),1.0)

func _box(at: Vector2, width_world: float, depth_world: float, height: float, col: Color, opacity: float = 1.0) -> void:
    var a: Vector2 = screen(at + Vector2(-width_world*0.5,-depth_world*0.5))
    var b: Vector2 = screen(at + Vector2(width_world*0.5,-depth_world*0.5))
    var c: Vector2 = screen(at + Vector2(width_world*0.5,depth_world*0.5))
    var d: Vector2 = screen(at + Vector2(-width_world*0.5,depth_world*0.5))
    var lift: Vector2 = Vector2(0,-height)
    var front_left: Color = col.darkened(0.22)
    var front_right: Color = col.darkened(0.38)
    front_left.a = opacity
    front_right.a = opacity
    var cap: Color = col.lightened(0.14)
    cap.a = opacity
    poly([d,c,c+lift,d+lift],front_left)
    poly([b,c,c+lift,b+lift],front_right)
    poly([a+lift,b+lift,c+lift,d+lift],cap)
    cv.draw_line(d+lift,c+lift,Color(0.95,0.85,0.79,0.35*opacity),1.2)
    cv.draw_line(b+lift,c+lift,Color(0.05,0.04,0.09,0.45*opacity),1.2)

func _wall(x: int,y: int) -> void:
    var pt: Vector2 = g.tile(x,y)
    # Fachadas sempre opacas: nada fica translucido ao se aproximar.
    var col: Color = Color("344051") if ((x*3+y*5)%7 > 1) else Color("3a4755")
    _box(pt,32.0,32.0,WALL_HEIGHT,col)
    if (x*5+y*7)%13 == 0:
        var s: Vector2 = screen(pt)-Vector2(0,WALL_HEIGHT+10)
        cv.draw_line(s-Vector2(6,0),s+Vector2(7,2),Color(0.6,0.63,0.69,.14),1.0)

func _floor() -> void:
    cv.draw_rect(Rect2(0,0,VIEW_WIDTH,VIEW_HEIGHT),Color("080d17"))
    # As quatro alas recebem ladrilhos diferentes; a geometria base continua a mesma.
    for y in range(ManorMap.H):
        for x in range(ManorMap.W):
            var pt: Vector2 = screen(g.tile(x,y))
            if not _onscreen(pt,55.0):
                continue
            if g.map.is_wall_cell(x,y):
                _diamond(x,y,Color("101925"))
            else:
                var floor_col: Color = Color("2a2d3d")
                for room in g.map.rooms:
                    if x >= int(room["x"]) and x < int(room["x"])+int(room["w"]) and y >= int(room["y"]) and y < int(room["y"])+int(room["h"]):
                        floor_col = room["shade"]
                        break
                if (x*19+y*11)%8 == 0:
                    floor_col = floor_col.lightened(0.065)
                _diamond(x,y,floor_col)
    # Tapete central e saguão com marcas do ritual, sempre no plano do piso.
    for n in range(13,27):
        var rug: Vector2 = g.tile(26,n)
        var p: Vector2 = screen(rug)
        if _onscreen(p):
            poly([p+Vector2(0,-15),p+Vector2(30,0),p+Vector2(0,15),p+Vector2(-30,0)],Color("503543"))
            cv.draw_line(p-Vector2(21,0),p+Vector2(21,0),Color("7b5262"),1.0)
    _ritual_circle()

func _cached_floor_details() -> void:
    # O tapete e estatico e ja esta no cache. O ritual deve continuar animado.
    _ritual_circle()

func _ritual_circle() -> void:
    var altar_pt: Vector2 = screen(g.tile(26,29))
    if not _onscreen(altar_pt):
        return
    var glow: float = float(g.collected_count())/3.0
    var ink: Color = Color("6d3443").lerp(Color("e36a8c"),glow*0.7)
    cv.draw_arc(altar_pt,45.0,0,TAU,60,Color("9b7881"),2.3)
    # Pentagrama no piso; acende conforme os fragmentos chegam.
    var star: Array = []
    for k in range(5):
        var ang: float = -PI*0.5 + TAU*float(k)/5.0
        star.append(altar_pt+Vector2(cos(ang)*43.0,sin(ang)*43.0))
    for k in range(5):
        cv.draw_line(star[k],star[(k+2)%5],ink,1.6)
    for k in range(5):
        # Velas nas pontas.
        cv.draw_line(star[k],star[k]+Vector2(0,-7),Color("cdbfae"),2.4)
        var flick: float = 1.6+0.5*sin(g.real_time*9.0+float(k)*2.1)
        cv.draw_circle(star[k]+Vector2(0,-9),flick,Color(1.0,.72,.35,.85))
    if g.ritual_running:
        cv.draw_arc(altar_pt,45.0+4.0*sin(g.time_passed*4),0,TAU,60,Color("ebb1d6"),3.0)

func _floor_matrix(at_screen: Vector2, rotation: float = 0.0, scale: float = 1.0) -> void:
    # Tudo desenhado depois disto fica "deitado" no plano do piso isometrico.
    cv.draw_set_transform_matrix(Transform2D(Vector2(SKEW_X,SKEW_Y)*scale,Vector2(-SKEW_X,SKEW_Y)*scale,at_screen)*Transform2D(rotation,Vector2.ZERO))

func _decals() -> void:
    # Marcas de arrasto: cada uma delas foi puxada pelo chao ate o altar.
    for trail in g.drag_marks:
        var pts: PackedVector2Array = PackedVector2Array()
        var side: PackedVector2Array = PackedVector2Array()
        for w in trail:
            pts.append(screen(w))
            side.append(screen(w+Vector2(7,-4)))
        cv.draw_polyline(pts,Color(0.20,0.02,0.05,0.50),7.5)
        cv.draw_polyline(side,Color(0.30,0.03,0.07,0.40),2.2)
    # Maos ensanguentadas de quem tentou se segurar.
    for h in g.handprints:
        var hp: Vector2 = screen(h["at"])
        if not _onscreen(hp,30.0):
            continue
        _floor_matrix(hp,float(h["rot"]))
        var ink: Color = Color(0.34,0.03,0.08,0.72)
        cv.draw_circle(Vector2.ZERO,4.2,ink)
        for fx in [-3.6,-1.2,1.2,3.6]:
            cv.draw_line(Vector2(fx,-3.0),Vector2(fx*1.35,-10.5+absf(fx)*0.6),ink,1.7)
        cv.draw_line(Vector2(-4.0,0.5),Vector2(-8.5,-2.5),ink,1.9)
        cv.draw_line(Vector2(0,4.0),Vector2(0.8,17.0),Color(0.34,0.03,0.08,0.35),3.0)
    # Recados escritos com o dedo no assoalho.
    for w in g.floor_writings:
        var wp: Vector2 = screen(w["at"])
        if not _onscreen(wp,320.0):
            continue
        _floor_matrix(wp,float(w.get("rot",0.0)),0.92)
        cv.draw_string(ThemeDB.fallback_font,Vector2.ZERO,str(w["text"]),HORIZONTAL_ALIGNMENT_LEFT,-1,int(w.get("size",15)),Color(0.44,0.04,0.09,0.82))
    cv.draw_set_transform_matrix(Transform2D.IDENTITY)

func _shadow_reach() -> void:
    ## Enquanto a luz a segura, a sombra da Ygona rasteja pelo chao ate a jogadora.
    if not g.monster_present() or g.freeze_time <= 0.05:
        return
    var a: Vector2 = g.draw_monster
    var b: Vector2 = g.draw_player
    var dist: float = a.distance_to(b)
    if dist < 1.0:
        return
    var length: float = dist*0.92*clampf(g.freeze_time/g.shadow_seconds(dist),0.0,1.0)
    var dir: Vector2 = (b-a)/dist
    var side: Vector2 = dir.orthogonal()
    var ink: Color = Color(0,0,0,0.66)
    for k in range(5):
        var off: float = (float(k)-2.0)*9.0
        var pts: PackedVector2Array = PackedVector2Array()
        var n: int = 11
        for i in range(n+1):
            var f: float = float(i)/float(n)
            pts.append(screen(a+dir*(length*f)+side*(off*(1.0-f*0.65)+sin(f*9.0+g.real_time*3.0+float(k)*1.7)*5.5*f)))
        cv.draw_polyline(pts,ink,3.4-0.5*absf(float(k)-2.0))
        var d2: Vector2 = (pts[n]-pts[n-1]).normalized()
        for r in [-0.55,0.0,0.55]:
            cv.draw_line(pts[n],pts[n]+d2.rotated(r)*8.0,ink,1.5)

func _hanged(h: Dictionary) -> void:
    ## Uma das tres, embrulhada no lencol e pendurada pelo pescoco.
    var p: Vector2 = screen(h["at"])
    var lit: bool = g.is_illuminated(h["at"])
    var idx: float = float(h["idx"])
    var t: float = g.real_time
    var near: bool = g.draw_player.distance_to(h["at"]) < 150.0
    cv.draw_set_transform(p,0.0,Vector2(1.0,0.5))
    cv.draw_circle(Vector2.ZERO,13.0,Color(0,0,0,0.4))
    cv.draw_circle(Vector2(2,1),8.0,Color(0.30,0.02,0.07,0.8))
    # Sob a luz ela balanca mais, como se tivesse acabado de se mexer.
    var sway: float = sin(t*0.8+idx*2.0)*(0.035+(0.07 if lit else 0.0)) + (sin(t*23.0)*0.012 if near and not lit else 0.0)
    cv.draw_set_transform(p+Vector2(0,-152),sway,Vector2.ONE)
    var cloth: Color = Color("9c9488")
    cv.draw_line(Vector2(0,-40),Vector2(0,62),Color("6b5d4a"),1.7)
    poly([Vector2(-9,68),Vector2(9,68),Vector2(13,88),Vector2(10,114),Vector2(5,132),Vector2(-5,132),Vector2(-10,114),Vector2(-13,88)],cloth)
    poly([Vector2(2,68),Vector2(9,68),Vector2(13,88),Vector2(10,114),Vector2(5,132),Vector2(2,132)],cloth.darkened(0.22))
    # Cabeca tombada sobre o no.
    cv.draw_circle(Vector2(2.5,66),8.2,cloth.lightened(0.06))
    cv.draw_line(Vector2(-8,75),Vector2(9,76),Color("6b5d4a"),2.0)
    # O peito do lencol empapado, exatamente onde ela cortou.
    poly([Vector2(-9,86),Vector2(9,86),Vector2(6,101),Vector2(0,106),Vector2(-6,101)],Color("4a0b17"))
    for dx in [-5.0,-1.0,4.0]:
        cv.draw_line(Vector2(dx,101),Vector2(dx,112.0+fposmod(dx*5.3+idx*3.0,13.0)),Color("3a0812"),1.6)
    # Cordas apertando o lencol e os pes para fora.
    cv.draw_line(Vector2(-11,96),Vector2(11,98),Color("6b5d4a"),1.2)
    cv.draw_line(Vector2(-9,118),Vector2(9,119),Color("6b5d4a"),1.2)
    var twitch: float = sin(t*31.0)*1.2 if (lit and fposmod(t+idx,3.1) < 0.35) else 0.0
    cv.draw_line(Vector2(-3,131),Vector2(-3.5+twitch,141),Color("7d7478"),2.6)
    cv.draw_line(Vector2(3,131),Vector2(3.5-twitch,142),Color("7d7478"),2.6)
    if near:
        # De perto, da para ver que o lencol afundou onde ficam os olhos. Abertos.
        cv.draw_circle(Vector2(-0.5,65),1.7,Color("0a0508"))
        cv.draw_circle(Vector2(5.5,66),1.7,Color("0a0508"))
    var drop: float = fposmod(t*0.55+idx*0.37,1.0)
    cv.draw_circle(Vector2(0,142+drop*drop*12.0),1.3,Color(0.42,0.04,0.09,1.0-drop))
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _mannequin(m: Dictionary) -> void:
    ## Manequim de costura da oficina. A cabeca sem rosto acompanha a jogadora;
    ## depois que ele sai do lugar, um braco passa a apontar para ela.
    var p: Vector2 = screen(m["at"])
    var to: Vector2 = screen(g.draw_player)-p
    var lean: float = clampf(to.x/110.0,-1.0,1.0)*3.2
    poly([p+Vector2(-13,0),p+Vector2(0,6),p+Vector2(13,0),p+Vector2(0,-6)],Color(0,0,0,.42))
    for leg in [Vector2(-9,2),Vector2(9,2),Vector2(0,5)]:
        cv.draw_line(p+Vector2(0,-6),p+leg,Color("3b3038"),2.0)
    cv.draw_line(p+Vector2(0,-6),p+Vector2(0,-24),Color("3b3038"),2.6)
    var cloth: Color = Color("b8ab9a")
    poly([p+Vector2(-8,-22),p+Vector2(-12,-40),p+Vector2(-10,-53),p+Vector2(10,-53),p+Vector2(12,-40),p+Vector2(8,-22)],cloth)
    poly([p+Vector2(1,-22),p+Vector2(1,-53),p+Vector2(10,-53),p+Vector2(12,-40),p+Vector2(8,-22)],cloth.darkened(0.18))
    cv.draw_line(p+Vector2(0,-52),p+Vector2(0,-23),Color("6f6557"),1.0)
    # O mesmo corte no peito, costurado com linha grossa.
    cv.draw_line(p+Vector2(-8,-45),p+Vector2(8,-45),Color("5c0f1d"),2.0)
    for sx in [-6.0,-2.0,2.0,6.0]:
        cv.draw_line(p+Vector2(sx-1,-48),p+Vector2(sx+1,-42),Color("2a2026"),1.0)
    if bool(m.get("moved",false)) and to.length() > 1.0:
        var sh: Vector2 = p+Vector2(signf(to.x)*10.0,-50)
        var tip: Vector2 = sh+to.normalized()*19.0
        cv.draw_line(sh,tip,cloth.darkened(0.1),3.2)
        cv.draw_line(tip,tip+to.normalized()*5.0,Color("6f6557"),1.4)
    cv.draw_line(p+Vector2(0,-53),p+Vector2(lean*0.5,-58),Color("8d8172"),3.4)
    cv.draw_circle(p+Vector2(lean,-64),7.2,Color("c9bdac"))
    cv.draw_circle(p+Vector2(lean+1.5,-63),6.0,Color("b3a696"))
    if g.draw_player.distance_to(m["at"]) < 135.0:
        # Nenhum rosto. So duas marcas de dedo afundadas onde ficariam os olhos.
        cv.draw_circle(p+Vector2(lean-2.6+lean*0.4,-65),1.3,Color("241a20"))
        cv.draw_circle(p+Vector2(lean+2.6+lean*0.4,-65),1.3,Color("241a20"))

func _blood_trail() -> void:
    # Por onde ela passou fica um rastro escuro, que seca aos poucos.
    for drop in g.blood_trail:
        var p: Vector2 = screen(drop["at"])
        if not _onscreen(p,30.0):
            continue
        var a: float = clampf(float(drop["ttl"])/8.0,0.0,1.0)*0.62
        var r: float = float(drop["r"])
        cv.draw_set_transform(p,0.0,Vector2(1.0,0.5))
        cv.draw_circle(Vector2.ZERO,r,Color(0.30,0.02,0.07,a))
        cv.draw_circle(Vector2(r*0.9,r*0.5),r*0.38,Color(0.24,0.01,0.05,a))
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _floor_light() -> void:
    if not g.light_active() or g.in_hiding:
        return
    var half: float = g.light_half_angle()
    var begin: Vector2 = screen(g.draw_player)
    var rays: Array = [begin]
    var rays2: Array = [begin]
    var count: int = 28
    var r: float = g.light_range()
    for n in range(count+1):
        var a: float = g.look.angle()+lerpf(-half,half,float(n)/count)
        var beam_edge: Vector2 = screen(g.map.ray_end(g.draw_player,a,r))
        rays.append(beam_edge)
        # Reutiliza as amostras centrais do cone externo. Corta pela metade
        # o numero de testes de colisao por quadro sem deixar a luz atravessar parede.
        if n >= 7 and n <= 21:
            rays2.append(begin.lerp(beam_edge,0.84))
    poly(rays,Color(0.60,0.38,0.95,.23) if g.ghost_mode else Color(1.0,.83,.52,.19))
    poly(rays2,Color(.72,.56,1.0,.18) if g.ghost_mode else Color(1.0,.95,.69,.17))
    cv.draw_circle(begin,18,Color(.63,.37,.94,.10) if g.ghost_mode else Color(.98,.88,.62,.08))

func _object_should_draw(item: Dictionary) -> bool:
    var kind: String = item["kind"]
    if kind == "fragment":
        var idx: int = item["idx"]
        return not g.fragment_owned[idx] and (idx != 0 or g.library_open) and (idx != 1 or g.musicbox_open) and (idx != 2 or g.mirror_open)
    if kind == "key":
        return not g.key_owned
    if kind == "seal":
        return not g.mirror_open
    if kind == "clue":
        return g.ghost_mode and g.light_on and g.is_illuminated(item["at"])
    if kind == "book":
        return not g.library_open
    if kind == "door":
        return not g.foyer_door_open
    if kind == "lens":
        return not g.ghost_unlocked
    return kind != "exit" and kind != "altar"

func gel(c: CanvasItem, at: Vector2, r: float, wobble: float = 0.0, alpha: float = 1.0) -> void:
    ## Protese de silicone: cupula de gel translucida sobre uma base achatada.
    ## "at" e o centro da base; "wobble" balanca o topo (gelatina).
    c.draw_colored_polygon(PackedVector2Array([at+Vector2(-r*1.15,1),at+Vector2(0,r*0.42),at+Vector2(r*1.15,1),at+Vector2(0,-r*0.2)]),Color(0.26,0.03,0.07,0.75*alpha))
    var pts: PackedVector2Array = PackedVector2Array()
    var n: int = 14
    for i in range(n+1):
        var a: float = PI + PI*float(i)/float(n)
        pts.append(at+Vector2(cos(a)*r - sin(a)*wobble, sin(a)*r*0.80))
    for i in range(1,n):
        var b: float = PI*float(i)/float(n)
        pts.append(at+Vector2(cos(b)*r, sin(b)*r*0.26))
    c.draw_colored_polygon(pts,Color(0.95,0.79,0.83,0.90*alpha))
    var rim: PackedVector2Array = pts.duplicate()
    rim.append(pts[0])
    c.draw_polyline(rim,Color(1.0,0.93,0.95,0.85*alpha),1.2)
    # Miolo mais denso e brilho molhado.
    c.draw_circle(at+Vector2(wobble*0.4,-r*0.26),r*0.46,Color(0.86,0.60,0.68,0.35*alpha))
    c.draw_circle(at+Vector2(-r*0.34+wobble*0.6,-r*0.46),r*0.17,Color(1,1,1,0.80*alpha))

func _scene_object(obj: Dictionary) -> void:
    var p: Vector2 = screen(obj["at"])
    var kind: String = obj["kind"]
    if kind == "fragment":
        # Os "fragmentos" sao os silicones das sacrificadas: tremem e pulsam.
        var idx: int = int(obj["idx"])
        var v: float = g.fragment_pulse(idx)
        cv.draw_circle(p+Vector2(0,-8),17.0+7.0*v,Color(1.0,.70,.80,.08+.14*v))
        gel(cv,p+Vector2(0,-2),11.0,sin(g.real_time*5.0+float(idx)*1.7)*(0.7+1.6*v))
    elif kind == "key":
        cv.draw_circle(p+Vector2(-7,-14),7,Color("e1bc79"),false,2.5)
        cv.draw_line(p+Vector2(-1,-13),p+Vector2(12,-1),Color("e1bc79"),3.0)
    elif kind == "book":
        _box(obj["at"],20.0,14.0,7.0,Color("7d5261") if int(obj["number"]) % 2 else Color("4e7982"))
        _text(p+Vector2(-6,-18),str(obj["number"]),11,Color("f6dfbb"))
    elif kind == "seal":
        cv.draw_circle(p+Vector2(0,-8),16.0,Color("b19be8") if obj["number"] in g.mirror_sequence else Color("72637c"))
        cv.draw_circle(p+Vector2(0,-8),11.0,Color("32283b"))
        _text(p+Vector2(-4,-3),str(obj["number"]),12,Color("f1e0ff"))
    elif kind == "box":
        _box(obj["at"],32.0,25.0,18.0,Color("ae8465"))
        cv.draw_circle(p+Vector2(0,-24),4.0,Color("f6d8a1"))
    elif kind == "letter":
        # Carta em destaque sobre a mesa: o cenario aponta o que ler.
        var lp: Vector2 = p+Vector2(0,-21)
        poly([lp+Vector2(-11,0),lp+Vector2(0,-6),lp+Vector2(11,0),lp+Vector2(0,6)],Color("eadfc4") if not g.letter_read else Color("a59c8a"))
        cv.draw_line(lp+Vector2(-4,0),lp+Vector2(4,0),Color("7b2f3d"),1.4)
        if not g.letter_read:
            cv.draw_circle(lp,13.0+2.5*sin(g.real_time*3.0),Color(1,.93,.72,.13))
    elif kind == "note":
        var np: Vector2 = p+Vector2(0,-2)
        poly([np+Vector2(-8,0),np+Vector2(0,-4),np+Vector2(8,0),np+Vector2(0,4)],Color("d8ceb4") if not g.note_read else Color("94907f"))
        cv.draw_line(np+Vector2(-3,0),np+Vector2(3,0),Color("5a5160"),1.0)
    elif kind == "vase":
        var vp: Vector2 = p+Vector2(0,-15)
        poly([vp+Vector2(-7,-2),vp+Vector2(7,-2),vp+Vector2(5,-15),vp+Vector2(-5,-15)],Color("7f8fa6"))
        cv.draw_line(vp+Vector2(-6,-9),vp+Vector2(6,-9),Color("b9c6d8"),1.2)
        for fx in [-6,0,6]:
            cv.draw_line(vp+Vector2(fx*0.4,-15),vp+Vector2(fx,-27),Color("4c5b3c"),1.6)
            cv.draw_circle(vp+Vector2(fx,-28),3.0,Color("7a3148"))
    elif kind == "door":
        _box(obj["at"],32.0,32.0,WALL_HEIGHT,Color("6a4a3c"))
        cv.draw_line(p+Vector2(-15,-28),p+Vector2(-15,-6),Color("3b2a25"),1.5)
        cv.draw_circle(p+Vector2(-6,-16),2.6,Color("e1bc79") if g.foyer_key_owned else Color("8d7a5c"))
    elif kind == "lens":
        var la: float = 0.7+0.3*sin(g.real_time*3.4)
        cv.draw_circle(p+Vector2(0,-12),15.0,Color(.62,.40,.98,.16*la))
        cv.draw_arc(p+Vector2(0,-12),7.0,0,TAU,24,Color(.80,.66,1.0,la),2.4)
        cv.draw_circle(p+Vector2(0,-12),3.0,Color("efe1ff"))
    elif kind == "clue":
        cv.draw_circle(p+Vector2(0,-19),19,Color(.64,.42,.96,.26))
        cv.draw_arc(p+Vector2(0,-19),16,0,TAU,32,Color("bca1ff"),2.0)
        _text(p+Vector2(-7,-13),"?",17,Color("f5deff"))

func _furniture(obj: Dictionary) -> void:
    _box(obj["at"],obj["w"],obj["d"],obj["h"],obj["c"])
    var p: Vector2 = screen(obj["at"])
    var kind: String = obj["kind"]
    if kind == "shelf":
        for i in range(3):
            cv.draw_line(p+Vector2(-17+i*10,-obj["h"]-5),p+Vector2(-15+i*10,-obj["h"]+10),Color("a78e73"),3.0)
    elif kind == "bed":
        # Travesseiro, e alguma coisa respirando devagar debaixo do lencol.
        var bt: Vector2 = p+Vector2(0,-obj["h"])
        poly([bt+Vector2(-34,-12),bt+Vector2(-16,-21),bt+Vector2(-2,-14),bt+Vector2(-20,-5)],Color("c3b5c3"))
        var breath: float = 1.0+0.13*sin(g.real_time*1.3)
        cv.draw_set_transform(bt+Vector2(8,-1.0-2.0*breath),0.46,Vector2(1.0,0.55*breath))
        cv.draw_circle(Vector2(2,0),13.0,Color("5b4670"))
        cv.draw_circle(Vector2(0,-2),12.0,Color("7d6590"))
        cv.draw_circle(Vector2(18,-1),8.0,Color("7d6590"))
        cv.draw_circle(Vector2(-17,-2),6.5,Color("86709a"))
        cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
        poly([bt+Vector2(2,3),bt+Vector2(14,1),bt+Vector2(20,9),bt+Vector2(8,13)],Color(0.30,0.03,0.08,0.75))
    elif kind == "butcher":
        # Bancada da cozinha: mancha, cutelo cravado e um resto que ninguem recolheu.
        var kt: Vector2 = p+Vector2(0,-obj["h"])
        poly([kt+Vector2(-22,-5),kt+Vector2(-6,-10),kt+Vector2(12,-2),kt+Vector2(-2,6)],Color("3d0a14"))
        poly([kt+Vector2(8,-4),kt+Vector2(16,-7),kt+Vector2(24,-1),kt+Vector2(14,4)],Color("5c1420"))
        cv.draw_circle(kt+Vector2(16,-3),3.0,Color("7a2231"))
        cv.draw_line(kt+Vector2(-14,-6),kt+Vector2(-9,-21),Color("4a3527"),3.0)
        poly([kt+Vector2(-15,-6),kt+Vector2(-12,-15),kt+Vector2(-23,-13),kt+Vector2(-25,-5)],Color("aab3ba"))
        cv.draw_line(kt+Vector2(-25,-5),kt+Vector2(-15,-6),Color("5c0f1d"),1.4)
        # Ganchos pendurados do teto, um deles ainda pingando.
        for hx in [-30.0, 30.0]:
            var hook: Vector2 = kt+Vector2(hx,-46+sin(g.real_time*1.1+hx)*1.5)
            cv.draw_line(hook+Vector2(0,-60),hook,Color("56515c"),1.2)
            cv.draw_arc(hook+Vector2(0,4),4.0,-PI*0.5,PI,10,Color("8b8791"),1.6)
        var drop: float = fposmod(g.real_time*0.7,1.0)
        cv.draw_circle(kt+Vector2(-30,-36+drop*30.0),1.3,Color(0.42,0.04,0.09,1.0-drop))
    elif kind == "mirror":
        cv.draw_line(p+Vector2(-8,-obj["h"]-19),p+Vector2(8,-obj["h"]-8),Color("bed0d5"),4.0)
        cv.draw_line(p+Vector2(0,-obj["h"]-20),p+Vector2(9,-obj["h"]-32),Color("a38abd"),3.0)
    elif kind == "altar":
        # Tampo empoçado de sangue velho, que escorre pelas duas fachadas.
        var lift: Vector2 = Vector2(0,-obj["h"])
        var top: Vector2 = p+lift
        var hw: float = float(obj["w"])*0.5
        var hd: float = float(obj["d"])*0.5
        var left: Vector2 = screen(obj["at"]+Vector2(-hw,hd))+lift
        var front: Vector2 = screen(obj["at"]+Vector2(hw,hd))+lift
        var right: Vector2 = screen(obj["at"]+Vector2(hw,-hd))+lift
        poly([top+Vector2(-24,-4),top+Vector2(-4,-10),top+Vector2(20,1),top+Vector2(8,10),top+Vector2(-9,5)],Color("3d0a14"))
        poly([top+Vector2(-10,-3),top+Vector2(2,-6),top+Vector2(10,1),top+Vector2(0,5)],Color("5c0f1d"))
        for f in [0.16,0.40,0.66,0.88]:
            var s1: Vector2 = left.lerp(front,f)
            cv.draw_line(s1,s1+Vector2(0,7.0+fposmod(f*37.0,1.0)*15.0),Color("4a0b17"),2.2)
        for f in [0.28,0.62]:
            var s2: Vector2 = right.lerp(front,f)
            cv.draw_line(s2,s2+Vector2(0,6.0+fposmod(f*53.0,1.0)*13.0),Color("3a0812"),2.0)
        # Argolas onde elas foram amarradas.
        cv.draw_arc(left+Vector2(6,9),3.0,0,TAU,10,Color("8b8791"),1.3)
        cv.draw_arc(right+Vector2(-6,9),3.0,0,TAU,10,Color("8b8791"),1.3)
        if g.ritual_running or g.monster_banished:
            for i in range(3):
                gel(cv,top+Vector2(-18+i*18,-8+i*8),6.0,sin(g.real_time*7.0+float(i)*2.0)*0.8)

func _hide_spot(at: Vector2) -> void:
    _box(at,32.0,30.0,49.0,Color("676175"))
    var p: Vector2 = screen(at)
    cv.draw_line(p+Vector2(-5,-46),p+Vector2(-5,-12),Color("b6a8b1"),1.3)
    cv.draw_circle(p+Vector2(5,-24),2.4,Color("d7c19c"))

func _portal(at: Vector2) -> void:
    var p: Vector2 = screen(at)
    if not g.light_on or not g.ghost_mode:
        return
    if not g.is_illuminated(at) and g.player.distance_to(at)>49.0:
        return
    var a: float = 0.72+0.27*sin(g.time_passed*4.0)
    cv.draw_circle(p+Vector2(0,-17),21,Color(.51,.25,.93,.16*a))
    cv.draw_arc(p+Vector2(0,-17),18.0,0,TAU,40,Color(.77,.60,1.0,a),3.1)
    cv.draw_line(p+Vector2(-7,-25),p+Vector2(7,-10),Color("dcc2ff"),2.0)

func _battery(at: Vector2) -> void:
    var p: Vector2 = screen(at)
    cv.draw_circle(p+Vector2(0,-11),13.0,Color(.30,1.0,.76,.14))
    cv.draw_rect(Rect2(p+Vector2(-11,-17),Vector2(21,14)),Color("6bdfb1"))
    cv.draw_rect(Rect2(p+Vector2(10,-13),Vector2(3,6)),Color("f2e9bd"))
    cv.draw_line(p+Vector2(-3,-11),p+Vector2(4,-11),Color("205c54"),2.0)

func _character() -> void:
    var center: Vector2 = screen(g.draw_player)
    if g.in_hiding:
        cv.draw_circle(center + Vector2(0,-9),7,Color("b9a9df"))
        return
    # A protagonista (adulta) e desenhada em escala maior, para o gesto ficar legivel.
    cv.draw_set_transform(center, 0.0, Vector2(1.35,1.35))
    var p: Vector2 = Vector2.ZERO
    var rate: float = 14.0 if g.running else 8.0
    var step: float = sin(g.time_passed*rate) * (1.9 if g.moving else 0.0)
    var bob: float = step + sin(g.real_time*2.1)*0.4          # passo + respiracao
    var skin: Color = Color("bb806b")
    var skin_shade: Color = Color("96604f")
    var cloth: Color = Color("824b6e")
    # Sombra e cabelo comprido caindo pelas costas.
    poly([p+Vector2(-18,-1),p+Vector2(0,8),p+Vector2(18,-1),p+Vector2(0,-10)],Color(0,0,0,.42))
    poly([p+Vector2(-13,-52+bob),p+Vector2(13,-52+bob),p+Vector2(17,-25+bob),p+Vector2(-17,-25+bob)],Color("211627"))
    # Pernas e sapatos.
    cv.draw_line(p+Vector2(-7,-12),p+Vector2(-7,-1+step),Color("23243d"),6.4)
    cv.draw_line(p+Vector2(7,-12),p+Vector2(7,-1-step),Color("23243d"),6.4)
    cv.draw_line(p+Vector2(-7,0),p+Vector2(-11,3),Color("101422"),5.0)
    cv.draw_line(p+Vector2(7,0),p+Vector2(11,3),Color("101422"),5.0)
    # Saia, cintura fina e blusa: silhueta em ampulheta.
    poly([p+Vector2(-18,-10),p+Vector2(-9,-23+bob),p+Vector2(9,-23+bob),p+Vector2(18,-10)],Color("4a3c62"))
    poly([p+Vector2(-9,-22+bob),p+Vector2(-15,-32+bob),p+Vector2(-11,-40+bob),p+Vector2(11,-40+bob),p+Vector2(15,-32+bob),p+Vector2(9,-22+bob)],Color("6e4668"))
    cv.draw_line(p+Vector2(-9,-22.5+bob),p+Vector2(9,-22.5+bob),Color("2f2440"),2.0)
    # Braco esquerdo em repouso.
    cv.draw_line(p+Vector2(-13,-37+bob),p+Vector2(-18,-23+bob),Color("754a60"),6.0)
    cv.draw_circle(p+Vector2(-18,-21+bob),2.9,skin)
    # CINCO MOMENTOS DO GESTO:
    # 0%: lanterna completamente escondida no decote, mao na cintura;
    # 0-25%: a mao alcanca o meio do decote;
    # 25-60%: ela puxa o corpo da lanterna de entre os seios;
    # 60-100%: ergue o braco e mira para a frente.
    # Ao guardar, a animacao se repete em ordem inversa.
    var pose: float = clampf(g.flashlight_pose,0.0,1.0)
    var reach: float = smoothstep(0.0,0.25,pose)
    var extract: float = smoothstep(0.25,0.60,pose)
    var extend: float = smoothstep(0.60,1.0,pose)
    var aim: Vector2 = Vector2((g.look.x-g.look.y)*SKEW_X,(g.look.x+g.look.y)*SKEW_Y).normalized()
    if aim.length_squared()<0.01:
        aim=Vector2.RIGHT
    var chest: Vector2 = p + Vector2(0,-30+bob)
    var cleft: Vector2 = chest + Vector2(0,-3)               # onde a lanterna mora
    # Balanco atrasado em relacao ao passo, e os seios se afastam um pouco
    # enquanto a lanterna passa entre eles.
    var sway: float = sin(g.time_passed*rate-1.1) * ((1.5 if g.running else 0.9) if g.moving else 0.0)
    var part: float = sin(clampf((pose-0.10)/0.52,0.0,1.0)*PI) * 1.7
    # Pele do colo, visivel no decote em V profundo.
    poly([chest+Vector2(-9,-10),chest+Vector2(9,-10),chest+Vector2(4,-2),chest+Vector2(0,3),chest+Vector2(-4,-2)],skin)
    # Enquanto e puxada, a haste sobe verticalmente por tras do busto.
    if pose > 0.28 and pose <= 0.60:
        _flashlight(cleft+Vector2(0,1.0),cleft+Vector2(0,-2.0-16.0*extract),false)
    # Busto proeminente: sombra por baixo, pele no alto do decote, tecido e brilho.
    for side in [-1.0, 1.0]:
        var b: Vector2 = chest + Vector2(side*(7.8+part),-1.5+sway)
        cv.draw_circle(b+Vector2(side*1.2,3.8),8.8,Color("4c2a45"))
        cv.draw_circle(b,8.8,skin)
        cv.draw_circle(b+Vector2(side*1.7,2.7),8.8,cloth)
        cv.draw_circle(b+Vector2(side*3.4,0.6),3.1,Color(0.72,0.45,0.62,0.55))
        cv.draw_arc(b+Vector2(side*1.7,2.7),8.8,-PI*0.5-side*1.25-0.55,-PI*0.5-side*1.25+0.55,8,Color("d79dae"),1.3)
    cv.draw_line(cleft+Vector2(0,-3.5),cleft+Vector2(0,5.0+sway*0.5),skin_shade,1.4+part*0.5)
    # Pescoço, rosto, olhos e cabelo.
    cv.draw_line(p+Vector2(0,-43+bob),p+Vector2(0,-39+bob),Color("b77d69"),6)
    cv.draw_circle(p+Vector2(0,-48+bob),12.2,Color("1a1425"))
    cv.draw_circle(p+Vector2(0,-47+bob),9.1,skin)
    poly([p+Vector2(-13,-52+bob),p+Vector2(-7,-62+bob),p+Vector2(6,-62+bob),p+Vector2(13,-52+bob),p+Vector2(5,-56+bob),p+Vector2(-6,-55+bob)],Color("241927"))
    cv.draw_line(p+Vector2(-12,-50+bob),p+Vector2(-15,-34+bob),Color("261a33"),5.0)
    cv.draw_line(p+Vector2(12,-50+bob),p+Vector2(15,-34+bob),Color("261a33"),5.0)
    cv.draw_circle(p+Vector2(-3.3,-47+bob),1.3,Color("eee4dd"))
    cv.draw_circle(p+Vector2(3.3,-47+bob),1.3,Color("eee4dd"))
    cv.draw_line(p+Vector2(-2,-42+bob),p+Vector2(2,-42+bob),Color("8c2f48"),1.5)
    # Braco direito: o ombro, o antebraco e os dedos acompanham o objeto.
    var rest: Vector2 = p+Vector2(18,-21+bob)
    var raised: Vector2 = cleft+Vector2(0,-9.0*extract)
    var ready: Vector2 = cleft+aim*33.0+Vector2(3,-6)
    var hand: Vector2 = rest.lerp(cleft,reach)
    if pose > 0.25:
        hand=cleft.lerp(raised,extract)
    if pose > 0.60:
        hand=raised.lerp(ready,extend)
    var shoulder: Vector2 = p+Vector2(13,-37+bob)
    var elbow: Vector2 = shoulder.lerp(hand,0.51)+Vector2(7,6)
    cv.draw_line(shoulder,elbow,Color("754a60"),7.0)
    cv.draw_line(elbow,hand,Color("c38b78"),5.1)
    # Ja fora do decote, a lanterna segue a mao e aponta para a mira.
    if pose > 0.60:
        _flashlight(hand-aim*3.0,hand+aim*15.0,g.light_on and pose > 0.86)
    cv.draw_circle(hand,3.1,Color("daa18c"))
    # Sem efeito de transformacao nos objetos e HUD desenhados em seguida.
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _flashlight(from: Vector2, to: Vector2, glowing: bool) -> void:
    cv.draw_line(from,to,Color("4b3f5d"),8.3)
    cv.draw_line(from,to,Color("e1bd8c"),5.5)
    var spectral: bool = g.ghost_mode and g.light_on
    cv.draw_circle(to,4.5,Color("b7a1ed") if spectral else Color("fbe4a3"))
    if glowing:
        cv.draw_circle(to,7.8,Color(.72,.52,1,.25) if spectral else Color(1,.94,.62,.25))

func _monster() -> void:
    _ygona(g.draw_monster, g.monster_lit, g.monster_state == "PERSEGUINDO" and not g.monster_lit)

func _ygona(at: Vector2, lit: bool, chasing: bool) -> void:
    ## Ygona: cadaver comprido de vestido rasgado, pescoco quebrado, orbitas
    ## vazias e um sorriso cortado ate as orelhas. Aparicao ficticia e abstrata:
    ## nao reproduz o rosto de nenhuma pessoa real.
    var base: Vector2 = screen(at)
    var t: float = g.real_time
    var bob: float = 0.0 if lit else sin(g.time_passed*6.0)*2.0
    # Tique: a cabeca troca de pose aos trancos. Sob a luz ela nao anda,
    # mas o pescoco continua estalando.
    var tempo: float = 0.75 if lit else 2.1
    var beat: float = floor(t*tempo)
    var tilt: float = (fposmod(sin(beat*12.9898)*43758.5453,1.0)-0.5)*(1.0 if lit else 0.55)
    if fposmod(t*tempo,1.0) < 0.08:
        tilt += randf_range(-0.28,0.28)
    var s: float = 1.24
    var bone: Color = Color("cfc4c6") if lit else Color("8d7f86")
    cv.draw_set_transform(base,0.0,Vector2(s,s))
    var p: Vector2 = Vector2.ZERO
    poly([p+Vector2(-21,1),p+Vector2(0,9),p+Vector2(21,1),p+Vector2(0,-8)],Color(0,0,0,.55))
    # Vestido em farrapos, encharcado na barra.
    poly([p+Vector2(-22,-2),p+Vector2(-15,5),p+Vector2(-9,-3),p+Vector2(-3,6),p+Vector2(4,-2),p+Vector2(10,6),p+Vector2(16,-3),p+Vector2(23,2),p+Vector2(14,-44+bob),p+Vector2(8,-58+bob),p+Vector2(-8,-58+bob),p+Vector2(-14,-44+bob)],Color("0a0910"))
    poly([p+Vector2(-15,5),p+Vector2(-9,-3),p+Vector2(-3,6),p+Vector2(4,-2),p+Vector2(10,6),p+Vector2(13,-9),p+Vector2(1,-17),p+Vector2(-12,-11)],Color("36070f"))
    # Torax aberto: costelas a mostra.
    poly([p+Vector2(-9,-52+bob),p+Vector2(9,-52+bob),p+Vector2(7,-31+bob),p+Vector2(0,-25+bob),p+Vector2(-7,-31+bob)],Color("241622"))
    for i in range(4):
        var ry: float = -48.0+float(i)*5.0+bob
        var rw: float = 7.0-float(i)*0.7
        cv.draw_line(p+Vector2(-rw,ry),p+Vector2(-1.2,ry+1.6),bone.darkened(0.25),1.3)
        cv.draw_line(p+Vector2(rw,ry),p+Vector2(1.2,ry+1.6),bone.darkened(0.25),1.3)
    cv.draw_line(p+Vector2(0,-50+bob),p+Vector2(0,-29+bob),Color("4a0b17"),1.6)
    # Bracos compridos demais; na perseguicao eles se estendem para a jogadora.
    var toward: Vector2 = (screen(g.draw_player)-base).normalized() if chasing else Vector2.ZERO
    for side in [-1.0, 1.0]:
        var sh: Vector2 = p+Vector2(side*12.0,-53+bob)
        var el: Vector2 = p+Vector2(side*20.0,-33+bob)
        var hd: Vector2 = p+Vector2(side*22.0,-9+bob*0.5)
        if chasing:
            var grab: float = 0.75+0.25*sin(t*9.0+side)
            el = sh+toward*15.0+Vector2(side*7.0,5.0)
            hd = sh+toward*(31.0*grab)+Vector2(side*5.0,-2.0)
        cv.draw_line(sh,el,Color("12101a"),5.0)
        cv.draw_line(el,hd,bone,2.6)
        var reach: Vector2 = (hd-el).normalized()
        for f in [-0.55, 0.0, 0.55]:
            var tip: Vector2 = hd+reach.rotated(f)*9.5
            cv.draw_line(hd,tip,bone,1.4)
            cv.draw_line(tip,tip+reach.rotated(f)*2.5,Color("36070f"),1.4)
    # Pescoco quebrado e cabeca pendendo.
    cv.draw_line(p+Vector2(0,-58+bob),p+Vector2(0,-52+bob),bone.darkened(0.2),3.6)
    cv.draw_set_transform(base+Vector2(0,-58+bob)*s,tilt,Vector2(s,s))
    cv.draw_circle(Vector2(0,-9),13.0,Color("0b0810"))
    cv.draw_circle(Vector2(0,-10),8.6,bone)
    poly([Vector2(-8,-7),Vector2(8,-7),Vector2(4.5,3),Vector2(0,5.5),Vector2(-4.5,3)],bone)
    var eyes: Color = Color("c7f3ff") if lit else Color("ff3b6b")
    for side in [-1.0, 1.0]:
        cv.draw_circle(Vector2(side*4.0,-10.5),3.5,Color("050307"))
        cv.draw_circle(Vector2(side*4.0,-10.2),1.1,eyes)
        # Lagrimas pretas.
        cv.draw_line(Vector2(side*4.0,-7.5),Vector2(side*4.6,0.5+sin(t*2.0+side)*1.2),Color("050307"),1.3)
    # Sorriso cortado, com dentes demais.
    cv.draw_polyline(PackedVector2Array([Vector2(-7.5,-6),Vector2(-4.5,-1.5),Vector2(0,-0.3),Vector2(4.5,-1.5),Vector2(7.5,-6)]),Color("070305"),2.6)
    for tx in [-4.5,-2.3,0.0,2.3,4.5]:
        cv.draw_line(Vector2(tx,-1.9+absf(tx)*0.12),Vector2(tx,0.3+absf(tx)*0.05),Color("e6dccf"),0.9)
    # Cabelo escorrido por cima do rosto.
    # (as mechas caem pelos lados; so uma atravessa o rosto, para ele continuar legivel)
    for hx in [-12.0,-9.5,-7.5,1.5,7.5,9.5,12.0]:
        var hl: float = 12.0+fposmod(hx*7.3,13.0)
        cv.draw_line(Vector2(hx*0.85,-21),Vector2(hx+sin(t*1.7+hx)*1.4,hl),Color("0d0912"),1.0 if absf(hx) < 5.0 else 2.2)
    cv.draw_set_transform(base,0.0,Vector2(s,s))
    if lit:
        cv.draw_arc(p+Vector2(0,-40),40,0,TAU,40,Color(.65,.83,1.0,.30),1.6)
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _vulto(v: Dictionary) -> void:
    # Vulto: silhueta que some quando se olha para ela (so com a casa iluminada).
    var p: Vector2 = screen(v["at"])
    var a: float = clampf(minf(float(v["ttl"]),float(v["life"])-float(v["ttl"]))/0.35,0.0,1.0)*0.5
    poly([p+Vector2(-13,0),p+Vector2(-10,-46),p+Vector2(-5,-62),p+Vector2(5,-62),p+Vector2(10,-46),p+Vector2(13,0)],Color(0.02,0.01,0.05,a))
    cv.draw_circle(p+Vector2(0,-64),9.0,Color(0.02,0.01,0.05,a))

func _blob(c: CanvasItem, center: Vector2, rx: float, ry: float, strength: float) -> void:
    # Mancha radial (centro forte, borda zero) sem triangulacao automatica.
    var pts: PackedVector2Array = PackedVector2Array([center])
    var cols: PackedColorArray = PackedColorArray([Color(1,1,1,clampf(strength,0.0,1.0))])
    var idx: PackedInt32Array = PackedInt32Array()
    var n: int = 20
    for i in range(n):
        var a: float = TAU*float(i)/float(n)
        pts.append(center+Vector2(cos(a)*rx,sin(a)*ry))
        cols.append(Color(1,1,1,0))
        idx.append(0)
        idx.append(1+i)
        idx.append(1+(i+1)%n)
    RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(),idx,pts,cols)

func draw_light_mask(c: CanvasItem) -> void:
    ## Mascara de luz (branco = visivel). O shader de escuridao le esta textura.
    c.draw_rect(Rect2(0,0,VIEW_WIDTH,VIEW_HEIGHT),Color.BLACK)
    var hero: Vector2 = screen(g.draw_player)
    var amb: float = g.CFG.AMBIENT_RADIUS
    if g.in_hiding:
        _blob(c,hero+Vector2(0,-20),amb*0.5,amb*0.42,0.8)
    else:
        _blob(c,hero+Vector2(0,-34),amb,amb*0.86,1.0)
    if g.light_active() and not g.in_hiding:
        var r: float = g.light_range()
        var half: float = g.light_half_angle()
        var base: float = g.look.angle()
        var n: int = 30
        var feather: float = 0.11
        var pts: PackedVector2Array = PackedVector2Array([hero])
        var cols: PackedColorArray = PackedColorArray([Color.WHITE])
        var idx: PackedInt32Array = PackedInt32Array()
        var rays: int = n+3
        for i in range(rays):
            var t: float = clampf(float(i-1)/float(n),0.0,1.0)
            var ang: float = base+lerpf(-half,half,t)
            var edge: bool = i == 0 or i == rays-1
            if i == 0:
                ang -= feather
            elif i == rays-1:
                ang += feather
            var dir: Vector2 = Vector2.from_angle(ang)
            var hit_at: Vector2 = g.map.ray_end(g.draw_player,ang,r)
            var d: float = hit_at.distance_to(g.draw_player)
            var blocked: bool = d < r-9.0
            # Anel interno: luz plena. Anel externo: esmaece no fim do alcance,
            # mas entra um pouco na parede atingida para revelar a fachada.
            var inner: Vector2 = g.draw_player+dir*minf(d,r*0.78)
            var outer: Vector2 = hit_at+dir*(24.0 if blocked else 0.0)
            pts.append(screen(inner))
            cols.append(Color(1,1,1,0.0 if edge else 1.0))
            pts.append(screen(outer))
            cols.append(Color(1,1,1,1.0 if (blocked and not edge) else 0.0))
            if i > 0:
                var a0: int = 1+(i-1)*2
                var a1: int = 1+i*2
                for tri in [[0,a0,a1],[a0,a0+1,a1+1],[a0,a1+1,a1]]:
                    idx.append(tri[0])
                    idx.append(tri[1])
                    idx.append(tri[2])
        RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(),idx,pts,cols)
    if g.monster_present() and g.monster_lit:
        # A entidade iluminada aparece inteira (e mais alta que as paredes).
        _blob(c,screen(g.draw_monster)+Vector2(0,-48),64.0,88.0,1.0)
    # Coisas mais altas que as paredes precisam de luz propria quando o facho as toca.
    if not g.apparition.is_empty() and g.is_illuminated(g.apparition["at"]):
        _blob(c,screen(g.apparition["at"])+Vector2(0,-48),64.0,88.0,1.0)
    if g.light_active() and not g.monster_banished:
        for h in g.hanged:
            if g.is_illuminated(h["at"]):
                _blob(c,screen(h["at"])+Vector2(0,-84),40.0,100.0,1.0)
        for m in g.mannequins:
            if g.is_illuminated(m["at"]):
                _blob(c,screen(m["at"])+Vector2(0,-40),32.0,46.0,1.0)
    # As velas do altar seguram um resto de luz; o ritual incendeia o circulo.
    if not g.power_on:
        var altar_at: Vector2 = screen(g.tile(26,29))+Vector2(0,-14)
        if g.ritual_running:
            _blob(c,altar_at,150.0,100.0,0.95)
        else:
            _blob(c,altar_at,74.0,50.0,0.30+0.05*sin(g.real_time*7.0))
    # Fragmentos pulsam e clareiam o entorno por um instante, mesmo no escuro.
    for item in g.scene_objects:
        var kind: String = item["kind"]
        if kind == "fragment":
            var v: float = g.fragment_pulse(int(item["idx"]))
            if v > 0.02:
                var rr: float = 55.0+85.0*v
                _blob(c,screen(item["at"])+Vector2(0,-18),rr,rr*0.72,v)
        elif kind == "lens" and not g.ghost_unlocked:
            _blob(c,screen(item["at"])+Vector2(0,-12),46.0,34.0,0.75)
    for bat in g.batteries:
        if not bat["taken"]:
            _blob(c,screen(bat["at"])+Vector2(0,6),20.0,13.0,0.42)

func _text(at: Vector2, label: String, size: int, color: Color) -> void:
    cv.draw_string(ThemeDB.fallback_font,at+Vector2(1.3,1.3),label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0,0,.85))
    cv.draw_string(ThemeDB.fallback_font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _labeled_door() -> void:
    var p: Vector2 = screen(g.tile(26,34))
    _box(g.tile(26,34),40.0,20.0,39.0,Color("a38660") if g.monster_banished else Color("5c4554"))
    _text(p+Vector2(-30,-58),"SAÍDA",12,Color("ebd6b3"))

func _clues_and_ritual() -> void:
    if g.light_on and g.ghost_mode:
        if g.is_illuminated(g.tile(12,11)):
            _text(screen(g.tile(12,11))+Vector2(-41,-56),"II — I — III",15,Color("dac2ff"))
        if g.is_illuminated(g.tile(44,29)):
            _text(screen(g.tile(44,29))+Vector2(-41,-55),"II — III — I",15,Color("dac2ff"))
        for w in g.ghost_writings:
            if g.is_illuminated(w["at"]):
                _text(screen(w["at"])+Vector2(-float(str(w["text"]).length())*3.6,-8),str(w["text"]),13,Color(.78,.20,.34,.92))
    if g.ritual_running:
        var p: Vector2 = screen(g.tile(26,29))
        for i in range(9):
            var ang: float = TAU*float(i)/9.0 + g.time_passed*1.7
            cv.draw_circle(p+Vector2(cos(ang)*44.0,sin(ang)*20.0-22),3.0,Color("eeb3d9"))
        # As tres sacrificadas se erguem em volta do altar para buscar a Ygona.
        var progress: float = 1.0-g.ritual_left/g.CFG.RITUAL_SECONDS
        for i in range(3):
            var ga: float = TAU*float(i)/3.0+PI/6.0
            var gp: Vector2 = p+Vector2(cos(ga)*66.0,sin(ga)*31.0)+Vector2(0,-3.0*sin(g.real_time*2.0+float(i)))
            var al: float = clampf(0.18+0.55*progress+0.08*sin(g.real_time*3.0+float(i)*2.0),0.0,0.85)
            var pale: Color = Color(.84,.90,1.0,al)
            poly([gp+Vector2(-11,0),gp+Vector2(-13,-30),gp+Vector2(-7,-48),gp+Vector2(7,-48),gp+Vector2(13,-30),gp+Vector2(11,0),gp+Vector2(4,-6),gp+Vector2(-4,-5)],pale)
            cv.draw_circle(gp+Vector2(0,-56),8.0,pale)
            cv.draw_circle(gp+Vector2(-3,-57),1.6,Color(0,0,0,al))
            cv.draw_circle(gp+Vector2(3,-57),1.6,Color(0,0,0,al))
            # O vazio no peito, onde a Ygona cortou.
            cv.draw_line(gp+Vector2(-7,-38),gp+Vector2(7,-38),Color(.35,.03,.09,al),2.4)
            _text(gp+Vector2(-18,-70),str(g.VICTIMS[i]["name"]),10,Color(.88,.92,1.0,al))

func draw_world() -> void:
    if floor_texture != null:
        cv.draw_texture(floor_texture, floor_origin - g.camera)
        _cached_floor_details()
    else:
        _floor()
    _decals()
    _blood_trail()
    _floor_light()
    _shadow_reach()
    var entities: Array = []
    # Visibilidade e profundidade das paredes sao consultadas em um cache pequeno.
    # Bandas de paredes permanecem 100% opacas em qualquer distancia.
    if wall_bands.size() > 0:
        var visible: Rect2 = Rect2(-85,-120,VIEW_WIDTH+170,VIEW_HEIGHT+240)
        for band in wall_bands:
            var top_left: Vector2 = band["offset"] - g.camera
            if Rect2(top_left,band["size"]).intersects(visible):
                entities.append({"kind":"wall_band", "data":band,"z":band["z"]-g.camera.y})
    else:
        for y in range(ManorMap.H):
            for x in range(ManorMap.W):
                if not g.map.is_wall_cell(x,y):
                    continue
                var p: Vector2 = screen(g.tile(x,y))
                if _onscreen(p,90):
                    entities.append({"kind":"wall","x":x,"y":y,"z":p.y})
    for obj in furniture:
        if _onscreen(screen(obj["at"]),140):
            entities.append({"kind":"furniture","data":obj,"z":project(obj["at"]).y-g.camera.y})
    for obj in g.scene_objects:
        if _object_should_draw(obj) and _onscreen(screen(obj["at"]),80):
            entities.append({"kind":"item","data":obj,"z":project(obj["at"]).y-g.camera.y})
    for bat in g.batteries:
        if not bat["taken"] and _onscreen(screen(bat["at"]),90):
            entities.append({"kind":"battery","at":bat["at"],"z":project(bat["at"]).y-g.camera.y})
    for spot in g.hiding_places:
        if _onscreen(screen(spot),90):
            entities.append({"kind":"hide","at":spot,"z":project(spot).y-g.camera.y})
    if g.light_on and g.ghost_mode:
        for portal in g.portals:
            for endpoint in [portal["a"],portal["b"]]:
                if _onscreen(screen(endpoint),90):
                    entities.append({"kind":"portal","at":endpoint,"z":project(endpoint).y-g.camera.y})
    for bottle in g.thrown_bottles:
        if _onscreen(screen(bottle["at"]),90):
            entities.append({"kind":"bottle","at":bottle["at"],"z":project(bottle["at"]).y-g.camera.y})
    for m in g.mannequins:
        if _onscreen(screen(m["at"]),90):
            entities.append({"kind":"mannequin","data":m,"z":project(m["at"]).y-g.camera.y})
    if not g.monster_banished:
        for h in g.hanged:
            if _onscreen(screen(h["at"]),200):
                entities.append({"kind":"hanged","data":h,"z":project(h["at"]).y-g.camera.y})
    if not g.apparition.is_empty():
        entities.append({"kind":"apparition","z":project(g.apparition["at"]).y-g.camera.y})
    for v in g.vultos:
        entities.append({"kind":"vulto","data":v,"z":project(v["at"]).y-g.camera.y})
    if g.monster_present():
        entities.append({"kind":"monster","z":project(g.draw_monster).y-g.camera.y})
    entities.append({"kind":"hero","z":project(g.draw_player).y-g.camera.y})
    entities.append({"kind":"door","z":project(g.tile(26,34)).y-g.camera.y})
    entities.sort_custom(func(a,b): return float(a["z"]) < float(b["z"]))
    for entity in entities:
        var kind: String = entity["kind"]
        match kind:
            "wall_band":
                var band: Dictionary = entity["data"]
                cv.draw_texture(band["tex"],band["offset"]-g.camera)
            "wall": _wall(entity["x"],entity["y"])
            "furniture": _furniture(entity["data"])
            "item": _scene_object(entity["data"])
            "battery": _battery(entity["at"])
            "hide": _hide_spot(entity["at"])
            "portal": _portal(entity["at"])
            "bottle":
                var p: Vector2 = screen(entity["at"])
                cv.draw_circle(p+Vector2(0,-10),6,Color("90cce4"))
                cv.draw_arc(p+Vector2(0,-10),17,0,TAU,28,Color(.70,.83,1,.30),2)
            "monster": _monster()
            "apparition": _ygona(g.apparition["at"],g.is_illuminated(g.apparition["at"]),false)
            "mannequin": _mannequin(entity["data"])
            "hanged": _hanged(entity["data"])
            "vulto": _vulto(entity["data"])
            "hero": _character()
            "door": _labeled_door()
    _clues_and_ritual()
    # Gradiente sombrio de vinheta em quatro faixas discretas.
    cv.draw_rect(Rect2(0,0,32,VIEW_HEIGHT),Color(0,0,.02,.23))
    cv.draw_rect(Rect2(VIEW_WIDTH-32,0,32,VIEW_HEIGHT),Color(0,0,.02,.23))
