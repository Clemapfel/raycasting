import { GLWidget } from "../common/GLWidget.ts";
import { Mesh, MeshDrawMode } from "../common/Mesh.ts";
import { Shader } from "../common/Shader.ts";
import { RGBA, parseRGBA, LCHA } from "../common/Colors.ts";
import { type Seconds } from "../common/Time.ts";
import { perlinNoise } from "../common/Noise.ts";
import { Vec2 } from "../common/Vector.ts";
import { default_color_background } from "../styles/default.ts";

const hue_speed : number = 1 / 40; // cycles per second
const inner_color_lighten : number = 1.25; // rgb multiplier
const outer_color_darken : number = 0.75; // rgb multiplier
const default_segment_length : number = 10; // px
const max_noise_offset : number = 2; // px
const noise_frequency : number = 0.04;
const noise_speed : number = 1 / 3; // multiplies seconds
const default_background_overhang : number = 2; // px
const default_outline_width : number = 4;
const default_border_radius : number = 8;
const default_background_color : RGBA = new RGBA(0, 0, 0, 1);

export class NoisyFrame extends GLWidget {
    // cache
    private mesh? : Mesh
    private contour? : Float64Array;
    private offset_contour? : Float64Array;
    private vertex_buffer? : Float32Array;
    private index_buffer? : Uint16Array;
    private n_contour_vertices = 0;

    private color : LCHA = new LCHA(0.8, 1, 0, 1);
    private elapsed : Seconds = 0;

    protected override reformat(width: number, height: number) {
        const style = window.getComputedStyle(this as HTMLElement);
        const outline_width = style.outlineWidth ? parseFloat(style.outlineWidth) : default_outline_width;
        const margin = style.margin ? parseFloat(style.margin) : 0;
        const border_radius = style.borderRadius ? parseFloat(style.borderRadius) : default_border_radius;
        const background_color = parseRGBA(default_color_background);

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
        this.elapsed += delta;

        if (this.mesh === undefined) return;

        // reupload mesh data
        this.reformat(this.getWidth(), this.getHeight())

        /*
        // only upload color for frame
        const vertex_buffer = this.vertex_buffer!;
        const color = this.color.asRGBA();
        const alpha = color.a;

        const outer_r = color.r * outer_color_darken;
        const outer_g = color.g * outer_color_darken;
        const outer_b = color.b * outer_color_darken;

        const center_r = color.r * inner_color_lighten;
        const center_g = color.g * inner_color_lighten;
        const center_b = color.b * inner_color_lighten;

        for (let i = 0; i < this.n_contour_vertices; i++) {
            const is_center = (i % 3) === 1;
            const base = i * 8;
            vertex_buffer[base + 4] = is_center ? center_r : outer_r;
            vertex_buffer[base + 5] = is_center ? center_g : outer_g;
            vertex_buffer[base + 6] = is_center ? center_b : outer_b;
            vertex_buffer[base + 7] = alpha;
        }

        this.mesh.replaceData(vertex_buffer, this.index_buffer);
         */
    }

    protected override unrealize() {
        if (this.mesh !== undefined)
            this.mesh.free();
    }

    // ### internal ###

    private last_x : number = -Infinity;
    private last_y : number = -Infinity;
    private last_width : number = -Infinity;
    private last_height : number = -Infinity;

