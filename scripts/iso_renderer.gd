extends RefCounted
class_name IsoRenderer
## AFRODITE SCARE: apresentacao 2.5D projetada a 45 graus (losangos 2:1).
## A simulacao, as colisoes e o pathfinding continuam em coordenadas 2D.
## Toda a arte foi desenhada para o projeto com primitivas do Godot.

const TS: int = 32
const VIEW_WIDTH: float = 1152.0
const VIEW_HEIGHT: float = 720.0
const SKEW_X: float = 0.96
const SKEW_Y: float = 0.48
const ORIGIN: Vector2 = Vector2(1210.0, 65.0)
const WALL_BASE: float = 37.0     # altura para a qual os acabamentos das paredes foram desenhados
const WALL_HEIGHT: float = 48.0   # 30% mais alta; os acabamentos esticam junto (_wall_stretch)

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
        {"at":g.tile(5,4),"w":49.0,"d":23.0,"h":45.5,"kind":"shelf","c":Color("654b44")},
        {"at":g.tile(8,4),"w":49.0,"d":23.0,"h":45.5,"kind":"shelf","c":Color("684d44")},
        {"at":g.tile(11,4),"w":49.0,"d":23.0,"h":45.5,"kind":"shelf","c":Color("654b44")},
        {"at":g.tile(14,4),"w":49.0,"d":23.0,"h":45.5,"kind":"shelf","c":Color("684d44")},
        {"at":g.tile(39,5),"w":105.0,"d":37.0,"h":23.0,"kind":"butcher","c":Color("617076")},
        {"at":g.tile(47,6),"w":66.0,"d":36.0,"h":24.0,"kind":"butcher","c":Color("65747a")},
        {"at":g.tile(39,11),"w":82.0,"d":33.0,"h":22.0,"kind":"table","c":Color("77675d")},
        {"at":g.tile(5,22),"w":85.0,"d":74.0,"h":19.0,"kind":"bed","c":Color("6e557f")},
        {"at":g.tile(14,22),"w":64.0,"d":45.0,"h":30.0,"kind":"table","c":Color("664955")},
        {"at":g.tile(7,30),"w":75.0,"d":28.0,"h":20.0,"kind":"table","c":Color("73515d")},
        {"at":g.tile(38,27),"w":73.0,"d":36.0,"h":24.0,"kind":"table","c":Color("6c6772")},
        {"at":g.tile(49,29),"w":55.0,"d":48.0,"h":37.0,"kind":"table","c":Color("545965")},
        {"at":g.tile(44,27),"w":53.0,"d":20.0,"h":45.0,"kind":"mirror","c":Color("7b5f6f")},
        {"at":g.altar_at(),"w":62.0,"d":36.0,"h":31.0,"kind":"altar","c":Color("876c66")},
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
    bake_wall(x,y)

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
    var altar_pt: Vector2 = screen(g.altar_at())
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
        disc(cv,star[k]+Vector2(0,-9),flick,Color(1.0,.72,.35,.85))
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
        disc(cv,Vector2.ZERO,4.2,ink)
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
    ## Enquanto a luz a segura, a sombra de Afrodite rasteja pelo chao ate a jogadora.
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
    ## Uma das tres, enrolada num lencol encharcado e pendurada pelo pescoco.
    ## O pescoco quebrou: a cabeca tomba de lado. Pelo rasgo do lencol aparece
    ## o rosto cinzento, de olhos arregalados, que segue a jogadora de perto.
    ## O sangue atravessou o tecido, escorre pelo braco solto e pelos pes
    ## arroxeados e pinga numa poca que nao para de crescer.
    var p: Vector2 = screen(h["at"])
    var lit: bool = g.is_illuminated(h["at"])
    var idx: float = float(h["idx"])
    var t: float = g.real_time
    var gap: float = g.draw_player.distance_to(h["at"])
    var near: bool = gap < 150.0
    var blood: Color = Color("4a0b17")
    var fresh: Color = Color("74101f")
    var clot: Color = Color("2a050c")
    # --- Poca de sangue no piso, com respingos e o pingo caindo nela ---
    cv.draw_set_transform(p,0.0,Vector2(1.0,0.5))
    disc(cv,Vector2.ZERO,17.0,Color(0,0,0,0.38))
    for k in range(7):
        var pa: float = TAU*float(k)/7.0+idx
        disc(cv,Vector2.from_angle(pa)*(6.0+_h(idx,float(k))*8.0),5.0+_h(float(k),idx)*4.5,clot)
    disc(cv,Vector2(1,0),10.5,blood)
    disc(cv,Vector2(-3,-3),4.0,Color(0.58,0.12,0.18,0.5))
    for k in range(7):
        var sa: float = TAU*_h(float(k)*3.1,idx+1.0)
        disc(cv,Vector2.from_angle(sa)*(21.0+_h(idx,float(k)*1.7)*12.0),0.9+_h(float(k),2.0)*1.5,blood)
    var drop: float = fposmod(t*0.9+idx*0.37,1.0)
    if drop > 0.72:
        var rip: float = (drop-0.72)/0.28
        cv.draw_arc(Vector2(-2,0),2.0+rip*10.0,0,TAU,18,Color(0.70,0.16,0.24,0.6*(1.0-rip)),1.2)
    # --- Corpo: balanca na corda; sob a luz, convulsiona por instantes ---
    var sway: float = sin(t*0.8+idx*2.0)*(0.03+(0.05 if lit else 0.0))
    if lit and fposmod(t*0.7+idx*0.31,2.8) < 0.24:
        sway += sin(t*47.0)*0.045
    elif near and not lit:
        sway += sin(t*23.0)*0.012
    var origin: Vector2 = p+Vector2(0,-160)
    var body_xf: Transform2D = Transform2D(sway,origin)
    cv.draw_set_transform_matrix(body_xf)
    var rope: Color = Color("6b5d4a")
    var sheet: Color = Color("a1998c")
    var sheet_dk: Color = sheet.darkened(0.28)
    var skin: Color = Color("8a8b94")
    var bruise: Color = Color("5a4660")
    cv.draw_line(Vector2(0,-70),Vector2(2,60),rope,1.8,true)
    cv.draw_line(Vector2(0.6,-60),Vector2(-0.6,-40),rope.darkened(0.3),0.6,true)
    # Mortalha com forma de gente: ombros, cintura, joelhos colados.
    var shroud: Array = [Vector2(-7,69),Vector2(7,69),Vector2(12,78),Vector2(11,92),Vector2(8,102),Vector2(10,113),Vector2(8,127),Vector2(5,139),Vector2(-5,139),Vector2(-8,127),Vector2(-10,113),Vector2(-8,102),Vector2(-11,92),Vector2(-12,78)]
    _shape(shroud,sheet,true)
    _shape([Vector2(2,70),Vector2(7,69),Vector2(12,78),Vector2(11,92),Vector2(8,102),Vector2(10,113),Vector2(8,127),Vector2(5,139),Vector2(1.5,139),Vector2(3,104)],sheet_dk,false)
    for fl in [[-8.0,82.0,-3.0,96.0],[6.0,84.0,2.0,100.0],[-6.0,106.0,-2.0,124.0],[5.0,110.0,3.0,130.0]]:
        cv.draw_line(Vector2(fl[0],fl[1]),Vector2(fl[2],fl[3]),sheet.darkened(0.4),0.7,true)
    # O sangue atravessou o lencol: uma mancha no peito, onde a seita cortou,
    # aureolada de rosa onde o tecido bebeu, e escorridos ate os pes.
    var soak: Color = Color(0.55,0.20,0.24,0.35)
    _shape([Vector2(-8,81),Vector2(-2,78),Vector2(4,80),Vector2(7,86),Vector2(4,95),Vector2(-2,97),Vector2(-7,92)],soak,false)
    _shape([Vector2(-6,83),Vector2(-1,81),Vector2(3,83),Vector2(5,88),Vector2(2,93),Vector2(-3,94),Vector2(-6,89)],blood,false)
    _shape([Vector2(-3.5,85),Vector2(0.5,84),Vector2(2.5,88),Vector2(-0.5,91),Vector2(-3.5,89)],fresh,false)
    cv.draw_line(Vector2(-4,87),Vector2(1.5,86),clot,1.0,true)           # o corte por baixo do pano
    _shape([Vector2(-4,106),Vector2(1,105),Vector2(4,109),Vector2(1,114),Vector2(-4,112)],soak,false)
    _shape([Vector2(-2.5,107),Vector2(1,106.5),Vector2(2.5,109.5),Vector2(-0.5,112)],blood.darkened(0.1),false)
    var streaks: Array = [[-4.0,93.0,38.0,1.3],[0.0,95.0,30.0,1.0],[3.0,92.0,18.0,0.9],[-1.5,112.0,26.0,1.2],[2.0,111.0,16.0,0.8]]
    for s in streaks:
        var sx: float = float(s[0])
        var sy: float = float(s[1])
        var sl: float = float(s[2])*(0.92+0.08*sin(t*0.5+sx))
        cv.draw_polyline(PackedVector2Array([Vector2(sx,sy),Vector2(sx+0.6,sy+sl*0.5),Vector2(sx*0.85,sy+sl)]),blood,float(s[3]),true)
        disc(cv,Vector2(sx*0.85,sy+sl),float(s[3])*0.9,blood)
    var run: float = fposmod(t*0.35+idx*0.5,1.0)
    disc(cv,Vector2(-4.0+run*0.6,93.0+run*38.0),1.2,fresh)
    # Cordas apertando o lencol, afundando no tecido.
    for ry in [86.0,101.0,121.0]:
        var half: float = 11.5 if ry < 90.0 else (8.5 if ry < 110.0 else 8.0)
        cv.draw_polyline(PackedVector2Array([Vector2(-half,ry-1.0),Vector2(0,ry+1.2),Vector2(half,ry-0.6)]),Color("2e261d"),2.2,true)
        cv.draw_polyline(PackedVector2Array([Vector2(-half,ry-1.0),Vector2(0,ry+1.2),Vector2(half,ry-0.6)]),rope,1.2,true)
    # Um braco escapou do lencol: pende mole, roxo, e o sangue pinga dos dedos.
    var hand: Vector2 = Vector2(-15.5,121.0)
    _limb(Vector2(-11,79),Vector2(-15,100),2.6,2.1,skin)
    _limb(Vector2(-15,100),hand,2.1,1.6,skin)
    disc(cv,Vector2(-13.5,88),1.4,bruise)
    disc(cv,Vector2(-15.2,108),1.1,bruise)
    cv.draw_line(Vector2(-12,82),Vector2(-15.2,118),blood,0.9,true)
    for f in [-1.6,-0.5,0.6,1.6]:
        cv.draw_line(hand,hand+Vector2(f,6.0+absf(f)*-0.8),skin.darkened(0.15),0.9,true)
        disc(cv,hand+Vector2(f,6.0+absf(f)*-0.8),0.5,Color("1a0d12"))
    var fd: float = fposmod(t*1.1+idx*0.7,1.0)
    disc(cv,hand+Vector2(0.4,7.0+fd*fd*32.0),1.0,Color(0.45,0.05,0.10,1.0-fd))
    # Pes descalcos, arroxeados, com as pontas viradas para baixo.
    var twitch: float = sin(t*31.0)*1.0 if (lit and fposmod(t+idx,3.1) < 0.35) else 0.0
    var feet: Color = Color("6e5e78")
    for fx in [-3.0, 3.0]:
        var tip: Vector2 = Vector2(fx*1.1+(twitch if fx < 0.0 else -twitch),151.0)
        _limb(Vector2(fx,138),tip,2.2,1.4,feet)
        disc(cv,tip,1.0,Color("2a1c2c"))
        cv.draw_line(Vector2(fx,139),tip,blood,0.8,true)
    disc(cv,Vector2(-3.3,152.0+drop*drop*8.0),1.2,Color(0.45,0.05,0.10,1.0-drop))
    # --- Cabeca: o pescoco quebrado a deixa tombada sobre o ombro ---
    var tilt: float = 0.62+sin(t*0.6+idx)*0.04
    const HEAD_SCALE: float = 1.3
    var neck: Vector2 = Vector2(2,67)
    cv.draw_set_transform_matrix(body_xf*Transform2D(tilt,Vector2(HEAD_SCALE,HEAD_SCALE),0.0,neck))
    _shape([Vector2(-7.5,-6),Vector2(-6.5,-13),Vector2(0,-16.5),Vector2(6.5,-13),Vector2(7.5,-6),Vector2(5,0),Vector2(-5,0)],sheet,true)
    cv.draw_line(Vector2(-6,0.5),Vector2(6,0.5),rope,2.2,true)                    # o no apertando
    cv.draw_arc(Vector2(5.5,1.5),2.4,0,TAU,10,rope.darkened(0.2),1.4)
    # O rasgo no lencol e o rosto cinzento la dentro.
    var hole: PackedVector2Array = PackedVector2Array([Vector2(-5.5,-11),Vector2(-2,-13),Vector2(1.5,-12),Vector2(4,-13.5),Vector2(5,-9),Vector2(4.2,-5),Vector2(5,-2.5),Vector2(0.5,-1.5),Vector2(-3,-2.5),Vector2(-5.8,-4.5),Vector2(-4.6,-7.5)])
    cv.draw_colored_polygon(hole,skin)
    var torn: PackedVector2Array = hole.duplicate()
    torn.append(hole[0])
    cv.draw_polyline(torn,sheet.lightened(0.15),0.8,true)
    for tk in [0,2,4,7,9]:
        var e: Vector2 = hole[tk]
        cv.draw_line(e,e+(e-Vector2(0,-7)).normalized()*1.8,sheet.lightened(0.1),0.5,true)
    # Olhos arregalados em orbitas fundas; de perto, as pupilas encontram voce.
    var look: Vector2 = Vector2.ZERO
    if near:
        var to_hero: Vector2 = (screen(g.draw_player)+Vector2(0,-50))-(origin+Vector2(0,60))
        look = to_hero.normalized().rotated(-(sway+tilt))*0.7
    for ex in [-2.6, 2.0]:
        var eye: Vector2 = Vector2(ex,-8.6)
        disc(cv,eye+Vector2(0,0.3),2.5,Color("1e141c"))              # orbita funda e roxa
        _oval(eye,1.6,1.05,Color("c2b59c"))                                # esclera amarelada
        cv.draw_line(eye+Vector2(-1.4,0.2),eye+Vector2(-0.5,0.0),Color(0.72,0.10,0.14,0.8),0.35,true)
        cv.draw_line(eye+Vector2(1.4,0.3),eye+Vector2(0.6,-0.1),Color(0.72,0.10,0.14,0.7),0.35,true)
        disc(cv,eye+look,0.45 if near else 0.6,Color("0a0508"))
    # Boca aberta num grito que nao saiu; sangue preto escorre pelo queixo.
    var gape: float = 1.45+(0.7+0.3*sin(t*5.0) if near else 0.0)
    _oval(Vector2(-0.5,-4.2),1.5,gape*0.9,Color("120508"))
    cv.draw_line(Vector2(0.4,-3.0),Vector2(1.0,1.5),Color("1a0508"),0.9,true)
    cv.draw_line(Vector2(-1.4,-3.2),Vector2(-1.8,0.5),Color("1a0508"),0.6,true)
    # --- Cabelo comprido e molhado: escapa pelo alto do rasgo e cai reto,
    # pelo peso, do lado da cabeca que tombou (sem cobrir o rosto) ---
    cv.draw_set_transform_matrix(body_xf)
    var roots: Array = [Vector2(1.5,-15.5),Vector2(4.0,-14.0),Vector2(6.0,-11.5),Vector2(7.2,-8.0)]
    for k in range(roots.size()):
        var root: Vector2 = neck+(roots[k] as Vector2).rotated(tilt)*HEAD_SCALE
        var hlen: float = 22.0+fposmod(float(k)*7.3+idx*3.0,12.0)
        var hw: float = sin(t*0.9+float(k))*0.7
        strand(cv,[root,root+Vector2(1.4,4.0),root+Vector2(1.0+hw,hlen*0.55),root+Vector2(0.6+hw*1.4,hlen)],1.1,0.15,Color("0c0a10"))
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
    # Moscas rodeando a cabeca.
    var fly_c: Vector2 = origin+Vector2(4,58).rotated(sway)
    for k in range(4):
        var fa: float = t*(3.1+float(k)*0.7)+float(k)*1.9+idx
        var fp: Vector2 = fly_c+Vector2(cos(fa)*(11.0+float(k)*2.0),sin(fa*1.7)*7.0)+Vector2(randf_range(-0.6,0.6),randf_range(-0.6,0.6))
        disc(cv,fp,0.85,Color("050305"))

