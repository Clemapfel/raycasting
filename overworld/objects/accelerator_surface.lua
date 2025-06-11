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
        if which == "h" then
            local before = love.timer.getTime()
            _shader:recompile()
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
    self._particle_mesh_texture = rt.RenderTexture(canvas_w, canvas_w, 4)
    self._particle_mesh_texture:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._particle_mesh:get_native(), 0.5 * canvas_w, 0.5 * canvas_w)
    self._particle_mesh_texture:unbind()

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
                mass = 1,
                speed = rt.random.number(min_speed, max_speed),
                scale = radius / max_size,
                radius = radius,
                position_x = self._emission_x,
                position_y = self._emission_y,
                velocity_x = vx,
                velocity_y = vy,
                r = r,
                g = g,
                b = b,
                opacity = 1,
                lifetime_multiplier = 1 + rt.random.number(-lifetime_offset, lifetime_offset),
                lifetime_elapsed = 0,
                which = particle_which % 2 == 0
            }
            particle_which = particle_which + 1

            if particle.which == true then
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
        particle.position_x = particle.position_x + particle.velocity_x * particle.speed * delta
        particle.position_y = particle.position_y + particle.velocity_y * particle.speed * delta
        particle.lifetime_elapsed = particle.lifetime_elapsed + delta

        particle.opacity = 1 - particle.lifetime_elapsed / (particle.lifetime_multiplier * lifetime)

        local x, y = particle.position_x, particle.position_y
        if particle.lifetime_elapsed > (particle.lifetime_multiplier * lifetime) or -- scheduled end of lifetime
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

    if self._particle_mesh_texture == nil then return end -- uninitialized

    love.graphics.setLineWidth(0.5)
    local w, h = self._particle_mesh_texture:get_size()

    rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.NORMAL)
    for particle in keys(self._texture_particles) do
        local damp = particle.opacity
        love.graphics.setColor(damp * particle.r, damp * particle.g, damp * particle.b, 1)
        love.graphics.draw(self._particle_mesh_texture:get_native(), particle.position_x, particle.position_y, 0, particle.scale, particle.scale, 0.5 * w, 0.5 * h)
    end

    rt.graphics.set_blend_mode(nil)
    for particle in keys(self._shape_particles) do
        love.graphics.setColor(particle.r, particle.g, particle.b, particle.opacity * 0.5)
        love.graphics.circle("fill", particle.position_x, particle.position_y, particle.radius)
        love.graphics.setColor(particle.r, particle.g, particle.b, particle.opacity)
        love.graphics.circle("line", particle.position_x, particle.position_y, particle.radius)
    end
end

function ow.AcceleratorSurface:reinitialize()
    _instances = {}
end

function ow.AcceleratorSurface:_draw_mask()
    if not self._scene:get_is_body_visible(self._body) then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._mesh:get_native())
end

function ow.AcceleratorSurface:_bind_post_fx()
    local w, h = love.graphics.getDimensions()
    if _post_fx_canvas == nil or _post_fx_canvas:get_width() ~= w or _post_fx_canvas:get_height() ~= h then
        _post_fx_canvas = rt.RenderTexture(w, h, 2)
    end

    _post_fx_canvas:bind()
end

function ow.AcceleratorSurface:_unbind_post_fx()
    _post_fx_canvas:unbind()
end

function ow.AcceleratorSurface:draw_all()
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

    love.graphics.push()
    love.graphics.origin()
    _post_fx_shader:bind()
    _post_fx_canvas:draw()
    _post_fx_shader:unbind()
    love.graphics.pop()
end

--- @brief
function ow.AcceleratorSurface:get_render_priority()
    return 1
end