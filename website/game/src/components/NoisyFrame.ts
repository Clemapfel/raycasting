import { GLWidget } from "../common/GLWidget.ts";
import { Mesh, MeshDrawMode } from "../common/Mesh.ts";
import { Shader } from "../common/Shader.ts";
import { RGBA, parseRGBA, LCHA } from "../common/Colors.ts";
import { type Seconds } from "../common/Time.ts";
import { perlin_noise } from "../common/Noise.ts";
import { Vec2, turn_left, turn_right, subtract, normalize } from "../common/Math.ts";

const hue_speed : number = 1 / 20;
const inner_color_lighten : number = 1.25;
const segment_length : number = 10;

const default_outline_width : number = 4;
const default_border_radius : number = 8;
const default_background_color : RGBA = new RGBA(0, 0, 0, 1);

export class NoisyFrame extends GLWidget {
    private mesh? : Mesh
    private contour? : Float32Array;
    private vertex_buffer? : Float32Array;
    private index_buffer? : Uint16Array;

    private color : LCHA = new LCHA(0.8, 1, 0, 1);

    protected override reformat(width: number, height: number) {
        const style = window.getComputedStyle(this as HTMLElement);
        const outline_width = style.outlineWidth ? parseFloat(style.outlineWidth) : default_outline_width;
        const margin = style.margin ? parseFloat(style.margin) : 0;
        const border_radius = style.borderRadius ? parseFloat(style.borderRadius) : default_border_radius;
        const background_color = style.backgroundColor ? parseRGBA(style.backgroundColor) : default_background_color;

        this.reinitialize_mesh(
            margin, margin,
            width - 2 * margin, height - 2 * margin,
            outline_width,
            border_radius,
            this.color.asRGBA(),
            background_color
        );
    }

    protected override draw() {
        if (this.mesh === undefined) return;
        this.context.clear();
        this.context.setColor(1, 1, 1, 1);
        this.mesh.draw();
    }

    protected override update(delta : Seconds) {
        this.color.h = Math.fract(this.color.h += delta * hue_speed);

    }

    protected override unrealize() {
        if (this.mesh !== undefined)
            this.mesh.free();
    }

    // ### internal ###

