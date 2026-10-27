shader_type canvas_item;
// Умеренная аналоговая постобработка: зерно, лёгкий сдвиг каналов,
// мягкие строки развёртки, редкая полоса нестабильности, приглушённая палитра.
// intensity = 0 полностью отключает эффект (узел скрывается скриптом).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.55;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// Медленная полоса нестабильности, проходящая снизу вверх раз в ~9 с
	float band_pos = fract(t * 0.11);
	float band = smoothstep(0.035, 0.0, abs(uv.y - (1.0 - band_pos)));
	float jitter = (hash(vec2(floor(uv.y * 240.0), floor(t * 30.0))) - 0.5);
	uv.x += jitter * 0.0035 * band * intensity;
	// Сюжетный сбой
	uv.x += jitter * 0.03 * glitch;
	uv.y += (hash(vec2(floor(t * 20.0), 1.0)) - 0.5) * 0.01 * glitch;

	// Сдвиг каналов
	float ca = (0.0012 + 0.004 * glitch) * intensity;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;

	// Приглушённая палитра: лёгкое снижение насыщенности, холодные тени, тёплый свет
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(lum), col, 1.0 - 0.22 * intensity);
	graded = mix(graded, graded * vec3(0.92, 1.0, 1.04), (1.0 - lum) * 0.5 * intensity);
	graded = mix(graded, graded * vec3(1.05, 1.0, 0.92), lum * 0.4 * intensity);

	// Строки развёртки и зерно
	float scan = 0.5 + 0.5 * sin(SCREEN_UV.y * 900.0);
	graded *= 1.0 - scan * 0.045 * intensity;
	float grain = hash(SCREEN_UV * vec2(1920.0, 1080.0) + fract(t * 13.7) * 100.0) - 0.5;
	graded += grain * 0.06 * intensity;
	graded += band * 0.02 * intensity;

	// Виньетка
	vec2 d = SCREEN_UV - 0.5;
	float vig = 1.0 - dot(d, d) * 0.9 * intensity;
	graded *= vig;

	COLOR = vec4(graded, 1.0);
}
