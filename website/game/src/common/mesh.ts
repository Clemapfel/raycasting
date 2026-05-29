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
function radius_to_n_vertices(rx: number, ry: number = rx): number {
    // cf. https://github.com/love2d/love/blob/5670df13b6980afd025cd7e7d442a24499bf86a7/src/modules/graphics/Graphics.cpp#L2419C1-L2423C2
    return Math.max(8, Math.floor(Math.sqrt(((rx + ry) / 2) * 20.0)));
}

/** **/
export function MeshEllipse(
    context: GLContext,
    center_x: number,
    center_y: number,
    x_radius: number,
    y_radius: number = x_radius,
    color : RGBA = default_color
): Mesh {
    const n_outer_vertices = radius_to_n_vertices(x_radius, y_radius);
    const vertex_data = new Float32Array((1 + n_outer_vertices + 1) * (2 + 2 + 4));
    const index_data = new Uint16Array((n_outer_vertices + 1) * 3)
    const { r, g, b, a } = default_color;

    let idx = 0;

    vertex_data[idx++] = center_x;
    vertex_data[idx++] = center_y;
    vertex_data[idx++] = 0.5; // u
    vertex_data[idx++] = 0.5; // v
    vertex_data[idx++] = r;
    vertex_data[idx++] = g;
    vertex_data[idx++] = b;
    vertex_data[idx++] = a;

    for (let i = 0; i <= n_outer_vertices; ++i) {
        const angle = i / n_outer_vertices * 2 * Math.PI;
        vertex_data[idx++] = center_x + x_radius * Math.cos(angle);
        vertex_data[idx++] = center_y + y_radius * Math.sin(angle);
        vertex_data[idx++] = 0.5 + Math.cos(angle) / 2;
        vertex_data[idx++] = 0.5 + Math.sin(angle) / 2;
        vertex_data[idx++] = r;
        vertex_data[idx++] = g;
        vertex_data[idx++] = b;
        vertex_data[idx++] = a;
    }

    idx = 0;

    for (let outer_i = 1; outer_i <= n_outer_vertices; outer_i++) {
        index_data[idx++] = 0;
        index_data[idx++] = outer_i - 1;
        index_data[idx++] = outer_i;
    }

    index_data[idx++] = n_outer_vertices;
    index_data[idx++] = 0;
    index_data[idx++] = 1;

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
    color : RGBA = default_color
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

export function MeshLine(
    context: GLContext,
    points: Vec2[],
    thickness: number,
    add_end_cap: boolean = false,
    color: RGBA = default_color
): Mesh {
    if (points.length < 2) {
        throw new Error("MeshLine requires at least 2 points");
    }

    const vertices: number[] = [];
    const indices: number[] = [];

    const r = color.r;
    const g = color.g;
    const b = color.b;
    const a = color.a;

    // Helper to add a vertex and return its index
    function addVertex(v: Vec2, uv: Vec2): number {
        vertices.push(v.x, v.y, uv.x, uv.y, r, g, b, a);
        return (vertices.length / 8) - 1;
    }

    let current_S_L_index = -1;
    let current_S_R_index = -1;

    const half_t = thickness / 2;

    for (let i = 0; i < points.length; i++) {
        const P = points[i];

        if (i === 0) {
            // First point: just setup the initial segment start
            const D = points[1].subtract(points[0]).normalize();
            const N = D.turn_left();
            const S_L = P.add(N.multiply(half_t));
            const S_R = P.subtract(N.multiply(half_t));

            current_S_L_index = addVertex(S_L, new Vec2(0, 0));
            current_S_R_index = addVertex(S_R, new Vec2(1, 0));

            // Start Cap
            if (add_end_cap) {
                const start_angle = N.angle();
                const center_idx = addVertex(P, new Vec2(0.5, 0));
                let prev_idx = current_S_L_index;

                // Determine segments based on thickness, min 8
                const num_segs = Math.max(8, Math.floor(Math.sqrt(half_t * 20.0)));
                for (let j = 1; j <= num_segs; j++) {
                    const t = j / num_segs;
                    // Sweep CCW from Left (N) to Right (-N) around the back
                    const angle = start_angle + t * Math.PI;
                    const v_dir = new Vec2(Math.cos(angle), Math.sin(angle));
                    const pt = P.add(v_dir.multiply(half_t));

                    const pt_idx = (j === num_segs) ? current_S_R_index : addVertex(pt, new Vec2(0, 0));
                    indices.push(center_idx, prev_idx, pt_idx); // CCW
                    prev_idx = pt_idx;
                }
            }
        } else if (i === points.length - 1) {
            // Last point: close out the final segment
            const D = points[i].subtract(points[i - 1]).normalize();
            const N = D.turn_left();
            const E_L = P.add(N.multiply(half_t));
            const E_R = P.subtract(N.multiply(half_t));

            const E_L_index = addVertex(E_L, new Vec2(0, 1));
            const E_R_index = addVertex(E_R, new Vec2(1, 1));

            // Final segment quad
            indices.push(current_S_L_index, current_S_R_index, E_R_index);
            indices.push(current_S_L_index, E_R_index, E_L_index);

            // End Cap
            if (add_end_cap) {
                const start_angle = N.angle() + Math.PI; // Start from Right (-N)
                const center_idx = addVertex(P, new Vec2(0.5, 1));
                let prev_idx = E_R_index;

                const num_segs = Math.max(8, Math.floor(Math.sqrt(half_t * 20.0)));
                for (let j = 1; j <= num_segs; j++) {
                    const t = j / num_segs;
                    // Sweep CCW from Right (-N) to Left (N) around the front
                    const angle = start_angle + t * Math.PI;
                    const v_dir = new Vec2(Math.cos(angle), Math.sin(angle));
                    const pt = P.add(v_dir.multiply(half_t));

                    const pt_idx = (j === num_segs) ? E_L_index : addVertex(pt, new Vec2(0, 1));
                    indices.push(center_idx, prev_idx, pt_idx); // CCW
                    prev_idx = pt_idx;
                }
            }
        } else {
            // Joint processing
            const D_in = points[i].subtract(points[i - 1]).normalize();
            const D_out = points[i + 1].subtract(points[i]).normalize();
            const N_in = D_in.turn_left();
            const N_out = D_out.turn_left();

            const cross = D_in.cross(D_out);
            const dot = D_in.dot(D_out);

            // Collinear forward path (no bevel needed)
            if (Math.abs(cross) < Math.EPS && dot > 0) {
                const L = P.add(N_in.multiply(half_t));
                const R = P.subtract(N_in.multiply(half_t));
                const L_idx = addVertex(L, new Vec2(0, 0.5));
                const R_idx = addVertex(R, new Vec2(1, 0.5));

                indices.push(current_S_L_index, current_S_R_index, R_idx);
                indices.push(current_S_L_index, R_idx, L_idx);

                current_S_L_index = L_idx;
                current_S_R_index = R_idx;
            } else {
                // Determine joint angles and miter point
                const T = D_in.add(D_out).normalize();
                const M = T.turn_left(); // Miter direction

                let miter_dot = M.dot(N_in);
                // Prevent division by zero for exactly 180 degree turns
                if (Math.abs(miter_dot) < Math.EPS) miter_dot = Math.EPS;

                // Limit the miter length to prevent extreme spikes on sharp turns
                const m_len = Math.min(1.0 / miter_dot, 10.0);
                const V_miter = M.multiply(m_len * half_t);

                if (cross > 0) {
                    // LEFT TURN (Inner side is Left, Outer side is Right)
                    const V_inner = P.add(V_miter);
                    const V_outer_in = P.subtract(N_in.multiply(half_t));
                    const V_outer_out = P.subtract(N_out.multiply(half_t));

                    const inner_idx = addVertex(V_inner, new Vec2(0, 0.5));
                    const outer_in_idx = addVertex(V_outer_in, new Vec2(1, 0.5));
                    const outer_out_idx = addVertex(V_outer_out, new Vec2(1, 0.5));

                    // Quad for incoming segment (i - 1)
                    indices.push(current_S_L_index, current_S_R_index, outer_in_idx);
                    indices.push(current_S_L_index, outer_in_idx, inner_idx);

                    // Corner Bevel Triangle (CCW)
                    indices.push(inner_idx, outer_in_idx, outer_out_idx);

                    // Setup left and right indices for outgoing segment (i)
                    current_S_L_index = inner_idx;
                    current_S_R_index = outer_out_idx;
                } else {
                    // RIGHT TURN (Inner side is Right, Outer side is Left)
                    const V_inner = P.subtract(V_miter);
                    const V_outer_in = P.add(N_in.multiply(half_t));
                    const V_outer_out = P.add(N_out.multiply(half_t));

                    const inner_idx = addVertex(V_inner, new Vec2(1, 0.5));
                    const outer_in_idx = addVertex(V_outer_in, new Vec2(0, 0.5));
                    const outer_out_idx = addVertex(V_outer_out, new Vec2(0, 0.5));

                    // Quad for incoming segment (i - 1)
                    indices.push(current_S_L_index, current_S_R_index, inner_idx);
                    indices.push(current_S_L_index, inner_idx, outer_in_idx);

                    // Corner Bevel Triangle (CCW)
                    indices.push(inner_idx, outer_out_idx, outer_in_idx);

                    // Setup left and right indices for outgoing segment (i)
                    current_S_L_index = outer_out_idx;
                    current_S_R_index = inner_idx;
                }
            }
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