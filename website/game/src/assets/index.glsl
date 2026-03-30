precision mediump float;
uniform float time;
uniform vec2 canvas_size;

void main() {
    // 1. Normalize coordinates to [0, 1]
    vec2 uv = gl_FragCoord.xy / canvas_size;

    // 2. Remap to [-1, 1] range
    vec2 p = uv * 2.0 - 1.0;

    // 3. Correct the Aspect Ratio
    // We multiply the x-component by (width / height)
    // This keeps the vertical range [-1, 1] and expands/contracts the horizontal
    float aspect = canvas_size.x / canvas_size.y;
    p.x *= aspect;

    // 4. Shape Logic
    // atan(p.y, p.x) provides the angle for the "wobble" effect
    float angle = atan(p.y, p.x);
    float wobble = 0.1 * sin(time / 100.0 + angle * 6.0);

    float d = length(p) - 0.5 + wobble;
    float ring = smoothstep(0.02, 0.0, abs(d));

    // 5. Coloring
    vec3 color = mix(vec3(0), vec3(0.2, 0.8, 1.0), ring);
    gl_FragColor = vec4(color, 1.0);
}