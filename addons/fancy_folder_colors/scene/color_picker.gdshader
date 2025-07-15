shader_type canvas_item;

uniform float shift_speed : hint_range(0.0, 5.0, 0.01) = 0.25;
uniform vec2 shift_direction = vec2(0.0,-1.0);

void fragment() {
    vec2 normalized_direction = normalize(shift_direction);
	vec2 offset = normalized_direction * TIME * shift_speed;
	vec2 shifted_uv = fract(UV + offset);
    COLOR = texture(TEXTURE, shifted_uv);
}