shader_type canvas_item;
// Pos-processamento do jumpscare: sinal de TV morrendo por cima do rosto.
// Escurece e esmaga o contraste, rasga a imagem em faixas, faz as linhas
// tremerem, deforma o centro (o rosto "incha" e repuxa), separa as cores
// e cobre tudo de chiado em blocos. "amount" (0..1) controla a intensidade.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount = 0.0;
uniform float clock = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    float frame = floor(clock * 30.0);
    vec2 c = uv - 0.5;
    // Rosto incha e repuxa: lente que pulsa e torce no centro.
    float r = length(c);
    float bulge = 0.22 * amount * (0.6 + 0.4 * sin(clock * 23.0));
    uv = 0.5 + c * (1.0 - bulge * smoothstep(0.55, 0.0, r));
    uv += vec2(c.y, -c.x) * 0.05 * amount * sin(clock * 17.0) * smoothstep(0.5, 0.0, r);
    // Faixas rasgadas: blocos horizontais deslocados a cada quadro.
    float band = floor(uv.y * 26.0);
    float tear = step(0.62, hash(vec2(band, frame)));
    uv.x += (hash(vec2(band * 3.7, frame)) - 0.5) * 0.16 * amount * tear;
    // Cada linha treme um pouco (sinal sem sincronismo) e ondula.
    float line = floor(uv.y * 360.0);
    uv.x += (hash(vec2(line, frame)) - 0.5) * 0.0025 * amount;
    uv.x += sin(uv.y * 48.0 + clock * 60.0) * 0.003 * amount;
    // Salto vertical de vez em quando (a imagem "pula" de quadro).
    uv.y += step(0.86, hash(vec2(frame, 7.0))) * (hash(vec2(frame, 9.0)) - 0.5) * 0.12 * amount;
    // Aberracao cromatica forte.
    float ab = 0.006 * amount * (0.4 + r * 1.4);
    vec3 col;
    col.r = texture(screen_tex, uv + vec2(ab, ab * 0.3)).r;
    col.g = texture(screen_tex, uv).g;
    col.b = texture(screen_tex, uv - vec2(ab, ab * 0.3)).b;
    // Mais escuro: contraste esmagado, tudo puxado para o vermelho-sangue.
    // (o que ja brilha, como olhos e dentes, e preservado e ate realcado)
    vec3 glow = max(col - 0.55, vec3(0.0));
    col = pow(max(col, vec3(0.0)), vec3(1.0 + 0.35 * amount));
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(luma * 1.15, luma * 0.55, luma * 0.6), 0.35 * amount);
    col *= 1.0 - 0.18 * amount;
    col += glow * 0.8 * amount;
    // Chiado em blocos de 3 px, mais um chiado fino por cima.
    vec2 px = floor(FRAGCOORD.xy / 3.0);
    float snow = hash(px + frame * 13.1);
    float fine = hash(FRAGCOORD.xy + frame * 7.3);
    col = mix(col, vec3(snow * 0.55), 0.17 * amount);
    col += (fine - 0.5) * 0.16 * amount;
    // Linhas de varredura e uma faixa clara que rola de cima para baixo.
    col *= 1.0 - 0.18 * amount * step(0.5, fract(FRAGCOORD.y * 0.5));
    float roll = fract(clock * 1.7);
    col += vec3(0.10, 0.06, 0.07) * amount * smoothstep(0.06, 0.0, abs(SCREEN_UV.y - roll));
    // Quadros em que o sinal cai: quase so chiado no escuro.
    float drop = step(0.93, hash(vec2(frame, 3.0)));
    col = mix(col, vec3(snow * 0.32), drop * amount);
    // Vinheta pesada.
    col *= 1.0 - dot(c, c) * 1.5 * amount;
    COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
