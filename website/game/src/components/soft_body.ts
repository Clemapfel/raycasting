import { GLWidget } from "../common/gl_widget.ts";
import { Time } from "../common/time.ts";
import { Mesh, MeshDrawMode, MeshLine } from "../common/mesh.ts";
import { Vec2Array } from "../common/vector.ts";
import { OKLCHA, parseOKLCHA, parseRGBA, RGBA } from "../common/color.ts";
import { getIsAnimationPaused } from "../common/state.ts";

const settings = {
    n_sub_steps: 4,
    n_constraint_iterations: 4,

    vertex_density: 1 / 8,
    damping: 0.998,
    gravity: 5000,

    distance_compliance: 2e-6,
    volume_compliance: 1e-7,
    line_compliance: 0,
    bending_compliance: 1e-5,
    angular_compliance: 1e-8,
    particle_collision_compliance: 0,

    radius: 200,
    line_width: 3,
    texture_zoom: 1 / 1.25,

    mesh_color: new RGBA(0, 0, 0, 0.8),
    outline_color: new RGBA(1, 1, 1, 1)
} as const;

const PARTICLE_X = 0;
const PARTICLE_Y = 1;
const PARTICLE_PREVIOUS_X = 2;
const PARTICLE_PREVIOUS_Y = 3;
const PARTICLE_DRAW_X = 4;
const PARTICLE_DRAW_Y = 5;
const PARTICLE_VELOCITY_X = 6;
const PARTICLE_VELOCITY_Y = 7;
const PARTICLE_RADIUS = 8;
const PARTICLE_MASS = 9;
const PARTICLE_INVERSE_MASS = 10;
const PARTICLE_DISTANCE_LAMBDA = 11;
const PARTICLE_BENDING_LAMBDA = 12;
const PARTICLE_POLYGON_LAMBDA = 13;
const PARTICLE_STRIDE = 14;

const EDGE_X1 = 0;
const EDGE_Y1 = 1;
const EDGE_X2 = 2;
const EDGE_Y2 = 3;
const EDGE_NORMAL_X = 4;
const EDGE_NORMAL_Y = 5;
const EDGE_STRIDE = 6;

const MESH_VERTEX_STRIDE = 8; // x, y, u, v, r, g, b, a
const TAU = 2 * Math.PI;
const EPS = 1e-7;

interface SoftBodyChain {
    n_particles: number;
    particle_indices: Uint32Array;
    collision_edges: Float32Array;
    n_collision_edges: number;
    inter_chain_lambda: Float32Array;
    rest_volume: number;
    volume_lambda: number;
    angular_lambda: number;
    volume_gradient_x: Float32Array;
    volume_gradient_y: Float32Array;
    segment_length: number;
    draw_positions: Float32Array;
    mesh_data: Float32Array;
    mesh: Mesh;
    line_mesh_data: Float32Array;
    line_mesh: Mesh;
}

/** **/
export class SoftBody extends GLWidget {
    
    private n_particles = 0;
    private particles = new Float32Array(0);
    
    private polygon = new Float32Array(0);
    private polygon_edges = new Float32Array(0);
    private n_polygon_edges = 0;
    
    private chains: SoftBodyChain[] = [];
    
    private mesh_data_needs_update = false;

    private readonly constraint_cache = new Float64Array(7);
    private readonly collision_cache = new Float64Array(3);

    protected override async realize(): Promise<void> {
        this.reformat(this.getWidth(), this.getHeight());
    }

    protected override unrealize(): void {
        for (let i = 0; i < this.chains.length; i++) {
            this.chains[i].mesh.deallocate();
        }
    }

