import { Vec2, Vec3 } from "./vector.ts";

/** **/
export class Transform {
    private data: Float32Array;

    /** **/
    constructor(data?: Float32Array) {
        this.data = data ?? new Float32Array([
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        ]);
    }

    /** **/
    public setData(data: Float32Array) : Transform {
        if (data.length != 4 * 4)
            throw new Error("In Transform.set: data does not have 16 entries")

        this.data = data;
        return this;
    }

    /** **/
    public getData() : Float32Array {
        return this.data;
    }

    /** **/
    public clone() : Transform {
        return new Transform(this.data)
    }

    /** **/
    public apply<T extends Vec2 | Vec3 | Transform>(other: T, write_to?: T): T {
        if (other instanceof Vec2)
            return this.multiply_vec2(other, write_to as Vec2) as T;
        else if (other instanceof Vec3)
            return this.multiply_vec3(other, write_to as Vec3) as T;
        else
            return this.multiply_transform(other as Transform, write_to as Transform) as T;
    }

    /** **/
    public translate(x: number, y: number, z: number = 0): Transform {
        const e = this.data;
        e[12] += e[0] * x + e[4] * y + e[8]  * z;
        e[13] += e[1] * x + e[5] * y + e[9]  * z;
        e[14] += e[2] * x + e[6] * y + e[10] * z;
        e[15] += e[3] * x + e[7] * y + e[11] * z;
        return this;
    }

    /** **/
    public scale(x: number, y?: number, z: number = 1): Transform {
        if (y === undefined) y = x;

        const e = this.data;
        e[0]  *= x; e[1]  *= x; e[2]  *= x; e[3]  *= x;
        e[4]  *= y; e[5]  *= y; e[6]  *= y; e[7]  *= y;
        e[8]  *= z; e[9]  *= z; e[10] *= z; e[11] *= z;
        return this;
    }

    /** **/
    public rotate(angle: number): Transform {
        const c = Math.cos(angle);
        const s = Math.sin(angle);
        const e = this.data;
        const column_0_x = e[0], column_0_y = e[1], column_0_z = e[2], column_0_w = e[3];
        const column_1_x = e[4], column_1_y = e[5], column_1_z = e[6], column_1_w = e[7];
        e[0] = c * column_0_x + s * column_1_x;
        e[1] = c * column_0_y + s * column_1_y;
        e[2] = c * column_0_z + s * column_1_z;
        e[3] = c * column_0_w + s * column_1_w;
        e[4] = -s * column_0_x + c * column_1_x;
        e[5] = -s * column_0_y + c * column_1_y;
        e[6] = -s * column_0_z + c * column_1_z;
        e[7] = -s * column_0_w + c * column_1_w;
        return this;
    }

    /** **/
    public transpose(write_to?: Transform): Transform {
        const e = this.data;
        const target = write_to ?? new Transform();
        target.data.set([
            e[0], e[4], e[8],  e[12],
            e[1], e[5], e[9],  e[13],
            e[2], e[6], e[10], e[14],
            e[3], e[7], e[11], e[15],
        ]);
        return target;
    }

    /** **/
    public asIdentity(): Transform {
        this.data.set([
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ]);

        return this;
    }

    /** **/
    public asPerspectiveProjection(fov: number, aspect: number, near: number, far: number): Transform {
        const top    =  near * Math.tan(fov / 2);
        const bottom = -top;
        const right  =  top * aspect;
        const left   = -right;
        this.data.set([
            2 * near / (right - left), 0, 0, 0,
            0, 2 * near / (bottom - top), 0, 0,
            0, 0, -(far + near) / (far - near), -1,
            0, 0, -2 * far * near / (far - near), 0
        ]);
        return this;
    }

    /** **/
    public asOrthographicProjection(width: number, height: number, near: number, far: number): Transform {
        const right  =  width  / 2;
        const left   = -right;
        const top    = -height / 2;  // y-down: top is negative
        const bottom =  height / 2;
        this.data.set([
            2 / (right - left), 0, 0, 0,
            0, 2 / (top - bottom), 0, 0,
            0, 0, -2 / (far - near), 0,
            -((right + left) / (right - left)), -((top + bottom) / (top - bottom)), -((far + near) / (far - near)), 1,
        ]);
        return this;
    }

