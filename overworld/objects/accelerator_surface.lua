rt.settings.overworld.accelerator_surface = {

}

--- @class ow.AcceleratorSurface
ow.AcceleratorSurface = meta.class("AcceleratorSurface")

local _shader

--- @brief
function ow.AcceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag("use_friction", "hitbox")
    self._body:set_friction(object:get_number("friction") or -1)
    self._body:set_user_data(self)

    self._mesh, self._tris = object:create_mesh()
    if _shader == nil then _shader = rt.Shader("overworld/objects/accelerator_surface.glsl") end

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
    self._particle_emission_elapsed = 0
    self._emission_x, self._emission_y = 0, 0
    self._emission_nx, self._emission_ny = 0, 0

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "h" then
            local before = love.timer.getTime()
            _shader:recompile()
            dbg(love.timer.getTime() - before)
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

--- @brief
function ow.AcceleratorSurface:_update_particles(delta)
    local emission_rate = math.magnitude(self._scene:get_player():get_velocity()) / 10
    local min_size, max_size = 2, 7
    local hue_offset = 0.2
    local lifetime_offset = 0.2 -- fraction
    local lifetime = 1
    local angle_offset = 1 -- fraction
    local gravity = 30
    local min_speed, max_speed = 10, 30

    local normal_x, normal_y = self._emission_nx, self._emission_ny
    local tangent_x, tangent_y = math.turn_left(self._emission_nx, self._emission_ny)

    -- spawn
    if self._is_active then
        self._particle_emission_elapsed = self._particle_emission_elapsed + delta
        local step = 1 / emission_rate
        local player_hue = self._scene:get_player():get_hue()
        while self._particle_emission_elapsed >= step do
            local vx, vy = math.normalize(math.mix2(tangent_x, tangent_y, -normal_x, -normal_y, rt.random.number(0, 1) * angle_offset))

            local hue = rt.random.number(-hue_offset, hue_offset) + player_hue
            local r, g, b, a = rt.lcha_to_rgba(0.8, 1, hue)
            local particle = {
                mass = 1,
                speed = rt.random.number(min_speed, max_speed),
                radius = rt.random.number(min_size, max_size),
                position_x = self._emission_x,
                position_y = self._emission_y,
                velocity_x = vx,
                velocity_y = vy,
                r = r,
                g = g,
                b = b,
                opacity = 1,
                lifetime_multiplier = 1 + rt.random.number(-lifetime_offset, lifetime_offset),
                lifetime_elapsed = 0
            }
            table.insert(self._particles, particle)
            self._particle_emission_elapsed = self._particle_emission_elapsed - step
        end
    end

    -- simulate
    local to_remove = {}
    for i, particle in ipairs(self._particles) do
        particle.position_x = particle.position_x + particle.velocity_x * particle.speed * delta
        particle.position_y = particle.position_y + particle.velocity_y * particle.speed * delta
        particle.lifetime_elapsed = particle.lifetime_elapsed + delta

        particle.opacity = 1 - particle.lifetime_elapsed / (particle.lifetime_multiplier * lifetime)
        if particle.opacity <= 0 then
            table.insert(to_remove, i)
        end
    end

    for i in values(to_remove) do
        table.remove(self._particles, i)
    end
end

--- @brief
function ow.AcceleratorSurface:draw()
    if not self._scene:get_is_body_visible(self._body) then return end
    _shader:bind()
    _shader:send("camera_offset", self._camera_offset)
    _shader:send("camera_scale", self._camera_scale)
    _shader:send("elapsed", self._elapsed)
    _shader:send("player_position", { self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_physics_body():get_position()) })
    _shader:send("player_hue", self._scene:get_player():get_hue())
    self._mesh:draw()
    _shader:unbind()

    love.graphics.setLineWidth(0.5)
    for particle in values(self._particles) do
        love.graphics.setColor(particle.r, particle.g, particle.b, particle.opacity * 0.5)
        love.graphics.circle("fill", particle.position_x, particle.position_y, particle.radius)
        love.graphics.setColor(particle.r, particle.g, particle.b, particle.opacity)
        love.graphics.circle("line", particle.position_x, particle.position_y, particle.radius)
    end
end

--- @brief
function ow.AcceleratorSurface:get_render_priority()
    return 1
end
