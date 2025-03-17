require "overworld.ray_material"
require "common.particle_emitter"

rt.settings.overworld.raycast = {
    width = 2,
    laser_color = rt.Palette.RED_4
}

--- @class ow.Raycast
ow.Raycast = meta.class("OverworldRaycast", rt.Drawable)

local _particle_texture = nil
local _static_instances = meta.make_weak({})

--- @brief
function ow.Raycast:instantiate(world)
    meta.assert(world, "PhysicsWorld")

    if _particle_texture == nil then
        _particle_texture = rt.Texture("assets/sprites/laser_particle.png")
    end

    meta.install(self, {
        _lines = {},
        _world = world,
        _receivers = {},
        _is_active = false,

        _last_origin_x = 0,
        _last_origin_y = 0,
        _last_direction_x = 0,
        _last_direction_y = 0,

        _particle = _particle_texture,
        _particle_emitter = rt.ParticleEmitter(_particle_texture),

        _particle_x = 0,
        _particle_y = 0,
        _particle_visible = false,
    })

    self._id = meta.hash(self)

    self._particle_emitter:realize()
    self._particle_emitter:set_emission_rate(50)
    self._particle_emitter:set_particle_lifetime(0.2, 0.3)
    self._particle_emitter:set_emission_area(rt.ParticleEmissionAreaShape.ROUND)
    self._particle_emitter:set_rotation(0, 2 * math.pi)
    self._particle_emitter:set_sizes(0.1, 0.5)
    self._particle_emitter:set_color(rt.color_unpack(rt.settings.overworld.raycast.laser_color))

    local r = 3
    self._particle_emitter:reformat(0, 0, 2 * r, 2 *  r)

    local _elapsed = 0
    world:signal_connect("step", function(world, delta)
        _elapsed = _elapsed + delta
        if _elapsed > 1 / 60 then
            if self._is_active then
                self:start(self._last_origin_x, self._last_origin_y, self._last_direction_x, self._last_direction_y)
            end
            _elapsed = 0
        end
    end)

    table.insert(_static_instances, self)
end

--- @brief
function ow.Raycast:stop()
    for receiver in values(self._receivers) do
        receiver:signal_emit("ray_collision_end")
    end
    self._receivers = {}
    self._lines = {}
    self._is_active = false
end

local _max_n_bounces = 10000
local _scale = function(dx, dy)
    dx, dy = math.normalize(dx, dy)
    return dx * 10e9, dy * 10e9
end

local _mask -- things rays collide with
do
    _mask = 0x0
    _mask = bit.bor(_mask, ow.RayMaterial.ABSORPTIVE)
    _mask = bit.bor(_mask, ow.RayMaterial.FILTRATIVE)
    _mask = bit.bor(_mask, ow.RayMaterial.REFLECTIVE)
    _mask = bit.bor(_mask, ow.RayMaterial.RECEIVER)
    _mask = bit.bor(_mask, ow.RayMaterial.TELEPORTER)
    _mask = bit.bor(_mask, ow.RayMaterial.BEAM_SPLITTER)
end

