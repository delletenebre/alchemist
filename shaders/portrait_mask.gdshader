shader_type canvas_item;
varying vec4 vertex_color;
void vertex() { vertex_color = COLOR; }
void fragment() {
 vec4 pixel = texture(TEXTURE, UV);
 float edge = length(UV - vec2(0.5));
 pixel.a *= 1.0 - smoothstep(0.485, 0.5, edge);
 COLOR = pixel * vertex_color;
}
