shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float blurRadius : hint_range(0.0, 64.0) = 20.0;
uniform float borderPx : hint_range(0.0, 8.0) = 1.5;
uniform float bgAlpha : hint_range(0.0, 1.0) = 0.72;
uniform vec4 tint : source_color = vec4(0.04, 0.05, 0.08, 0.9);
uniform vec4 borderColor : source_color = vec4(1.0, 1.0, 1.0, 0.14);
uniform vec4 accentColor : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform float cornerRadius : hint_range(0.0, 48.0) = 14.0;
uniform float accentWidth : hint_range(0.0, 12.0) = 0.0;
uniform float topHighlight : hint_range(0.0, 0.3) = 0.06;
uniform vec2 panelSize = vec2(800.0, 400.0);

float rounded_box_sdf(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 size = max(panelSize, vec2(1.0));
	vec2 half_size = size * 0.5;
	vec2 px = UV * size;
	vec2 p = px - half_size;
	float d = rounded_box_sdf(p, half_size, cornerRadius);

	float inside = 1.0 - smoothstep(-1.0, 1.0, d);

	vec2 one_over_size = 1.0 / size;
	vec2 off = vec2(blurRadius) * one_over_size;
	vec3 sum = vec3(0.0);
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-off.x, -off.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, -off.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(off.x, -off.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-off.x, 0.0)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, 0.0)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(off.x, 0.0)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-off.x, off.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, off.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(off.x, off.y)).rgb;

	vec2 off2 = off * 2.2;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-off2.x, -off2.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(off2.x, -off2.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-off2.x, off2.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(off2.x, off2.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-off2.x, 0.0)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(off2.x, 0.0)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, -off2.y)).rgb;
	sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, off2.y)).rgb;
	sum /= 17.0;

	vec3 col = mix(sum, tint.rgb, clamp(tint.a, 0.0, 1.0));

	float edge_grad = smoothstep(-cornerRadius, 0.0, p.y) * topHighlight;
	col += vec3(edge_grad);

	float border = 1.0 - smoothstep(0.0, borderPx, d);
	vec3 border_col = borderColor.rgb;
	float accent_mix = 0.0;
	if (accentWidth > 0.5) {
		float left_band = 1.0 - smoothstep(accentWidth - 1.0, accentWidth + 1.0, px.x);
		float v_ok = smoothstep(2.0, 6.0, px.y) * (1.0 - smoothstep(size.y - 6.0, size.y - 2.0, px.y));
		float accent = left_band * v_ok;
		col = mix(col, accentColor.rgb, accent * 0.95);
		border_col = mix(border_col, accentColor.rgb, left_band);
		accent_mix = left_band * v_ok;
	}
	col = mix(col, border_col, border * borderColor.a);

	float boost = max(borderColor.a, accent_mix * 0.9);
	float alpha = mix(bgAlpha, 1.0, border * boost) * inside;
	COLOR = vec4(col, alpha);
}
