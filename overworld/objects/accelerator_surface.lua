require "overworld.movable_object"

rt.settings.overworld.accelerator_surface = {
    particle = {
        max_n_particles_per_second = 120,
        min_speed = 100,
        max_speed = 200,
        min_lifetime = 0.5,
        max_lifetime = 1.5,
        attack = 0.05,
        decay = 1 - 0.05 - 0.4,
        min_scale = 0.1,
        max_scale = 0.4,
        deceleration = 0.985,
        max_n_particles = 1024
    },

    outline_width = 2,
}

--- @class ow.AcceleratorSurface
--- @types Polygon, Rectangle
--- @field friction Number? defaults to -1, negative friction speeds up player
ow.AcceleratorSurface = meta.class("AcceleratorSurface", ow.MovableObject)

local _particle_texture, _particle_quads = nil, {}

-- init particle meshes
local _vertex_counts = {}
do
    for _ = 1, 1 do table.insert(_vertex_counts, 3) end
    for _ = 1, 2 do table.insert(_vertex_counts, 4) end
    for _ = 1, 4 do table.insert(_vertex_counts, 5) end
    for _ = 1, 3 do table.insert(_vertex_counts, 6) end
    for _ = 1, 2 do table.insert(_vertex_counts, 7) end
end

local _body_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 0 })
local _outline_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 1 })
local _particle_shader = rt.Shader("overworld/objects/accelerator_surface.glsl", { MODE = 2 })

local _noise_texture = rt.NoiseTexture(64, 64, 16,
    rt.NoiseType.GRADIENT, 6
)

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    -- inject global particle count into stage
    if self._stage.accelerator_total_n_particles == nil then
        self._stage.accelerator_total_n_particles = 0
    end

    if _particle_texture == nil then
        love.graphics.push("all")
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)

        local radius = 30
        local padding = 5
        local max_offset = 10
        local frame_w = 2 * radius + 2 * padding + 2 * max_offset
        local frame_h = frame_w

        local n_frames = #_vertex_counts
        local canvas_w = frame_w * n_frames
        local canvas_h = frame_h

        _particle_texture = rt.RenderTexture(canvas_w, canvas_h, 4)

        local frame_i = 1
        local center_x, center_y = 0.5 * frame_w, 0.5 * frame_h
        for n_vertices in values(_vertex_counts) do
            local vertices = {}
            local centroid_x, centroid_y = 0, 0
            for i = 1, n_vertices do
                local angle = (i - 1) * (2 * math.pi) / n_vertices
                local length = radius + rt.random.number(-1, 1) * max_offset
                local dx, dy = math.cos(angle) * length, math.sin(angle) * length
                table.insert(vertices, dx)
                table.insert(vertices, dy)
                centroid_x = centroid_x + dx
                centroid_y = centroid_y + dy
            end

            centroid_x = centroid_x / n_vertices
            centroid_y = centroid_y / n_vertices

            local x, y = (frame_i - 1) * frame_w, 0
            local quad = love.graphics.newQuad(
                x, y,
                frame_w, frame_h,
                canvas_w, canvas_h
            )

            table.insert(_particle_quads, quad)

            local line_vertices = table.deepcopy(vertices)
            table.insert(line_vertices, vertices[1])
            table.insert(line_vertices, vertices[2])

            love.graphics.push("all")
            local line_width = 6
            love.graphics.setLineWidth(line_width)
            love.graphics.setLineStyle("smooth")
            love.graphics.setLineJoin("none")

            _particle_texture:bind()
            love.graphics.translate(x + center_x - centroid_x, y + center_y - centroid_y)
            love.graphics.setColor(0, 0, 0, 1);
            love.graphics.polygon("fill", vertices)
            love.graphics.setColor(1, 1, 1, 1)
            for i = 1, #line_vertices, 2 do
                love.graphics.circle("fill", line_vertices[i+0], line_vertices[i+1], 0.5 * line_width)
            end
            love.graphics.line(line_vertices)
            _particle_texture:unbind()
            love.graphics.pop()

            frame_i = frame_i + 1
        end

        love.graphics.pop()
    end

    -- Create a per-instance spritebatch (texture is shared)
    self._particle_spritebatch = love.graphics.newSpriteBatch(
        _particle_texture:get_native(),
        rt.settings.overworld.accelerator_surface.particle.max_n_particles,
        "stream"
    )

    self._scene = scene
    self._stage = stage
    self._elapsed_offset = rt.random.number(-1000, 1000)
    self._particle_data = {}
    self._particle_elapsed = 0
    self._stale_particle_indices = {}

    self._n_particles = 0

    self._is_visible = object:get_boolean("is_visible", false)
    if self._is_visible == nil then self._is_visible = true end

    -- physics

    self._body = object:create_physics_body(
        stage:get_physics_world(),
        b2.BodyType.KINEMATIC
    )

    self._body:add_tag(
        "use_friction",
        "stencil",
        "slippery"
    )

    self._body:set_friction(object:get_number("friction") or -1)
    self._body:set_user_data(self)
    self._body:set_collides_with(bit.bor(
        rt.settings.player.player_collision_group,
        rt.settings.player.player_outer_body_collision_group
    ))

    local x, y = self._body:get_position()

    local _, tris, mesh_data
    _, tris, mesh_data = object:create_mesh()

    for i, data in ipairs(mesh_data) do
        data[1] = data[1] - x
        data[2] = data[2] - y
    end

    -- mesh

    if not self._is_visible then return end

    self._contour = rt.contour.round(object:create_contour(), 10)
    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)

    local contour = object:create_contour()
    for i = 1, #contour, 2 do
        contour[i+0] = contour[i+0] - x
        contour[i+1] = contour[i+1] - y
    end
    self._outline = contour

    table.insert(self._outline, self._outline[1])
    table.insert(self._outline, self._outline[2])
