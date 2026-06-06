import {GLWidget} from "../common/gl_widget.ts";
import { BlendMode, PushTarget, StencilMode } from "../common/gl_context.ts";
import {
    LineJoin,
    Mesh, MeshCircle,
    MeshDrawMode,
    MeshEllipse,
    MeshLine,
    MeshRectangle,
    radius_to_n_vertices
} from "../common/mesh.ts";
import {
    DEFAULT_COLOR_NAME,
    DEFAULT_FLOAT_PRECISION,
    DEFAULT_FRAGMENT_OUT_NAME,
    DEFAULT_RGBA_NAME,
    DEFAULT_SCREEN_POS_NAME,
    DEFAULT_SCREEN_SIZE_NAME,
    DEFAULT_SHADER_VERSION,
    DEFAULT_TEXTURE_NAME,
    DEFAULT_UV_NAME,
    Shader
} from "../common/shader.ts";
import {RenderTexture, TextureFormat} from "../common/texture.ts";
import {LCHA, RGBA} from "../common/color.ts";
import {Time} from "../common/time.ts";
import "../common/math.ts";
import {MeshVertexFormat} from "../common/mesh_vertex_format.ts";
import {Vec2, Vec2Array} from "../common/vector.ts";

const line_width_factor = 5 / 100;
const line_margin_factor = 1 / 100;
const line_angle = 0;

const n_particles = 128 + 64;
const n_sub_steps = 3;
const n_constraint_iterations = 2;
const step_delta = 1 / 60;
const max_n_steps = 4;
const gravity = 3000;
const gravity_dxy = new Vec2(0, -1).normalize();
const swirl_strength = gravity * 0.25;
const swirl_reference_height = 120;
const collision_compliance = 0.0001;
const orb_compliance = 0.0001;
const damping = 0.95;
const max_agitation = 4;
const agitation_duration = 3;

const texture_scale = 5.5;
const threshold = 0.1;
const eps = 0.05;
const blend_strength = 1;

const min_radius = 6;
const max_radius = 6;
const reference_height = 300;
const min_radius_frequency = 0.0;
const max_radius_frequency = 0.0;
const min_radius_scale = 1;
const max_radius_scale = 1;
const ring_width_factor = 0.15;

const x_offset = 0;
const y_offset = 1;
const previous_x_offset = 2;
const previous_y_offset = 3;
const velocity_x_offset = 4;
const velocity_y_offset = 5;
const radius_base_offset = 6;
const radius_cycle_offset = 7;
const radius_offset = 8;
const swirl_direction_offset = 9;
const inverse_mass_offset = 10;
const orb_lambda_offset = 11;
const r_offset = 12;
const g_offset = 13;
const b_offset = 14;
const a_offset = 15;

const mesh_vertex_data_stride = 4 * (2 + 2 + 4); // four vertices (xy uv rgba)
const index_data_stride = 6; // two tris
const particle_stride = a_offset + 1;

const particle_texture_resolution = 256;
const particle_texture_shader_source = `${DEFAULT_SHADER_VERSION}
    ${DEFAULT_FLOAT_PRECISION}

    const float PI = 3.1415926535897932384626433832795;

    float gaussian(float x, float ramp)
    {
        return exp(((-4.0 * PI) / 3.0) * (ramp * x) * (ramp * x));
    }

    in vec2 ${DEFAULT_UV_NAME};
    in vec4 ${DEFAULT_RGBA_NAME};
    in vec2 ${DEFAULT_SCREEN_POS_NAME};

    out vec4 ${DEFAULT_FRAGMENT_OUT_NAME};

    void main() {
        ${DEFAULT_FRAGMENT_OUT_NAME} = vec4(gaussian(
            2.5 * (distance(${DEFAULT_UV_NAME}, vec2(0.5))),
            1.0            
        ));
        
        //${DEFAULT_FRAGMENT_OUT_NAME} = vec4(1.0 - 2.0 * (distance(${DEFAULT_UV_NAME}, vec2(0.5))));
    }
`

