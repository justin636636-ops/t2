shader_type spatial;
uniform vec4 tint : source_color = vec4(0.4, 0.2, 0.12, 1.0);
uniform float base_roughness = 0.78;
varying vec3 object_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453); }
float noise(vec3 p) {
 vec3 a=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(a),hash(a+vec3(1,0,0)),f.x),mix(hash(a+vec3(0,1,0)),hash(a+vec3(1,1,0)),f.x),f.y),mix(mix(hash(a+vec3(0,0,1)),hash(a+vec3(1,0,1)),f.x),mix(hash(a+vec3(0,1,1)),hash(a+vec3(1,1,1)),f.x),f.y),f.z);
}
float filtered_wave(float phase) { return sin(phase)*exp(-0.5*pow(fwidth(phase),2.0)); }
void vertex() { object_position=VERTEX; }
void fragment() {
 float wash=noise(object_position*8.0);
 float warp=noise(object_position*vec3(3.2,1.4,1.0));
 float grain=filtered_wave(object_position.x*75.0+warp*4.0);
 float fine=filtered_wave(object_position.x*270.0+warp*9.0);
 ALBEDO=tint.rgb*(0.96+wash*0.035+grain*0.023+fine*0.007);
 ROUGHNESS=clamp(base_roughness+(wash-0.5)*0.035,0.65,1.0);
 SPECULAR=0.24;
 CLEARCOAT=0.07;
 CLEARCOAT_ROUGHNESS=0.70;
}
