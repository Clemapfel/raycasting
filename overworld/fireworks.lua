rt.settings.overworld.fireworks = {
    duration = 2
}

--- @brief ow.Fireworks
ow.Fireworks = meta.class("Fireworks")

local _canvas

--- @brief
function ow.Fireworks:instantiate(scene)
    meta.assert(scene, "OverworldScene")
    meta.install(self, {
        _scene = scene,
        _particles = {},
        _active = false,
        _elapsed = math.huge
    })

    if _canvas == nil then _canvas = rt.RenderTexture(love.graphics.getDimensions()) end

    self._scene:signal_connect("update", function(_, delta)
        _canvas:bind()
        love.graphics.push()
        love.graphics.origin()
        rt.graphics.set_blend_mode(rt.BlendMode.SUBTRACT, rt.BlendMode.SUBTRACT)
        love.graphics.setColor(0, 0, 0, delta * 5)
        --love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
        love.graphics.pop()
        _canvas:unbind()
    end)
end

local _golden_ratio = (1 + math.sqrt(5)) / 2
local _rng = rt.random.number
local _perturbation = 0.5
local _velocity_bias = 0.4

--- @brie
function ow.Fireworks:spawn(n_particles, velocity, position_x, position_y, bias_x, bias_y, hue_min, hue_max)
    if position_x == nil then position_x = 0 end
    if position_y == nil then position_y = 0 end
    if bias_x == nil then bias_x = 0 end
    if bias_y == nil then bias_y = 0 end
    if hue_min == nil then hue_min = 0 end
    if hue_max == nil then hue_max = 1 end

    self._origin_x, self._origin_y = position_x, position_y
    meta.assert(n_particles, "Number", velocity, "Number", position_x, "Number", position_y, "Number", bias_x, "Number", bias_y, "Number", hue_min, "Number", hue_max, "Number")

    self._spawn_offset_x, self._spawn_offset_y = self._scene:get_camera():get_offset()

    self._particles = {}
    for i = 1, n_particles do
        -- fibonacci lattice to generate random points on sphere
        local idx = i - 0.5 - 1
        local z = 1 - 2 * idx / n_particles
        local theta = 2 * math.pi * idx / _golden_ratio

        local r = math.sqrt(1 - z * z)
        local x = r * math.cos(theta)
        local y = r * math.sin(theta)

        if _perturbation > 0 then
            local angle = _rng(0, 2 * math.pi)
            local offset = _rng(0, _perturbation)
            x = x + offset * math.cos(angle)
            y = y + offset * math.sin(angle)
            z = z + offset * math.sin(angle)
            local norm = math.sqrt(x * x + y * y + z * z)
            x, y, z = x / norm, y / norm, z / norm
        end

        local fraction = 0.7
        x, y, z = math.normalize3(x, y, z)

        bias_x, bias_y = math.normalize(bias_x, bias_y)

        local to_push = {
            position_x = position_x,
            position_y = position_y,
            position_z = 0,
            color = { rt.lcha_to_rgba(0.8, 1, _rng(hue_min, hue_max), 1) },
            velocity_x = 0,
            velocity_y = 0,
            velocity_z = 0,
            direction_x = math.mix(x, bias_x, _velocity_bias),
            direction_y = math.mix(y, bias_y, _velocity_bias),
            direction_z = z,
            direction_magnitude = velocity,
            mass = _rng(0, 1),
            radius = _rng(2, 6),
        }

        table.insert(self._particles, to_push)
    end

    self._active = true
    self._elapsed = 0
end

local _elapsed = 0
local _step = 1 / 120

--- @brief
--- @return Boolean is_done
function ow.Fireworks:update(delta)
    if not self._active then return end

    _elapsed = _elapsed + delta
    while _elapsed > _step do

        local duration = rt.settings.overworld.fireworks.duration
        local fraction = self._elapsed / duration
        local fade_out_duration = 0.1
        local gravity_per_second = 1000
        local gravity_x = 0
        local gravity_y = gravity_per_second * duration
        local gravity_z = -1 * gravity_per_second * duration

        for particle in values(self._particles) do
            local dx, dy, dz = particle.direction_x, particle.direction_y, particle.direction_z -- already normalized
            local vx, vy, vz = math.normalize3(particle.velocity_x, particle.velocity_y, particle.velocity_z)
            local alignment = math.abs(math.dot3(dx, dy, dz, vx, vy, vz))

            particle.velocity_x = particle.velocity_x + particle.direction_x * particle.direction_magnitude * particle.mass + delta * gravity_x * alignment * particle.mass * fraction
            particle.velocity_y = particle.velocity_y + particle.direction_y * particle.direction_magnitude * particle.mass + delta * gravity_y * alignment * particle.mass * fraction
            particle.velocity_z = particle.velocity_z + particle.direction_z * particle.direction_magnitude * particle.mass + delta * gravity_z * alignment * particle.mass * fraction

            particle.position_x = particle.position_x + particle.velocity_x * delta
            particle.position_y = particle.position_y + particle.velocity_y * delta
            particle.position_z = particle.position_z + particle.velocity_z * delta

            if fraction > 1 - fade_out_duration then
                particle.color[4] = 1 - (fraction - (1 - fade_out_duration)) / fade_out_duration
            end
        end

        self._elapsed = self._elapsed + delta
        if self._elapsed > duration then
            self._particles = {}
            self._active = false
            break
        end

        _canvas:bind()
        love.graphics.push()
        local w, h = _canvas:get_size()
        local camera_x, camera_y = self._scene:get_camera()
        love.graphics.translate(self._spawn_offset_x, self._spawn_offset_y)
        for particle in values(self._particles) do
            love.graphics.setColor(table.unpack(particle.color))
            love.graphics.circle("fill", particle.position_x, particle.position_y, particle.radius)
        end
        love.graphics.pop()
        _canvas:unbind()

        _elapsed = _elapsed - _step
    end
end

--- @brief
function ow.Fireworks:draw()
    if not self._active then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.origin()
    local w, h = _canvas:get_size()
    _canvas:draw()
    love.graphics.pop()
end

--- @brief
function ow.Fireworks:get_is_done()
    return not self._active
end