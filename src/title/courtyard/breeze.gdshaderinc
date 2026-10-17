// One clock for foliage, complete lantern assemblies, fog, water and falling petals.
uniform float ambient_time = 0.0;
uniform int wind_mode = 0;
uniform vec3 lantern_pivot = vec3(0.0);
uniform float wind_phase = 0.0;

vec3 breeze_offset(vec3 p) {
	if (wind_mode == 0) return vec3(0.0);
	if (wind_mode == 3) {
		float angle = sin(ambient_time * 0.72 + wind_phase) * 0.018;
		angle += sin(ambient_time * 1.13 + wind_phase) * 0.004;
		vec3 local = p - lantern_pivot;
		vec3 turned = vec3(local.x * cos(angle) - local.y * sin(angle), local.x * sin(angle) + local.y * cos(angle), local.z);
		return turned - local;
	}
	float height = pow(clamp((p.y - 0.45) / 4.8, 0.0, 1.0), 1.6);
	float gust = sin(ambient_time * 0.61 + p.z * 0.12) + sin(ambient_time * 1.04 + p.x * 0.20) * 0.23;
	float amplitude = (wind_mode == 1) ? 0.060 : 0.040;
	return vec3(gust, 0.0, sin(ambient_time * 0.48 + p.x * 0.09) * 0.40) * height * amplitude;
}
