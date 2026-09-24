shader_type canvas_item;
render_mode unshaded;

varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

uniform bool heat_spirit = true;
uniform float clock = 0.0;
uniform float liveliness = 1.0;

// Each paper cluster bends about its own attachment. The face, belly and feet stay pinned.
float patch_weight(vec2 uv, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.25, 1.0, length((uv - center) / radius));
}

vec2 bend(vec2 uv, vec2 pivot, vec2 center, vec2 radius, float angle) {
	float a = angle * patch_weight(uv, center, radius);
	vec2 p = (uv - pivot) * vec2(1.0, 1.5);
	vec2 rotated = vec2(cos(a) * p.x - sin(a) * p.y, sin(a) * p.x + cos(a) * p.y);
	return (rotated - p) / vec2(1.0, 1.5);
}

void fragment() {
	vec2 drift = vec2(0.0);
	float t = clock;
	float face_lock;
	float belly_lock;
	if (heat_spirit) {
		float flicker = sin(t * 2.6) * 0.030 + sin(t * 6.1 + 0.7) * 0.009;
		drift += bend(UV, vec2(0.60, 0.35), vec2(0.55, 0.14), vec2(0.27, 0.27), flicker);
		drift += bend(UV, vec2(0.40, 0.37), vec2(0.19, 0.27), vec2(0.21, 0.18), sin(t * 2.2 + 1.1) * 0.045);
		drift += bend(UV, vec2(0.29, 0.51), vec2(0.14, 0.43), vec2(0.20, 0.16), sin(t * 2.8 + 2.0) * 0.036);
		drift += bend(UV, vec2(0.76, 0.58), vec2(0.88, 0.49), vec2(0.16, 0.20), sin(t * 2.4 + 3.4) * 0.050);
		drift += bend(UV, vec2(0.35, 0.69), vec2(0.17, 0.70), vec2(0.20, 0.20), sin(t * 2.0 + 4.2) * 0.023);
		face_lock = patch_weight(UV, vec2(0.58, 0.43), vec2(0.28, 0.16));
		belly_lock = patch_weight(UV, vec2(0.58, 0.70), vec2(0.40, 0.27));
	} else {
		drift += bend(UV, vec2(0.47, 0.38), vec2(0.48, 0.14), vec2(0.40, 0.27), sin(t * 0.92) * 0.052);
		drift += bend(UV, vec2(0.62, 0.34), vec2(0.75, 0.27), vec2(0.24, 0.21), sin(t * 1.08 + 1.7) * 0.047);
		drift += bend(UV, vec2(0.28, 0.60), vec2(0.11, 0.62), vec2(0.24, 0.25), sin(t * 0.88 + 2.8) * 0.053);
		drift += bend(UV, vec2(0.69, 0.60), vec2(0.88, 0.65), vec2(0.26, 0.30), sin(t * 0.98 + 4.1) * 0.055);
		drift += bend(UV, vec2(0.32, 0.31), vec2(0.17, 0.32), vec2(0.23, 0.18), sin(t * 1.15 + 0.8) * 0.026);
		face_lock = patch_weight(UV, vec2(0.47, 0.49), vec2(0.25, 0.15));
		belly_lock = patch_weight(UV, vec2(0.46, 0.75), vec2(0.38, 0.24));
	}
	float pinned = max(face_lock, belly_lock);
	float free_edge = (1.0 - smoothstep(0.80, 0.88, UV.y)) * (1.0 - smoothstep(0.35, 0.70, pinned));
	vec2 sample_uv = UV + drift * liveliness * free_edge;
	COLOR = texture(TEXTURE, sample_uv) * sprite_tint;
}
