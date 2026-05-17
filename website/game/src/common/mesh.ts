import type { GLContext } from "./gl_context.ts";
import { MeshVertexFormat, MESH_VERTEX_FORMAT_TO_N_COMPONENTS } from "./mesh_vertex_format.ts";
import { Shader, DEFAULT_TEXTURE_UNIFORM_NAME } from "./shader.ts";

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
    private vertex_buffer_object?: WebGLBuffer;
    private vertex_array_object?: WebGLVertexArrayObject;

    private index_buffer: Uint16Array;
    private index_buffer_object?: WebGLBuffer;

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

        const n_components = MESH_VERTEX_FORMAT_TO_N_COMPONENTS[this.format];

        if (vertex_buffer.length === 0 || vertex_buffer.length % n_components !== 0)
            throw new Error(`In Mesh: vertex buffer length is not a multiple of ${n_components} for the given format`);

        const n_vertices_before : number | undefined = this.n_vertices;
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

        gl.bindVertexArray(null);
        gl.bindBuffer(gl.ARRAY_BUFFER, null);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);
    }

    public free() {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (this.vertex_array_object !== undefined) gl.deleteVertexArray(this.vertex_array_object);
        if (this.vertex_buffer_object !== undefined) gl.deleteBuffer(this.vertex_buffer_object);
        if (this.index_buffer_object !== undefined) gl.deleteBuffer(this.index_buffer_object);

        this.vertex_array_object = undefined;
        this.vertex_buffer_object = undefined;
        this.index_buffer_object = undefined;
        this.n_vertices = 0;
    }
}

/** **/
export function MeshRectangle(
    context: GLContext,
    x: number = 0,
    y: number = 0,
    width: number = 1,
    height: number = 1
): Mesh {
    const vertices = new Float32Array([
        x,         y,          0, 0,  1, 1, 1, 1,
        x + width, y,          1, 0,  1, 1, 1, 1,
        x + width, y + height, 1, 1,  1, 1, 1, 1,
        x,         y + height, 0, 1,  1, 1, 1, 1,
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
export function MeshCircle(
    context: GLContext,
    center_x: number,
    center_y: number,
    x_radius: number,
    y_radius: number = x_radius,
    n_outer_vertices: number = radius_to_n_vertices(x_radius, y_radius)
): Mesh {
    const vertexData = new Float32Array((n_outer_vertices + 2) * 8); // xy uv rgba
    const indices = new Uint16Array(n_outer_vertices * 3);

    {
        let idx = 0;

        // center, index 0
        vertexData[idx++] = center_x;
        vertexData[idx++] = center_y;
        vertexData[idx++] = 0.5;
        vertexData[idx++] = 0.5;
        vertexData[idx++] = 1;
        vertexData[idx++] = 1;
        vertexData[idx++] = 1;
        vertexData[idx++] = 1;

        const step = (2 * Math.PI) / n_outer_vertices;
        for (let angle = 0; angle <= 2 * Math.PI; angle += step) {
            vertexData[idx++] = center_x + Math.cos(angle) * x_radius;
            vertexData[idx++] = center_y + Math.sin(angle) * y_radius;
            vertexData[idx++] = 0.5 + Math.cos(angle) * 0.5;
            vertexData[idx++] = 0.5 + Math.sin(angle) * 0.5;
            vertexData[idx++] = 1;
            vertexData[idx++] = 1;
            vertexData[idx++] = 1;
            vertexData[idx++] = 1;
        }
    }

    {
        let idx = 0;
        for (let outer_i = 2; outer_i <= n_outer_vertices; outer_i++) {
            indices[idx++] = 0;
            indices[idx++] = outer_i - 1;
            indices[idx++] = outer_i;
        }

        // connect last and first
        indices[idx++] = n_outer_vertices;
        indices[idx++] = 0;
        indices[idx++] = 1;
    }

    return new Mesh(
        context,
        new Float32Array(vertexData),
        indices,
        MeshDrawMode.TRIANGLES,
        MeshVertexFormat.XY_UV_RGBA
    );
}