    private reinitialize_mesh(
        x: number, y: number,
        width: number, height: number,
        thickness: number, border_radius: number,
        color: RGBA, background_color: RGBA
    ) {
        x += thickness;
        y += thickness;
        width -= 2 * thickness;
        height -= 2 * thickness;

        const k = (4 / 3) * Math.tan(Math.PI / 8);
        const r = border_radius;

        const corner_steps = Math.max(2, Math.ceil(Math.sqrt(r) * 2));

        const top_steps= Math.max(1, Math.ceil((width - 2 * r) / segment_length));
        const right_steps = Math.max(1, Math.ceil((height - 2 * r) / segment_length));
        const bottom_steps = Math.max(1, Math.ceil((width - 2 * r) / segment_length));
        const left_steps = Math.max(1, Math.ceil((height - 2 * r) / segment_length));

        const total_points = 4 * corner_steps + top_steps + right_steps + bottom_steps + left_steps;

        if (this.contour == undefined)
            this.contour = new Float32Array(total_points * 2);

        const contour = this.contour;

        let index = 0;

        const sample_bezier = (p0x: number, p0y: number, p1x: number, p1y: number, p2x: number, p2y: number, p3x: number, p3y: number): void => {
            for (let i = 0; i < corner_steps; i++) {
                const t = i / corner_steps;
                const u = 1 - t;
                contour[index++] = u * u * u * p0x + 3 * u * u * t * p1x + 3 * u * t * t * p2x + t * t * t * p3x;
                contour[index++] = u * u * u * p0y + 3 * u * u * t * p1y + 3 * u * t * t * p2y + t * t * t * p3y;
            }
        };

        const sample_line = (x1: number, y1: number, x2: number, y2: number, steps: number): void => {
            for (let i = 0; i < steps; i++) {
                const t = i / steps;
                contour[index++] = x1 + (x2 - x1) * t;
                contour[index++] = y1 + (y2 - y1) * t;
            }
        };

        sample_bezier(
            x, y + r,
            x, y + r - k*r,
            x + r - k*r, y,
            x + r, y
        );
        sample_line(x + r, y, x + width - r, y, top_steps);

        sample_bezier(
            x + width - r, y,
            x + width - r + k*r, y,
            x + width, y + r - k*r,
            x + width, y + r
        );
        sample_line(x + width, y + r, x + width, y + height - r, right_steps);

        sample_bezier(
            x + width, y + height - r,
            x + width, y + height - r + k*r,
            x + width - r + k*r, y + height,
            x + width - r, y + height
        );
        sample_line(x + width - r, y + height,  x + r, y + height, bottom_steps);

        sample_bezier(
            x + r, y + height,
            x + r - k * r, y + height,
            x, y + height - r + k * r,
            x, y + height - r
        );
        sample_line(x, y + height - r, x, y + r, left_steps);

        // construct contour mesh

        const point_count = contour.length / 2;
        const vertex_count = point_count * 3;

        if (this.vertex_buffer === undefined)
            this.vertex_buffer = new Float32Array(vertex_count * 8);

        const vertex_buffer = this.vertex_buffer;

        if (this.index_buffer === undefined)
            this.index_buffer = new Uint16Array(point_count * 12);

        const index_buffer = this.index_buffer;

        const outer_r = color.r, outer_g = color.g, outer_b = color.b, outer_a = color.a;
        const center_r = color.r * inner_color_lighten;
        const center_g = color.g * inner_color_lighten;
        const center_b = color.b * inner_color_lighten;

        let vertex_data_offset = 0;

        const push_vertex = (px: number, py: number, is_outer: boolean): void => {
            vertex_buffer[vertex_data_offset++] = px; // x
            vertex_buffer[vertex_data_offset++] = py; // y
            vertex_buffer[vertex_data_offset++] = 0;  // u
            vertex_buffer[vertex_data_offset++] = 0;  // v
            vertex_buffer[vertex_data_offset++] = is_outer ? outer_r : center_r; // r
            vertex_buffer[vertex_data_offset++] = is_outer ? outer_g : center_g; // g
            vertex_buffer[vertex_data_offset++] = is_outer ? outer_b : center_b; // b
            vertex_buffer[vertex_data_offset++] = outer_a; // a
        };

        let index_data_offset = 0;

        const push_indices = (point_i: number): void => {
            const current_left = ((point_i + 0) * 3 + 0) % vertex_count;
            const current_center = ((point_i + 0) * 3 + 1) % vertex_count;
            const current_right = ((point_i + 0) * 3 + 2) % vertex_count;
            const next_left = ((point_i + 1) * 3 + 0) % vertex_count;
            const next_center = ((point_i + 1) * 3 + 1) % vertex_count;
            const next_right = ((point_i + 1) * 3 + 2) % vertex_count;

            index_buffer[index_data_offset++] = current_left;
            index_buffer[index_data_offset++] = current_center;
            index_buffer[index_data_offset++] = next_center;
            index_buffer[index_data_offset++] = current_left;
            index_buffer[index_data_offset++] = next_left;
            index_buffer[index_data_offset++] = next_center;

            index_buffer[index_data_offset++] = current_right;
            index_buffer[index_data_offset++] = current_center;
            index_buffer[index_data_offset++] = next_center;
            index_buffer[index_data_offset++] = current_right;
            index_buffer[index_data_offset++] = next_center;
            index_buffer[index_data_offset++] = next_right;
        };

        const direction = new Vec2();
        const left = new Vec2();
        const right = new Vec2();

        for (let i = 0; i < point_count; i++) {
            const x1 = contour[(i * 2 + 0) % contour.length];
            const y1 = contour[(i * 2 + 1) % contour.length];
            const x2 = contour[(i * 2 + 2) % contour.length];
            const y2 = contour[(i * 2 + 3) % contour.length];

            direction.x = x2 - x1;
            direction.y = y2 - y1;
            normalize(direction);
            turn_left(direction, left);
            turn_right(direction, right);

            push_vertex(x1 + left.x * thickness, y1 + left.y * thickness, true);
            push_vertex(x1, y1, false);
            push_vertex(x1 + right.x * thickness, y1 + right.y * thickness, true);
            push_indices(i);
        }

        if (this.mesh !== undefined) this.mesh.free();
        this.mesh = new Mesh(this.context, vertex_buffer, index_buffer, MeshDrawMode.TRIANGLES);
    }
}