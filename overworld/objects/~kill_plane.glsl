#define MODE_BASE 0
#define MODE_OUTLINE 1

#ifdef VERTEX

// Triangle wave function centered at zero
float triangle(float x) {
    return 2.0 * abs(fract(x) - 0.5) - 1.0;
}

// Noise function using summed triangle waves
float triangle_noise(float x, int octaves, float persistence) {
    float sum = 0.0;
    float amp = 1.0;
    float freq = 1.0;
    float maxAmp = 0.0;

    for (int i = 0; i < octaves; ++i) {
        sum += amp * triangle(x * freq);
        maxAmp += amp;
        freq *= 2.0;
        amp *= persistence;
    }

    // Normalize to [-1, 1]
    return sum / maxAmp;
}

uniform float elapsed;

layout (location = 0) in vec2 position; // start of vector
layout (location = 1) in vec3 contour_vector; // xy normalized, z magnitude
layout (location = 2) in float scale; // magnitude scale

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    const float scale = 10;
    const float magnitude = 0.4;
    vec2 offset = vec2(
    triangle_noise((position.x / love_ScreenSize.x) * scale + elapsed, 3, 1) * magnitude,
    triangle_noise((position.y / love_ScreenSize.y) * scale + elapsed, 3, 1) * magnitude
    );

    vec2 position = position + contour_vector.xy *  contour_vector.z * vec2(1 + offset);

    VaryingTexCoord = vec4(0);
    VaryingColor = gammaCorrectColor(ConstantColor);

    love_Position = TransformProjectionMatrix * vec4(position.xy, 0, 1);
}


#endif

#ifdef PIXEL

vec4 effect(vec4 vertex_color, Image image, vec2 _, vec2 frag_position) {
    return vertex_color;
}

#endif
