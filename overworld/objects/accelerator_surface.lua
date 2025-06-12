require "common.contour"

--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _post_fx_canvas, _post_fx_shader

local _instances = {}

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene
    table.insert(_instances, self) -- for post fx

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag("use_friction", "hitbox")
    self._body:set_friction(object:get_number("friction") or -1)
    self._body:set_user_data(self)

    self._mesh, self._tris = object:create_mesh()
    self._contour = rt.contour_from_tris(self._tris)

    self._camera_scale = 1
    self._camera_offset = { 0, 0 }
    self._elapsed = 0

    self._is_active = false
    self._body:set_collides_with(bit.bor(rt.settings.player.player_collision_group, rt.settings.player.player_outer_body_collision_group))

    self._body:signal_connect("collision_start", function()
        self._is_active = true
        self:update(0)
    end)

    -- particles
    self._particles = {}
    self._texture_particles = meta.make_weak({})
    self._shape_particles = meta.make_weak({})
    self._particle_emission_elapsed = 0
    self._emission_x, self._emission_y = 0, 0
    self._emission_nx, self._emission_ny = 0, 0

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" and _instances[1] == self then
            local before = love.timer.getTime()
            _post_fx_shader:recompile()
            dbg("called")
        end
    end)
end

--- @brief
function ow.AcceleratorSurface:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end

    self._elapsed = self._elapsed + delta
    local camera = self._scene:get_camera()
    self._camera_offset = { camera:get_offset() }
    self._camera_scale = camera:get_scale()

    self:_update_particles(delta)

    if self._is_active then
        local nx, ny, x, y = self._scene:get_player():get_collision_normal(self._body)
        if nx == nil then
            self._is_active = false
        else
            self._is_active = true
            self._emission_x, self._emission_y = x, y
            self._emission_nx, self._emission_ny = nx, ny
        end
    end
end

local padding = 5
local particle_which = 0
local _total_n_particles = 0
local _max_n_particles = 1000

local _position_x = 1
local _position_y = 2
local _velocity_x = 3
local _velocity_y = 4
local _speed = 5
local _scale = 6
local _radius = 7
local _r = 8
local _g = 9
local _b = 10
local _opacity = 11
local _lifetime_multiplier = 12
local _lifetime_elapsed = 13
local _which = 14

--- @brief
function ow.AcceleratorSurface:_update_particles(delta)
    local min_emission_factor = 0.5
    local player = self._scene:get_player()
    local player_vx, player_vy = player:get_velocity()
    local emission_rate = math.mix(0, 10, math.min(player:get_flow() + (math.magnitude(player_vx, player_vy) / 10), 1))
    local min_size, max_size = 2, 7
    local hue_offset = 0.2
    local lifetime_offset = 0.2 -- fraction
    local lifetime = 2
    local angle_offset = 1 -- fraction
    local gravity = 30
    local min_speed, max_speed = 20, 50

    local normal_x, normal_y = self._emission_nx, self._emission_ny
    local angle = math.normalize_angle(math.angle(player_vx, player_vy) - math.pi)

    self._particle_mesh = rt.MeshCircle(0, 0, max_size)
    self._particle_mesh:set_vertex_color(1, 1, 1, 1, 1)
    for i = 2, self._particle_mesh:get_n_vertices() do
        self._particle_mesh:set_vertex_color(i, 1, 1, 1, 0.0)
    end

    local canvas_w = 2 * max_size + padding
    self._particle_texture_gaussian = rt.RenderTexture(canvas_w, canvas_w, 4)
    self._particle_texture_gaussian:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._particle_mesh:get_native(), 0.5 * canvas_w, 0.5 * canvas_w)
    self._particle_texture_gaussian:unbind()

    -- spawn
    if self._is_active then
        self._particle_emission_elapsed = self._particle_emission_elapsed + delta
        local step = 1 / (emission_rate * (1 + self._scene:get_player():get_flow()))
        local player_hue = self._scene:get_player():get_hue()
        while self._particle_emission_elapsed >= step do
            local current_angle = angle + rt.random.number(-1, 1) * angle_offset
            local vx, vy = math.cos(current_angle), math.sin(current_angle)

            local hue = rt.random.number(-hue_offset, hue_offset) + player_hue
            local radius = rt.random.number(min_size, max_size)
            local r, g, b, a = rt.lcha_to_rgba(0.8, 1, hue)
            local particle = {
                [_speed] = rt.random.number(min_speed, max_speed),
                [_scale] = radius / max_size,
                [_radius] = radius,
                [_position_x] = self._emission_x,
                [_position_y] = self._emission_y,
                [_velocity_x] = vx,
                [_velocity_y] = vy,
                [_r] = r,
                [_g] = g,
                [_b] = b,
                [_opacity] = 1,
                [_lifetime_multiplier] = 1 + rt.random.number(-lifetime_offset, lifetime_offset),
                [_lifetime_elapsed] = 0,
                [_which] = particle_which % 2 == 0
            }

            particle_which = particle_which + 1

            if particle[_which] == true then
                self._texture_particles[particle] = true
            else
                self._shape_particles[particle] = true
            end

            table.insert(self._particles, particle)
            _total_n_particles = _total_n_particles + 1
            self._particle_emission_elapsed = self._particle_emission_elapsed - step
        end
    end

    local camera = self._scene:get_camera()
    local top_x, top_y = camera:screen_xy_to_world_xy(0, 0)
    local bottom_x, bottom_y = camera:screen_xy_to_world_xy(love.graphics.getDimensions())

    top_x = top_x - 2 * max_size
    top_y = top_y - 2 * max_size
    bottom_x = bottom_x + 2 * max_size
    bottom_y = bottom_y + 2 * max_size

    -- simulate
    local to_remove = {}
    for i, particle in ipairs(self._particles) do
        particle[_position_x] = particle[_position_x] + particle[_velocity_x] * particle[_speed] * delta
        particle[_position_y] = particle[_position_y] + particle[_velocity_y] * particle[_speed] * delta
        particle[_lifetime_elapsed] = particle[_lifetime_elapsed] + delta

        particle[_opacity] = 1 - particle[_lifetime_elapsed] / (particle[_lifetime_multiplier] * lifetime)

        local x, y = particle[_position_x], particle[_position_y]
        if particle[_lifetime_elapsed] > (particle[_lifetime_multiplier] * lifetime) or -- scheduled end of lifetime
            x < top_x or y < top_y or x > bottom_x or y > bottom_y or -- despawn off-screen
            _total_n_particles > _max_n_particles -- prevent lag
        then
            table.insert(to_remove, i)
            _total_n_particles = _total_n_particles - 1
        end
    end

    table.sort(to_remove, function(a, b)
        return a > b
    end)

    for i in values(to_remove) do
        local particle = self._particles[i]
        table.remove(self._particles, i)
        self._shape_particles[particle] = nil
        self._texture_particles[particle] = nil
    end
