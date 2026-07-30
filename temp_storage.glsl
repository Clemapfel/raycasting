#pragma language glsl4

#ifdef VERTEX // vertex shader

// draw mesh attributes
layout (location = 0) in vec2 VertexPosition;
layout (location = 1) in vec2 VertexTextureCoords;
layout (location = 2) in vec4 VertexColor;

out float FragmentIsVisible;
out vec2 FragmentTextureCoords;
out vec4 FragmentColor;

// new; storage buffer
struct InstanceData {
    uint isVisible;
    vec2 offset;
    float scale;
};

readonly layout(std430, binding = 0) buffer perInstanceDataBuffer {
    InstanceData data[];
};

void vertexmain() {
    InstanceData instanceData = data[gl_InstanceID];

    vec2 position = VertexPosition;
    position.xy *= instanceData.scale;
    position.xy += instanceData.offset;

    FragmentTextureCoords = VertexTextureCoords;
    FragmentColor = ConstantColor * VertexColor;
    FragmentIsVisible = instanceData.isVisible;

    love_Position = TransformProjectionMatrix * vec4(position.xy, 0.0, 1.0);
}

#endif

#ifdef PIXEL

in float FragmentIsVisible;
in vec2 FragmentTextureCoords;
in vec4 FragmentColor;

out vec4 FinalColor;
uniform sampler2D InstanceTexture;

void pixelmain() {
    if (FragmentIsVisible == 0.0) { discard; }
    FinalColor = FragmentColor * texture(InstanceTexture, FragmentTextureCoords);
}

#endif