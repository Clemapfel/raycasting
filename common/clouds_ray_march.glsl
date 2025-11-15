#pragma glsl4
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
uniform vec3 ray_direction;

uniform sampler2D export_textures[8];

out vec4 frag_color;

void pixelmain() {
    const int max_n_steps = 64;
    const float min_step_size = 0.01;
    const float max_step_size = 0.04;

    vec3 ray_pos = varying_texture_coords;
    vec3 ray_dir = ray_direction;

    // Light in world space, transformed to texture space
    vec3 light_dir = normalize(vec3(0, 1.0, 0));

    float transmittance = 1.0;
    vec3 accumulated_light = vec3(0.0);
    float ambient_light = 0.3;

    const float n_shadow_steps = 3;
    const float shadow_step_size_base = 0.04;
    const float light_attenuation = 0.5;
    const float light_factor = 0.9;
    const float shadow_factor = 2.0 * light_factor;
    const float scattering_intensity = 25.0;

    // Early exit thresholds
    const float min_transmittance = 0.01;
    const float min_density = 0.01;
    const float gradient_threshold = 0.02;

    for (int i = 0; i < max_n_steps; i++) {
        vec4 texel = texture(volume_texture, ray_pos);
        float density = texel.r;
        float gradient_mag = texel.g;

        // Adaptive step size based on gradient magnitude
        // High gradient = edge/detail, use small steps
        // Low gradient = uniform region, use large steps
        float adaptive_step = mix(max_step_size, min_step_size, smoothstep(0.0, gradient_threshold, gradient_mag));

        if (density > min_density) {
            float light_sample = 0.0;
            vec3 light_ray_pos = ray_pos;

            // Adaptive shadow steps based on local gradient
            float shadow_step_size = shadow_step_size_base * mix(2.0, 1.0, smoothstep(0.0, gradient_threshold, gradient_mag));

            // Shadow ray with early exit
            for (int j = 0; j < n_shadow_steps; j++) {
                light_ray_pos += light_dir * shadow_step_size;

                // Exit shadow ray early if out of bounds
                if (any(greaterThan(light_ray_pos, vec3(1.0))) || any(lessThan(light_ray_pos, vec3(0.0)))) {
                    break;
                }

                float shadow_density = texture(volume_texture, light_ray_pos).r;
                light_sample += shadow_factor * shadow_density;

                // Early exit if shadow is fully opaque
                if (light_sample > 5.0) {
                    break;
                }
            }

            // Beer-Lambert law for light attenuation
            float light_transmittance = exp(-light_sample * light_attenuation);

            // Lighting calculations
            float light_energy = light_transmittance;

            // Absorption and scattering
            float scaled_density = light_factor * density;
            float sample_transmittance = exp(-scaled_density * adaptive_step * scattering_intensity);
            accumulated_light += (light_energy + ambient_light) * transmittance * (1.0 - sample_transmittance);
            transmittance *= sample_transmittance;

            // Early exit if transmittance is very low (ray fully occluded)
            if (transmittance < min_transmittance) {
                break;
            }
        }

        // Advance ray with adaptive step size
        ray_pos += ray_dir * adaptive_step;

        // Exit if ray leaves volume
        if (any(greaterThan(ray_pos, vec3(1.0))) || any(lessThan(ray_pos, vec3(0.0)))) {
            break;
        }
    }

    vec3 final_color = accumulated_light;

        final_color.rgb += texture(export_textures[7], varying_texture_coords.xy).rgb;

    frag_color = vec4(final_color, 1.0 - transmittance);
}

#endif // PIXEL