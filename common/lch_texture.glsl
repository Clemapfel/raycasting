#ifndef TEXTURE_FORMAT
#error "TEXTURE_FORMAT undefined"
#endif

#ifndef WORK_GROUP_SIZE_X
#error "WORK_GROUP_SIZE_X undefined"
#endif

#ifndef WORK_GROUP_SIZE_Y
#error "WORK_GROUP_SIZE_Y undefined"
#endif

#ifndef WORK_GROUP_SIZE_Z
#error "WORK_GROUP_SIZE_Z undefined"
#endif

vec3 lch_to_rgb(vec3 lch) {
    float luminance = lch.x * 100.0;
    float chroma    = lch.y * 100.0;
    float hue_rad   = radians(lch.z * 360.0);

    float lab_a = cos(hue_rad) * chroma;
    float lab_b = sin(hue_rad) * chroma;

    float fy = (luminance + 16.0) / 116.0;
    float fx = lab_a / 500.0 + fy;
    float fz = fy - lab_b / 200.0;

    float x = 0.95047 * (fx > 0.206897 ? fx * fx * fx : (fx - 16.0 / 116.0) / 7.787);
    float y = 1.00000 * (fy > 0.206897 ? fy * fy * fy : (fy - 16.0 / 116.0) / 7.787);
    float z = 1.08883 * (fz > 0.206897 ? fz * fz * fz : (fz - 16.0 / 116.0) / 7.787);

    float linear_r =  3.2406 * x - 1.5372 * y - 0.4986 * z;
    float linear_g = -0.9689 * x + 1.8758 * y + 0.0415 * z;
    float linear_b =  0.0557 * x - 0.2040 * y + 1.0570 * z;

    return vec3(
        clamp(linear_r > 0.0031308 ? 1.055 * pow(linear_r, 1.0 / 2.4) - 0.055 : 12.92 * linear_r, 0.0, 1.0),
        clamp(linear_g > 0.0031308 ? 1.055 * pow(linear_g, 1.0 / 2.4) - 0.055 : 12.92 * linear_g, 0.0, 1.0),
        clamp(linear_b > 0.0031308 ? 1.055 * pow(linear_b, 1.0 / 2.4) - 0.055 : 12.92 * linear_b, 0.0, 1.0)
    );
}

uniform float lightness_default;
uniform float chroma_default;
uniform float hue_default;

layout(TEXTURE_FORMAT) uniform writeonly image3D output_texture;

layout (local_size_x = WORK_GROUP_SIZE_X, local_size_y = WORK_GROUP_SIZE_Y, local_size_z = WORK_GROUP_SIZE_Z) in;
void computemain()
{
    ivec3 size = imageSize(output_texture);
    uvec3 gid  = gl_GlobalInvocationID.xyz;

    if (gid.x >= uint(size.x) || gid.y >= uint(size.y) || gid.z >= uint(size.z))
        return;

    float lightness = size.x > 1 ? float(gid.x) / float(size.x - 1) : lightness_default;
    float chroma    = size.y > 1 ? float(gid.y) / float(size.y - 1) : chroma_default;
    float hue       = size.z > 1 ? float(gid.z) / float(size.z - 1) : hue_default;

    vec3 rgb = lch_to_rgb(vec3(lightness, chroma, hue));
    imageStore(output_texture, ivec3(gid), vec4(rgb, 1.0));
}
