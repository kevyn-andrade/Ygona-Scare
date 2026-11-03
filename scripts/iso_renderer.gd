extends RefCounted
class_name IsoRenderer
## YGONA SCARE: apresentacao 2.5D projetada a 45 graus (losangos 2:1).
## A simulacao, as colisoes e o pathfinding continuam em coordenadas 2D.
## Toda a arte foi desenhada para o projeto com primitivas do Godot.

const TS: int = 32
const VIEW_WIDTH: float = 1152.0
const VIEW_HEIGHT: float = 720.0
const LIGHT_HALF_ANGLE: float = 0.53
const SKEW_X: float = 0.96
const SKEW_Y: float = 0.48
const ORIGIN: Vector2 = Vector2(1210.0, 65.0)
const WALL_HEIGHT: float = 37.0

var g
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
        {"at":g.tile(39,5),"w":105.0,"d":37.0,"h":23.0,"kind":"table","c":Color("617076")},
        {"at":g.tile(47,6),"w":66.0,"d":36.0,"h":24.0,"kind":"table","c":Color("65747a")},
        {"at":g.tile(39,11),"w":82.0,"d":33.0,"h":22.0,"kind":"table","c":Color("77675d")},
        {"at":g.tile(5,22),"w":85.0,"d":74.0,"h":19.0,"kind":"bed","c":Color("6e557f")},
        {"at":g.tile(14,22),"w":64.0,"d":45.0,"h":30.0,"kind":"table","c":Color("664955")},
        {"at":g.tile(7,30),"w":75.0,"d":28.0,"h":20.0,"kind":"table","c":Color("73515d")},
        {"at":g.tile(38,27),"w":73.0,"d":36.0,"h":24.0,"kind":"table","c":Color("6c6772")},
        {"at":g.tile(49,29),"w":55.0,"d":48.0,"h":37.0,"kind":"table","c":Color("545965")},
        {"at":g.tile(44,27),"w":53.0,"d":20.0,"h":45.0,"kind":"mirror","c":Color("7b5f6f")},
        {"at":g.tile(26,29),"w":62.0,"d":36.0,"h":31.0,"kind":"altar","c":Color("876c66")}
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
    g.draw_colored_polygon(PackedVector2Array(points), color)

func _diamond(x: int, y: int, color: Color) -> void:
    var ul: Vector2 = screen(Vector2(x*TS, y*TS))
    var ur: Vector2 = screen(Vector2((x+1)*TS, y*TS))
    var lr: Vector2 = screen(Vector2((x+1)*TS, (y+1)*TS))
    var ll: Vector2 = screen(Vector2(x*TS, (y+1)*TS))
    poly([ul, ur, lr, ll], color)
    g.draw_line(ul,ur,Color(0.025,0.04,0.065,0.21),1.0)
    g.draw_line(ur,lr,Color(0.025,0.04,0.065,0.21),1.0)

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
    g.draw_line(d+lift,c+lift,Color(0.95,0.85,0.79,0.35*opacity),1.2)
    g.draw_line(b+lift,c+lift,Color(0.05,0.04,0.09,0.45*opacity),1.2)

func _wall(x: int,y: int) -> void:
    var pt: Vector2 = g.tile(x,y)
    # Fachadas sempre opacas: nada fica translucido ao se aproximar.
    var col: Color = Color("344051") if ((x*3+y*5)%7 > 1) else Color("3a4755")
    _box(pt,32.0,32.0,WALL_HEIGHT,col)
    if (x*5+y*7)%13 == 0:
        var s: Vector2 = screen(pt)-Vector2(0,WALL_HEIGHT+10)
        g.draw_line(s-Vector2(6,0),s+Vector2(7,2),Color(0.6,0.63,0.69,.14),1.0)

func _floor() -> void:
    g.draw_rect(Rect2(0,0,VIEW_WIDTH,VIEW_HEIGHT),Color("080d17"))
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
            g.draw_line(p-Vector2(21,0),p+Vector2(21,0),Color("7b5262"),1.0)
    var altar_pt: Vector2 = screen(g.tile(26,29))
    if _onscreen(altar_pt):
        g.draw_arc(altar_pt,45.0,0,TAU,60,Color("9b7881"),2.3)
        if g.ritual_running:
            g.draw_arc(altar_pt,45.0+4.0*sin(g.time_passed*4),0,TAU,60,Color("ebb1d6"),3.0)

