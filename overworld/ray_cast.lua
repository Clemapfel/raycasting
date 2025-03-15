require "overworld.ray_material"

--- @class ow.Raycast
ow.Raycast = meta.class("OverworldRaycast", rt.Drawable)

--- @brief
function ow.Raycast:instantiate(scene, world)
    meta.assert(world, "PhysicsWorld")
    meta.install(self, {
        _lines = {},
        _scene = scene,
        _world = world,
        _receivers = {}
    })
end

--- @brief
function ow.Raycast:stop()
    for receiver in values(self._receivers) do
        receiver:signal_emit("ray_collision_end")
    end
    self._receivers = {}
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
end

--- @brief
function ow.Raycast:start(x, y, dx, dy)
    self:stop()
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
            contact_x, contact_y, dx, dy = teleporter:teleport_ray(contact_x, contact_y, dx, dy, normal_x, normal_y)

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
        else
            break -- absorptive
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
function ow.Raycast:draw()
    local line_width = 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(line_width)
    love.graphics.setLineJoin("none")
    for line in values(self._lines) do
        if #line >= 4 then
            love.graphics.line(line)
            for i = 1, #line, 2 do
                love.graphics.circle("fill", line[i], line[i+1], 0.5 * line_width)
            end
        end
    end
end
