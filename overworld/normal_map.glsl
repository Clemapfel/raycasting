
uniform vec2 player_position; // in texture coords

vec4 effect(vec4 vertex_color, Image img, vec2 texture_coords, vec2 frag_position) {
    // Sample the normal map data
    vec4 data = Texel(img, texture_coords);
    vec2 normal = normalize(data.xy * 2.0 - 1.0); // Convert from [0, 1] to [-1, 1]

    // Compute the light direction
    vec2 light_dir = normalize(player_position - texture_coords);

    // Calculate diffuse lighting (dot product of normal and light direction)
    float diffuse = max(dot(normal, light_dir), 0.0);

    // Return the final color with lighting applied
    return vec4(vec3(diffuse), 1.0); // Grayscale based on lighting intensity
}