func _cached_floor_details() -> void:
    # O tapete e estatico e ja esta no cache. O ritual deve continuar animado.
    var altar_pt: Vector2 = screen(g.tile(26,29))
    if _onscreen(altar_pt):
        g.draw_arc(altar_pt,45.0,0,TAU,60,Color("9b7881"),2.3)
        if g.ritual_running:
            g.draw_arc(altar_pt,45.0+4.0*sin(g.time_passed*4),0,TAU,60,Color("ebb1d6"),3.0)

func _floor_light() -> void:
    if not g.light_on or g.flashlight_pose < 0.86 or g.energy <= 0.0 or g.in_hiding:
        return
    var begin: Vector2 = screen(g.draw_player)
    var rays: Array = [begin]
    var rays2: Array = [begin]
    var count: int = 28
    var r: float = g.light_range()
    for n in range(count+1):
        var a: float = g.look.angle()+lerpf(-LIGHT_HALF_ANGLE,LIGHT_HALF_ANGLE,float(n)/count)
        var beam_edge: Vector2 = screen(g.map.ray_end(g.draw_player,a,r))
        rays.append(beam_edge)
        # Reutiliza as amostras centrais do cone externo. Corta pela metade
        # o numero de testes de colisao por quadro sem deixar a luz atravessar parede.
        if n >= 7 and n <= 21:
            rays2.append(begin.lerp(beam_edge,0.84))
    poly(rays,Color(0.60,0.38,0.95,.23) if g.ghost_mode else Color(1.0,.83,.52,.19))
    poly(rays2,Color(.72,.56,1.0,.18) if g.ghost_mode else Color(1.0,.95,.69,.17))
    g.draw_circle(begin,18,Color(.63,.37,.94,.10) if g.ghost_mode else Color(.98,.88,.62,.08))

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
    return kind != "exit" and kind != "altar"

func _marker(at: Vector2, color: Color) -> void:
    var p: Vector2 = screen(at)
    g.draw_circle(p+Vector2(0,-15),20.0+3.0*sin(g.time_passed*3.2),Color(color.r,color.g,color.b,.10))
    poly([p+Vector2(0,-37),p+Vector2(12,-21),p+Vector2(0,-6),p+Vector2(-12,-21)],color)
    g.draw_circle(p+Vector2(0,-22),3,Color("fff0ce"))

func _scene_object(obj: Dictionary) -> void:
    var p: Vector2 = screen(obj["at"])
    var kind: String = obj["kind"]
    if kind == "fragment":
        _marker(obj["at"],Color("e9c37d"))
    elif kind == "key":
        g.draw_circle(p+Vector2(-7,-14),7,Color("e1bc79"),false,2.5)
        g.draw_line(p+Vector2(-1,-13),p+Vector2(12,-1),Color("e1bc79"),3.0)
    elif kind == "book":
        _box(obj["at"],20.0,14.0,7.0,Color("7d5261") if int(obj["number"]) % 2 else Color("4e7982"))
        _text(p+Vector2(-6,-18),str(obj["number"]),11,Color("f6dfbb"))
    elif kind == "seal":
        g.draw_circle(p+Vector2(0,-8),16.0,Color("b19be8") if obj["number"] in g.mirror_sequence else Color("72637c"))
        g.draw_circle(p+Vector2(0,-8),11.0,Color("32283b"))
        _text(p+Vector2(-4,-3),str(obj["number"]),12,Color("f1e0ff"))
    elif kind == "box":
        _box(obj["at"],32.0,25.0,18.0,Color("ae8465"))
        g.draw_circle(p+Vector2(0,-24),4.0,Color("f6d8a1"))
    elif kind == "clue":
        g.draw_circle(p+Vector2(0,-19),19,Color(.64,.42,.96,.26))
        g.draw_arc(p+Vector2(0,-19),16,0,TAU,32,Color("bca1ff"),2.0)
        _text(p+Vector2(-7,-13),"?",17,Color("f5deff"))

func _furniture(obj: Dictionary) -> void:
    _box(obj["at"],obj["w"],obj["d"],obj["h"],obj["c"])
    var p: Vector2 = screen(obj["at"])
    var kind: String = obj["kind"]
    if kind == "shelf":
        for i in range(3):
            g.draw_line(p+Vector2(-17+i*10,-obj["h"]-5),p+Vector2(-15+i*10,-obj["h"]+10),Color("a78e73"),3.0)
    elif kind == "bed":
        g.draw_circle(p+Vector2(-13,-obj["h"]-6),13,Color("c3b5c3"))
    elif kind == "mirror":
        g.draw_line(p+Vector2(-8,-obj["h"]-19),p+Vector2(8,-obj["h"]-8),Color("bed0d5"),4.0)
        g.draw_line(p+Vector2(0,-obj["h"]-20),p+Vector2(9,-obj["h"]-32),Color("a38abd"),3.0)
    elif kind == "altar":
        g.draw_arc(p+Vector2(0,-obj["h"]-3),21,0,TAU,24,Color("f4bf9d"),2.5)

