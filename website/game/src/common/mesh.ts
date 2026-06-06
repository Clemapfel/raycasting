import type { GLContext } from "./gl_context.ts";
import { MeshVertexFormat, MESH_VERTEX_FORMAT_TO_N_COMPONENTS } from "./mesh_vertex_format.ts";
import { Shader, DEFAULT_TEXTURE_UNIFORM_NAME } from "./shader.ts";
import { RGBA } from "./color.ts";
import { Vec2 } from "./vector.ts";

export enum MeshDrawMode {
    POINTS,
    LINES,
    LINE_LOOP,
    LINE_STRIP,
    TRIANGLES,
    TRIANGLE_STRIP,
    TRIANGLE_FAN
}

const initialized_contexts = new Set<GLContext>();

export class Mesh {
    private context: GLContext;

    private vertex_buffer: Float32Array;
    private vertex_buffer_object: WebGLBuffer | null = null;
    private vertex_array_object: WebGLVertexArrayObject | null = null;

    private index_buffer: Uint16Array;
    private index_buffer_object: WebGLBuffer | null = null;

    private draw_mode: number;
    private format: MeshVertexFormat;
    private n_vertices: number = 0;

    static context_to_default_shader = new Map<GLContext, Shader>();

    constructor(
        context: GLContext,
        vertex_buffer: Float32Array,
        index_buffer?: Uint16Array,
        draw_mode: MeshDrawMode = MeshDrawMode.TRIANGLE_FAN,
        format: MeshVertexFormat = MeshVertexFormat.XY_UV_RGBA
    ) {
        this.context = context;
        this.format = format;

        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (draw_mode == MeshDrawMode.POINTS)
            this.draw_mode = gl.POINTS;
        else if (draw_mode == MeshDrawMode.LINES)
            this.draw_mode = gl.LINES;
        else if (draw_mode == MeshDrawMode.LINE_LOOP)
            this.draw_mode = gl.LINE_LOOP;
        else if (draw_mode == MeshDrawMode.LINE_STRIP)
            this.draw_mode = gl.LINE_STRIP;
        else if (draw_mode == MeshDrawMode.TRIANGLES)
            this.draw_mode = gl.TRIANGLES;
        else if (draw_mode == MeshDrawMode.TRIANGLE_STRIP)
            this.draw_mode = gl.TRIANGLE_STRIP;
        else if (draw_mode == MeshDrawMode.TRIANGLE_FAN)
            this.draw_mode = gl.TRIANGLE_FAN;
        else
            this.draw_mode = gl.TRIANGLES;

        // add event listeners for static member if not already present
        if (!Mesh.context_to_default_shader.has(this.context)) {
            Mesh.context_to_default_shader.set(this.context, new Shader(this.context));

            gl.canvas.addEventListener("webglcontextlost", () => {
                Mesh.context_to_default_shader.delete(this.context);
            })

            gl.canvas.addEventListener("webglcontextrestored", () => {
                Mesh.context_to_default_shader.set(this.context, new Shader(this.context));
            });
        }

        this.replaceData(vertex_buffer, index_buffer);
    }

    public draw() {
        if (!this.context.isValid() || this.vertex_array_object === undefined) return;
        const { gl } = this.context;

        const default_shader = gl.getParameter(gl.CURRENT_PROGRAM) === null
            ? Mesh.context_to_default_shader.get(this.context)
            : undefined;

        if (default_shader !== undefined) default_shader.bind();

        if (gl.getParameter(gl.CURRENT_PROGRAM) === null) throw new Error("trace point");

        gl.bindVertexArray(this.vertex_array_object);
        gl.drawElements(this.draw_mode, this.index_buffer.length, gl.UNSIGNED_SHORT, 0);
        gl.bindVertexArray(null);

        if (default_shader !== undefined) default_shader.unbind();
    }