    /** **/
    public inverse(write_to?: Transform): Transform {
        const e = this.data;
        const target = (write_to ?? new Transform());
        const t = new Float32Array(16);

        t[0]  =  e[5]*e[10]*e[15] - e[5]*e[11]*e[14] - e[9]*e[6]*e[15]  + e[9]*e[7]*e[14]  + e[13]*e[6]*e[11]  - e[13]*e[7]*e[10];
        t[4]  = -e[4]*e[10]*e[15] + e[4]*e[11]*e[14] + e[8]*e[6]*e[15]  - e[8]*e[7]*e[14]  - e[12]*e[6]*e[11]  + e[12]*e[7]*e[10];
        t[8]  =  e[4]*e[9]*e[15]  - e[4]*e[11]*e[13] - e[8]*e[5]*e[15]  + e[8]*e[7]*e[13]  + e[12]*e[5]*e[11]  - e[12]*e[7]*e[9];
        t[12] = -e[4]*e[9]*e[14]  + e[4]*e[10]*e[13] + e[8]*e[5]*e[14]  - e[8]*e[6]*e[13]  - e[12]*e[5]*e[10]  + e[12]*e[6]*e[9];
        t[1]  = -e[1]*e[10]*e[15] + e[1]*e[11]*e[14] + e[9]*e[2]*e[15]  - e[9]*e[3]*e[14]  - e[13]*e[2]*e[11]  + e[13]*e[3]*e[10];
        t[5]  =  e[0]*e[10]*e[15] - e[0]*e[11]*e[14] - e[8]*e[2]*e[15]  + e[8]*e[3]*e[14]  + e[12]*e[2]*e[11]  - e[12]*e[3]*e[10];
        t[9]  = -e[0]*e[9]*e[15]  + e[0]*e[11]*e[13] + e[8]*e[1]*e[15]  - e[8]*e[3]*e[13]  - e[12]*e[1]*e[11]  + e[12]*e[3]*e[9];
        t[13] =  e[0]*e[9]*e[14]  - e[0]*e[10]*e[13] - e[8]*e[1]*e[14]  + e[8]*e[2]*e[13]  + e[12]*e[1]*e[10]  - e[12]*e[2]*e[9];
        t[2]  =  e[1]*e[6]*e[15]  - e[1]*e[7]*e[14]  - e[5]*e[2]*e[15]  + e[5]*e[3]*e[14]  + e[13]*e[2]*e[7]   - e[13]*e[3]*e[6];
        t[6]  = -e[0]*e[6]*e[15]  + e[0]*e[7]*e[14]  + e[4]*e[2]*e[15]  - e[4]*e[3]*e[14]  - e[12]*e[2]*e[7]   + e[12]*e[3]*e[6];
        t[10] =  e[0]*e[5]*e[15]  - e[0]*e[7]*e[13]  - e[4]*e[1]*e[15]  + e[4]*e[3]*e[13]  + e[12]*e[1]*e[7]   - e[12]*e[3]*e[5];
        t[14] = -e[0]*e[5]*e[14]  + e[0]*e[6]*e[13]  + e[4]*e[1]*e[14]  - e[4]*e[2]*e[13]  - e[12]*e[1]*e[6]   + e[12]*e[2]*e[5];
        t[3]  = -e[1]*e[6]*e[11]  + e[1]*e[7]*e[10]  + e[5]*e[2]*e[11]  - e[5]*e[3]*e[10]  - e[9]*e[2]*e[7]    + e[9]*e[3]*e[6];
        t[7]  =  e[0]*e[6]*e[11]  - e[0]*e[7]*e[10]  - e[4]*e[2]*e[11]  + e[4]*e[3]*e[10]  + e[8]*e[2]*e[7]    - e[8]*e[3]*e[6];
        t[11] = -e[0]*e[5]*e[11]  + e[0]*e[7]*e[9]   + e[4]*e[1]*e[11]  - e[4]*e[3]*e[9]   - e[8]*e[1]*e[7]    + e[8]*e[3]*e[5];
        t[15] =  e[0]*e[5]*e[10]  - e[0]*e[6]*e[9]   - e[4]*e[1]*e[10]  + e[4]*e[2]*e[9]   + e[8]*e[1]*e[6]    - e[8]*e[2]*e[5];

        const inverse_determinant = 1.0 / (e[0]*t[0] + e[1]*t[4] + e[2]*t[8] + e[3]*t[12]);
        for (let i = 0; i < 16; i++) t[i] *= inverse_determinant;

        target.setData(t);
        return target;
    }

