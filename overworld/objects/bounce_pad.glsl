#ifdef VERTEX

layout(location = 3) in vec3 axis_offset;

// add offset to vertex position
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 axis = axis_offset.xy;
    float offset = axis_offset.z;
    vertex_position.xy += axis * offset;
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

uniform sampler3D noise_texture;
float worley_noise(vec3 p) {
    p.xy /= 4;
    return texture(noise_texture, p).r;
}

float worley_octaves(vec3 p, int octaves, float lacunarity, float gain) {
    float amplitude = 1.0;
    float frequency = 1.0;
    float sum = 0.0;
    float norm = 0.0;

    for (int i = 0; i < octaves; i++) {
        float d = worley_noise(p * frequency);
        sum += (1.0 - d) * amplitude;
        norm += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }
    return sum / norm;
}

uniform float elapsed;
uniform float signal;
uniform vec2 axis; // inverse bounce normal

uniform vec2 camera_offset;
uniform float camera_scale = 1;
vec2 to_uv(vec2 frag_position) {
    vec2 uv = frag_position;
    vec2 origin = vec2(love_ScreenSize.xy / 2);
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;
    uv /= love_ScreenSize.xy;
    return uv;
}

vec4 effect(vec4 color, Image img, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = to_uv(vertex_position);

    const float noise_scale = 6;
    vec3 noise_p = vec3(uv * noise_scale - axis * vec2(elapsed * 0.8 * 0.05), signal * 0.5);

    float bubble = worley_octaves(noise_p, 3, 1.5, 1);

    int steps = 10; // n toon shading steps
    float step_size = 1.0 / float(steps);

    float step_index = floor(bubble / step_size);
    float lower_bound = step_index * step_size;
    float upper_bound = (step_index + 1.0) * step_size;

    float eps = mix(0.025, 0.2, signal);

    float t = smoothstep(
        lower_bound + step_size * (0.5 - eps),
        lower_bound + step_size * (0.5 + eps),
        bubble
    );

    bubble = mix(lower_bound, upper_bound, t);
    float value = smoothstep(-0.5, 0.5, bubble);

    return vec4(vec3(mix(vec3(0), color.rgb, value)), color.a);
}

#endif