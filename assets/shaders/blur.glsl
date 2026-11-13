// Desenfoque gaussiano separable (9 muestras).
// Se ejecuta dos veces: una horizontal y otra vertical.

uniform vec2 uDir;    // (1/w, 0) o (0, 1/h)
uniform float uScale; // separación entre muestras

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 d = uDir * uScale;
    vec3 acc = Texel(tex, tc).rgb * 0.2270270270;
    acc += Texel(tex, tc + d * 1.3846153846).rgb * 0.3162162162;
    acc += Texel(tex, tc - d * 1.3846153846).rgb * 0.3162162162;
    acc += Texel(tex, tc + d * 3.2307692308).rgb * 0.0702702703;
    acc += Texel(tex, tc - d * 3.2307692308).rgb * 0.0702702703;
    return vec4(acc, 1.0);
}
