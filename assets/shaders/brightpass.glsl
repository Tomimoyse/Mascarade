// Extrae sólo las zonas brillantes de la escena, para alimentar el bloom.

uniform float uThreshold; // luminancia por debajo de la cual no hay bloom
uniform float uKnee;      // suavizado del corte

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec3 c = Texel(tex, tc).rgb;
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    float w = smoothstep(uThreshold, uThreshold + uKnee, lum);
    return vec4(c * w, 1.0);
}
