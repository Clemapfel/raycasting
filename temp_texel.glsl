#ifdef VERTEX // vertex shader

// draw mesh attributes
layout (location = 0) in vec2 VertexPosition;
layout (location = 1) in vec2 VertexTextureCoords;
layout (location = 2) in vec4 VertexColor;

// no per-instance attributes

out float FragmentIsVisible;
out vec2 FragmentTextureCoords;
out vec4 FragmentColor;

// new: texel buffer
uniform samplerBuffer perInstanceDataBuffer;

void vertexmain() {
    vec4 instanceData = texelFetch(perInstanceDataBuffer, gl_InstanceID);
    float instanceIsVisible = instanceData.x;
    vec2 instanceOffset = instanceData.yz;
    float instanceScale = instanceData.w;

    vec2 position = VertexPosition;
    position.xy *= instanceScale;
    position.xy += instanceOffset;

    FragmentTextureCoords = VertexTextureCoords;
    FragmentColor = ConstantColor * VertexColor;
    FragmentIsVisible = instanceIsVisible;

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