end

local function _get_friction(nx, ny, vx, vy)
    local dot = vx * nx + vy * ny
    local tangent_vx = vx - dot * nx
    local tangent_vy = vy - dot * ny

    if math.magnitude(tangent_vx, tangent_vy) == 0 then
        return 0, 0
    end

    return -tangent_vx, -tangent_vy
end

local _x_offset = 0
local _y_offset = 1
local _velocity_x_offset = 2
local _velocity_y_offset = 3
local _velocity_magnitude_offset = 4
local _elapsed_offset = 5
local _lifetime_offset = 6
local _scale_offset = 7
local _angle_offset = 8
local _quad_i_offset = 9
local _is_stale_offset = 10

local _stride = _is_stale_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1
end

local _is_stale = 0
local _is_not_stale = 1

function ow.AcceleratorSurface:update(delta)
    if not self._is_visible or (not self._stage:get_is_body_visible(self._body) and self._n_particles == 0) then return end

    local settings = rt.settings.overworld.accelerator_surface.particle

    local player = self._scene:get_player()
    local data = self._particle_data

    local n_particles_before = self._n_particles

    if player:get_is_colliding_with(self._body) == true then
        self._particle_elapsed = self._particle_elapsed + delta
        local normal_x, normal_y = player:get_collision_normal(self._body)
        local velocity_x, velocity_y = player:get_physics_body():get_velocity()
        local dx, dy = _get_friction(normal_x, normal_y, velocity_x, velocity_y)
        local px, py = player:get_contact_point(self._body)

        local t = math.min(math.magnitude(dx, dy) / 800, 1)
        local n_particle_per_second = math.mix(0, settings.max_n_particles_per_second, rt.InterpolationFunctions.SQUARE_ACCELERATION(t))
        local step = 1 / n_particle_per_second

        dx, dy = math.normalize(dx, dy)

        local player_radius = rt.settings.player.radius * 2.5
        px, py = px + dx * player_radius, py + dy * player_radius

        dx, dy = math.mix2(dx, dy, normal_x, normal_y, 0.5)

        while self._particle_elapsed > step do
            local i = #data + 1
            data[i + _x_offset] = px
            data[i + _y_offset] = py
            data[i + _velocity_x_offset] = dx
            data[i + _velocity_y_offset] = dy
            data[i + _velocity_magnitude_offset] = rt.random.number(settings.min_speed, settings.max_speed)
            data[i + _elapsed_offset] = 0
            data[i + _lifetime_offset] = rt.random.number(settings.min_lifetime, settings.max_lifetime)
            data[i + _scale_offset] = rt.random.number(settings.min_scale, settings.max_scale * t)
            data[i + _angle_offset] = rt.random.number(0, 2 * math.pi)
            data[i + _quad_i_offset] = rt.random.integer(1, #_particle_quads)
            data[i + _is_stale_offset] = _is_not_stale

            self._particle_elapsed = self._particle_elapsed - step
            self._n_particles = self._n_particles + 1
            self._stage.accelerator_total_n_particles = self._stage.accelerator_total_n_particles + 1
        end
    end

    -- per-instance spritebatch
    self._particle_spritebatch:clear()
    local frame_h = _particle_texture:get_height()

    local aabb = self._scene:get_camera():get_world_bounds()
    local x, y, w, h = aabb:unpack()

    -- particle start out transparent, so they don't need to be added to the
    -- spritebatch this frame, and they don't need to be updated
    for particle_i = 1, n_particles_before do
        local i = _particle_i_to_data_offset(particle_i)
        local is_stale = data[i + _is_stale_offset] == _is_stale
        if not is_stale then
            local px, py = data[i + _x_offset], data[i + _y_offset]
            if data[i + _elapsed_offset] > data[i + _lifetime_offset]
                or not (px >= x and px <= x + w and py >= y and py <= y + h)
            then
                data[i + _is_stale_offset] = _is_stale
                data[i + _elapsed_offset] = math.huge
                is_stale = true
                table.insert(self._stale_particle_indices, particle_i)
            else
                data[i + _x_offset] = data[i + _x_offset] + data[i + _velocity_x_offset] * data[i + _velocity_magnitude_offset] * delta
                data[i + _y_offset] = data[i + _y_offset] + data[i + _velocity_y_offset] * data[i + _velocity_magnitude_offset] * delta
                data[i + _elapsed_offset] = data[i + _elapsed_offset] + delta
                data[i + _velocity_magnitude_offset] = data[i + _velocity_magnitude_offset] * settings.deceleration
            end
        end

        if not is_stale then
            local alpha = rt.InterpolationFunctions.ENVELOPE(
                data[i + _elapsed_offset] / data[i + _lifetime_offset],
                rt.settings.overworld.accelerator_surface.particle.attack,
                rt.settings.overworld.accelerator_surface.particle.decay
            )

            if alpha > math.eps then
                self._particle_spritebatch:setColor(1, 1, 1, alpha)
                self._particle_spritebatch:add(
                    _particle_quads[data[i + _quad_i_offset]],
                    data[i + _x_offset],
                    data[i + _y_offset],
                    data[i + _angle_offset],
                    data[i + _scale_offset],
                    data[i + _scale_offset],
                    0.5 * frame_h,
                    0.5 * frame_h
                )
            end
        end
    end

    -- reduce number if overwhelmed, use oldest particles at the start first
    for particle_i = 1, math.max(0, self._stage.accelerator_total_n_particles - settings.max_n_particles) do
        table.insert(self._stale_particle_indices, particle_i)
    end

    -- periodically remove stale particles
    if #self._stale_particle_indices > 32 then
        table.sort(self._stale_particle_indices, function(a, b) return a > b end)

        local n_removed = 0
        for _, particle_i in ipairs(self._stale_particle_indices) do
            local i = _particle_i_to_data_offset(particle_i)
            for _ = 1, _stride do
                table.remove(data, i)
            end
            n_removed = n_removed + 1
        end

        self._n_particles = self._n_particles - n_removed
        self._stage.accelerator_total_n_particles = self._stage.accelerator_total_n_particles - n_removed
        table.clear(self._stale_particle_indices)
    end
end

local base_priority = 0
local particle_priority = math.huge

--- @brief
function ow.AcceleratorSurface:draw(priority)
    local offset_x, offset_y = self._body:get_position()
    love.graphics.setColor(1, 1, 1, 1)
    local camera = self._scene:get_camera()
    local transform = self._scene:get_camera():get_transform()
    transform:translate(offset_x, offset_y)
    transform = transform:inverse()

    if priority == base_priority then
        if not self._is_visible or not self._stage:get_is_body_visible(self._body) then return end

        love.graphics.push()
        love.graphics.translate(offset_x, offset_y)

        local camera_bounds = camera:get_world_bounds()

        _body_shader:bind()
        _body_shader:send("screen_to_world_transform", transform)
        _body_shader:send("elapsed", rt.SceneManager:get_elapsed() + self._elapsed_offset)
        _body_shader:send("camera_position", { camera_bounds.x + camera_bounds.width * 0.5, camera_bounds.y + camera_bounds.height * 0.5})
        _body_shader:send("player_position", { camera:world_xy_to_screen_xy(self._scene:get_player():get_position()) })
        _body_shader:send("player_hue", self._scene:get_player():get_hue())
        love.graphics.push()
        self._mesh:draw()
        love.graphics.pop()
        _body_shader:unbind()

        _outline_shader:bind()
        _outline_shader:send("noise_texture", _noise_texture)
        _outline_shader:send("screen_to_world_transform", transform)
        _outline_shader:send("elapsed", rt.SceneManager:get_elapsed())
        _outline_shader:send("player_position", { camera:world_xy_to_screen_xy(self._scene:get_player():get_position()) })
        _outline_shader:send("player_hue", self._scene:get_player():get_hue())
        love.graphics.setLineWidth(rt.settings.overworld.accelerator_surface.outline_width)
        love.graphics.line(self._outline)
        _outline_shader:unbind()

        love.graphics.pop()
    elseif priority == particle_priority then
        _particle_shader:bind()
        _particle_shader:send("noise_texture", _noise_texture)
        _particle_shader:send("screen_to_world_transform", transform)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self._particle_spritebatch)
        _particle_shader:unbind()
    end
end

--- @brief
function ow.AcceleratorSurface:draw_bloom(priority)
    if not self._is_visible or not self._stage:get_is_body_visible(self._body) or priority ~= base_priority then return end

    love.graphics.push()
    local offset_x, offset_y = self._body:get_position()
    love.graphics.translate(offset_x, offset_y)

    love.graphics.setColor(1, 1, 1, 1)
    _outline_shader:bind()
    _outline_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _outline_shader:send("camera_scale", self._scene:get_camera():get_scale())
    _outline_shader:send("elapsed", rt.SceneManager:get_elapsed())
    love.graphics.setLineWidth(rt.settings.overworld.accelerator_surface.outline_width)
    love.graphics.line(self._outline)
    _outline_shader:unbind()

    love.graphics.pop()
end

--- @brief
function ow.AcceleratorSurface:get_render_priority()
    return base_priority, particle_priority
end

--- @brief
function ow.AcceleratorSurface:reset()
    self._particles = {}
end