    public replaceData(vertex_buffer: Float32Array, index_buffer?: Uint16Array) {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        try {

            const n_components = MESH_VERTEX_FORMAT_TO_N_COMPONENTS[this.format];

            if (vertex_buffer.length === 0 || vertex_buffer.length % n_components !== 0)
                throw new Error(`In Mesh: vertex buffer length is not a multiple of ${n_components} for the given format`);

            const n_vertices_before: number | undefined = this.n_vertices;
            const n_vertices = vertex_buffer.length / n_components;

            if (index_buffer === undefined) {
                if (n_vertices_before !== n_vertices || this.index_buffer === undefined) {
                    this.index_buffer = new Uint16Array(n_vertices);
                    for (let i = 0; i < n_vertices; i++) this.index_buffer[i] = i;
                }

                index_buffer = this.index_buffer;
            }

            this.free(); // safe noop not yet allocated

            this.vertex_buffer = vertex_buffer;
            this.index_buffer = index_buffer;
            this.n_vertices = n_vertices;

            const vao = gl.createVertexArray();
            if (vao === null) throw new Error("In Mesh.replaceData: unable to create vertex array object");
            this.vertex_array_object = vao;

            const vbo = gl.createBuffer();
            if (vbo === null) throw new Error("In Mesh.replaceData: unable to create vertex buffer object");
            this.vertex_buffer_object = vbo;

            gl.bindVertexArray(this.vertex_array_object);
            gl.bindBuffer(gl.ARRAY_BUFFER, this.vertex_buffer_object);
            gl.bufferData(gl.ARRAY_BUFFER, vertex_buffer, gl.STATIC_DRAW);

            const bytes = Float32Array.BYTES_PER_ELEMENT;
            const stride = n_components * bytes;

            gl.enableVertexAttribArray(0);
            gl.vertexAttribPointer(0, 2, gl.FLOAT, false, stride, 0);

            if (this.format === MeshVertexFormat.XY_UV_RGBA || this.format === MeshVertexFormat.XY_UV) {
                gl.enableVertexAttribArray(1);
                gl.vertexAttribPointer(1, 2, gl.FLOAT, false, stride, 2 * bytes);
            } else {
                gl.disableVertexAttribArray(1);
            }

            if (this.format === MeshVertexFormat.XY_UV_RGBA) {
                gl.enableVertexAttribArray(2);
                gl.vertexAttribPointer(2, 4, gl.FLOAT, false, stride, 4 * bytes);
            } else if (this.format === MeshVertexFormat.XY_RGBA) {
                gl.enableVertexAttribArray(2);
                gl.vertexAttribPointer(2, 4, gl.FLOAT, false, stride, 2 * bytes);
            } else {
                gl.disableVertexAttribArray(2);
            }

            const ibo = gl.createBuffer();
            if (ibo === null) throw new Error("In Mesh.replaceData: unable to create index buffer object");
            this.index_buffer_object = ibo;

            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.index_buffer_object);
            gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, this.index_buffer, gl.STATIC_DRAW);
        }
        catch (error) {
            this.free();
            throw error;
        }
        finally {
            gl.bindVertexArray(null);
            gl.bindBuffer(gl.ARRAY_BUFFER, null);
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);
        }
    }

    public free() {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (this.vertex_array_object !== null) gl.deleteVertexArray(this.vertex_array_object);
        if (this.vertex_buffer_object !== null) gl.deleteBuffer(this.vertex_buffer_object);
        if (this.index_buffer_object !== null) gl.deleteBuffer(this.index_buffer_object);

        this.vertex_array_object = null;
        this.vertex_buffer_object = null;
        this.index_buffer_object = null;
        this.n_vertices = 0;
    }

    public getVertexCount() {
        return this.n_vertices;
    }
}

const default_color : RGBA = new RGBA(1, 1, 1, 1);

/** **/
export function MeshRectangle(
    context: GLContext,
    x: number = 0,
    y: number = 0,
    width: number = 1,
    height: number = 1,
    color : RGBA = default_color
): Mesh {
    const { r, g, b, a } = default_color;
    const vertices = new Float32Array([
        x,         y,          0, 0,  r, g, b, a,
        x + width, y,          1, 0,  r, g, b, a,
        x + width, y + height, 1, 1,  r, g, b, a,
        x,         y + height, 0, 1,  r, g, b, a
    ]);

    const indices = new Uint16Array([
        0, 1, 2,
        0, 2, 3
    ])

    return new Mesh(
        context,
        vertices,
        indices,
        MeshDrawMode.TRIANGLES,
        MeshVertexFormat.XY_UV_RGBA
    );
}

