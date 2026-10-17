shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled;
#include "res://src/title/courtyard/breeze.gdshaderinc"

// Three pigments, rather than a photographic albedo multiplied by white light.
uniform vec4 shade_ink : source_color = vec4(0.04, 0.13, 0.16, 1.0);
uniform vec4 pigment_mid : source_color = vec4(0.10, 0.30, 0.30, 1.0);
uniform vec4 pigment_light : source_color = vec4(0.24, 0.48, 0.43, 1.0);
uniform sampler2D grain_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.05;
uniform float grain_scale = 0.5;
uniform bool foliage = false;
uniform vec4 distance_ink : source_color = vec4(0.055, 0.30, 0.33, 1.0);
varying vec3 world_position;
varying vec3 world_normal;
varying float pigment_variation;

void vertex() {
	vec3 rest = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(breeze_offset(rest), 0.0)).xyz;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 p = world_position * grain_scale;
	vec3 grain = texture(grain_texture, p.yz).rgb * weights.x;
	grain += texture(grain_texture, p.xz).rgb * weights.y;
	grain += texture(grain_texture, p.xy).rgb * weights.z;
	float value = sqrt(dot(grain, vec3(0.2126, 0.7152, 0.0722)));
	// Broad, low contrast wear only. No normal-map glitter or photographic hue.
	float wear = smoothstep(0.18, 0.32, value) * 0.45 + smoothstep(0.42, 0.60, value) * 0.55;
	pigment_variation = 1.0 + (wear - 0.58) * grain_amount;
	ALBEDO = vec3(1.0);
	// The contour pass uses roughness as a surface mask. Foliage stays a colour mass.
	ROUGHNESS = foliage ? 0.15 : 1.0;
	SPECULAR = 0.0;
	EMISSION = shade_ink.rgb * pigment_variation;
	// Atmospheric perspective is shared by every pigment, also in the mirror view.
	float recession = smoothstep(13.0, 90.0, length(VERTEX)) * 0.42;
	FOG = vec4(distance_ink.rgb, recession);
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	if (foliage) {
		// Group the crown into broad colour masses; avoid lighting each tiny petal.
		facing = 0.56 + sin(world_position.x * 0.65 + world_position.y * 0.9) * 0.10;
	}
	float light_value = facing * ATTENUATION;
	float mid_band = smoothstep(0.19, 0.24, light_value);
	float lit_band = smoothstep(0.62, 0.67, light_value);
	vec3 target = mix(shade_ink.rgb, pigment_mid.rgb, mid_band);
	target = mix(target, pigment_light.rgb, lit_band);
	vec3 contribution = max(target - shade_ink.rgb, vec3(0.0)) * pigment_variation;
	if (LIGHT_IS_DIRECTIONAL) {
		// LIGHT_COLOR includes PI. Clamp energy without erasing the lighting controls.
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, contribution * clamp(LIGHT_COLOR / PI, vec3(0.0), vec3(1.0)));
	} else {
		DIFFUSE_LIGHT += contribution * min(LIGHT_COLOR / PI, vec3(1.0)) * 0.30;
	}
}