func _mannequin(m: Dictionary) -> void:
    ## Manequim de costura da oficina. Cabeca de gesso rachada, olhos fundos
    ## e boca costurada que abre num sorriso quando ela chega perto. O peito
    ## foi aberto em Y e costurado de volta, e ainda sangra. Bracos de
    ## articulacoes de madeira: um pende quebrado ao contrario; o outro sobe
    ## devagar e aponta para a jogadora com um dedo comprido e unha preta.
    var p: Vector2 = screen(m["at"])
    var t: float = g.real_time
    var seed: float = float(m["home"].x)*0.03+float(m["home"].y)*0.05
    var to: Vector2 = screen(g.draw_player)-p
    var near: bool = g.draw_player.distance_to(m["at"]) < 150.0
    var lit: bool = g.is_illuminated(m["at"])
    var raise: float = smoothstep(0.0,1.0,float(m.get("raise",0.0)))
    var side: float = 1.0 if to.x >= 0.0 else -1.0
    var linen: Color = Color("b3a690")
    var linen_dk: Color = linen.darkened(0.22)
    var wood: Color = Color("8a775f")
    var joint: Color = Color("a89275")
    var plaster: Color = Color("d2c7b6")
    var blood: Color = Color("5c0f1d")
    var fresh: Color = Color("7a1424")
    # Sombra: com o facho nela, estica para longe da jogadora.
    poly([p+Vector2(-13,0),p+Vector2(0,6),p+Vector2(13,0),p+Vector2(0,-6)],Color(0,0,0,.42))
    if lit and to.length() > 1.0:
        var away: Vector2 = -to.normalized()*46.0
        var perp: Vector2 = to.normalized().orthogonal()
        poly([p-perp*5.0,p+perp*5.0,p+away+perp*9.0,p+away-perp*9.0],Color(0,0,0,0.30))
    # Poca pequena embaixo, alimentada pelo que pinga da barra.
    cv.draw_set_transform(p+Vector2(3,2),0.0,Vector2(1.0,0.5))
    disc(cv,Vector2.ZERO,6.0,blood.darkened(0.3))
    disc(cv,Vector2(-1,-1),3.2,blood)
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
    # Tripe de ferro enferrujado e haste.
    for leg in [Vector2(-10,2),Vector2(10,2),Vector2(0,6)]:
        cv.draw_line(p+Vector2(0,-6),p+leg,Color("2f262c"),2.2,true)
        disc(cv,p+leg,1.3,Color("4a3a36"))
    cv.draw_line(p+Vector2(0,-6),p+Vector2(0,-26),Color("3b3038"),2.6,true)
    # Braco quebrado, do lado oposto: pende e dobra o cotovelo ao contrario.
    var sh2: Vector2 = p+Vector2(-side*9.5,-55)
    var el2: Vector2 = sh2+Vector2(-side*3.0,11.0)
    var wr2: Vector2 = el2+Vector2(side*3.5,9.5)
    _limb(sh2,el2,1.9,1.6,wood)
    _limb(el2,wr2,1.6,1.3,wood)
    disc(cv,el2,2.2,joint)
    for f in [-1.2,0.0,1.2]:
        cv.draw_line(wr2,wr2+Vector2(f*0.8+side*1.0,5.5),wood.darkened(0.2),0.8,true)
    # Tronco: busto de linho manchado, mais escuro do lado da sombra.
    var torso: Array = [p+Vector2(-9,-24),p+Vector2(-12,-36),p+Vector2(-10,-46),p+Vector2(-12,-54),p+Vector2(-6,-58),p+Vector2(6,-58),p+Vector2(12,-54),p+Vector2(10,-46),p+Vector2(12,-36),p+Vector2(9,-24)]
    _shape(torso,linen,true)
    _shape([p+Vector2(1,-24),p+Vector2(1,-58),p+Vector2(6,-58),p+Vector2(12,-54),p+Vector2(10,-46),p+Vector2(12,-36),p+Vector2(9,-24)],linen_dk,false)
    disc(cv,p+Vector2(-6,-31),3.0,Color(0.42,0.32,0.20,0.35))
    disc(cv,p+Vector2(5,-40),2.4,Color(0.42,0.32,0.20,0.30))
    poly([p+Vector2(-9,-24),p+Vector2(9,-24),p+Vector2(8,-22),p+Vector2(-8,-22)],Color("3b3038"))
    # Corte em Y, do ombro ao umbigo, costurado com linha preta grossa. Ainda sangra.
    var cut: Array = [[p+Vector2(-8,-55),p+Vector2(0,-48)],[p+Vector2(8,-55),p+Vector2(0,-48)],[p+Vector2(0,-48),p+Vector2(0,-29)]]
    for seg in cut:
        cv.draw_line(seg[0],seg[1],blood,2.0,true)
        cv.draw_line(seg[0],seg[1],fresh,0.8,true)
        for k in range(4):
            var sp: Vector2 = (seg[0] as Vector2).lerp(seg[1],(float(k)+0.5)/4.0)
            var nrm: Vector2 = ((seg[1] as Vector2)-(seg[0] as Vector2)).normalized().orthogonal()*2.2
            cv.draw_line(sp-nrm,sp+nrm,Color("140c10"),0.9,true)
    for dx in [-1.5,1.0,3.0]:
        var dl: float = 6.0+fposmod(dx*13.0+seed*40.0,7.0)
        cv.draw_line(p+Vector2(dx*0.6,-30),p+Vector2(dx,-30+dl),blood,1.0,true)
    var drip: float = fposmod(t*0.6+seed*7.0,1.0)
    disc(cv,p+Vector2(2.5,-23.0+drip*drip*24.0),0.9,Color(0.45,0.05,0.10,1.0-drip))
    # Alfinetes espetados no busto.
    for pin in [[Vector2(-8,-40),Vector2(-12,-43),Color("b0202a")],[Vector2(7,-50),Vector2(11,-53),Color("e8e2d6")],[Vector2(-4,-34),Vector2(-7,-31),Color("b0202a")],[Vector2(8,-31),Vector2(12,-29),Color("2a2a30")]]:
        cv.draw_line(p+pin[0],p+pin[1],Color("c9c9cf"),0.6,true)
        disc(cv,p+pin[1],1.1,pin[2])
    # Fita metrica pendurada no pescoco.
    var tape: Color = Color("c9b25a")
    for tx in [-1.0, 1.0]:
        var tp: PackedVector2Array = PackedVector2Array([p+Vector2(tx*3.5,-59),p+Vector2(tx*6.0,-52),p+Vector2(tx*6.5,-44+tx*3.0)])
        cv.draw_polyline(tp,tape,1.6,true)
    # Pescoco de madeira, rachado, e a cabeca de gesso que vira para ela aos estalos.
    var lean: float = clampf(to.x/110.0,-1.0,1.0)*3.4
    var cock: float = side*(0.22+0.26*raise)
    if near and fposmod(t*1.3+seed*9.0,1.0) < 0.07:
        cock += sin(t*60.0)*0.25
    var neck_top: Vector2 = p+Vector2(lean*0.5,-62)
    cv.draw_line(p+Vector2(0,-57),neck_top,wood,3.4,true)
    cv.draw_line(p+Vector2(-0.6,-58),p+Vector2(0.8,-61),Color("3b2c22"),0.6,true)
    cv.draw_set_transform(neck_top+Vector2(lean*0.5,-8),cock,Vector2.ONE)
    _shape([Vector2(-6.5,-4),Vector2(-5.8,-9),Vector2(0,-11),Vector2(5.8,-9),Vector2(6.5,-4),Vector2(5,3),Vector2(2,6.5),Vector2(-2,6.5),Vector2(-5,3)],plaster,true)
    _shape([Vector2(1.5,-11),Vector2(5.8,-9),Vector2(6.5,-4),Vector2(5,3),Vector2(2,6.5),Vector2(1.5,6.5)],plaster.darkened(0.14),false)
    # Rachaduras no gesso, uma delas lascou um pedaco da testa.
    cv.draw_polyline(PackedVector2Array([Vector2(-1,-11),Vector2(-2.2,-7),Vector2(-0.8,-4.5),Vector2(-2.6,-1)]),Color("4f4440"),0.6,true)
    cv.draw_polyline(PackedVector2Array([Vector2(4.5,-8.5),Vector2(2.6,-6.8),Vector2(3.4,-4.6)]),Color("4f4440"),0.5,true)
    poly([Vector2(1.5,-10.6),Vector2(4.2,-9.6),Vector2(2.8,-8.2)],Color("2a2226"))
    # Orbitas fundas: de perto, uma brasa vermelha acende la no fundo.
    var glow: float = 0.0
    if near:
        glow = 0.55+0.45*sin(t*4.0+seed)
    elif raise > 0.5:
        glow = 0.25
    for ex in [-2.6, 2.6]:
        _oval(Vector2(ex,-3.6),1.9,1.4,Color("140c10"))
        cv.draw_line(Vector2(ex-0.4,-2.4),Vector2(ex-0.6,0.4+absf(ex)*0.3),Color(0.20,0.10,0.10,0.55),0.5,true)
        if glow > 0.0:
            disc(cv,Vector2(ex,-3.5),0.65,Color(1.0,0.28,0.20,glow))
    # Boca costurada; os pontos esticam num sorriso quando ela se aproxima.
    var grin: float = raise*(1.0 if near else 0.55)
    var mouth: PackedVector2Array = PackedVector2Array()
    var lower: PackedVector2Array = PackedVector2Array()
    for k in range(7):
        var u: float = float(k)/6.0
        var corner: float = pow(2.0*u-1.0,2.0)        # 0 no meio, 1 nos cantos
        var at_line: Vector2 = Vector2(lerpf(-4.2,4.2,u),2.4+grin*0.5*(1.0-corner)-grin*1.5*corner)
        mouth.append(at_line)
        lower.append(at_line+Vector2(0,grin*1.8*(1.0-corner)))
    if grin > 0.05:
        var gap_pts: PackedVector2Array = mouth.duplicate()
        for k in range(5,0,-1):    # cantos sao comuns aos dois labios
            gap_pts.append(lower[k])
        cv.draw_colored_polygon(gap_pts,Color("1a0a0e"))
    cv.draw_polyline(mouth,Color("2a1a1c"),0.8,true)
    for k in range(1,6):
        cv.draw_line(mouth[k]+Vector2(-0.3,-1.2),mouth[k]+Vector2(0.3,1.2+grin*1.6),Color("100808"),0.5,true)
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
    # Braco que aponta: sobe aos poucos e trava na direcao dela, tremendo.
    var sh: Vector2 = p+Vector2(side*9.5,-55)
    var target: Vector2 = screen(g.draw_player)+Vector2(0,-48)-sh
    var rest: float = Vector2(side*0.2,1.0).angle()
    var aim: float = lerp_angle(rest,target.angle(),raise)+sin(t*31.0+seed)*0.025*raise
    var d1: Vector2 = Vector2.from_angle(aim)
    var d2: Vector2 = Vector2.from_angle(lerp_angle(aim+side*0.5,aim,raise))
    var el: Vector2 = sh+d1*(11.5+1.5*raise)
    var wr: Vector2 = el+d2*(10.5+2.0*raise)
    _limb(sh,el,2.3,1.9,wood)
    _limb(el,wr,1.9,1.5,wood)
    disc(cv,sh,2.4,joint)
    disc(cv,el,2.1,joint)
    _oval(wr+d2*1.6,2.0,1.5,wood.lightened(0.05),d2.angle())
    # Dedos fechados e um indicador comprido demais, com unha preta pontuda.
    var curl_side: Vector2 = d2.orthogonal()*side
    for f in [0.9,1.8,2.6]:
        var k0: Vector2 = wr+d2*2.4+curl_side*(f-1.6)
        cv.draw_line(k0,k0+d2*1.6-curl_side*0.6,wood.darkened(0.2),0.9,true)
    var knuckle: Vector2 = wr+d2*3.0
    var index_tip: Vector2 = knuckle+d2*(4.0+5.0*raise)
    cv.draw_line(knuckle,index_tip,wood,1.1,true)
    disc(cv,knuckle+d2*(2.0+2.5*raise),0.7,joint)
    cv.draw_line(index_tip,index_tip+d2*(1.5+2.5*raise),Color("0a0508"),1.0,true)

func _blood_trail() -> void:
    # Por onde ela passou fica um rastro escuro, que seca aos poucos.
    for drop in g.blood_trail:
        var p: Vector2 = screen(drop["at"])
        if not _onscreen(p,30.0):
            continue
        var a: float = clampf(float(drop["ttl"])/8.0,0.0,1.0)*0.62
        var r: float = float(drop["r"])
        cv.draw_set_transform(p,0.0,Vector2(1.0,0.5))
        disc(cv,Vector2.ZERO,r,Color(0.30,0.02,0.07,a))
        disc(cv,Vector2(r*0.9,r*0.5),r*0.38,Color(0.24,0.01,0.05,a))
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
    var phasing: bool = g.spectral_open()
    for n in range(count+1):
        var a: float = g.look.angle()+lerpf(-half,half,float(n)/count)
        var beam_edge: Vector2 = screen(g.map.ray_end(g.draw_player,a,r,phasing))
        rays.append(beam_edge)
        # Reutiliza as amostras centrais do cone externo. Corta pela metade
        # o numero de testes de colisao por quadro sem deixar a luz atravessar parede.
        if n >= 7 and n <= 21:
            rays2.append(begin.lerp(beam_edge,0.84))
    poly(rays,Color(0.60,0.38,0.95,.23) if g.ghost_mode else Color(1.0,.83,.52,.19))
    poly(rays2,Color(.72,.56,1.0,.18) if g.ghost_mode else Color(1.0,.95,.69,.17))
    disc(cv,begin,18,Color(.63,.37,.94,.10) if g.ghost_mode else Color(.98,.88,.62,.08))

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
    disc(c,at+Vector2(wobble*0.4,-r*0.26),r*0.46,Color(0.86,0.60,0.68,0.35*alpha))
    disc(c,at+Vector2(-r*0.34+wobble*0.6,-r*0.46),r*0.17,Color(1,1,1,0.80*alpha))

func _hide_spot(at: Vector2) -> void:
    _wardrobe(at)

func _portal(at: Vector2) -> void:
    ## Costura Espectral (E): um rasgo no ar, costurado com linha grossa.
    ## Na luz espectral aparece inteira, com o circulo de runas no piso.
    ## Na luz comum, so uma cicatriz costurada no chao denuncia o lugar.
    var p: Vector2 = screen(at)
    var t: float = g.real_time
    var seed: float = at.x*0.013+at.y*0.007
    if not g.spectral_open():
        if g.is_illuminated(at) or g.draw_player.distance_to(at) < 60.0:
            _floor_matrix(p,seed*3.0)
            cv.draw_line(Vector2(-12,0),Vector2(12,0),Color(0.36,0.18,0.58,0.6),1.8)
            for k in range(6):
                var sx: float = -10.0+float(k)*4.0
                cv.draw_line(Vector2(sx-1.4,-3.2),Vector2(sx+1.4,3.2),Color(0.66,0.48,0.90,0.55),0.9)
            cv.draw_set_transform_matrix(Transform2D.IDENTITY)
        return
    var near: float = clampf(1.0-g.draw_player.distance_to(at)/110.0,0.0,1.0)
    var breath: float = 0.5+0.5*sin(t*2.4+seed*10.0)
    # Circulo de runas no piso, girando devagar.
    _floor_matrix(p,t*0.5+seed)
    disc(cv,Vector2.ZERO,18.0,Color(0.45,0.22,0.85,0.20+0.08*breath))
    cv.draw_arc(Vector2.ZERO,16.0,0,TAU,40,Color(0.82,0.66,1.0,0.8),1.4)
    cv.draw_arc(Vector2.ZERO,11.0,0,TAU,30,Color(0.82,0.66,1.0,0.45),0.9)
    for k in range(8):
        var ra: float = TAU*float(k)/8.0
        cv.draw_line(Vector2.from_angle(ra)*12.0,Vector2.from_angle(ra+0.22)*15.0,Color(0.92,0.84,1.0,0.75),1.0)
    cv.draw_set_transform_matrix(Transform2D.IDENTITY)
    # O rasgo: abre mais quando ela chega perto.
    var top: Vector2 = p+Vector2(0,-54)
    var bottom: Vector2 = p+Vector2(0,-6)
    var w: float = 4.5+2.0*breath+4.0*near
    disc(cv,p+Vector2(0,-30),22.0+6.0*breath+8.0*near,Color(0.55,0.30,1.0,0.10+0.06*near))
    var slit: PackedVector2Array = PackedVector2Array([top])
    for k in range(1,12):
        var f: float = float(k)/12.0
        slit.append(top.lerp(bottom,f)+Vector2(sin(f*PI)*(w+sin(f*9.0+t*3.0)*0.7),0))
    slit.append(bottom)
    for k in range(11,0,-1):
        var f2: float = float(k)/12.0
        slit.append(top.lerp(bottom,f2)-Vector2(sin(f2*PI)*(w+sin(f2*7.0+t*2.6)*0.7),0))
    cv.draw_colored_polygon(slit,Color(0.06,0.01,0.10,0.92))
    cv.draw_line(top.lerp(bottom,0.12),top.lerp(bottom,0.88),Color(0.86,0.72,1.0,0.30+0.35*breath),1.4,true)
    slit.append(slit[0])
    cv.draw_polyline(slit,Color(0.84,0.70,1.0,0.9),1.3,true)
    # Pontos de linha grossa atravessando o rasgo, como se alguem o tivesse fechado.
    for k in range(5):
        var f3: float = 0.16+0.68*float(k)/4.0
        var c: Vector2 = top.lerp(bottom,f3)
        var ww: float = sin(f3*PI)*w+3.0
        cv.draw_line(c+Vector2(-ww,-2.5),c+Vector2(ww,2.5),Color("e8dcff"),1.0,true)
    for k in range(5):
        var oa: float = t*1.3+float(k)*TAU/5.0+seed
        disc(cv,p+Vector2(cos(oa)*17.0,-28.0+sin(oa)*7.0-sin(t*2.0+float(k))*9.0),1.2,Color(0.92,0.82,1.0,0.75))

func _portal_threads() -> void:
    ## Na luz espectral, um fio costurado no chao liga as duas pontas de cada
    ## Costura: passa por baixo da parede e mostra para onde ela leva.
    if not g.spectral_open():
        return
    var t: float = g.real_time
    for portal in g.portals:
        var a: Vector2 = portal["a"]
        var b: Vector2 = portal["b"]
        if g.draw_player.distance_to(a) > 640.0 and g.draw_player.distance_to(b) > 640.0:
            continue
        var dist: float = a.distance_to(b)
        var dir: Vector2 = (b-a)/dist
        var side: Vector2 = dir.orthogonal()
        var n: int = int(dist/13.0)
        for i in range(n):
            var f0: float = float(i)/float(n)
            var p0: Vector2 = a+dir*dist*f0
            var p1: Vector2 = a+dir*dist*((float(i)+0.55)/float(n))
            var glow: float = 0.5+0.5*sin(f0*14.0-t*4.0)
            cv.draw_line(screen(p0),screen(p1),Color(0.74,0.52,1.0,0.30+0.35*glow),1.6,true)
            var m: Vector2 = (p0+p1)*0.5
            cv.draw_line(screen(m-side*3.5),screen(m+side*3.5),Color(0.88,0.76,1.0,0.25+0.3*glow),1.0,true)

func _spectral_wall(cell: Vector2i) -> void:
    ## Parede Espectral (dois blocos). Com a luz comum e uma parede igual as
    ## outras, so com uma costura fina e fumaca roxa vazando pelas frestas.
    ## Com a luz espectral acesa vira um bloco lilas translucido: da para ver
    ## atraves dela e atravessa-la andando.
    var x: int = cell.x
    var y: int = cell.y
    var at: Vector2 = g.tile(x,y)
    var t: float = g.real_time
    var seed: float = float(x*3+y*7)
    var H: float = WALL_HEIGHT
    if not g.spectral_open():
        bake_wall(x,y)
        var pulse: float = 0.5+0.5*sin(t*1.6+seed)
        for side in [0, 1]:
            var nb: Vector2i = cell+(Vector2i(0,1) if side == 0 else Vector2i(1,0))
            if g.map.is_spectral_cell(nb.x,nb.y) or _static_wall(nb.x,nb.y):
                continue   # face escondida pela parede vizinha
            var seam: PackedVector2Array = PackedVector2Array()
            for k in range(8):
                seam.append(_wpt(at,side,0.5+(0.05 if k%2 == 0 else -0.05),2.0+(H-5.0)*float(k)/7.0))
            cv.draw_polyline(seam,Color(0.05,0.02,0.08,0.8),2.2,true)
            cv.draw_polyline(seam,Color(0.72,0.48,1.0,0.22+0.3*pulse),0.9,true)
            for k in range(3):
                var z: float = 8.0+float(k)*10.0
                _wl(at,side,0.42,z-2.0,0.58,z+2.0,Color(0.82,0.68,1.0,0.22+0.25*pulse),0.8)
        var crest: Vector2 = screen(at)+Vector2(0,-H)
        for k in range(3):
            var f: float = fposmod(t*0.4+float(k)/3.0+seed*0.07,1.0)
            disc(cv,crest+Vector2(sin(f*6.0+seed+float(k))*4.0,-f*18.0),1.5+f*4.0,Color(0.55,0.35,0.90,0.22*(1.0-f)))
        return
    var shimmer: float = 0.5+0.5*sin(t*3.1+seed)
    # Brilho lilas no piso por baixo do bloco.
    poly([_wp(at,-16,-16,0),_wp(at,16,-16,0),_wp(at,16,16,0),_wp(at,-16,16,0)],Color(0.72,0.52,1.0,0.16+0.06*shimmer))
    var edge: Color = Color(0.94,0.86,1.0,0.55+0.2*shimmer)
    for side in [0, 1]:
        var nb2: Vector2i = cell+(Vector2i(0,1) if side == 0 else Vector2i(1,0))
        if g.map.is_spectral_cell(nb2.x,nb2.y):
            continue   # face interna do bloco de dois
        var face: Color = Color(0.80,0.64,1.0,0.28+0.08*shimmer) if side == 0 else Color(0.68,0.52,0.92,0.30+0.08*shimmer)
        _wq(at,side,0,1,0,H,face)
        # Faixas de luz subindo pela face, como fumaca presa no vidro.
        for k in range(3):
            var z2: float = fposmod(t*9.0+float(k)*H/3.0+seed,H)
            _wl(at,side,0.03,z2,0.97,z2,Color(0.94,0.86,1.0,0.25*(1.0-z2/H)),1.0)
        _wl(at,side,0,0,0,H,edge,1.0)
        _wl(at,side,1,0,1,H,edge,1.0)
        _wl(at,side,0,0,1,0,Color(edge.r,edge.g,edge.b,edge.a*0.6),1.0)
    var t0: Vector2 = _wp(at,-16,-16,H)
    var t1: Vector2 = _wp(at,16,-16,H)
    var t2: Vector2 = _wp(at,16,16,H)
    var t3: Vector2 = _wp(at,-16,16,H)
    poly([t0,t1,t2,t3],Color(0.88,0.78,1.0,0.30+0.10*shimmer))
    cv.draw_polyline(PackedVector2Array([t0,t1,t2,t3,t0]),edge,1.0,true)
    # Particulas subindo de dentro do bloco.
    for k in range(4):
        var f4: float = fposmod(t*0.5+float(k)*0.25+seed*0.05,1.0)
        var q: Vector2 = screen(at)+Vector2(sin(f4*7.0+float(k)*2.0+seed)*9.0,-4.0-f4*(H+14.0))
        disc(cv,q,1.0+0.6*(1.0-f4),Color(0.95,0.88,1.0,0.7*(1.0-f4)))

