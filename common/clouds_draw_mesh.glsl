#ifdef VERTEX

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 texture_coords;
layout (location = 2) in vec4 color;

out vec3 varying_texture_coords;
out vec4 varying_color;
out vec4 varying_frag_position;

void vertexmain() {
    varying_texture_coords = texture_coords;
    varying_color = gammaCorrectColor(ConstantColor * color);
    varying_frag_position = TransformProjectionMatrix * vec4(position.xyz, 1.0);
    love_Position = varying_frag_position;
}

#endif // VERTEX

#ifdef PIXEL

in vec3 varying_texture_coords;
in vec4 varying_color;
in vec4 varying_frag_position;

uniform sampler3D volume_texture;

uniform vec3 camera_position;
uniform mat4x4 view_transform_inverse;

out vec4 frag_color;

void pixelmain() {
    const int max_n_steps = 256;
    const float step_size = 0.01;

    vec3 ray_pos = varying_texture_coords;
    vec3 cam_pos_tex = (view_transform_inverse * vec4(camera_position, 1.0)).xyz;
    vec3 ray_dir = normalize(varying_frag_position.xyz - cam_pos_tex);

    // Light in world space, transformed to texture space
    vec3 light_dir_world = normalize(vec3(0, 1.0, 0));
    vec3 light_dir = normalize((view_transform_inverse * vec4(light_dir_world, 0.0)).xyz);

    float transmittance = 1.9;
    vec3 accumulated_light = vec3(0.0);
    float ambient_light = 0.3;

    const float n_shadow_steps = 1;
    const float shadow_step_size = step_size * 2;
    const float light_attenuation = 1; // larger: less transmittance, exponentially
    const float light_factor = 1.4;
    const float shadow_factor = 1;
    for (int i = 0; i < max_n_steps; i++) {
        float density = light_factor * texture(volume_texture, ray_pos).r;

        if (density > 0.01) {
            float light_sample = 0.0;
            vec3 light_ray_pos = ray_pos;

            for (int j = 0; j < n_shadow_steps; j++) {
                light_ray_pos += light_dir * shadow_step_size;
                light_sample += shadow_factor * texture(volume_texture, light_ray_pos).r;
            }

            // Beer-Lambert law for light attenuation
            float light_transmittance = exp(-light_sample * light_attenuation);

            // Combine lighting
            float light_energy = light_transmittance;

            // Absorption and scattering
            float sample_transmittance = exp(-density * step_size * 12.0);
            accumulated_light += (light_energy + ambient_light) * transmittance * (1.0 - sample_transmittance);
            transmittance *= sample_transmittance;
        }

        ray_pos += ray_dir * step_size;
    }

    vec3 final_color = accumulated_light;
    frag_color = vec4(final_color, 1  - transmittance);
}

#endif // PIXEL
