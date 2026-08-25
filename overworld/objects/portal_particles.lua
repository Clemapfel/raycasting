rt.settings.overworld.portal_particles = {
    mesh_w = 100, -- px
    pulse_duration = 1, -- s
    transition_min_speed = 600,
    transition_speed_factor = 1.5,
    particle = {
        radius = 25,
        min_speed = 10, -- px / s
        max_speed = 20,
        min_scale = 0.3,
        max_scale = 0.6,
        coverage = 5,
        collapse_speed = 10, -- fraction
    },

    min_velocity_magnitude = 500, -- px/s, when exiting portal
    max_velocity_magnitude = rt.settings.player.downwards_force / 2,

    impulse_max_scale = 1.2,
    one_way_light_animation_duration = 1.15, -- seconds
    velocity_angle_min_threshold = math.degrees_to_radians(15),
}

--- @class ow.PortalParticles
-- Merged: also owns the portal "pulse" mesh/shader/animation that used to live in ow.PortalPulse.
ow.PortalParticles = meta.class("PortalParticles")

local _particle_texture
local _particle_shader = rt.Shader("overworld/objects/portal_particles.glsl")
local _lch_texture = rt.LCHTexture(64, 4, 256)
local _pulse_shader = rt.Shader("overworld/objects/portal.glsl")

local _FORWARD = true
local _BACKWARDS = false

local _LEFT = true
local _RIGHT = false

local _x_offset = 0
local _y_offset = 1
local _direction_offset = 2
local _speed_offset = 3
local _scale_offset = 4
local _t_offset = 5
local _stride = _t_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1
end

--- @brief
function ow.PortalParticles:instantiate(ax, ay, bx, by, left_or_right)
    meta.assert(ax, mt.Number, ay, mt.Number, bx, mt.Number, by, mt.Number, left_or_right, mt.Boolean)

    self._winding = left_or_right -- true = left, false = right

    -- shared endpoints, used by both the particle field and the pulse mesh
    self._ax, self._ay, self._bx, self._by = ax, ay, bx, by

    if _particle_texture == nil then
        local radius = rt.settings.overworld.portal_particles.particle.radius
        local padding = 3
        _particle_texture = rt.RenderTexture(2 * (radius + padding), 2 * (radius + padding))

        local n_outer_vertices = 32
        local mesh = rt.MeshRing(
            0, 0,
            5, radius,
            true,
            n_outer_vertices,
            rt.RGBA(1, 1, 1, 1),
            rt.RGBA(1, 1, 1, 0)
        )

        love.graphics.push("all")
        love.graphics.origin()
        _particle_texture:bind()
        love.graphics.translate(0.5 * _particle_texture:get_width(), 0.5 * _particle_texture:get_width())
        mesh:draw()
        _particle_texture:unbind()
        love.graphics.pop()
    end

    local settings = rt.settings.overworld.portal_particles.particle
    local min_radius = settings.radius * settings.min_scale
    local max_radius = settings.radius * settings.max_scale

    local length = math.distance(ax, ay, bx, by)
    local n_particles = length / min_radius * settings.coverage

    local canvas_w, canvas_h = 2 * (2 * max_radius), length
    self._static_canvas = rt.RenderTexture(canvas_w, canvas_h, {
        has_stencil = true
    })

    self._canvas_x, self._canvas_y = math.mix2(
        ax, ay, bx, by,
        0.5
    )

    self._canvas_angle = math.angle(
        bx - ax, by - ay
    ) + 0.5 * math.pi

    self._particle_axis = {
        0.5 * canvas_w, min_radius,
        0.5 * canvas_w, length - min_radius
    }

    if self._winding then -- left
        self._particle_stencil = {
            0.5 * canvas_w, 0,
            0.5 * canvas_w, length
        }
    else -- right
        self._particle_stencil = {
            0, 0,
            0.5 * canvas_w, length
        }
    end

    self._particle_data = {}
    self._n_particles = 0

    local data = self._particle_data
    local pax, pay, pbx, pby = table.unpack(self._particle_axis)
    for particle_i = 1, n_particles do
        local t = (particle_i - 1) / n_particles
        local x, y = math.mix2(pax, pay, pbx, pby, t)
        local i = #self._particle_data + 1
        data[i + _x_offset] = x
        data[i + _y_offset] = y
        data[i + _speed_offset] = rt.random.number(settings.min_speed, settings.max_speed)
        data[i + _direction_offset] = rt.random.choose(_FORWARD, _BACKWARDS)
        data[i + _scale_offset] = rt.random.number(settings.min_scale, settings.max_scale)
        data[i + _t_offset] = t
        self._n_particles = self._n_particles + 1
    end

    self._collapse_active = false
    self._collapse_t = 0.5
    self._canvas_needs_update = true

    -- pulse state / mesh (formerly ow.PortalPulse:instantiate)
    do
        local dx, dy = math.normalize(ax - bx, ay - by)
        local left_x, left_y = math.turn_left(dx, dy)
        local right_x, right_y = math.turn_right(dx, dy)

        if self._winding == _LEFT then
            self._pulse_normal_x, self._pulse_normal_y = left_x, left_y
        else
            self._pulse_normal_x, self._pulse_normal_y = right_x, right_y
        end

        local w = rt.settings.overworld.portal_particles.mesh_w
        local pulse_padding = rt.settings.player.radius * rt.settings.player.bubble_radius_factor

        local mesh_ax, mesh_ay = ax + dx * pulse_padding, ay + dy * pulse_padding
        local mesh_bx, mesh_by = bx - dx * pulse_padding, by - dy * pulse_padding

        local outer = function() return 0, 0, 0, 0 end
        local inner = function() return 1, 1, 1, 1 end

        if self._winding == _LEFT then
            self._pulse_mesh = rt.Mesh({
                { mesh_ax + left_x * w, mesh_ay + left_y * w, 0, 1, outer() },
                { mesh_ax, mesh_ay, 0, 0, inner() },
                { mesh_bx, mesh_by, 1, 0, inner() },
                { mesh_bx + left_x * w, mesh_by + left_y * w, 1, 1, outer() },
            })
        else
            self._pulse_mesh = rt.Mesh({
                { mesh_ax, mesh_ay, 1, 0, inner() },
                { mesh_ax + right_x * w, mesh_ay + right_y * w, 1, 1, outer() },
                { mesh_bx + right_x * w, mesh_by + right_y * w, 0, 1, outer() },
                { mesh_bx, mesh_by, 0, 0, inner() },
            })
        end

        self._pulse_elapsed = math.huge
        self._pulse_value = 0
        self._pulse_entry_t = 0.5
        -- note: self._lightness is shared with set_is_enabled below
        self._lightness = 1
    end
