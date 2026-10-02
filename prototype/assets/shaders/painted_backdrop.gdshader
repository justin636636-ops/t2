shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform float sea_layer = 0.0;
uniform vec4 show_tint : source_color = vec4(1.0);
uniform float show_gain = 1.0;
uniform float sea_clock = 0.0;
uniform float sea_motion = 1.0;
uniform sampler2D harbour_paint : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_harbour_paint = false;
varying vec3 object_position;

void vertex() { object_position = VERTEX; }

void fragment() {
    if (use_harbour_paint) {
        // The source is 3:1; the curved board is wider. Clamp the dark margins
        // instead of stretching harbour roofs. UV.y runs from floor to ceiling.
        vec2 paint_uv = vec2(((object_position.x + 2.2) / 19.14) + 0.5, 1.0 - UV.y);
        vec3 painting = texture(harbour_paint, paint_uv).rgb;
        float painted_edge = smoothstep(0.0, 0.08, paint_uv.x)
            * (1.0 - smoothstep(0.92, 1.0, paint_uv.x));
        painting = mix(vec3(0.003, 0.007, 0.014), painting, painted_edge);
        painting *= mix(vec3(1.0), show_tint.rgb, 0.18);
        ALBEDO = vec3(0.0);
        EMISSION = painting * 0.90 * show_gain;
        ROUGHNESS = 0.94;
    } else {
    vec3 midnight = vec3(0.019, 0.043, 0.064);
    vec3 horizon = vec3(0.043, 0.091, 0.094);
    float wash = 1.0 - smoothstep(2.0, 7.2, object_position.y);
    vec3 pigment = mix(midnight, horizon, wash);
    float brush = sin(object_position.x * 13.0 + sin(object_position.y * 2.4)) * sin(object_position.y * 17.0) * 0.025;
    if (sea_layer > 0.5) {
        pigment = mix(vec3(0.034, 0.075, 0.087), vec3(0.062, 0.122, 0.120), sea_layer / 3.0);
        float strokes = sin(object_position.x * 2.9 + object_position.y * 19.0);
        brush += strokes * 0.06;
    } else {
        // Sparse stamped stars remain static, low contrast and above the lanes.
        vec2 cell = floor(object_position.xy * vec2(0.65, 0.85));
        float stamp = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
        vec2 center = vec2(0.3 + stamp * 0.4, 0.36 + fract(stamp * 17.0) * 0.28);
        vec2 point = fract(object_position.xy * vec2(0.65, 0.85)) - center;
        float radius = 0.013 + stamp * 0.010;
        float edge = max(fwidth(length(point)), 0.002);
        float star = (1.0 - smoothstep(radius, radius + edge, length(point))) * step(0.35, stamp) * smoothstep(4.5, 4.9, object_position.y);
        pigment += vec3(0.12, 0.13, 0.12) * star;
    }
    pigment *= mix(vec3(1.0), show_tint.rgb, 0.18);
    ALBEDO = pigment * 0.24 * (1.0 + brush);
    // Slow, broad theatre water reflection stays behind both firing lanes.
    // No TIME: pause and reduced motion are controlled by the show owner.
    float phase = sea_clock * 0.22 * sea_motion;
    float water_light = sin(object_position.x * 0.82 + phase) * sin(object_position.y * 5.4 - phase * 0.7);
    float sea_mask = sea_layer > 0.5 ? 1.0 : (1.0 - smoothstep(2.4, 4.0, object_position.y));
    EMISSION = pigment * (0.035 + sea_mask * (0.035 + water_light * 0.025)) * show_gain;
    ROUGHNESS = 0.94;
    }
}
