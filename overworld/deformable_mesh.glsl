#ifdef VERTEX

layout (location = 0) in vec2 origin;
layout (location = 1) in vec2 dxy;
layout (location = 2) in vec4 color;


out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    vec2 position = origin + dxy;

    VaryingTexCoord = vec4(0);
    VaryingColor = gammaCorrectColor(color);
    love_Position = TransformProjectionMatrix * vec4(position.xy, 0, 1);
}

#endif