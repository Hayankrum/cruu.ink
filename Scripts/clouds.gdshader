shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 0.92);
uniform vec4 shadow_color : source_color = vec4(0.72, 0.78, 0.9, 0.85);
uniform float noise_scale = 0.0045;
uniform float coverage = 0.42;
uniform float softness = 0.18;
uniform float scroll_speed = 0.008;
uniform float altitude_fade = 30.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * noise_scale;
	uv += vec2(TIME * scroll_speed, TIME * scroll_speed * 0.35);
	float base = fbm(uv);
	float detail = fbm(uv * 2.7 + vec2(4.2, 1.3));
	float n = base * 0.72 + detail * 0.28;
	float alpha = smoothstep(coverage, coverage + softness, n);

	float edge = length(world_pos.xz) / (altitude_fade * 8.0);
	alpha *= 1.0 - smoothstep(0.55, 1.0, edge);

	float shade = smoothstep(coverage, coverage + softness * 2.5, n);
	vec3 col = mix(shadow_color.rgb, cloud_color.rgb, shade);
	ALBEDO = col;
	ALPHA = alpha * cloud_color.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
