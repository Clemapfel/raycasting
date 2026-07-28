#ifdef VERTEX

// instance mesh attributes
layout (location = 0) in vec2 VertexPosition;      // attribute #1: x: position (px), y: position (px)
layout (location = 1) in vec2 VertexTextureCoords; // attribute #2: x: u, y: v
layout (location = 2) in vec4 VertexColor;         // attribute #3: rgba

// per-instance data, now packed into a texel buffer instead of vertex attributes
// each texel holds: x = offset.x, y = offset.y, z = scale, w = unused (padding)
uniform samplerBuffer InstanceData;

out vec2 FragmentTextureCoords; // final interpolated texture coordinates, for fragment shader
out vec4 FragmentColor;         // final interpolated color, for fragment shader

void vertexmain() { // custom vertex shader entry point

    // fetch this instance's data from the texel buffer
    vec4 instanceData = texelFetch(InstanceData, love_InstanceID);
    vec2 instanceOffset = instanceData.xy;
    float instanceScale = instanceData.z;

    // compute position from custom vertex attributes
    vec2 position = VertexPosition;
    position.xy *= instanceScale;
    position.xy += instanceOffset;

    // set texture coords to default value
    FragmentTextureCoords = VertexTextureCoords; // xy = uv

    // set color to default value
    FragmentColor = ConstantColor * VertexColor; // rgba
    // where `ConstantColor` is a hardcoded global that holds the `love.graphics` Color

    // set position
    love_Position = TransformProjectionMatrix * vec4(position.xy, 0.0, 1.0);
    // where `TransformProjectionMatrix` is a hardcoded global that holds the `love.graphics` Transform
    // and `love_Position` is a hardcoded global variable that holds the position of a vertex, in px
}

#endif

#ifdef PIXEL // fragment shader

uniform sampler2D InstanceTexture; // texture of the instance mesh
in vec2 FragmentTextureCoords;     // texture coords from vertex shader
in vec4 FragmentColor;             // color from vertex shader

out vec4 FinalColor; // final fragment color drawn to the screen at love_Position

void pixelmain() { // custom fragment shader entry point

    // default behavior of `effect`, implemented manually
    FinalColor = FragmentColor * texture(InstanceTexture, FragmentTextureCoords);
}

#endif