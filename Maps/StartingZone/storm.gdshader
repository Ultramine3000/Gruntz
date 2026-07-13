shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// ---------------------------------------------------------------
// RADIOACTIVE STORM / ANOMALY SHADER (fixed center artifact)
//
// Previous version used atan(y, x) to compute a swirl angle. atan is
// undefined exactly at the center (radius 0) and has a hard -pi/pi seam,
// which produced a visible glitch/spike right in the middle of the
// circle. This version rotates the UV vector directly using sin/cos
// instead of computing an angle at all -- the rotation is smooth and
// well-defined everywhere, including exactly at the center, so there's
// no seam and no singularity.
// ---------------------------------------------------------------

uniform vec4 core_color : source_color = vec4(0.55, 0.95, 0.15, 1.0);
uniform vec4 edge_color : source_color = vec4(0.15, 0.55, 0.85, 1.0);
uniform float swirl_speed : hint_range(0.0, 5.0) = 1.2;
uniform float rotation_speed : hint_range(-3.0, 3.0) = 0.6;
uniform float swirl_twist : hint_range(0.0, 10.0) = 3.0; // how much the spiral winds up with radius
uniform float noise_scale : hint_range(1.0, 20.0) = 6.0;
uniform float turbulence : hint_range(0.0, 2.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.35;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.4;
uniform float radius_cutoff : hint_range(0.1, 1.0) = 0.95;
uniform float brightness : hint_range(0.5, 5.0) = 2.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 uv) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(uv);
		uv *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered) * 2.0; // 0 at center, 1 at mesh edge

	// differential rotation: twist amount grows with radius, plus a
	// constant spin over time. Rotating the VECTOR (not computing an
	// angle from it) means this is perfectly smooth at radius == 0,
	// where centered == (0,0) and rotation has no effect either way.
	float swirl_angle = radius * swirl_twist + TIME * rotation_speed;
	float s = sin(swirl_angle);
	float c = cos(swirl_angle);
	vec2 rotated = vec2(
		c * centered.x - s * centered.y,
		s * centered.x + c * centered.y
	);

	vec2 noise_uv = rotated * noise_scale;
	noise_uv += vec2(TIME * swirl_speed, -TIME * swirl_speed * 0.6);

	float turb = fbm(noise_uv) * turbulence;
	float turb2 = fbm(noise_uv * 1.7 + 10.0) * turbulence * 0.5;
	float pattern = turb + turb2;

	// pulsing brightness rippling outward from the core
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed - radius * 4.0);
	float glow = pattern * (1.0 + pulse * pulse_strength);

	// gentle taper so the very center reads as a soft bright core
	// rather than fully depending on noise, which can look thin/empty
	// right at radius 0 once the seam artifact is gone
	float core_boost = 1.0 - smoothstep(0.0, 0.25, radius);
	glow = mix(glow, max(glow, 0.6), core_boost);

	vec3 color = mix(core_color.rgb, edge_color.rgb, clamp(radius + pattern * 0.3, 0.0, 1.0));

	float edge_fade = 1.0 - smoothstep(radius_cutoff - edge_softness, radius_cutoff, radius);
	float alpha = clamp(glow * edge_fade, 0.0, 1.0);

	ALBEDO = color;
	EMISSION = color * glow * brightness;
	ALPHA = alpha;
}
