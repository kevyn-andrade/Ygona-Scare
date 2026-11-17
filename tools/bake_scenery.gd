extends SceneTree
## Refaz o cache do cenario (piso inteiro + uma faixa de parede por diagonal)
## com o acabamento de cada comodo, usando o proprio IsoRenderer.
## Precisa de janela, pois desenha na GPU:
##   godot --path . --script res://tools/bake_scenery.gd
## Depois rode "godot --headless --path . --import" para gerar os .import.

const CACHE_DIR: String = "res://assets/render_cache"
const DrawLayer = preload("res://scripts/draw_layer.gd")

var game: Node2D

func _initialize() -> void:
    call_deferred("_run")

func _paint(size: Vector2i, cam: Vector2, transparent: bool, painter: Callable) -> Image:
    var vp: SubViewport = SubViewport.new()
    vp.size = size
    vp.disable_3d = true
    vp.transparent_bg = transparent
    vp.render_target_update_mode = SubViewport.UPDATE_ONCE
    var layer: Node2D = DrawLayer.new()
    layer.painter = func(c: CanvasItem) -> void:
        game.iso_renderer.cv = c
        game.camera = cam
        painter.call()
    vp.add_child(layer)
    root.add_child(vp)
    for i in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    var img: Image = vp.get_texture().get_image()
    vp.queue_free()
    return img

func _run() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    await process_frame
    var r = game.iso_renderer
    var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CACHE_DIR+"/cache.json"))
    var f: Dictionary = meta["floor"]
    var fsize: Vector2i = Vector2i(int(f["w"]),int(f["h"]))
    var floor_img: Image = await _paint(fsize,Vector2(float(f["x"]),float(f["y"])),false,func() -> void:
        r.bake_floor(Vector2(fsize)))
    floor_img.save_png(ProjectSettings.globalize_path(str(f["path"])))
    print("piso: ", fsize)
    # Paredes: uma imagem por diagonal (x+y), ordenada pela profundidade.
    var walls_dir: String = ProjectSettings.globalize_path(CACHE_DIR+"/walls")
    for old in DirAccess.get_files_at(walls_dir):
        DirAccess.remove_absolute(walls_dir.path_join(old))
    var bands: Array = []
    var half_w: float = 16.0*IsoRenderer.SKEW_X*2.0
    var half_h: float = 16.0*IsoRenderer.SKEW_Y*2.0
    for diag in range(ManorMap.W+ManorMap.H-1):
        var cells: Array = []
        for x in range(ManorMap.W):
            var y: int = diag-x
            if y >= 0 and y < ManorMap.H and game.map.cells[y][x] == 1:
                cells.append(Vector2i(x,y))
        if cells.is_empty():
            continue
        var lo: Vector2 = Vector2(INF,INF)
        var hi: Vector2 = Vector2(-INF,-INF)
        var z: float = 0.0
        for cell in cells:
            var p: Vector2 = r.project(game.tile(cell.x,cell.y))
            z = p.y
            lo = lo.min(p+Vector2(-half_w-4.0,-half_h-IsoRenderer.WALL_HEIGHT-8.0))
            hi = hi.max(p+Vector2(half_w+4.0,half_h+4.0))
        var origin: Vector2 = lo.floor()
        var size: Vector2i = Vector2i((hi-origin).ceil())
        var img: Image = await _paint(size,origin,true,func() -> void:
            for cell in cells:
                r.bake_wall(cell.x,cell.y))
        var path: String = CACHE_DIR+"/walls/d%02d.png" % diag
        img.save_png(ProjectSettings.globalize_path(path))
        bands.append({"path":path,"diag":diag,"x":int(origin.x),"y":int(origin.y),"w":size.x,"h":size.y,"z":snappedf(z,0.01),"count":cells.size()})
    meta["bands"] = bands
    var out: FileAccess = FileAccess.open(CACHE_DIR+"/cache.json",FileAccess.WRITE)
    out.store_string(JSON.stringify(meta,"  "))
    out.close()
    print("paredes: ", bands.size(), " faixas")
    quit()