    // ### internal ###

    private multiply_transform(other: Transform, write_to?: Transform): Transform {
        const a = this.data;
        const b = other.data;
        const t = new Float32Array(16);

        t[0]  = a[0]*b[0]  + a[4]*b[1]  + a[8]*b[2]  + a[12]*b[3];
        t[4]  = a[0]*b[4]  + a[4]*b[5]  + a[8]*b[6]  + a[12]*b[7];
        t[8]  = a[0]*b[8]  + a[4]*b[9]  + a[8]*b[10] + a[12]*b[11];
        t[12] = a[0]*b[12] + a[4]*b[13] + a[8]*b[14] + a[12]*b[15];
        t[1]  = a[1]*b[0]  + a[5]*b[1]  + a[9]*b[2]  + a[13]*b[3];
        t[5]  = a[1]*b[4]  + a[5]*b[5]  + a[9]*b[6]  + a[13]*b[7];
        t[9]  = a[1]*b[8]  + a[5]*b[9]  + a[9]*b[10] + a[13]*b[11];
        t[13] = a[1]*b[12] + a[5]*b[13] + a[9]*b[14] + a[13]*b[15];
        t[2]  = a[2]*b[0]  + a[6]*b[1]  + a[10]*b[2] + a[14]*b[3];
        t[6]  = a[2]*b[4]  + a[6]*b[5]  + a[10]*b[6] + a[14]*b[7];
        t[10] = a[2]*b[8]  + a[6]*b[9]  + a[10]*b[10]+ a[14]*b[11];
        t[14] = a[2]*b[12] + a[6]*b[13] + a[10]*b[14]+ a[14]*b[15];
        t[3]  = a[3]*b[0]  + a[7]*b[1]  + a[11]*b[2] + a[15]*b[3];
        t[7]  = a[3]*b[4]  + a[7]*b[5]  + a[11]*b[6] + a[15]*b[7];
        t[11] = a[3]*b[8]  + a[7]*b[9]  + a[11]*b[10]+ a[15]*b[11];
        t[15] = a[3]*b[12] + a[7]*b[13] + a[11]*b[14]+ a[15]*b[15];

        if (write_to === undefined)
            return new Transform(t);
        else
            return write_to.setData(t);
    }

    private multiply_vec2(vector: Vec2, write_to?: Vec2): Vec2 {
        const e = this.data;
        const target = write_to ?? vector;
        const previous_x = vector.x;
        const previous_y = vector.y;
        target.x = e[0] * previous_x + e[4] * previous_y + e[12];
        target.y = e[1] * previous_x + e[5] * previous_y + e[13];
        return target;
    }

    private multiply_vec3(vector : Vec3, write_to: Vec3): Vec3 {
        const e = this.data;
        const target = write_to ?? new Vec3();
        const previous_x = vector.x;
        const previous_y = vector.y;
        const previous_z = vector.z;

        target.x = e[0] * previous_x + e[4] * previous_y + e[8] * previous_z + e[12];
        target.y = e[1] * previous_x + e[5] * previous_y + e[9] * previous_z + e[13];
        target.z = e[2] * previous_x + e[6] * previous_y + e[10] * previous_z + e[14];

        // perspective divide
        const w = e[3] * previous_x + e[7] * previous_y + e[11] * previous_z + e[15];
        if (w !== 1.0 && w !== 0.0) {
            target.x /= w;
            target.y /= w;
            target.z /= w;
        }

        return target;
    }
}