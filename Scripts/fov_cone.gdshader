shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_back;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 fog_color = vec3(0.003, 0.004, 0.02);
uniform float fog_opacity = 1.0;
uniform vec3 cone_origin = vec3(0.0, 0.0, 0.0);
uniform vec3 facing_dir = vec3(0.0, 0.0, -1.0);
uniform float cone_angle = 1.22173;
uniform float radius = 14.0;
uniform bool flat_cone = true;

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	float alpha = fog_opacity;
	if (depth < 1.0) {
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
		vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		vec3 view_pos = vp.xyz / vp.w;
		vec4 wp = INV_VIEW_MATRIX * vec4(view_pos, 1.0);
		vec3 delta = wp.xyz - cone_origin;
		if (flat_cone) {
			delta.y = 0.0;
		}
		float dist = length(delta);
		vec3 dir = dist > 0.0001 ? delta / dist : vec3(0.0, 0.0, 0.0);
		float cos_half = cos(cone_angle);
		bool inside = dist <= radius && dot(dir, normalize(facing_dir)) >= cos_half;
		if (inside) {
			alpha = 0.0;
		}
	}
	ALBEDO = fog_color;
	ALPHA = alpha;
}