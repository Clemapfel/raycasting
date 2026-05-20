import { GLWidget } from "../common/gl_widget.ts";
import { BlendMode, StencilMode } from "../common/gl_context.ts";
import { Mesh, MeshDrawMode, MeshRectangle, MeshEllipse } from "../common/mesh.ts";
import {
    DEFAULT_COLOR_NAME,
    DEFAULT_FLOAT_PRECISION,
    DEFAULT_FRAGMENT_OUT_NAME,
    DEFAULT_RGBA_NAME,
    DEFAULT_SCREEN_POS_NAME,
    DEFAULT_SCREEN_SIZE_NAME,
    DEFAULT_SHADER_VERSION,
    DEFAULT_TEXTURE_UNIFORM_NAME,
    DEFAULT_UV_NAME,
    Shader
} from "../common/shader.ts";
import { RenderTexture, Texture, TextureFormat } from "../common/texture.ts";
import { LCHA, RGBA } from "../common/color.ts";
import { Time } from "../common/time.ts";
import "../common/math.ts";
import { MeshVertexFormat } from "../common/mesh_vertex_format.ts";
import { Vec2 } from "../common/vector.ts";

const particle_texture_path = "/orb_particle_texture.png"

const n_particles = 64;
const n_sub_steps = 3;
const n_constraint_iterations = 2;
const step_delta = 1 / 60;
const gravity = 2000;
const gravity_dx = 0;
const gravity_dy = 0;
const swirl_strength = gravity * 0.25;
const collision_compliance = 0.0001;
const orb_compliance = 0.000;
const damping = 0.95;
const max_agitation = 4;
const agitation_duration = 3;

const texture_scale = 4;
const threshold = 0.3;
const eps = 0.05;
const blend_strength = 1;

const min_radius = 10;
const max_radius = 15;
const min_radius_frequency = 0.75;
const max_radius_frequency = 1.25;
const min_radius_scale = 1;
const max_radius_scale = 2;

const x_offset = 0;
const y_offset = 1;
const previous_x_offset = 2;
const previous_y_offset = 3;
const velocity_x_offset = 4;
const velocity_y_offset = 5;
const radius_offset = 6;
const radius_cycle_offset = 7;
const swirl_direction_offset = 8;
const inverse_mass_offset = 9;
const orb_lambda_offset = 10;
const r_offset = 11;
const g_offset = 12;
const b_offset = 13;
const a_offset = 14;

const mesh_vertex_data_stride = 4 * (2 + 2 + 4); // four vertices (xy uv rgba)
const index_data_stride = 6; // two tris
const particle_stride = a_offset + 1;

