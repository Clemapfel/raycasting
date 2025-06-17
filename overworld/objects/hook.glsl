#ifdef PIXEL

uniform float elapsed;

vec4 effect(vec4 color, Image img, vec2 uv, vec2 _) {
    // Center UV around (0,0)
    vec2 centered = uv - vec2(0.5);

    // Distance from center (0 to 0.707)
    float dist = length(centered);

    // Angle in radians (-PI to PI)
    float angle = atan(centered.y, centered.x);

    // Vortex swirl: modulate angle by distance for spiral arms
    float swirl = sin(angle * 6.0 + dist * 12.0 + elapsed);

    // Vortex mask: fade out at edges, sharp at center
    float mask = smoothstep(0.4, 0.0, dist);

    // Psychedelic color: use angle and distance for color cycling
    vec3 vortexColor = 0.5 + 0.5 * cos(vec3(0.0, 2.0, 4.0) + angle * 2.0 + dist * 10.0);

    // Combine everything: swirl modulates brightness, mask fades out
    float intensity = (1 - distance(uv, vec2(0.5)) * 2) + mask * (0.7 + 0.3 * swirl);

    return vec4(vortexColor * intensity, intensity);
}

#endif // PIXEL