func _curve(ctrl: Array, steps: int = 6) -> PackedVector2Array:
    ## Contorno fechado e arredondado que passa por todos os pontos de controle.
    var out: PackedVector2Array = PackedVector2Array()
    var n: int = ctrl.size()
    for i in range(n):
        var p0: Vector2 = ctrl[(i-1+n)%n]
        var p1: Vector2 = ctrl[i]
        var p2: Vector2 = ctrl[(i+1)%n]
        var p3: Vector2 = ctrl[(i+2)%n]
        for k in range(steps):
            out.append(p1.cubic_interpolate(p2,p0,p3,float(k)/float(steps)))
    return out

func strand(c: CanvasItem, ctrl: Array, w0: float, w1: float, color: Color, steps: int = 5) -> void:
    ## Mecha de cabelo: curva suave (Catmull-Rom) que afina ate a ponta.
    ## Montada como faixa de triangulos, sem triangulacao automatica, entao
    ## curvas fortes nunca "somem" por poligono invalido.
    var n: int = ctrl.size()
    if n < 2:
        return
    var pts: PackedVector2Array = PackedVector2Array()
    for i in range(n-1):
        var p0: Vector2 = ctrl[maxi(i-1,0)]
        var p1: Vector2 = ctrl[i]
        var p2: Vector2 = ctrl[i+1]
        var p3: Vector2 = ctrl[mini(i+2,n-1)]
        for k in range(steps):
            pts.append(p1.cubic_interpolate(p2,p0,p3,float(k)/float(steps)))
    pts.append(ctrl[n-1])
    var m: int = pts.size()
    var verts: PackedVector2Array = PackedVector2Array()
    var cols: PackedColorArray = PackedColorArray()
    var idx: PackedInt32Array = PackedInt32Array()
    for i in range(m):
        var d: Vector2 = pts[mini(i+1,m-1)]-pts[maxi(i-1,0)]
        var nrm: Vector2 = d.normalized().orthogonal() if d.length_squared() > 0.0001 else Vector2.RIGHT
        var f: float = float(i)/float(m-1)
        # Grossa na raiz, afina devagar e so fecha mesmo na ponta.
        var w: float = lerpf(w0,w1,f*f)
        verts.append(pts[i]+nrm*w)
        verts.append(pts[i]-nrm*w)
        cols.append(color)
        cols.append(color)
        if i > 0:
            var a: int = (i-1)*2
            idx.append_array([a,a+1,a+2,a+1,a+3,a+2])
    RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(),idx,verts,cols)

# Curva + triangulacao de cada forma, por pontos de controle. A maioria das
# formas (mortalhas, manchas, cabecas) tem pontos fixos e era recalculada a
# cada quadro; no navegador (WebAssembly) isso pesava muito.
var _shape_cache: Dictionary = {}
const SHAPE_CACHE_MAX: int = 1024

func _shape_geometry(ctrl: Array) -> Array:
    ## [pontos, indices, contorno fechado, cores, cor das cores, controle];
    ## vazio se a forma for invalida.
    var key: int = ctrl.hash()
    var entry: Variant = _shape_cache.get(key)
    if entry != null and (entry.is_empty() or entry[5] == ctrl):
        return entry
    var pts: PackedVector2Array = _curve(ctrl)
    # Triangula aqui: se a curva suave se cruzar em alguma volta fechada,
    # usa o contorno dos pontos de controle em vez de nao desenhar nada.
    var idx: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
    if idx.is_empty():
        pts = PackedVector2Array(ctrl)
        idx = Geometry2D.triangulate_polygon(pts)
    var result: Array = []
    if not idx.is_empty():
        var closed: PackedVector2Array = pts.duplicate()
        closed.append(pts[0])
        var cols: PackedColorArray = PackedColorArray()
        cols.resize(pts.size())
        result = [pts, idx, closed, cols, null, ctrl.duplicate()]
    # Formas animadas mudam a cada quadro: o limite impede o cache de crescer sem fim.
    if _shape_cache.size() >= SHAPE_CACHE_MAX:
        _shape_cache.clear()
    _shape_cache[key] = result
    return result

func _shape(ctrl: Array, color: Color, outline: bool = true) -> void:
    var geo: Array = _shape_geometry(ctrl)
    if geo.is_empty():
        return
    if geo[4] != color:
        var cols: PackedColorArray = geo[3]
        cols.fill(color)
        geo[3] = cols   # arrays empacotados sao copiados por valor
        geo[4] = color
    RenderingServer.canvas_item_add_triangle_array(cv.get_canvas_item(),geo[1],geo[0],geo[3])
    if outline:
        # Contorno suavizado: esconde o serrilhado e separa as formas.
        cv.draw_polyline(geo[2],color.darkened(0.38),0.8,true)

func _oval(center: Vector2, rx: float, ry: float, color: Color, rot: float = 0.0) -> void:
    var pts: PackedVector2Array = PackedVector2Array()
    for i in range(20):
        var a: float = TAU*float(i)/20.0
        pts.append(center+Vector2(cos(a)*rx,sin(a)*ry).rotated(rot))
    cv.draw_colored_polygon(pts,color)

# Disco cheio rapido. CanvasItem.draw_circle monta e triangula um poligono de
# 64 lados a cada chamada (~10 us nativo, varias vezes mais no navegador); os
# corpos usam centenas de circulos por quadro. Aqui cada disco e um retangulo
# texturizado, que o renderizador agrupa num unico lote.
var _disc_textures: Array = []   # [diametro em texels, textura], do menor ao maior

func _disc_texture(radius: float) -> Texture2D:
    if _disc_textures.is_empty():
        for size in [16, 32, 64, 128]:
            var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
            var half: float = size * 0.5
            for y in range(size):
                for x in range(size):
                    var d: float = Vector2(x + 0.5 - half, y + 0.5 - half).length()
                    img.set_pixel(x, y, Color(1, 1, 1, clampf(half - d + 0.5, 0.0, 1.0)))
            _disc_textures.append([size, ImageTexture.create_from_image(img)])
    # Escolhe a textura com ~4 texels por pixel do raio (sobra para o zoom da Web).
    for pair in _disc_textures:
        if float(pair[0]) >= radius * 8.0:
            return pair[1]
    return _disc_textures[-1][1]