const canvas_threshold_shader_source = `${DEFAULT_SHADER_VERSION}
    ${DEFAULT_FLOAT_PRECISION}

    uniform sampler2D ${DEFAULT_TEXTURE_UNIFORM_NAME};
    uniform vec2 ${DEFAULT_SCREEN_SIZE_NAME};
    uniform float eps;
    uniform float threshold;
    
    in vec2 ${DEFAULT_UV_NAME};
    in vec4 ${DEFAULT_RGBA_NAME};
    in vec2 ${DEFAULT_SCREEN_POS_NAME};
    
    out vec4 ${DEFAULT_FRAGMENT_OUT_NAME};
    
    vec3 lch_to_rgb(vec3 lch) {
        float L = lch.x * 100.0;
        float C = lch.y * 100.0;
        float H = lch.z * 360.0;
    
        float a = cos(radians(H)) * C;
        float b = sin(radians(H)) * C;
    
        float Y = (L + 16.0) / 116.0;
        float X = a / 500.0 + Y;
        float Z = Y - b / 200.0;
    
        X = 0.95047 * ((X * X * X > 0.008856) ? X * X * X : (X - 16.0 / 116.0) / 7.787);
        Y = 1.00000 * ((Y * Y * Y > 0.008856) ? Y * Y * Y : (Y - 16.0 / 116.0) / 7.787);
        Z = 1.08883 * ((Z * Z * Z > 0.008856) ? Z * Z * Z : (Z - 16.0 / 116.0) / 7.787);
    
        float R = X *  3.2406 + Y * -1.5372 + Z * -0.4986;
        float G = X * -0.9689 + Y *  1.8758 + Z *  0.0415;
        float B = X *  0.0557 + Y * -0.2040 + Z *  1.0570;
    
        R = (R > 0.0031308) ? 1.055 * pow(R, 1.0 / 2.4) - 0.055 : 12.92 * R;
        G = (G > 0.0031308) ? 1.055 * pow(G, 1.0 / 2.4) - 0.055 : 12.92 * G;
        B = (B > 0.0031308) ? 1.055 * pow(B, 1.0 / 2.4) - 0.055 : 12.92 * B;
    
        return vec3(clamp(R, 0.0, 1.0), clamp(G, 0.0, 1.0), clamp(B, 0.0, 1.0));
    }

    void main() {
        vec4 texel = texture(${DEFAULT_TEXTURE_UNIFORM_NAME}, ${DEFAULT_UV_NAME});        
        float alpha = smoothstep(threshold - eps, threshold + eps, min(1.0, texel.a));
        ${DEFAULT_FRAGMENT_OUT_NAME} = vec4(lch_to_rgb(vec3(0.8, 1, max(max(texel.r, texel.g), texel.b))), alpha);
    }
    `

const default_shader_source = `${DEFAULT_SHADER_VERSION}
    ${DEFAULT_FLOAT_PRECISION}
    
    uniform sampler2D ${DEFAULT_TEXTURE_UNIFORM_NAME};
    uniform vec2 ${DEFAULT_SCREEN_SIZE_NAME};
    
    in vec2 ${DEFAULT_UV_NAME};
    in vec4 ${DEFAULT_RGBA_NAME};
    in vec2 ${DEFAULT_SCREEN_POS_NAME};
    
    out vec4 ${DEFAULT_FRAGMENT_OUT_NAME};
    
    void main() {
        vec4 texel = texture(${DEFAULT_TEXTURE_UNIFORM_NAME}, ${DEFAULT_UV_NAME});
        ${DEFAULT_FRAGMENT_OUT_NAME} = texel * ${DEFAULT_RGBA_NAME};
    }
    `

interface EnforceDistanceResult {
    a_x_correction : number,
    a_y_correction : number,
    b_x_correction : number,
    b_y_correction : number,
    lambda : number
}

interface EnforceOrbResult {
    x_correction : number,
    y_correction : number,
    lambda : number
}

export class Orb extends GLWidget  {
    private default_shader : Shader;
    private particle_mesh : Mesh;
    private particle_mesh_texture? : Texture;

    private canvas? : RenderTexture;
    private canvas_mesh? : Mesh;
    private canvas_threshold_shader : Shader;

    private particle_data : Float64Array;
    private collision_lambdas : Float64Array;
    private particle_mesh_vertex_data : Float32Array;
    private particle_mesh_index_data : Uint16Array;

    private stencil_mesh? : Mesh;

    private orb_radius : number = 0;
    private orb_center_x : number = 0;
    private orb_center_y : number = 0;
    private elapsed : number = 0;
    private is_paused : Boolean = false;
    private was_freed : Boolean = false;

    private agitation_elapsed : number = Infinity;

