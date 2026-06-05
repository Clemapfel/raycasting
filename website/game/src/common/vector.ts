import { type Radians } from "./math.ts";

/** **/
export class Vec2 {
    x: number;
    y: number;

    /** **/
    constructor(x: number = 0, y: number = 0) {
        this.x = x;
        this.y = y;
    }

    /** **/
    public assign(x : number, y : number) {
        this.x = x;
        this.y = y;
    }

    /** **/
    public clone() : Vec2 {
        return new Vec2(this.x, this.y);
    }

    /** **/
    public dot(other: Vec2) : number {
        return this.x * other.x + this.y * other.y;
    }

    /** **/
    public cross(other: Vec2) : number {
        return this.x * other.y - this.y * other.x;
    }

    /** **/
    public distance(other: Vec2) : number {
        return Math.sqrt((this.x - other.x) ** 2 + (this.y - other.y) ** 2);
    }

    /** **/
    public squared_distance(other: Vec2) : number {
        const dx = this.x - other.x
        const dy = this.y - other.y
        return (dx * dx) + (dy * dy)
    }

    /** **/
    public magnitude() : number {
        return Math.sqrt(this.x * this.x + this.y * this.y);
    }

    /** **/
    public angle() : Radians {
        return Math.atan2(this.y, this.x);
    }

    /** **/
    public flip(write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);
        target.x = -this.x;
        target.y = -this.y;
        return target;
    }

    /** **/
    public turn_left(write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);
        const previous_x = this.x;
        target.x = this.y;
        target.y = -previous_x;
        return target;
    }

    /** **/
    public turn_right(write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);
        const previous_x = this.x;
        target.x = -this.y;
        target.y = previous_x;
        return target
    }

    /** **/
    public normalize(write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);
        const length = this.magnitude();
        if (length <= Math.EPS) {
            target.x = 0;
            target.y = 0;
        }
        else {
            target.x = this.x / length;
            target.y = this.y / length;
        }
        return target;
    }

    /** **/
    public rotate(angle: number, write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);
        const cos = Math.cos(angle);
        const sin = Math.sin(angle);
        const previous_x = this.x;
        const previous_y = this.y;
        target.x = cos * previous_x - sin * previous_y;
        target.y = sin * previous_x + cos * previous_y;
        return target;
    }

    /** **/
    public add(other: Vec2 | number, write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);

        if (other instanceof Vec2) {
            target.x = this.x + other.x;
            target.y = this.y + other.y;
        }
        else {
            target.x = this.x + other;
            target.y = this.y + other;
        }
        return target;
    }

    /** **/
    public subtract(other: Vec2 | number, write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);
        if (other instanceof Vec2) {
            target.x = this.x - other.x;
            target.y = this.y - other.y;
        }
        else {
            target.x = this.x - other;
            target.y = this.y - other;
        }
        return target;
    }

    public reverse_subtract(other: Vec2 | number, write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);
        if (other instanceof Vec2) {
            target.x = other.x - this.x;
            target.y = other.y - this.y;
        }
        else {
            target.x = other - this.x;
            target.y = other - this.y;
        }
        return target;
    }

    /** **/
    public multiply(other: Vec2 | number, write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);
        if (other instanceof Vec2) {
            target.x = this.x * other.x;
            target.y = this.y * other.y;
        }
        else {
            target.x = this.x * other;
            target.y = this.y * other;
        }

        return target;
    }

    /** **/
    public divide(other: Vec2 | number, write_to?: Vec2) : Vec2 {
        const target = (write_to ?? this);
        if (other instanceof Vec2) {
            target.x = this.x / other.x;
            target.y = this.y / other.y;
        }
        else {
            target.x = this.x / other;
            target.y = this.y / other;
        }

        return target;
    }
}

/** **/
export class Vec3 {
    x: number;
    y: number;
    z: number;

    /** **/
    constructor(x: number = 0, y: number = 0, z: number = 0) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    /** **/
    public assign(x : number, y : number, z : number) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    /** **/
    public clone() : Vec3 {
        return new Vec3(this.x, this.y, this.z);
    }

    /** **/
    public dot(other: Vec3) : number {
        return this.x * other.x + this.y * other.y + this.z * other.z;
    }

