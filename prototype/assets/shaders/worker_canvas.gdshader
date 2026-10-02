shader_type spatial;
uniform vec4 tint : source_color = vec4(0.7, 0.65, 0.5, 1.0);
uniform float base_roughness = 0.84;
varying vec3 cloth_position;
void vertex() { cloth_position = VERTEX; }
float filtered_wave(float phase) {
    return sin(phase) * exp(-0.5 * pow(fwidth(phase), 2.0));
}
void fragment() {
    float weave = filtered_wave(cloth_position.x * 410.0) * filtered_wave(cloth_position.y * 350.0);
    float wash = sin(cloth_position.x * 9.0 + cloth_position.y * 5.0) * 0.012;
    ALBEDO = tint.rgb * (0.98 + wash + weave * 0.016);
    ROUGHNESS = clamp(base_roughness + wash, 0.65, 1.0);
    SPECULAR = 0.16;
}
