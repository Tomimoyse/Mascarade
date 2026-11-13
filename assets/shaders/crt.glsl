// Postprocesado CRT. Se aplica al dibujar el canvas interno escalado a la ventana,
// por lo que el fragment shader se ejecuta una vez por píxel real de pantalla
// mientras que 'tc' sigue estando en el espacio del canvas interno (0..1).
//
// Efectos: curvatura, scanlines alineadas a la rejilla de píxeles virtuales,
// máscara de apertura, aberración cromática, viñeta y suma del bloom.
// uCrt y uBloom permiten apagar cada parte desde las opciones.

uniform Image uBloomTex;
uniform vec2  uCanvasRes;  // 640x360
uniform float uCrt;        // 0 = apagado, 1 = encendido
uniform float uBloom;      // cantidad de bloom (0 = apagado)

const float PI = 3.14159265;

// Distorsión de barril: acerca los bordes hacia el centro.
vec2 curve(vec2 uv, float amount) {
    uv = uv * 2.0 - 1.0;
    vec2 off = abs(uv.yx) / vec2(5.0, 4.0);
    uv += uv * off * off * amount;
    return uv * 0.5 + 0.5;
}

vec3 sampleScene(Image tex, vec2 uv, float aberration) {
    // Desplazamiento radial: más aberración en los bordes, como una lente real.
    vec2 dir = uv - 0.5;
    vec2 px = aberration / uCanvasRes;
    float r = Texel(tex, uv + dir * px * 2.0).r;
    float g = Texel(tex, uv).g;
    float b = Texel(tex, uv - dir * px * 2.0).b;
    return vec3(r, g, b);
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 uv = mix(tc, curve(tc, 0.09), uCrt);

    // Fuera del tubo: negro.
    vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
    float mask = inside.x * inside.y;

    vec2 clamped = clamp(uv, 0.0, 1.0);
    vec3 c = sampleScene(tex, clamped, 0.6 * uCrt);

    // Bloom (se suma antes de las scanlines para que las atraviese el brillo).
    if (uBloom > 0.001) {
        vec3 bl = Texel(uBloomTex, clamped).rgb;
        c += bl * uBloom;
    }

    if (uCrt > 0.001) {
        // Scanlines: un ciclo cada dos filas de píxeles virtuales.
        float row = clamped.y * uCanvasRes.y;
        float scan = 0.88 + 0.12 * sin(row * PI);
        // Máscara de apertura vertical, muy suave.
        float col = clamped.x * uCanvasRes.x;
        float grille = 0.95 + 0.05 * sin(col * PI * 1.0);
        c *= mix(1.0, scan * grille, uCrt);

        // Viñeta.
        vec2 v = clamped * (1.0 - clamped.yx);
        float vig = pow(clamp(v.x * v.y * 34.0, 0.0, 1.0), 0.22);
        c *= mix(1.0, vig, 0.55 * uCrt);

        // Realce de contraste leve para compensar el oscurecimiento.
        c = clamp(c * 1.12, 0.0, 1.0);
    }

    return vec4(c * mask, 1.0) * color;
}