    /** **/
    public cross(other: Vec3, write_to?: Vec3) : Vec3 {
        const target = (write_to ?? this);

        const previous_x = this.x;
        const previous_y = this.y;
        const previous_z = this.z;

        target.x = previous_y * other.z - previous_z * other.y;
        target.y = previous_z * other.x - previous_x * other.z;
        target.z = previous_x * other.y - previous_y * other.x;

        return target;
    }

    /** **/
    public distance(other: Vec3) : number {
        return Math.sqrt(
            (this.x - other.x) ** 2 +
            (this.y - other.y) ** 2 +
            (this.z - other.z) ** 2
        );
    }

    /** **/
    public squared_distance(other: Vec3) : number {
        const dx = this.x - other.x;
        const dy = this.y - other.y;
        const dz = this.z - other.z;

        return (dx * dx) + (dy * dy) + (dz * dz);
    }

    /** **/
    public magnitude() : number {
        return Math.sqrt(
            this.x * this.x +
            this.y * this.y +
            this.z * this.z
        );
    }

    /** **/
    public normalize(write_to?: Vec3) : Vec3 {
        const target = (write_to ?? this);
        const length = this.magnitude();

        if (length <= Math.EPS) {
            target.x = 0;
            target.y = 0;
            target.z = 0;
        }
        else {
            target.x = this.x / length;
            target.y = this.y / length;
            target.z = this.z / length;
        }

        return target;
    }

    /** **/
    public add(other: Vec3 | number, write_to?: Vec3) : Vec3 {
        const target = (write_to ?? this);

        if (other instanceof Vec3) {
            target.x = this.x + other.x;
            target.y = this.y + other.y;
            target.z = this.z + other.z;
        }
        else {
            target.x = this.x + other;
            target.y = this.y + other;
            target.z = this.z + other;
        }

        return target;
    }

    /** **/
    public subtract(other: Vec3 | number, write_to?: Vec3) : Vec3 {
        const target = (write_to ?? this);

        if (other instanceof Vec3) {
            target.x = this.x - other.x;
            target.y = this.y - other.y;
            target.z = this.z - other.z;
        }
        else {
            target.x = this.x - other;
            target.y = this.y - other;
            target.z = this.z - other;
        }

        return target;
    }

    /** **/
    public reverse_subtract(other: Vec3 | number, write_to?: Vec3) : Vec3 {
        const target = (write_to ?? this);

        if (other instanceof Vec3) {
            target.x = other.x - this.x;
            target.y = other.y - this.y;
            target.z = other.z - this.z;
        }
        else {
            target.x = other - this.x;
            target.y = other - this.y;
            target.z = other - this.z;
        }

        return target;
    }

    /** **/
    public multiply(other: Vec3 | number, write_to?: Vec3) : Vec3 {
        const target = (write_to ?? this);

        if (other instanceof Vec3) {
            target.x = this.x * other.x;
            target.y = this.y * other.y;
            target.z = this.z * other.z;
        }
        else {
            target.x = this.x * other;
            target.y = this.y * other;
            target.z = this.z * other;
        }

        return target;
    }

    /** **/
    public divide(other: Vec3 | number, write_to?: Vec3) : Vec3 {
        const target = (write_to ?? this);

        if (other instanceof Vec3) {
            target.x = this.x / other.x;
            target.y = this.y / other.y;
            target.z = this.z / other.z;
        }
        else {
            target.x = this.x / other;
            target.y = this.y / other;
            target.z = this.z / other;
        }

        return target;
    }
}

/** **/
export class Vec4 {
    x: number;
    y: number;
    z: number;
    w: number;