--- @brief
function ow.Raycast:start(x, y, dx, dy)
    self:stop()

    self._last_origin_x = x
    self._last_origin_y = y
    self._last_direction_x = dx
    self._last_direction_y = dy

    self._particle_visible = false

    self._is_active = true
    self._lines = {{x, y}}
    local n_lines = 1

    local world = self._world:get_native()
    local ndx, ndy = _scale(dx, dy)
    local shape, contact_x, contact_y, normal_x, normal_y = world:rayCastClosest(
        x, y,
        x + ndx, y + ndy,
        _mask
    )

    local n_bounces = 0
    while shape ~= nil and n_bounces <= _max_n_bounces do
        table.insert(self._lines[n_lines], contact_x)
        table.insert(self._lines[n_lines], contact_y)

        local category, _, _ = shape:getFilterData()
        if bit.band(category, ow.RayMaterial.REFLECTIVE) ~= 0x0 then
            local dot_product = dx * normal_x + dy * normal_y
            dx = dx - 2 * dot_product * normal_x
            dy = dy - 2 * dot_product * normal_y

            ndx, ndy = _scale(dx, dy)
            contact_x = math.round(contact_x) -- to reduce numerical error
            contact_y = math.round(contact_y)

            shape, contact_x, contact_y, normal_x, normal_y = world:rayCastClosest(
                contact_x, contact_y,
                contact_x + ndx, contact_y + ndy,
                _mask
            )
        elseif bit.band(category, ow.RayMaterial.RECEIVER) ~= 0x0 then
            local receiver = shape:getBody():getUserData():get_user_data()
            meta.assert(receiver, ow.RayReceiver)

            if receiver:signal_try_emit("ray_collision_start", contact_x, contact_y, normal_x, normal_y) then
                table.insert(self._receivers, receiver)
            end
            break -- receiver absorbs
        elseif bit.band(category, ow.RayMaterial.TELEPORTER) ~= 0x0 then
            local teleporter = shape:getBody():getUserData():get_user_data()
            meta.assert(teleporter, ow.RayTeleporter)

            -- move ray origin and direction based on teleporter
            contact_x, contact_y, dx, dy = teleporter:teleport_ray(self._id, contact_x, contact_y, dx, dy, normal_x, normal_y)

            ndx, ndy = _scale(dx, dy)
            contact_x = math.round(contact_x) -- to reduce numerical error
            contact_y = math.round(contact_y)

            table.insert(self._lines, { contact_x, contact_y })
            n_lines = n_lines + 1

            shape, contact_x, contact_y, normal_x, normal_y = world:rayCastClosest(
                contact_x, contact_y,
                contact_x + ndx, contact_y + ndy,
                _mask
            )
        elseif bit.band(category, ow.RayMaterial.BEAM_SPLITTER) ~= 0x0 then
            local beam_splitter = shape:getBody():getUserData():get_user_data()
            meta.assert(beam_splitter, ow.BeamSplitter)

            table.insert(self._lines[n_lines], contact_x)
            table.insert(self._lines[n_lines], contact_y)

            contact_x, contact_y, dx, dy = beam_splitter:split_ray(self._id, contact_x, contact_y, dx, dy, normal_x, normal_y)

            table.insert(self._lines[n_lines], contact_x)
            table.insert(self._lines[n_lines], contact_y)

            shape, contact_x, contact_y, normal_x, normal_y = world:rayCastClosest(
                contact_x, contact_y,
                contact_x + ndx, contact_y + ndy,
                _mask
            )

        else -- absorptive
            self._particle_x = contact_x
            self._particle_y = contact_y
            self._particle_visible = true
            break
        end

        n_bounces = n_bounces + 1
    end

    if shape == nil then -- shoot off into infinity if no hit for last segment
        local points = self._lines[n_lines]
        local last_x, last_y = points[#points - 1], points[#points]
        dx, dy = _scale(dx, dy)
        table.insert(points, last_x + dx)
        table.insert(points, last_y + dy)
    end
end

--- @brief
function ow.Raycast:update(delta)
    self._particle_emitter:update(delta)
end

--- @brief
function ow.Raycast:draw()
    if self._is_active == false then return end

    --[[
    local line_width = rt.settings.overworld.raycast.width

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(line_width)
    love.graphics.setLineJoin("none")
    for line in values(self._lines) do
        if #line >= 4 then
            love.graphics.line(line)
            for i = 1, #line, 2 do
                love.graphics.circle("fill", line[i], line[i+1], 2 * line_width)
            end
        end
    end
    ]]--

    if self._particle_visible then
        love.graphics.push()
        love.graphics.translate(self._particle_x, self._particle_y)
        self._particle_emitter:draw()
        love.graphics.pop()
    end
end

--- @brief
function ow.Raycast.draw_all()
    local line_width = rt.settings.overworld.raycast.width
    love.graphics.setColor(rt.color_unpack(rt.settings.overworld.raycast.laser_color))
    love.graphics.setLineWidth(line_width)
    love.graphics.setLineJoin("none")

    for object in values(_static_instances) do
        if object._is_active then
            for line in values(object._lines) do
                if #line >= 4 then
                    love.graphics.line(line)
                    for i = 1, #line, 2 do
                        love.graphics.circle("fill", line[i], line[i+1], line_width)
                    end
                end
            end
        end
    end
end