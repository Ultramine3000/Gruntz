shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;

uniform vec4 color_rock_a : source_color = vec4(0.12, 0.1, 0.09, 1.0);
uniform vec4 color_rock_b : source_color = vec4(0.05, 0.04, 0.04, 1.0);
uniform vec4 color_glow : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform vec4 color_glow_hot : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float cell_scale : hint_range(1.0, 20.0) = 6.0;
uniform float crack_width : hint_range(0.0, 0.2) = 0.04;
uniform float crack_pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float heat_shimmer : hint_range(0.0, 0.05) = 0.01;
uniform float glow_flicker_speed : hint_range(0.0, 10.0) = 3.0;

uniform float parallax_depth : hint_range(0.0, 0.3) = 0.08;
uniform int parallax_steps : hint_range(4, 32) = 14;

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

vec3 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float min_dist = 8.0;
	vec2 min_point;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = vec2(float(i), float(j));
			vec2 diff = cell + hash22(n + cell) * 0.5 + 0.5 - f;
			float d = length(diff);
			if (d < min_dist) {
				min_dist = d;
				min_point = diff;
			}
		}
	}
	float edge_dist = 8.0;
	vec2 min_cell_id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = vec2(float(i), float(j));
			vec2 diff = cell + hash22(n + cell) * 0.5 + 0.5 - f;
			vec2 to_edge = diff - min_point;
			if (dot(to_edge, to_edge) > 0.0001) {
				float d = dot(0.5 * (min_point + diff), normalize(to_edge));
				if (d < edge_dist) {
					edge_dist = d;
					min_cell_id = n + cell;
				}
			}
		}
	}
	return vec3(edge_dist, min_cell_id);
}

float get_height(vec2 uv) {
	vec3 v = voronoi(uv * cell_scale);
	float crack_mask = smoothstep(crack_width, 0.0, v.x);
	return 1.0 - crack_mask;
}

varying vec3 world_pos_v;

void vertex() {
	world_pos_v = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV;

	// --- Manually derive a tangent basis via screen-space derivatives ---
	// Works regardless of whether the mesh supplies tangent data (QuadMesh often doesn't).
	vec3 dp_dx = dFdx(world_pos_v);
	vec3 dp_dy = dFdy(world_pos_v);
	vec2 duv_dx = dFdx(uv);
	vec2 duv_dy = dFdy(uv);

	vec3 n = normalize(NORMAL);
	// Solve for tangent that matches how UV changes across the surface
	vec3 tangent = normalize(dp_dx * duv_dy.y - dp_dy * duv_dx.y);
	tangent = normalize(tangent - n * dot(n, tangent)); // orthogonalize
	vec3 bitangent = cross(n, tangent);

	vec3 view_dir_world = normalize(CAMERA_POSITION_WORLD - world_pos_v);
	vec3 view_dir_tangent = normalize(vec3(
		dot(view_dir_world, tangent),
		dot(view_dir_world, bitangent),
		dot(view_dir_world, n)
	));

	// --- Parallax occlusion mapping ---
	vec2 parallax_dir = view_dir_tangent.xy / max(abs(view_dir_tangent.z), 0.2);
	float layer_depth = 1.0 / float(parallax_steps);
	vec2 delta_uv = parallax_dir * parallax_depth * layer_depth;

	vec2 cur_uv = uv;
	float cur_layer_depth = 0.0;
	float cur_height = get_height(cur_uv);

	for (int i = 0; i < 32; i++) {
		if (i >= parallax_steps) break;
		if (cur_height > 1.0 - cur_layer_depth) break;
		cur_uv -= delta_uv;
		cur_layer_depth += layer_depth;
		cur_height = get_height(cur_uv);
	}

	vec2 prev_uv = cur_uv + delta_uv;
	float after = cur_height - (1.0 - cur_layer_depth);
	float before = get_height(prev_uv) - (1.0 - (cur_layer_depth - layer_depth));
	float weight = after / max(after - before, 0.0001);
	vec2 final_uv = mix(cur_uv, prev_uv, weight);

	final_uv.x += sin(uv.y * 30.0 + TIME * 2.0) * heat_shimmer;
	final_uv.y += cos(uv.x * 30.0 + TIME * 1.7) * heat_shimmer;

	vec3 v = voronoi(final_uv * cell_scale);
	float edge_dist = v.x;
	float cell_rand = hash22(v.yz).x * 0.5 + 0.5;

	vec3 rock_col = mix(color_rock_a.rgb, color_rock_b.rgb, cell_rand);
	rock_col *= 0.85 + 0.3 * cell_rand;

	float pulse = 0.6 + 0.4 * sin(TIME * crack_pulse_speed + cell_rand * 10.0);
	float crack_mask = smoothstep(crack_width, 0.0, edge_dist);

	vec3 glow_col = mix(color_glow.rgb, color_glow_hot.rgb, pulse * 0.5);
	float flicker = 0.7 + 0.3 * sin(TIME * glow_flicker_speed + cell_rand * 20.0);

	vec3 col = mix(rock_col, glow_col * flicker, crack_mask);

	float inner = smoothstep(crack_width * 0.4, 0.0, edge_dist);
	col = mix(col, color_glow_hot.rgb, inner * flicker * 0.6);

	col *= mix(1.0, 0.55, cur_layer_depth);

	float rim = distance(uv, vec2(0.5));
	col *= mix(1.0, 0.7, smoothstep(0.4, 0.7, rim));

	ALBEDO = clamp(col, 0.0, 1.0);
	ALPHA = 1.0;
}