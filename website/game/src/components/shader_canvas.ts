import { GLWidget } from "../common/gl_widget.ts";
import { Mesh, MeshDrawMode } from "../common/mesh.ts";
import { MeshVertexFormat } from "../common/mesh_vertex_format.ts";
import { Shader, DEFAULT_TRANSFORM_NAME, DEFAULT_SCREEN_SIZE_NAME } from "../common/shader.ts";
import { Time } from "../common/time.ts";
import { Vec2 } from "../common/vector.ts";
import { SmoothedMotion1D, SmoothedMotion2D } from "../common/smoothed_motion.ts";

import {
    getIsAnimationPaused
} from "../common/state.ts";

const cursor_position_name = "cursor_position";
const cursor_visible_name = "cursor_visible";
const elapsed_name = "elapsed";

export class ShaderCanvas extends GLWidget {
    private shader_program? : Shader;
    private quad? : Mesh;
    private elapsed : Time = new Time(Math.mix(-100, 100, Math.random()));
    private animation_speed = 0.5;

    private cursor_position = new SmoothedMotion2D(0, 0);
    private cursor_visible = new SmoothedMotion1D(1.0);

    private on_mouse_move = (event: MouseEvent) => {
        const { x, y } = super.to_local_position(event);
        this.cursor_position.setTargetPosition(new Vec2(x, y));
    };

    private on_mouse_enter = () => {
        this.cursor_visible.setTargetValue(1.0);
    };

    private on_mouse_leave = () => {
        this.cursor_visible.setTargetValue(0.0);
    };

    protected override async realize() {
        const source_code = this.getAttribute("fragment-shader-source");
        if (!source_code)
            throw new Error("ShaderCanvas: Attribute 'fragment-shader-source' is missing.");

        this.shader_program = new Shader(this.context, source_code);

        this.cursor_visible.setValue(1.0);
        this.cursor_position.setTargetPosition(0.5 * this.getWidth(), 0.5 * this.getHeight())

        window.addEventListener("mousemove", this.on_mouse_move);
        document.documentElement.addEventListener("mouseenter", this.on_mouse_enter);
        document.documentElement.addEventListener("mouseleave", this.on_mouse_leave);
    }

    protected override unrealize() {
        window.removeEventListener("mousemove", this.on_mouse_move);
        document.documentElement.removeEventListener("mouseenter", this.on_mouse_enter);
        document.documentElement.removeEventListener("mouseleave", this.on_mouse_leave);
    }

    protected override reformat(width: number, height: number): void {
        if (this.quad !== undefined)
            this.quad.deallocate();

        this.quad = new Mesh(
            this.context,
            new Float32Array([
                0, 0,           0, 0,   1, 1, 1, 1,
                width, 0,       1, 0,   1, 1, 1, 1,
                width, height,  1, 1,   1, 1, 1, 1,
                0, height,      0, 1,    1, 1, 1, 1
            ]),
            new Uint16Array([ 0, 1, 2, 0, 2, 3 ]),
            MeshDrawMode.TRIANGLES,
            MeshVertexFormat.XY_UV_RGBA
        )
    }

    protected override update(delta: Time): void {
        if (getIsAnimationPaused()) return;

        this.elapsed.add(delta.multiply(this.animation_speed));
        this.cursor_position.update(delta);
        this.cursor_visible.update(delta)
    }

    protected override draw(): void {
        if (!this.getIsRealized() ||this.shader_program === undefined || this.quad === undefined) return;

        if (this.shader_program.hasUniform(elapsed_name))
            this.shader_program.setUniform(elapsed_name, this.elapsed.asSeconds());

        if (this.shader_program.hasUniform(cursor_position_name))
            this.shader_program.setUniform(cursor_position_name, this.cursor_position.getPosition());

        if (this.shader_program.hasUniform(cursor_visible_name))
            this.shader_program.setUniform(cursor_visible_name, this.cursor_visible.getValue())

        if (this.shader_program.hasUniform(DEFAULT_SCREEN_SIZE_NAME)) {
            const dpr = window.devicePixelRatio || 1;
            this.shader_program.setUniform(DEFAULT_SCREEN_SIZE_NAME, new Vec2(
                Math.round(window.innerWidth * dpr),
                Math.round(window.innerHeight * dpr)
            ))
        }

        this.shader_program.bind();
        this.quad.draw();
        this.shader_program.unbind();
    }
}