shader_type spatial;
uniform vec4 tint : source_color = vec4(0.4, 0.2, 0.12, 1.0);
uniform float finish_mode = 0.0;
uniform float metalness = 0.0;
uniform float base_roughness = 0.65;
varying vec3 object_position;

float hash(vec3 p) { return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453); }
float noise(vec3 p) {
    vec3 a=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(a),hash(a+vec3(1,0,0)),f.x),mix(hash(a+vec3(0,1,0)),hash(a+vec3(1,1,0)),f.x),f.y),mix(mix(hash(a+vec3(0,0,1)),hash(a+vec3(1,0,1)),f.x),mix(hash(a+vec3(0,1,1)),hash(a+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { object_position = VERTEX; }
// Attenuate fine periodic detail at distance rather than sparkling in motion.
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
        CLEARCOAT=0.16;
        CLEARCOAT_ROUGHNESS=0.62;
    } else if (finish_mode < 1.5) {
        float weave=filtered_wave(object_position.x*290.0)*filtered_wave(object_position.y*240.0);
        variation=weave*0.025+detail*0.09;
        RIM=0.26;
        RIM_TINT=0.82;
    } else {
        float wear=smoothstep(0.68,0.90,noise(object_position*17.0));
        variation=detail*0.05-wear*0.09;
    }
    ALBEDO=tint.rgb*(0.92+variation);
    ROUGHNESS=clamp(base_roughness+(detail-0.5)*0.14,0.15,1.0);
    METALLIC=metalness;
}