    protected override reformat(width: number, height: number): void {
        for (let i = 0; i < this.chains.length; i++) {
            this.chains[i].mesh.deallocate();
        }

        this.n_particles = 0;

        const x : number = 0;
        const y : number = 0;

        const tl_x = x;
        const tl_y = y;
        const tr_x = x + width;
        const tr_y = y;
        const br_x = x + width;
        const br_y = y + height;
        const bl_x = x;
        const bl_y = y + height;
        
        this.polygon = new Float32Array([
            tl_x, tl_y,
            tr_x, tr_y,
            br_x, br_y,
            bl_x, bl_y,
            tl_x, tl_y
        ]);;
        
        const n_polygon_vertices = this.polygon.length / 2;
        this.polygon_edges = new Float32Array(n_polygon_vertices * EDGE_STRIDE);
        this.n_polygon_edges = 0;
        for (let vertex_i = 0; vertex_i < n_polygon_vertices; vertex_i++) {
            const next_vertex_i = (vertex_i + 1) % n_polygon_vertices;
            const a = vertex_i * 2;
            const b = next_vertex_i * 2;
            const x1 = this.polygon[a];
            const y1 = this.polygon[a + 1];
            const x2 = this.polygon[b];
            const y2 = this.polygon[b + 1];

            const dx = x2 - x1;
            const dy = y2 - y1;
            const magnitude = Math.sqrt(dx * dx + dy * dy);
            if (magnitude <= EPS) continue;

            const edge_base = this.n_polygon_edges * EDGE_STRIDE;
            this.polygon_edges[edge_base + EDGE_X1] = x1;
            this.polygon_edges[edge_base + EDGE_Y1] = y1;
            this.polygon_edges[edge_base + EDGE_X2] = x2;
            this.polygon_edges[edge_base + EDGE_Y2] = y2;
            this.polygon_edges[edge_base + EDGE_NORMAL_X] = -dy / magnitude;
            this.polygon_edges[edge_base + EDGE_NORMAL_Y] = dx / magnitude;
            this.n_polygon_edges++;
        }

        const n_per_chain = Math.max(
            16,
            Math.floor(settings.radius * TAU * settings.vertex_density)
        );
        
        this.n_particles = n_per_chain * 2;
        this.particles = new Float32Array(this.n_particles * PARTICLE_STRIDE);
        
        this.chains = [
            this.newChain(0.4 * width, 0.5 * height, n_per_chain, 0),
            this.newChain(0.6 * width, 0.5 * height, n_per_chain, n_per_chain)
        ];

        this.mesh_data_needs_update = false;
    }

    private newChain(
        cx: number,
        cy: number,
        n_particles: number,
        particle_start: number
    ) : SoftBodyChain {
        const radius = settings.radius;
        const particles = this.particles;
        const particle_indices = new Uint32Array(n_particles);
        const collision_edges = new Float32Array(n_particles * EDGE_STRIDE);
        const inter_chain_lambda = new Float32Array(n_particles);
        const volume_gradient_x = new Float32Array(n_particles);
        const volume_gradient_y = new Float32Array(n_particles);
        const draw_positions = new Float32Array(n_particles * 2);
        const mesh_data = new Float32Array(n_particles * 3 * MESH_VERTEX_STRIDE);

        for (let particle_i = 0; particle_i < n_particles; particle_i++) {
            const global_particle_i = particle_start + particle_i;
            particle_indices[particle_i] = global_particle_i;
            const base = global_particle_i * PARTICLE_STRIDE;
            const angle = (particle_i / n_particles) * TAU;
            const px = cx + radius * Math.cos(angle);
            const py = cy + radius * Math.sin(angle);

            particles[base + PARTICLE_X] = px;
            particles[base + PARTICLE_Y] = py;
            particles[base + PARTICLE_PREVIOUS_X] = px;
            particles[base + PARTICLE_PREVIOUS_Y] = py;
            particles[base + PARTICLE_DRAW_X] = px;
            particles[base + PARTICLE_DRAW_Y] = py;
            particles[base + PARTICLE_VELOCITY_X] = 0;
            particles[base + PARTICLE_VELOCITY_Y] = 0;
            particles[base + PARTICLE_RADIUS] = 1;
            particles[base + PARTICLE_MASS] = 1;
            particles[base + PARTICLE_INVERSE_MASS] = 1;
            particles[base + PARTICLE_DISTANCE_LAMBDA] = 0;
            particles[base + PARTICLE_BENDING_LAMBDA] = 0;
            particles[base + PARTICLE_POLYGON_LAMBDA] = 0;
            draw_positions[particle_i * 2] = px;
            draw_positions[particle_i * 2 + 1] = py;
        }

        let rest_volume = 0;
        for (let particle_i = 0; particle_i < n_particles; particle_i++) {
            const ai = particle_indices[particle_i] * PARTICLE_STRIDE;
            const bi = particle_indices[(particle_i + 1) % n_particles] * PARTICLE_STRIDE;
            const ax = particles[ai + PARTICLE_X];
            const ay = particles[ai + PARTICLE_Y];
            const bx = particles[bi + PARTICLE_X];
            const by = particles[bi + PARTICLE_Y];
            rest_volume += 0.5 * (ax * by - bx * ay);
        }

        const set_vertex = (target, offset, x, y, u, v) => {
            target[offset] = x;
            target[offset + 1] = y;
            target[offset + 2] = u;
            target[offset + 3] = v;
            target[offset + 4] = 1;
            target[offset + 5] = 1;
            target[offset + 6] = 1;
            target[offset + 7] = 1;
        }

        const zoom = settings.texture_zoom;
        for (let particle_i = 0; particle_i < n_particles; particle_i++) {
            const a_particle_i = particle_i;
            const b_particle_i = (particle_i + 1) % n_particles;
            const angle_a = (a_particle_i / n_particles) * TAU;
            const angle_b = (b_particle_i / n_particles) * TAU;
            const u_a = 0.5 + 0.5 * zoom * Math.cos(angle_a);
            const v_a = 0.5 + 0.5 * zoom * Math.sin(angle_a);
            const u_b = 0.5 + 0.5 * zoom * Math.cos(angle_b);
            const v_b = 0.5 + 0.5 * zoom * Math.sin(angle_b);

            const ai = particle_indices[a_particle_i] * PARTICLE_STRIDE;
            const bi = particle_indices[b_particle_i] * PARTICLE_STRIDE;
            const ax = particles[ai + PARTICLE_X];
            const ay = particles[ai + PARTICLE_Y];
            const bx = particles[bi + PARTICLE_X];
            const by = particles[bi + PARTICLE_Y];
            const mesh_base = particle_i * 3 * MESH_VERTEX_STRIDE;

            set_vertex(mesh_data, mesh_base, cx, cy, 0.5, 0.5);
            set_vertex(mesh_data, mesh_base + MESH_VERTEX_STRIDE, ax, ay, u_a, v_a);
            set_vertex(mesh_data, mesh_base + 2 * MESH_VERTEX_STRIDE, bx, by, u_b, v_b);
        }

        const line_mesh_data = new Float32Array((n_particles + 1) * 2);
        for (let particle_i = 0; particle_i < n_particles; particle_i++) {
            const ai = particle_indices[particle_i] * PARTICLE_STRIDE;
            line_mesh_data[particle_i * 2 + 0] = particles[ai + PARTICLE_X];
            line_mesh_data[particle_i * 2 + 1] = particles[ai + PARTICLE_Y];
        }

        line_mesh_data[n_particles * 2 + 0] = line_mesh_data[0];
        line_mesh_data[n_particles * 2 + 1] = line_mesh_data[1];

        const mesh = new Mesh(
            this.context,
            mesh_data,
            undefined, // default index buffer
            MeshDrawMode.TRIANGLES
        );

        const line_mesh = MeshLine(
            this.context,
            line_mesh_data,
            settings.line_width
        );

        return {
            n_particles,
            particle_indices,
            collision_edges,
            n_collision_edges: 0,
            inter_chain_lambda,
            rest_volume,
            volume_lambda: 0,
            angular_lambda: 0,
            volume_gradient_x,
            volume_gradient_y,
            segment_length: TAU * radius / n_particles,
            draw_positions,
            mesh_data,
            mesh,
            line_mesh_data,
            line_mesh
        };
    }

