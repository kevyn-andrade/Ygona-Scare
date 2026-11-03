#!/usr/bin/env python3
"""Valida o pacote sem precisar iniciar o editor Godot."""
import json, struct, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def png_size(path):
    with path.open('rb') as fh:
        data=fh.read(24)
    assert data[:8]==b'\x89PNG\r\n\x1a\n',f'PNG invalido: {path}'
    return struct.unpack('>II',data[16:24])

meta=json.loads((ROOT/'assets/render_cache/cache.json').read_text())
f=meta['floor']
floor=ROOT/f['path'].replace('res://','')
assert png_size(floor)==(f['w'],f['h'])
assert 75 <= len(meta['bands']) <= 95
assert sum(int(b['count']) for b in meta['bands'])==644
for b in meta['bands']:
    p=ROOT/b['path'].replace('res://','')
    assert png_size(p)==(b['w'],b['h']),(p,b)
assert len(list((ROOT/'assets/render_cache/walls').glob('*.png')))==len(meta['bands'])
for file in (ROOT/'assets/audio').glob('*.wav'):
    with wave.open(str(file),'rb') as audio:
        assert audio.getnframes()>0,file
for file in [ROOT/'project.godot',ROOT/'scenes/main.tscn',*(ROOT/'scripts').glob('*.gd')]:
    assert file.stat().st_size>50,file
render=(ROOT/'scripts/iso_renderer.gd').read_text()
game=(ROOT/'scripts/game.gd').read_text()
assert 'opacity = 0.26' not in render
assert 'wall_bands' in render and 'floor_texture' in render
assert 'g.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)' in render
assert 'if pose > 0.28:' in render
assert 'var flashlight_pose: float = 0.0' in game
assert 'if energy < 45.0:' in game
assert 'Engine.get_physics_interpolation_fraction()' in game
print(f'OK: piso {f["w"]}x{f["h"]}, {len(meta["bands"])} faixas de parede, 644 blocos, {len(list((ROOT/"assets/audio").glob("*.wav")))} audios, controles e animacao presentes')
