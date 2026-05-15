// ### common ###

declare global {
    interface Math {
        EPS: number;
        mix: (lower: number, upper: number, ratio: number) => number;
        gaussian: (t: number, mean: number, sigma: number) => number;
        fract: (x: number) => number;
        clamp: (value: number, min: number, max: number) => number;
        step: (edge: number, x: number) => number;
        smoothstep: (edge0: number, edge1: number, x: number) => number;
        degrees: (radians: number) => number;
        radians: (degrees: number) => number;
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
Math.radians_to_degrees = function(radians: number): number {
    return radians * (180 / Math.PI);
}

/** **/
Math.degrees_to_radians = function(degrees: number): number {
    return degrees * (Math.PI / 180);
}

// ### Vector ###

export class Vec2 {
    x: number;
    y: number;

    constructor(x: number = 0, y: number = 0) {
        this.x = x;
        this.y = y;
    }

    public clone() : Vec2 {
        return new Vec2(this.x, this.y);
    }
}

export class Vec3 {
    x: number;
    y: number;
    z: number;

    constructor(x: number = 0, y: number = 0, z: number = 0) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    public clone() : Vec3 {
        return new Vec3(this.x, this.y, this.z);
    }
}

export class Vec4 {
    x: number;
    y: number;
    z: number;
    w: number;

    constructor(x: number = 0, y: number = 0, z: number = 0, w: number = 0) {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    public clone() : Vec4 {
        return new Vec4(this.x, this.y, this.z, this.w);
    }
}

/** **/
export function dot(a: Vec2, b: Vec2) : number {
    return a.x * b.x + a.y * b.y;
}

/** **/
export function cross(a: Vec2, b: Vec2) : number {
    return a.x * b.y - a.y * b.x;
}

/** **/
export function distance(a: Vec2, b: Vec2) : number {
    return Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2);
}

/** **/
export function squared_distance(a: Vec2, b: Vec2) : number {
    const dx = a.x - b.x
    const dy = a.y - b.y
    return (dx * dx) + (dy * dy)
}

/** **/
export function magnitude(a: Vec2) : number {
    return Math.sqrt(a.x * a.x + a.y * a.y);
}

/** **/
export function angle(a: Vec2) : number {
    return Math.atan2(a.y, a.x);
}

/** **/
export function flip(a: Vec2, out?: Vec2) : void {
    if (out === undefined) {
        a.x = -a.x;
        a.y = -a.y;
    } else {
        out.x = -a.x;
        out.y = -a.y;
    }
}

/** **/
export function turn_left(a: Vec2, out?: Vec2) : void {
    if (out === undefined) {
        const previous_x = a.x;
        a.x = a.y;
        a.y = -previous_x;
    } else {
        out.x = a.y;
        out.y = -a.x;
    }
}

/** **/
export function turn_right(a: Vec2, out?: Vec2) : void {
    if (out === undefined) {
        const previous_x = a.x;
        a.x = -a.y;
        a.y = previous_x;
    } else {
        out.x = -a.y;
        out.y = a.x;
    }
}

/** **/
export function normalize(a: Vec2, out?: Vec2) : void {
    const length = magnitude(a);
    if (out === undefined) {
        if (length <= Math.EPS) {
            a.x = 0;
            a.y = 0;
        }
        else {
            a.x /= length;
            a.y /= length;
        }
    } else {
        if (length <= Math.EPS) {
            out.x = 0;
            out.y = 0;
        }
        else {
            out.x = a.x / length;
            out.y = a.y / length;
        }
    }
}

/** **/
export function rotate(a: Vec2, angle: number, out?: Vec2) : void {
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);
    if (out === undefined) {
        const previous_x = a.x;
        a.x = cos * previous_x - sin * a.y;
        a.y = sin * previous_x + cos * a.y;
    } else {
        out.x = cos * a.x - sin * a.y;
        out.y = sin * a.x + cos * a.y;
    }
}

/** **/
export function add(a: Vec2, b: Vec2, out: Vec2) : void {
    out.x = a.x + b.x
    out.y = a.y + b.y
}

/** **/
export function subtract(a: Vec2, b: Vec2, out: Vec2) : void {
    out.x = a.x - b.x
    out.y = a.y - b.y
}

export function reverse_subtract(a: Vec2, b: Vec2, out: Vec2) : void {
    out.x = b.x - a.x
    out.y = b.y - a.y
}

/** **/
export function multiply(a: Vec2, b: Vec2, out: Vec2) : void {
    out.x = a.x * b.x
    out.y = a.y * b.y
}

/** **/
export function divide(a: Vec2, b: Vec2, out: Vec2) : void {
    out.x = a.x / b.x
    out.y = a.y / b.y
}