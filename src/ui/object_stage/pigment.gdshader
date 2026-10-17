shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled;
uniform vec4 shade_ink : source_color;
uniform vec4 pigment_mid : source_color;
uniform vec4 pigment_light : source_color;
uniform sampler2D grain_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float grain_amount = 0.04;
uniform float grain_scale = 0.8;
uniform float local_light_gain = 0.3;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 ALBEDO = vec3(1.0);
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
 float wear = texture(grain_texture, world_position.xz * grain_scale).r;
 EMISSION = shade_ink.rgb * (1.0 + (wear - 0.5) * grain_amount);
}
void light() {
 float facing = max(dot(NORMAL, LIGHT), 0.0);
 vec3 paint = mix(shade_ink.rgb, pigment_mid.rgb, smoothstep(0.12, 0.36, facing));
 paint = mix(paint, pigment_light.rgb, smoothstep(0.57, 0.82, facing));
 // Keep filtered shadow attenuation continuous, rather than thresholding PCF samples.
 vec3 contribution = max(paint - shade_ink.rgb, vec3(0.0)) * ATTENUATION;
 if (LIGHT_IS_DIRECTIONAL) DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, contribution * clamp(LIGHT_COLOR / PI, vec3(0.0), vec3(1.0)));
 else DIFFUSE_LIGHT += max(paint - shade_ink.rgb, vec3(0.0)) * min(LIGHT_COLOR / PI * ATTENUATION, vec3(1.3)) * local_light_gain;
}
