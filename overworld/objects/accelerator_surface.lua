require "common.contour"

rt.settings.overworld.accelerator_surface = {
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

local _draw_shader

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

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    if _draw_shader == nil then _draw_shader = rt.Shader("overworld/objects/accelerator_surface_draw.glsl") end
    self._scene = scene

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "l" then
            _draw_shader:recompile()
        end
    end)

    -- collision
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

    -- graphics
    self._contour = object:create_contour()
    table.insert(self._contour, self._contour[1])
    table.insert(self._contour, self._contour[2])

    self._mesh = object:create_mesh()

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
end

local _settings = rt.settings.overworld.accelerator_surface
local _particle_i = 0
local _total_n_particles = 0

--- @brief
function ow.AcceleratorSurface:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end

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
    if self._is_active then
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

    -- update particles
    local bounds = rt.AABB(self._scene:get_camera():get_world_bounds())

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
    love.graphics.setColor(1, 1, 1, 0.5)
    
    _draw_shader:bind()
    _draw_shader:send("elapsed", rt.SceneManager:get_elapsed())
    local scene = rt.SceneManager:get_current_scene()
    local camera = scene:get_camera()
    local player = scene:get_player()
    _draw_shader:send("camera_offset", { scene:get_camera():get_offset() })
    _draw_shader:send("camera_scale", scene:get_camera():get_scale())
    _draw_shader:send("player_position", { camera:world_xy_to_screen_xy(player:get_physics_body():get_position()) })
    _draw_shader:send("player_color", { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1)})
    _draw_shader:send("player_flow", player:get_flow())
    love.graphics.draw(self._mesh:get_native())
    _draw_shader:unbind()

    love.graphics.setLineWidth(4)
    rt.Palette.BLACK:bind()
    love.graphics.line(self._contour)

    rt.Palette.WHITE:bind()
    love.graphics.line(self._contour)

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

