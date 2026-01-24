#ifdef PIXEL

uniform float outline_thickness = 10.0;

uniform vec4 outline_color;
uniform vec4 body_color;

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coordinates, vec2 frag_position) {
    vec2 screen_size = love_ScreenSize.xy;
    vec2 pixel_size = 1.0 / screen_size;

    vec4 center = texture(tex, texture_coordinates);

    float max_alpha = 0.0;
    float radius = outline_thickness;

    int steps = int(ceil(radius)) + 1;
    float step_size = radius / float(steps);

    // approximate circular topological dilation kernel with normalized 8-directional sampling
    const float diagonal = sqrt(2.0) / 2.0;
    const float cardinal = 1.0;

    const vec2 directions[8] = vec2[8](
        vec2(cardinal, 0.0),
        vec2(-cardinal, 0.0),
        vec2(0.0, +cardinal),
        vec2(0.0, -cardinal),
        vec2(+diagonal, +diagonal),
        vec2(-diagonal, +diagonal),
        vec2(+diagonal, -diagonal),
        vec2(-diagonal, -diagonal)
    );

    for (int direction = 0; direction < 8; direction++) {
        for (int step = 1; step <= steps; step++) {
            vec2 offset = directions[direction] * (float(step) * step_size) * pixel_size;
            vec4 sample_color = texture(tex, texture_coordinates + offset);
            max_alpha = max(max_alpha, sample_color.a);
        }
    }

    max_alpha = smoothstep(0, 1, min(max_alpha, 1.0)) - center.a;

    return mix(body_color, outline_color, max_alpha) * max(max_alpha, center.a);
}

#endif