    protected override draw(): void {
        if (!getIsAnimationPaused() && this.mesh_data_needs_update) {
            this.mesh_data_needs_update = false;
            const particles = this.particles;

            for (let chain_i = 0; chain_i < this.chains.length; chain_i++) {
                const chain = this.chains[chain_i];
                const n_particles = chain.n_particles;
                const draw_positions = chain.draw_positions;
                const line_mesh_data = chain.line_mesh_data;
                let x_sum = 0;
                let y_sum = 0;

                for (let particle_i = 0; particle_i < n_particles; particle_i++) {
                    const base = chain.particle_indices[particle_i] * PARTICLE_STRIDE;
                    const base_x = particles[base + PARTICLE_X];
                    const base_y = particles[base + PARTICLE_Y];
                    const old_draw_x = particles[base + PARTICLE_DRAW_X];
                    const old_draw_y = particles[base + PARTICLE_DRAW_Y];
                    const x = old_draw_x + (base_x - old_draw_x);
                    const y = old_draw_y + (base_y - old_draw_y);

                    x_sum += x;
                    y_sum += y;
                    draw_positions[particle_i * 2] = x;
                    draw_positions[particle_i * 2 + 1] = y;
                    line_mesh_data[particle_i * 2] = x;
                    line_mesh_data[particle_i * 2 + 1] = y
                }

                line_mesh_data[n_particles * 2 + 0] = line_mesh_data[0];
                line_mesh_data[n_particles * 2 + 1] = line_mesh_data[1];

                const cx = x_sum / n_particles;
                const cy = y_sum / n_particles;
                const mesh_data = chain.mesh_data;

                for (let particle_i = 0; particle_i < n_particles; particle_i++) {
                    const a = particle_i * 2;
                    const b = ((particle_i + 1) % n_particles) * 2;
                    const ax = draw_positions[a];
                    const ay = draw_positions[a + 1];
                    const bx = draw_positions[b];
                    const by = draw_positions[b + 1];
                    const mesh_base = particle_i * 3 * MESH_VERTEX_STRIDE;

                    mesh_data[mesh_base] = cx;
                    mesh_data[mesh_base + 1] = cy;
                    mesh_data[mesh_base + MESH_VERTEX_STRIDE] = ax;
                    mesh_data[mesh_base + MESH_VERTEX_STRIDE + 1] = ay;
                    mesh_data[mesh_base + 2 * MESH_VERTEX_STRIDE] = bx;
                    mesh_data[mesh_base + 2 * MESH_VERTEX_STRIDE + 1] = by;
                }

                chain.mesh.replaceData(mesh_data);
                chain.line_mesh = MeshLine(this.context, line_mesh_data, settings.line_width);
            }
        }

        for (let chain_i = 0; chain_i < this.chains.length; chain_i++) {
            this.context.setColor(parseRGBA(
                getComputedStyle(this).getPropertyValue("--default-color-background")
            ));

            this.chains[chain_i].mesh.draw();
            this.context.setColor(parseOKLCHA(getComputedStyle(this).color).asRGBA());
            this.chains[chain_i].line_mesh.draw();
        }
    }

