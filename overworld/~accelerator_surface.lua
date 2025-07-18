require "common.contour"

rt.settings.overworld.accelerator_surface = {
    -- base
    segment_length = 10,

    -- particles
    canvas_w = 15,
    max_angle_offset = 0.1 * math.pi,
    max_hue_offset = 0.4,
    min_lifetime = 1,
    max_lifetime = 3,
    max_n_particles = 1000, -- global limit
    min_scale = 0.4,
    max_scale = 1,
    min_n_particles_per_second = 40,
    max_n_particles_per_second = 80,
    min_speed = 10,
    max_speed = 30,
    min_velocity_threshold = 50
}

--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _base_shader, _outline_shader

-- particles
local _particle_texture
local _particle_left, _particle_right = 1, 2
local _particle_which_to_quad = {}

-- particle buffer indices
local _position_x = 1
local _position_y = 2
local _velocity_x = 3
local _velocity_y = 4
local _r = 5
local _g = 6
local _b = 7
local _elapsed = 8
local _scale = 9
local _lifetime = 10
local _quad = 11

-- shape mesh data members
local _origin_x_index = 1
local _origin_y_index = 2
local _dx_index = 3
local _dy_index = 4
local _magnitude_index = 5

-- data mesh members
local _scale_index = 1

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    if _base_shader == nil then _base_shader = rt.Shader("overworld/objects/accelerator_surface_base.glsl") end
    if _outline_shader == nil then _outline_shader = rt.Shader("overworld/objects/accelerator_surface_outline.glsl") end

    self._scene = scene

    -- construct mesh
    self._contour = object:create_contour()
    local shapes, tris = {}, {}

    self._contour = rt.subdivide_contour(self._contour, rt.settings.overworld.accelerator_surface.segment_length)

    local slick = require "dependencies.slick.slick"
    for shape in values(slick.polygonize(6, { self._contour })) do
        table.insert(shapes, b2.Polygon(shape))
    end

    local triangulation = rt.DelaunayTriangulation(self._contour, self._contour):get_triangle_vertex_map()

    local center_x, center_y, n = 0, 0, 0
    for i = 1, #self._contour, 2 do
        local x, y = self._contour[i], self._contour[i+1]
        center_x = center_x + x
        center_y = center_y + y
        n = n + 1
    end

    center_x = center_x / n
    center_y = center_y / n

    local shape_mesh_format = {
        { location = 0, name = "origin", format = "floatvec2" }, -- absolute xy
        { location = 1, name = "contour_vector", format = "floatvec3" } -- normalized xy, magnitude
    }

    local data_mesh_format = {
        { location = 2, name = "scale", format = "float" }
    }

    self._shape_mesh_data = {}
    self._data_mesh_data = {}

    -- construct contour vectors
    local target_magnitude = 100
    for i = 1, #self._contour, 2 do
        local x, y = self._contour[i+0], self._contour[i+1]
        local origin_x, origin_y = center_x, center_y
        local dx = x - origin_x
        local dy = y - origin_y

        -- rescale origin such that each point has same magnitude, while
        -- mainting end point x, y
        dx, dy = math.normalize(dx, dy)
        local magnitude = target_magnitude
        origin_x = x - dx * magnitude
        origin_y = y - dy * magnitude

        table.insert(self._shape_mesh_data, {
            [_origin_x_index] = origin_x,
            [_origin_y_index] = origin_y,
            [_dx_index] = dx,
            [_dy_index] = dy,
            [_magnitude_index] = magnitude
        })

        table.insert(self._data_mesh_data, {
            [_scale_index] = 1
        })
    end

    self._contour_center_x, self._contour_center_y = center_x, center_y
    table.insert(self._contour, self._contour[1])
    table.insert(self._contour, self._contour[2])

    self._shape_mesh = rt.Mesh(
        self._shape_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        shape_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )
    self._shape_mesh:set_vertex_map(triangulation)

    self._data_mesh = rt.Mesh(
        self._data_mesh_data,
        rt.MeshDrawMode.POINTS,
        data_mesh_format,
        rt.GraphicsBufferUsage.DYNAMIC
    )
    self._shape_mesh:attach_attribute(self._data_mesh, "scale", "pervertex")

    -- collision
    self._body = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, 0, 0, shapes)

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

    self._should_emit = object:get_boolean("should_emit")
    if self._should_emit == nil then self._should_emit = true end

    self._is_active = false
    self._body:signal_connect("collision_start", function()
        self._is_active = true
        self:update(0)
    end)

    self._particle_emission_elapsed = 0
    self._emission_x, self._emission_y = 0, 0
    self._emission_nx, self._emission_ny = 0, 0

    -- setup particle texture
    -- all particles use same texture, for batched draws
    if _particle_texture == nil then
        local padding = 5
        local canvas_w = rt.settings.overworld.accelerator_surface.canvas_w * rt.get_pixel_scale()
        _particle_texture = rt.RenderTexture(2 * (canvas_w + 2 * padding), canvas_w + 2 * padding)
        _particle_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
        local left_x = padding + 0.5 * canvas_w
        local right_x = padding + canvas_w + padding + padding + 0.5 * canvas_w
        local y = 0.5 * (canvas_w + padding)

        _particle_texture:bind()

        -- left_particle
        local mesh = rt.MeshCircle(0, 0, 0.5 * canvas_w)
        for i = 2, mesh:get_n_vertices() do
            mesh:set_vertex_color(i, 1, 1, 1, 0.5)
        end

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(mesh:get_native(), left_x, y)

        _particle_which_to_quad[_particle_left] = love.graphics.newQuad(
            0, 0, canvas_w + 2 * padding, canvas_w + 2 * padding, _particle_texture:get_size()
        )

        -- right particle
        love.graphics.setLineWidth(canvas_w / 5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("line", right_x, y, 0.4 * canvas_w) -- sic
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.circle("fill", right_x, y, 0.4 * canvas_w)

        _particle_which_to_quad[_particle_right] = love.graphics.newQuad(
            padding + canvas_w + padding, 0, canvas_w + 2 * padding, canvas_w + 2 * padding, _particle_texture:get_size()
        )

        _particle_texture:unbind()
    end

    self._particles = {}

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "l" then
            _outline_shader:recompile()
        end
    end)
