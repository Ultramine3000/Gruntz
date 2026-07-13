shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_always;

uniform vec4 fog_color_near : source_color = vec4(0.85, 0.55, 0.9, 1.0);  // pinkish near
uniform vec4 fog_color_far : source_color = vec4(0.4, 0.6, 0.95, 1.0);   // blue-ish far/horizon
uniform float noise_scale = 2.5;
uniform float drift_speed = 0.05;
uniform float band_count = 6.0;      // number of horizontal fog "layers"
uniform float band_softness = 0.4;
uniform float density = 0.6;
uniform float fade_distance = 1.0;   // 0=near edge, 1=far edge of plane, controls color/alpha falloff
uniform sampler2D noise_tex : hint_default_white;

varying float v_depth; // 0 near edge of plane, 1 far edge (assumes UV.y along depth)

void vertex() {
	v_depth = UV.y;
}

void fragment() {
	vec2 uv = UV * noise_scale;
	uv.x += TIME * drift_speed;
	uv.y -= TIME * drift_speed * 0.5;

	float n1 = texture(noise_tex, uv).r;
	float n2 = texture(noise_tex, uv * 1.8 + vec2(0.2, TIME * drift_speed * 0.3)).r;
	float noise = mix(n1, n2, 0.5);

	// horizontal banding — classic retro fog "layers" stacked
	float band = sin(v_depth * band_count * 3.14159 - TIME * 0.2) * 0.5 + 0.5;
	band = smoothstep(0.5 - band_softness, 0.5 + band_softness, band);

	float alpha = mix(noise, band, 0.5) * density;
	alpha *= smoothstep(0.0, fade_distance, 1.0 - v_depth) + 0.3; // fade out toward far edge

	vec3 color = mix(fog_color_near.rgb, fog_color_far.rgb, v_depth);

	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}