    private enforceExactDistance(
        ax: number, ay: number, bx: number, by: number,
        inverse_mass_a: number, inverse_mass_b: number,
        target_distance: number, alpha: number, lambda_before: number
    ): void {
        const cache = this.constraint_cache;
        const dx = bx - ax;
        const dy = by - ay;
        const length = Math.sqrt(dx * dx + dy * dy);

        if (length < EPS) {
            cache[0] = 0;
            cache[1] = 0;
            cache[2] = 0;
            cache[3] = 0;
            cache[4] = lambda_before;
            return;
        }

        const nx = dx / length;
        const ny = dy / length;
        const constraint = length - target_distance;
        const denominator = inverse_mass_a + inverse_mass_b + alpha;
        if (denominator < EPS) {
            cache[0] = 0; cache[1] = 0; cache[2] = 0; cache[3] = 0;
            cache[4] = lambda_before;
            return;
        }

        const delta_lambda = -(constraint + alpha * lambda_before) / denominator;
        cache[0] = inverse_mass_a * delta_lambda * -nx;
        cache[1] = inverse_mass_a * delta_lambda * -ny;
        cache[2] = inverse_mass_b * delta_lambda * nx;
        cache[3] = inverse_mass_b * delta_lambda * ny;
        cache[4] = lambda_before + delta_lambda;
    }

    private enforceBending(
        ax: number, ay: number,
        bx: number, by: number,
        cx: number, cy: number,
        inverse_mass_a: number, inverse_mass_b: number, inverse_mass_c: number,
        alpha: number, lambda_before: number
    ): void {
        const cache = this.constraint_cache;
        const chord_x = cx - ax;
        const chord_y = cy - ay;
        const length = Math.sqrt(chord_x * chord_x + chord_y * chord_y);
        if (length < EPS) {
            cache[0] = 0;
            cache[1] = 0;
            cache[2] = 0;
            cache[3] = 0;
            cache[4] = 0;
            cache[5] = 0;
            cache[6] = lambda_before;
            return;
        }

        const inv_length = 1 / length;
        const tx = chord_x * inv_length;
        const ty = chord_y * inv_length;
        const nx = -ty;
        const ny = tx;
        const ex = 0.5 * (ax + cx) - bx;
        const ey = 0.5 * (ay + cy) - by;
        const constraint = ex * nx + ey * ny;
        const k = (ex * tx + ey * ty) * inv_length;
        const wa = 0.5 + k;
        const wb = -1;
        const wc = 0.5 - k;
        const weight_sum = inverse_mass_a * wa * wa
            + inverse_mass_b * wb * wb
            + inverse_mass_c * wc * wc;
        const denominator = weight_sum + alpha

        if (denominator < EPS) {
            cache[0] = 0;
            cache[1] = 0;
            cache[2] = 0;
            cache[3] = 0;
            cache[4] = 0;
            cache[5] = 0;
            cache[6] = lambda_before;
            return;
        }

        const delta_lambda = -(constraint + alpha * lambda_before) / denominator;
        const sa = inverse_mass_a * delta_lambda * wa;
        const sb = inverse_mass_b * delta_lambda * wb;
        const sc = inverse_mass_c * delta_lambda * wc;
        cache[0] = sa * nx;
        cache[1] = sa * ny;
        cache[2] = sb * nx;
        cache[3] = sb * ny;
        cache[4] = sc * nx;
        cache[5] = sc * ny;
        cache[6] = lambda_before + delta_lambda;
    }

