shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.72, 0.43, 1.0);
uniform float air_clock = 0.0;
uniform float opacity = 0.035;
uniform bool mote = false;
varying float seed;

void vertex() { seed = INSTANCE_CUSTOM.r; }
void fragment() {
    float shape;
    if (mote) {
        vec2 centered = (UV - 0.5) * 2.0;
        shape = exp(-dot(centered, centered) * 5.0);
        shape *= 0.75 + 0.25 * sin(air_clock * 0.7 + seed * 6.283185);
    } else {
        float centered = (UV.x - 0.5) * 2.0;
        float edge = exp(-centered * centered * 8.0) * smoothstep(0.0, 0.18, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x));
        float length_fade = smoothstep(0.0, 0.10, UV.y) * (1.0 - smoothstep(0.65, 1.0, UV.y));
        shape = edge * length_fade * (0.98 + 0.02 * sin(air_clock * 0.35));
    }
    ALBEDO = tint.rgb;
    ALPHA = shape * opacity;
}