end

--- @brief
function ow.PortalParticles:update(delta)
    local ax, ay, bx, by = table.unpack(self._particle_axis)
    local length = math.distance(ax, ay, bx, by)
    local particle_r = select(1, _particle_texture:get_size()) / 2

    local speed = rt.settings.overworld.portal_particles.particle.collapse_speed
    local collapse_mean_distance = 0

    local data = self._particle_data
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        local t = data[i + _t_offset]
        local scale = data[i + _scale_offset]
        local eps = 2 / length

        if data[i + _direction_offset] == _FORWARD then
            t = t + data[i + _speed_offset] / length * delta
            if t > 1 - eps then
                t = 1 - eps
                data[i + _direction_offset] = not data[i + _direction_offset]
            end
        else
            t = t - data[i + _speed_offset] / length * delta
            if t < eps then
                t = eps
                data[i + _direction_offset] = not data[i + _direction_offset]
            end
        end

        data[i + _t_offset] = t

        if self._collapse_active then
            t = self._collapse_t
        end
        local target_x, target_y = math.mix2(ax, ay, bx, by, t)

        data[i + _x_offset] = data[i + _x_offset] + speed * (target_x - data[i + _x_offset]) * delta
        data[i + _y_offset] = data[i + _y_offset] + speed * (target_y - data[i + _y_offset]) * delta

        if self._collapse_active then
            collapse_mean_distance = collapse_mean_distance + math.distance(target_x, target_y, data[i + _x_offset], data[i + _y_offset])
        end
    end

    if self._collapse_active and collapse_mean_distance < 2 * rt.settings.overworld.portal_particles.particle.radius then
        self._collapse_active = false
    end

    self._canvas_needs_update = true

    -- pulse animation update (formerly ow.PortalPulse:update)
    self._pulse_elapsed = self._pulse_elapsed + delta
    self._pulse_value = rt.InterpolationFunctions.ENVELOPE(
        self._pulse_elapsed / rt.settings.overworld.portal_particles.pulse_duration,
        0.05,
        0.05
    )
end