const canvas_threshold_shader_source = `${DEFAULT_SHADER_VERSION}
    ${DEFAULT_FLOAT_PRECISION}

    uniform sampler2D ${DEFAULT_TEXTURE_NAME};
    uniform vec2 ${DEFAULT_SCREEN_SIZE_NAME};
    uniform float eps;
    uniform float threshold;
    
    in vec2 ${DEFAULT_UV_NAME};
    in vec4 ${DEFAULT_RGBA_NAME};
    in vec2 ${DEFAULT_SCREEN_POS_NAME};
    
    out vec4 ${DEFAULT_FRAGMENT_OUT_NAME};
    
    void main() {
        vec2 pixel_size = 1.0 / ${DEFAULT_SCREEN_SIZE_NAME};

        vec4 data = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME});
        
        float value = smoothstep(
            threshold - eps,
            threshold + eps,
            data.r
        );

        vec4 center = vec4(value) * ${DEFAULT_RGBA_NAME};

        float tl = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME} + vec2(-1.0, -1.0) * pixel_size).r;
        float tm = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME} + vec2( 0.0, -1.0) * pixel_size).r;
        float tr = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME} + vec2( 1.0, -1.0) * pixel_size).r;
        float ml = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME} + vec2(-1.0,  0.0) * pixel_size).r;
        float mr = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME} + vec2( 1.0,  0.0) * pixel_size).r;
        float bl = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME} + vec2(-1.0,  1.0) * pixel_size).r;
        float bm = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME} + vec2( 0.0,  1.0) * pixel_size).r;
        float br = texture(${DEFAULT_TEXTURE_NAME}, ${DEFAULT_UV_NAME} + vec2( 1.0,  1.0) * pixel_size).r;

        float gradient_x = -tl + tr - 2.0 * ml + 2.0 * mr - bl + br;
        float gradient_y = -tl - 2.0 * tm - tr + bl + 2.0 * bm + br;

        const float gradient_influence = 0.25;
        vec3 surface_normal = gradient_influence * normalize(vec3(-gradient_x, -gradient_y, 1.0));

        vec3 specular_light_direction = normalize(vec3(1.0, -1.0, 1.0));
        vec3 view_dir = vec3(0.0, 0.0, 1.0);
        vec3 half_dir = normalize(specular_light_direction + view_dir);
        
        const float specular_focus = 16.0;
        const float highlight_strength = 1.0;
        float specular = highlight_strength * pow(max(dot(surface_normal, half_dir), 0.0), specular_focus);

        vec3 shadow_light_direction = normalize(vec3(-0.5, 0.75, 0.0));
        const float shadow_strength = 1.0;
        float shadow = dot(surface_normal, shadow_light_direction);
        shadow = smoothstep(0.0, 1.0, clamp(shadow * shadow_strength, 0.0, 1.0));
        
        float alpha = smoothstep(threshold - eps, threshold + eps, center.r);

        ${DEFAULT_FRAGMENT_OUT_NAME} = vec4(center.rgb - shadow + specular, alpha);
    }
    `;

