rt.settings.overworld.accelerator_surface = {
    particle = {
        max_n_particles_per_second = 120,
        min_speed = 100,
        max_speed = 200,
        min_lifetime = 0.5,
        max_lifetime = 1.5,
        attack = 0.05,
        sustain = 0.4,
        min_scale = 0.1,
        max_scale = 0.4,
        deceleration = 0.985
    }
}

--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _particle_texture, _particle_quads = nil, {}
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

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
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
                local angle = (i - 1) *  (2 * math.pi) / n_vertices
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

            love.graphics.push()
            _particle_texture:bind()
            love.graphics.translate(x + center_x - centroid_x, y + center_y - centroid_y)
            love.graphics.polygon("fill", vertices)
            _particle_texture:unbind()
            love.graphics.pop()

            frame_i = frame_i + 1
        end

        love.graphics.pop()
    end

    self._scene = scene
    self._elapsed = 0
    self._particles = {}
    self._particle_elapsed = 0

    -- mesh
    self._contour = rt.round_contour(object:create_contour(), 10)
    self._mesh = object:create_mesh()
    self._body = object:create_physics_body(stage:get_physics_world())

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

    self._mesh = object:create_mesh()
    self._outline = object:create_contour()

    table.insert(self._outline, self._outline[1])
    table.insert(self._outline, self._outline[2])
end

function _get_friction(nx, ny, vx, vy)
    local dot = vx * nx + vy * ny
    local tangent_vx = vx - dot * nx
    local tangent_vy = vy - dot * ny

    if math.magnitude(tangent_vx, tangent_vy) == 0 then
        return 0, 0
    end

    return -tangent_vx, -tangent_vy
end

local _x = 1
local _y = 2
local _velocity_x = 3
local _velocity_y = 4
local _velocity_magnitude = 5
local _elapsed = 6
local _lifetime = 7
local _scale = 8
local _angle = 9
local _quad = 10

local _total_n_particles = 0
local _max_n_particles = 1000

--- @brief
function ow.AcceleratorSurface:update(delta)
    if not self._scene:get_is_body_visible(self._body) then
        self._particles = {}
        return
    end

    local settings = rt.settings.overworld.accelerator_surface.particle

    local player = self._scene:get_player()
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

        local player_radius = rt.settings.player.radius * 2
        px, py = px + dx * player_radius, py + dy * player_radius

        dx, dy = math.mix2(dx, dy, normal_x, normal_y, 0.5)

        while self._particle_elapsed > step do
            local particle = {
                [_x] = px,
                [_y] = py,
                [_velocity_x] = dx,
                [_velocity_y] = dy,
                [_velocity_magnitude] = rt.random.number(settings.min_speed, settings.max_speed),
                [_elapsed] = 0,
                [_lifetime] = rt.random.number(settings.min_lifetime, settings.max_lifetime),
                [_scale] = rt.random.number(settings.min_scale, settings.max_scale * t),
                [_angle] = rt.random.number(0, 2 * math.pi),
                [_quad] = rt.random.choose(_particle_quads),
            }

            table.insert(self._particles, particle)
            self._particle_elapsed = self._particle_elapsed - step
            _total_n_particles = _total_n_particles + 1
        end
    end

    local aabb = self._scene:get_camera():get_world_bounds()

    local to_remove = {}
    for i, particle in ipairs(self._particles) do
        particle[_x] = particle[_x] + particle[_velocity_x] * particle[_velocity_magnitude] * delta
        particle[_y] = particle[_y] + particle[_velocity_y] * particle[_velocity_magnitude] * delta
        particle[_elapsed] = particle[_elapsed] + delta
        particle[_velocity_magnitude] = particle[_velocity_magnitude] * settings.deceleration
        if _total_n_particles > _max_n_particles or not aabb:contains(particle[_x], particle[_y]) or particle[_elapsed] > particle[_lifetime] then
            table.insert(to_remove, i)
            _total_n_particles = _total_n_particles - 1
        end
    end

    if #to_remove > 0 then
        table.sort(to_remove, function(a, b) return a > b end)
        for i in values(to_remove) do
            table.remove(self._particles, i)
        end
    end
end

--- @brief
function ow.AcceleratorSurface:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    local outline_width = 2
    local outline_color = rt.Palette.GRAY_3;
    love.graphics.setColor(1, 1, 1, 1)

    local offset_x, offset_y = self._scene:get_camera():get_offset()

    _body_shader:bind()
    _body_shader:send("camera_offset", { offset_x, offset_y })
    _body_shader:send("camera_scale", self._scene:get_camera():get_scale())
    _body_shader:send("player_position", { self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_position()) })
    _body_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _body_shader:send("player_hue", self._scene:get_player():get_hue())
    love.graphics.push()
    self._mesh:draw()
    love.graphics.pop()
    _body_shader:unbind()

    outline_color:bind()
    _outline_shader:bind()
    _outline_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _outline_shader:send("camera_scale", self._scene:get_camera():get_scale())
    _outline_shader:send("player_position", { self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_position()) })
    _outline_shader:send("elapsed", rt.SceneManager:get_elapsed())
    love.graphics.setLineWidth(outline_width)
    love.graphics.line(self._outline)
    _outline_shader:unbind()

    _particle_shader:bind()
    _particle_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _particle_shader:send("camera_scale", self._scene:get_camera():get_scale())

    local frame_h = _particle_texture:get_height()
    local texture = _particle_texture:get_native()

    love.graphics.push()
    for particle in values(self._particles) do
        love.graphics.setColor(
            1, 1, 1,
            rt.InterpolationFunctions.ENVELOPE(
                particle[_elapsed] / particle[_lifetime],
                rt.settings.overworld.accelerator_surface.particle.attack,
                rt.settings.overworld.accelerator_surface.particle.sustain
            )
        )

        love.graphics.draw(texture, particle[_quad],
            particle[_x], particle[_y],
            particle[_angle],
            particle[_scale], particle[_scale],
            0.5 * frame_h, 0.5 * frame_h
        )
    end
    love.graphics.pop()

    _particle_shader:unbind()
end
