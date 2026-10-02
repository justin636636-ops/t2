shader_type spatial;
uniform vec4 tint : source_color = vec4(0.4, 0.2, 0.12, 1.0);
uniform float finish_mode = 0.0;
uniform float metalness = 0.0;
uniform float base_roughness = 0.65;
uniform float fabric_clock = 0.0;
uniform float flutter_power = 0.0;
uniform float fabric_top = 6.66;
uniform float fabric_bottom = 1.74;
varying vec3 object_position;

void vertex() {
    object_position = VERTEX;
    if (flutter_power > 0.0) {
        vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        float span = max(0.1, fabric_top - fabric_bottom);
        float fall = clamp((fabric_top - world.y) / span, 0.0, 1.0);
        float phase = fabric_clock * 1.25 + world.x * 2.8 + world.y * 0.9;
        float wave = sin(phase);
        float dx = flutter_power * fall * fall * cos(phase) * 2.8;
        float dy = flutter_power * (fall * fall * cos(phase) * 0.9 - 2.0 * fall / span * wave);
        vec3 normal_world = MODEL_NORMAL_MATRIX * NORMAL;
        normal_world.xy -= normal_world.z * vec2(dx, dy);
        NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * normal_world);
        world.z += flutter_power * fall * fall * wave;
        VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
    }
}
float filtered_wave(float phase) {
    return sin(phase) * exp(-0.5 * pow(fwidth(phase), 2.0));
}
void fragment() {
    // Quiet woven canvas; broad pigment wash and filtered fine threads.
    float wash = sin(object_position.x * 2.3 + object_position.y * 1.1) * 0.016;
    float weave = filtered_wave(object_position.x * 260.0) * filtered_wave(object_position.y * 220.0) * 0.012;
    ALBEDO = tint.rgb * (0.96 + wash + weave);
    ROUGHNESS = clamp(base_roughness + wash * 0.2, 0.5, 1.0);
    METALLIC = metalness;
    SPECULAR = 0.16;
}
