shader_type canvas_item;
// 宣纸：纤维噪点 + 做旧水渍 + 暗角。
// 参数可在 Inspector 里调，用于不同界面营造层次。

uniform vec3 paper_color : source_color = vec3(0.937, 0.902, 0.824);
uniform vec3 stain_color : source_color = vec3(0.78, 0.71, 0.55);
uniform float grain : hint_range(0.0, 0.4) = 0.055;
uniform float stain_amount : hint_range(0.0, 1.0) = 0.45;
uniform float vignette : hint_range(0.0, 1.5) = 0.55;
uniform float fiber : hint_range(0.0, 0.3) = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float fine = noise(uv * vec2(320.0, 320.0));
	float blot = fbm(uv * vec2(6.0, 6.0) + vec2(3.1, 7.7));
	// 纸纤维：横向拉长的细纹
	float fib = noise(vec2(uv.x * 90.0, uv.y * 1400.0));
	vec3 col = paper_color;
	col = mix(col, stain_color, smoothstep(0.55, 1.0, blot) * stain_amount * 0.6);
	col += (fine - 0.5) * grain;
	col += (fib - 0.5) * fiber;
	// 暗角
	vec2 d = uv - 0.5;
	float v = smoothstep(0.35, 0.95, length(d * vec2(1.0, 1.18)));
	col = mix(col, col * 0.66, v * vignette);
	COLOR = vec4(col, 1.0);
}