    private reinitialize_mesh(
        x: number, y: number,
        width: number, height: number,
        thickness: number, border_radius: number,
        color: RGBA, background_color: RGBA
    ) {
        const element = this as HTMLElement;
        const rect = element.getBoundingClientRect();
        const scale = Math.max(
            (rect.width / element.offsetWidth) * window.devicePixelRatio,
            (rect.height / element.offsetHeight) * window.devicePixelRatio
        )

        thickness *= scale;
        const segment_length = default_segment_length * scale;
        const noise_magnitude = max_noise_offset;
        const background_overhang = default_background_overhang * scale;

        const padding = thickness + noise_magnitude + background_overhang;
        x += padding;
        y += padding;
        width -= 2 * padding;
        height -= 2 * padding;

        if (this.contour === undefined
            || x != this.last_x
            || y != this.last_y
            || width != this.last_width
            || height != this.last_height
        ) {

            const k = (4 / 3) * Math.tan(Math.PI / 8);
            const r = border_radius;

            const corner_steps = Math.max(2, Math.ceil(Math.sqrt(r) * 2));

            const top_steps = Math.max(1, Math.ceil((width - 2 * r) / segment_length));
            const right_steps = Math.max(1, Math.ceil((height - 2 * r) / segment_length));
            const bottom_steps = Math.max(1, Math.ceil((width - 2 * r) / segment_length));
            const left_steps = Math.max(1, Math.ceil((height - 2 * r) / segment_length));

            const total_points = 4 * corner_steps + top_steps + right_steps + bottom_steps + left_steps;

            const contour = new Float64Array(total_points * 2);
            this.contour = contour;

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
                x, y + r - k * r,
                x + r - k * r, y,
                x + r, y
            );
            sample_line(x + r, y, x + width - r, y, top_steps);

            sample_bezier(
                x + width - r, y,
                x + width - r + k * r, y,
                x + width, y + r - k * r,
                x + width, y + r
            );
            sample_line(x + width, y + r, x + width, y + height - r, right_steps);

            sample_bezier(
                x + width, y + height - r,
                x + width, y + height - r + k * r,
                x + width - r + k * r, y + height,
                x + width - r, y + height
            );
            sample_line(x + width - r, y + height, x + r, y + height, bottom_steps);

            sample_bezier(
                x + r, y + height,
                x + r - k * r, y + height,
                x, y + height - r + k * r,
                x, y + height - r
            );
            sample_line(x, y + height - r, x, y + r, left_steps);
        }

        const contour = this.contour;
        const point_count = contour.length / 2;

        // apply noise
        if (this.offset_contour === undefined || this.offset_contour.length != contour.length)
            this.offset_contour = new Float64Array(contour.length);

        const offset_contour = this.offset_contour;
        for (let i = 0; i < contour.length; i += 2) {
            const xi = i + 0;
            const yi = i + 1;

            const value = (2 * Math.PI) * (1 + perlinNoise(
                contour[xi] * noise_frequency / scale,
                contour[yi] * noise_frequency / scale,
                this.elapsed * noise_speed
            )) / 2;

            offset_contour[xi] = contour[xi] + Math.cos(value) * noise_magnitude;
            offset_contour[yi] = contour[yi] + Math.sin(value) * noise_magnitude;
        }

        this.last_x = x;
        this.last_y = y;
        this.last_width = width;
        this.last_height = height;

        // construct mesh buffers
        this.n_contour_vertices = point_count * 3;
        const n_background_vertices = 1 + point_count;

        const vertex_count = this.n_contour_vertices + n_background_vertices;
        const vertex_buffer_length = vertex_count * 8; // xy uv rgba

        // contour: 12 per vertex; background: 3 per vertex
        const n_contour_indices = (point_count * 12);
        const n_background_indices = (point_count * 3) + 1;
        const index_buffer_length = n_contour_indices + n_background_indices;

        if (this.vertex_buffer === undefined || this.vertex_buffer.length !== vertex_buffer_length)
            this.vertex_buffer = new Float32Array(vertex_buffer_length);

        const vertex_buffer = this.vertex_buffer;

        if (this.index_buffer === undefined || this.index_buffer.length !== index_buffer_length)
            this.index_buffer = new Uint16Array(index_buffer_length);

        const index_buffer = this.index_buffer;

        const alpha = color.a;

        const outer_r = color.r * outer_color_darken;
        const outer_g = color.g * outer_color_darken;
        const outer_b = color.b * outer_color_darken;

        const center_r = color.r * inner_color_lighten;
        const center_g = color.g * inner_color_lighten;
        const center_b = color.b * inner_color_lighten;

        let vertex_data_offset = 0;
        let contour_index_offset = 0;
        let background_index_offset = 0;

        const push_contour_vertex = (px: number, py: number, is_outer: boolean): void => {
            vertex_buffer[vertex_data_offset++] = px;
            vertex_buffer[vertex_data_offset++] = py;
            vertex_buffer[vertex_data_offset++] = 0;
            vertex_buffer[vertex_data_offset++] = 0;
            vertex_buffer[vertex_data_offset++] = is_outer ? outer_r : center_r;
            vertex_buffer[vertex_data_offset++] = is_outer ? outer_g : center_g;
            vertex_buffer[vertex_data_offset++] = is_outer ? outer_b : center_b;
            vertex_buffer[vertex_data_offset++] = alpha;
        };