end

local _settings = rt.settings.overworld.accelerator_surface
local _particle_i = 0
local _total_n_particles = 0

--- @brief
function ow.AcceleratorSurface:update(delta)
    if self._scene:get_is_body_visible(self._body) == true then

        -- update particle location
        local nx, ny, x, y = self._scene:get_player():get_collision_normal(self._body)
        if nx == nil then
            self._is_active = false
        else
            self._is_active = true
            self._emission_x, self._emission_y = x, y
            self._emission_nx, self._emission_ny = math.normalize(nx, ny)
        end

        if not self._should_emit then return end

        -- add particles
        if self._is_active and rt.GameState:get_is_performance_mode_enabled() == false then
            self._particle_emission_elapsed = self._particle_emission_elapsed + delta

            local player = self._scene:get_player()
            local player_vx, player_vy = player:get_velocity()
            if math.magnitude(player_vx, player_vy) > _settings.min_velocity_threshold then
                local step = 1 / math.mix(_settings.min_n_particles_per_second, _settings.max_n_particles_per_second, player:get_flow())
                while self._particle_emission_elapsed >= step do
                    self._particle_emission_elapsed = self._particle_emission_elapsed - step

                    if _total_n_particles > _settings.max_n_particles then break end

                    local vx, vy = math.normalize(math.rotate(
                        self._emission_nx, self._emission_ny,
                        rt.random.number(-1, 1) * _settings.max_angle_offset
                    ))

                    local speed = rt.random.number(_settings.min_speed, _settings.max_speed)
                    local r, g, b = rt.lcha_to_rgba(0.8, 1, player:get_hue() + rt.random.number(-1, 1) * _settings.max_hue_offset)
                    local quad = _particle_i % 2 == 0 and _particle_left or _particle_right
                    _particle_i = _particle_i + 1

                    local particle = {
                        [_position_x] = self._emission_x,
                        [_position_y] = self._emission_y,
                        [_velocity_x] = vx * speed,
                        [_velocity_y] = vy * speed,
                        [_r] = r,
                        [_g] = g,
                        [_b] = b,
                        [_elapsed] = 0,
                        [_lifetime] = rt.random.number(_settings.min_lifetime, _settings.max_lifetime),
                        [_quad] = quad,
                        [_scale] = rt.random.number(_settings.min_scale, _settings.max_scale)
                    }

                    table.insert(self._particles, particle)
                    _total_n_particles = _total_n_particles + 1
                end
            end
        end
    end

    -- update particles
    local bounds = self._scene:get_camera():get_world_bounds()

    local to_remove = {}
    for i, particle in ipairs(self._particles) do
        particle[_elapsed] = particle[_elapsed] + delta
        local fraction = particle[_elapsed] / particle[_lifetime]
        if fraction > 1 or (not bounds:contains(particle[_position_x], particle[_position_y])) then
            table.insert(to_remove, i)
        else
            particle[_position_x] = particle[_position_x] + particle[_velocity_x] * delta
            particle[_position_y] = particle[_position_y] + particle[_velocity_y] * delta
        end
    end

    table.sort(to_remove, function(a, b)
        return a > b
    end)

    for i in values(to_remove) do
        table.remove(self._particles, i)
        _total_n_particles = _total_n_particles - 1
    end
end

--- @brief
function ow.AcceleratorSurface:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    local elapsed = rt.SceneManager:get_elapsed()
    local camera_offset = { self._scene:get_camera():get_offset() }
    local camera_scale = self._scene:get_camera():get_final_scale()

    _base_shader:bind()
    love.graphics.draw(self._shape_mesh:get_native())
    _base_shader:unbind()

    _outline_shader:bind()
    _outline_shader:send("elapsed", elapsed)
    _outline_shader:send("camera_offset", camera_offset)
    _outline_shader:send("camera_scale", camera_scale)
    love.graphics.setLineWidth(10)
    love.graphics.line(self._contour)
    _outline_shader:unbind()

    -- particles
    local texture = _particle_texture:get_native()
    local h = _particle_texture:get_height()
    love.graphics.push()
    love.graphics.setBlendMode("alpha", "premultiplied")
    for particle in values(self._particles) do
        local quad = _particle_which_to_quad[particle[_quad]]
        local opacity = 1 - particle[_elapsed] / particle[_lifetime]
        love.graphics.setColor(particle[_r] * opacity, particle[_g] * opacity, particle[_b] * opacity, opacity)
        love.graphics.draw(
            texture,
            quad,
            particle[_position_x], particle[_position_y],
            0,
            particle[_scale], particle[_scale],
            0.5 * h, 0.5 * h
        )
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