    /** **/
    constructor(x: number = 0, y: number = 0, z: number = 0, w: number = 0) {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    /** **/
    public assign(x : number, y : number, z : number, w : number) {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    /** **/
    public clone() : Vec4 {
        return new Vec4(this.x, this.y, this.z, this.w);
    }

    /** **/
    public distance(other: Vec4) : number {
        return Math.sqrt(
            (this.x - other.x) ** 2 +
            (this.y - other.y) ** 2 +
            (this.z - other.z) ** 2 +
            (this.w - other.w) ** 2
        );
    }

    /** **/
    public squared_distance(other: Vec4) : number {
        const dx = this.x - other.x;
        const dy = this.y - other.y;
        const dz = this.z - other.z;
        const dw = this.w - other.w;

        return (
            (dx * dx) +
            (dy * dy) +
            (dz * dz) +
            (dw * dw)
        );
    }

    /** **/
    public magnitude() : number {
        return Math.sqrt(
            this.x * this.x +
            this.y * this.y +
            this.z * this.z +
            this.w * this.w
        );
    }

    /** **/
    public normalize(write_to?: Vec4) : Vec4 {
        const target = (write_to ?? this);
        const length = this.magnitude();

        if (length <= Math.EPS) {
            target.x = 0;
            target.y = 0;
            target.z = 0;
            target.w = 0;
        }
        else {
            target.x = this.x / length;
            target.y = this.y / length;
            target.z = this.z / length;
            target.w = this.w / length;
        }

        return target;
    }

    /** **/
    public add(other: Vec4 | number, write_to?: Vec4) : Vec4 {
        const target = (write_to ?? this);

        if (other instanceof Vec4) {
            target.x = this.x + other.x;
            target.y = this.y + other.y;
            target.z = this.z + other.z;
            target.w = this.w + other.w;
        }
        else {
            target.x = this.x + other;
            target.y = this.y + other;
            target.z = this.z + other;
            target.w = this.w + other;
        }

        return target;
    }

    /** **/
    public subtract(other: Vec4 | number, write_to?: Vec4) : Vec4 {
        const target = (write_to ?? this);

        if (other instanceof Vec4) {
            target.x = this.x - other.x;
            target.y = this.y - other.y;
            target.z = this.z - other.z;
            target.w = this.w - other.w;
        }
        else {
            target.x = this.x - other;
            target.y = this.y - other;
            target.z = this.z - other;
            target.w = this.w - other;
        }

        return target;
    }

    /** **/
    public reverse_subtract(other: Vec4 | number, write_to?: Vec4) : Vec4 {
        const target = (write_to ?? this);

        if (other instanceof Vec4) {
            target.x = other.x - this.x;
            target.y = other.y - this.y;
            target.z = other.z - this.z;
            target.w = other.w - this.w;
        }
        else {
            target.x = other - this.x;
            target.y = other - this.y;
            target.z = other - this.z;
            target.w = other - this.w;
        }

        return target;
    }

    /** **/
    public multiply(other: Vec4 | number, write_to?: Vec4) : Vec4 {
        const target = (write_to ?? this);

        if (other instanceof Vec4) {
            target.x = this.x * other.x;
            target.y = this.y * other.y;
            target.z = this.z * other.z;
            target.w = this.w * other.w;
        }
        else {
            target.x = this.x * other;
            target.y = this.y * other;
            target.z = this.z * other;
            target.w = this.w * other;
        }

        return target;
    }

    /** **/
    public divide(other: Vec4 | number, write_to?: Vec4) : Vec4 {
        const target = (write_to ?? this);

        if (other instanceof Vec4) {
            target.x = this.x / other.x;
            target.y = this.y / other.y;
            target.z = this.z / other.z;
            target.w = this.w / other.w;
        }
        else {
            target.x = this.x / other;
            target.y = this.y / other;
            target.z = this.z / other;
            target.w = this.w / other;
        }

        return target;
    }
}

/** **/
export function Vec2Array(...xy : number[]) : Vec2[] {
    let out : Vec2[] = [];
    for (let i = 0; i < xy.length; i += 2)
        out.push(new Vec2(xy[i + 0], xy[i + 1]))

    return out
}

/** **/
export function Vec3Array(...xyz : number[]) : Vec3[] {
    let out : Vec3[] = [];
    for (let i = 0; i < xyz.length; i += 3)
        out.push(new Vec3(xyz[i + 0], xyz[i + 1], xyz[i + 2]))

    return out
}

/** **/
export function Vec4Array(...xyzw : number[]) : Vec4[] {
    let out : Vec4[] = [];
    for (let i = 0; i < xyzw.length; i += 4)
        out.push(new Vec4(xyzw[i + 0], xyzw[i + 1], xyzw[i + 2], xyzw[i + 3]))

    return out
}