        const push_contour_indices = (point_i: number): void => {
            const current_left = (point_i * 3) + 0;
            const current_center = (point_i * 3) + 1;
            const current_right = (point_i * 3) + 2;

            const next_i = (point_i + 1) % point_count;
            const next_left = (next_i * 3) + 0;
            const next_center = (next_i * 3) + 1;
            const next_right = (next_i * 3) + 2;

            const offset = n_background_indices - 1
                // offset so contour tris are drawn *after* background tris

            index_buffer[offset + contour_index_offset++] = current_left;
            index_buffer[offset + contour_index_offset++] = current_center;
            index_buffer[offset + contour_index_offset++] = next_center;
            index_buffer[offset + contour_index_offset++] = current_left;
            index_buffer[offset + contour_index_offset++] = next_left;
            index_buffer[offset + contour_index_offset++] = next_center;

            index_buffer[offset + contour_index_offset++] = current_right;
            index_buffer[offset + contour_index_offset++] = current_center;
            index_buffer[offset + contour_index_offset++] = next_center;
            index_buffer[offset + contour_index_offset++] = current_right;
            index_buffer[offset + contour_index_offset++] = next_center;
            index_buffer[offset + contour_index_offset++] = next_right;
        };

        const direction = new Vec2();
        const left = new Vec2();
        const right = new Vec2();

        for (let i = 0; i < point_count; i++) {
            const prev_i = (i - 1 + point_count) % point_count;
            const next_i = (i + 1) % point_count;

            const px = offset_contour[prev_i * 2 + 0];
            const py = offset_contour[prev_i * 2 + 1];
            const nx = offset_contour[next_i * 2 + 0];
            const ny = offset_contour[next_i * 2 + 1];

            direction.x = nx - px;
            direction.y = ny - py;
            direction.normalize();
            direction.turn_left(left);
            direction.turn_right(right);

            const cx = offset_contour[i * 2 + 0];
            const cy = offset_contour[i * 2 + 1];

            push_contour_vertex(cx + left.x * thickness, cy + left.y * thickness, true);
            push_contour_vertex(cx, cy, false);
            push_contour_vertex(cx + right.x * thickness, cy + right.y * thickness, true);
            push_contour_indices(i);
        }

        const background_r = background_color.r;
        const background_g = background_color.g;
        const background_b = background_color.b;

        // center vertex
        const center_vertex_index = this.n_contour_vertices;
        vertex_buffer[vertex_data_offset++] = x + 0.5 * width;
        vertex_buffer[vertex_data_offset++] = y + 0.5 * height;
        vertex_buffer[vertex_data_offset++] = 0;
        vertex_buffer[vertex_data_offset++] = 0;
        vertex_buffer[vertex_data_offset++] = background_r;
        vertex_buffer[vertex_data_offset++] = background_g;
        vertex_buffer[vertex_data_offset++] = background_b;
        vertex_buffer[vertex_data_offset++] = alpha;

        const background_start_i = center_vertex_index + 1;

        for (let i = 0; i < point_count; i++) {
            const prev_i = (i - 1 + point_count) % point_count;
            const next_i = (i + 1) % point_count;

            const px = offset_contour[prev_i * 2 + 0];
            const py = offset_contour[prev_i * 2 + 1];
            const nx = offset_contour[next_i * 2 + 0];
            const ny = offset_contour[next_i * 2 + 1];

            direction.x = nx - px;
            direction.y = ny - py;
            direction.normalize();
            direction.turn_left(left); // left is the outward-facing normal

            const cx = offset_contour[i * 2 + 0];
            const cy = offset_contour[i * 2 + 1];

            vertex_buffer[vertex_data_offset++] = cx + left.x * (thickness + background_overhang);
            vertex_buffer[vertex_data_offset++] = cy + left.y * (thickness + background_overhang);
            vertex_buffer[vertex_data_offset++] = 0;
            vertex_buffer[vertex_data_offset++] = 0;
            vertex_buffer[vertex_data_offset++] = background_r;
            vertex_buffer[vertex_data_offset++] = background_g;
            vertex_buffer[vertex_data_offset++] = background_b;
            vertex_buffer[vertex_data_offset++] = alpha;

            const offset = 0; // inserted before background tris
            index_buffer[offset + background_index_offset++] = center_vertex_index;
            index_buffer[offset + background_index_offset++] = background_start_i + i;
            index_buffer[offset + background_index_offset++] = background_start_i + ((i + 1) % point_count);
        }

        if (this.mesh !== undefined) this.mesh.free();
        this.mesh = new Mesh(this.context, vertex_buffer, index_buffer, MeshDrawMode.TRIANGLES);
    }
}