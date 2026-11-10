extends RefCounted
class_name ManorMap

const TS: int = 32
const W: int = 53
const H: int = 37

const FOYER_DOOR: Vector2i = Vector2i(26, 27)

var cells: Array = []
var blocked: Dictionary = {}   # celulas de piso fechadas dinamicamente (portas)
var nav: AStarGrid2D
var rooms: Array = [
    {"name":"BIBLIOTECA", "x":2, "y":2, "w":16, "h":13, "shade":Color("253543")},
    {"name":"COZINHA", "x":35, "y":2, "w":16, "h":13, "shade":Color("26343b")},
    {"name":"QUARTO", "x":2, "y":18, "w":16, "h":15, "shade":Color("302d3d")},
    {"name":"OFICINA", "x":35, "y":18, "w":16, "h":15, "shade":Color("30303a")},
    {"name":"SALÃO", "x":19, "y":8, "w":15, "h":20, "shade":Color("302d3c")},
    {"name":"VESTÍBULO", "x":19, "y":28, "w":15, "h":7, "shade":Color("302c39")}
]

func _init() -> void:
    for y in range(H):
        var line: Array = []
        for x in range(W):
            line.append(1)
        cells.append(line)
    # Os corredores tornam as quatro alas acessíveis; os portais são atalhos.
    for room in rooms:
        carve(int(room["x"]), int(room["y"]), int(room["w"]), int(room["h"]))
    carve(17, 8, 3, 4)
    carve(33, 8, 3, 4)
    carve(17, 24, 3, 4)
    carve(33, 24, 3, 4)
    carve(23, 27, 8, 3)
    # Um corredor periférico liga as alas superior e inferior.
    carve(9, 14, 3, 5)
    carve(41, 14, 3, 5)
    # Paredes internas parciais: riscos sem bloquear objetivos.
    wall_line(6, 10, 9, false)
    wall_line(46, 5, 6, true)
    wall_line(6, 25, 3, true)
    wall_line(47, 26, 4, false)
    # Parede que fecha o vestibulo (quarto inicial trancado). A porta em
    # FOYER_DOOR e piso no mapa estatico e bloqueada dinamicamente.
    wall_line(19, 27, 15, true)
    cells[FOYER_DOOR.y][FOYER_DOOR.x] = 0
    # Objetos sólidos visuais são desenhados no jogo, não bloqueiam corredores.
    nav = AStarGrid2D.new()
    nav.region = Rect2i(0, 0, W, H)
    nav.cell_size = Vector2(TS, TS)
    nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    nav.update()
    for y in range(H):
        for x in range(W):
            if cells[y][x] == 1:
                nav.set_point_solid(Vector2i(x, y), true)

func carve(x0: int, y0: int, width: int, height: int) -> void:
    for y in range(max(1, y0), min(H - 1, y0 + height)):
        for x in range(max(1, x0), min(W - 1, x0 + width)):
            cells[y][x] = 0

func wall_line(x0: int, y0: int, length: int, horizontal: bool) -> void:
    for i in range(length):
        var x = x0 + i if horizontal else x0
        var y = y0 if horizontal else y0 + i
        if x >= 1 and y >= 1 and x < W-1 and y < H-1:
            cells[y][x] = 1

func is_wall_cell(x: int, y: int) -> bool:
    if x < 0 or y < 0 or x >= W or y >= H:
        return true
    return cells[y][x] == 1 or blocked.has(Vector2i(x, y))

func set_blocked(cell: Vector2i, closed: bool) -> void:
    # Porta: fecha/abre colisao, linha de visao e pathfinding de uma vez.
    if closed:
        blocked[cell] = true
    else:
        blocked.erase(cell)
    nav.set_point_solid(cell, closed)

func is_wall_at(point: Vector2) -> bool:
    return is_wall_cell(int(floor(point.x / TS)), int(floor(point.y / TS)))

func can_stand(point: Vector2, radius: float = 10.0) -> bool:
    for dx in [-radius, radius]:
        for dy in [-radius, radius]:
            if is_wall_at(point + Vector2(dx, dy)):
                return false
    return true

func slide(pos: Vector2, delta: Vector2, radius: float = 10.0) -> Vector2:
    var nx = pos + Vector2(delta.x, 0)
    if can_stand(nx, radius):
        pos = nx
    var ny = pos + Vector2(0, delta.y)
    if can_stand(ny, radius):
        pos = ny
    return pos

func has_wall_between(a: Vector2, b: Vector2) -> bool:
    var dist = a.distance_to(b)
    if dist < 1.0:
        return false
    var steps = int(ceil(dist / 8.0))
    for i in range(1, steps + 1):
        if is_wall_at(a.lerp(b, float(i) / float(steps))):
            return true
    return false

func ray_end(origin: Vector2, angle: float, max_dist: float) -> Vector2:
    var dir = Vector2.from_angle(angle)
    var previous = origin
    var n = int(ceil(max_dist / 8.0))
    for i in range(1, n + 1):
        var probe = origin + dir * min(float(i) * 8.0, max_dist)
        if is_wall_at(probe):
            return previous
        previous = probe
    return origin + dir * max_dist

func route(a: Vector2, b: Vector2) -> Array:
    var start = Vector2i(int(a.x / TS), int(a.y / TS))
    var finish = Vector2i(int(b.x / TS), int(b.y / TS))
    if is_wall_cell(start.x, start.y) or is_wall_cell(finish.x, finish.y):
        return []
    return nav.get_id_path(start, finish)

func room_name(point: Vector2) -> String:
    var tile = Vector2i(int(point.x / TS), int(point.y / TS))
    for room in rooms:
        if tile.x >= int(room["x"]) and tile.x < int(room["x"]) + int(room["w"]) and tile.y >= int(room["y"]) and tile.y < int(room["y"]) + int(room["h"]):
            return str(room["name"])
    return "CORREDOR"

func cell_center(x: int, y: int) -> Vector2:
    return Vector2((float(x) + 0.5) * TS, (float(y) + 0.5) * TS)
