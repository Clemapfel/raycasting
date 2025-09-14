#ifdef PIXEL

#define PI 3.1415926535897932384626433832795

float gaussian(float x, float sigma)
{
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

float exponential_falloff(float x, float decay)
{
    return exp(-decay * pow(x, 1.8));
}

float distance_to_line(vec2 pt, vec4 line)
{
    vec2 a = line.xy;
    vec2 b = line.zw;
    vec2 ab = b - a;
    float ab_len = length(ab);
    if (ab_len < 1e-6) {
        // Line is degenerate; return distance to point a
        return length(pt - a);
    }
    vec2 ap = pt - a;
    // 2D cross product: ab.x * ap.y - ab.y * ap.x
    float cross = abs(ab.x * ap.y - ab.y * ap.x);
    return cross / ab_len;
}

vec2 closest_point_on_line(vec2 pt, vec4 line)
{
    vec2 a = line.xy;
    vec2 b = line.zw;
    vec2 ab = b - a;
    float ab_len2 = dot(ab, ab);
    if (ab_len2 < 1e-8) {
        // Degenerate line: return the only point available
        return a;
    }
    float t = dot(pt - a, ab) / ab_len2;
    return a + t * ab;
}

vec2 reflect_point_across_line(vec2 point, vec4 line)
{
    vec2 a = line.xy;
    vec2 b = line.zw;
    vec2 line_dir = normalize(b - a);
    vec2 line_normal = vec2(-line_dir.y, line_dir.x);

    // vector from line point to the point we want to reflect
    vec2 to_point = point - a;

    // vroject onto the normal to get the perpendicular distance
    float dist_along_normal = dot(to_point, line_normal);

    // reflect by moving twice the distance in the opposite direction
    vec2 reflected = point - 2.0 * dist_along_normal * line_normal;

    return reflected;
}

uniform vec2 camera_offset;
uniform float camera_scale = 1;
vec2 to_uv(vec2 frag_position) {
    vec2 uv = frag_position;
    vec2 origin = vec2(love_ScreenSize.xy / 2);
    uv -= origin;
    uv /= camera_scale;
    uv += origin;
    uv -= camera_offset;
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;
    uv /= love_ScreenSize.xy;
    return uv;
}

uniform vec4 axis_of_reflection;
uniform float radius;
uniform vec2 player_position;
uniform vec4 player_color;

vec4 effect(vec4 color, sampler2D img, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texel = texture(img, texture_coords);

    vec2 pxy = to_uv(player_position);
    vec2 uv = to_uv(screen_coords);
    vec4 axis = vec4(to_uv(axis_of_reflection.xy), to_uv(axis_of_reflection.zw));

    // mirror falloff
    const float mirror_range = 10.0;
    float dist_to_mirror = distance_to_line(uv, axis);
    float normalized_dist = dist_to_mirror * mirror_range;
    float mirror_falloff = exponential_falloff(normalized_dist, 3.5);
    mirror_falloff = clamp(mirror_falloff, 0.0, 1.0);

    // player glow
    vec2 reflected_player_pos = to_uv(reflect_point_across_line(player_position, axis_of_reflection));
    float glow = mirror_falloff * gaussian(distance(uv, reflected_player_pos), 1. / 50);

    // diffuse reflection
    vec2 diffuse_center = closest_point_on_line(reflected_player_pos, axis);
    float diffuse = gaussian(distance(uv, diffuse_center), 1. / 40) * gaussian(normalized_dist, 1 / 5.);
    float diffuse_weight = gaussian(distance(pxy, diffuse_center), 1. / 20);
    diffuse *= diffuse_weight;

    const float glow_intensity = 0.2;
    const float mirror_opacity = 0.25;
    const float diffuse_inensity = 0.5;
    return vec4(mirror_opacity * texel * mirror_falloff + glow * player_color * glow_intensity + diffuse * player_color * diffuse_inensity);
}

#endif