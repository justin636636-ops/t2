shader_type spatial;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0, 0.79, 0.52, 1.0);
uniform float power = 0.8;
void fragment() {
    float radius = length((UV - 0.5) * 2.0);
    float rings = sin(radius * 43.0) * 0.045;
    float center = 1.0 - smoothstep(0.25, 1.0, radius);
    ALBEDO = tint.rgb * (0.32 + center * 0.25 + rings);
    EMISSION = tint.rgb * power * (0.75 + center * 0.30);
    ROUGHNESS = 0.3;
}