func disc(c: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
    ## Substitui c.draw_circle(center, radius, color) (circulo cheio).
    if radius <= 0.0:
        return
    var r: Vector2 = Vector2(radius, radius)
    c.draw_texture_rect(_disc_texture(radius), Rect2(center - r, r * 2.0), false, color)

func _limb(a: Vector2, b: Vector2, wa: float, wb: float, color: Color) -> void:
    ## Membro afunilado com as pontas redondas (coxa, antebraco, mecha de cabelo).
    var d: Vector2 = b-a
    if d.length_squared() > 0.01:
        var nrm: Vector2 = d.normalized().orthogonal()
        cv.draw_colored_polygon(PackedVector2Array([a+nrm*wa,b+nrm*wb,b-nrm*wb,a-nrm*wa]),color)
    disc(cv,a,wa,color)
    disc(cv,b,wb,color)

# Estado da animacao da protagonista: marcha suavizada e fisica do busto.
# Guardado entre quadros para o movimento ter inercia (nada muda aos trancos).
var _anim_clock: float = -1.0
var _gait_phase: float = 0.0
var _gait_amt: float = 0.0
var _run_amt: float = 0.0
var _prev_anchor: Vector2 = Vector2.ZERO
var _prev_anchor_vel: Vector2 = Vector2.ZERO
var _bust_off: Array = [Vector2.ZERO, Vector2.ZERO]
var _bust_vel: Array = [Vector2.ZERO, Vector2.ZERO]

func _anim_step() -> float:
    ## Tempo real desde o ultimo desenho; congela fora do jogo (pausa, leitura).
    var now: float = g.real_time
    var dt: float = 0.0 if _anim_clock < 0.0 else clampf(now-_anim_clock,0.0,0.05)
    _anim_clock = now
    return dt if g.status == "playing" else 0.0

func _simulate_bust(dt: float, anchor: Vector2, part: float, lift: float) -> void:
    ## Cada seio e uma massa presa ao peito por uma mola amortecida: atrasa no
    ## passo, quica ao parar/arrancar e balanca depois que a lanterna passa.
    if dt <= 0.0:
        return
    var vel: Vector2 = (anchor-_prev_anchor)/dt
    if vel.length() > 900.0:   # teleporte (inicio, respawn): sem solavanco
        vel = Vector2.ZERO
        _prev_anchor_vel = Vector2.ZERO
    var acc: Vector2 = ((vel-_prev_anchor_vel)/dt).limit_length(700.0)
    _prev_anchor = anchor
    _prev_anchor_vel = vel
    var n: int = clampi(int(ceil(dt/0.004)),1,12)
    var h: float = dt/float(n)
    for i in range(2):
        var side: float = -1.0 if i == 0 else 1.0
        var w: float = 14.5 + 0.8*float(i)          # lados levemente diferentes
        var damp: float = 2.0*0.22*w
        var target: Vector2 = Vector2(side*part, lift)
        var o: Vector2 = _bust_off[i]
        var v: Vector2 = _bust_vel[i]
        for _s in range(n):
            var a: Vector2 = -(o-target)*w*w - v*damp - acc*Vector2(0.6,1.1)
            v += a*h
            o += v*h
        o = Vector2(clampf(o.x,-2.8,2.8), clampf(o.y,-3.2,3.6))
        _bust_off[i] = o
        _bust_vel[i] = v.limit_length(90.0)

func _breast(center: Vector2, rx: float, ry: float, side: float, color: Color) -> void:
    ## Gota arredondada: encosta suave em cima, mais cheia embaixo e um pouco
    ## voltada para fora, em vez de um circulo perfeito.
    var pts: PackedVector2Array = PackedVector2Array()
    for k in range(24):
        var a: float = TAU*float(k)/24.0
        var c: float = cos(a)
        var s: float = sin(a)
        var fy: float = ry*(1.0 + 0.12*maxf(0.0,s) - 0.16*maxf(0.0,-s))
        var fx: float = rx*(1.0 + 0.05*maxf(0.0,s))
        var p: Vector2 = Vector2(c*fx, s*fy)
        p.x += side*0.9*maxf(0.0,s)*absf(c)
        pts.append(center+p)
    cv.draw_colored_polygon(pts,color)

func _character() -> void:
    var center: Vector2 = screen(g.draw_player)
    if g.in_hiding:
        disc(cv,center + Vector2(0,-9),7,Color("b9a9df"))
        return
    var dt: float = _anim_step()
    # A protagonista (adulta) e desenhada em escala maior, para o gesto ficar legivel.
    # Formas curvas (splines, ovais e membros afunilados) em vez de blocos retos.
    const BODY_SCALE: float = 1.35
    cv.draw_set_transform(center, 0.0, Vector2(BODY_SCALE,BODY_SCALE))
    # Marcha: a amplitude e a cadencia mudam aos poucos, sem trancos ao parar,
    # arrancar ou passar de andar para correr.
    _gait_amt = move_toward(_gait_amt, 1.0 if g.moving else 0.0, dt*5.0)
    _run_amt = move_toward(_run_amt, 1.0 if g.running else 0.0, dt*4.0)
    var walk: float = smoothstep(0.0,1.0,_gait_amt)
    var run: float = _run_amt*walk
    if walk > 0.001:
        _gait_phase = fposmod(_gait_phase + dt*lerpf(8.0,13.5,_run_amt), TAU)
    var phase: float = _gait_phase
    var step: float = sin(phase)*walk
    var breath: float = sin(g.real_time*2.1)
    # Sobe no meio do apoio e desce quando as pernas se abrem; ao correr, mais.
    var bob: float = -absf(cos(phase))*lerpf(1.2,2.1,run)*walk + breath*0.4
    var hipx: float = -step*lerpf(1.2,0.8,run)     # quadril vai para a perna de apoio
    var shx: float = step*0.45                     # ombros em contraposicao
    var aim: Vector2 = Vector2((g.look.x-g.look.y)*SKEW_X,(g.look.x+g.look.y)*SKEW_Y).normalized()
    if aim.length_squared()<0.01:
        aim=Vector2.RIGHT
    var turn: float = clampf(aim.x,-1.0,1.0)        # para que lado ela olha
    var fear: float = clampf(g.dread,0.0,1.0)       # o rosto reage a entidade
    var skin: Color = Color("c08570")
    var skin_shade: Color = Color("9a6352")
    var hair: Color = Color("1d1424")
    var hair_mid: Color = Color("2a1d34")
    var hair_sheen: Color = Color(0.42,0.32,0.52,0.55)
    var blouse: Color = Color("6e4668")
    var cloth: Color = Color("864d71")
    var sleeve: Color = Color("754a60")
    var skirt: Color = Color("40335a")
    var stocking: Color = Color("1f2036")
    var boot: Color = Color("0f1220")
    # Proporcoes: cabeca menor (HK) e pescoco um pouco mais longo, ombros e
    # quadril com a mesma largura, cintura marcada e busto proporcional.
    const HK: float = 0.86
    # Pernas longas: tudo acima do quadril fica 7 unidades mais alto.
    # L = quadril (balanca para o apoio), U = tronco/ombros (contrapoe).
    var B: Vector2 = Vector2(0,bob-7.0)
    var L: Vector2 = B+Vector2(hipx,0)
    var U: Vector2 = B+Vector2(shx,0)
    var H: Vector2 = U+Vector2(turn*0.8+shx*0.3,-58.0)
    _oval(Vector2(hipx*0.3,1),14.0,6.0,Color(0,0,0,.42))
    # Cabelo comprido por tras: volume na nuca e mechas onduladas de tamanhos
    # diferentes, que afinam na ponta e balancam com atraso em relacao ao passo.
    var hs: float = sin(phase-0.8)*lerpf(1.6,2.4,run)*walk + sin(g.real_time*1.3)*0.5
    _oval(H+Vector2(0,-1.0)*HK,11.0*HK,11.5*HK,hair)
    _shape([H+Vector2(-10.5,-2)*HK,H+Vector2(10.5,-2)*HK,U+Vector2(12.5,-45),U+Vector2(-12.5,-45)],hair,false)
    for i in range(9):
        var u: float = float(i)/8.0
        var rx: float = lerpf(-11.5,11.5,u)
        var hlen: float = 22.0+fposmod(float(i)*13.7,7.0)
        var wv: float = sin(g.real_time*1.4+float(i)*0.8)*0.5
        var flare: float = (u-0.5)*4.5
        var root: Vector2 = H+Vector2(rx*0.85,-1.0)*HK
        strand(cv,[root,U+Vector2(rx+flare*0.3,-47),U+Vector2(rx+flare*0.7+hs*0.5+sin(float(i)*2.4)*0.7,-47+hlen*0.5),U+Vector2(rx+flare+hs+wv,-47+hlen)],2.6,0.25,hair if i%3 != 1 else hair_mid)
    # Pernas torneadas, de meia escura e botas. A perna que avanca dobra o
    # joelho e tira o pe do chao; a de apoio fica quase esticada.
    for side in [-1.0, 1.0]:
        var swing_leg: float = maxf(0.0,step*side)
        var lift: float = swing_leg*lerpf(3.0,4.6,run)
        var fwd: float = step*side*lerpf(2.2,3.0,run)
        var hip: Vector2 = L+Vector2(side*4.6,-24)
        var knee: Vector2 = Vector2(side*4.6+hipx*0.5+fwd*0.5,-16.0-lift*0.6)
        var ankle: Vector2 = Vector2(side*4.4+fwd*0.2,-2.6-lift)
        _limb(hip,knee,3.7,2.5,stocking)
        _limb(knee,ankle,2.5,1.6,stocking)
        _limb(ankle+Vector2(0,-3.4),ankle+Vector2(0,0.6),2.5,2.5,boot)
        _oval(ankle+Vector2(side*1.4,1.7),4.0,2.1,boot)
    # Saia rodada: segue o quadril e a barra acompanha com atraso, como tecido.
    var sk: float = sin(phase-0.6)*lerpf(1.4,2.0,run)*walk
    _shape([L+Vector2(-7.8,-31),L+Vector2(7.8,-31),L+Vector2(11,-25),L+Vector2(13+sk,-17),L+Vector2(7+sk,-14.6),L+Vector2(0,-15.4),L+Vector2(-7+sk,-14.6),L+Vector2(-13+sk,-17),L+Vector2(-11,-25)],skirt)
    for fx in [-4.0, 0.5, 4.5]:
        cv.draw_line(L+Vector2(fx,-28),L+Vector2(fx*1.7+sk,-16.0),skirt.darkened(0.28),0.9,true)
    cv.draw_line(L+Vector2(-11.5+sk,-17.2),L+Vector2(11.5+sk,-17.2),skirt.lightened(0.12),0.8,true)
    # Tronco em ampulheta: ombros (U) e quadril (L) se movem em sentidos opostos.
    var W: Vector2 = B+Vector2((hipx+shx)*0.5,0)
    _shape([U+Vector2(-10.5,-46),U+Vector2(0,-47.5),U+Vector2(10.5,-46),U+Vector2(11,-40),W+Vector2(6.8,-32.5),L+Vector2(8,-29.5),L+Vector2(-8,-29.5),W+Vector2(-6.8,-32.5),U+Vector2(-11,-40)],blouse)
    _limb(L+Vector2(-7.2,-30.4),L+Vector2(7.2,-30.4),1.4,1.4,Color("2a2038"))
    _oval(L+Vector2(0,-30.4),1.7,1.5,Color("c9a15d"))
    # Braco esquerdo solto, balancando ao contrario da perna (um pouco atrasado);
    # correndo, o cotovelo dobra e a mao sobe.
    var swing: float = -sin(phase-0.25)*walk*lerpf(2.6,3.6,run)
    var lel: Vector2 = U+Vector2(-15.0+swing*0.3,-35.0+run*1.2)
    var lhand: Vector2 = U+Vector2(-15.5+swing,-24.5-run*5.0)
    _limb(U+Vector2(-11,-44),lel,3.0,2.4,sleeve)
    _limb(lel,lhand,2.3,1.7,skin)
    _oval(lhand+Vector2(0,1.3),2.0,2.6,skin)
    # Pescoco e colo, visiveis no decote em V profundo.
    _limb(U+Vector2(0,-51.5),U+Vector2(0,-45.5),2.4,3.0,skin_shade)
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
    var chest: Vector2 = U + Vector2(0,-38.5-breath*0.25)
    var cleft: Vector2 = chest + Vector2(0,-2.6)             # onde a lanterna mora
    # Enquanto a lanterna passa, os seios se afastam e sao erguidos um pouco;
    # a mola (fisica) faz eles voltarem balancando quando ela sai ou entra.
    var part: float = sin(clampf((pose-0.10)/0.52,0.0,1.0)*PI) * 1.4
    var lift_up: float = -sin(clampf((pose-0.25)/0.35,0.0,1.0)*PI) * 1.1
    _simulate_bust(dt, project(g.draw_player)/BODY_SCALE + Vector2(shx,bob), part, lift_up)
    var o_avg: float = (_bust_off[0].y+_bust_off[1].y)*0.5
    _shape([chest+Vector2(-7.5,-7.2),chest+Vector2(0,-8.4),chest+Vector2(7.5,-7.2),chest+Vector2(4.2,-1),chest+Vector2(0,2.6),chest+Vector2(-4.2,-1)],skin,false)
    cv.draw_line(chest+Vector2(-6.2,-7.1),chest+Vector2(-1.6,-6.1),skin_shade,0.7,true)
    cv.draw_line(chest+Vector2(6.2,-7.1),chest+Vector2(1.6,-6.1),skin_shade,0.7,true)
    # Enquanto e puxada, a haste sobe verticalmente por tras do busto.
    if pose > 0.28 and pose <= 0.60:
        _flashlight(cleft+Vector2(0,1.0),cleft+Vector2(0,-2.0-16.0*extract),false)
    # Busto grande, mas em proporcao com ombros e quadril: forma de gota, peso
    # embaixo, levemente para fora. Estica e achata conforme a velocidade da mola.
    for i in range(2):
        var side: float = -1.0 if i == 0 else 1.0
        var o: Vector2 = _bust_off[i]
        var st: float = clampf((_bust_vel[i] as Vector2).y*0.004,-0.08,0.08)
        var b: Vector2 = chest + Vector2(side*6.3,0.6) + o
        var rx: float = 6.7*(1.0-st*0.5)
        var ry: float = 6.5*(1.0+st)
        _breast(b+Vector2(side*0.8,3.0),rx+0.3,ry+0.2,side,Color("4c2a45"))
        _breast(b,rx,ry,side,skin)
        _breast(b+Vector2(side*1.1,2.0),rx,ry*0.97,side,cloth)
        _oval(b+Vector2(side*1.5,5.0),4.9,2.4,Color(0.36,0.18,0.33,0.40))
        _oval(b+Vector2(side*2.3,-0.2)+o*0.2,2.8,1.9,Color(0.80,0.52,0.68,0.45),side*0.5)
        cv.draw_arc(b+Vector2(side*1.1,2.0),rx-0.2,-PI*0.5-side*1.25-0.55,-PI*0.5-side*1.25+0.55,10,Color("d79dae"),1.0,true)
    cv.draw_line(cleft+Vector2(0,-3.2),cleft+Vector2(0,4.4+o_avg*0.6),skin_shade,1.1+part*0.4,true)
    # ---------------- CABECA (coordenadas locais do rosto) ----------------
    cv.draw_set_transform(center+H*BODY_SCALE, 0.0, Vector2(BODY_SCALE*HK,BODY_SCALE*HK))
    # Rosto em formato de coracao: macas cheias, queixo delicado.
    _shape([Vector2(-8.2,-3.5),Vector2(-7.9,1.5),Vector2(-6.4,5.6),Vector2(-3.4,8.7),Vector2(0,9.8),Vector2(3.4,8.7),Vector2(6.4,5.6),Vector2(7.9,1.5),Vector2(8.2,-3.5),Vector2(5.8,-8.8),Vector2(0,-10.2),Vector2(-5.8,-8.8)],skin,false)
    _oval(Vector2(turn*0.8,8.4),3.0,0.9,Color(0.55,0.30,0.26,0.20))          # sombra sob o queixo
    for side in [-1.0, 1.0]:
        _oval(Vector2(side*4.9+turn*0.8,3.4),2.4,1.3,Color(0.90,0.42,0.48,0.20))
        _oval(Vector2(side*4.6+turn*0.8,1.6),1.5,0.7,Color(1.0,0.86,0.80,0.18))  # brilho da maca
        # Olhos grandes e amendoados, com delineado puxado para fora; arregalam
        # e as sobrancelhas sobem quando a criatura esta perto.
        var e: Vector2 = Vector2(side*3.4+turn*1.2,-0.7)
        var open: float = 1.0+0.55*fear
        _oval(e,2.5,1.45*open,Color("f6eeea"),-side*0.10)
        var iris: Vector2 = e+Vector2(turn*0.6,0.15)
        disc(cv,iris,minf(1.45,1.3*open),Color("3c2452"))
        disc(cv,iris+Vector2(0,0.25),minf(1.05,0.95*open),Color("7a4ea0"))
        disc(cv,iris,0.55,Color("0d0812"))
        disc(cv,iris+Vector2(-0.5,-0.5),0.38,Color.WHITE)
        disc(cv,iris+Vector2(0.45,0.45),0.18,Color(1,1,1,0.8))
        cv.draw_polyline(PackedVector2Array([e+Vector2(-side*2.6,0.1),e+Vector2(-side*1.2,-1.45*open),e+Vector2(side*1.2,-1.6*open),e+Vector2(side*2.7,-0.6),e+Vector2(side*3.6,-1.5)]),hair,1.0,true)
        cv.draw_polyline(PackedVector2Array([e+Vector2(-side*1.8,1.1),e+Vector2(side*0.4,1.45),e+Vector2(side*2.3,0.8)]),Color(0.35,0.20,0.25,0.45),0.5,true)
        cv.draw_polyline(PackedVector2Array([e+Vector2(-side*2.1,-3.2-1.4*fear),e+Vector2(side*0.6,-4.0-1.1*fear),e+Vector2(side*3.0,-3.4-0.3*fear)]),hair,0.75,true)
    # Nariz pequeno e suave.
    cv.draw_line(Vector2(turn*1.4,1.0),Vector2(turn*1.4+0.6,3.7),Color(0.55,0.33,0.28,0.55),0.6,true)
    disc(cv,Vector2(turn*1.4+0.2,4.1),0.5,Color(0.55,0.33,0.28,0.35))
    # Labios cheios: arco do cupido em cima, inferior mais carnudo com brilho.
    var m: Vector2 = Vector2(turn*1.1,6.3)
    var drop: float = 0.9*maxf(0.0,fear-0.45)/0.55
    if drop > 0.0:
        _oval(m+Vector2(0,0.55+drop*0.5),1.6,0.35+drop*0.6,Color("2a0d16"))
    poly([m+Vector2(-2.3,0.15),m+Vector2(-1.0,-0.75),m+Vector2(0,-0.4),m+Vector2(1.0,-0.75),m+Vector2(2.3,0.15),m+Vector2(0,0.4)],Color("a84b62"))
    poly([m+Vector2(-2.1,0.3+drop*0.3),m+Vector2(0,0.45+drop),m+Vector2(2.1,0.3+drop*0.3),m+Vector2(1.2,1.4+drop),m+Vector2(0,1.7+drop),m+Vector2(-1.2,1.4+drop)],Color("c2627a"))
    disc(cv,m+Vector2(-0.5,1.0+drop),0.35,Color(1,0.85,0.88,0.6))
    # Cabelo da frente: topo com volume, risca de lado e franja em mechas
    # que caem varrendo a testa.
    _shape([Vector2(-9.6,-1),Vector2(-10.2,-7),Vector2(-6.2,-12.4),Vector2(0,-13.6),Vector2(6.2,-12.4),Vector2(10.2,-7),Vector2(9.6,-1),Vector2(8.2,-6.6),Vector2(5.2,-9.4),Vector2(2.6,-10.0),Vector2(-2,-9.6),Vector2(-6,-8.4),Vector2(-8.4,-5)],hair)
    var fw: float = sin(g.real_time*1.2)*0.3 + hs*0.15
    strand(cv,[Vector2(2.4,-12.6),Vector2(-1.5,-10.2),Vector2(-5.2,-7.4),Vector2(-7.4+fw,-3.4)],1.7,0.2,hair)
    strand(cv,[Vector2(2.8,-12.4),Vector2(0.2,-10.6),Vector2(-2.6,-8.6),Vector2(-4.0+fw,-6.0)],1.2,0.15,hair_mid)
    strand(cv,[Vector2(3.4,-12.2),Vector2(6.0,-10.2),Vector2(7.8,-6.4),Vector2(8.4+fw,-2.4)],1.4,0.2,hair)
    strand(cv,[Vector2(1.6,-13.0),Vector2(-2.4,-12.0),Vector2(-6.4,-9.6)],0.45,0.1,hair_sheen)
    strand(cv,[Vector2(4.6,-12.6),Vector2(7.6,-10.4)],0.4,0.1,hair_sheen)
    cv.draw_set_transform(center, 0.0, Vector2(BODY_SCALE,BODY_SCALE))
    # Mechas da frente que descem pelos ombros e ondulam sobre o peito.
    for side in [-1.0, 1.0]:
        var wv: float = hs*0.5 + sin(g.real_time*1.5+side)*0.4
        strand(cv,[H+Vector2(side*9.2,-2.5)*HK,H+Vector2(side*9.6,4.0)*HK,U+Vector2(side*10.6+wv*0.5,-47),U+Vector2(side*11.4+wv,-41.5),U+Vector2(side*10.4+wv*1.2,-37.5)],1.9,0.2,hair)
        strand(cv,[H+Vector2(side*9.0,-3.5)*HK,H+Vector2(side*9.8,3.0)*HK,U+Vector2(side*11.0+wv*0.5,-46.5)],0.4,0.1,hair_sheen)
    # Braco direito: o ombro, o antebraco e os dedos acompanham o objeto.
    var rest: Vector2 = U+Vector2(15.5-swing,-24.5-run*5.0)
    var raised: Vector2 = cleft+Vector2(0,-9.0*extract)
    var ready: Vector2 = cleft+aim*31.0+Vector2(3,-6)
    var hand: Vector2 = rest.lerp(cleft,reach)
    if pose > 0.25:
        hand=cleft.lerp(raised,extract)
    if pose > 0.60:
        hand=raised.lerp(ready,extend)
    var shoulder: Vector2 = U+Vector2(11,-44)
    var elbow: Vector2 = shoulder.lerp(hand,0.51)+Vector2(6,5)
    _limb(shoulder,elbow,3.0,2.4,sleeve)
    _limb(elbow,hand,2.3,1.7,skin)
    # Ja fora do decote, a lanterna segue a mao e aponta para a mira.
    if pose > 0.60:
        _flashlight(hand-aim*3.0,hand+aim*15.0,g.light_on and pose > 0.86)
    _oval(hand,2.4,2.1,Color("d39a85"))
    # Sem efeito de transformacao nos objetos e HUD desenhados em seguida.
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _flashlight(from: Vector2, to: Vector2, glowing: bool) -> void:
    cv.draw_line(from,to,Color("4b3f5d"),8.3)
    cv.draw_line(from,to,Color("e1bd8c"),5.5)
    var spectral: bool = g.ghost_mode and g.light_on
    disc(cv,to,4.5,Color("b7a1ed") if spectral else Color("fbe4a3"))
    if glowing:
        disc(cv,to,7.8,Color(.72,.52,1,.25) if spectral else Color(1,.94,.62,.25))

func _monster() -> void:
    _afrodite(g.draw_monster, g.monster_lit, g.monster_state == "PERSEGUINDO" and not g.monster_lit)

func _afrodite(at: Vector2, lit: bool, chasing: bool) -> void:
    ## Afrodite pela metade: uma seita tentou traze-la por bruxaria e o ritual
    ## nao terminou, entao o que atravessou e uma deusa de marmore apodrecida,
    ## como se tivesse ficado presa no fundo do mar. Concha partida como aureola, cabelo encharcado ate os quadris,
    ## tunica grega em farrapos pingando agua preta, pele rachada com veias
    ## acesas e o peito aberto e costurado: falta nela o que ela tira das
    ## outras. Metade do rosto ainda e bela; a outra metade e osso.
    ## Criatura ficticia: nao reproduz o rosto de nenhuma pessoa real.
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
    var marble: Color = Color("d6cdc8") if lit else Color("8a8085")
    var marble_dk: Color = marble.darkened(0.38)
    var cloth: Color = Color("aaa298") if lit else Color("57535a")
    var rot: Color = Color("3b1220")
    var vein: Color = Color(0.85,0.10,0.22,0.85) if not lit else Color(0.55,0.08,0.16,0.8)
    var hair: Color = Color("07060a")
    var wet: Color = Color(0.03,0.06,0.07,0.85)
    var y: float = bob
    cv.draw_set_transform(base,0.0,Vector2(s,s))
    # Sombra e a poca que ela vai deixando.
    _oval(Vector2(0,1),23.0,8.0,Color(0,0,0,.55))
    _oval(Vector2(4,2),15.0,4.6,Color(0.04,0.08,0.09,0.65))
    # Cabelo comprido e encharcado, colado nas costas ate os quadris.
    # Massa arredondada nas costas e, dela, mechas onduladas de comprimentos
    # diferentes que afinam nas pontas e balancam com atraso.
    var hs: float = sin(t*1.3)*1.4
    var sheen: Color = Color(0.22,0.20,0.27,0.55)
    _shape([Vector2(-9,-79+y),Vector2(9,-79+y),Vector2(15,-66+y),Vector2(16,-52+y),Vector2(10,-46+y),Vector2(-10,-46+y),Vector2(-16,-52+y),Vector2(-15,-66+y)],hair,false)
    for i in range(9):
        var u: float = float(i)/8.0
        var rx: float = lerpf(-14.5,14.5,u)
        var hlen: float = 26.0+fposmod(float(i)*17.3,14.0)
        var sway: float = hs*(0.6+0.5*u)+sin(t*1.1+float(i)*0.9)*0.8
        var bend: float = (u-0.5)*5.0
        strand(cv,[Vector2(rx*0.8,-62+y),Vector2(rx+bend*0.4,-52+y),Vector2(rx+bend+sway*0.5+sin(float(i)*2.1)*1.2,-52+y+hlen*0.45),Vector2(rx+bend*1.3+sway,-52+y*0.6+hlen)],3.0,0.25,hair)
    for rx in [-9.0, 4.0, 11.0]:
        strand(cv,[Vector2(rx*0.8,-64+y),Vector2(rx,-54+y),Vector2(rx+hs*0.5+0.6,-40+y),Vector2(rx+hs+0.3,-30+y)],0.45,0.1,sheen)
    # Tronco de marmore magro demais: clavículas, cintura de vespa.
    _shape([Vector2(-11,-58+y),Vector2(0,-60+y),Vector2(11,-58+y),Vector2(10.5,-49+y),Vector2(6,-40+y),Vector2(-6,-40+y),Vector2(-10.5,-49+y)],marble,false)
    cv.draw_line(Vector2(-9,-57+y),Vector2(-1.5,-55.5+y),marble_dk,1.0,true)
    cv.draw_line(Vector2(9,-57+y),Vector2(1.5,-55.5+y),marble_dk,1.0,true)
    # O peito: duas cavidades abertas e costuradas com linha grossa.
    for side in [-1.0, 1.0]:
        var w: Vector2 = Vector2(side*5.0,-49.5+y)
        _oval(w,4.8,3.9,rot)
        _oval(w+Vector2(side*0.3,0.4),3.0,2.3,Color("120509"))
        for k in range(3):
            var sx: float = w.x-2.8+float(k)*2.8
            cv.draw_line(Vector2(sx-0.9,w.y-2.8),Vector2(sx+0.9,w.y+2.8),Color("c9bcae"),0.7,true)
        cv.draw_line(w+Vector2(side*0.5,3.2),w+Vector2(side*0.9,7.5+sin(t*2.0+side)*1.0),Color("4a0b17"),1.0,true)
    for i in range(3):
        var ry: float = -44.0+float(i)*1.9+y
        cv.draw_line(Vector2(-6.0+float(i)*0.5,ry),Vector2(-1.0,ry+0.9),marble_dk,0.8,true)
        cv.draw_line(Vector2(6.0-float(i)*0.5,ry),Vector2(1.0,ry+0.9),marble_dk,0.8,true)
    # Rachaduras com brilho vermelho por dentro.
    cv.draw_polyline(PackedVector2Array([Vector2(2,-59+y),Vector2(-1,-55+y),Vector2(1.5,-52+y),Vector2(-0.5,-45+y)]),vein,0.8,true)
    cv.draw_polyline(PackedVector2Array([Vector2(-10,-50+y),Vector2(-7,-47+y),Vector2(-8,-43+y)]),vein,0.7,true)
    # Tunica grega em farrapos, com cintura marcada e barra rasgada.
    poly([Vector2(-6.5,-43+y),Vector2(6.5,-43+y),Vector2(5.5,-38+y),Vector2(10,-29+y),Vector2(14,-14),Vector2(19,-2),Vector2(14,4),Vector2(10,-3),Vector2(5,6),Vector2(0,-1),Vector2(-5,5),Vector2(-9,-4),Vector2(-14,4),Vector2(-19,-1),Vector2(-14,-14),Vector2(-10,-29+y),Vector2(-5.5,-38+y)],cloth)
    _limb(Vector2(9.5,-57.5+y),Vector2(6.5,-41+y),2.3,3.0,cloth)    # alca no ombro
    for fx in [-6.0,-2.0,2.5,7.0]:
        cv.draw_line(Vector2(fx*0.6,-36+y),Vector2(fx*1.9,-3),cloth.darkened(0.3),0.9,true)
    cv.draw_line(Vector2(-6,-38.5+y),Vector2(6,-38.5+y),Color("3a2a1c"),1.4,true)
    # Barra encharcada, pingando, com algas presas.
    poly([Vector2(-15,-11),Vector2(0,-14),Vector2(15,-11),Vector2(19,-2),Vector2(14,4),Vector2(10,-3),Vector2(5,6),Vector2(0,-1),Vector2(-5,5),Vector2(-9,-4),Vector2(-14,4),Vector2(-19,-1)],wet)
    for dx in [-14.0,-5.0,5.0,14.0]:
        var drip: float = fposmod(t*1.6+dx*0.37,1.0)
        disc(cv,Vector2(dx,4.0+drip*5.0),0.9,Color(0.05,0.10,0.12,0.9*(1.0-drip)))
    for ax in [-11.0, 3.0, 12.0]:
        cv.draw_polyline(PackedVector2Array([Vector2(ax,-22+y*0.5),Vector2(ax+1.5+sin(t*1.9+ax),-13),Vector2(ax-0.5,-6),Vector2(ax+1.0+sin(t*2.3+ax)*1.5,3)]),Color("16261c"),1.2,true)
    # Bracos compridos de estatua; na perseguicao eles se estendem para a jogadora.
    var toward: Vector2 = (screen(g.draw_player)-base).normalized() if chasing else Vector2.ZERO
    for side in [-1.0, 1.0]:
        var sh: Vector2 = Vector2(side*11.0,-56+y)
        var el: Vector2 = Vector2(side*19.0,-36+y)
        var hd: Vector2 = Vector2(side*21.0,-12+y*0.5)
        if chasing:
            var grab: float = 0.75+0.25*sin(t*9.0+side)
            el = sh+toward*15.0+Vector2(side*7.0,5.0)
            hd = sh+toward*(31.0*grab)+Vector2(side*5.0,-2.0)
        _limb(sh,el,2.5,1.9,marble)
        _limb(el,hd,1.9,1.4,marble)
        cv.draw_line(el+Vector2(-1,-2),el+Vector2(1.5,2.5),vein,0.6,true)
        var reach: Vector2 = (hd-el).normalized()
        _oval(hd+reach*1.5,2.2,1.7,marble,reach.angle())
        for f in [-0.5,-0.17,0.17,0.5]:
            var knuckle: Vector2 = hd+reach.rotated(f)*6.5
            var tip: Vector2 = knuckle+reach.rotated(f*1.3)*4.0
            cv.draw_line(hd+reach*1.5,knuckle,marble,1.1,true)
            cv.draw_line(knuckle,tip,Color("0a0508"),1.3,true)         # unhas pretas compridas
            disc(cv,tip,0.6,Color("5c0f1d"))
    # Pescoco comprido e quebrado; a cabeca pende para os lados.
    _limb(Vector2(0,-60+y),Vector2(0,-65+y),2.2,2.0,marble)
    cv.draw_set_transform(base+Vector2(0,-65+y)*s,tilt,Vector2(s,s))
    # Aureola: a concha de Venus, rachada e com um pedaco arrancado.
    var shell: Color = Color("a8928f") if lit else Color("5b4a50")
    var fan: PackedVector2Array = PackedVector2Array([Vector2(0,-8)])
    for k in range(17):
        var a: float = PI+0.2+(PI-0.4)*float(k)/16.0
        var r: float = 19.0+1.8*float(k%2)
        if k >= 10 and k <= 12:
            r *= 0.62+0.1*float(k%2)        # o pedaco que falta
        fan.append(Vector2(0,-8)+Vector2.from_angle(a)*r)
    cv.draw_colored_polygon(fan,shell)
    for k in range(0,17,2):
        cv.draw_line(Vector2(0,-8),fan[k+1],shell.darkened(0.4),0.8,true)
    # Cabelo molhado colado no cranio, com risca no meio e linha irregular.
    _shape([Vector2(-10.5,-6),Vector2(-10,-14),Vector2(-6,-19.5),Vector2(0,-21),Vector2(6,-19.5),Vector2(10,-14),Vector2(10.5,-6),Vector2(8.5,1),Vector2(-8.5,1)],hair,false)
    # Rosto de deusa: oval, queixo fino, marmore sujo.
    _shape([Vector2(-7.5,-12),Vector2(-8,-6),Vector2(-7,0),Vector2(-4,4.5),Vector2(0,6),Vector2(4,4.5),Vector2(7,0),Vector2(8,-6),Vector2(7.5,-12),Vector2(4.5,-16.5),Vector2(0,-17.5),Vector2(-4.5,-16.5)],marble,false)
    # Metade direita descarnada: carne viva e osso do maxilar.
    poly([Vector2(0.8,-5),Vector2(6.5,-9),Vector2(7.9,-5),Vector2(7,0),Vector2(4,4.5),Vector2(0.8,5.8)],rot)
    cv.draw_line(Vector2(2,3.8),Vector2(6.6,-1),Color("cfc4b8"),0.9,true)
    var eyes: Color = Color("c7f3ff") if lit else Color("ff3b6b")
    # Olho esquerdo: ainda bonito, com cilios longos, mas a esclera e preta.
    var le: Vector2 = Vector2(-3.5,-8.5)
    _oval(le,2.6,1.4,Color("050307"))
    disc(cv,le+Vector2(0.2,0.1),0.95,eyes)
    for k in range(4):
        var lx: float = le.x-2.2+float(k)*1.4
        cv.draw_line(Vector2(lx,le.y-1.2),Vector2(lx-1.0,le.y-2.6),Color("050307"),0.5,true)
    cv.draw_polyline(PackedVector2Array([le+Vector2(-2.8,-2.9),le+Vector2(0,-3.9),le+Vector2(2.6,-3.2)]),Color("120c14"),0.8,true)
    # Olho direito: orbita vazia, so uma brasa la no fundo.
    var re: Vector2 = Vector2(3.6,-8.5)
    disc(cv,re,2.9,Color("050307"))
    disc(cv,re+Vector2(0,0.4),0.9,eyes)
    for side in [-1.0, 1.0]:
        var ex: float = side*3.5
        cv.draw_line(Vector2(ex,-7),Vector2(ex+side*0.4,1.0+sin(t*2.0+side)*1.2),Color("050307"),0.9,true)
    cv.draw_line(Vector2(0,-6.5),Vector2(-0.6,-2.5),marble_dk,0.7,true)
    # Boca: labio vermelho de um lado, rasgo ate a orelha do outro.
    poly([Vector2(-3.6,0.6),Vector2(-1.2,-0.2),Vector2(0,0.2),Vector2(0.6,1.6),Vector2(-1.4,2.2)],Color("6b0f22"))
    poly([Vector2(0,0.4),Vector2(4,-1.2),Vector2(7.6,-4.4),Vector2(6.4,0.6),Vector2(3.4,2.4),Vector2(0.4,1.8)],Color("070305"))
    for k in range(5):
        var tx: float = 1.2+float(k)*1.3
        var ty: float = 0.6-float(k)*0.95
        cv.draw_line(Vector2(tx,ty),Vector2(tx,ty+1.4),Color("e6dccf"),0.6,true)
    cv.draw_polyline(PackedVector2Array([Vector2(-2,-17.4),Vector2(-1,-14),Vector2(-2.5,-11.5)]),vein,0.6,true)
    # Mechas encharcadas caindo pelos lados (uma atravessa a metade podre).
    # Cada mecha sai da risca, contorna a testa e cai ondulando pelos ombros.
    for hx in [-10.5,-8.8,-7.2,7.0,8.6,10.2]:
        var sd: float = signf(hx)
        var hl: float = 14.0+fposmod(absf(hx)*7.3,10.0)
        var wv: float = sin(t*1.7+hx)*1.3
        strand(cv,[Vector2(sd*1.0,-20.5),Vector2(hx*0.85,-14),Vector2(hx+sd*0.6,-4),Vector2(hx+wv*0.5-sd*0.4,4),Vector2(hx+sd*1.2+wv,hl)],1.5,0.15,hair)
    # Uma mecha fina cai na frente da metade podre do rosto.
    strand(cv,[Vector2(1.0,-20),Vector2(4.0,-14),Vector2(5.2,-6),Vector2(4.4+sin(t*1.5)*0.6,2.0),Vector2(5.4+sin(t*1.5)*1.0,9.0)],0.8,0.1,hair)
    strand(cv,[Vector2(-1.0,-20.5),Vector2(-6.5,-17),Vector2(-9.2,-10)],0.35,0.1,sheen)
    cv.draw_set_transform(base,0.0,Vector2(s,s))
    if lit:
        cv.draw_arc(Vector2(0,-42),42,0,TAU,40,Color(.65,.83,1.0,.30),1.6)
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _vulto(v: Dictionary) -> void:
    # Vulto: silhueta que some quando se olha para ela (so com a casa iluminada).
    var p: Vector2 = screen(v["at"])
    var a: float = clampf(minf(float(v["ttl"]),float(v["life"])-float(v["ttl"]))/0.35,0.0,1.0)*0.5
    poly([p+Vector2(-13,0),p+Vector2(-10,-46),p+Vector2(-5,-62),p+Vector2(5,-62),p+Vector2(10,-46),p+Vector2(13,0)],Color(0.02,0.01,0.05,a))
    disc(cv,p+Vector2(0,-64),9.0,Color(0.02,0.01,0.05,a))

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
    if g.foyer_sealed():
        # Porta do salao trancada: so o vestibulo (e as paredes em volta dele)
        # tem a luz da casa; o resto da mansao fica no escuro do jogo.
        for room in g.map.rooms:
            if room["name"] != "VESTÍBULO":
                continue
            var x0: float = float(int(room["x"])-1)*TS
            var y0: float = float(int(room["y"])-1)*TS
            var x1: float = float(int(room["x"])+int(room["w"])+1)*TS
            var y1: float = float(int(room["y"])+int(room["h"])+1)*TS
            var lvl: float = g.foyer_light_level()
            c.draw_colored_polygon(PackedVector2Array([screen(Vector2(x0,y0)),screen(Vector2(x1,y0)),screen(Vector2(x1,y1)),screen(Vector2(x0,y1))]),Color(lvl,lvl,lvl))
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
        var phasing: bool = g.spectral_open()
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
            var hit_at: Vector2 = g.map.ray_end(g.draw_player,ang,r,phasing)
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
                _blob(c,screen(h["at"])+Vector2(0,-88),44.0,104.0,1.0)
        for m in g.mannequins:
            if g.is_illuminated(m["at"]):
                _blob(c,screen(m["at"])+Vector2(0,-44),42.0,54.0,1.0)
    # Na luz espectral, Paredes e Costuras Espectrais brilham sozinhas por perto:
    # da para acha-las mesmo fora do facho.
    if g.spectral_open():
        for cell in g.map.spectral:
            var wc: Vector2 = g.map.cell_center(cell.x,cell.y)
            if g.draw_player.distance_to(wc) < 620.0:
                _blob(c,screen(wc)+Vector2(0,-12),42.0,34.0,0.8)
        for portal in g.portals:
            for end in [portal["a"],portal["b"]]:
                if g.draw_player.distance_to(end) < 620.0:
                    _blob(c,screen(end)+Vector2(0,-26),34.0,40.0,0.75)
    # As velas do altar seguram um resto de luz; o ritual incendeia o circulo.
    if not g.power_on:
        var altar_glow: Vector2 = screen(g.altar_at())+Vector2(0,-14)
        if g.ritual_running:
            _blob(c,altar_glow,150.0,100.0,0.95)
        else:
            _blob(c,altar_glow,74.0,50.0,0.30+0.05*sin(g.real_time*7.0))
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
        var p: Vector2 = screen(g.altar_at())
        for i in range(9):
            var ang: float = TAU*float(i)/9.0 + g.time_passed*1.7
            disc(cv,p+Vector2(cos(ang)*44.0,sin(ang)*20.0-22),3.0,Color("eeb3d9"))
        # As tres sacrificadas se erguem em volta do altar para levar Afrodite de volta.
        var progress: float = 1.0-g.ritual_left/g.CFG.RITUAL_SECONDS
        for i in range(3):
            var ga: float = TAU*float(i)/3.0+PI/6.0
            var gp: Vector2 = p+Vector2(cos(ga)*66.0,sin(ga)*31.0)+Vector2(0,-3.0*sin(g.real_time*2.0+float(i)))
            var al: float = clampf(0.18+0.55*progress+0.08*sin(g.real_time*3.0+float(i)*2.0),0.0,0.85)
            var pale: Color = Color(.84,.90,1.0,al)
            poly([gp+Vector2(-11,0),gp+Vector2(-13,-30),gp+Vector2(-7,-48),gp+Vector2(7,-48),gp+Vector2(13,-30),gp+Vector2(11,0),gp+Vector2(4,-6),gp+Vector2(-4,-5)],pale)
            disc(cv,gp+Vector2(0,-56),8.0,pale)
            disc(cv,gp+Vector2(-3,-57),1.6,Color(0,0,0,al))
            disc(cv,gp+Vector2(3,-57),1.6,Color(0,0,0,al))
            # O vazio no peito, onde a seita cortou.
            cv.draw_line(gp+Vector2(-7,-38),gp+Vector2(7,-38),Color(.35,.03,.09,al),2.4)
            _text(gp+Vector2(-18,-70),str(g.VICTIMS[i]["name"]),10,Color(.88,.92,1.0,al))

func draw_world() -> void:
    if floor_texture != null:
        cv.draw_texture(floor_texture, floor_origin - g.camera)
        _cached_floor_details()
    else:
        _floor()
    _decals()
    _portal_threads()
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
                if not g.map.is_wall_cell(x,y) or g.map.is_spectral_cell(x,y):
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
    for portal in g.portals:
        for endpoint in [portal["a"],portal["b"]]:
            if _onscreen(screen(endpoint),90):
                entities.append({"kind":"portal","at":endpoint,"z":project(endpoint).y-g.camera.y})
    # Paredes Espectrais ficam fora do cache: sao desenhadas a cada quadro,
    # na mesma profundidade das outras paredes.
    for cell in g.map.spectral:
        var wc: Vector2 = g.tile(cell.x,cell.y)
        if _onscreen(screen(wc),90):
            entities.append({"kind":"spectral","cell":cell,"z":project(wc).y-g.camera.y})
    for bottle in g.thrown_bottles:
        if _onscreen(screen(bottle["at"]),90):
            entities.append({"kind":"bottle","at":bottle["at"],"z":project(bottle["at"]).y-g.camera.y})
    # Com a porta do salao trancada, os manequins da oficina nao aparecem por
    # cima da parede iluminada do vestibulo (eles ficam no escuro de verdade).
    for m in g.mannequins:
        if _onscreen(screen(m["at"]),90) and not g.foyer_sealed():
            entities.append({"kind":"mannequin","data":m,"z":project(m["at"]).y-g.camera.y})
    if not g.monster_banished and not g.foyer_sealed():
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
            "spectral": _spectral_wall(entity["cell"])
            "bottle": _bottle(entity["at"])
            "monster": _monster()
            "apparition": _afrodite(g.apparition["at"],g.is_illuminated(g.apparition["at"]),false)
            "mannequin": _mannequin(entity["data"])
            "hanged": _hanged(entity["data"])
            "vulto": _vulto(entity["data"])
            "hero": _character()
            "door": _labeled_door()
    _clues_and_ritual()
    # Gradiente sombrio de vinheta em quatro faixas discretas.
    cv.draw_rect(Rect2(0,0,32,VIEW_HEIGHT),Color(0,0,.02,.23))
    cv.draw_rect(Rect2(VIEW_WIDTH-32,0,32,VIEW_HEIGHT),Color(0,0,.02,.23))

# =====================================================================
# CENARIO: piso e paredes com o acabamento de cada comodo.
# Desenhados uma vez por tools/bake_scenery.gd e salvos em
# assets/render_cache (o jogo so cola as imagens prontas).
# =====================================================================
const ROOM_STYLE: Dictionary = {"BIBLIOTECA":"library","COZINHA":"kitchen","QUARTO":"bedroom","OFICINA":"workshop","SALÃO":"hall","VESTÍBULO":"foyer"}

func _h(a: float, b: float) -> float:
    ## Ruido deterministico (o mesmo valor sempre que o cache for refeito).
    return fposmod(sin(a*12.9898+b*78.233)*43758.5453,1.0)

func room_style(x: int, y: int) -> String:
    for room in g.map.rooms:
        if x >= int(room["x"]) and x < int(room["x"])+int(room["w"]) and y >= int(room["y"]) and y < int(room["y"])+int(room["h"]):
            return ROOM_STYLE.get(room["name"],"corridor")
    return "corridor"

func _static_wall(x: int, y: int) -> bool:
    if x < 0 or y < 0 or x >= ManorMap.W or y >= ManorMap.H:
        return true
    return g.map.cells[y][x] == 1

func _fw(x: float, y: float) -> Vector2:
    return screen(Vector2(x,y))

func _fquad(x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
    poly([_fw(x0,y0),_fw(x1,y0),_fw(x1,y1),_fw(x0,y1)],col)

func _fline(x0: float, y0: float, x1: float, y1: float, col: Color, w: float = 1.0) -> void:
    cv.draw_line(_fw(x0,y0),_fw(x1,y1),col,w,true)

func bake_floor(size: Vector2) -> void:
    ## Piso inteiro da mansao, com o padrao proprio de cada comodo.
    cv.draw_rect(Rect2(Vector2.ZERO,size),Color("080d17"))
    for y in range(ManorMap.H):
        for x in range(ManorMap.W):
            if _static_wall(x,y):
                _fquad(x*TS,y*TS,(x+1)*TS,(y+1)*TS,Color("101925"))
            else:
                _floor_cell(x,y,room_style(x,y))
    _rugs()

func _planks(X: float, Y: float, base: Color, along_x: bool, rows: int, seed: float) -> void:
    ## Tabuas corridas: emendas desencontradas, tons variados, veio e frestas.
    var bw: float = float(TS)/float(rows)
    for k in range(rows):
        var row: int = int((Y if along_x else X)/bw)+k
        var a0: float = X if along_x else Y
        var off: float = fposmod(float(row)*21.0,64.0)
        var joint: float = ceil((a0-off)/64.0)*64.0+off
        var cuts: Array = [a0]
        if joint > a0+0.5 and joint < a0+TS-0.5:
            cuts.append(joint)
        cuts.append(a0+TS)
        for c in range(cuts.size()-1):
            var s0: float = cuts[c]
            var s1: float = cuts[c+1]
            var tone: float = _h(float(row)+seed,floor((s0+1.0-off)/64.0))
            var col: Color = base.lerp(base.lightened(0.22),tone*0.7).darkened(0.08*_h(float(row),seed))
            var b0: float = (Y if along_x else X)+k*bw
            if along_x:
                _fquad(s0,b0,s1,b0+bw,col)
                cv.draw_line(_fw(s0+3,b0+bw*0.45),_fw(s1-3,b0+bw*0.55),col.darkened(0.16),0.6,true)
                if s0 > a0:
                    _fline(s0,b0,s0,b0+bw,Color(0,0,0,0.45),1.0)
            else:
                _fquad(b0,s0,b0+bw,s1,col)
                cv.draw_line(_fw(b0+bw*0.45,s0+3),_fw(b0+bw*0.55,s1-3),col.darkened(0.16),0.6,true)
                if s0 > a0:
                    _fline(b0,s0,b0+bw,s0,Color(0,0,0,0.45),1.0)
        if along_x:
            _fline(X,Y+k*bw,X+TS,Y+k*bw,Color(0,0,0,0.38),1.0)
        else:
            _fline(X+k*bw,Y,X+k*bw,Y+TS,Color(0,0,0,0.38),1.0)

func _floor_cell(x: int, y: int, style: String) -> void:
    var X: float = float(x*TS)
    var Y: float = float(y*TS)
    var n: float = _h(float(x),float(y))
    match style:
        "library":
            _planks(X,Y,Color("3a291e"),true,4,1.0)
        "bedroom":
            _planks(X,Y,Color("45302a"),false,4,2.0)
        "corridor":
            _planks(X,Y,Color("33292a"),true,3,3.0)
            if n > 0.8:
                _fquad(X+6,Y+9,X+20,Y+16,Color(0,0,0,0.18))     # tabua gasta
        "kitchen":
            # Ladrilhinho hidraulico creme, encardido, com rejunte escuro.
            for j in range(4):
                for i in range(4):
                    var col: Color = Color("6b6a5e").darkened(0.22*_h(float(x*4+i),float(y*4+j)))
                    _fquad(X+i*8,Y+j*8,X+i*8+8,Y+j*8+8,col)
            for k in range(1,4):
                _fline(X,Y+k*8,X+TS,Y+k*8,Color(0.1,0.1,0.08,0.55),0.7)
                _fline(X+k*8,Y,X+k*8,Y+TS,Color(0.1,0.1,0.08,0.55),0.7)
            if n > 0.86:
                disc(cv,_fw(X+10+n*12,Y+14),3.5,Color(0.30,0.03,0.07,0.45))
        "workshop":
            # Cimento queimado: manchas de oleo, pontinhos e rachaduras.
            _fquad(X,Y,X+TS,Y+TS,Color("37383d").lerp(Color("2d2e33"),n))
            for k in range(7):
                disc(cv,_fw(X+_h(n,float(k))*TS,Y+_h(float(k),n)*TS),0.7,Color(0.6,0.6,0.62,0.18))
            if n > 0.78:
                cv.draw_polyline(PackedVector2Array([_fw(X+2,Y+8+n*10),_fw(X+11,Y+12),_fw(X+18,Y+9+n*6),_fw(X+30,Y+16)]),Color(0,0,0,0.5),0.9,true)
            if _h(float(y),float(x)) > 0.96:
                var oc: Vector2 = _fw(X+16,Y+16)
                cv.draw_set_transform(oc,0.0,Vector2(1.0,0.5))
                disc(cv,Vector2.ZERO,12.0,Color(0.04,0.04,0.06,0.45))
                disc(cv,Vector2(3,1),7.0,Color(0.02,0.02,0.04,0.35))
                cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
        "hall":
            # Marmore em placas grandes, alternadas, com veios.
            var col: Color = Color("433e4b") if (x+y)%2 == 0 else Color("3b3744")
            _fquad(X,Y,X+TS,Y+TS,col.darkened(0.06*n))
            var v0: float = _h(n,7.0)
            cv.draw_polyline(PackedVector2Array([_fw(X,Y+v0*TS),_fw(X+10,Y+v0*TS*0.7+6),_fw(X+20,Y+v0*TS*0.9+3),_fw(X+TS,Y+_h(v0,3.0)*TS)]),Color(0.82,0.78,0.86,0.10),0.8,true)
        "foyer":
            # Xadrez preto e branco de entrada de casarao, com filete.
            for j in range(2):
                for i in range(2):
                    var dark: bool = ((x*2+i)+(y*2+j))%2 == 1
                    _fquad(X+i*16,Y+j*16,X+i*16+16,Y+j*16+16,Color("221f28") if dark else Color("5b5662"))
            _fquad(X+15,Y+15,X+17,Y+17,Color("8a7650"))
    # Rejunte da celula.
    _fline(X,Y,X+TS,Y,Color(0.02,0.03,0.06,0.28),1.0)
    _fline(X,Y,X,Y+TS,Color(0.02,0.03,0.06,0.28),1.0)

func _rug(x0: float, y0: float, x1: float, y1: float, field: Color, border: Color, trim: Color, fringe_on_y: bool) -> void:
    ## Tapete persa: barra, filetes dourados, medalhoes e franja nas pontas.
    _fquad(x0,y0,x1,y1,border)
    _fquad(x0+5,y0+5,x1-5,y1-5,field)
    for inset in [3.0, 6.5]:
        var a: float = inset
        cv.draw_polyline(PackedVector2Array([_fw(x0+a,y0+a),_fw(x1-a,y0+a),_fw(x1-a,y1-a),_fw(x0+a,y1-a),_fw(x0+a,y0+a)]),trim,0.9,true)
    var long_y: bool = (y1-y0) > (x1-x0)
    var length: float = (y1-y0) if long_y else (x1-x0)
    var count: int = maxi(1,int(length/64.0))
    var cx: float = (x0+x1)*0.5
    var cy: float = (y0+y1)*0.5
    var r: float = minf(x1-x0,y1-y0)*0.28
    for i in range(count):
        var t: float = (float(i)+0.5)/float(count)
        var mx: float = cx if long_y else lerpf(x0,x1,t)
        var my: float = lerpf(y0,y1,t) if long_y else cy
        # Medalhao redondo no plano do piso (elipse na tela), em tons do proprio tapete.
        var ring: PackedVector2Array = PackedVector2Array()
        var core: PackedVector2Array = PackedVector2Array()
        for k in range(24):
            var a: float = TAU*float(k)/24.0
            ring.append(_fw(mx+cos(a)*r,my+sin(a)*r))
            core.append(_fw(mx+cos(a)*r*0.5,my+sin(a)*r*0.5))
        cv.draw_colored_polygon(ring,border.lightened(0.04))
        cv.draw_colored_polygon(core,field.lightened(0.08))
        ring.append(ring[0])
        cv.draw_polyline(ring,Color(trim.r,trim.g,trim.b,0.55),0.8,true)
        for k in range(4):
            var a2: float = TAU*float(k)/4.0
            _fline(mx+cos(a2)*r*0.5,my+sin(a2)*r*0.5,mx+cos(a2)*r*1.25,my+sin(a2)*r*1.25,Color(trim.r,trim.g,trim.b,0.45),0.8)
    # Franja nas duas pontas.
    var steps: int = int(((x1-x0) if fringe_on_y else (y1-y0))/3.0)
    for i in range(steps+1):
        var f: float = float(i)/float(steps)
        if fringe_on_y:
            var fx: float = lerpf(x0+1,x1-1,f)
            _fline(fx,y0,fx,y0-3.5,trim.darkened(0.2),0.7)
            _fline(fx,y1,fx,y1+3.5,trim.darkened(0.2),0.7)
        else:
            var fy: float = lerpf(y0+1,y1-1,f)
            _fline(x0,fy,x0-3.5,fy,trim.darkened(0.2),0.7)
            _fline(x1,fy,x1+3.5,fy,trim.darkened(0.2),0.7)

func _rugs() -> void:
    # Passadeira do salao ate o altar, tapete do quarto e da biblioteca.
    _rug(26.5*TS-26,13*TS,26.5*TS+26,26.8*TS,Color("4a1820"),Color("2c0e14"),Color("a2844e"),true)
    _rug(2.4*TS,19.0*TS,9.6*TS,26.2*TS,Color("5a2028"),Color("33121a"),Color("9c7c4c"),false)
    _rug(6.5*TS,7.6*TS,14.5*TS,11.6*TS,Color("1f3a30"),Color("142820"),Color("8c7a4a"),false)

# ------------------------------- PAREDES -------------------------------
var _wall_stretch: float = 1.0   # escala vertical dos acabamentos (so dentro de _wall_face)

func _wpt(at: Vector2, side: int, u: float, z: float) -> Vector2:
    ## Ponto numa face de parede: side 0 = face +y, 1 = face +x;
    ## u vai da esquerda (0) para a direita (1) na tela, z e a altura.
    if side == 0:
        return _wp(at,-16.0+32.0*u,16.0,z*_wall_stretch)
    return _wp(at,16.0,16.0-32.0*u,z*_wall_stretch)

func _wq(at: Vector2, side: int, u0: float, u1: float, z0: float, z1: float, col: Color) -> void:
    poly([_wpt(at,side,u0,z0),_wpt(at,side,u1,z0),_wpt(at,side,u1,z1),_wpt(at,side,u0,z1)],col)

func _wl(at: Vector2, side: int, u0: float, z0: float, u1: float, z1: float, col: Color, w: float = 1.0) -> void:
    cv.draw_line(_wpt(at,side,u0,z0),_wpt(at,side,u1,z1),col,w,true)

func bake_wall(x: int, y: int) -> void:
    ## Um bloco de parede, com cada face vestida pelo comodo para onde olha.
    var at: Vector2 = g.tile(x,y)
    for side in [0, 1]:
        var nx: int = x if side == 0 else x+1
        var ny: int = y+1 if side == 0 else y
        var style: String = "exterior" if _static_wall(nx,ny) else room_style(nx,ny)
        _wall_face(at,side,style,x,y)
    var H: float = WALL_HEIGHT
    poly([_wp(at,-16,-16,H),_wp(at,16,-16,H),_wp(at,16,16,H),_wp(at,-16,16,H)],Color("1b202c"))
    cv.draw_line(_wp(at,-16,16,H),_wp(at,16,16,H),Color(0.75,0.70,0.68,0.22),1.0,true)
    cv.draw_line(_wp(at,16,16,H),_wp(at,16,-16,H),Color(0.75,0.70,0.68,0.14),1.0,true)

func _wall_face(at: Vector2, side: int, style: String, x: int, y: int) -> void:
    # Os acabamentos foram desenhados para WALL_BASE e esticam ate WALL_HEIGHT:
    # lambri, papel de parede e tijolos mantem a proporcao na parede mais alta.
    var H: float = WALL_BASE
    _wall_stretch = WALL_HEIGHT/WALL_BASE
    var k: float = 0.10 if side == 0 else 0.30          # face +x recebe menos luz
    var n: float = _h(float(x*7+side),float(y*3))
    match style:
        "library":
            # Papel de parede verde com arabescos, lambri de madeira embaixo.
            _wq(at,side,0,1,0,H,Color("26382f").darkened(k))
            for r in range(4):
                var z: float = 17.0+float(r)*5.5
                for i in range(4):
                    var u: float = (float(i)+0.25+0.5*float(r%2))/4.0
                    if u < 0.95:
                        poly([_wpt(at,side,u-0.03,z),_wpt(at,side,u,z+2.2),_wpt(at,side,u+0.03,z),_wpt(at,side,u,z-2.2)],Color("3c5546").darkened(k))
            _wq(at,side,0,1,0,14,Color("3d2a1f").darkened(k))
            for pu in [[0.07,0.45],[0.55,0.93]]:
                _wq(at,side,pu[0],pu[1],3,11,Color("33231a").darkened(k))
                _wl(at,side,pu[0],11,pu[1],11,Color("5a4030").darkened(k),0.8)
            _wl(at,side,0,14,1,14,Color("6b4a33").darkened(k),1.6)
            _wl(at,side,0,H-1,1,H-1,Color("7a6440").darkened(k),1.2)
        "kitchen":
            # Azulejo de metro encardido, com sujeira escorrida.
            _wq(at,side,0,1,0,H,Color("6c7069").darkened(k))
            var row: int = 0
            var z: float = 3.0
            while z < H-1:
                var off: float = 0.0 if row%2 == 0 else 1.0/6.0
                _wl(at,side,0,z,1,z,Color(0.15,0.16,0.15,0.55),0.7)
                for i in range(4):
                    var u: float = off+float(i)/3.0
                    if u > 0.01 and u < 0.99:
                        _wl(at,side,u,z,u,minf(z+4.5,H),Color(0.15,0.16,0.15,0.55),0.7)
                z += 4.5
                row += 1
            _wq(at,side,0,1,0,3,Color("2a2622").darkened(k))
            _wq(at,side,0,1,3,10,Color(0.12,0.10,0.06,0.30))
            if n > 0.6:
                _wl(at,side,n*0.8,H-2,n*0.8+0.02,H-14-n*8,Color(0.22,0.15,0.08,0.45),1.4)
            if n > 0.88:
                for d in range(4):
                    disc(cv,_wpt(at,side,0.3+_h(n,float(d))*0.4,8+_h(float(d),n)*14),0.8+_h(float(d),2.0),Color(0.35,0.03,0.08,0.7))
        "bedroom":
            # Papel listrado rosa-velho com florzinhas; alguns quadros.
            _wq(at,side,0,1,0,H,Color("4b3440").darkened(k))
            for i in range(6):
                var u0: float = float(i)/6.0
                _wq(at,side,u0,u0+1.0/12.0,3,H,Color("57404c").darkened(k))
                for r in range(5):
                    disc(cv,_wpt(at,side,u0+1.0/24.0,8+float(r)*6.0+float(i%2)*3.0),0.7,Color(0.78,0.55,0.62,0.35))
            _wq(at,side,0,1,0,3.5,Color("3a2620").darkened(k))
            _wl(at,side,0,3.5,1,3.5,Color("5a3c30").darkened(k),1.0)
            if n > 0.8 and side == 0:
                _wq(at,side,0.28,0.72,15,31,Color("6e5636").darkened(k))
                _wq(at,side,0.33,0.67,17,29,Color("1a1418"))
                var fc: Vector2 = _wpt(at,side,0.5,23.5)
                cv.draw_set_transform(fc,0.0,Vector2(0.8,1.0))
                disc(cv,Vector2.ZERO,3.0,Color(0.62,0.56,0.55,0.55))
                disc(cv,Vector2(-1.1,-0.6),0.5,Color(0,0,0,0.8))
                disc(cv,Vector2(1.1,-0.6),0.5,Color(0,0,0,0.8))
                cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
            elif n > 0.65:
                poly([_wpt(at,side,0.55,H-3),_wpt(at,side,0.8,H-4),_wpt(at,side,0.74,H-12),_wpt(at,side,0.6,H-9)],Color("6e6268").darkened(k))
        "workshop":
            # Tijolo aparente fuligento.
            _wq(at,side,0,1,0,H,Color("3a2f2c").darkened(k))
            var r2: int = 0
            var z2: float = 0.5
            while z2 < H-0.5:
                var off2: float = 0.0 if r2%2 == 0 else 0.25
                for i in range(-1,3):
                    var u0: float = off2+float(i)*0.5
                    var a: float = clampf(u0+0.02,0.0,1.0)
                    var b: float = clampf(u0+0.48,0.0,1.0)
                    if b-a > 0.02:
                        var tone: float = _h(float(x*4+i+side*13),float(y*9+r2))
                        _wq(at,side,a,b,z2,minf(z2+3.4,H),Color("6a3c31").lerp(Color("7c4a3a"),tone).darkened(k+0.2*_h(tone,1.0)))
                z2 += 4.0
                r2 += 1
            _wq(at,side,0,1,H-11,H,Color(0,0,0,0.28))
        "hall":
            # Papel bordo com filetes dourados, lambri escuro e arandelas.
            _wq(at,side,0,1,0,H,Color("3c1923").darkened(k))
            for i in range(4):
                var u: float = (float(i)+0.5)/4.0
                _wl(at,side,u,14,u,H-2,Color(0.62,0.48,0.26,0.45).darkened(k),0.6)
                disc(cv,_wpt(at,side,u-0.125,25),0.8,Color(0.62,0.48,0.26,0.35))
            _wq(at,side,0,1,0,13,Color("2d1b15").darkened(k))
            for pu in [[0.07,0.45],[0.55,0.93]]:
                _wq(at,side,pu[0],pu[1],2.5,10.5,Color("24150f").darkened(k))
            _wl(at,side,0,13,1,13,Color("9a7a45").darkened(k),1.4)
            _wl(at,side,0,H-1,1,H-1,Color("9a7a45").darkened(k),1.2)
            if n > 0.84:
                var sc: Vector2 = _wpt(at,side,0.5,22)
                cv.draw_line(sc,sc+Vector2(0,-4),Color("8a6a3a"),1.6)
                cv.draw_line(sc+Vector2(-3,-4),sc+Vector2(3,-4),Color("8a6a3a"),1.4)
                cv.draw_line(sc+Vector2(0,-4),sc+Vector2(0,-9),Color("d8cdbb"),1.8)
                disc(cv,sc+Vector2(0,-11),1.6,Color(1.0,0.75,0.4,0.85))
                disc(cv,sc+Vector2(0,-11),5.0,Color(1.0,0.7,0.35,0.12))
        "foyer":
            # Lambri de madeira com almofadas, do chao ao teto.
            _wq(at,side,0,1,0,H,Color("45322a").darkened(k))
            for pu in [[0.06,0.46],[0.54,0.94]]:
                for pz in [[4.0,17.0],[20.0,33.0]]:
                    _wq(at,side,pu[0],pu[1],pz[0],pz[1],Color("3a2922").darkened(k))
                    _wl(at,side,pu[0],pz[1],pu[1],pz[1],Color("1e1511"),0.8)
                    _wl(at,side,pu[0],pz[0],pu[1],pz[0],Color("6a4e3c").darkened(k),0.8)
            _wq(at,side,0,1,0,2.5,Color("231914"))
            _wl(at,side,0,H-1,1,H-1,Color("7a5c44").darkened(k),1.2)
        "corridor":
            # Reboco descascando, com mancha de umidade embaixo.
            _wq(at,side,0,1,0,H,Color("45424d").darkened(k))
            _wq(at,side,0,1,0,9,Color(0.10,0.12,0.10,0.30))
            if n > 0.5:
                poly([_wpt(at,side,n*0.6,20),_wpt(at,side,n*0.6+0.25,22),_wpt(at,side,n*0.6+0.2,14),_wpt(at,side,n*0.6+0.05,12)],Color("5b5258").darkened(k))
            if n < 0.35:
                cv.draw_polyline(PackedVector2Array([_wpt(at,side,0.2,H-2),_wpt(at,side,0.28,H-10),_wpt(at,side,0.22,H-16),_wpt(at,side,0.35,H-24)]),Color(0,0,0,0.5),0.8,true)
            _wq(at,side,0,1,0,2.5,Color("27242b"))
        _:
            # Fachada externa: pedra em blocos grandes.
            _wq(at,side,0,1,0,H,Color("262b36").darkened(k))
            var r3: int = 0
            var z3: float = 0.0
            while z3 < H:
                _wl(at,side,0,z3,1,z3,Color(0,0,0,0.45),0.8)
                var off3: float = 0.0 if r3%2 == 0 else 0.5
                for i in range(2):
                    var u3: float = off3+float(i)*0.5
                    if u3 > 0.01 and u3 < 0.99:
                        _wl(at,side,u3,z3,u3,minf(z3+9.0,H),Color(0,0,0,0.45),0.8)
                z3 += 9.0
                r3 += 1
    # Rodape de sombra onde a parede encontra o piso.
    _wq(at,side,0,1,0,1.2,Color(0,0,0,0.35))
    _wall_stretch = 1.0

# =====================================================================
# OBJETOS E MOVEIS: cada um com a forma do que e (pernas, gavetas,
# lombadas, portas...), montados em caixas no espaco do mundo.
# =====================================================================
func _wp(at: Vector2, x: float, y: float, h: float) -> Vector2:
    ## Ponto do mundo (deslocado x,y de "at") erguido h px do chao.
    return screen(at+Vector2(x,y))+Vector2(0,-h)

func _prism(at: Vector2, x0: float, y0: float, x1: float, y1: float, z0: float, z1: float, col: Color, edge: bool = true) -> void:
    ## Caixa alinhada aos eixos, de z0 a z1 de altura: faces +y, +x e tampo.
    var a: Vector2 = _wp(at,x0,y0,z1)
    var b: Vector2 = _wp(at,x1,y0,z1)
    var c: Vector2 = _wp(at,x1,y1,z1)
    var d: Vector2 = _wp(at,x0,y1,z1)
    var b0: Vector2 = _wp(at,x1,y0,z0)
    var c0: Vector2 = _wp(at,x1,y1,z0)
    var d0: Vector2 = _wp(at,x0,y1,z0)
    poly([d0,c0,c,d],col.darkened(0.22))
    poly([b0,c0,c,b],col.darkened(0.40))
    poly([a,b,c,d],col.lightened(0.10))
    if edge:
        cv.draw_line(d,c,Color(1,0.92,0.85,0.22),1.0,true)
        cv.draw_line(c,b,Color(1,0.92,0.85,0.12),1.0,true)
        cv.draw_line(c,c0,Color(0,0,0,0.28),1.0,true)

func _qy(at: Vector2, y: float, x0: float, x1: float, z0: float, z1: float, col: Color) -> void:
    ## Retangulo na face voltada para +y (plano y constante).
    poly([_wp(at,x0,y,z0),_wp(at,x1,y,z0),_wp(at,x1,y,z1),_wp(at,x0,y,z1)],col)

func _qx(at: Vector2, x: float, y0: float, y1: float, z0: float, z1: float, col: Color) -> void:
    ## Retangulo na face voltada para +x (plano x constante).
    poly([_wp(at,x,y0,z0),_wp(at,x,y1,z0),_wp(at,x,y1,z1),_wp(at,x,y0,z1)],col)

func _qtop(at: Vector2, x0: float, y0: float, x1: float, y1: float, z: float, col: Color) -> void:
    poly([_wp(at,x0,y0,z),_wp(at,x1,y0,z),_wp(at,x1,y1,z),_wp(at,x0,y1,z)],col)

func _ground_shadow(at: Vector2, w: float, d: float, alpha: float = 0.35) -> void:
    poly([_wp(at,-w*0.5-3,-d*0.5-1,0),_wp(at,w*0.5+3,-d*0.5-1,0),_wp(at,w*0.5+4,d*0.5+4,0),_wp(at,-w*0.5-1,d*0.5+4,0)],Color(0,0,0,alpha))

func _furniture(obj: Dictionary) -> void:
    var at: Vector2 = obj["at"]
    var w: float = obj["w"]
    var d: float = obj["d"]
    var h: float = obj["h"]
    var col: Color = obj["c"]
    var kind: String = obj["kind"]
    _ground_shadow(at,w,d)
    match kind:
        "table": _table(at,w,d,h,col)
        "shelf": _bookshelf(at,w,d,h,col)
        "butcher": _counter(at,w,d,h,col)
        "bed": _bed(at,w,d,h,col)
        "mirror": _dresser_mirror(at,w,d,h,col)
        "altar": _altar(at,w,d,h,col)
        _: _box(at,w,d,h,col)
    _table_props(obj)

func _table(at: Vector2, w: float, d: float, h: float, col: Color) -> void:
    ## Mesa de madeira: quatro pernas torneadas, saia e tampo de tabuas.
    var hw: float = w*0.5
    var hd: float = d*0.5
    var leg: Color = col.darkened(0.30)
    var li: float = 4.0
    for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
        var cx: float = corner.x*(hw-li)
        var cy: float = corner.y*(hd-li)
        _prism(at,cx-1.6,cy-1.6,cx+1.6,cy+1.6,0,h-4,leg,false)
        _prism(at,cx-2.2,cy-2.2,cx+2.2,cy+2.2,h*0.45,h*0.45+2,leg.lightened(0.08),false)
    _qy(at,hd-li+1.6,-hw+li,hw-li,h-8,h-3.5,col.darkened(0.32))
    _qx(at,hw-li+1.6,hd-li,-hd+li,h-8,h-3.5,col.darkened(0.48))
    _prism(at,-hw,-hd,hw,hd,h-3.5,h,col)
    var planks: int = maxi(2,int(d/11.0))
    for i in range(1,planks):
        var yy: float = -hd+d*float(i)/float(planks)
        cv.draw_line(_wp(at,-hw,yy,h),_wp(at,hw,yy,h),col.darkened(0.25),0.8,true)
    for i in range(planks):
        var yy: float = -hd+d*(float(i)+0.5)/float(planks)
        var gx: float = -hw+w*_h(at.x+float(i),at.y)
        cv.draw_line(_wp(at,gx,yy-1,h),_wp(at,minf(gx+w*0.25,hw-2),yy+0.5,h),col.lightened(0.06),0.6,true)

func _bookshelf(at: Vector2, w: float, d: float, h: float, col: Color) -> void:
    ## Estante: armacao de madeira, tres prateleiras de livros e cornija.
    var hw: float = w*0.5
    var hd: float = d*0.5
    _prism(at,-hw,-hd,hw,hd,0,h,col)
    _qy(at,hd,-hw+2.5,hw-2.5,2.5,h-3,col.darkened(0.65))
    var shelves: Array = [2.5,h*0.36,h*0.68,h-3.0]
    var palette: Array = [Color("7a2a33"),Color("2b4566"),Color("3a5a36"),Color("7a5a2a"),Color("553565"),Color("8f7448"),Color("2c2b38"),Color("6b3a28")]
    for s in range(3):
        var z0: float = shelves[s]+1.6
        var gap: float = float(shelves[s+1])-z0-0.6
        var x: float = -hw+3.0
        var i: int = 0
        while x < hw-3.5:
            var r: float = _h(at.x+float(s*31+i),at.y+float(i))
            var bw: float = 2.0+r*2.2
            if x+bw > hw-3.0:
                break
            var bh: float = gap*(0.68+0.28*_h(r,float(i)))
            if r > 0.9:
                x += bw*0.6               # um vao: livro faltando
            else:
                var bc: Color = palette[int(r*97.0)%palette.size()]
                _qy(at,hd+0.01,x,x+bw,z0,z0+bh,bc)
                _qy(at,hd+0.02,x,x+bw,z0+bh-2.2,z0+bh-1.4,Color("c8a85e").darkened(0.2))
                cv.draw_line(_wp(at,x,hd,z0),_wp(at,x,hd,z0+bh),Color(0,0,0,0.35),0.6)
            x += bw
            i += 1
        _qy(at,hd+0.03,-hw+2.5,hw-2.5,shelves[s],shelves[s]+1.6,col.lightened(0.05))
    _qx(at,hw,hd,-hd,2,h-2,col.darkened(0.46))
    cv.draw_line(_wp(at,hw,hd-3,3),_wp(at,hw,hd-3,h-3),col.darkened(0.6),0.7)
    _prism(at,-hw-1.5,-hd-1,hw+1.5,hd+1.6,h,h+2.6,col.lightened(0.06))

func _counter(at: Vector2, w: float, d: float, h: float, col: Color) -> void:
    ## Bancada de cozinha: portas de armario, rodape, tampo de inox e tabua.
    var hw: float = w*0.5
    var hd: float = d*0.5
    _prism(at,-hw+2,-hd+2,hw-2,hd-2,0,3,Color("1a1a1e"),false)
    _prism(at,-hw,-hd,hw,hd,3,h-2.5,col)
    var doors: int = maxi(2,int(w/24.0))
    var dw: float = (w-4.0)/float(doors)
    for i in range(doors):
        var x0: float = -hw+2.0+dw*float(i)
        _qy(at,hd+0.01,x0+1.2,x0+dw-1.2,5.5,h-5.5,col.darkened(0.30))
        _qy(at,hd+0.02,x0+2.6,x0+dw-2.6,7.0,h-7.0,col.darkened(0.15))
        var kx: float = x0+dw-4.0 if i%2 == 0 else x0+4.0
        cv.draw_line(_wp(at,kx,hd,h-9),_wp(at,kx,hd,h-12),Color("b8b6ae"),1.4)
    _prism(at,-hw-1.5,-hd-1.5,hw+1.5,hd+1.5,h-2.5,h,Color("9aa2a7"))
    cv.draw_line(_wp(at,-hw+4,hd-4,h),_wp(at,hw-12,-hd+6,h),Color(1,1,1,0.18),1.0,true)
    _qtop(at,hw-26,-hd+5,hw-8,hd-12,h+0.1,Color("6e5338"))
    # Mancha, cutelo cravado e ganchos (o que ninguem limpou).
    var kt: Vector2 = screen(at)+Vector2(0,-h)
    poly([kt+Vector2(-22,-5),kt+Vector2(-6,-10),kt+Vector2(12,-2),kt+Vector2(-2,6)],Color("3d0a14"))
    poly([kt+Vector2(8,-4),kt+Vector2(16,-7),kt+Vector2(24,-1),kt+Vector2(14,4)],Color("5c1420"))
    disc(cv,kt+Vector2(16,-3),3.0,Color("7a2231"))
    cv.draw_line(kt+Vector2(-14,-6),kt+Vector2(-9,-21),Color("4a3527"),3.0)
    poly([kt+Vector2(-15,-6),kt+Vector2(-12,-15),kt+Vector2(-23,-13),kt+Vector2(-25,-5)],Color("aab3ba"))
    cv.draw_line(kt+Vector2(-25,-5),kt+Vector2(-15,-6),Color("5c0f1d"),1.4)
    for hx in [-30.0, 30.0]:
        var hook: Vector2 = kt+Vector2(hx,-46+sin(g.real_time*1.1+hx)*1.5)
        cv.draw_line(hook+Vector2(0,-60),hook,Color("56515c"),1.2)
        cv.draw_arc(hook+Vector2(0,4),4.0,-PI*0.5,PI,10,Color("8b8791"),1.6)
    var drop: float = fposmod(g.real_time*0.7,1.0)
    disc(cv,kt+Vector2(-30,-36+drop*30.0),1.3,Color(0.42,0.04,0.09,1.0-drop))

func _bed(at: Vector2, w: float, d: float, h: float, col: Color) -> void:
    ## Cama de casal: cabeceira entalhada, colchao, travesseiros, cobertor
    ## caindo pelas laterais e pezeira. Algo respira debaixo do lencol.
    var hw: float = w*0.5
    var hd: float = d*0.5
    var wood: Color = Color("4a2f24")
    _prism(at,-hw-4,-hd,-hw,hd,0,h+26,wood)
    for py in [-hd, hd-3.0]:
        _prism(at,-hw-5,py-0.5,-hw+1,py+3.5,0,h+30,wood.darkened(0.1))
        disc(cv,_wp(at,-hw-2,py+1.5,h+31.5),2.4,wood.lightened(0.1))
    for i in range(1,5):
        var yy: float = -hd+d*float(i)/5.0
        cv.draw_line(_wp(at,-hw,yy,h+3),_wp(at,-hw,yy,h+22),wood.darkened(0.35),1.0)
    _prism(at,-hw,-hd,hw,hd,2,8,wood)
    _prism(at,-hw+1,-hd+1,hw-1,hd-1,8,h,Color("cbc2c4"))
    # Cobertor sobre 2/3 da cama, caindo pelas faces.
    var bx: float = -hw+w*0.36
    _qtop(at,bx,-hd-1,hw+0.5,hd+1,h+1.2,col.lightened(0.05))
    _qy(at,hd+1,bx,hw+0.5,6,h+1.2,col.darkened(0.15))
    _qx(at,hw+0.5,hd+1,-hd-1,6,h+1.2,col.darkened(0.35))
    cv.draw_line(_wp(at,bx,-hd-1,h+1.2),_wp(at,bx,hd+1,h+1.2),col.lightened(0.25),1.4,true)
    for i in range(1,4):
        var fx: float = bx+(hw-bx)*float(i)/4.0
        cv.draw_line(_wp(at,fx,hd+1,h),_wp(at,fx+1,hd+1,7),col.darkened(0.3),0.8)
    # Dois travesseiros fofos junto da cabeceira.
    for py in [-hd+4.0, 2.0]:
        _shape([_wp(at,-hw+3,py,h+2),_wp(at,-hw+3,py+(hd-6.0),h+2),_wp(at,-hw+17,py+(hd-6.0),h+3),_wp(at,-hw+17,py,h+3),_wp(at,-hw+10,py-1,h+6)],Color("e2d8da"),false)
    # A coisa debaixo do cobertor.
    var bt: Vector2 = _wp(at,hw*0.25,0,h)
    var breath: float = 1.0+0.13*sin(g.real_time*1.3)
    cv.draw_set_transform(bt+Vector2(0,-1.0-2.0*breath),0.46,Vector2(1.0,0.55*breath))
    disc(cv,Vector2(2,0),13.0,col.darkened(0.12))
    disc(cv,Vector2(0,-2),12.0,col.lightened(0.08))
    disc(cv,Vector2(18,-1),8.0,col.lightened(0.08))
    disc(cv,Vector2(-17,-2),6.5,col.lightened(0.12))
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
    poly([bt+Vector2(-6,3),bt+Vector2(6,1),bt+Vector2(12,9),bt+Vector2(0,13)],Color(0.30,0.03,0.08,0.75))
    _prism(at,hw,-hd,hw+3,hd,0,h+7,wood)
    disc(cv,_wp(at,hw+1.5,hd-1.5,h+8.5),2.0,wood.lightened(0.1))

func _dresser_mirror(at: Vector2, w: float, d: float, h: float, col: Color) -> void:
    ## Penteadeira com gavetas e um espelho oval de moldura dourada.
    ## Quando o puzzle e resolvido, o vidro esta estilhacado.
    var hw: float = w*0.5
    var hd: float = d*0.5
    var top: float = 18.0
    var gold: Color = Color("8b6f4e")
    # Espelho (fica atras, apoiado na parede do fundo).
    var my: float = -hd+3.0
    var mz: float = top+h*0.5
    var outer: PackedVector2Array = PackedVector2Array()
    var inner: PackedVector2Array = PackedVector2Array()
    for k in range(28):
        var a: float = TAU*float(k)/28.0
        outer.append(_wp(at,cos(a)*(hw-5),my,mz+sin(a)*(h*0.5)))
        inner.append(_wp(at,cos(a)*(hw-9),my,mz+sin(a)*(h*0.5-4)))
    cv.draw_colored_polygon(outer,gold)
    cv.draw_colored_polygon(inner,Color("1d2a33") if g.mirror_open else Color("6f8794"))
    if not g.mirror_open:
        for k in range(3):
            var u: float = -hw*0.4+float(k)*7.0
            cv.draw_line(_wp(at,u,my,mz-10),_wp(at,u+8,my,mz+12),Color(1,1,1,0.22),1.6,true)
    else:
        var cc: Vector2 = _wp(at,3,my,mz+4)
        for k in range(8):
            var a2: float = TAU*float(k)/8.0+0.3
            var e1: Vector2 = cc+Vector2.from_angle(a2)*(8.0+_h(float(k),1.0)*6.0)
            cv.draw_line(cc,e1,Color(0.85,0.9,0.95,0.6),0.8,true)
            cv.draw_line(e1,e1+Vector2.from_angle(a2+0.5)*6.0,Color(0.85,0.9,0.95,0.4),0.6,true)
    cv.draw_polyline(outer,gold.lightened(0.25),0.8,true)
    # Penteadeira: tampo, tres gavetas na frente, pes curtos.
    for corner in [Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:
        _prism(at,corner.x*(hw-3)-1.5,corner.y*(hd-3)-1.5,corner.x*(hw-3)+1.5,corner.y*(hd-3)+1.5,0,4,col.darkened(0.3),false)
    _prism(at,-hw+1,-hd+1,hw-1,hd-1,4,top-2,col)
    var dr: int = 3
    for i in range(dr):
        var x0: float = -hw+3+(w-6)*float(i)/float(dr)
        var x1: float = -hw+3+(w-6)*float(i+1)/float(dr)
        _qy(at,hd-0.99,x0+1,x1-1,6.5,top-4,col.darkened(0.12))
        disc(cv,_wp(at,(x0+x1)*0.5,hd-1,(top+2.5)*0.5),1.3,Color("c9a15d"))
    _prism(at,-hw,-hd,hw,hd,top-2,top,col.lightened(0.08))
    # Escova e um frasco de perfume em cima.
    _prism(at,hw-12,-2,hw-8,2,top,top+5,Color(0.75,0.55,0.70,0.85),false)
    disc(cv,_wp(at,hw-10,0,top+6.5),1.4,Color("c9a15d"))

func _altar(at: Vector2, w: float, d: float, h: float, col: Color) -> void:
    ## Altar de pedra: plinto, corpo com paineis entalhados e laje de tampo.
    var hw: float = w*0.5
    var hd: float = d*0.5
    _prism(at,-hw-3,-hd-3,hw+3,hd+3,0,5,col.darkened(0.25))
    _prism(at,-hw+2,-hd+2,hw-2,hd-2,5,h-5,col)
    for pu in [[-hw+6,-3.0],[3.0,hw-6]]:
        _qy(at,hd-1.99,pu[0],pu[1],9,h-9,col.darkened(0.30))
        var cx: float = (float(pu[0])+float(pu[1]))*0.5
        var ring: PackedVector2Array = PackedVector2Array()
        for k in range(17):
            var a: float = TAU*float(k)/16.0
            ring.append(_wp(at,cx+cos(a)*6.0,hd-1.98,(h*0.5)+sin(a)*6.0))
        cv.draw_polyline(ring,col.darkened(0.55),1.0,true)
        cv.draw_line(_wp(at,cx,hd-1.98,h*0.5-6),_wp(at,cx,hd-1.98,h*0.5+6),col.darkened(0.55),1.0)
    _qx(at,hw-1.99,hd-6,-hd+6,9,h-9,col.darkened(0.48))
    _prism(at,-hw-2,-hd-2,hw+2,hd+2,h-5,h,col.lightened(0.04))
    for k in range(4):
        var cx2: float = -hw+w*_h(float(k),5.0)
        cv.draw_line(_wp(at,cx2,hd+2,h),_wp(at,cx2+3,hd+2,h-4),col.darkened(0.5),0.7,true)
    # Tampo empocado de sangue velho, que escorre pelas duas fachadas.
    var lift: Vector2 = Vector2(0,-h)
    var top: Vector2 = screen(at)+lift
    var left: Vector2 = screen(at+Vector2(-hw,hd))+lift
    var front: Vector2 = screen(at+Vector2(hw,hd))+lift
    var right: Vector2 = screen(at+Vector2(hw,-hd))+lift
    poly([top+Vector2(-24,-4),top+Vector2(-4,-10),top+Vector2(20,1),top+Vector2(8,10),top+Vector2(-9,5)],Color("3d0a14"))
    poly([top+Vector2(-10,-3),top+Vector2(2,-6),top+Vector2(10,1),top+Vector2(0,5)],Color("5c0f1d"))
    for f in [0.16,0.40,0.66,0.88]:
        var s1: Vector2 = left.lerp(front,f)
        cv.draw_line(s1,s1+Vector2(0,7.0+fposmod(f*37.0,1.0)*15.0),Color("4a0b17"),2.2)
    for f in [0.28,0.62]:
        var s2: Vector2 = right.lerp(front,f)
        cv.draw_line(s2,s2+Vector2(0,6.0+fposmod(f*53.0,1.0)*13.0),Color("3a0812"),2.0)
    cv.draw_arc(left+Vector2(6,9),3.0,0,TAU,10,Color("8b8791"),1.3)
    cv.draw_arc(right+Vector2(-6,9),3.0,0,TAU,10,Color("8b8791"),1.3)
    if g.ritual_running or g.monster_banished:
        for i in range(3):
            gel(cv,top+Vector2(-18+i*18,-8+i*8),6.0,sin(g.real_time*7.0+float(i)*2.0)*0.8)

func _candle(at: Vector2, x: float, y: float, z: float, tall: float) -> void:
    _prism(at,x-1.3,y-1.3,x+1.3,y+1.3,z,z+tall,Color("d8cdbb"),false)
    var tip: Vector2 = _wp(at,x,y,z+tall)
    var flick: float = 1.5+0.4*sin(g.real_time*9.0+x)
    cv.draw_line(tip,tip+Vector2(0,-1.5),Color("2a2020"),0.8)
    disc(cv,tip+Vector2(0,-3.0),flick,Color(1.0,0.75,0.38,0.9))
    disc(cv,tip+Vector2(0,-3.0),flick*3.5,Color(1.0,0.7,0.35,0.10))

func _table_props(obj: Dictionary) -> void:
    ## O que esta em cima de cada mesa diz que comodo e aquele.
    if obj["kind"] != "table":
        return
    var at: Vector2 = obj["at"]
    var h: float = obj["h"]
    var room: String = room_style(int(at.x/TS),int(at.y/TS))
    match room:
        "library":
            for i in range(3):
                var bc: Color = [Color("6b2a33"),Color("2b4566"),Color("6b5a2a")][i]
                _prism(at,-30,-8+float(i)*0.6,-12,6,h+float(i)*3.0,h+float(i)*3.0+3.0,bc,false)
                _qy(at,6.01,-30,-12,h+float(i)*3.0+0.6,h+float(i)*3.0+2.4,Color("d8ccb0"))
            _candle(at,18,-4,h,7)
            poly([_wp(at,0,-10,h+0.1),_wp(at,12,-10,h+0.1),_wp(at,12,4,h+0.1),_wp(at,0,4,h+0.1)],Color("cfc3a5"))
        "kitchen":
            for px in [-24.0, 0.0, 24.0]:
                var pc: Vector2 = _wp(at,px,0,h+0.5)
                cv.draw_set_transform(pc,0.0,Vector2(1.0,0.5))
                disc(cv,Vector2.ZERO,8.0,Color("bfbcb2"))
                disc(cv,Vector2.ZERO,5.5,Color("a8a49a"))
                if px == 0.0:
                    disc(cv,Vector2(1,0),3.5,Color("4a0b17"))
                cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
        "bedroom":
            _candle(at,-8,-6,h,9)
            _prism(at,4,-4,14,4,h,h+6,Color("5a4a6a"),false)
        "workshop":
            # Ferramentas: martelo, serrote e um potinho de pregos.
            cv.draw_line(_wp(at,-14,-6,h+1),_wp(at,2,4,h+1),Color("6b4a33"),2.2)
            _prism(at,0,2,5,6,h,h+3,Color("6c6f78"),false)
            poly([_wp(at,8,-10,h+0.5),_wp(at,22,-6,h+0.5),_wp(at,20,-2,h+0.5),_wp(at,6,-6,h+0.5)],Color("a7adb3"))
            _prism(at,-20,6,-15,11,h,h+5,Color("4a4f58"),false)
        "foyer":
            pass   # a carta e o vaso ficam por conta dos objetos de cena
        _:
            _candle(at,0,0,h,8)

func _wardrobe(at: Vector2) -> void:
    ## Guarda-roupa de duas portas, com almofadas, puxadores e uma fresta.
    ## "s" deixa o movel 30% mais alto, acompanhando as paredes.
    var s: float = 1.3
    _ground_shadow(at,30,26)
    var wood: Color = Color("4b382e")
    for corner in [Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:
        _prism(at,corner.x*12-1.5,corner.y*10-1.5,corner.x*12+1.5,corner.y*10+1.5,0,3*s,wood.darkened(0.3),false)
    _prism(at,-14,-12,14,12,3*s,47*s,wood)
    for side in [0, 1]:
        var x0: float = -13.0+13.0*float(side)
        var x1: float = x0+13.0
        _qy(at,12.01,x0+1.0,x1-1.0,5*s,45*s,wood.darkened(0.08))
        _qy(at,12.02,x0+2.6,x1-2.6,26*s,42*s,wood.darkened(0.28))
        _qy(at,12.02,x0+2.6,x1-2.6,8*s,23*s,wood.darkened(0.28))
        cv.draw_line(_wp(at,x0+2.6,12,42*s),_wp(at,x1-2.6,12,42*s),wood.lightened(0.15),0.7)
    cv.draw_line(_wp(at,0,12,5*s),_wp(at,0,12,45*s),Color(0,0,0,0.85),1.4)
    for kx in [-2.2, 2.2]:
        disc(cv,_wp(at,kx,12,25*s),1.2,Color("c9a15d"))
    _prism(at,-15.5,-13,15.5,13.5,47*s,50*s,wood.lightened(0.06))
    var eye: float = 0.5+0.5*sin(g.real_time*0.6)
    if eye > 0.93:
        disc(cv,_wp(at,0.6,12,33*s),0.8,Color(0.9,0.2,0.3,0.8))

func _battery(at: Vector2) -> void:
    ## Pilha grande deitada no chao: corpo verde, polo de cobre e rotulo.
    var p: Vector2 = screen(at)
    disc(cv,p+Vector2(0,-6),13.0,Color(.30,1.0,.76,.12+.05*sin(g.real_time*3.0+at.x)))
    var a: Vector2 = _wp(at,-7,0,3.2)
    var b: Vector2 = _wp(at,6,0,3.2)
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
    _oval(screen(at)+Vector2(0,1),10,3.5,Color(0,0,0,0.35))
    _limb(a,b,3.4,3.4,Color("2f9c76"))
    _limb(b,_wp(at,9,0,3.2),3.4,3.4,Color("c98a3c"))
    disc(cv,_wp(at,10.5,0,3.2),1.4,Color("e0b070"))
    cv.draw_line(_wp(at,-1,0,0.2),_wp(at,-1,0,6.2),Color("1d5e48"),1.4)
    cv.draw_line(a+Vector2(0,-2.4),b+Vector2(0,-2.4),Color(1,1,1,0.35),0.8)
    _text(_wp(at,-5,0,6.5)+Vector2(-1,5),"+",8,Color("e8f5ee"))

func _bottle(at: Vector2) -> void:
    ## Garrafa de vidro verde arremessada como distracao.
    var p: Vector2 = screen(at)
    _oval(p+Vector2(0,1),6,2.5,Color(0,0,0,0.35))
    _shape([p+Vector2(-4.5,0),p+Vector2(4.5,0),p+Vector2(5,-10),p+Vector2(2,-14),p+Vector2(1.6,-20),p+Vector2(-1.6,-20),p+Vector2(-2,-14),p+Vector2(-5,-10)],Color(0.35,0.62,0.48,0.85),false)
    cv.draw_rect(Rect2(p+Vector2(-2,-23),Vector2(4,3)),Color("6b4a33"))
    cv.draw_line(p+Vector2(-2.5,-2),p+Vector2(-2.5,-11),Color(1,1,1,0.45),1.0)
    cv.draw_arc(p+Vector2(0,-10),17,0,TAU,28,Color(.70,.83,1,.30),2)

func _scene_object(obj: Dictionary) -> void:
    var at: Vector2 = obj["at"]
    var p: Vector2 = screen(at)
    var kind: String = obj["kind"]
    match kind:
        "fragment":
            # Os "fragmentos" sao os silicones das sacrificadas: tremem e pulsam.
            var idx: int = int(obj["idx"])
            var v: float = g.fragment_pulse(idx)
            disc(cv,p+Vector2(0,-8),17.0+7.0*v,Color(1.0,.70,.80,.08+.14*v))
            gel(cv,p+Vector2(0,-2),11.0,sin(g.real_time*5.0+float(idx)*1.7)*(0.7+1.6*v))
        "key": _key(p)
        "book": _lectern(at,int(obj["number"]))
        "seal": _seal(p,int(obj["number"]))
        "box": _music_box(at)
        "letter": _letter(p+Vector2(0,-19))
        "note": _note(p)
        "vase": _vase(p+Vector2(0,-15))
        "door": _foyer_door(at)
        "lens": _lens(p)
        "clue":
            disc(cv,p+Vector2(0,-19),19,Color(.64,.42,.96,.26))
            cv.draw_arc(p+Vector2(0,-19),16,0,TAU,32,Color("bca1ff"),2.0)
            _text(p+Vector2(-7,-13),"?",17,Color("f5deff"))

func _key(p: Vector2) -> void:
    ## Chave de latao antiga deitada no chao: argola vazada, haste e dentes.
    var gold: Color = Color("d9b25f")
    var dark: Color = Color("7a5a24")
    _floor_matrix(p,0.6)
    disc(cv,Vector2(1,1.5),7.5,Color(0,0,0,0.30))
    cv.draw_arc(Vector2(-6,0),4.6,0,TAU,18,dark,3.2)
    cv.draw_arc(Vector2(-6,0),4.6,0,TAU,18,gold,2.0)
    disc(cv,Vector2(-6,0),1.2,dark)
    cv.draw_line(Vector2(-1.5,0),Vector2(13,0),dark,2.8)
    cv.draw_line(Vector2(-1.5,0),Vector2(13,0),gold,1.6)
    cv.draw_rect(Rect2(Vector2(9,0),Vector2(2,4)),gold)
    cv.draw_rect(Rect2(Vector2(12,0),Vector2(1.6,3)),gold)
    cv.draw_line(Vector2(-0.8,-2),Vector2(-0.8,2),gold,1.4)
    cv.draw_set_transform_matrix(Transform2D.IDENTITY)
    var tw: float = 0.5+0.5*sin(g.real_time*4.0)
    var sp: Vector2 = p+Vector2(-4,-4)
    cv.draw_line(sp+Vector2(-3*tw,0),sp+Vector2(3*tw,0),Color(1,0.95,0.75,0.8),0.8)
    cv.draw_line(sp+Vector2(0,-3*tw),sp+Vector2(0,3*tw),Color(1,0.95,0.75,0.8),0.8)

func _lectern(at: Vector2, number: int) -> void:
    ## Atril de madeira com um livro aberto; o numero romano marca a ordem.
    var wood: Color = Color("5a3b2a")
    _ground_shadow(at,14,12,0.3)
    _prism(at,-6,-5,6,5,0,2,wood.darkened(0.1))
    _prism(at,-1.5,-1.5,1.5,1.5,2,15,wood)
    var tl: Vector2 = _wp(at,-8,-6,20)
    var tr: Vector2 = _wp(at,8,-6,20)
    var br: Vector2 = _wp(at,8,5,14)
    var bl: Vector2 = _wp(at,-8,5,14)
    poly([tl,tr,br,bl],wood.lightened(0.05))
    poly([bl,br,br+Vector2(0,2),bl+Vector2(0,2)],wood.darkened(0.3))
    var cover: Color = Color("7d2f3e") if number % 2 else Color("2f5a66")
    var m0: Vector2 = tl.lerp(tr,0.5)
    var m1: Vector2 = bl.lerp(br,0.5)
    poly([tl.lerp(bl,0.08).lerp(tr,0.06),tl.lerp(tr,0.94).lerp(br,0.08),bl.lerp(br,0.94).lerp(tr,0.08),bl.lerp(tl,0.08).lerp(br,0.06)],cover)
    poly([tl.lerp(bl,0.12).lerp(tr,0.1),m0+Vector2(0,0.8),m1+Vector2(0,-0.8),bl.lerp(tl,0.12).lerp(br,0.1)],Color("e3d7bb"))
    poly([m0+Vector2(0,0.8),tl.lerp(tr,0.9).lerp(br,0.12),bl.lerp(br,0.9).lerp(tr,0.12),m1+Vector2(0,-0.8)],Color("d6c9ac"))
    cv.draw_line(m0,m1,Color("8a7a5c"),0.8)
    for k in range(4):
        var f: float = 0.25+float(k)*0.17
        cv.draw_line(tl.lerp(bl,f).lerp(m0.lerp(m1,f),0.15),tl.lerp(bl,f).lerp(m0.lerp(m1,f),0.8),Color(0.3,0.25,0.2,0.45),0.5)
        cv.draw_line(m0.lerp(m1,f).lerp(tr.lerp(br,f),0.2),m0.lerp(m1,f).lerp(tr.lerp(br,f),0.85),Color(0.3,0.25,0.2,0.45),0.5)
    cv.draw_line(m1,m1+Vector2(1,7),Color("8c2030"),1.2)
    var roman: String = ["I","II","III"][clampi(number-1,0,2)]
    var tw: float = ThemeDB.fallback_font.get_string_size(roman,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
    _text(_wp(at,0,-6,26)+Vector2(-tw*0.5,0),roman,11,Color("e8cf8f"))

func _seal(p: Vector2, number: int) -> void:
    ## Selo de pedra no piso: disco entalhado com runas e o numeral no centro.
    var lit: bool = number in g.mirror_sequence
    var ink: Color = Color("c4adff") if lit else Color("8a7d94")
    _floor_matrix(p,0.0)
    if lit:
        disc(cv,Vector2.ZERO,19.0,Color(0.6,0.45,1.0,0.22+0.08*sin(g.real_time*5.0)))
    disc(cv,Vector2.ZERO,14.5,Color("2c2733"))
    disc(cv,Vector2.ZERO,13.0,Color("4a4352"))
    cv.draw_arc(Vector2.ZERO,11.0,0,TAU,32,ink,1.0)
    cv.draw_arc(Vector2.ZERO,6.5,0,TAU,24,ink,0.8)
    for k in range(10):
        var a: float = TAU*float(k)/10.0
        var r0: Vector2 = Vector2.from_angle(a)*7.6
        var r1: Vector2 = Vector2.from_angle(a)*10.2
        cv.draw_line(r0,r1,ink,0.8)
        cv.draw_line(r1,Vector2.from_angle(a+0.18)*8.8,ink,0.6)
    var roman: String = ["I","II","III"][clampi(number-1,0,2)]
    var font: Font = ThemeDB.fallback_font
    var tw: float = font.get_string_size(roman,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
    cv.draw_string(font,Vector2(-tw*0.5,3.2),roman,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("f1e0ff") if lit else Color("bdb0c8"))
    cv.draw_set_transform_matrix(Transform2D.IDENTITY)

func _music_box(at: Vector2) -> void:
    ## Caixa de musica de madeira com frisos dourados e manivela.
    ## Aberta, mostra o veludo vermelho e a bailarina girando.
    var wood: Color = Color("6b3e2a")
    var gold: Color = Color("c9a15d")
    _ground_shadow(at,26,20,0.3)
    for corner in [Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:
        disc(cv,_wp(at,corner.x*11,corner.y*8,1.0),1.6,gold.darkened(0.3))
    if g.musicbox_open:
        # Tampa aberta para tras, forrada de veludo, com espelhinho.
        var l0: Vector2 = _wp(at,-12,-9,13)
        var l1: Vector2 = _wp(at,12,-9,13)
        var l2: Vector2 = _wp(at,12,-14,30)
        var l3: Vector2 = _wp(at,-12,-14,30)
        poly([l0,l1,l2,l3],wood.darkened(0.2))
        poly([l0.lerp(l2,0.08),l1.lerp(l3,0.08),l2.lerp(l0,0.08),l3.lerp(l1,0.08)],Color("6a1a26"))
        poly([l0.lerp(l2,0.3),l1.lerp(l3,0.3),l2.lerp(l0,0.3),l3.lerp(l1,0.3)],Color("8fa3ad"))
    _prism(at,-12,-9,12,9,2,13,wood)
    cv.draw_line(_wp(at,-12,9,4),_wp(at,12,9,4),gold,1.0)
    cv.draw_line(_wp(at,12,9,4),_wp(at,12,-9,4),gold.darkened(0.2),1.0)
    cv.draw_line(_wp(at,-12,9,11.5),_wp(at,12,9,11.5),gold,1.0)
    cv.draw_line(_wp(at,12,9,11.5),_wp(at,12,-9,11.5),gold.darkened(0.2),1.0)
    var kh: Vector2 = _wp(at,0,9,8)
    disc(cv,kh,1.6,gold)
    cv.draw_line(kh,kh+Vector2(0,2.2),Color("1a1010"),0.8)
    # Manivela na lateral.
    var crank: Vector2 = _wp(at,12,0,7.5)
    var turn: float = g.real_time*3.0 if g.musicbox_open else 0.0
    var arm: Vector2 = crank+Vector2(cos(turn)*3.0+3.0,sin(turn)*3.0-1.0)
    cv.draw_line(crank,crank+Vector2(3,-1),gold.darkened(0.2),1.4)
    cv.draw_line(crank+Vector2(3,-1),arm,gold,1.4)
    disc(cv,arm,1.3,Color("3a2018"))
    if g.musicbox_open:
        _qtop(at,-10,-7,10,7,13.1,Color("7a1f2c"))
        # Bailarina de porcelana girando no centro.
        var bc: Vector2 = _wp(at,0,0,13)
        var spin: float = cos(g.real_time*4.0)
        cv.draw_line(bc,bc+Vector2(0,-4),Color("d8cdbb"),0.8)
        poly([bc+Vector2(-4.0*absf(spin)-1.0,-5),bc+Vector2(4.0*absf(spin)+1.0,-5),bc+Vector2(0,-8)],Color("e6b8c6"))
        cv.draw_line(bc+Vector2(0,-8),bc+Vector2(0,-11),Color("efe4dc"),1.2)
        cv.draw_line(bc+Vector2(0,-10),bc+Vector2(3.0*spin,-13),Color("efe4dc"),0.7)
        cv.draw_line(bc+Vector2(0,-10),bc+Vector2(-3.0*spin,-13),Color("efe4dc"),0.7)
        disc(cv,bc+Vector2(0,-12.5),1.4,Color("efe4dc"))
    else:
        _prism(at,-12.5,-9.5,12.5,9.5,13,15,wood.lightened(0.06))
        var c0: Vector2 = _wp(at,0,0,15)
        cv.draw_set_transform(c0,0.0,Vector2(1.0,0.5))
        cv.draw_arc(Vector2.ZERO,6.0,0,TAU,20,gold,1.0)
        disc(cv,Vector2.ZERO,2.0,gold)
        cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _letter(lp: Vector2) -> void:
    ## Envelope aberto com lacre de cera vermelha e a carta saindo dele.
    var read: bool = g.letter_read
    if not read:
        disc(cv,lp,14.0+2.5*sin(g.real_time*3.0),Color(1,.93,.72,.13))
    _floor_matrix(lp,0.25)
    var paper: Color = Color("eadfc4") if not read else Color("a59c8a")
    cv.draw_rect(Rect2(Vector2(-9,-6),Vector2(18,12)),Color(0,0,0,0.25))
    cv.draw_rect(Rect2(Vector2(-6,-11),Vector2(14,12)),paper.lightened(0.05))
    for k in range(4):
        cv.draw_line(Vector2(-4,-9+float(k)*2.2),Vector2(5,-9+float(k)*2.2),Color(0.25,0.2,0.2,0.5),0.5)
    cv.draw_rect(Rect2(Vector2(-10,-7),Vector2(18,12)),paper)
    cv.draw_polyline(PackedVector2Array([Vector2(-10,-7),Vector2(-1,0),Vector2(8,-7)]),paper.darkened(0.25),0.8)
    cv.draw_line(Vector2(-10,5),Vector2(-3,-1),paper.darkened(0.18),0.6)
    cv.draw_line(Vector2(8,5),Vector2(1,-1),paper.darkened(0.18),0.6)
    disc(cv,Vector2(-1,0),2.4,Color("8a1f2c"))
    disc(cv,Vector2(-1.4,-0.4),0.8,Color("c0404f"))
    cv.draw_set_transform_matrix(Transform2D.IDENTITY)

func _note(p: Vector2) -> void:
    ## Bilhete amassado no chao: papel dobrado em vincos, rabiscado.
    var paper: Color = Color("d8ceb4") if not g.note_read else Color("94907f")
    _floor_matrix(p+Vector2(0,-1),-0.4)
    cv.draw_colored_polygon(PackedVector2Array([Vector2(-8,-5),Vector2(-2,-7),Vector2(7,-6),Vector2(9,0),Vector2(6,6),Vector2(-1,5),Vector2(-7,7),Vector2(-9,1)]),paper)
    cv.draw_polyline(PackedVector2Array([Vector2(-8,-5),Vector2(-1,0),Vector2(6,6)]),paper.darkened(0.2),0.7)
    cv.draw_polyline(PackedVector2Array([Vector2(-2,-7),Vector2(-1,0),Vector2(-7,7)]),paper.darkened(0.15),0.6)
    for k in range(3):
        cv.draw_polyline(PackedVector2Array([Vector2(-5,-3+k*3),Vector2(-2,-4+k*3),Vector2(1,-2.5+k*3),Vector2(4,-3.5+k*3)]),Color(0.2,0.15,0.2,0.6),0.5)
    cv.draw_set_transform_matrix(Transform2D.IDENTITY)

func _vase(vp: Vector2) -> void:
    ## Vaso de porcelana barrigudo, com faixa pintada e flores murchas.
    var porcelain: Color = Color("7f8fa6")
    cv.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
    _oval(vp+Vector2(1,0.5),7,2.5,Color(0,0,0,0.35))
    _shape([vp+Vector2(-3.5,0),vp+Vector2(3.5,0),vp+Vector2(6.8,-5),vp+Vector2(6.4,-10),vp+Vector2(3,-13.5),vp+Vector2(2.6,-16),vp+Vector2(4.2,-17.5),vp+Vector2(-4.2,-17.5),vp+Vector2(-2.6,-16),vp+Vector2(-3,-13.5),vp+Vector2(-6.4,-10),vp+Vector2(-6.8,-5)],porcelain,false)
    cv.draw_polyline(PackedVector2Array([vp+Vector2(-6.6,-7),vp+Vector2(-3,-6),vp+Vector2(3,-6),vp+Vector2(6.6,-7)]),Color("2c3c6a"),1.6,true)
    for k in range(4):
        disc(cv,vp+Vector2(-4.5+float(k)*3.0,-9.5),0.7,Color("2c3c6a"))
    cv.draw_line(vp+Vector2(-4.2,-3),vp+Vector2(-4.6,-10),Color(1,1,1,0.4),1.0,true)
    var stems: Array = [[-5.0,-27.0,0.4],[0.0,-30.0,-0.2],[5.5,-26.0,0.5],[-2.5,-24.0,0.9]]
    for s in stems:
        var tip: Vector2 = vp+Vector2(float(s[0]),float(s[1]))
        var mid: Vector2 = vp+Vector2(float(s[0])*0.5,-21)
        cv.draw_polyline(PackedVector2Array([vp+Vector2(0,-16),mid,tip]),Color("4c5b3c"),1.0,true)
        var droop: Vector2 = tip+Vector2(float(s[2])*4.0,3.0)
        cv.draw_line(tip,droop,Color("4c5b3c"),0.9,true)
        for pk in range(4):
            var pa: float = TAU*float(pk)/4.0+float(s[2])
            _oval(droop+Vector2.from_angle(pa)*1.7,1.5,1.0,Color("6a2a3e"),pa)
        disc(cv,droop,0.9,Color("3a2a1a"))
    _oval(vp+Vector2(-2.5,-20),2.4,1.0,Color("5d6a3a"),-0.6)
    _oval(vp+Vector2(3,-19),2.2,0.9,Color("5d6a3a"),0.7)
    for k in range(3):
        _oval(vp+Vector2(-9+float(k)*8.0,1.5+float(k%2)),1.3,0.7,Color("6a2a3e"),float(k))

func _foyer_door(at: Vector2) -> void:
    ## Porta do vestibulo para o salao: batente, almofadas, macaneta e fechadura.
    ## Ocupa a altura do bloco inteiro; "k" estica as almofadas e a fechadura
    ## na mesma proporcao da porta original (33 px).
    bake_wall(int(at.x/TS),int(at.y/TS))
    var wood: Color = Color("5a3b2c")
    var top: float = WALL_HEIGHT
    var k: float = (top-2.0)/33.0
    _qy(at,16.02,-13,13,0,top,Color("2a1d17"))
    _qy(at,16.03,-11,11,0,top-2.0,wood)
    for pz in [[4.0,15.0],[18.0,30.0]]:
        _qy(at,16.04,-8.5,-1.5,pz[0]*k,pz[1]*k,wood.darkened(0.25))
        _qy(at,16.04,1.5,8.5,pz[0]*k,pz[1]*k,wood.darkened(0.25))
    var glint: bool = g.foyer_key_owned
    var knob: Vector2 = _wp(at,7.5,16.05,17*k)
    disc(cv,knob,1.8,Color("e1bc79") if glint else Color("8d7a5c"))
    _qy(at,16.05,6.6,8.4,12.5*k,15.5*k,Color("2a2018"))
    if glint:
        disc(cv,knob,5.0+sin(g.real_time*4.0),Color(1,0.85,0.5,0.15))

func _lens(p: Vector2) -> void:
    ## Lente estranha num aro de latao com runas, pousada num suporte.
    var la: float = 0.7+0.3*sin(g.real_time*3.4)
    var c: Vector2 = p+Vector2(0,-12)
    _oval(p+Vector2(0,1),7,2.5,Color(0,0,0,0.35))
    cv.draw_line(p,c+Vector2(0,8),Color("6b5a3a"),2.0)
    cv.draw_line(p+Vector2(-4,0),p+Vector2(4,0),Color("6b5a3a"),2.0)
    disc(cv,c,15.0,Color(.62,.40,.98,.14*la))
    disc(cv,c,8.6,Color("8a6a2a"))
    disc(cv,c,6.6,Color(0.55,0.42,0.85,0.85))
    disc(cv,c+Vector2(-1.5,-1.5),2.6,Color(0.9,0.85,1.0,0.35+0.3*la))
    for k in range(8):
        var a: float = TAU*float(k)/8.0+g.real_time*0.4
        cv.draw_line(c+Vector2.from_angle(a)*7.0,c+Vector2.from_angle(a)*8.2,Color("e8d08f"),0.8)

func _labeled_door() -> void:
    ## Porta da frente: dupla, almofadada, com bandeira de vidro em cima.
    ## Aberta (fim do jogo), a luz de fora entra pelo vao.
    var at: Vector2 = g.tile(26,34)
    var free: bool = g.monster_banished
    var wood: Color = Color("6b4a33") if free else Color("4a3340")
    _prism(at,-20,-10,20,10,0,41,Color("2a1e1a"))
    if free:
        _qy(at,10.01,-16,16,0,33,Color(1.0,0.86,0.6,0.85))
        _qy(at,10.02,-16,-11,0,33,wood)
        _qy(at,10.02,11,16,0,33,wood)
    else:
        for side in [-1.0, 1.0]:
            var x0: float = -16.0 if side < 0.0 else 0.4
            var x1: float = -0.4 if side < 0.0 else 16.0
            _qy(at,10.01,x0,x1,0,33,wood)
            _qy(at,10.02,x0+2.5,x1-2.5,4,15,wood.darkened(0.25))
            _qy(at,10.02,x0+2.5,x1-2.5,18,29,wood.darkened(0.25))
            disc(cv,_wp(at,side*-2.6,10.03,17),1.4,Color("c9a15d"))
    _qy(at,10.02,-16,16,34,39,Color(0.55,0.45,0.30,0.6) if free else Color("1b2026"))
    for k in range(1,4):
        var fx: float = -16.0+32.0*float(k)/4.0
        cv.draw_line(_wp(at,fx,10.03,34),_wp(at,fx,10.03,39),Color("2a1e1a"),0.8)
    var p: Vector2 = screen(at)
    _text(p+Vector2(-17,-62),"SAÍDA",12,Color("ebd6b3"))