    private enforcePolygonCollision(
        position_x: number, position_y: number,
        inverse_mass: number, radius: number,
        edges: Float32Array, n_edges: number,
        alpha: number, lambda_before: number,
        keep_outside: boolean
    ): void {
        const result = this.collision_cache;
        if (inverse_mass <= 0 || n_edges === 0) {
            result[0] = 0; result[1] = 0; result[2] = lambda_before;
            return;
        }

        let min_dist_sq = Number.POSITIVE_INFINITY;
        let best_cx = position_x;
        let best_cy = position_y;
        let best_nx = 0;
        let best_ny = 0;
        let inside = false;

        for (let edge_i = 0; edge_i < n_edges; edge_i++) {
            const edge_base = edge_i * EDGE_STRIDE;
            const x1 = edges[edge_base + EDGE_X1];
            const y1 = edges[edge_base + EDGE_Y1];
            const x2 = edges[edge_base + EDGE_X2];
            const y2 = edges[edge_base + EDGE_Y2];
            const ab_x = x2 - x1;
            const ab_y = y2 - y1;
            const ab_magnitude_sq = ab_x * ab_x + ab_y * ab_y;

            let closest_x = x1;
            let closest_y = y1;
            if (ab_magnitude_sq > 0) {
                const ap_x = position_x - x1;
                const ap_y = position_y - y1;
                let t = (ap_x * ab_x + ap_y * ab_y) / ab_magnitude_sq;
                if (t < 0) t = 0;
                else if (t > 1) t = 1;
                closest_x = x1 + t * ab_x;
                closest_y = y1 + t * ab_y;
            }

            const dx = position_x - closest_x;
            const dy = position_y - closest_y;
            const dist_sq = dx * dx + dy * dy;
            if (dist_sq < min_dist_sq) {
                min_dist_sq = dist_sq;
                best_cx = closest_x;
                best_cy = closest_y;
                best_nx = edges[edge_base + EDGE_NORMAL_X];
                best_ny = edges[edge_base + EDGE_NORMAL_Y];
            }

            // even-odd
            if (((y2 > position_y) !== (y1 > position_y))
                && (position_x < (x1 - x2) * (position_y - y2) / (y1 - y2) + x2)) {
                inside = !inside;
            }
        }

        const distance = Math.sqrt(min_dist_sq);
        let signed_dist: number;
        let normal_x: number;
        let normal_y: number;

        if (keep_outside) {
            signed_dist = inside ? -distance : distance;
            normal_x = best_nx;
            normal_y = best_ny;
        } else if (inside) {
            signed_dist = distance;
            const vx = position_x - best_cx;
            const vy = position_y - best_cy;

            if (distance < EPS) {
                normal_x = best_nx;
                normal_y = best_ny;
            } else {
                normal_x = vx / distance;
                normal_y = vy / distance;
            }
        } else {
            signed_dist = -distance;
            normal_x = best_nx;
            normal_y = best_ny;
        }

        const constraint = signed_dist - radius;
        if (constraint >= 0) {
            result[0] = 0; result[1] = 0; result[2] = lambda_before;
            return;
        }

        const denominator = inverse_mass + alpha;
        if (denominator < EPS) {
            result[0] = 0; result[1] = 0; result[2] = lambda_before;
            return;
        }

        const delta_lambda = -(constraint + alpha * lambda_before) / denominator;
        const lambda_new = Math.max(lambda_before + delta_lambda, 0);
        const applied_delta_lambda = lambda_new - lambda_before;
        result[0] = inverse_mass * applied_delta_lambda * normal_x;
        result[1] = inverse_mass * applied_delta_lambda * normal_y;
        result[2] = lambda_new;
    }

    private enforceAngularMomentum(
        particles: Float32Array,
        chain: Uint32Array,
        n_particles: number,
        alpha: number,
        lambda_before: number
    ): number {
        let mass_sum = 0;
        let com_x = 0;
        let com_y = 0;
        for (let i = 0; i < n_particles; i++) {
            const base = chain[i] * PARTICLE_STRIDE;
            const mass = particles[base + PARTICLE_MASS];
            mass_sum += mass;
            com_x += mass * particles[base + PARTICLE_PREVIOUS_X];
            com_y += mass * particles[base + PARTICLE_PREVIOUS_Y];
        }
        if (mass_sum < EPS) return lambda_before;
        com_x /= mass_sum;
        com_y /= mass_sum;

        let constraint = 0;
        let weight_sum = 0;
        for (let i = 0; i < n_particles; i++) {
            const base = chain[i] * PARTICLE_STRIDE;
            const mass = particles[base + PARTICLE_MASS];
            const inverse_mass = particles[base + PARTICLE_INVERSE_MASS];
            const rx = particles[base + PARTICLE_PREVIOUS_X] - com_x;
            const ry = particles[base + PARTICLE_PREVIOUS_Y] - com_y;
            const dx = particles[base + PARTICLE_X] - particles[base + PARTICLE_PREVIOUS_X];
            const dy = particles[base + PARTICLE_Y] - particles[base + PARTICLE_PREVIOUS_Y];
            constraint += mass * (rx * dy - ry * dx);
            const gx = -mass * ry;
            const gy = mass * rx;
            weight_sum += inverse_mass * (gx * gx + gy * gy);
        }

        const denominator = weight_sum + alpha;
        if (denominator < EPS) return lambda_before;
        const delta_lambda = -(constraint + alpha * lambda_before) / denominator;
        const lambda_new = lambda_before + delta_lambda;

        for (let i = 0; i < n_particles; i++) {
            const base = chain[i] * PARTICLE_STRIDE;
            const mass = particles[base + PARTICLE_MASS];
            const inverse_mass = particles[base + PARTICLE_INVERSE_MASS];
            const rx = particles[base + PARTICLE_PREVIOUS_X] - com_x;
            const ry = particles[base + PARTICLE_PREVIOUS_Y] - com_y;
            particles[base + PARTICLE_X] += inverse_mass * delta_lambda * (-mass * ry);
            particles[base + PARTICLE_Y] += inverse_mass * delta_lambda * (mass * rx);
        }
        return lambda_new;
    }

