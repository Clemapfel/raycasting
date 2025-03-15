require "overworld.ray_material"

--- @class ow.Raycast
ow.Raycast = meta.class("OverworldRaycast", rt.Drawable)

--- @brief
function ow.Raycast:instantiate(scene, world)
    meta.assert(world, "PhysicsWorld")
    meta.install(self, {
        _points = {},
        _scene = scene,
        _world = world,
        _receivers = {}
    })
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
end

function ow.Raycast:stop()
    for receiver in values(self._receivers) do
        receiver:signal_emit("ray_collision_end")
    end
    self._receivers = {}
end

function ow.Raycast:start(x, y, dx, dy)
    self:stop()

    local _should_stop = function(shape, x, y, nx, ny)
        if shape == nil then return true end
        local category, _, _ = shape:getFilterData()
        local should_reflect = bit.band(category, ow.RayMaterial.REFLECTIVE) == 0x0

        if bit.band(category, ow.RayMaterial.RECEIVER) ~= 0x0 then
            local receiver = shape:getBody():getUserData():get_user_data()
            if receiver:signal_try_emit("ray_collision_start", x, y, nx, y) then
                table.insert(self._receivers, receiver)
            end
        end

        if bit.band(category, ow.RayMaterial.TELEPORTER) ~= 0x0 then
            local teleporter = shape:getBody():getUserdata():get_user_data()
        end

        return should_reflect
    end

    self._points = {x, y}
    local world = self._world._native

    local ndx, ndy = _scale(dx, dy)
    local shape, contact_x, contact_y, normal_x, normal_y = world:rayCastClosest(
        x, y,
        x + ndx, y + ndy,
        _mask
    )

    local n_bounces = 0
    while contact_x ~= nil do
        table.insert(self._points, contact_x)
        table.insert(self._points, contact_y)

        if _should_stop(shape) then break end

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

        n_bounces = n_bounces + 1
        if n_bounces > _max_n_bounces then
            break
        end
    end

    if shape == nil then -- shoot off into infinity if no hit for last segment
        local last_x, last_y = self._points[#self._points - 1], self._points[#self._points]
        dx, dy = _scale(dx, dy)
        table.insert(self._points, last_x + dx)
        table.insert(self._points, last_y + dy)
    end
end


--- @brief
function ow.Raycast:draw()
    local line_width = 2
    if #self._points >= 4 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(line_width)
        love.graphics.setLineJoin("none")
        love.graphics.line(self._points)
        for i = 1, #self._points, 2 do
            love.graphics.circle("fill", self._points[i], self._points[i+1], 0.5 * line_width)
        end
    end
end
