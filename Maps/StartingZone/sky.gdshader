shader_type spatial;
render_mode unshaded, cull_front;

// ---------------------------------------------------------------
// OPPRESSIVE OVERCAST SKY
// No sun disc, no day/night cycle, no stars. The whole point is a flat,
// heavy, moving cloud ceiling that never resolves into blue sky -- the
// zone doesn't get nice weather. Light comes through as a diffuse bleed
// in one direction, never a crisp source.
// ---------------------------------------------------------------

// Base tones -- kept close together in value on purpose. A big spread
// between horizon and zenith reads as "clear sky gradient." A narrow,
// desaturated spread reads as "solid ceiling of cloud."
uniform vec3 zenith_color : source_color = vec3(0.16, 0.17, 0.155);
uniform vec3 horizon_color : source_color = vec3(0.32, 0.33, 0.30);
uniform vec3 ground_color : source_color = vec3(0.10, 0.10, 0.095);

// Cloud layer
uniform float cloud_scale : hint_range(0.5, 8.0) = 2.2;
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.025;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float cloud_density : hint_range(0.0, 1.0) = 0.6;   // higher = darker, heavier patches dominate
uniform float cloud_contrast : hint_range(0.5, 3.0) = 1.4;   // higher = more defined dark/light patches
uniform vec3 cloud_dark_color : source_color = vec3(0.10, 0.105, 0.095);
uniform vec3 cloud_light_color : source_color = vec3(0.42, 0.42, 0.39);

// Diffuse light bleed -- a soft brightening toward one direction,
// standing in for a sun that never actually breaks through
uniform vec3 bleed_direction = vec3(0.3, 0.35, -0.4);
uniform vec3 bleed_color : source_color = vec3(0.55, 0.52, 0.46);
uniform float bleed_strength : hint_range(0.0, 1.0) = 0.35;
uniform float bleed_falloff : hint_range(1.0, 16.0) = 4.0;

// Low haze that thickens near the horizon
uniform float haze_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec3 haze_color : source_color = vec3(0.30, 0.30, 0.28);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 uv) {
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
	for (int i = 0; i < 5; i++) {
		v += amp * noise2(uv);
		uv *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	VERTEX = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += CAMERA_POSITION_WORLD;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 view_dir = -normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float height = view_dir.y;

	// base sky gradient -- narrow value range, desaturated, never blue
	vec3 sky_color;
	if (height > 0.0) {
		sky_color = mix(horizon_color, zenith_color, pow(height, 0.6));
	} else {
		sky_color = mix(horizon_color, ground_color, pow(-height, 0.8));
	}

	// cloud ceiling: sample fbm using the view direction projected onto
	// a dome, drifting slowly in one wind direction. Only rendered above
	// the horizon -- below it, the base gradient (ground fade) takes over.
	if (height > -0.05) {
		vec2 dome_uv = view_dir.xz / (max(height, 0.05) + 0.35);
		dome_uv = dome_uv * cloud_scale + wind_direction * TIME * cloud_speed;

		float cloud = fbm(dome_uv);
		cloud = clamp((cloud - (1.0 - cloud_density)) * cloud_contrast + 0.5, 0.0, 1.0);

		vec3 cloud_col = mix(cloud_dark_color, cloud_light_color, cloud);
		float cloud_blend = smoothstep(-0.05, 0.15, height); // fade cloud layer in just above horizon
		sky_color = mix(sky_color, cloud_col, cloud_blend);
	}

	// diffuse light bleed -- soft, wide, no hard edge, no visible disc
	vec3 bleed_dir_n = normalize(bleed_direction);
	float bleed_amount = pow(clamp(dot(view_dir, bleed_dir_n), 0.0, 1.0), bleed_falloff);
	sky_color += bleed_color * bleed_amount * bleed_strength;

	// low haze thickening toward the horizon, on top of everything else
	float haze_amount = (1.0 - smoothstep(0.0, 0.35, abs(height))) * haze_strength;
	sky_color = mix(sky_color, haze_color, haze_amount);

	ALBEDO = sky_color;
}