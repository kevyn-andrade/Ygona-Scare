shader_type canvas_item;
// Escuridao fora do cone da lanterna.
// "mask" e uma textura em meia resolucao onde branco = chao iluminado.
// Como a vista e 2.5D, tudo que esta ate "lift" acima de um chao iluminado
// (paredes, moveis) tambem aparece: a mascara e varrida para cima.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform float darkness = 0.95;
uniform vec3 tint = vec3(0.0, 0.0, 0.012);
uniform float lift = 0.052;      // altura das paredes em UV (37 px / 720 px)
uniform vec2 blur = vec2(0.0045, 0.0072);

float swept(vec2 uv) {
    float m = 0.0;
    for (int k = 0; k < 4; k++) {
        m = max(m, texture(mask, uv + vec2(0.0, lift * float(k) / 3.0)).r);
    }
    return m;
}

void fragment() {
    float m = swept(UV) * 0.4;
    m += swept(UV + vec2(blur.x, blur.y)) * 0.15;
    m += swept(UV + vec2(-blur.x, blur.y)) * 0.15;
    m += swept(UV + vec2(blur.x, -blur.y)) * 0.15;
    m += swept(UV + vec2(-blur.x, -blur.y)) * 0.15;
    float lit = smoothstep(0.0, 0.6, m);
    COLOR = vec4(tint, darkness * (1.0 - lit));
}
