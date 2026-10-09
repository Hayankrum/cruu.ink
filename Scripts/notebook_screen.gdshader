shader_type spatial;
render_mode unshaded, cull_back;

// Tela do notebook. As UVs originais do modelo (Notebook.glb) sao invalidas,
// entao a UV e reconstruida por projecao planar dos vertices locais.
// Com `load_t < 0` a tela fica "desligada" com um standby sutil (respiracao +
// cursor piscando). Com `load_t >= 0` desenha um progresso de carregamento
// so na tela preta: barra animada, contador em fonte 3x5 e 3 bolinhas.
// `ui_texture` fica reservado para uma futura interface 2D real de um SubViewport.
uniform sampler2D ui_texture : source_color, filter_linear;
uniform bool ui_enabled = false;
uniform vec3 screen_origin : source_color = vec3(-0.0177349597, 0.0293890703, 0.1687812954);
uniform vec3 screen_axis_u : source_color = vec3(-0.228530034, 0.0, 0.0);
uniform vec3 screen_axis_v : source_color = vec3(0.0, 0.116231231, 0.0519927);
uniform float load_t = -1.0;
uniform float load_duration = 2.4;
uniform float load_pause = 1.1;

varying vec3 lpos;

const vec3 BLACK = vec3(0.0, 0.004, 0.012);
const vec3 CYAN = vec3(0.42, 0.72, 1.0);

float rrect(vec2 p, vec2 c, vec2 s, float r) {
	vec2 d = abs(p - c) - (s * 0.5 - vec2(r));
	return length(max(d, vec2(0.0))) - r;
}

int font_row(int d, int r) {
	if (d == 0) return r == 0 ? 7 : r == 4 ? 7 : 5;
	if (d == 1) return r == 0 ? 2 : r == 4 ? 7 : 6;
	if (d == 2) return r == 0 ? 7 : r == 1 ? 1 : r == 2 ? 7 : r == 3 ? 4 : 7;
	if (d == 3) return r == 0 ? 7 : r == 1 ? 1 : r == 2 ? 3 : r == 3 ? 1 : 7;
	if (d == 4) return r == 0 ? 5 : r == 1 ? 5 : r == 2 ? 7 : r == 3 ? 1 : 1;
	if (d == 5) return r == 0 ? 7 : r == 1 ? 4 : r == 2 ? 7 : r == 3 ? 1 : 7;
	if (d == 6) return r == 0 ? 7 : r == 1 ? 4 : r == 2 ? 7 : r == 3 ? 5 : 7;
	if (d == 7) return r == 0 ? 7 : r == 1 ? 1 : r == 2 ? 2 : r == 3 ? 2 : 2;
	if (d == 8) return r == 0 ? 7 : r == 1 ? 5 : r == 2 ? 7 : r == 3 ? 5 : 7;
	if (d == 9) return r == 0 ? 7 : r == 1 ? 5 : r == 2 ? 7 : r == 3 ? 1 : 7;
	return 0;
}

