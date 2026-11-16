shader_type canvas_item;
// Filtro de pavor aplicado sobre o mundo (o HUD fica por cima, nitido).
// Granulado de filme, vinheta, cores drenadas e aberracao cromatica que
// pioram conforme a entidade se aproxima; "glitch" rasga a imagem em faixas.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float fear = 0.0;
uniform float glitch = 0.0;
uniform float grain = 0.06;
uniform float clock = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 c = uv - 0.5;
    // A imagem "respira" pelas bordas.
    uv += c * dot(c, c) * 0.07 * fear * sin(clock * 2.3);
    float band = floor(uv.y * 34.0);
    float tear = step(0.72, hash(vec2(band, floor(clock * 22.0))));
    uv.x += (hash(vec2(band * 3.1, floor(clock * 22.0))) - 0.5) * 0.09 * glitch * tear;
    float ab = (0.0010 + 0.0055 * fear + 0.018 * glitch) * length(c) * 2.0;
    vec3 col;
    col.r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
    col.g = texture(screen_tex, uv).g;
    col.b = texture(screen_tex, uv - vec2(ab, 0.0)).b;
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(luma) * vec3(1.06, 0.93, 0.93), 0.22 + 0.38 * fear);
    col += (hash(uv * vec2(1152.0, 720.0) + fract(clock) * 91.7) - 0.5) * (grain + 0.09 * fear + 0.2 * glitch);
    col *= 1.0 - dot(c, c) * (0.85 + 0.9 * fear);
    COLOR = vec4(col, 1.0);
}
