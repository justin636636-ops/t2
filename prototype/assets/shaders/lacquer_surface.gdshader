shader_type spatial;
uniform vec4 tint : source_color = vec4(0.7, 0.3, 0.2, 1.0);
uniform float base_roughness = 0.4;
uniform float clear_coat = 0.32;
varying vec3 object_position;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float noise(vec3 p) {
    vec3 a = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(a), hash(a + vec3(1,0,0)), f.x), mix(hash(a + vec3(0,1,0)), hash(a + vec3(1,1,0)), f.x), f.y), mix(mix(hash(a + vec3(0,0,1)), hash(a + vec3(1,0,1)), f.x), mix(hash(a + vec3(0,1,1)), hash(a + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { object_position = VERTEX; }
void fragment() {
    float pigment = noise(object_position * 14.0);
    float broad = noise(object_position * 3.7);
    ALBEDO = tint.rgb * (0.90 + broad * 0.14 + pigment * 0.035);
    ROUGHNESS = clamp(base_roughness + (pigment - 0.5) * 0.10, 0.2, 0.7);
    CLEARCOAT = clear_coat;
    CLEARCOAT_ROUGHNESS = 0.38;
}
