#ifdef VERTEX // vertex shader

// draw mesh attributes
layout (location = 0) in vec2 VertexPosition;      // drawMesh attribute #1
layout (location = 1) in vec2 VertexTextureCoords; // drawMesh attribute #2
layout (location = 2) in vec4 VertexColor;         // drawMesh attribute #3

// data mesh attributes
layout (location = 3) in uint InstanceIsVisible; // perInstanceDataBuffer attribute #1
layout (location = 4) in vec2 InstanceOffset;    // perInstanceDataBuffer attribute #2
layout (location = 5) in float InstanceScale;    // perInstanceDataBuffer attribute #3

out float FragmentIsVisible;     // whether to discard the entire shape
out vec2 FragmentTextureCoords; // final interpolated texture coordinates, for fragment shader
out vec4 FragmentColor;         // final interpolated color, for fragment shader

void vertexmain() { // custom vertex shader entry point
    // compute position from custom vertex attributes
    vec2 position = VertexPosition;
    position.xy *= InstanceScale;
    position.xy += InstanceOffset;

    // set texture coords to default value
    FragmentTextureCoords = VertexTextureCoords; // xy = uv

    // set color to default value
    FragmentColor = ConstantColor * VertexColor; // rgba

    // set whether the instance is visible
    FragmentIsVisible = float(InstanceIsVisible);

    // set position
    love_Position = TransformProjectionMatrix * vec4(position.xy, 0.0, 1.0);
    // where `TransformProjectionMatrix` is a hardcoded global that holds the `love.graphics` Transform
    // and `love_Position` is a hardcoded global variable that holds the position of a vertex, in px
}

#endif

#ifdef PIXEL // fragment shader

in float FragmentIsVisible;    // whether to discard from vertex shader
in vec2 FragmentTextureCoords; // texture coords from vertex shader
in vec4 FragmentColor;         // color from vertex shader

out vec4 FinalColor; // final fragment color drawn to the screen at love_Position

uniform sampler2D InstanceTexture; // texture of the instance mesh

void pixelmain() { // custom fragment shader entry point
    // make shape invisible
    if (FragmentIsVisible == 0.0) { discard; }

    // default behavior of `effect`, implemented manually
    FinalColor = FragmentColor * texture(InstanceTexture, FragmentTextureCoords);
}

#endif