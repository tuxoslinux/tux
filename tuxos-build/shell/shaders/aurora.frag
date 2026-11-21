#version 440
// TuxOS live wallpaper "Aurora": soft bands of the accent colour drifting
// over a near-black sky.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec4 accent;
};
float wave(vec2 p, float t, float k) { return sin(p.x * k + t) * 0.5 + 0.5; }
void main() {
    vec2 uv = qt_TexCoord0;
    float t = time * 0.12;
    float y = uv.y + 0.08 * sin(uv.x * 3.0 + t) + 0.05 * sin(uv.x * 7.0 - t * 1.3);
    float band = exp(-pow((y - 0.42) * 6.0, 2.0)) * (0.55 + 0.45 * wave(uv, t * 2.0, 5.0));
    float band2 = exp(-pow((y - 0.55) * 9.0, 2.0)) * 0.5 * wave(uv + 0.3, -t * 1.6, 3.0);
    vec3 sky = mix(vec3(0.015, 0.018, 0.03), vec3(0.035, 0.045, 0.08), uv.y);
    vec3 col = sky + accent.rgb * (band * 0.38 + band2 * 0.22);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
