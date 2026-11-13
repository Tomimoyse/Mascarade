// Fondo animado: remolino psicodélico.
// Coordenadas polares con torsión dependiente del radio + ondas concéntricas.
// Se dibuja como un rectángulo que cubre todo el canvas interno.

uniform float uTime;
uniform vec2  uRes;       // tamaño del canvas interno
uniform vec3  uColA;      // color grave (sombras)
uniform vec3  uColB;      // color medio
uniform vec3  uColC;      // color de acento (brillos)
uniform float uIntensity; // 0..1, permite atenuarlo durante la partida
uniform float uLevels;    // niveles de posterizado (0 = desactivado)

// Ruido suave muy baratito, para romper la simetría perfecta.
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(41.7, 289.3))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    // OJO: love.graphics.rectangle no genera coordenadas de textura utiles
    // (todas valen lo mismo), asi que partimos de las coordenadas de pantalla,
    // que al dibujar sobre el canvas interno ya estan en pixeles de 640x360.
    vec2 ndc = sc / uRes;

    // Centrado y corregido de aspecto.
    vec2 uv = (ndc - 0.5) * vec2(uRes.x / uRes.y, 1.0) * 2.0;

    float t = uTime * 0.12;

    // Deformación del dominio: hace que el remolino "respire".
    uv += 0.18 * vec2(
        noise(uv * 0.8 + vec2(t, -t * 0.7)),
        noise(uv * 0.8 + vec2(-t * 0.6, t))
    ) - 0.09;

    // El centro del remolino deriva despacio para que no quede clavado.
    uv -= 0.22 * vec2(sin(uTime * 0.07), cos(uTime * 0.053));

    float r = length(uv);
    float a = atan(uv.y, uv.x);

    // Torsion: cuanto mas cerca del centro, mas gira. Esto es el remolino.
    // El multiplicador de 'swirl' DEBE ser entero: atan salta de -PI a PI y
    // solo un multiplo entero mantiene el seno continuo en esa costura.
    float swirl = a + uTime * 0.19 - 2.6 / (r + 0.55);

    float rings = sin(r * 3.4 - uTime * 0.38) * 1.5;
    float raw = 0.5 + 0.5 * sin(swirl * 3.0 + rings);

    // Separamos los brazos del fondo, pero sin saturar: queremos un fondo,
    // no un protagonista.
    float m = smoothstep(0.22, 0.78, raw);
    vec3 c = mix(uColA, uColB, m);

    // El acento es una linea fina en la cresta de cada brazo.
    float crest = smoothstep(0.93, 1.0, raw);
    c = mix(c, uColC, crest * 0.5);

    // Segundo remolino, mas lento y debil: da profundidad.
    float deep = 0.5 + 0.5 * sin(swirl * 1.0 - r * 1.6 + uTime * 0.11);
    c *= 0.82 + 0.26 * deep;

    // Vineta propia del fondo: oscurece los bordes para que la UI respire.
    c *= 0.38 + 0.62 * smoothstep(2.4, 0.3, r);

    // Posterizado opcional, para que el degradado tenga sabor retro.
    if (uLevels > 1.5) {
        c = floor(c * uLevels + 0.5) / uLevels;
    }

    c = mix(uColA * 0.5, c, uIntensity);

    return vec4(c, 1.0) * color;
}
