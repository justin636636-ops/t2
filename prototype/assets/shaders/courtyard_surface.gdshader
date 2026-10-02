shader_type spatial;
uniform vec4 tint : source_color = vec4(0.09, 0.15, 0.16, 1.0);
varying vec3 world_position;

void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 paving = world_position.xz / vec2(0.9, 0.62);
    paving.x += mod(floor(paving.y), 2.0) * 0.5;
    vec2 cell = floor(paving);
    vec2 local = fract(paving);
    float border = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
    float aa = max(fwidth(border), 0.001);
    float stone = smoothstep(0.016, 0.027 + aa, border);
    float variation = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
    float cloud = sin(world_position.x * 1.2 + sin(world_position.z)) * sin(world_position.z * 1.7);
    ALBEDO = tint.rgb * mix(0.45, 0.86 + variation * 0.20 + cloud * 0.035, stone);
    ROUGHNESS = 0.88 + (variation - 0.5) * 0.08;
}