/** **/
export function radius_to_n_vertices(rx: number, ry: number = rx): number {
    // cf. https://github.com/love2d/love/blob/5670df13b6980afd025cd7e7d442a24499bf86a7/src/modules/graphics/Graphics.cpp#L2419C1-L2423C2
    return Math.max(8, Math.floor(Math.sqrt(((rx + ry) / 2) * 20.0)));
}

/** **/
export function MeshEllipse(
    context: GLContext,
    center_x: number,
    center_y: number,
    rx: number,
    ry: number,
    color: RGBA = default_color,
    add_anti_aliasing: boolean = true
): Mesh {
    const rim_width = add_anti_aliasing ? 2 : 0;
    const outer_rx = rx + rim_width;
    const outer_ry = ry + rim_width;
    const n_vertices = radius_to_n_vertices(outer_rx, outer_ry);
    const { r, g, b, a } = color;

    const vertex_data = new Float32Array((1 + (n_vertices + 1) * (add_anti_aliasing ? 2 : 1)) * 8);
    const index_data = new Uint16Array(n_vertices * (add_anti_aliasing ? 9 : 3));

    let v_idx = 0;
    vertex_data[v_idx++] = center_x;
    vertex_data[v_idx++] = center_y;
    vertex_data[v_idx++] = 0.5;
    vertex_data[v_idx++] = 0.5;
    vertex_data[v_idx++] = r;
    vertex_data[v_idx++] = g;
    vertex_data[v_idx++] = b;
    vertex_data[v_idx++] = a;

    const uv_x_inner = 0.5 * (rx / outer_rx);
    const uv_y_inner = 0.5 * (ry / outer_ry);

    for (let i = 0; i <= n_vertices; i++) {
        const angle = (i / n_vertices) * 2 * Math.PI;
        const cos = Math.cos(angle);
        const sin = Math.sin(angle);
        vertex_data[v_idx++] = center_x + cos * rx;
        vertex_data[v_idx++] = center_y + sin * ry;
        vertex_data[v_idx++] = 0.5 + cos * uv_x_inner;
        vertex_data[v_idx++] = 0.5 + sin * uv_y_inner;
        vertex_data[v_idx++] = r;
        vertex_data[v_idx++] = g;
        vertex_data[v_idx++] = b;
        vertex_data[v_idx++] = a;
    }

    if (add_anti_aliasing) {
        for (let i = 0; i <= n_vertices; i++) {
            const angle = (i / n_vertices) * 2 * Math.PI;
            const cos = Math.cos(angle);
            const sin = Math.sin(angle);
            vertex_data[v_idx++] = center_x + cos * outer_rx;
            vertex_data[v_idx++] = center_y + sin * outer_ry;
            vertex_data[v_idx++] = 0.5 + cos * 0.5;
            vertex_data[v_idx++] = 0.5 + sin * 0.5;
            vertex_data[v_idx++] = r;
            vertex_data[v_idx++] = g;
            vertex_data[v_idx++] = b;
            vertex_data[v_idx++] = 0;
        }
    }

    let i_idx = 0;
    for (let i = 0; i < n_vertices; i++) {
        index_data[i_idx++] = 0;
        index_data[i_idx++] = 1 + i;
        index_data[i_idx++] = 1 + i + 1;
    }

    if (add_anti_aliasing) {
        const outer_offset = 1 + (n_vertices + 1);
        for (let i = 0; i < n_vertices; i++) {
            const i_curr = 1 + i;
            const i_next = i_curr + 1;
            const o_curr = outer_offset + i;
            const o_next = o_curr + 1;

            index_data[i_idx++] = i_curr;
            index_data[i_idx++] = o_curr;
            index_data[i_idx++] = o_next;

            index_data[i_idx++] = i_curr;
            index_data[i_idx++] = o_next;
            index_data[i_idx++] = i_next;
        }
    }

    return new Mesh(
        context,
        vertex_data,
        index_data,
        MeshDrawMode.TRIANGLES,
        MeshVertexFormat.XY_UV_RGBA
    );
}

