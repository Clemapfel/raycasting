import type { GLContext } from './GLContext.ts';
import type { Texture } from './Texture.ts';
import { type Shader, default_texture_uniform_name } from './Shader.ts';

const n_vertex_buffer_elements = 8; // x y u v r g b a
const vertex_buffer_stride = n_vertex_buffer_elements * Float32Array.BYTES_PER_ELEMENT;

enum MeshDrawMode {
    POINTS,
    LINES,
    LINE_LOOP,
    LINE_STRIP,
    TRIANGLES,
    TRIANGLE_STRIP,
    TRIANGLE_FAN
}

export class Mesh {
    private context : GLContext;

    private vertex_buffer : Float32Array; // always inline x y u v r g b a | x y u v r ...
    private vertex_buffer_object : WebGLBuffer;
    private vertex_array_object : WebGLVertexArrayObject;

    private index_buffer : Uint16Array;
    private index_buffer_object : WebGLBuffer;

    private draw_mode : number;
    private n_vertices : number;

    constructor(
        context : GLContext,
        vertex_buffer : Float32Array,
        index_buffer? : Uint16Array,
        draw_mode? : MeshDrawMode
    ) {
        this.context = context;
        const gl = context;

        if (draw_mode == undefined) draw_mode = MeshDrawMode.TRIANGLE_FAN;
        switch (draw_mode) {
            case MeshDrawMode.POINTS:
                this.draw_mode = gl.POINTS;
                break;
            case MeshDrawMode.LINES:
                this.draw_mode = gl.LINES;
                break;
            case MeshDrawMode.LINE_LOOP:
                this.draw_mode = gl.LINE_LOOP;
                break;
            case MeshDrawMode.LINE_STRIP:
                this.draw_mode = gl.LINE_STRIP;
                break;
            case MeshDrawMode.TRIANGLES:
                this.draw_mode = gl.TRIANGLES;
                break;
            case MeshDrawMode.TRIANGLE_STRIP:
                this.draw_mode = gl.TRIANGLE_STRIP;
                break;
            case MeshDrawMode.TRIANGLE_FAN:
                this.draw_mode = gl.TRIANGLE_FAN;
                break;
            default:
                throw new Error(`In Mesh: unhandled draw mode ${draw_mode}`)
        }

        this.replaceData(vertex_buffer, index_buffer);
    }

    public draw() {
        const gl = this.context;
        gl.bindVertexArray(this.vertex_array_object);
        gl.drawElements(this.draw_mode, this.index_buffer.length, gl.UNSIGNED_SHORT, 0);
        gl.bindVertexArray(null);
    }

    public replaceData(vertex_buffer : Float32Array, index_buffer? : Uint16Array) {
        this.free();

        const gl = this.context;
        this.vertex_buffer = vertex_buffer;

        // verify vertex buffer integrity
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

        gl.vertexAttribPointer(0, 2, gl.FLOAT, is_normalized, vertex_buffer_stride, 0);
        gl.vertexAttribPointer(1, 2, gl.FLOAT, is_normalized, vertex_buffer_stride, 2 * bytes);
        gl.vertexAttribPointer(2, 4, gl.FLOAT, is_normalized, vertex_buffer_stride, (2 + 2) * bytes);

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

        gl.bindBuffer(gl.ARRAY_BUFFER, null);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);
        gl.bindVertexArray(null);
    }

    public free() {
        if (this.vertex_array_object) gl.deleteVertexArray(this.vertex_array_object);
        if (this.vertex_buffer_object) gl.deleteBuffer(this.vertex_buffer_object);
        if (this.index_buffer_object) gl.deleteBuffer(this.index_buffer_object);
    }
}