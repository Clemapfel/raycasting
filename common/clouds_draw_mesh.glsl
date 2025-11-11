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

vec3 calculate_gradient(vec3 pos, float step) {
    float dx = texture(volume_texture, pos + vec3(step, 0, 0)).r -
    texture(volume_texture, pos - vec3(step, 0, 0)).r;
    float dy = texture(volume_texture, pos + vec3(0, step, 0)).r -
    texture(volume_texture, pos - vec3(0, step, 0)).r;
    float dz = texture(volume_texture, pos + vec3(0, 0, step)).r -
    texture(volume_texture, pos - vec3(0, 0, step)).r;
    return vec3(dx, dy, dz);
}

uniform vec3 camera_position;
uniform mat4x4 view_transform_inverse;

out vec4 frag_color;

void pixelmain() {
    const int max_n_steps = 256;
    const float step_size = 0.02;

    vec3 ray_pos = varying_texture_coords;
    vec3 cam_pos_tex = (view_transform_inverse * vec4(camera_position, 1.0)).xyz;
    vec3 ray_dir = normalize(varying_frag_position.xyz - cam_pos_tex);

    // Light in world space, transformed to texture space
    vec3 light_dir_world = normalize(vec3(0, 1.0, 0));
    vec3 light_dir = normalize((view_transform_inverse * vec4(light_dir_world, 0.0)).xyz);

    float transmittance = 1;
    vec3 accumulated_light = vec3(0.0);
    float ambient_light = 0.3;

    const float n_shadow_steps = 3;
    const float shadow_step_size = step_size * 2;
    const float light_attenuation = 0.5;
    const float light_factor = 0.9;
    const float shadow_factor = 2 * light_factor;
    const float scattering_intensity = 25;

    for (int i = 0; i < max_n_steps; i++) {
        vec4 texel = texture(volume_texture, ray_pos);
        float density = light_factor * texel.r;

        if (density > 0.01) {
            float light_sample = 0.0;
            vec3 light_ray_pos = ray_pos;

            for (int j = 0; j < n_shadow_steps; j++) {
                light_ray_pos += light_dir * shadow_step_size;
                light_sample += shadow_factor * texture(volume_texture, light_ray_pos).r;
            }

            // Beer-Lambert law for light attenuation
            float light_transmittance = exp(-light_sample * light_attenuation);

            // Calculate gradient for surface normal
            vec3 gradient = calculate_gradient(ray_pos, step_size);
            vec3 normal = normalize(gradient);

            // Silver lining effect: rim lighting on edges facing the light
            float light_facing = dot(normal, light_dir);
            float view_facing = dot(normal, -ray_dir);

            // Combine lighting
            float light_energy = light_transmittance;

            // Absorption and scattering
            float sample_transmittance = exp(-density * step_size * scattering_intensity);
            accumulated_light += (light_energy + ambient_light) * transmittance * (1.0 - sample_transmittance);
            transmittance *= sample_transmittance;
        }

        vec3 gradient = calculate_gradient(ray_pos, step_size);
        ray_pos += ray_dir * (step_size * (1 + 1 - (dot(gradient, ray_dir) + 1) / 2));

        if (any(greaterThan(ray_pos, vec3(1.0))) || any(lessThan(ray_pos, vec3(0.0)))) break;
    }

    vec3 final_color = accumulated_light;
    frag_color = vec4(final_color, 1 - transmittance);
}

#endif // PIXEL