export function MeshCircle(
    context: GLContext,
    center_x: number,
    center_y: number,
    radius: number,
    color : RGBA = default_color,
    add_anti_aliasing : boolean = true
) {
    return MeshEllipse(context, center_x, center_y, radius, radius, color)
}

export function MeshRing(
    context: GLContext,
    center_x: number,
    center_y: number,
    inner_radius: number,
    outer_radius: number,
    fill_center: boolean = false,
    inner_color: RGBA = default_color,
    outer_color: RGBA = default_color
): Mesh {
    const n_outer_vertices = radius_to_n_vertices(outer_radius, outer_radius);
    const n_vertices = 1 + (n_outer_vertices + 1) + (n_outer_vertices + 1);
    const vertex_data = new Float32Array(n_vertices * 8);

    let n_indices = n_outer_vertices * 6; // 2 triangles per segment for the ring
    if (fill_center) n_indices += n_outer_vertices * 3; // 1 triangle per segment for the center
    const index_data = new Uint16Array(n_indices);

    let idx = 0;
    const step = (2 * Math.PI) / n_outer_vertices;

    vertex_data[idx++] = center_x;
    vertex_data[idx++] = center_y;
    vertex_data[idx++] = 0.5; // u
    vertex_data[idx++] = 0.5; // v
    vertex_data[idx++] = inner_color.r; // r
    vertex_data[idx++] = inner_color.g; // g
    vertex_data[idx++] = inner_color.b; // b
    vertex_data[idx++] = inner_color.a; // a

    for (let i = 0; i <= n_outer_vertices; i++) {
        const angle = i * step;
        const cos = Math.cos(angle);
        const sin = Math.sin(angle);
        vertex_data[idx++] = center_x + cos * inner_radius;
        vertex_data[idx++] = center_y + sin * inner_radius;
        vertex_data[idx++] = 0.5 + cos * 0.5 * (inner_radius / outer_radius);
        vertex_data[idx++] = 0.5 + sin * 0.5 * (inner_radius / outer_radius);
        vertex_data[idx++] = inner_color.r;
        vertex_data[idx++] = inner_color.g;
        vertex_data[idx++] = inner_color.b;
        vertex_data[idx++] = inner_color.a;

    }

    for (let i = 0; i <= n_outer_vertices; i++) {
        const angle = i * step;
        const cos = Math.cos(angle);
        const sin = Math.sin(angle);
        vertex_data[idx++] = center_x + cos * outer_radius;
        vertex_data[idx++] = center_y + sin * outer_radius;
        vertex_data[idx++] = 0.5 + cos * 0.5;
        vertex_data[idx++] = 0.5 + sin * 0.5;
        vertex_data[idx++] = outer_color.r;
        vertex_data[idx++] = outer_color.g;
        vertex_data[idx++] = outer_color.b;
        vertex_data[idx++] = outer_color.a;

    }

    idx = 0;

    if (fill_center) {
        for (let i = 0; i < n_outer_vertices; i++) {
            const inner_curr = 1 + i;
            const inner_next = inner_curr + 1;
            index_data[idx++] = 0;
            index_data[idx++] = inner_curr;
            index_data[idx++] = inner_next;
        }
    }

    for (let i = 0; i < n_outer_vertices; i++) {
        const inner_curr = 1 + i;
        const inner_next = inner_curr + 1;
        const outer_curr = 1 + (n_outer_vertices + 1) + i;
        const outer_next = outer_curr + 1;

        index_data[idx++] = inner_curr;
        index_data[idx++] = outer_curr;
        index_data[idx++] = outer_next;

        index_data[idx++] = inner_curr;
        index_data[idx++] = outer_next;
        index_data[idx++] = inner_next;
    }

    return new Mesh(
        context,
        vertex_data,
        index_data,
        MeshDrawMode.TRIANGLES,
        MeshVertexFormat.XY_UV_RGBA
    );
}