float digit_mask(vec2 uv, vec2 top_left, int d, float sq) {
	float v = 0.0;
	for (int r = 0; r < 5; r++) {
		int row = font_row(d, r);
		for (int c = 0; c < 3; c++) {
			int bit = (row >> (2 - c)) & 1;
			float on = float(bit);
			vec2 cell_c = top_left + vec2(float(c) + 0.5, float(r) + 0.5) * sq;
			vec2 cell_s = vec2(sq * 0.9);
			float d2 = rrect(uv, cell_c, cell_s, sq * 0.18);
			v = max(v, on * step(d2, 0.0));
		}
	}
	return v;
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec3 rel = lpos - screen_origin;
	float u = dot(rel, screen_axis_u) / dot(screen_axis_u, screen_axis_u);
	float v = dot(rel, screen_axis_v) / dot(screen_axis_v, screen_axis_v);
	vec2 uv = clamp(vec2(u, 1.0 - v), 0.0, 1.0);

	vec3 col = BLACK;

	if (load_t >= 0.0) {
		float f = clamp(load_t / load_duration, 0.0, 1.0);
		float e = 1.0 - pow(1.0 - f, 2.4);
		bool hold = load_t >= load_duration;

		// trilho da barra
		vec2 c_track = vec2(0.5, 0.56);
		vec2 s_track = vec2(0.5, 0.06);
		float d_trk = rrect(uv, c_track, s_track, 0.028);
		float in_trk = step(d_trk, 0.0);
		col = mix(col, vec3(0.045, 0.065, 0.1) * (0.6 + 0.4 * min(e + 0.06, 1.0)), in_trk);

		// preenchimento com shimmer na ponta
		float bw = 0.007;
		vec2 s0 = s_track - vec2(bw * 2.0);
		float fw = (s0.x - 0.012) * e;
		vec2 c_fill = vec2(c_track.x - (s0.x * 0.5 - 0.006) + fw * 0.5, c_track.y);
		vec2 s_fill = vec2(max(fw, 0.006), s0.y * 0.9);
		float d_fill = rrect(uv, c_fill, s_fill, 0.014);
		float in_fill = step(d_fill, 0.0);
		col = mix(col, CYAN, in_fill);

		float sh = fract((uv.x - (c_fill.x - s_fill.x * 0.5)) / max(s_fill.x, 0.001));
		col += CYAN * (exp(-max(d_fill, 0.0) * 24.0) * 0.55) * in_trk;
		col = clamp(col + CYAN * (smoothstep(0.92, 1.0, sh) * in_fill * 0.5), 0.0, 1.0);

		// contador de percentual acima da barra
		int val = int(floor(e * 100.0 + 0.5));
		int d100 = val / 100;
		int d10 = (val / 10) % 10;
		int d1 = val % 10;
		float sq = 0.034;
		float gap = sq * 0.35;
		float digit_w = sq * 3.0 + gap;
		float x_left = 0.5 - (digit_w * 1.5 - gap * 0.5);
		float y_top = c_track.y - s_track.y - 0.035 - sq * 5.0;
		vec3 txt_c = vec3(0.72, 0.8, 0.95);
		float m100 = digit_mask(uv, vec2(x_left, y_top), d100, sq) * step(99.5, float(val));
		float m10 = digit_mask(uv, vec2(x_left + digit_w, y_top), d10, sq) * step(9.5, float(val));
		float m1 = digit_mask(uv, vec2(x_left + digit_w * 2.0, y_top), d1, sq);
		col = mix(col, txt_c, m100 + m10 + m1);

		// 3 bolinhas pulsantes abaixo da barra
		for (int i = 0; i < 3; i++) {
			float ph = fract(load_t * 0.9 + float(i) * 0.34);
			float a = smoothstep(0.0, 0.3, ph) * (1.0 - smoothstep(0.75, 1.0, ph));
			float dd = length(uv - vec2(0.5 + (float(i) - 1.0) * 0.075, 0.72));
			col = mix(col, vec3(0.5, 0.72, 0.95), step(dd, 0.014) * (0.3 + 0.7 * a));
		}
	} else if (ui_enabled) {
		// conteudo (ui_texture) na tela: fundo estavel, sem cursor/animacao
		col = BLACK + vec3(0.012, 0.02, 0.034);
	} else {
		// standby: respiracao suave + cursor piscando + linha de sistema
		float breath = 0.5 + 0.5 * sin(TIME * 1.4);
		col = BLACK + vec3(0.016, 0.026, 0.042) * (0.25 + 0.75 * breath);

		float blink = step(0.5, fract(TIME * 2.2));
		vec2 cs = vec2(0.09, 0.026);
		float dcur = rrect(uv, vec2(0.08 + cs.x * 0.5, 0.86), cs, 0.008);
		col = mix(col, CYAN * 0.7, step(dcur, 0.0) * blink);

		float dline = rrect(uv, vec2(0.5, 0.045), vec2(0.5, 0.004), 0.002);
		col = mix(col, vec3(0.1, 0.18, 0.32), step(dline, 0.0) * (0.4 + 0.6 * breath));
	}

	if (ui_enabled) {
		vec4 tex = texture(ui_texture, uv);
		col = mix(col, tex.rgb, tex.a);
	}

	ALBEDO = col;
}