    protected override draw() {
        if (this.was_freed
            || this.canvas === undefined
            || this.canvas_mesh === undefined
            || this.stencil_mesh === undefined  // not yet resized
            || this.particle_mesh_texture === undefined // waiting for particle texture load
            || this.particle_mesh === undefined
        ) return;

        this.canvas.bind()
        this.context.clear(0, 0, 0, 0);
        this.context.setColor(1, 1, 1, 1)
        this.context.setBlendmode(BlendMode.ADD, BlendMode.ALPHA)

        this.default_shader.bind();
        this.default_shader.setUniform(DEFAULT_TEXTURE_UNIFORM_NAME, this.particle_mesh_texture);
        this.particle_mesh!.draw();
        this.default_shader.unbind();

        this.canvas.unbind();
        
        const value = 0x1
        this.context.setStencilMode(StencilMode.DRAW, value);
        this.stencil_mesh!.draw();
        this.context.setStencilMode(StencilMode.TEST, value);

        this.canvas_threshold_shader.bind();
        this.canvas_threshold_shader.setUniform(DEFAULT_TEXTURE_UNIFORM_NAME, this.canvas);
        this.canvas_threshold_shader.setUniform("threshold", threshold);
        this.canvas_threshold_shader.setUniform("eps", eps);
        this.canvas_mesh!.draw();
        this.canvas_threshold_shader!.unbind();

        this.context.setStencilMode(StencilMode.NONE);
    }

    private delta_accumulator : number = 0;
    protected override update(delta : Time) {
        if (this.is_paused || this.was_freed) return;
        const as_seconds = delta.asSeconds();
        
        this.elapsed += as_seconds;
        this.agitation_elapsed += as_seconds;
        this.delta_accumulator = this.delta_accumulator + delta.asSeconds();
        while (this.delta_accumulator >= step_delta) {
            this.step(step_delta);
            this.delta_accumulator -= step_delta;
        }

        this.update_mesh_data();
    }

    protected override onMousePressed(event: MouseEvent) {
        this.agitation_elapsed = 0;
    }

    protected override async realize() {
        const particle_texture_promise = new Promise<HTMLImageElement>((resolve, reject) => {
            const image = new Image();
            image.src = particle_texture_path;
            image.onload = () => resolve(image);
            image.onerror = reject;
        });

        this.default_shader = new Shader(this.context,
            undefined,
            undefined,
            MeshVertexFormat.XY_UV_RGBA
        );

        const particle_texture = await particle_texture_promise;
        this.particle_mesh_texture = new Texture(this.context, particle_texture);

        this.canvas_threshold_shader = new Shader(this.context,
            canvas_threshold_shader_source,
            undefined,
            MeshVertexFormat.XY_UV_RGBA
        )
        // canvas and canvas mesh set in reformat
    }

    private mass_distribution = (t) => {
        return Math.exp(-Math.pow((7 / 5) * Math.PI * (t - 0.5), 2));
    }

