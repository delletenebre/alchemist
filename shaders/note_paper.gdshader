shader_type canvas_item;
render_mode unshaded;
varying vec4 paper_tint;
void vertex() {
	paper_tint = COLOR;
}
void fragment() {
	// The mesh supplies the torn silhouette; use the parchment's RGB, not the sprite matte.
	COLOR = vec4(texture(TEXTURE, UV).rgb * paper_tint.rgb, paper_tint.a);
}