/*
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

// Central difference gradient. Only used where density is significant.
vec3 calculate_gradient(vec3 pos, float step) {
    float dx = texture(volume_texture, pos + vec3(step, 0, 0)).r -
               texture(volume_texture, pos - vec3(step, 0, 0)).r;
    float dy = texture(volume_texture, pos + vec3(0, step, 0)).r -
               texture(volume_texture, pos - vec3(0, step, 0)).r;
    float dz = texture(volume_texture, pos + vec3(0, 0, step)).r -
               texture(volume_texture, pos - vec3(0, 0, step)).r;
    return vec3(dx, dy, dz);
}

void pixelmain() {
    // Marching parameters
    const int   MAX_STEPS             = 256;
    const float BASE_STEP             = 0.02;
    const float MIN_STEP              = BASE_STEP * 0.5;
    const float MAX_STEP              = BASE_STEP * 4.0;

    // Density thresholds and transmittance cutoff
    const float DENSITY_EMPTY_THRESH  = 0.005;   // early skip threshold
    const float DENSITY_SHADE_THRESH  = 0.01;    // shading threshold
    const float TRANSMIT_EPS          = 0.01;    // early out when fully opaque

    // Lighting and scattering
    const float ambient_light         = 0.3;
    const float light_factor          = 0.9;     // scales base density for lighting
    const float shadow_factor         = 2.0 * light_factor;
    const float light_attenuation     = 0.5;
    const float scattering_intensity  = 25.0;

    // Shadow ray parameters
    const int   N_SHADOW_STEPS        = 3;
    const float SHADOW_STEP_MULT      = 2.0;     // shadow step is larger than primary

    // Early-out threshold for shadows: if exp(-tau) < eps => tau > -ln(eps)
    const float SHADOW_EPS            = 0.02;
    const float SHADOW_TAU_CUTOFF     = -log(SHADOW_EPS) / max(light_attenuation, 1e-4);

    // Transform camera and light into texture space
    vec3 cam_pos_tex = (view_transform_inverse * vec4(camera_position, 1.0)).xyz;
    vec3 ray_pos     = varying_texture_coords;
    vec3 ray_dir     = normalize(varying_frag_position.xyz - cam_pos_tex);

    // Light in world space, transformed to texture space (directional)
    vec3 light_dir_world = normalize(vec3(0.0, 1.0, 0.0));
    vec3 light_dir       = normalize((view_transform_inverse * vec4(light_dir_world, 0.0)).xyz);

    float transmittance     = 1.0;
    vec3 accumulated_light  = vec3(0.0);

    // Start with a base step and adapt as we go
    float stepSize = BASE_STEP;

    for (int i = 0; i < MAX_STEPS; i++) {
        // Exit if ray leaves the [0,1]^3 volume
        if (any(greaterThan(ray_pos, vec3(1.0))) || any(lessThan(ray_pos, vec3(0.0)))) {
            break;
        }

        // Early out if we are effectively opaque
        if (transmittance <= TRANSMIT_EPS) {
            break;
        }

        // Sample density (scaled)
        float raw_density = texture(volume_texture, ray_pos).r;
        float density     = light_factor * raw_density;

        // Fast skip: in very empty space, use large steps and minimal work
        if (density < DENSITY_EMPTY_THRESH) {
            // Grow step quickly in emptiness
            stepSize = min(MAX_STEP, stepSize * 1.5);
            ray_pos += ray_dir * stepSize;
            continue;
        }

        // We have some content; compute lighting and shading
        float light_transmittance = 1.0;

        // Shadow ray march with early exit when enough optical thickness accumulated
        {
            float light_tau = 0.0;
            vec3 light_ray_pos = ray_pos;
            float shadow_step = stepSize * SHADOW_STEP_MULT;

            // Accumulate an approximate optical thickness along the light
            for (int j = 0; j < N_SHADOW_STEPS; j++) {
                light_ray_pos += light_dir * shadow_step;

                // Early break if shadow ray leaves volume
                if (any(greaterThan(light_ray_pos, vec3(1.0))) || any(lessThan(light_ray_pos, vec3(0.0)))) {
                    break;
                }

                float s = texture(volume_texture, light_ray_pos).r;
                light_tau += shadow_factor * s;

                // Early out if we've reached enough attenuation
                if (light_tau > SHADOW_TAU_CUTOFF) {
                    light_tau = SHADOW_TAU_CUTOFF;
                    break;
                }
            }

            light_transmittance = exp(-light_tau * light_attenuation);
        }

        // Compute gradient only where density is significant (to reduce texture fetches)
        vec3 normal = vec3(0.0);
        float gradMag = 0.0;
        if (density > DENSITY_SHADE_THRESH) {
            vec3 gradient = calculate_gradient(ray_pos, stepSize);
            gradMag = length(gradient);
            // Avoid division by zero; if gradient is tiny, normal is irrelevant anyway
            normal = gradMag > 1e-5 ? (gradient / gradMag) : vec3(0.0);
        }

        // Simple single-scattering/absorption model for this step
        // Use local stepSize in the attenuation term
        float tau = density * stepSize * scattering_intensity;
        float sample_transmittance = exp(-tau);
        float sample_alpha = 1.0 - sample_transmittance;

        // Lighting energy reaching this point
        float light_energy = light_transmittance;

        // Accumulate color (premultiplied by transmittance)
        accumulated_light += (ambient_light + light_energy) * transmittance * sample_alpha;

        // Update transmittance (Beer-Lambert)
        transmittance *= sample_transmittance;

        // Adaptive step size:
        // - Smaller steps where density or gradient magnitude is high (more detail)
        // - Larger steps in smoother/emptier regions
        // Map density and gradient magnitude to a [0,1] detail factor
        float detail_from_density = clamp(density * 4.0, 0.0, 1.0);   // tune multiplier as needed
        float detail_from_grad    = clamp(gradMag * 2.0, 0.0, 1.0);
        float detail = max(detail_from_density, detail_from_grad);

        // Interpolate between MAX_STEP (low detail) and MIN_STEP (high detail)
        stepSize = mix(MAX_STEP, MIN_STEP, detail);

        // Advance ray
        ray_pos += ray_dir * stepSize;
    }

    vec3 final_color = accumulated_light;
    frag_color = vec4(final_color, 1.0 - transmittance);
}

#endif // PIXEL
*/