    protected override reformat(width : number, height : number) {
        if (this.canvas !== undefined) this.canvas.free();
        if (this.canvas_mesh !== undefined) this.canvas_mesh.free();

        this.particle_mesh_vertex_data = new Float32Array(n_particles * mesh_vertex_data_stride);
        this.particle_mesh_index_data = new Uint16Array(n_particles * index_data_stride);

        this.particle_data = new Float64Array(n_particles * particle_stride);
        this.collision_lambdas = new Float64Array(n_particles * n_particles);

        this.canvas = new RenderTexture(this.context, width, height, TextureFormat.RGBA8);
        this.canvas_mesh = MeshRectangle(this.context, 0, 0, width, height);

        this.stencil_mesh = MeshEllipse(this.context,
            0.5 * width, 0.5 * height, // xy
            0.5 * width, 0.5 * height  // x-radius, y-radius
        )

        const size = this.getSize();
        this.orb_radius = Math.min(size.x, size.y) / 2;
        this.orb_center_x = 0.5 * size.x;
        this.orb_center_y = 0.5 * size.y;

        // reinitialize simulation

        const golden_angle = Math.PI * (3 - Math.sqrt(5));
        const lcha = new LCHA(0.8, 1, 0, 1);
        const rgba = new RGBA();

        let index_data_i = 0;
        for (let particle_i = 0; particle_i < n_particles; ++particle_i) {
            const particle_data_i = particle_i * particle_stride;

            const t = particle_i / n_particles;
            const distance = this.orb_radius * Math.sqrt(t);
            const angle = particle_i * golden_angle;

            const position_x = this.orb_center_x + distance * Math.cos(angle);
            const position_y = this.orb_center_y + distance * Math.sin(angle);
            const mass_t = this.mass_distribution(t);

            lcha.h = t
            lcha.asRGBA(rgba);

            this.particle_data[particle_data_i + x_offset] = position_x;
            this.particle_data[particle_data_i + y_offset] = position_y;
            this.particle_data[particle_data_i + previous_x_offset] = position_x;
            this.particle_data[particle_data_i + previous_y_offset] = position_y;
            this.particle_data[particle_data_i + velocity_x_offset] = 0;
            this.particle_data[particle_data_i + velocity_y_offset] = 0;
            this.particle_data[particle_data_i + radius_offset] = Math.mix(min_radius, max_radius, mass_t);
            this.particle_data[particle_data_i + radius_cycle_offset] = Math.mix(min_radius_frequency, max_radius_frequency, Math.random());
            this.particle_data[particle_data_i + swirl_direction_offset] = particle_data_i % 2 == 0 ? 1 : -1;
            this.particle_data[particle_data_i + inverse_mass_offset] = 1 / (1 + mass_t);
            this.particle_data[particle_data_i + orb_lambda_offset] = 0;
            this.particle_data[particle_data_i + r_offset] = rgba.r;
            this.particle_data[particle_data_i + g_offset] = rgba.g;
            this.particle_data[particle_data_i + b_offset] = rgba.b;
            this.particle_data[particle_data_i + a_offset] = 1;
        }

        if (this.particle_mesh !== undefined)
            this.particle_mesh.free()

        // triangulation, does not change between frames
        for (let particle_i = 0; particle_i < n_particles; ++particle_i) {
            const vertex_base = particle_i * 4; // n vertices per particle

            this.particle_mesh_index_data[index_data_i++] = vertex_base + 0;
            this.particle_mesh_index_data[index_data_i++] = vertex_base + 1;
            this.particle_mesh_index_data[index_data_i++] = vertex_base + 2;
            this.particle_mesh_index_data[index_data_i++] = vertex_base + 0;
            this.particle_mesh_index_data[index_data_i++] = vertex_base + 2;
            this.particle_mesh_index_data[index_data_i++] = vertex_base + 3;
        }

        this.particle_mesh = new Mesh(
            this.context,
            this.particle_mesh_vertex_data,
            this.particle_mesh_index_data,
            MeshDrawMode.TRIANGLES
        );
    }

    protected override unrealize() {
        for (const object of [
            this.particle_mesh,
            this.default_shader,
            this.particle_mesh_texture,
            this.canvas,
            this.canvas_mesh,
            this.canvas_threshold_shader
        ]) {
            if (object !== undefined)
                object.free();
        }

        this.was_freed = true;
    }

