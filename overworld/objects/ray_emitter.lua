--- @class ow.RayEmitter
ow.RayEmitter = meta.class("RayEmitter", rt.Drawable)
ow.RayEmitterDirection = meta.class("RayEmitterDirection") -- dummy

--- @brief
function ow.RayEmitter:instantiate(object, stage, scene)
    local world = stage:get_physics_world()

    meta.install(self, {
        _body = object:create_physics_body(world),
        _raycast = ow.Raycast(world),
        _ray_active = false
    })

    local direction = object:get_object("direction")
    assert(direction ~= nil and direction.type == ow.ObjectType.POINT, "In ow.RayEmitter: `direction` property of object `" .. object.id .. "` is not set or does not point to a valid point")
    local centroid_x, centroid_y = object:get_centroid()
    self._origin_x = centroid_x
    self._origin_y = centroid_y
    self._direction_x = direction.x - centroid_x
    self._direction_y = direction.y - centroid_y

    self._body:signal_connect("activate", function()
        self._ray_active = not self._ray_active
        if self._ray_active then
            self._raycast:start(self._origin_x, self._origin_y, self._direction_x, self._direction_y)
        else
            self._raycast:stop()
        end
    end)
end

--- @brief
function ow.RayEmitter:draw()
    self._raycast:draw()
    self._body:draw()
end

--- @brief
function ow.RayEmitter:update(delta)
    self._raycast:update(delta)
end