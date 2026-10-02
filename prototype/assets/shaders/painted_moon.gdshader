shader_type spatial;
render_mode shadows_disabled;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 p = local_position.xy / 1.2;
	float blotches = 0.0;
	blotches += 0.12 * (1.0 - smoothstep(0.08, 0.28, length(p - vec2(-0.33, 0.20))));
	blotches += 0.09 * (1.0 - smoothstep(0.02, 0.19, length(p - vec2(0.19, -0.29))));
	blotches += 0.06 * (1.0 - smoothstep(0.04, 0.20, length(p - vec2(-0.42, -0.30))));
	vec3 pigment = vec3(0.54, 0.63, 0.71) * (1.0 - blotches);
	ALBEDO = pigment;
	EMISSION = pigment * 0.34;
	ROUGHNESS = 0.96;
}