    private update_mesh_data() {
        if (this.particle_mesh === undefined) return;

        let mesh_data_i = 0;
        for (let particle_i = 0; particle_i < n_particles; ++particle_i) {
            const particle_data_i = particle_i * particle_stride;

            let px = this.particle_data[particle_data_i + x_offset];
            let py = this.particle_data[particle_data_i + y_offset];
            const vx = this.particle_data[particle_data_i + velocity_x_offset];
            const vy = this.particle_data[particle_data_i + velocity_y_offset];
            const r = this.particle_data[particle_data_i + r_offset] * blend_strength;
            const g = this.particle_data[particle_data_i + g_offset] * blend_strength;
            const b = this.particle_data[particle_data_i + b_offset] * blend_strength;
            const a = this.particle_data[particle_data_i + a_offset] * 1;
            const radius_cycle = this.particle_data[particle_data_i + radius_cycle_offset]

            const elapsed = this.elapsed;
            let radius = this.particle_data[particle_data_i + radius_offset] * texture_scale
            //radius *= Math.mix(min_radius_scale, max_radius_scale, 0.5 * (1 + Math.cos(radius_cycle * Math.PI * (elapsed + particle_i))))

            px = px + vx * this.delta_accumulator;
            py = py + vy * this.delta_accumulator;

            const top_left_x = px - radius
            const top_left_y = py - radius;
            const top_right_x = px + radius
            const top_right_y = py - radius;
            const bottom_right_x = px + radius;
            const bottom_right_y = py + radius;
            const bottom_left_x = px - radius;
            const bottom_left_y = py + radius;

            const data = this.particle_mesh_vertex_data

            let offset = 0;
            data[mesh_data_i++] = top_left_x;
            data[mesh_data_i++] = top_left_y;
            data[mesh_data_i++] = 0;
            data[mesh_data_i++] = 0;
            data[mesh_data_i++] = r;
            data[mesh_data_i++] = g;
            data[mesh_data_i++] = b;
            data[mesh_data_i++] = a;

            data[mesh_data_i++] = top_right_x;
            data[mesh_data_i++] = top_right_y;
            data[mesh_data_i++] = 1;
            data[mesh_data_i++] = 0;
            data[mesh_data_i++] = r;
            data[mesh_data_i++] = g;
            data[mesh_data_i++] = b;
            data[mesh_data_i++] = a;

            data[mesh_data_i++] = bottom_right_x;
            data[mesh_data_i++] = bottom_right_y;
            data[mesh_data_i++] = 1;
            data[mesh_data_i++] = 1;
            data[mesh_data_i++] = r;
            data[mesh_data_i++] = g;
            data[mesh_data_i++] = b;
            data[mesh_data_i++] = a;

            data[mesh_data_i++] = bottom_left_x;
            data[mesh_data_i++] = bottom_left_y;
            data[mesh_data_i++] = 0;
            data[mesh_data_i++] = 1;
            data[mesh_data_i++] = r;
            data[mesh_data_i++] = g;
            data[mesh_data_i++] = b;
            data[mesh_data_i++] = a;
        }

        this.particle_mesh.replaceData(this.particle_mesh_vertex_data);
    }

    private swirl_easing(t: number) {
        let out = Math.exp(-Math.pow((Math.PI / 1.5) * t, 2));
        out *= (1 + Math.mix(0, max_agitation, 1 - Math.min(1, this.agitation_elapsed / agitation_duration)));
        return out;
    }

    private particle_is_to_lambda_i(i1: number, i2: number, n: number) {
        return i1 * n + i2;
    }

    private squared_distance(x1: number, y1: number, x2: number, y2: number) {
        const dx = x2 - x1;
        const dy = y2 - y1;
        return dx * dx + dy * dy;
    }

    private magnitude(x: number, y: number) {
        return Math.sqrt(x * x + y * y);
    }

    private distance(x1: number, y1: number, x2: number, y2: number) {
        const dx = x2 - x1;
        const dy = y2 - y1;
        return this.magnitude(dx, dy);
    }

    private enforce_distance(
        ax : number, ay : number,
        bx : number, by : number,
        inverse_mass_a : number, inverse_mass_b : number,
        target_distance : number,
        alpha : number, lambda_before : number,
        out : EnforceDistanceResult
    ) : void {
        const delta_x = bx - ax;
        const delta_y = by - ay;
        const length = this.magnitude(delta_x, delta_y);

        if (length < Math.EPS) {
            out.a_x_correction = 0;
            out.a_y_correction = 0;
            out.b_x_correction = 0;
            out.b_y_correction = 0;
            out.lambda = lambda_before;
            return;
        }

        const normal_x = delta_x / length;
        const normal_y = delta_y / length;

        const constraint = length - target_distance;
        const weight_sum = inverse_mass_a + inverse_mass_b;
        const denominator = weight_sum + alpha;

        if (denominator < Math.EPS) {
            out.a_x_correction = 0;
            out.a_y_correction = 0;
            out.b_x_correction = 0;
            out.b_y_correction = 0;
            out.lambda = lambda_before;
            return;
        }

        const delta_lambda = -(constraint + alpha * lambda_before) / denominator;
        const lambda_new = lambda_before + delta_lambda;

        out.a_x_correction = inverse_mass_a * delta_lambda * -normal_x;
        out.a_y_correction = inverse_mass_a * delta_lambda * -normal_y;
        out.b_x_correction = inverse_mass_b * delta_lambda *  normal_x;
        out.b_y_correction = inverse_mass_b * delta_lambda *  normal_y;
        out.lambda = lambda_new;
    }

