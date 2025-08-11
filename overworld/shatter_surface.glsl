#ifdef VERTEX

layout (location = 0) in vec4 VertexPosition;
layout (location = 1) in vec4 VertexTexCoord;
layout (location = 2) in vec2 offset;

out vec4 VaryingTexCoord;
out vec4 VaryingColor;

void vertexmain() {
    VaryingColor = gammaCorrectColor(vec4(1)) * ConstantColor;
    VaryingTexCoord.xy = VertexTexCoord.xy;
    love_Position = TransformProjectionMatrix * vec4(VertexPosition.xy + offset.xy, 0, 1);
}

#endif
