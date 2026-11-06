shader_type canvas_item;
uniform float elapsed = 0.0;
uniform float density = 0.12;

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = UV * vec2(5.0, 3.0) + vec2(elapsed * 0.008, elapsed * 0.004);
	float veil = noise(p) * 0.65 + noise(p * 2.1) * 0.35;
	COLOR = vec4(vec3(0.65, 0.73, 0.73), density * (0.35 + veil));
}
