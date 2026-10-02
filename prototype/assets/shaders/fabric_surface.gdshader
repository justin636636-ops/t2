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

float hash(vec3 p) { return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453); }
float noise(vec3 p) {
    vec3 a=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(a),hash(a+vec3(1,0,0)),f.x),mix(hash(a+vec3(0,1,0)),hash(a+vec3(1,1,0)),f.x),f.y),mix(mix(hash(a+vec3(0,0,1)),hash(a+vec3(1,0,1)),f.x),mix(hash(a+vec3(0,1,1)),hash(a+vec3(1,1,1)),f.x),f.y),f.z);
}
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
    float detail=noise(object_position*24.0);
    float variation=detail*0.10;
    if (finish_mode < 0.5) {
        float warp=noise(object_position*vec3(7.0,2.0,0.5));
        float grain=filtered_wave(object_position.x*110.0+warp*7.0+object_position.z*1.2);
        float fine=filtered_wave(object_position.x*280.0+warp*15.0);
        variation=grain*0.095+fine*0.023+warp*0.07;
    } else if (finish_mode < 1.5) {
        float weave=filtered_wave(object_position.x*290.0)*filtered_wave(object_position.y*240.0);
        variation=weave*0.025+detail*0.09;
        RIM=0.30;
        RIM_TINT=0.88;
    } else {
        float wear=smoothstep(0.68,0.90,noise(object_position*17.0));
        variation=detail*0.05-wear*0.09;
    }
    ALBEDO=tint.rgb*(0.92+variation);
    ROUGHNESS=clamp(base_roughness+(detail-0.5)*0.14,0.15,1.0);
    METALLIC=metalness;
}
