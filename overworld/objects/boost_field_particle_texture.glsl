#ifdef PIXEL

float dome(float dist) {
    return sqrt(max(0.0, 1.0 - dist * dist));
}

float gaussian(float dist) {
    float sigma = 0.25;
    return exp(-(dist * dist) / (2.0 * sigma * sigma));
}

float butterworth(float dist, float order) {
    float cutoff = 0.5;
    return 1.0 / (1.0 + pow(dist / cutoff, 2.0 * order));
}

float cone(float dist) {
    return dist;
}

vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    float dist = 2.0 * distance(texture_coords, vec2(0.5));

    dist = butterworth(dist, 3.0);
    return vec4(vec3(1.0), dist);
}

#endif