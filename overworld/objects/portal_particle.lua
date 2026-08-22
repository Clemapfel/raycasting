
--- @class ow.PortalParticles
ow.PortalParticles = meta.class("PortalParticles")

local _particle_texture -- rt.RenderTexture

local _pulse_shader = rt.Shader("overworld/objects/portal.glsl")
local _particle_shader = rt.Shader("overworld/objects/portal_particles.glsl")
local _lch_texture = rt.LCHTexture(64, 1, 256)

-- particle directions
local _FORWARD = true
local _BACKWARDS = not _FORWARD

-- particle properties
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
function ow.PortalParticles:instantiate(ax, ay, bx, by, winding)
    meta.assert(ax, mt.Number, ay, mt.Number, bx, mt.Number, by, mt.Number, winding, mt.Boolean)

    if _particle_texture == nil then
        local radius = rt.settings.overworld.portal.particle.radius
        local padding = 3
        _particle_texture = rt.RenderTexture(2 * (radius + padding), 2 * (radius + padding))

        local n_outer_vertices = 32
        local mesh = rt.MeshRing(
            0, 0,
            5, radius,
            true, -- fill center
            n_outer_vertices,
            rt.RGBA(1, 1, 1, 1),
            rt.RGBA(1, 1, 1, 0)
        )

        love.graphics.push()
        love.graphics.origin()
        _particle_texture:bind()
        love.graphics.translate(0.5 * _particle_texture:get_width(), 0.5 * _particle_texture:get_width())
        mesh:draw()
        _particle_texture:unbind()
        love.graphics.pop()
    end

    -- particles
    local settings = rt.settings.overworld.portal.particle
    local min_radius = settings.radius * settings.min_scale
    local max_radius = settings.radius * settings.max_scale

    local length = math.distance(self._ax, self._ay, self._bx, self._by)
    local n_particles = length / min_radius * settings.coverage

    local padding = 2 * max_radius
    self._static_canvas = rt.RenderTexture(2 * padding, length, {
        has_stencil = true
    })

    self._canvas_x, self._canvas_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)
    self._canvas_angle = math.angle(self._bx - self._ax, self._by - self._ay) + 0.5 * math.pi

    local canvas_w, canvas_h = self._static_canvas:get_size()
    self._particle_axis = {
        0.5 * canvas_w, min_radius,
        0.5 * canvas_w, length - min_radius
    }

    if winding == true then
        self._particle_stencil = {
            0.5 * canvas_w, 0,
            0.5 * canvas_w, length
        }
    else
        self._particle_stencil = {
            0, 0,
            0.5 * canvas_w, length
        }
    end

    -- distribute evenly across line
    self._particle_data = {}
    self._n_particles = 0

    local data = self._particle_data
    local lax, lay, lbx, lby = table.unpack(self._particle_axis)
    for particle_i = 1, n_particles do
        local t = (particle_i - 1) / n_particles
        local x, y = math.mix2(lax, lay, lbx, lby, t)
        local i = #self._particle_data + 1
        data[i + _x_offset] = x
        data[i + _y_offset] = y
        data[i + _speed_offset] = rt.random.number(settings.min_speed, settings.max_speed)
        data[i + _direction_offset] = rt.random.choose(_FORWARD, _BACKWARDS)
        data[i + _scale_offset] = rt.random.number(settings.min_scale, settings.max_scale)
        data[i + _t_offset] = t
        self._n_particles = self._n_particles + 1
    end

    self._canvas_needs_update = true
    self._collapse_active = false
    self._collapse_t = 0.5
end

--- @brief
function ow.PortalParticles:update(delta)
    local ax, ay, bx, by = table.unpack(self._particle_axis)
    local length = math.distance(ax, ay, bx, by)
    local particle_r = select(1, _particle_texture:get_size()) / 2

    local speed = rt.settings.overworld.portal.particle.collapse_speed
    local collapse_mean_distance = 0

    local data = self._particle_data
    for particle_i = 1, self._n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        local t = data[i + _t_offset]
        local scale = data[i + _scale_offset]
        local eps = 2 -- width of particle outline, in px --(scale * particle_r) / length / 2
        eps = eps / length

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

        if self._collapse_active then -- always collapsed if no entry
            t = self._entry_t
        end

        local target_x, target_y = math.mix2(ax, ay, bx, by, t)

        data[i + _x_offset] = data[i + _x_offset] + speed * (target_x - data[i + _x_offset]) * delta
        data[i + _y_offset] = data[i + _y_offset] + speed * (target_y - data[i + _y_offset]) * delta

        if self._collapse_active then
            collapse_mean_distance = collapse_mean_distance + math.distance(target_x, target_y, data[i + _x_offset], data[i + _y_offset])
        end
    end

    if self._collapse_active and collapse_mean_distance < 2 * rt.settings.overworld.portal.particle.radius then
        self._collapse_active = false
    end
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
        local scale = math.mix(1, rt.settings.overworld.portal.impulse_max_scale, self._impulse:get_beat())
        local data = self._particle_data
        for particle_i = 1, self._n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            love.graphics.draw(
                _particle_texture:get_native(),
                data[i + _x_offset], data[i + _y_offset], 0,
                data[i + _scale_offset] * scale, data[i + _scale_offset] * scale,
                0.5 * w, 0.5 * h
            )
        end

        rt.graphics.set_stencil_mode(nil)

        self._static_canvas:unbind()
        love.graphics.pop("all")

        self._canvas_needs_update = false
    end
end

--- @brief
function ow.PortalParticles:contract(t)
    self._collapse_t = t
    self._collapse_active = true
end

--- @brief
function ow.PortalParticles:reset()

end