    private enforce_inside_circle(
        particle_x : number, particle_y : number,
        particle_r : number, particle_inverse_mass : number,
        circle_x : number, circle_y : number, circle_r : number,
        alpha : number, lambda_before : number,
        out : EnforceOrbResult
    ) : void {
        const delta_x = particle_x - circle_x;
        const delta_y = particle_y - circle_y;
        const length = this.magnitude(delta_x, delta_y);

        const constraint = length - (circle_r - particle_r);
        if (constraint <= 0 || length < Math.EPS) {
            out.x_correction = 0;
            out.y_correction = 0;
            out.lambda = lambda_before;
            return;
        }

        const normal_x = delta_x / length;
        const normal_y = delta_y / length;

        const denominator = particle_inverse_mass + alpha;
        if (denominator < Math.EPS) {
            out.x_correction = 0;
            out.y_correction = 0;
            out.lambda = lambda_before;
            return;
        }

        const delta_lambda = -(constraint + alpha * lambda_before) / denominator;
        const lambda_new = lambda_before + delta_lambda;

        out.x_correction = particle_inverse_mass * delta_lambda * normal_x;
        out.y_correction = particle_inverse_mass * delta_lambda * normal_y;
        out.lambda = lambda_new;
        return;
    }

    private step(delta : number) {
        this.agitation_elapsed += delta;

        const sub_delta = delta / n_sub_steps;
        const collision_alpha = collision_compliance / (sub_delta * sub_delta);
        const orb_alpha = orb_compliance / (sub_delta * sub_delta);

        const data = this.particle_data;
        const collision_lambdas = this.collision_lambdas;

        // cache
        const xy = new Vec2();
        const dxy = new Vec2();
        const orb_xy = new Vec2(this.orb_center_x, this.orb_center_y);
        const orthogonal_dxy = new Vec2();

        const enforce_distance_result = {
            a_x_correction : 0,
            a_y_correction : 0,
            b_x_correction : 0,
            b_y_correction : 0,
            lambda : 0
        } as EnforceDistanceResult;

        const enforce_orb_result = {
            x_correction : 0,
            y_correction : 0,
            lambda : 0
        } as EnforceOrbResult;

        for (let sub_step = 0; sub_step < n_sub_steps; ++sub_step) {

            // pre solve
            for (let particle_i = 0; particle_i < n_particles; particle_i++) {
                const i = particle_i * particle_stride;

                const x = data[i + x_offset];
                const y = data[i + y_offset];
                data[i + previous_x_offset] = x;
                data[i + previous_y_offset] = y;

                let velocity_x = data[i + velocity_x_offset] * damping;
                let velocity_y = data[i + velocity_y_offset] * damping;

                velocity_x += sub_delta * gravity_dx * gravity;
                velocity_y += sub_delta * gravity_dy * gravity;

                xy.x = x;
                xy.y = y;

                dxy.x = x;
                dxy.y = y;
                dxy.subtract(orb_xy);
                dxy.normalize();

                if (data[i + swirl_direction_offset] >= 0)
                    dxy.turn_left(orthogonal_dxy);
                else
                    dxy.turn_right(orthogonal_dxy);

                let strength = this.swirl_easing(1 - Math.min(1, this.distance(x, y, orb_xy.x, orb_xy.y ) / this.orb_radius));
                velocity_x += orthogonal_dxy.x * strength * swirl_strength * delta;
                velocity_y += orthogonal_dxy.y * strength * swirl_strength * delta;

                data[i + velocity_x_offset] = velocity_x;
                data[i + velocity_y_offset] = velocity_y;

                data[i + x_offset] = x + sub_delta * velocity_x;
                data[i + y_offset] = y + sub_delta * velocity_y;

                data[i + orb_lambda_offset] = 0;
            }

            for (let i = 0; i < collision_lambdas.length; ++i)
                collision_lambdas[i] = 0;

            for (let _ = 0; _ < n_constraint_iterations; ++_) {

                // particle - particle collision
                for (let self_particle_i = 0; self_particle_i < n_particles; self_particle_i++) {
                    for (let other_particle_i = 0; other_particle_i < n_particles; other_particle_i++) {
                        if (self_particle_i !== other_particle_i) {
                            const self_i = self_particle_i * particle_stride;
                            const other_i = other_particle_i * particle_stride;

                            const lambda_i = this.particle_is_to_lambda_i(
                                self_particle_i, other_particle_i, n_particles
                            );

                            const self_x = data[self_i + x_offset];
                            const self_y = data[self_i + y_offset];
                            const self_r = data[self_i + radius_offset];
                            const self_inv_mass = data[self_i + inverse_mass_offset];

                            const other_x = data[other_i + x_offset];
                            const other_y = data[other_i + y_offset];
                            const other_r = data[other_i + radius_offset];
                            const other_inv_mass = data[other_i + inverse_mass_offset];

                            const min_distance = self_r + other_r;
                            const squared_distance = this.squared_distance(
                                self_x, self_y, other_x, other_y
                            );

                            if (squared_distance <= min_distance * min_distance) {
                                this.enforce_distance(
                                    self_x, self_y, other_x, other_y,
                                    self_inv_mass, other_inv_mass,
                                    min_distance, collision_alpha,
                                    collision_lambdas[lambda_i],
                                    enforce_distance_result
                                );

                                data[self_i + x_offset] = self_x + enforce_distance_result.a_x_correction;
                                data[self_i + y_offset] = self_y + enforce_distance_result.a_y_correction;
                                data[other_i + x_offset] = other_x + enforce_distance_result.b_x_correction;
                                data[other_i + y_offset] = other_y + enforce_distance_result.b_y_correction;
                                collision_lambdas[lambda_i] = enforce_distance_result.lambda;
                            }
                        }
                    }
                }

                // particle - orb collision
                for (let particle_i = 0; particle_i < n_particles; particle_i++) {
                    const self_i = particle_i * particle_stride;
                    const self_x = data[self_i + x_offset];
                    const self_y = data[self_i + y_offset];
                    const self_r = data[self_i + radius_offset];
                    const self_inv_mass = data[self_i + inverse_mass_offset];

                    this.enforce_inside_circle(
                        self_x, self_y, self_r, self_inv_mass,
                        this.orb_center_x, this.orb_center_y, this.orb_radius,
                        orb_alpha, data[self_i + orb_lambda_offset],
                        enforce_orb_result
                    );

                    data[self_i + x_offset] = self_x + enforce_orb_result.x_correction;
                    data[self_i + y_offset] = self_y + enforce_orb_result.y_correction;
                    data[self_i + orb_lambda_offset] = enforce_orb_result.lambda;
                }
            }

            // post solve
            for (let particle_i = 0; particle_i < n_particles; particle_i++) {
                const i = particle_i * particle_stride
                const x = data[i + x_offset];
                const y = data[i + y_offset];

                data[i + velocity_x_offset] = (x - data[i + previous_x_offset]) / sub_delta;
                data[i + velocity_y_offset] = (y - data[i + previous_y_offset]) / sub_delta;
            }
        }
    }
}