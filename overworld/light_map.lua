require "common.matrix"

rt.settings.overworld.light_map = {
    max_n_point_lights = 256,
    max_n_segment_lights = 64,
    work_group_size = 32,
    intensity_texture_format = rt.TextureFormat.RGB10A2,
    direction_texture_format = rt.TextureFormat.RG16F,
    mask_texture_format = rt.TextureFormat.R8
}

--- @class ow.LightMap
ow.LightMap = meta.class("LightMap")

--- @brief
function ow.LightMap:instantiate(width, height)
    local settings = rt.settings.overworld.light_map

    self._light_intensity_texture = rt.RenderTexture(
        width, height,
        0, -- msaa
        settings.intensity_texture_format,
        true -- compute write
    )

    self._light_direction_texture = rt.RenderTexture(
        width, height,
        0,
        settings.direction_texture_format,
        true
    )

    self._mask_texture = rt.RenderTexture(
        width, height,
        0,
        settings.mask_texture_format,
        true
    )

    self._work_group_size = settings.work_group_size
    self._dispatch_x = math.ceil(width / self._work_group_size)
    self._dispatch_y = math.ceil(height / self._work_group_size)

    self._shader = rt.ComputeShader("overworld/light_map_compute.glsl", {
        LIGHT_INTENSITY_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(settings.intensity_texture_format),
        LIGHT_DIRECTION_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(settings.direction_texture_format),
        MASK_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(settings.mask_texture_format),
        WORK_GROUP_SIZE_X = self._work_group_size,
        WORK_GROUP_SIZE_Y = self._work_group_size,
        WORK_GROUP_SIZE_Z = 1
    })

    self._point_light_buffer = rt.GraphicsBuffer(
        self._shader:get_buffer_format("point_light_source_buffer"),
        settings.max_n_point_lights,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    self._current_n_point_lights = 0
    self._point_light_buffer_data = {}
    for i = 1, settings.max_n_segment_lights do
        table.insert(self._point_light_buffer_data, {
            0, 0,      -- position
            0,         -- radius
            0, 0, 0, 0 -- color
        })
    end

    self._segment_light_buffer = rt.GraphicsBuffer(
        self._shader:get_buffer_format("segment_light_sources_buffer"),
        settings.max_n_segment_lights,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    self._current_n_segment_lights = 0
    self._segment_light_buffer_data = {}
    for i = 1, settings.max_n_segment_lights do
        table.insert(self._segment_light_buffer_data, {
            0, 0, 0, 0, -- segment
            0, 0, 0, 0  -- color
        })
    end

    self._spatial_hash = rt.Matrix()
end

--- @brief
function ow.LightMap:bind_mask()
    self._mask_texture:bind()
end

--- @brief
function ow.LightMap:unbind_mask()
    self._mask_texture:unbind()
end

--- @brief
function ow.LightMap:update(stage)
    local point_light_i = 1
    local add_point_light = function(x, y, radius, color_r, color_g, color_b, color_a)
        if point_light_i > #self._point_light_buffer_data then return end
        local data = self._point_light_buffer_data[point_light_i]
        data[1], data[2], data[3] = x, y, radius
        data[4], data[5], data[6], data[7] = color_r, color_g, color_b, color_a
        point_light_i = point_light_i + 1
    end

    local segment_light_i = 1
    local add_segment_light = function(x1, y1, x2, y2, color_r, color_g, color_b, color_a)
        if segment_light_i > #self._segment_light_buffer_data then return end
        local data = self._segment_light_buffer_data[segment_light_i]
        data[1], data[2], data[3], data[4] = x1, y1, x2, y2
        data[5], data[6], data[7], data[8] = color_r, color_g, color_b, color_a
        segment_light_i = segment_light_i + 1
    end

    stage:collect_point_lights(add_point_light)
    stage:collect_segment_lights(add_segment_light)

    self._current_n_point_lights = point_light_i - 1
    self._point_light_buffer:replace_data(
        self._point_light_buffer_data,
        1, 1, math.max(1, point_light_i - 1)
    )

    self._current_n_segment_lights = segment_light_i - 1
    self._segment_light_buffer:replace_data(
        self._segment_light_buffer_data,
        1, 1, math.max(1, segment_light_i - 1)
    )

    self._light_intensity_texture:bind()
    love.graphics.clear(0, 0, 0, 0)
    self._light_intensity_texture:unbind()

    local shader = self._shader
    shader:send("point_light_source_buffer", self._point_light_buffer)
    shader:send("n_point_light_sources", self._current_n_point_lights)

    shader:send("segment_light_sources_buffer", self._segment_light_buffer)
    shader:send("n_segment_light_sources", self._current_n_segment_lights)

    shader:send("mask_texture", self._mask_texture)
    shader:send("light_intensity_texture", self._light_intensity_texture)
    shader:send("light_direction_texture", self._light_direction_texture)

    shader:send("screen_to_world_transform", stage:get_scene():get_camera():get_transform():inverse())
    shader:dispatch(self._dispatch_x, self._dispatch_y)
end

--- @brief
function ow.LightMap:draw()
    self._light_intensity_texture:draw()
end

--- @brief
function ow.LightMap:get_light_intensity()
    return self._light_intensity_texture
end

--- @brief
function ow.LightMap:get_light_direction()
    return self._light_direction_texture
end

--- @brief
function ow.LightMap:get_size()
    return self._light_intensity_texture:get_size()
end

--[[
Great idea—baking the lights down to a couple of textures is the right way to make your normal-map pass cheap.

High-level approach

Bake two fields per pixel:
Total scalar light intensity E (you already have this “luminance” map).
An aggregate light direction plus a directionality factor that tells you how “focused” the lighting is versus being omnidirectional.
At runtime, fetch:
the aggregate direction d and a directionality r (0 = very diffuse/omnidirectional, 1 = a single dominant direction),
the total intensity E from your light map,
the surface normal from your normal map. Then compute a single-lobe Lambert term with an isotropic fallback blended by r, and multiply by E. That gives you plausible shading without per-light loops.
How to bake a single “direction” texture For each texel p in the bake (in the same screen space you used in your original shader):

For each light i (point or segment):
Compute the closest point to p (circle or segment, exactly like your runtime code).
Compute distance attenuation and the light’s scalar weight Li = luminance(light_color_i) * attenuation_i.
Compute the unit light direction li (screen-space 2D with z = 0, same as compute_light).
Accumulate:
E = Σ Li
v = Σ (Li · li) as a 3D vector (z = 0)
Convert to aggregate direction and directionality:
If E > 0:
d = normalize(v) // dominant direction
r = clamp(|v| / E, 0, 1) // directionality (0 = evenly from many directions, 1 = single light)
Else: d = (0,0,1), r = 0
Pack into one RGBA texture:
R,G: octahedral-encoded d
B: directionality r
A: optionally E (if you prefer a single fetch), or leave for other data if your luminance stays in a separate texture.
Notes

If you can afford colored lighting later, bake RGB irradiance instead of luminance: E_rgb = Σ (light_color_rgb · attenuation). Then at runtime you multiply your scalar shading term by E_rgb (better than luminance).
Use linear space for all bake outputs. Prefer RGBA16F for quality.
Using the baked direction + luminance + normal map

Fetch dirSample = dirTex(uv), luminance E from your luminance map (or alpha of dirSample if packed).
Decode d and r.
Compute lambert = max(dot(n, d), 0).
Compute an isotropic fallback for “omnidirectional” light. For your screen-space setup (lights purely in XY plane, L.z = 0), an energy-preserving average for clamp(dot(n_xy, l_xy), 0) over all directions on the circle is (1/π) · |n_xy|. Use:
iso = (1/π) * length(n.xy)
Blend by directionality and scale by E:
irradiance = E * mix(iso, lambert, r)
Multiply by your material/albedo as usual.
Edge cases and tips

When E is very small, r can be noisy. Clamp or bias r toward 0 below a small E threshold.
Mip-filter your direction map with a prefilter that averages the vector moments: store v_sum (not unit d), prefilter by averaging vectors, then recompute d and r in a downsampling pass. If that’s too much, at least clamp r in low-E regions.
If you need sharper specular later, you’ll need additional data (e.g., half-vector distribution), which won’t fit well in a single RGBA; keep this pass diffuse-only.
Below is a compact, drop-in GLSL helper for runtime usage.

/*
Runtime usage of baked light direction + luminance maps for normal mapped shading.

Encoding convention for the direction map (RGBA):
- R,G: octahedral-encoded dominant light direction d (xyz), unit length
- B:   directionality r in [0,1]  (0 = isotropic/omni, 1 = single dominant dir)
- A:   optional luminance E (total scalar light intensity). If not packed here, fetch from a separate luminance texture.

All values are expected in linear space.
*/

#ifndef BAKED_LIGHT_DIR_RUNTIME_GLSL
#define BAKED_LIGHT_DIR_RUNTIME_GLSL

// Octahedral encoding/decoding for unit vectors
// Reference: "A Survey of Efficient Representations for Independent Unit Vectors" (Cigolle et al.)
vec2 octEncode(in vec3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z) + 1e-8);
    vec2 enc = n.xy;
    if (n.z < 0.0) {
        enc = (1.0 - abs(enc.yx)) * sign(enc.xy);
    }
    // Map from [-1,1] to [0,1] for storage if needed outside this helper.
    return enc;
}

vec3 octDecode(in vec2 e) {
    vec3 n = vec3(e.x, e.y, 1.0 - abs(e.x) - abs(e.y));
    float t = clamp(-n.z, 0.0, 1.0);
    n.x += (n.x >= 0.0 ? -t : t);
    n.y += (n.y >= 0.0 ? -t : t);
    return normalize(n);
}

// Isotropic fallback for screen-space 2D lights (all L lie in XY plane, L.z = 0)
// Average of max(dot(n_xy, l_xy), 0) over directions on the circle = (1/pi) * |n_xy|
float isotropicFallback2D(in vec3 normal) {
    return 0.3183098861837907 * length(normal.xy); // 1/pi
}

// Core shading using baked direction and luminance
// - dirSample: RG = oct-encoded dir, B = r directionality, A = E luminance if packed
// - E_external: if >= 0.0, use this luminance instead of dirSample.a
// - normal: unit-length surface normal in the same space as your light directions (your previous code uses screen-space with L.z=0)
// Returns scalar irradiance to modulate albedo (for colored lighting, multiply vector E_rgb instead of scalar E)
float shadeBakedLight(
    in vec4 dirSample,
    in float E_external,
    in vec3 normal
) {
    vec3 L = octDecode(dirSample.rg);
    float r = clamp(dirSample.b, 0.0, 1.0);
    float E = (E_external >= 0.0) ? E_external : max(dirSample.a, 0.0);

    // Safety: if E is ~0, push r toward 0 to avoid noisy lobes
    float small = 1e-4;
    float rEff = (E > small) ? r : 0.0;

    float lambert = max(dot(normal, L), 0.0);
    float iso     = isotropicFallback2D(normal);

    return E * mix(iso, lambert, rEff);
}

/*
Example integration:

uniform sampler2D uDirMap;       // RGBA: dir RG (oct), dirStrength B, optional E in A
uniform sampler2D uLumMap;       // If E is not packed in alpha, this stores luminance E
uniform sampler2D uNormalMap;    // Packed in your (x=heightInv, y,z=grad) convention
uniform vec4      uAlbedo;       // Material color

vec3 decodeNormalFromYourMap(vec4 data) {
    // data = Texel(normalTex, uv): a=data.a(mask), x=heightInv, y,z=gradient (per your code)
    vec2 gradient = normalize((data.yz * 2.0) - 1.0);
    float height  = 1.0 - data.x;
    return normalize(vec3(gradient.x, gradient.y, 1.0 - height));
}

vec4 effect(vec4 vertex_color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 data = Texel(tex, texture_coords);
    float mask = data.a;
    if (mask == 0.0) discard;

    vec3 normal = decodeNormalFromYourMap(data);

    vec4 dirSample = texture(uDirMap, texture_coords);
    // Use packed E in dirSample.a or fetch from luminance map:
    bool luminancePackedInA = true;
    float E = luminancePackedInA ? -1.0 : texture(uLumMap, texture_coords).r;

    float irradiance = shadeBakedLight(dirSample, E, normal);

    vec3 litColor = uAlbedo.rgb * irradiance;
    return vec4(litColor, 1.0) * vertex_color;
}
#endif
Copy
Insert

Practical baking details

Use the exact same distance attenuation and camera_scale/light_range as your original shader to ensure visual parity.
Segment lights: use closest_point_on_segment exactly as you do at runtime to define li and distance.
If you can, compute and mip-filter v (the vector sum) and E in high precision; then derive d and r during a downsample pass to get correct prefiltering.
If you want to reduce to one texture fetch: pack E in the alpha of the direction texture as shown above.
For colored lighting: bake E_rgb instead of luminance. Then store:
RG: oct(d), B: r, A: unused (or store luminance E for compatibility). At runtime compute scalar shading S = mix(iso, lambert, r), then finalColor = albedo.rgb * (E_rgb * S).
This gives you:

O(1) runtime work per pixel (one or two texture fetches).
Plausible normal-mapped shading under many lights.
Correct behavior in cases like “two opposite lights” because r→0 and you get the isotropic fallback.
]]