#ifdef VERTEX

layout (location = 0) in vec2 origin;
layout (location = 1) in vec2 dxy;

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    vec2 position = origin + dxy;

    VaryingTexCoord = vec4(0);
    VaryingColor = gammaCorrectColor(vec4(0.5));
    love_Position = TransformProjectionMatrix * vec4(position.xy, 0, 1);
}

#endif