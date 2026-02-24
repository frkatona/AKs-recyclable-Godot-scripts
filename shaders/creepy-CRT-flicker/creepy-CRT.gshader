shader_type spatial;

render_mode unshaded, cull_disabled;

// Controls
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.85;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_count : hint_range(50.0, 800.0) = 300.0;
uniform float flicker_speed : hint_range(0.5, 20.0) = 12.0;
uniform float text_chance : hint_range(0.0, 1.0) = 0.08;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.2;
uniform vec3 tint_color : source_color = vec3(0.75, 0.82, 0.9);
uniform float brightness : hint_range(0.0, 2.0) = 0.7;
uniform float text_flash_duration : hint_range(0.01, 0.3) = 0.08;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.003;

// ---- Pseudo-random hash functions ----

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash31(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.yzx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

// ---- White noise ----

float white_noise(vec2 uv, float t) {
	// Rapidly changing static – new value every frame-tick
	float time_seed = floor(t * flicker_speed);
	return hash31(vec3(floor(uv * 256.0), time_seed));
}

// ---- Character rendering (5x7 bitmap font subset) ----
// Each character is encoded as 5 columns × 7 rows packed into 35 bits of an int.
// Bit index = col * 7 + row  (row 0 = top)

const int char_D = 0x1F11111E;  // D
const int char_O = 0x0E11110E;  // O
const int char_W = 0x111B1511;  // W
const int char_N = 0x11131519; // N – needs trimming, see below

// We'll store the 5×7 bitmaps as arrays. Encoding: column-major, 7 bits per column.
// D: columns  11111  10001  10001  10001  01110
// O: columns  01110  10001  10001  10001  01110
// W: columns  10001  10001  10101  10101  01010
// N: columns  10001  11001  10101  10011  10001

// Actually let's use a simpler row-based lookup approach.

// Each glyph: 7 rows of 5-bit patterns (MSB = left pixel)
// Row data stored as a single int: row0 in bits 30..26, row1 in 25..21, etc.

// Returns 1.0 if pixel (px, py) is "on" for a given glyph row-data array
// px: 0..4 (column), py: 0..6 (row, 0=top)

// Glyph row data (5 bits per row, 7 rows) for each character
// Binary patterns (1 = pixel on):
// 'D' : 11110, 10001, 10001, 10001, 10001, 10001, 11110
// 'O' : 01110, 10001, 10001, 10001, 10001, 10001, 01110
// 'W' : 10001, 10001, 10001, 10101, 10101, 10101, 01010
// 'N' : 10001, 11001, 10101, 10011, 10001, 10001, 10001

// Pack each row as 5 bits from left (bit4=leftmost)
// Then store 7 rows in an array via a function

float glyph_pixel(int glyph_id, int px, int py) {
	// Returns 1.0 if on, 0.0 if off
	// Row data packed per-glyph. We store as series of bit checks.
	// glyph_id: 0=D, 1=O, 2=W, 3=N, 4..13 = garbage chars

	int row_bits = 0;

	if (glyph_id == 0) { // D
		if      (py == 0) row_bits = 0x1E; // 11110
		else if (py == 1) row_bits = 0x11; // 10001
		else if (py == 2) row_bits = 0x11;
		else if (py == 3) row_bits = 0x11;
		else if (py == 4) row_bits = 0x11;
		else if (py == 5) row_bits = 0x11;
		else              row_bits = 0x1E; // 11110
	} else if (glyph_id == 1) { // O
		if      (py == 0) row_bits = 0x0E; // 01110
		else if (py == 1) row_bits = 0x11; // 10001
		else if (py == 2) row_bits = 0x11;
		else if (py == 3) row_bits = 0x11;
		else if (py == 4) row_bits = 0x11;
		else if (py == 5) row_bits = 0x11;
		else              row_bits = 0x0E; // 01110
	} else if (glyph_id == 2) { // W
		if      (py == 0) row_bits = 0x11; // 10001
		else if (py == 1) row_bits = 0x11;
		else if (py == 2) row_bits = 0x11;
		else if (py == 3) row_bits = 0x15; // 10101
		else if (py == 4) row_bits = 0x15;
		else if (py == 5) row_bits = 0x15;
		else              row_bits = 0x0A; // 01010
	} else if (glyph_id == 3) { // N
		if      (py == 0) row_bits = 0x11; // 10001
		else if (py == 1) row_bits = 0x19; // 11001
		else if (py == 2) row_bits = 0x15; // 10101
		else if (py == 3) row_bits = 0x13; // 10011
		else if (py == 4) row_bits = 0x11;
		else if (py == 5) row_bits = 0x11;
		else              row_bits = 0x11;
	} else {
		// Garbage / nonsense characters – pseudo-random blocks
		float r = hash21(vec2(float(glyph_id * 7 + py), float(px + 13)));
		return step(0.45, r);
	}

	// Check bit at column px (bit 4 = leftmost column)
	int bit = (row_bits >> (4 - px)) & 1;
	return float(bit);
}

// Render a string of characters at a position on the UV quad
// Returns intensity of text at the given UV coordinate
float render_text(vec2 uv, float time_val, bool show_down) {
	// Text rendering region – centered on screen
	float char_w = 0.08;  // width of one character cell in UV space
	float char_h = 0.14;  // height of one character cell in UV space
	float gap = 0.015;    // gap between characters

	int total_chars;
	float start_x;
	float start_y;

	if (show_down) {
		total_chars = 4; // D O W N
	} else {
		// Random nonsense text: 3-6 garbage characters
		total_chars = 3 + int(hash11(floor(time_val * 3.0)) * 4.0);
	}

	// Center the text
	float total_w = float(total_chars) * (char_w + gap) - gap;
	start_x = 0.5 - total_w * 0.5;

	// Vertical position – varies for nonsense, centered for "DOWN"
	if (show_down) {
		start_y = 0.5 - char_h * 0.5;
	} else {
		start_y = 0.2 + hash11(floor(time_val * 2.7) + 7.0) * 0.5;
	}

	// Check if UV is within the text bounding box
	if (uv.x < start_x || uv.x > start_x + total_w) return 0.0;
	if (uv.y < start_y || uv.y > start_y + char_h) return 0.0;

	// Figure out which character cell we're in
	float local_x = uv.x - start_x;
	int char_idx = int(local_x / (char_w + gap));
	float in_char_x = local_x - float(char_idx) * (char_w + gap);

	// In the gap between characters?
	if (in_char_x > char_w) return 0.0;

	// Pixel coords within the 5x7 glyph
	int px = int(in_char_x / char_w * 5.0);
	int py = int((uv.y - start_y) / char_h * 7.0);
	px = clamp(px, 0, 4);
	py = clamp(py, 0, 6);

	int glyph_id;
	if (show_down) {
		// D=0, O=1, W=2, N=3
		glyph_id = char_idx;
	} else {
		// Random garbage glyph IDs (4+)
		glyph_id = 4 + int(hash11(float(char_idx) + floor(time_val * 3.0) * 13.0) * 10.0);
	}

	return glyph_pixel(glyph_id, px, py);
}

// ---- Scanlines ----

float scanlines(vec2 uv) {
	return 1.0 - scanline_strength * step(0.5, fract(uv.y * scanline_count));
}

// ---- Vignette ----

float vignette(vec2 uv) {
	vec2 d = uv - 0.5;
	return 1.0 - dot(d, d) * vignette_strength * 2.5;
}

// ---- Main ----

void fragment() {
	vec2 uv = UV;

	// Time
	float t = TIME;

	// --- Determine if we're in a text-flash frame ---
	// Use a slow tick to decide if text appears
	float slow_tick = floor(t * 2.5); // ~2.5 decisions per second
	float flash_roll = hash11(slow_tick + 0.123);
	bool text_active = flash_roll < text_chance;

	// "DOWN" appears less often than nonsense
	bool show_down = text_active && (hash11(slow_tick + 99.0) < 0.35);

	// Text flash has a short duration within the tick
	float tick_frac = fract(t * 2.5);
	bool in_flash_window = tick_frac < text_flash_duration * 2.5;
	text_active = text_active && in_flash_window;

	// --- White noise base ---
	float noise_r = white_noise(uv + vec2(chromatic_aberration, 0.0), t);
	float noise_g = white_noise(uv, t);
	float noise_b = white_noise(uv - vec2(chromatic_aberration, 0.0), t);

	vec3 noise_col = vec3(noise_r, noise_g, noise_b) * noise_intensity;

	// --- Global brightness flicker ---
	float flicker_val = 0.9 + 0.1 * hash11(floor(t * flicker_speed));
	// Occasional big flicker (rolling bar effect)
	float roll_bar = smoothstep(0.0, 0.06, abs(fract(uv.y - t * 1.7) - 0.5) - 0.47);
	flicker_val *= mix(0.7, 1.0, roll_bar);

	// --- Compose base color ---
	vec3 col = noise_col * tint_color * brightness * flicker_val;

	// --- Add text overlay ---
	if (text_active) {
		float text_val = render_text(uv, t, show_down);
		// Text appears as bright white over the static
		vec3 text_color = vec3(1.0);
		// Slight glow around text
		col = mix(col, text_color, text_val * 0.95);
		// Brighten the whole screen slightly during flash
		col *= 1.3;
	}

	// --- Scanlines ---
	col *= scanlines(uv);

	// --- Vignette ---
	col *= vignette(uv);

	// --- CRT curvature tint on edges ---
	float edge_dist = length((uv - 0.5) * 2.0);
	col *= mix(1.0, 0.6, smoothstep(0.9, 1.5, edge_dist));

	ALBEDO = col;
	EMISSION = col;
	ALPHA = 1.0;
}