    private enforceVolume(
        particles: Float32Array,
        chain: Uint32Array,
        n_particles: number,
        gradient_x: Float32Array,
        gradient_y: Float32Array,
        rest_area: number,
        alpha: number,
        lambda_before: number
    ): number {
        let current_area = 0;
        let weight_sum = 0;
        let previous_particle = chain[n_particles - 1];
        let current_particle = chain[0];

        for (let i = 0; i < n_particles; i++) {
            const next_particle = chain[(i + 1) % n_particles];
            const previous_base = previous_particle * PARTICLE_STRIDE;
            const current_base = current_particle * PARTICLE_STRIDE;
            const next_base = next_particle * PARTICLE_STRIDE;

            const previous_x = particles[previous_base + PARTICLE_X];
            const previous_y = particles[previous_base + PARTICLE_Y];
            const current_x = particles[current_base + PARTICLE_X];
            const current_y = particles[current_base + PARTICLE_Y];
            const next_x = particles[next_base + PARTICLE_X];
            const next_y = particles[next_base + PARTICLE_Y];

            current_area += 0.5 * (current_x * next_y - next_x * current_y);
            const grad_x = 0.5 * (next_y - previous_y);
            const grad_y = 0.5 * (previous_x - next_x);
            gradient_x[i] = grad_x;
            gradient_y[i] = grad_y;
            const inverse_mass = particles[current_base + PARTICLE_INVERSE_MASS];
            weight_sum += inverse_mass * (grad_x * grad_x + grad_y * grad_y);

            previous_particle = current_particle;
            current_particle = next_particle;
        }

        const constraint = current_area - rest_area;
        const denominator = weight_sum + alpha;
        if (denominator < EPS) return lambda_before;
        const delta_lambda = -(constraint + alpha * lambda_before) / denominator;
        const lambda_new = lambda_before + delta_lambda;

        for (let i = 0; i < n_particles; i++) {
            const base = chain[i] * PARTICLE_STRIDE;
            const inverse_mass = particles[base + PARTICLE_INVERSE_MASS];
            particles[base + PARTICLE_X] += inverse_mass * delta_lambda * gradient_x[i];
            particles[base + PARTICLE_Y] += inverse_mass * delta_lambda * gradient_y[i];
        }
        return lambda_new;
    }


    private updateChainCollisionContour(chain_data: SoftBodyChain): void {
        const particles = this.particles;
        const chain = chain_data.particle_indices;
        const n_particles = chain_data.n_particles;
        const edges = chain_data.collision_edges;
        let signed_area = 0;

        for (let i = 0; i < n_particles; i++) {
            const ai = chain[i] * PARTICLE_STRIDE;
            const bi = chain[(i + 1) % n_particles] * PARTICLE_STRIDE;
            const ax = particles[ai + PARTICLE_X];
            const ay = particles[ai + PARTICLE_Y];
            const bx = particles[bi + PARTICLE_X];
            const by = particles[bi + PARTICLE_Y];
            signed_area += 0.5 * (ax * by - bx * ay);
        }

        const orientation = signed_area >= 0 ? 1 : -1;
        let n_edges = 0;
        for (let i = 0; i < n_particles; i++) {
            const ai = chain[i] * PARTICLE_STRIDE;
            const bi = chain[(i + 1) % n_particles] * PARTICLE_STRIDE;
            const x1 = particles[ai + PARTICLE_X];
            const y1 = particles[ai + PARTICLE_Y];
            const x2 = particles[bi + PARTICLE_X];
            const y2 = particles[bi + PARTICLE_Y];
            const dx = x2 - x1;
            const dy = y2 - y1;
            const magnitude = Math.sqrt(dx * dx + dy * dy);
            if (magnitude <= EPS) continue;

            const edge_base = n_edges * EDGE_STRIDE;
            edges[edge_base + EDGE_X1] = x1;
            edges[edge_base + EDGE_Y1] = y1;
            edges[edge_base + EDGE_X2] = x2;
            edges[edge_base + EDGE_Y2] = y2;
            edges[edge_base + EDGE_NORMAL_X] = orientation * dy / magnitude;
            edges[edge_base + EDGE_NORMAL_Y] = -orientation * dx / magnitude;
            n_edges++;
        }
        chain_data.n_collision_edges = n_edges;
    }