func _hide_spot(at: Vector2) -> void:
    _box(at,32.0,30.0,49.0,Color("676175"))
    var p: Vector2 = screen(at)
    g.draw_line(p+Vector2(-5,-46),p+Vector2(-5,-12),Color("b6a8b1"),1.3)
    g.draw_circle(p+Vector2(5,-24),2.4,Color("d7c19c"))

func _portal(at: Vector2) -> void:
    var p: Vector2 = screen(at)
    if not g.light_on or not g.ghost_mode:
        return
    if not g.is_illuminated(at) and g.player.distance_to(at)>49.0:
        return
    var a: float = 0.72+0.27*sin(g.time_passed*4.0)
    g.draw_circle(p+Vector2(0,-17),21,Color(.51,.25,.93,.16*a))
    g.draw_arc(p+Vector2(0,-17),18.0,0,TAU,40,Color(.77,.60,1.0,a),3.1)
    g.draw_line(p+Vector2(-7,-25),p+Vector2(7,-10),Color("dcc2ff"),2.0)

func _battery(at: Vector2) -> void:
    var p: Vector2 = screen(at)
    g.draw_circle(p+Vector2(0,-11),13.0,Color(.30,1.0,.76,.14))
    g.draw_rect(Rect2(p+Vector2(-11,-17),Vector2(21,14)),Color("6bdfb1"))
    g.draw_rect(Rect2(p+Vector2(10,-13),Vector2(3,6)),Color("f2e9bd"))
    g.draw_line(p+Vector2(-3,-11),p+Vector2(4,-11),Color("205c54"),2.0)

