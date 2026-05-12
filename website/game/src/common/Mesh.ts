import type { GLContext } from "./GLContext.ts";
import type { Texture } from "./Texture.ts";
import { type Shader, default_texture_uniform_name } from "./Shader.ts";

const n_vertex_buffer_elements = 8; // x y u v r g b a
const vertex_buffer_stride = n_vertex_buffer_elements * Float32Array.BYTES_PER_ELEMENT;

/** **/
export enum MeshDrawMode {
    POINTS,
    LINES,
    LINE_LOOP,
    LINE_STRIP,
    TRIANGLES,
    TRIANGLE_STRIP,
    TRIANGLE_FAN
}

/** **/
export class Mesh {
    private context : GLContext;

    private vertex_buffer : Float32Array;
    private vertex_buffer_object : WebGLBuffer;
    private vertex_array_object : WebGLVertexArrayObject;

    private index_buffer : Uint16Array;
    private index_buffer_object : WebGLBuffer;

    private draw_mode : number;
    private n_vertices : number;

    /** **/
    constructor(
        context : GLContext,
        vertex_buffer : Float32Array,
        index_buffer? : Uint16Array,
        draw_mode? : MeshDrawMode
    ) {
        this.context = context;

        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (draw_mode == undefined) draw_mode = MeshDrawMode.TRIANGLE_FAN;

        // Map enum to GL constants
        const modeMap: Record<number, number> = {
            [MeshDrawMode.POINTS]: gl.POINTS,
            [MeshDrawMode.LINES]: gl.LINES,
            [MeshDrawMode.LINE_LOOP]: gl.LINE_LOOP,
            [MeshDrawMode.LINE_STRIP]: gl.LINE_STRIP,
            [MeshDrawMode.TRIANGLES]: gl.TRIANGLES,
            [MeshDrawMode.TRIANGLE_STRIP]: gl.TRIANGLE_STRIP,
            [MeshDrawMode.TRIANGLE_FAN]: gl.TRIANGLE_FAN,
        };

        this.draw_mode = modeMap[draw_mode] ?? gl.TRIANGLES;

        this.replaceData(vertex_buffer, index_buffer);
    }

    /**
     * Renders the mesh using the provided shader and optional texture.
     **/
    public draw() {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        gl.bindVertexArray(this.vertex_array_object);

        if (this.index_buffer)
            gl.drawElements(this.draw_mode, this.index_buffer.length, gl.UNSIGNED_SHORT, 0);
        else
            gl.drawArrays(this.draw_mode, 0, this.n_vertices);

        gl.bindVertexArray(null);
    }

    /** **/
    public replaceData(vertex_buffer : Float32Array, index_buffer? : Uint16Array) {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        this.free();
        this.vertex_buffer = vertex_buffer;

        if (vertex_buffer.length == 0 || vertex_buffer.length % n_vertex_buffer_elements != 0)
            throw new Error("In Mesh: number of components in vertex buffer is not a multiple of 8 (xy uv rgba)")

        this.n_vertices = vertex_buffer.length / n_vertex_buffer_elements;

        const vao = gl.createVertexArray();
        if (vao === null) throw new Error("In Mesh.replaceData: unable to create vertex array object")
        this.vertex_array_object = vao;

        const vbo = gl.createBuffer();
        if (vbo === null) throw new Error("In Mesh.replaceData: unable to create vertex buffer object")
        this.vertex_buffer_object = vbo;

        gl.bindVertexArray(this.vertex_array_object);
        gl.bindBuffer(gl.ARRAY_BUFFER, this.vertex_buffer_object);
        gl.bufferData(gl.ARRAY_BUFFER, vertex_buffer, gl.STATIC_DRAW);

        const bytes = Float32Array.BYTES_PER_ELEMENT;
        const is_normalized = false;

        gl.enableVertexAttribArray(0); // position (x, y)
        gl.vertexAttribPointer(0, 2, gl.FLOAT, is_normalized, vertex_buffer_stride, 0);

        gl.enableVertexAttribArray(1); // uv (u, v)
        gl.vertexAttribPointer(1, 2, gl.FLOAT, is_normalized, vertex_buffer_stride, 2 * bytes);

        gl.enableVertexAttribArray(2); // color (r, g, b, a)
        gl.vertexAttribPointer(2, 4, gl.FLOAT, is_normalized, vertex_buffer_stride, 4 * bytes);

        if (!index_buffer) {
            index_buffer = new Uint16Array(this.n_vertices);
            for (let i = 0; i < this.n_vertices; i++) {
                index_buffer[i] = i;
            }
        }
        this.index_buffer = index_buffer;

        const ibo = gl.createBuffer();
        if (ibo === null) throw new Error("In mesh.replaceData: unable to create index buffer object")
        this.index_buffer_object = ibo;

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.index_buffer_object);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, index_buffer, gl.STATIC_DRAW);

        gl.bindVertexArray(null);

        gl.bindBuffer(gl.ARRAY_BUFFER, null);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);
    }

    /** **/
    public free() {
        if (!this.context.isValid()) return;
        const { gl } = this.context;

        if (this.vertex_array_object) gl.deleteVertexArray(this.vertex_array_object);
        if (this.vertex_buffer_object) gl.deleteBuffer(this.vertex_buffer_object);
        if (this.index_buffer_object) gl.deleteBuffer(this.index_buffer_object);
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

    return new Mesh(context, vertices, indices, MeshDrawMode.TRIANGLES);
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
    );
}