export enum LineJoin {
    NONE,
    MITER,
    BEVEL
}

export function MeshLine(
    context: GLContext,
    points: Vec2[],
    thickness: number,
    line_join: LineJoin = LineJoin.BEVEL,
    color: RGBA = default_color,
    add_circular_endcaps: boolean = true
): Mesh {
    if (points.length < 2) {
        throw new Error("MeshLine requires at least 2 points");
    }

    const vertices: number[] = [];
    const indices: number[] = [];

    const { r, g, b, a } = color;

    const halfwidth = thickness / 2.0;
    const LINES_PARALLEL_EPS = 0.05;

    // Flat parallel arrays instead of Vec2[] — zero per-entry allocation
    const anchorX: number[] = [];
    const anchorY: number[] = [];
    const normalX: number[] = [];
    const normalY: number[] = [];

    const pushAN = (ax: number, ay: number, nx: number, ny: number) => {
        anchorX.push(ax); anchorY.push(ay);
        normalX.push(nx); normalY.push(ny);
    };

    // Scalar segment state (replaces segment Vec2 + segmentNormal Vec2)
    let sx = points[1].x - points[0].x;
    let sy = points[1].y - points[0].y;
    let segLen = Math.sqrt(sx * sx + sy * sy);

    // turn_right(-sy, sx), normalize, scale — inline getNormal
    const invLen0 = segLen > Math.EPS ? halfwidth / segLen : 0;
    let snx = -sy * invLen0;
    let sny =  sx * invLen0;

    // Takes scalars: no point clones needed at call sites
    const renderEdge = (pAx: number, pAy: number, pBx: number, pBy: number) => {
        const nsx = pBx - pAx;
        const nsy = pBy - pAy;
        const nsLen = Math.sqrt(nsx * nsx + nsy * nsy);

        if (line_join === LineJoin.NONE) {
            pushAN(pAx, pAy,  snx,  sny);
            pushAN(pAx, pAy, -snx, -sny);

            sx = nsx; sy = nsy; segLen = nsLen;
            const inv = segLen > Math.EPS ? halfwidth / segLen : 0;
            snx = -sy * inv;
            sny =  sx * inv;

            pushAN(pAx, pAy,  snx,  sny);
            pushAN(pAx, pAy, -snx, -sny);
            return;
        }

        if (nsLen <= Math.EPS) return;

        // inline getNormal for new segment
        const inv = halfwidth / nsLen;
        const nsnx = -nsy * inv;
        const nsny =  nsx * inv;

        // 2D cross & dot, all scalar
        const det = sx * nsy - sy * nsx;
        const isParallel = Math.abs(det) < LINES_PARALLEL_EPS * segLen * nsLen;
        const dotProduct = sx * nsx + sy * nsy;

        if (line_join === LineJoin.MITER) {
            if (isParallel) {
                pushAN(pAx, pAy,  snx,  sny);
                pushAN(pAx, pAy, -snx, -sny);
                if (dotProduct < 0) {
                    pushAN(pAx, pAy, -snx, -sny);
                    pushAN(pAx, pAy,  snx,  sny);
                }
            } else {
                // Cramer's rule — nDiff.cross(newSegment) / det
                const ndx = nsnx - snx;
                const ndy = nsny - sny;
                const lambda = (ndx * nsy - ndy * nsx) / det;
                const dx = snx + sx * lambda;
                const dy = sny + sy * lambda;
                pushAN(pAx, pAy,  dx,  dy);
                pushAN(pAx, pAy, -dx, -dy);
            }
        } else if (line_join === LineJoin.BEVEL) {
            if (isParallel) {
                pushAN(pAx, pAy,  snx,  sny);
                pushAN(pAx, pAy, -snx, -sny);
                if (dotProduct < 0) {
                    pushAN(pAx, pAy, -snx, -sny);
                    pushAN(pAx, pAy,  snx,  sny);
                }
            } else {
                const ndx = nsnx - snx;
                const ndy = nsny - sny;
                const lambda = (ndx * nsy - ndy * nsx) / det;
                const dx = snx + sx * lambda;
                const dy = sny + sy * lambda;

                if (det > 0) {
                    // 'Left' turn — miter corner on top
                    pushAN(pAx, pAy,   dx,    dy);
                    pushAN(pAx, pAy,  -snx,  -sny);
                    pushAN(pAx, pAy,   dx,    dy);
                    pushAN(pAx, pAy,  -nsnx, -nsny);
                } else {
                    // 'Right' turn — miter corner on bottom
                    pushAN(pAx, pAy,  snx,  sny);
                    pushAN(pAx, pAy, -dx,  -dy);
                    pushAN(pAx, pAy,  nsnx, nsny);
                    pushAN(pAx, pAy, -dx,  -dy);
                }
            }
        }

        sx = nsx; sy = nsy; segLen = nsLen;
        snx = nsnx; sny = nsny;
    };

    for (let i = 0; i + 1 < points.length; i++) {
        renderEdge(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y);
    }

    // Virtual closing point extends in the final segment direction
    const last = points[points.length - 1];
    renderEdge(last.x, last.y, last.x + sx, last.y + sy);

    const vertex_count = anchorX.length;

    const addVertex = (x: number, y: number): number => {
        const idx = vertices.length / 8;
        vertices.push(x, y, 0.0, 0.0, r, g, b, a);
        return idx;
    };

    for (let i = 0; i < vertex_count; i++) {
        addVertex(anchorX[i] + normalX[i], anchorY[i] + normalY[i]);
    }

    for (let i = 0; i < vertex_count - 2; i++) {
        if (i % 2 === 0) {
            indices.push(i, i + 1, i + 2);
        } else {
            indices.push(i + 1, i, i + 2);
        }
    }

    if (add_circular_endcaps && halfwidth > Math.EPS) {
        const CAP_SEGMENTS = 16;

        // Start cap — atan2 on stored scalars, no Vec2.angle() needed
        const scx = points[0].x;
        const scy = points[0].y;
        const startAngle = Math.atan2(normalY[0], normalX[0]);
        const centerStartIdx = addVertex(scx, scy);

        let prevIdx = 0;
        for (let i = 1; i <= CAP_SEGMENTS; i++) {
            let currentIdx: number;
            if (i === CAP_SEGMENTS) {
                currentIdx = 1;
            } else {
                const angle = startAngle + (i / CAP_SEGMENTS) * Math.PI;
                currentIdx = addVertex(
                    scx + Math.cos(angle) * halfwidth,
                    scy + Math.sin(angle) * halfwidth
                );
            }
            indices.push(centerStartIdx, prevIdx, currentIdx);
            prevIdx = currentIdx;
        }

        // End cap
        const ecx = last.x;
        const ecy = last.y;
        const endAngle = Math.atan2(normalY[normalY.length - 2], normalX[normalX.length - 2]);
        const centerEndIdx = addVertex(ecx, ecy);
        const endStartAngle = endAngle - Math.PI;

        let prevIdxEnd = vertex_count - 1;
        for (let i = 1; i <= CAP_SEGMENTS; i++) {
            let currentIdx: number;
            if (i === CAP_SEGMENTS) {
                currentIdx = vertex_count - 2;
            } else {
                const angle = endStartAngle + (i / CAP_SEGMENTS) * Math.PI;
                currentIdx = addVertex(
                    ecx + Math.cos(angle) * halfwidth,
                    ecy + Math.sin(angle) * halfwidth
                );
            }
            indices.push(centerEndIdx, prevIdxEnd, currentIdx);
            prevIdxEnd = currentIdx;
        }
    }

    return new Mesh(
        context,
        new Float32Array(vertices),
        new Uint16Array(indices),
        MeshDrawMode.TRIANGLES,
        MeshVertexFormat.XY_UV_RGBA
    );
}
