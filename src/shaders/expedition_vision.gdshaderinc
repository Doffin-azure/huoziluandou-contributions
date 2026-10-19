// A clamped texture repeats the last revealed row/column outside the map.
// The world is larger than the 12x8 play area: outside samples are unknown,
// rather than infinite revealed strips. Keep every sight layer consistent.
uniform bool clip_vision_bounds = false;
uniform vec2 vision_origin = vec2(0.0);
uniform vec2 vision_size = vec2(12.0, 8.0);
vec2 map_vision_at(vec2 world_xz) {
	vec2 local = world_xz - vision_origin;
	if (clip_vision_bounds && (any(lessThan(local, vec2(0.0))) || any(greaterThanEqual(local, vision_size)))) {
		return vec2(0.0);
	}
	return texture(fog_mask, clamp(local / max(vision_size, vec2(.001)), vec2(0.001), vec2(0.999))).rg;
}