--- @brief
function ow.PortalParticles:draw()
    if self._canvas_needs_update == true then
        love.graphics.push("all")
        love.graphics.origin()
        self._static_canvas:bind()
        love.graphics.clear(0, 0, 0, 0)

        local value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
        love.graphics.rectangle("fill", table.unpack(self._particle_stencil))
        rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

        local w, h = _particle_texture:get_size()
        local data = self._particle_data
        for particle_i = 1, self._n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            love.graphics.draw(
                _particle_texture:get_native(),
                data[i + _x_offset], data[i + _y_offset], 0,
                data[i + _scale_offset], data[i + _scale_offset],
                0.5 * w, 0.5 * h
            )
        end

        rt.graphics.set_stencil_mode(nil)

        self._static_canvas:unbind()
        love.graphics.pop("all")

        self._canvas_needs_update = false
    end

    _particle_shader:bind()
    _particle_shader:send("hue", self._hue or 1)
    _particle_shader:send("lightness", self._lightness or 1)
    _particle_shader:send("chroma", self._chroma or 1)
    _particle_shader:send("lch_texture", _lch_texture)

    _particle_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
    _particle_shader:send("black", { black_r, black_g, black_b })
    local w, h = self._static_canvas:get_size()
    love.graphics.draw(
        self._static_canvas:get_native(),
        self._canvas_x, self._canvas_y, self._canvas_angle,
        1, 1,
        0.5 * w, 0.5 * h
    )
    _particle_shader:unbind()
end

--- @brief draws the pulse mesh (formerly ow.PortalPulse:draw)
function ow.PortalParticles:draw_pulse(r, g, b, a)
    love.graphics.push()

    local px, py = math.mix2(
        self._ax, self._ay,
        self._bx, self._by,
        1 - self._pulse_entry_t
    )

    love.graphics.translate(px, py)
    love.graphics.scale(1 - self._pulse_value)
    love.graphics.translate(-px, -py)

    local lightness = self._lightness or 1
    love.graphics.setColor(
        lightness * r,
        lightness * g,
        lightness * b,
        a or 1
    )

    _pulse_shader:bind()
    _pulse_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _pulse_shader:send("pulse", self._pulse_value)
    _pulse_shader:send("brightness_scale", 1)
    self._pulse_mesh:draw()
    _pulse_shader:unbind()

    love.graphics.pop()
end

--- @brief draws the pulse mesh's bloom pass (formerly ow.PortalPulse:draw_bloom)
function ow.PortalParticles:draw_pulse_bloom(r, g, b, a, brightness_scale)
    love.graphics.push()

    local px, py = math.mix2(
        self._ax, self._ay,
        self._bx, self._by,
        1 - self._pulse_entry_t
    )

    love.graphics.translate(px, py)
    love.graphics.scale(1 - self._pulse_value)
    love.graphics.translate(-px, -py)

    love.graphics.setColor(r, g, b, a or 1)

    _pulse_shader:bind()
    _pulse_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self))
    _pulse_shader:send("pulse", self._pulse_value)
    _pulse_shader:send("brightness_scale", brightness_scale or 1)
    self._pulse_mesh:draw()
    _pulse_shader:unbind()

    love.graphics.pop()
end

--- @brief triggers the pulse animation (formerly ow.PortalPulse:trigger)
function ow.PortalParticles:trigger_pulse()
    self._pulse_elapsed = 0
    self._pulse_value = 0
end

--- @brief sets where along the portal the pulse enters from (formerly ow.PortalPulse:set_entry_t)
function ow.PortalParticles:set_pulse_entry_t(t)
    self._pulse_entry_t = t
end

--- @brief
function ow.PortalParticles:contract(t)
    self._collapse_active = true
    self._collapse_t = 1 - (t or 0.5)
    self._canvas_needs_update = true
end

--- @brief resets both particle collapse state and pulse animation state
function ow.PortalParticles:reset()
    self._collapse_active = false
    self._collapse_t = 0.5
    self._canvas_needs_update = true

    -- formerly ow.PortalPulse:reset
    self._pulse_elapsed = math.huge
    self._pulse_value = 0
    self._pulse_entry_t = 0.5
    self._lightness = 1
end

--- @brief
function ow.PortalParticles:set_hue(hue)
    self._hue = hue
end

--- @brief also drives pulse brightness, since the two used separate `_lightness` fields before
function ow.PortalParticles:set_is_enabled(b)
    if b == true then
        self._lightness = 1
    else
        self._lightness = 0.4
        self._chroma = 0.8
    end
end

--- @brief explicit setter kept for parity with the old ow.PortalPulse:set_lightness
function ow.PortalParticles:set_lightness(lightness)
    self._lightness = lightness
end