shader_type spatial;

uniform vec4 bulb_tint : source_color = vec4(1.0, 0.808, 0.561, 1.0);
varying float brightness;

void vertex() {
    brightness = INSTANCE_CUSTOM.r;
}

void fragment() {
    ALBEDO = bulb_tint.rgb * 0.35;
    EMISSION = bulb_tint.rgb * brightness * 4.0;
}