    protected override update(time_delta: Time): void {
        if (getIsAnimationPaused()) return;

        const delta = time_delta.asSeconds();
        const n_sub_steps = settings.n_sub_steps;
        const n_constraint_iterations = settings.n_constraint_iterations;
        const sub_delta = delta / n_sub_steps;
        const sub_delta_sq = sub_delta * sub_delta;
        const volume_alpha = settings.volume_compliance / sub_delta_sq;
        const line_alpha = settings.line_compliance / sub_delta_sq;
        const distance_alpha = settings.distance_compliance / sub_delta_sq;
        const bending_alpha = settings.bending_compliance / sub_delta_sq;
        const angular_alpha = settings.angular_compliance / sub_delta_sq;
        const particle_collision_alpha = settings.particle_collision_compliance / sub_delta_sq;

        const particles = this.particles;
        const n_particles = this.n_particles;
        const chains = this.chains;
        const edges = this.polygon_edges;
        const n_edges = this.n_polygon_edges;
        const gravity = settings.gravity;
        const damping = settings.damping;
        const result = this.constraint_cache;
        const collision_result = this.collision_cache;

        for (let particle_i = 0; particle_i < n_particles; particle_i++) {
            const base = particle_i * PARTICLE_STRIDE;
            particles[base + PARTICLE_DRAW_X] = particles[base + PARTICLE_X];
            particles[base + PARTICLE_DRAW_Y] = particles[base + PARTICLE_Y];
        }

        for (let sub_step = 0; sub_step < n_sub_steps; sub_step++) {

            // pre-solve
            for (let particle_i = 0; particle_i < n_particles; particle_i++) {
                const base = particle_i * PARTICLE_STRIDE;
                const position_x = particles[base + PARTICLE_X];
                const position_y = particles[base + PARTICLE_Y];
                const velocity_x = particles[base + PARTICLE_VELOCITY_X];
                const velocity_y = particles[base + PARTICLE_VELOCITY_Y];
                const mass = particles[base + PARTICLE_MASS];
                const new_velocity_x = velocity_x * damping;
                const new_velocity_y = velocity_y * damping + mass * gravity * sub_delta;
                particles[base + PARTICLE_X] = position_x + new_velocity_x * sub_delta;
                particles[base + PARTICLE_Y] = position_y + new_velocity_y * sub_delta;
                particles[base + PARTICLE_VELOCITY_X] = new_velocity_x;
                particles[base + PARTICLE_VELOCITY_Y] = new_velocity_y;
                particles[base + PARTICLE_PREVIOUS_X] = position_x;
                particles[base + PARTICLE_PREVIOUS_Y] = position_y;
                particles[base + PARTICLE_DISTANCE_LAMBDA] = 0;
                particles[base + PARTICLE_BENDING_LAMBDA] = 0;
                particles[base + PARTICLE_POLYGON_LAMBDA] = 0;
            }

            for (let chain_i = 0; chain_i < chains.length; chain_i++) {
                const chain = chains[chain_i];
                chain.volume_lambda = 0;
                chain.angular_lambda = 0;
                chain.inter_chain_lambda.fill(0);
            }

            for (let iteration = 0; iteration < n_constraint_iterations; iteration++) {
                for (let chain_i = 0; chain_i < chains.length; chain_i++) {
                    const chain_data = chains[chain_i];
                    const chain = chain_data.particle_indices;
                    const n_chain = chain_data.n_particles;
                    const segment_length = chain_data.segment_length;

                    // distance pairs
                    for (let chain_i2 = 0; chain_i2 < n_chain; chain_i2++) {
                        const ai = chain[chain_i2];
                        const bi = chain[(chain_i2 + 1) % n_chain];
                        const a = ai * PARTICLE_STRIDE;
                        const b = bi * PARTICLE_STRIDE;
                        this.enforceExactDistance(
                            particles[a + PARTICLE_X], particles[a + PARTICLE_Y],
                            particles[b + PARTICLE_X], particles[b + PARTICLE_Y],
                            particles[a + PARTICLE_INVERSE_MASS], particles[b + PARTICLE_INVERSE_MASS],
                            segment_length, distance_alpha, particles[a + PARTICLE_DISTANCE_LAMBDA]
                        );
                        particles[a + PARTICLE_X] += result[0];
                        particles[a + PARTICLE_Y] += result[1];
                        particles[b + PARTICLE_X] += result[2];
                        particles[b + PARTICLE_Y] += result[3];
                        particles[a + PARTICLE_DISTANCE_LAMBDA] = result[4];
                    }

                    // bending triplets
                    for (let chain_i2 = 0; chain_i2 < n_chain; chain_i2++) {
                        const ai = chain[chain_i2];
                        const bi = chain[(chain_i2 + 1) % n_chain];
                        const ci = chain[(chain_i2 + 2) % n_chain];
                        const a = ai * PARTICLE_STRIDE;
                        const b = bi * PARTICLE_STRIDE;
                        const c = ci * PARTICLE_STRIDE;
                        this.enforceBending(
                            particles[a + PARTICLE_X], particles[a + PARTICLE_Y],
                            particles[b + PARTICLE_X], particles[b + PARTICLE_Y],
                            particles[c + PARTICLE_X], particles[c + PARTICLE_Y],
                            particles[a + PARTICLE_INVERSE_MASS],
                            particles[b + PARTICLE_INVERSE_MASS],
                            particles[c + PARTICLE_INVERSE_MASS],
                            bending_alpha, particles[a + PARTICLE_BENDING_LAMBDA]
                        );
                        particles[a + PARTICLE_X] += result[0];
                        particles[a + PARTICLE_Y] += result[1];
                        particles[b + PARTICLE_X] += result[2];
                        particles[b + PARTICLE_Y] += result[3];
                        particles[c + PARTICLE_X] += result[4];
                        particles[c + PARTICLE_Y] += result[5];
                        particles[a + PARTICLE_BENDING_LAMBDA] = result[6];
                    }

                    // volume
                    chain_data.volume_lambda = this.enforceVolume(
                        particles,
                        chain,
                        n_chain,
                        chain_data.volume_gradient_x,
                        chain_data.volume_gradient_y,
                        chain_data.rest_volume,
                        volume_alpha,
                        chain_data.volume_lambda
                    );

                    // rotation
                    chain_data.angular_lambda = this.enforceAngularMomentum(
                        particles, chain, n_chain, angular_alpha, chain_data.angular_lambda
                    );
                }
            }

            // polygon collision
            for (let iteration = 0; iteration < n_constraint_iterations; iteration++) {
                for (let chain_i = 0; chain_i < chains.length; chain_i++) {
                    this.updateChainCollisionContour(chains[chain_i]);
                }

                for (let chain_i = 0; chain_i < chains.length; chain_i++) {
                    const chain_data = chains[chain_i];
                    const other_chain = chains[(chain_i + 1) % chains.length];
                    const chain = chain_data.particle_indices;

                    for (let chain_particle_i = 0; chain_particle_i < chain_data.n_particles; chain_particle_i++) {
                        const particle_base = chain[chain_particle_i] * PARTICLE_STRIDE;
                        let x = particles[particle_base + PARTICLE_X];
                        let y = particles[particle_base + PARTICLE_Y];
                        const inverse_mass = particles[particle_base + PARTICLE_INVERSE_MASS];
                        const radius = particles[particle_base + PARTICLE_RADIUS];

                        this.enforcePolygonCollision(
                            x, y, inverse_mass, radius,
                            edges, n_edges, line_alpha,
                            particles[particle_base + PARTICLE_POLYGON_LAMBDA], false
                        );
                        x += collision_result[0];
                        y += collision_result[1];
                        particles[particle_base + PARTICLE_POLYGON_LAMBDA] = collision_result[2];

                        this.enforcePolygonCollision(
                            x, y, inverse_mass, radius,
                            other_chain.collision_edges, other_chain.n_collision_edges,
                            particle_collision_alpha,
                            chain_data.inter_chain_lambda[chain_particle_i], true
                        );
                        x += collision_result[0];
                        y += collision_result[1];
                        chain_data.inter_chain_lambda[chain_particle_i] = collision_result[2];

                        particles[particle_base + PARTICLE_X] = x;
                        particles[particle_base + PARTICLE_Y] = y;
                    }
                }
            }

            // post-solve
            for (let particle_i = 0; particle_i < n_particles; particle_i++) {
                const base = particle_i * PARTICLE_STRIDE;
                particles[base + PARTICLE_VELOCITY_X] =
                    (particles[base + PARTICLE_X] - particles[base + PARTICLE_PREVIOUS_X]) / sub_delta;
                particles[base + PARTICLE_VELOCITY_Y] =
                    (particles[base + PARTICLE_Y] - particles[base + PARTICLE_PREVIOUS_Y]) / sub_delta;
            }
        }

        this.mesh_data_needs_update = true;
    }
}
