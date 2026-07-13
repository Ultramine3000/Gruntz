shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(0.3, 1.0, 0.2, 1.0);
uniform vec4 core_color : source_color = vec4(0.8, 1.0, 0.7, 1.0);
uniform float speed : hint_range(0.0, 10.0) = 4.0;
uniform float jaggedness : hint_range(0.0, 1.0) = 0.6;
uniform float bolt_width : hint_range(0.001, 0.2) = 0.02;
uniform float glow_width : hint_range(0.001, 0.5) = 0.08;
uniform int band_steps : hint_range(1, 8) = 3;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

float noise1d(float x) {
    float i = floor(x);
    float f = fract(x);
    float a = hash(i);
    float b = hash(i + 1.0);
    return mix(a, b, smoothstep(0.0, 1.0, f));
}

float boltOffset(float x, float t) {
    float snapT = floor(t * speed) / max(speed, 0.001);
    float n1 = noise1d(x * 6.0 + snapT * 13.0) - 0.5;
    float n2 = noise1d(x * 17.0 + snapT * 27.0) - 0.5;
    return (n1 * 0.7 + n2 * 0.3) * jaggedness;
}

varying vec2 uv_v;

void vertex() {
    uv_v = UV;
}

void fragment() {
    vec2 uv = uv_v;
    float t = TIME;

    float offset = boltOffset(uv.x, t);
    float boltY = 0.5 + offset;
    float d = abs(uv.y - boltY);

    float glow = 1.0 - smoothstep(0.0, glow_width, d);
    glow = ceil(glow * float(band_steps)) / float(band_steps);

    float core = 1.0 - smoothstep(0.0, bolt_width, d);
    core = step(0.5, core);

    vec3 col = mix(glow_color.rgb * glow, core_color.rgb, core);
    float alpha = clamp(glow + core, 0.0, 1.0);

    float flicker = step(0.94, hash(floor(t * speed * 2.0)));
    col += flicker * core_color.rgb * 0.5;

    ALBEDO = col;
    EMISSION = col * 2.0;
    ALPHA = alpha;
}