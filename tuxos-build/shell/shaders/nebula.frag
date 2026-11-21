#version 440
// TuxOS live wallpaper "Nebula": slow, deep clouds tinted with the accent.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec4 accent;
};
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.02; a *= 0.5; } return v; }
void main() {
    vec2 uv = qt_TexCoord0 * vec2(resolution.x / resolution.y, 1.0) * 2.2;
    float t = time * 0.03;
    float n = fbm(uv + vec2(t, -t * 0.6) + fbm(uv * 0.7 - t));
    vec3 col = vec3(0.012, 0.014, 0.024) + accent.rgb * pow(n, 3.0) * 0.55 + vec3(0.6, 0.7, 1.0) * pow(n, 8.0) * 0.25;
    float star = step(0.9985, hash(floor(qt_TexCoord0 * resolution))) * 0.6;
    fragColor = vec4(col + star, 1.0) * qt_Opacity;
}
