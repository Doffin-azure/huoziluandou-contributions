shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;
#include "res://src/title/courtyard/breeze.gdshaderinc"

uniform vec4 ink : source_color = vec4(0.02, 0.055, 0.075, 1.0);
uniform float width_pixels : hint_range(0.0, 3.0) = 0.85;

void vertex() {
	vec3 rest = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(breeze_offset(rest), 0.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = MODELVIEW_NORMAL_MATRIX * NORMAL;
	vec2 projected = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	// No outlines on the fine lattice or flowers; this pass is assigned selectively.
	clip.xy += projected / max(length(projected), 0.001) * width_pixels * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb;
}
