shader_type canvas_item;
render_mode unshaded;

// Preview only: quiet the scenery without processing UI or enemy artwork.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 focus_rect = vec4(0.61, 0.36, 0.94, 0.86);

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec2 center = (focus_rect.xy + focus_rect.zw) * 0.5;
	vec2 radius = (focus_rect.zw - focus_rect.xy) * 0.5;
	float distance_from_subject = length((SCREEN_UV - center) / radius);
	float focus = 1.0 - smoothstep(0.45, 1.25, distance_from_subject);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 3.2;
	vec3 softened = original.rgb * 4.0;
	softened += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).rgb * 2.0;
	softened += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).rgb * 2.0;
	softened += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).rgb * 2.0;
	softened += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).rgb * 2.0;
	softened += texture(TEXTURE, UV + step_uv).rgb;
	softened += texture(TEXTURE, UV - step_uv).rgb;
	softened += texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)).rgb;
	softened += texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)).rgb;
	softened /= 16.0;
	vec3 color = mix(original.rgb, softened, 0.24 + 0.61 * focus);
	float red_tree = smoothstep(0.06, 0.38, color.r - max(color.g, color.b));
	color = mix(color, vec3(0.24, 0.10, 0.13), red_tree * (0.45 + 0.25 * focus));
	float value = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(color, vec3(value), 0.23 + 0.27 * focus);
	color = mix(color, vec3(0.075, 0.17, 0.18), 0.16 + 0.35 * focus);
	COLOR = vec4(mix(original.rgb, color, strength), original.a);
}