end

--- @brief
function ow.AcceleratorSurface:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.setLineJoin("bevel")
    love.graphics.line(self._contour)

    if self._particle_texture_gaussian == nil then return end -- uninitialized

    love.graphics.setLineWidth(0.5)
    local w, h = self._particle_texture_gaussian:get_size()

    rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.NORMAL)
    for particle in keys(self._texture_particles) do
        local damp = particle[_opacity]
        love.graphics.setColor(damp * particle[_r], damp * particle[_g], damp * particle[_b], 1)
        love.graphics.draw(self._particle_texture_gaussian:get_native(), particle[_position_x], particle[_position_y], 0, particle[_scale], particle[_scale], 0.5 * w, 0.5 * h)
    end

    rt.graphics.set_blend_mode(nil)
    for particle in keys(self._shape_particles) do
        love.graphics.setColor(particle[_r], particle[_g], particle[_b], particle[_opacity] * 0.5)
        love.graphics.circle("fill", particle[_position_x], particle[_position_y], particle[_radius])
        love.graphics.setColor(particle[_r], particle[_g], particle[_b], particle[_opacity])
        love.graphics.circle("line", particle[_position_x], particle[_position_y], particle[_radius])
    end
end

function ow.AcceleratorSurface:reinitialize()
    _instances = {}
end

function ow.AcceleratorSurface:draw_all()
    if true then return end --#_instances == 0 then return end

    if _post_fx_shader == nil then _post_fx_shader = rt.Shader("overworld/objects/accelerator_surface.glsl") end
    local w, h = love.graphics.getDimensions()
    if _post_fx_canvas == nil or _post_fx_canvas:get_width() ~= w or _post_fx_canvas:get_height() ~= h then
        _post_fx_canvas = rt.RenderTexture(w, h, 2)
    end

    _post_fx_canvas:bind()
    love.graphics.clear()
    for instance in values(_instances) do
        if instance._scene:get_is_body_visible(instance._body) then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(instance._mesh:get_native())
        end
    end
    _post_fx_canvas:unbind()

    local scene = _instances[1]._scene
    local camera = scene:get_camera()
    local player = scene:get_player()
    local px, py = player:get_physics_body():get_position()
    px, py = camera:world_xy_to_screen_xy(px, py)

    love.graphics.push()
    love.graphics.origin()
    _post_fx_shader:bind()
    _post_fx_shader:send("player_position", { px, py })
    _post_fx_shader:send("color", { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1)})
    _post_fx_shader:send("camera_scale", camera:get_scale())
    _post_fx_shader:send("camera_offset", { camera:get_offset() })

    _post_fx_canvas:draw()
    _post_fx_shader:unbind()
    love.graphics.pop()
end

--- @brief
function ow.AcceleratorSurface:get_render_priority()
    return 1
end