
#define MODE_BASE 0
#define MODE_OUTLINE 1
#ifndef MODE
#error "MODE undefined, should be 0 or 1"
#endif

#ifdef VERTEX

#if MODE == MODE_BASE

layout (location = 0) in vec2 position; // start of vector
layout (location = 1) in vec2 uv; // xy normalized, z magnitude

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    vec2 dxdy = contour_vector.xy;
    float magnitude = contour_vector.z;
    vec2 position = position + dxdy * magnitude * scale;

    VaryingTexCoord = vec4(0);

    love_Position = TransformProjectionMatrix * vec4(position.xy, 0, 1);
}