func _character() -> void:
    var center: Vector2 = screen(g.draw_player)
    if g.in_hiding:
        g.draw_circle(center + Vector2(0,-9),7,Color("b9a9df"))
        return
    # A protagonista e desenhada em uma escala maior, para o gesto ficar legivel.
    g.draw_set_transform(center, 0.0, Vector2(1.35,1.35))
    var p: Vector2 = Vector2.ZERO
    var bob: float = sin(g.time_passed*(14.0 if g.running else 8.0)) * (1.9 if g.moving else 0.35)
    # Sombra, sapatos e pernas.
    poly([p+Vector2(-18,-1),p+Vector2(0,8),p+Vector2(18,-1),p+Vector2(0,-10)],Color(0,0,0,.42))
    g.draw_line(p+Vector2(-8,-12),p+Vector2(-8,-1+bob),Color("23243d"),6.4)
    g.draw_line(p+Vector2(8,-12),p+Vector2(8,-1-bob),Color("23243d"),6.4)
    g.draw_line(p+Vector2(-8,0),p+Vector2(-12,3),Color("101422"),5.0)
    g.draw_line(p+Vector2(8,0),p+Vector2(12,3),Color("101422"),5.0)
    # Saia, blusa e mangas em camadas.
    poly([p+Vector2(-18,-12),p+Vector2(-14,-29+bob),p+Vector2(14,-29+bob),p+Vector2(18,-12)],Color("4a3c62"))
    poly([p+Vector2(-13,-30+bob),p+Vector2(-9,-39+bob),p+Vector2(9,-39+bob),p+Vector2(13,-30+bob),p+Vector2(9,-13),p+Vector2(-9,-13)],Color("6e4668"))
    poly([p+Vector2(-13,-30+bob),p+Vector2(-9,-39+bob),p+Vector2(-2,-35+bob),p+Vector2(-5,-16)],Color("523656"))
    # Duas bordas do decote em V, com regiao central onde a lanterna some.
    var chest: Vector2 = p + Vector2(0,-28+bob)
    g.draw_circle(chest+Vector2(-7,-4),8,Color("824b6e"))
    g.draw_circle(chest+Vector2(7,-4),8,Color("824b6e"))
    poly([chest+Vector2(-7,-9),chest+Vector2(7,-9),chest+Vector2(0,0)],Color("b67d6e"))
    g.draw_line(chest+Vector2(-8,-10),chest,Color("d79dae"),2.0)
    g.draw_line(chest+Vector2(8,-10),chest,Color("d79dae"),2.0)
    # Pescoço, rosto, olhos e cabelo.
    g.draw_line(p+Vector2(0,-42+bob),p+Vector2(0,-38+bob),Color("b77d69"),6)
    g.draw_circle(p+Vector2(0,-47+bob),12.2,Color("1a1425"))
    g.draw_circle(p+Vector2(0,-46+bob),9.1,Color("bb806b"))
    poly([p+Vector2(-13,-51+bob),p+Vector2(-7,-61+bob),p+Vector2(6,-61+bob),p+Vector2(13,-51+bob),p+Vector2(5,-55+bob),p+Vector2(-6,-54+bob)],Color("241927"))
    g.draw_line(p+Vector2(-12,-49+bob),p+Vector2(-14,-28+bob),Color("261a33"),5.7)
    g.draw_line(p+Vector2(12,-49+bob),p+Vector2(15,-27+bob),Color("261a33"),5.7)
    g.draw_circle(p+Vector2(-3.3,-46+bob),1.3,Color("eee4dd"))
    g.draw_circle(p+Vector2(3.3,-46+bob),1.3,Color("eee4dd"))
    g.draw_line(p+Vector2(-2,-41+bob),p+Vector2(2,-41+bob),Color("6c3a4d"),1.3)
    # CINCO MOMENTOS DO GESTO:
    # 0%: lanterna completamente escondida no decote, mao na cintura;
    # 0-25%: a mao alcanca o meio do decote;
    # 25-60%: ela puxa o corpo da lanterna de dentro da roupa;
    # 60-100%: ergue o braco e mira para a frente.
    # Ao guardar, a animacao se repete em ordem inversa.
    var pose: float = clampf(g.flashlight_pose,0.0,1.0)
    var reach: float = smoothstep(0.0,0.25,pose)
    var extract: float = smoothstep(0.25,0.60,pose)
    var extend: float = smoothstep(0.60,1.0,pose)
    var aim: Vector2 = Vector2((g.look.x-g.look.y)*SKEW_X,(g.look.x+g.look.y)*SKEW_Y).normalized()
    if aim.length_squared()<0.01:
        aim=Vector2.RIGHT
    var rest: Vector2 = p+Vector2(17,-18+bob)
    var raised: Vector2 = chest+Vector2(0,-9.0*extract)
    var ready: Vector2 = chest+aim*33.0+Vector2(3,-8)
    var hand: Vector2 = rest.lerp(chest,reach)
    if pose > 0.25:
        hand=chest.lerp(raised,extract)
    if pose > 0.60:
        hand=raised.lerp(ready,extend)
    # O ombro, antebraco e dedos acompanham efetivamente o objeto.
    var shoulder: Vector2 = p+Vector2(12,-36+bob)
    var elbow: Vector2 = shoulder.lerp(hand,0.51)+Vector2(7,6)
    g.draw_line(shoulder,elbow,Color("754a60"),8.0)
    g.draw_line(elbow,hand,Color("c38b78"),5.1)
    # A haste emerge verticalmente do decote ANTES de ser levada a frente.
    # Ela nao e desenhada no estado guardado (evita um objeto colado ao peito).
    if pose > 0.28:
        var shaft_start: Vector2
        var shaft_end: Vector2
        if pose <= 0.60:
            shaft_start=chest+Vector2(0,-2.0*extract)
            shaft_end=chest+Vector2(0,-17.0*extract)
        else:
            shaft_start=hand-aim*3.0
            shaft_end=hand+aim*15.0
        g.draw_line(shaft_start,shaft_end,Color("4b3f5d"),8.3)
        g.draw_line(shaft_start,shaft_end,Color("e1bd8c"),5.5)
        var lens_col: Color = Color("b7a1ed") if g.ghost_mode and g.light_on else Color("fbe4a3")
        g.draw_circle(shaft_end,4.5,lens_col)
        if g.light_on and pose > 0.86:
            g.draw_circle(shaft_end,7.8,Color(.72,.52,1,.25) if g.ghost_mode else Color(1,.94,.62,.25))
    # Sobreposicao das duas lapelas: esconde a base da lanterna dentro do decote.
    # Esta camada frontal e o que torna a extracao visualmente convincente.
    poly([chest+Vector2(-9,-7),chest+Vector2(-3,-5),chest+Vector2(0,2),chest+Vector2(-9,1)],Color("73415f"))
    poly([chest+Vector2(9,-7),chest+Vector2(3,-5),chest+Vector2(0,2),chest+Vector2(9,1)],Color("754164"))
    g.draw_circle(hand,3.1,Color("daa18c"))
    # Sem efeito de transformacao nos objetos e HUD desenhados em seguida.
    g.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _monster() -> void:
    var p: Vector2 = screen(g.draw_monster)
    var bob: float = sin(g.time_passed*6.0)*2.0 if not g.monster_lit else 0.0
    poly([p+Vector2(-19,1),p+Vector2(0,8),p+Vector2(19,1),p+Vector2(0,-8)],Color(0,0,0,.48))
    poly([p+Vector2(-24,-4),p+Vector2(-16,-48+bob),p+Vector2(-9,-63+bob),p+Vector2(9,-63+bob),p+Vector2(19,-46+bob),p+Vector2(24,-3)],Color("0a0b1b"))
    poly([p+Vector2(-14,-28+bob),p+Vector2(0,-12),p+Vector2(14,-28+bob),p+Vector2(9,-49+bob),p+Vector2(-9,-49+bob)],Color("302038"))
    g.draw_line(p+Vector2(-18,-44+bob),p+Vector2(-27,-14+bob),Color("151021"),8.0)
    g.draw_line(p+Vector2(18,-44+bob),p+Vector2(27,-15+bob),Color("151021"),8.0)
    g.draw_circle(p+Vector2(0,-59+bob),13,Color("181122"))
    g.draw_circle(p+Vector2(0,-58+bob),9,Color("765b6b"))
    # Mechas espectrais violeta, para a silhueta ser reconhecível sem copiar imagem real.
    for sx in [-12, -7, 8, 13]:
        g.draw_line(p+Vector2(sx,-66+bob),p+Vector2(sx*1.1,-34+bob),Color("4b305d"),2.5)
    var eyes: Color = Color("c7f3ff") if g.monster_lit else Color("f475a2")
    g.draw_circle(p+Vector2(-4,-59+bob),2.6,eyes)
    g.draw_circle(p+Vector2(5,-59+bob),2.6,eyes)
    g.draw_line(p+Vector2(-4,-52+bob),p+Vector2(5,-51+bob),Color("d59cac"),1.8)
    if g.monster_lit:
        g.draw_arc(p+Vector2(0,-37),34,0,TAU,40,Color(.65,.83,1.0,.52),2.0)
    elif g.monster_state=="PERSEGUINDO":
        g.draw_arc(p+Vector2(0,-37),35,0,TAU,40,Color(.98,.25,.44,.55),2.2)

