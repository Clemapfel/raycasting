// ### common ###

export const EPS = 1e-8;

export function mix(lower: number, upper: number, ratio: number) : number {
    return lower * (1 - ratio) + upper * ratio;
}

export function gaussian(t : number, mean : number = 0, sigma : number = 1) : number {
    return Math.exp(-0.5 * ((t - mean) / sigma) ** 2) / (sigma * Math.sqrt(2 * Math.PI));
}

// ### Vector ###

export class Vec2 {
    x: number;
    y: number;

    constructor(x: number = 0, y: number = 0) {
        this.x = x;
        this.y = y;
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
}

export function dot(a: Vec2, b: Vec2) : number {
    return a.x * b.x + a.y * b.y;
}

export function cross(a: Vec2, b: Vec2) : number {
    return a.x * b.y - a.y * b.x;
}

export function distance(a: Vec2, b: Vec2) : number {
    return Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2);
}

export function squared_distance(a: Vec2, b: Vec2) : number {
    const delta = { x: a.x - b.x, y: a.y - b.y };
    return dot(delta, delta);
}

export function magnitude(a: Vec2) : number {
    return Math.sqrt(a.x * a.x + a.y * a.y);
}

export function angle(a: Vec2) : number {
    return Math.atan2(a.y, a.x);
}

export function flip(a: Vec2, out?: Vec2) : void {
    if (out === undefined) {
        a.x = -a.x;
        a.y = -a.y;
    } else {
        out.x = -a.x;
        out.y = -a.y;
    }
}

// Rotates 90 degrees counter-clockwise in standard math coords, which is
// clockwise on screen since the y-axis extends downwards.
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

// Rotates 90 degrees clockwise in standard math coords, which is
// counter-clockwise on screen since the y-axis extends downwards.
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

export function normalize(a: Vec2, out?: Vec2) : void {
    const length = magnitude(a);
    if (out === undefined) {
        if (length <= EPS) {
            a.x = 0;
            a.y = 0;
        }
        else {
            a.x /= length;
            a.y /= length;
        }
    } else {
        if (length <= EPS) {
            out.x = 0;
            out.y = 0;
        }
        else {
            out.x = a.x / length;
            out.y = a.y / length;
        }
    }
}

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

export function add(a: Vec2, b: Vec2, out: Vec2) : void {
    out.x = a.x + b.x
    out.y = a.y + b.y
}

export function subtract(a: Vec2, b: Vec2, out: Vec2) : void {
    out.x = a.x - b.x
    out.y = a.y - b.y
}

export function multiply(a: Vec2, b: Vec2, out: Vec2) : void {
    out.x = a.x * b.x
    out.y = a.y * b.y
}

export function divide(a: Vec2, b: Vec2, out: Vec2) : void {
    out.x = a.x / b.x
    out.y = a.y / b.y
}