const glass_mesh_shader_source = `${DEFAULT_SHADER_VERSION}
    ${DEFAULT_FLOAT_PRECISION}
    
    #define PI 3.1415926535897932384626433832795
    float gaussian(float x, float ramp)
    {
        return exp(((-4.0 * PI) / 3.0) * (ramp * x) * (ramp * x));
    }
    
    uniform vec2 cursor_position;
    
    uniform sampler2D ${DEFAULT_TEXTURE_NAME};
    uniform vec2 ${DEFAULT_SCREEN_SIZE_NAME};
    uniform vec4 ${DEFAULT_COLOR_NAME};
    
    in vec2 ${DEFAULT_UV_NAME};
    in vec4 ${DEFAULT_RGBA_NAME};
    in vec2 ${DEFAULT_SCREEN_POS_NAME};
    
    out vec4 ${DEFAULT_FRAGMENT_OUT_NAME};
    
    void main() {
        vec2 dxy = ${DEFAULT_UV_NAME}.xy;
        float distance_from_center = length(dxy);
        float angle = atan(dxy.y, dxy.x);
        
        vec3 surface_normal = vec3(
            distance_from_center * cos(angle),
            distance_from_center * sin(angle),
            sqrt(1.0 - distance_from_center * distance_from_center)
        );
        
        const vec2 center = vec2(0.0);
        vec2 uv = ${DEFAULT_UV_NAME};
        
        vec4 body_color = vec4(1.0);
        float shadow_offset = -1.0 / 3.5;
        float body = max(0.05, 1.0 - gaussian(distance(uv, vec2(shadow_offset)), 0.6));
        body_color.a = 0.1;
    
        vec4 static_highlight_color;
        {
            float dist = distance(pow(distance(uv, center), 1.5) * uv, vec2(-1.0 / 3.2, -1.0 / 2.7));
            float highlight = gaussian(dist, 1.2) * gaussian(distance(uv, center), 0.2);
            static_highlight_color = vec4(vec3(1.0), distance(uv, center)) * highlight;
            static_highlight_color = mix(static_highlight_color, vec4(highlight), 0.4);
        }
        
        float player_highlight_color;
        {
            vec2 player_dir = normalize(cursor_position);
            float player_dist = length(cursor_position);
            float intensity = clamp(8.0 / (player_dist * player_dist), 0.0, 2.0);
            vec2 highlight_pos = player_dir * 0.4;
            float dist = distance(pow(distance(uv, center), 1.5) * uv, highlight_pos);
            float highlight = gaussian(1.0 - dist, 1.3) * gaussian(1.0 - distance(uv, center), 0.25);
            player_highlight_color = highlight * min(intensity, 0.5);
        }
        
        player_highlight_color = 0.0;

        float fresnel_edge = dot(surface_normal, vec3(0.0, 0.0, 1.0));
        float limb_darkness = pow(1.0 - fresnel_edge, 2.0) * smoothstep(0.0, 0.5, distance_from_center);
        vec4 limb_outline = vec4(0.0, 0.0, 0.0, limb_darkness);
        
        ${DEFAULT_FRAGMENT_OUT_NAME} = ${DEFAULT_COLOR_NAME} * mix(
            vec4(body_color * static_highlight_color + player_highlight_color), 
            limb_outline, 
            limb_outline.a
        );
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
    private default_shader? : Shader;
    private particle_mesh? : Mesh;
    private particle_mesh_texture? : RenderTexture;

    private particle_canvas? : RenderTexture;
    private particle_canvas_mesh? : Mesh;
    private canvas_threshold_shader? : Shader;

    private is_initialized : boolean = false;
    private particle_data : Float64Array;
    private collision_lambdas : Float64Array;
    private particle_mesh_vertex_data : Float32Array;
    private particle_mesh_index_data : Uint16Array;

    private stencil_mesh? : Mesh;
    private glass_backing_mesh? : Mesh;
    private glass_mesh? : Mesh;
    private glass_mesh_shader? : Shader;
    private glass_mesh_cursor_position = new Vec2(0);

    private glass_backing_color : RGBA = new RGBA(0.5, 0.5, 0.5, 1);
    private line_color : RGBA = new RGBA(1, 1, 1, 1);
    private fluid_color : RGBA = new RGBA(1, 1, 1, 1);

    private line_end? : Mesh;
    private line? : Mesh;
    private line_arc? : Mesh;

    private orb_radius : number = 0;
    private orb_center_x : number = 0;
    private orb_center_y : number = 0;
    private elapsed : number = 0;
    private is_paused : Boolean = false;
    private was_freed : Boolean = false;

    private agitation_elapsed : number = Infinity;

    protected override draw() {
        if (this.was_freed
            || this.particle_canvas === undefined
        ) return;

        if (this.particle_mesh_texture === undefined) {
            const mesh = MeshRectangle(this.context, 0, 0, particle_texture_resolution, particle_texture_resolution);
            const shader = new Shader(this.context,
                particle_texture_shader_source,
                undefined,  // default vertex source
                MeshVertexFormat.XY_UV_RGBA
            );

            this.particle_mesh_texture = new RenderTexture(this.context,
                particle_texture_resolution,
                particle_texture_resolution,
                TextureFormat.RGBA8
            )

            this.particle_mesh_texture.bind()
            shader.bind();
            shader.setUniform(DEFAULT_SCREEN_SIZE_NAME, this.particle_mesh_texture.getSize())
            mesh.draw();
            shader.unbind();
            this.particle_mesh_texture.unbind();

            mesh.free();
            shader.free()
        }

        {   // draw raw data to particle canvas
            using context_raii = this.context.with();

            this.particle_canvas.bind();
            this.context.clear(0, 0, 0, 0);
            this.context.setColor(1, 1, 1, 1);
            this.context.setBlendmode(BlendMode.ADD, BlendMode.ALPHA);

            this.default_shader?.bind();
            this.default_shader?.setUniform(DEFAULT_TEXTURE_NAME, this.particle_mesh_texture);
            this.default_shader?.setUniform(DEFAULT_SCREEN_SIZE_NAME, this.particle_canvas.getSize());
            this.particle_mesh?.draw();
            this.default_shader?.unbind();

            this.particle_canvas.unbind()
        }

        {   // glass background
            using context = this.context.with(PushTarget.COLOR);

            this.context.setColor(this.glass_backing_color);
            this.glass_backing_mesh?.draw();
        }

        {   // stencil circle, then draw post-fx particles
            using context = this.context.with();

            const value = 0x1
            this.context.setStencilMode(StencilMode.DRAW, value);
            this.stencil_mesh?.draw();
            this.context.setStencilMode(StencilMode.TEST, value);

            this.context.setColor(this.fluid_color);
            this.canvas_threshold_shader?.bind();
            this.canvas_threshold_shader?.setUniform(DEFAULT_TEXTURE_NAME, this.particle_canvas);
            this.canvas_threshold_shader?.setUniform("threshold", threshold);
            this.canvas_threshold_shader?.setUniform("eps", eps);
            this.particle_canvas_mesh?.draw();
            this.canvas_threshold_shader?.unbind();

            this.context.setStencilMode(StencilMode.NONE);
        }

        {   // draw glass mesh on top of thresholded
            using context = this.context.with()

            const t = 0.5
            this.context.setColor(t, t, t, t); // additive blending
            this.context.setBlendmode(BlendMode.ADD, BlendMode.ALPHA);
            this.glass_mesh_shader?.bind();
            this.glass_mesh?.draw();
            this.glass_mesh_shader?.unbind();
        }

        {   // draw line
            using context = this.context.with()

            this.context.setColor(this.line_color);
            this.line_end?.draw();
            this.line?.draw();
            this.line_arc?.draw();
        }
    }

    private delta_accumulator : number = 0;
    protected override update(delta : Time) {
        if (this.is_paused || this.was_freed) return;
        const as_seconds = delta.asSeconds();
        this.delta_accumulator = this.delta_accumulator + delta.asSeconds();

        let n_steps = 0;
        while (this.delta_accumulator >= step_delta) {
            this.elapsed += step_delta;
            this.agitation_elapsed += step_delta;

            this.step(step_delta);
            this.delta_accumulator -= step_delta;
            if (++n_steps > max_n_steps) {
                // in case of spiked delta
                this.delta_accumulator = 0;
                break;
            }
        }

        this.update_mesh_data();
    }

    protected override onMousePressed(x : number, y : number, event : MouseEvent) {
        if (event.button == 0)
            this.agitation_elapsed = 0;
        else
            this.reformat(this.getWidth(), this.getHeight()); // reinitialize
    }

    protected override onMouseMoved(x : number, y : number, event : MouseEvent) {
        const is_in_circle = new Vec2(
            x - this.orb_center_x,
            y - this.orb_center_y
        ).magnitude() <= this.orb_radius;

        (this as HTMLElement).style.cursor = is_in_circle ? "pointer" : "default";

        this.glass_mesh_cursor_position.assign(
            (this.orb_center_x - x) / this.orb_radius,
            (this.orb_center_y - y) / this.orb_radius
        )
    }

    protected override async realize() {
        this.default_shader = new Shader(this.context,
            undefined,
            undefined,
            MeshVertexFormat.XY_UV_RGBA
        );

        this.canvas_threshold_shader = new Shader(this.context,
            canvas_threshold_shader_source,
            undefined,
            MeshVertexFormat.XY_UV_RGBA
        )

        this.glass_mesh_shader = new Shader(this.context,
            glass_mesh_shader_source,
            undefined,
            MeshVertexFormat.XY_UV_RGBA
        )
        // canvas and canvas mesh set in reformat
    }

    private mass_distribution = (t) => {
        return Math.exp(-Math.pow((7 / 5) * Math.PI * (t - 0.5), 2));
    }

    protected override reformat(width: number, height: number) {
        if (this.particle_canvas !== undefined) this.particle_canvas.free();
        if (this.particle_canvas_mesh !== undefined) this.particle_canvas_mesh.free();

        const widget_size = this.getSize();

        const line_width = line_width_factor * widget_size.y;
        const line_margin = line_margin_factor * widget_size.y;

        this.orb_radius = Math.min(widget_size.x, widget_size.y) / 2 - 2 * line_width - 4 * line_margin;
        this.orb_center_x = this.orb_radius + line_width + 2 * line_margin;
        this.orb_center_y = widget_size.y * 0.5;

        this.particle_mesh_vertex_data = new Float32Array(n_particles * mesh_vertex_data_stride);
        this.particle_mesh_index_data = new Uint16Array(n_particles * index_data_stride);

        this.particle_data = new Float64Array(n_particles * particle_stride);
        this.collision_lambdas = new Float64Array(n_particles * n_particles);

        this.particle_canvas = new RenderTexture(this.context, height, height, TextureFormat.R32F);
        this.particle_canvas_mesh = MeshRectangle(this.context,
            0, 0,
            this.particle_canvas.getWidth(),
            this.particle_canvas.getHeight()
        );

        // init line mesh

        const line_origin_radius = this.orb_radius + 0.5 * line_width + line_margin;
        const line_origin_left = new Vec2(
            this.orb_center_x + Math.cos(line_angle) * line_origin_radius,
            this.orb_center_y + Math.sin(line_angle) * line_origin_radius
        );

        const line_origin_right = new Vec2(
            width - line_width - line_margin,
            line_origin_left.y
        );

        this.line = MeshLine(this.context,
            [ line_origin_left, line_origin_right ],
            line_width,
            LineJoin.NONE,
            undefined, // default color
            false // no end caps
        )

        this.line_end = MeshEllipse(this.context,
            line_origin_right.x,
            line_origin_right.y,
            line_width / 2,
            line_width / 2,
            undefined, // default color
            false // no anti-aliasing
        );

        {
            const n_vertices = 10 * radius_to_n_vertices(this.orb_radius, this.orb_radius) / 2;
            const radius = this.orb_radius + line_margin + line_width;

            const tau = 2 * Math.PI;
            const sweep_start = line_angle - 0.25 * tau;
            const sweep_end   = line_angle + 0.25 * tau;
            const sweep_step  = 1 / n_vertices * 0.5 * tau;

            let vertices: Vec2[] = [];
            for (let angle = Math.min(sweep_start, sweep_end); angle <= Math.max(sweep_start, sweep_end); angle += sweep_step) {
                vertices.push(new Vec2(
                    this.orb_center_x + Math.cos(angle) * radius,
                    this.orb_center_y + Math.sin(angle) * radius
                ));
            }

            this.line_arc = MeshLine(this.context,
                vertices,
                line_width,
                LineJoin.NONE
            )
        }

        // init orb mesh

        this.stencil_mesh = MeshEllipse(this.context,
            this.orb_center_x, this.orb_center_y,
            this.orb_radius, this.orb_radius,
            new RGBA(1, 1, 1, 1),
            false // no anti-aliasing rim
        );

        {
            const n_outer_vertices = radius_to_n_vertices(this.orb_radius, this.orb_radius)
            const mesh_format = MeshVertexFormat.XY_UV;
            const glass_mesh_data = new Float32Array((1 + n_outer_vertices) * (2 + 2 + 4));
            let idx = 0;

            glass_mesh_data[idx++] = this.orb_center_x;
            glass_mesh_data[idx++] = this.orb_center_y;
            glass_mesh_data[idx++] = 0; // u
            glass_mesh_data[idx++] = 0; // v
            glass_mesh_data[idx++] = 0; // r
            glass_mesh_data[idx++] = 0; // g
            glass_mesh_data[idx++] = 0; // b
            glass_mesh_data[idx++] = 1; // a

            for (let i = 0; i < n_outer_vertices; ++i) { // <= sic
                const angle = i / n_outer_vertices * 2 * Math.PI;
                glass_mesh_data[idx++] = this.orb_center_x + this.orb_radius * Math.cos(angle);
                glass_mesh_data[idx++] = this.orb_center_y + this.orb_radius * Math.sin(angle);
                glass_mesh_data[idx++] = Math.cos(angle);
                glass_mesh_data[idx++] = Math.sin(angle);
                glass_mesh_data[idx++] = 1;
                glass_mesh_data[idx++] = 1;
                glass_mesh_data[idx++] = 1;
                glass_mesh_data[idx++] = 1;
            }

            const glass_mesh_indices = new Uint16Array((1 + n_outer_vertices) * 3)

            idx = 0;
            for (let outer_i = 1; outer_i <= n_outer_vertices; outer_i++) {
                glass_mesh_indices[idx++] = 0;
                glass_mesh_indices[idx++] = outer_i - 1;
                glass_mesh_indices[idx++] = outer_i;
            }

            glass_mesh_indices[idx++] = n_outer_vertices;
            glass_mesh_indices[idx++] = 0;
            glass_mesh_indices[idx++] = 1;

            this.glass_mesh = new Mesh(
                this.context,
                glass_mesh_data,
                glass_mesh_indices,
                MeshDrawMode.TRIANGLES,
                MeshVertexFormat.XY_UV_RGBA
            )

            this.glass_mesh_cursor_position.assign(0, 0);
        }

        this.glass_backing_mesh = MeshCircle(this.context,
            this.orb_center_x, this.orb_center_y,
            this.orb_radius
        )

        // reinitialize simulation

        const golden_angle = Math.PI * (3 - Math.sqrt(5));
        const lcha = new LCHA(0.8, 1, 0, 1);
        const rgba = new RGBA();

        const min_radius_fraction = min_radius / reference_height;
        const max_radius_fraction = max_radius / reference_height;

        const center_x = 0.5 * this.particle_canvas.getHeight();
        const center_y = 0.5 * this.particle_canvas.getWidth();

        let index_data_i = 0;
        for (let particle_i = 0; particle_i < n_particles; ++particle_i) {
            const particle_data_i = particle_i * particle_stride;

            const t = particle_i / n_particles;
            const distance = this.orb_radius * Math.sqrt(t);
            const angle = particle_i * golden_angle;

            const position_x = center_x + distance * Math.cos(angle);
            const position_y = center_y + distance * Math.sin(angle);
            const mass_t = this.mass_distribution(t);

            lcha.h = t
            lcha.asRGBA(rgba);

            const base_radius = Math.mix(
                min_radius_fraction * height,
                max_radius_fraction * height,
                mass_t
            );

            const radius_cycle_offset = Math.mix(min_radius_frequency, max_radius_frequency, Math.random()) + particle_i;

            this.particle_data[particle_data_i + x_offset] = position_x;
            this.particle_data[particle_data_i + y_offset] = position_y;
            this.particle_data[particle_data_i + previous_x_offset] = position_x;
            this.particle_data[particle_data_i + previous_y_offset] = position_y;
            this.particle_data[particle_data_i + velocity_x_offset] = 0;
            this.particle_data[particle_data_i + velocity_y_offset] = 0;
            this.particle_data[particle_data_i + radius_base_offset] = base_radius;
            this.particle_data[particle_data_i + radius_cycle_offset] = radius_cycle_offset;
            this.particle_data[particle_data_i + radius_offset] = this.get_radius(base_radius, radius_cycle_offset)
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

        this.is_initialized = true;
    }

    protected override unrealize() {
        for (const object of [
            this.particle_mesh,
            this.default_shader,
            this.particle_mesh_texture,
            this.particle_canvas,
            this.particle_canvas_mesh,
            this.canvas_threshold_shader
        ]) {
            if (object !== undefined)
                object.free();
        }

        this.was_freed = true;
    }

    private get_radius(radius : number, radius_cycle : number) {
        return radius * Math.mix(
            min_radius_scale,
            max_radius_scale,
            0.5 * (1 + Math.cos(radius_cycle * Math.PI * this.elapsed))
        )
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

            const radius = texture_scale * this.particle_data[particle_data_i + radius_offset];

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
        out *= (Math.mix(0, max_agitation, 1 - Math.min(1, this.agitation_elapsed / agitation_duration)));
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
        if (!this.is_initialized) return;

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

        const current_gravity = gravity * Math.min(1, this.agitation_elapsed / agitation_duration)
        const swirl_multiplier = this.particle_canvas!.getHeight() / swirl_reference_height;

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

                velocity_x += sub_delta * gravity_dxy.x * current_gravity;
                velocity_y += sub_delta * gravity_dxy.y * current_gravity;

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
                velocity_x += orthogonal_dxy.x * strength * swirl_multiplier * swirl_strength * delta;
                velocity_y += orthogonal_dxy.y * strength * swirl_multiplier * swirl_strength * delta;

                data[i + velocity_x_offset] = velocity_x;
                data[i + velocity_y_offset] = velocity_y;

                data[i + x_offset] = x + sub_delta * velocity_x;
                data[i + y_offset] = y + sub_delta * velocity_y;

                data[i + radius_offset] = this.get_radius(
                    data[i + radius_base_offset],
                    data[i + radius_cycle_offset]
                )

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
                            const self_r = data[self_i + radius_base_offset];

                            const self_inv_mass = data[self_i + inverse_mass_offset];

                            const other_x = data[other_i + x_offset];
                            const other_y = data[other_i + y_offset];
                            const other_r = data[other_i + radius_base_offset];

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
                    const self_r = data[self_i + radius_base_offset];
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