#!/usr/bin/env python3
"""Gera cache estatico do piso e paredes para o renderer isometrico.

Executar novamente apenas se a geometria/cores do mapa forem modificadas:
    python3 build_render_cache.py
Requer Pillow (pip install Pillow).
"""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'assets' / 'render_cache'
W, H, TS = 53, 37, 32
OX, OY = 1210., 65.
SX, SY = .96, .48
WALL_HEIGHT = 37
rooms = [
    ('BIBLIOTECA', 2,2,16,13,'#253543'),
    ('COZINHA',35,2,16,13,'#26343b'),
    ('QUARTO',2,18,16,15,'#302d3d'),
    ('OFICINA',35,18,16,15,'#30303a'),
    ('SALÃO',19,8,15,20,'#302d3c'),
    ('VESTÍBULO',19,28,15,7,'#302c39'),
]
cells = [[1]*W for _ in range(H)]
def carve(x,y,w,h):
    for yy in range(max(1,y), min(H-1,y+h)):
        for xx in range(max(1,x),min(W-1,x+w)):
            cells[yy][xx]=0
def wall_line(x,y,n,horizontal):
    for i in range(n):
        xx = x+i if horizontal else x
        yy = y if horizontal else y+i
        if 1 <= xx < W-1 and 1 <= yy < H-1:
            cells[yy][xx]=1
for _,x,y,w,h,_ in rooms:
    carve(x,y,w,h)
for r in [(17,8,3,4),(33,8,3,4),(17,24,3,4),(33,24,3,4),(23,27,8,3),(9,14,3,5),(41,14,3,5)]:
    carve(*r)
for r in [(6,10,9,False),(46,5,6,True),(6,25,3,True),(47,26,4,False)]:
    wall_line(*r)
# Parede que fecha o vestibulo; a porta (26,27) e piso e fechada dinamicamente.
wall_line(19,27,15,True)
cells[27][26]=0

def project(p):
    x,y=p
    return (OX+(x-y)*SX,OY+(x+y)*SY)
def color(s):
    return tuple(int(s[i:i+2],16) for i in (1,3,5))+(255,)
def blend(a,b,amount):
    return tuple(round(a[i]*(1-amount)+b[i]*amount) for i in range(3))+(255,)
def minus(a,n):
    return (a[0]-n,a[1]-n)
def plus(a,b):
    return (a[0]+b[0],a[1]+b[1])
def box_polygons(x,y):
    at=((x+.5)*TS,(y+.5)*TS)
    a=project((at[0]-16,at[1]-16))
    b=project((at[0]+16,at[1]-16))
    c=project((at[0]+16,at[1]+16))
    d=project((at[0]-16,at[1]+16))
    lift=(0,-WALL_HEIGHT)
    return [
        [d,c,plus(c,lift),plus(d,lift)],
        [b,c,plus(c,lift),plus(b,lift)],
        [plus(a,lift),plus(b,lift),plus(c,lift),plus(d,lift)]
    ], (d,c,b,plus(d,lift),plus(c,lift),plus(b,lift))
def bounds_polys(polys):
    return [(p[0],p[1]) for polygon in polys for p in polygon]
def ipoly(points, offset):
    return [(round(p[0]-offset[0]),round(p[1]-offset[1])) for p in points]

def floor_color(x,y):
    if cells[y][x]:
        return color('#101925')
    col=color('#2a2d3d')
    for _,rx,ry,rw,rh,c in rooms:
        if rx<=x<rx+rw and ry<=y<ry+rh:
            col=color(c)
            break
    if (x*19+y*11)%8 == 0:
        col=blend(col,(255,255,255,255),.065)
    return col

