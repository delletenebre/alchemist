shader_type canvas_item;
uniform vec4 family_tint : source_color = vec4(0.24, 0.52, 0.60, 1.0);
varying vec4 vertex_color;
void vertex() { vertex_color = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float blue_paper = smoothstep(0.025, 0.11, source.b - source.r) * smoothstep(0.02, 0.08, source.g - source.r);
	float lightness = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 colored_paper = clamp(family_tint.rgb * (lightness / 0.43), vec3(0.0), vec3(1.0));
	source.rgb = mix(source.rgb, colored_paper, blue_paper);
	// Trim the generated texture's outer backdrop at the die-cut card edge.
	vec2 q = abs((UV - vec2(0.5)) * vec2(240.0, 352.0)) - vec2(112.0, 163.0) + vec2(17.0);
	float edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 17.0;
	source.a *= 1.0 - smoothstep(-0.5, 0.5, edge);
	COLOR = source * vertex_color;
}
