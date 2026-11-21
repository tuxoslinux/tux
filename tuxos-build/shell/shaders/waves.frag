#version 440
// TuxOS live wallpaper "Night waves": layered hills of light, very slow.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec4 accent;
};
void main() {
    vec2 uv = qt_TexCoord0;
    float t = time * 0.06;
    vec3 col = mix(vec3(0.02, 0.025, 0.04), vec3(0.0), uv.y);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float h = 0.55 + fi * 0.1 + 0.05 * sin(uv.x * (2.0 + fi) + t * (1.0 + fi * 0.4)) + 0.02 * sin(uv.x * 9.0 - t);
        float edge = smoothstep(h, h + 0.004, uv.y);
        float glow = exp(-abs(uv.y - h) * 60.0) * (0.35 - fi * 0.06);
        col = mix(col, vec3(0.01, 0.012, 0.02) * (1.0 - fi * 0.2), edge) + accent.rgb * glow;
    }
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
