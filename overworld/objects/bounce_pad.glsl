#ifdef VERTEX

layout(location = 3) in vec3 axis_offset;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 axis = axis_offset.xy;
    float offset = axis_offset.z;
    vertex_position.xy += axis * offset;
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

vec4 worley_noise_with_offset(vec3 p) {
    vec3 n = floor(p);
    vec3 f = fract(p);

    float minDist = 1.0;
    vec3 minOffset = vec3(0.0);

    for (int k = -1; k <= 1; k++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec3 g = vec3(i, j, k);

                vec3 cell = n + g;
                cell = fract(cell * vec3(0.1031, 0.1030, 0.0973));
                cell += dot(cell, cell.yxz + 19.19);
                vec3 o = fract((cell.xxy + cell.yzz) * cell.zyx);

                vec3 delta = g + o - f;
                float d = length(delta);
                if (d < minDist) {
                    minDist = d;
                    minOffset = o;
                }
            }
        }
    }

    return vec4(minOffset, minDist);
}

vec3 lch_to_rgb(vec3 lch) {
    float L = lch.x * 100.0;
    float C = lch.y * 100.0;
    float H = lch.z * 360.0;

    float a = cos(radians(H)) * C;
    float b = sin(radians(H)) * C;

    float Y = (L + 16.0) / 116.0;
    float X = a / 500.0 + Y;
    float Z = Y - b / 200.0;

    X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
    Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
    Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);

    float R = X *  3.2406 + Y * -1.5372 + Z * -0.4986;
    float G = X * -0.9689 + Y *  1.8758 + Z *  0.0415;
    float B = X *  0.0557 + Y * -0.2040 + Z *  1.0570;

    R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
    G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
    B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;

    return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
}

uniform float elapsed;
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

// Gaussianize function for non-linear toon steps (optional, can be removed for linear steps)
float gaussianize(float x) {
    float y = (x - 0.5) * 4.0;
    return 0.5 + 0.5 * tanh(y);
}

vec4 effect(vec4 color, Image img, vec2 texture_coords, vec2 vertex_position) {
    vec2 uv = to_uv(vertex_position);

    const int OCTAVES = 1;
    float base_scale = 10.0;
    float scale = base_scale;
    float amplitude = 1.0;
    float total_amplitude = 0.0;

    vec3 accum_rgb = vec3(0.0);
    float accum_alpha = 0.0;

    for (int octave = 0; octave < 4; ++octave) {
        // Offset time per octave for more variety
        float t = elapsed + float(octave) * 13.37;
        vec4 noise = worley_noise_with_offset(vec3(uv.xy * scale, t));

        // Unique hue per bubble per octave
        float hue = fract(noise.x + noise.y + noise.z + float(octave) * 0.21);

        // Bubble intensity (optionally gaussianized for non-linear steps)
        float bubble = 1.0 - smoothstep(0.4, 1, noise.w);

        // Color for this octave's bubbles
        vec3 rgb = lch_to_rgb(vec3(0.8, 0.9, hue));

        // Accumulate, weighted by amplitude
        accum_rgb += rgb * bubble * amplitude;
        accum_alpha += bubble * amplitude;
        total_amplitude += amplitude;

        scale *= 2.0;
        amplitude *= 0.6;
    }

    // Normalize accumulated color and alpha
    if (total_amplitude > 0.0) {
        accum_rgb /= total_amplitude;
        accum_alpha /= total_amplitude;
    }

    return color * vec4(accum_alpha);
}

#endif