# O mapa original tem 53x37 tiles. Rasterizar 1x tira milhares de draw calls por frame.
all_corners=[project((x*TS,y*TS)) for x in (0,W) for y in (0,H)]
min_x=math.floor(min(p[0] for p in all_corners))-3
min_y=math.floor(min(p[1] for p in all_corners))-3
max_x=math.ceil(max(p[0] for p in all_corners))+3
max_y=math.ceil(max(p[1] for p in all_corners))+3
w,h=max_x-min_x,max_y-min_y
floor=Image.new('RGBA',(w,h),color('#080d17'))
d=ImageDraw.Draw(floor)
offset=(min_x,min_y)
for y in range(H):
    for x in range(W):
        a=project((x*TS,y*TS))
        b=project(((x+1)*TS,y*TS))
        c=project(((x+1)*TS,(y+1)*TS))
        e=project((x*TS,(y+1)*TS))
        col=floor_color(x,y)
        d.polygon(ipoly([a,b,c,e],offset),fill=col)
        edge=(5,10,17,53)
        # Piso e contornos combinados no png. As linhas sao suavizadas pelo Godot.
        d.line(ipoly([a,b],offset),fill=(20,25,33,255),width=1)
        d.line(ipoly([b,c],offset),fill=(20,25,33,255),width=1)
for n in range(13,27):
    p=project(((26+.5)*TS,(n+.5)*TS))
    def pplus(v): return plus(p,v)
    d.polygon(ipoly([pplus((0,-15)),pplus((30,0)),pplus((0,15)),pplus((-30,0))],offset),fill=color('#503543'))
    d.line(ipoly([pplus((-21,0)),pplus((21,0))],offset),fill=color('#7b5262'),width=1)
OUT.mkdir(parents=True,exist_ok=True)
floor.save(OUT/'floor.png',optimize=True)

# Cada diagonal x+y compartilha profundidade, mas tem sua propria textura com
# transparência apenas FORA das paredes. Nunca aplicamos alpha nas fachadas.
wall_dir=OUT/'walls'
wall_dir.mkdir(parents=True,exist_ok=True)
meta={'floor':{'path':'res://assets/render_cache/floor.png','x':min_x,'y':min_y,'w':w,'h':h},'bands':[]}
for diag in range(W+H-1):
    positions=[(x,diag-x) for x in range(W) if 0<=diag-x<H and cells[diag-x][x]==1]
    if not positions: continue
    corners=[]
    for x,y in positions:
        polys,_=box_polygons(x,y)
        corners.extend(bounds_polys(polys))
    lo_x=math.floor(min(p[0] for p in corners))-5
    lo_y=math.floor(min(p[1] for p in corners))-12
    hi_x=math.ceil(max(p[0] for p in corners))+5
    hi_y=math.ceil(max(p[1] for p in corners))+5
    img=Image.new('RGBA',(hi_x-lo_x,hi_y-lo_y),(0,0,0,0))
    dd=ImageDraw.Draw(img)
    local=(lo_x,lo_y)
    for x,y in positions:
        polys,edges=box_polygons(x,y)
        col=color('#344051') if (x*3+y*5)%7 > 1 else color('#3a4755')
        for polygon,fill in zip(polys,[blend(col,(0,0,0,255),.22),blend(col,(0,0,0,255),.38),blend(col,(255,255,255,255),.14)]):
            dd.polygon(ipoly(polygon,local),fill=fill)
        d0,c0,b0,dl,cl,bl=edges
        dd.line(ipoly([dl,cl],local),fill=(226,199,188,110),width=1)
        dd.line(ipoly([bl,cl],local),fill=(18,18,29,155),width=1)
        if (x*5+y*7)%13==0:
            s=minus(project(((x+.5)*TS,(y+.5)*TS)),WALL_HEIGHT+10) if False else None
            wall_center=project(((x+.5)*TS,(y+.5)*TS))
            s=plus(wall_center,(0,-WALL_HEIGHT-10))
            dd.line(ipoly([plus(s,(-6,0)),plus(s,(7,2))],local),fill=(145,154,173,90),width=1)
    name=f'd{diag:02d}.png'
    img.save(wall_dir/name,optimize=True)
    meta['bands'].append({'path':'res://assets/render_cache/walls/'+name,
                          'diag':diag,'x':lo_x,'y':lo_y,'w':hi_x-lo_x,'h':hi_y-lo_y,
                          'z':OY+(diag+1)*TS*SY,'count':len(positions)})
(OUT/'cache.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'floor: {w}x{h} / {len(meta["bands"])} bands / {sum(b["count"] for b in meta["bands"])} walls')
