// ### common ###

export type Radians = number;
export type Degrees = number;

declare global {
    interface Math {
        EPS: number;
        mix: (lower: number, upper: number, ratio: number) => number;
        gaussian: (t: number, mean: number, sigma: number) => number;
        fract: (x: number) => number;
        clamp: (value: number, min: number, max: number) => number;
        step: (edge: number, x: number) => number;
        smoothstep: (edge0: number, edge1: number, x: number) => number;
        degrees: (radians: Radians) => number;
        radians: (degrees: Degrees) => number;
    }
}

Math.EPS = 1e-8;

/** **/
Math.mix = function(lower: number, upper: number, ratio: number): number {
    return lower * (1 - ratio) + upper * ratio;
}

/** **/
Math.gaussian = function(t: number, mean: number = 0, sigma: number = 1): number {
    return Math.exp(-0.5 * ((t - mean) / sigma) ** 2) / (sigma * Math.sqrt(2 * Math.PI));
}

/** **/
Math.fract = function(x: number): number {
    return x % 1.0;
}

/** **/
Math.clamp = function(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
}

/** **/
Math.step = function(edge: number, x: number): number {
    return x < edge ? 0 : 1;
}

/** **/
Math.smoothstep = function(edge0: number, edge1: number, x: number): number {
    const t = Math.clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

/** **/
Math.degrees = function(radians: number): number {
    return radians * (180 / Math.PI);
}

/** **/
Math.radians = function(degrees: number): number {
    return degrees * (Math.PI / 180);
}
