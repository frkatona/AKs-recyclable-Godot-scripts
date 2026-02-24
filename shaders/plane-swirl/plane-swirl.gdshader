shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Swirl parameters
uniform float swirl_speed : hint_range(0.1, 5.0) = 1.2;
uniform float swirl_arms : hint_range(1.0, 10.0) = 4.0;
uniform float swirl_tightness : hint_range(0.5, 10.0) = 3.0;

// Color parameters
uniform vec4 color_inner : source_color = vec4(0.3, 0.1, 0.9, 1.0);
uniform vec4 color_outer : source_color = vec4(0.0, 0.6, 1.0, 1.0);
uniform vec4 color_highlight : source_color = vec4(0.8, 0.3, 1.0, 1.0);

// Transparency
uniform float center_radius : hint_range(0.0, 0.5) = 0.15;
uniform float center_fade : hint_range(0.01, 0.3) = 0.1;
uniform float edge_fade : hint_range(0.0, 0.5) = 0.05;

// Noise / detail
uniform float noise_scale : hint_range(1.0, 20.0) = 6.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.8;
uniform float brightness : hint_range(0.5, 5.0) = 2.0;

// Simple hash-based noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    // Center UV at (0.5, 0.5) so origin is middle of quad
    vec2 uv = UV - 0.5;

    // Polar coordinates
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    float t = TIME;

    // --- Noise-based distortion ---
    float n = fbm(uv * noise_scale + t * 0.3);
    float distorted_angle = angle + n * distortion_strength;

    // --- Swirling pattern ---
    // Spiral arms that rotate over time, tighter near center
    float spiral = sin(distorted_angle * swirl_arms - dist * swirl_tightness * 6.2832 + t * swirl_speed * 3.0);
    spiral = spiral * 0.5 + 0.5; // remap to 0..1

    // Secondary finer spiral for detail
    float spiral2 = sin(distorted_angle * (swirl_arms + 2.0) + dist * swirl_tightness * 3.0 - t * swirl_speed * 2.0);
    spiral2 = spiral2 * 0.5 + 0.5;

    // Combine spirals
    float pattern = mix(spiral, spiral2, 0.3);

    // Add noise detail
    float detail_noise = fbm(uv * noise_scale * 2.0 - t * 0.5);
    pattern = mix(pattern, detail_noise, 0.25);

    // --- Pulsing glow ---
    float pulse = sin(t * pulse_speed) * 0.15 + 0.85;

    // --- Radial gradient: brighter at mid-radius ---
    float radial = smoothstep(0.0, 0.25, dist) * smoothstep(0.5, 0.2, dist);

    // --- Color mixing ---
    vec3 col = mix(color_inner.rgb, color_outer.rgb, dist * 2.5);
    col = mix(col, color_highlight.rgb, pattern * 0.6);

    // Add highlight streaks
    float streaks = pow(spiral, 3.0) * radial;
    col += color_highlight.rgb * streaks * 0.8;

    // Apply brightness and pulse
    col *= brightness * pulse * radial;

    // Add emission glow near the swirl
    float glow = radial * pattern * pulse;
    col += col * glow * 0.5;

    // --- Alpha ---
    // Transparent center hole
    float center_alpha = smoothstep(center_radius, center_radius + center_fade, dist);
    // Fade at edges (circular boundary)
    float edge_alpha = smoothstep(0.5, 0.4 - edge_fade, dist);
    float alpha = center_alpha * edge_alpha;

    // Also fade alpha based on the swirl pattern for a more ethereal look
    alpha *= mix(0., 1.0, pattern);

    ALBEDO = col;
    ALPHA = alpha;
    EMISSION = col * 0.5;
}