func _text(at: Vector2, label: String, size: int, color: Color) -> void:
    g.draw_string(ThemeDB.fallback_font,at+Vector2(1.3,1.3),label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0,0,.85))
    g.draw_string(ThemeDB.fallback_font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

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
    if g.ritual_running:
        var p: Vector2 = screen(g.tile(26,29))
        for i in range(9):
            var ang: float = TAU*float(i)/9.0 + g.time_passed*1.7
            g.draw_circle(p+Vector2(cos(ang)*44.0,sin(ang)*20.0-22),3.0,Color("eeb3d9"))

func draw_world() -> void:
    if floor_texture != null:
        g.draw_texture(floor_texture, floor_origin - g.camera)
        _cached_floor_details()
    else:
        _floor()
    _floor_light()
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
    if not g.monster_banished:
        entities.append({"kind":"monster","z":project(g.draw_monster).y-g.camera.y})
    entities.append({"kind":"hero","z":project(g.draw_player).y-g.camera.y})
    entities.append({"kind":"door","z":project(g.tile(26,34)).y-g.camera.y})
    entities.sort_custom(func(a,b): return float(a["z"]) < float(b["z"]))
    for entity in entities:
        var kind: String = entity["kind"]
        match kind:
            "wall_band":
                var band: Dictionary = entity["data"]
                g.draw_texture(band["tex"],band["offset"]-g.camera)
            "wall": _wall(entity["x"],entity["y"])
            "furniture": _furniture(entity["data"])
            "item": _scene_object(entity["data"])
            "battery": _battery(entity["at"])
            "hide": _hide_spot(entity["at"])
            "portal": _portal(entity["at"])
            "bottle":
                var p: Vector2 = screen(entity["at"])
                g.draw_circle(p+Vector2(0,-10),6,Color("90cce4"))
                g.draw_arc(p+Vector2(0,-10),17,0,TAU,28,Color(.70,.83,1,.30),2)
            "monster": _monster()
            "hero": _character()
            "door": _labeled_door()
    _clues_and_ritual()
    # Gradiente sombrio de vinheta em quatro faixas discretas.
    g.draw_rect(Rect2(0,0,32,VIEW_HEIGHT),Color(0,0,.02,.23))
    g.draw_rect(Rect2(VIEW_WIDTH-32,0,32,VIEW_HEIGHT),Color(0,0,.02,.23))
