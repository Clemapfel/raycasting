require "common.path"
require "common.contour"

rt.settings.overworld.moving_hitbox = {
    default_velocity = 100, -- px per second
}

--- @class ow.MovingHitbox
ow.MovingHitbox = meta.class("MovingHitbox")

--- @class ow.MovingHitboxTarget
ow.MovingHitboxTarget = meta.class("MovingHitboxTarget")

--- @brief
function ow.MovingHitbox:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    -- read path by iterating through nodes
    local target = object:get_object("target", true)
    local path = {}
    repeat
        assert(target:get_type() == ow.ObjectType.POINT, "In ow.MovingHitbox: `MovingHitboxTarget` (" .. object:get_id() .. ") is not a point")
        table.insert(path, target.x)
        table.insert(path, target.y)
        target = target:get_object("target")
    until target == nil

    self._should_loop = object:get_boolean("should_loop", false)
    if self._should_loop == nil then self._should_loop = false end

    if self._should_loop then
        table.insert(path, path[1])
        table.insert(path, path[2])
        self._path = rt.Path(path)
    else
        self._path = rt.Path(path)
    end

    self._x, self._y = self._path:at(0)

    local centroid_x, centroid_y = object:get_centroid()
    self._offset_x, self._offset_y = centroid_x - self._x, centroid_y - self._y
    self._velocity = object:get_number("velocity", false) or rt.settings.overworld.moving_hitbox.default_velocity

    local easing = rt.InterpolationFunctions.LINEAR
    local easing_name = object:get_string("easing", false)
    if easing_name ~= nil then
        easing = rt.InterpolationFunctions[easing_name]
        if easing == nil then
            rt.error("In ow.MovingPlatform: for object `" .. object:get_id() .. "`: unknown easing `" .. easing_name .. "`")
        end
    end
    self._easing = easing

    self._body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.KINEMATIC)
    self._body:add_tag("stencil")
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    -- reset cycle on player respawn
    self._start_timestamp = love.timer.getTime()
    self._stage:signal_connect("respawn", function()
        self._start_timestamp = love.timer.getTime()
    end)

    -- mesh
    -- mesh
    local _, tris, mesh_data
    _, tris, mesh_data = object:create_mesh()

    local mass_x, mass_y  = self._body:get_position()
    self._centroid_x, self._centroid_y = mass_x, mass_y
    for data in values(mesh_data) do
        data[1] = data[1] - mass_x
        data[2] = data[2] - mass_y
    end

    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
end

local dt = math.eps * 10e2

function ow.MovingHitbox:update(_)
    --if not self._scene:get_is_body_visible(self._body) then return end

    local elapsed = (love.timer.getTime() - self._start_timestamp)
    local length = self._path:get_length()
    local t, direction, easing_derivative

    if self._should_loop then
        local distance = self._velocity * elapsed
        t = (distance / length) % 1.0
        direction = 1

        local easing_t = self._easing(t)
        local easing_t_dt = self._easing((t + dt) % 1.0)
        easing_derivative = (easing_t_dt - easing_t) / dt
    else
        local distance_in_cycle = (self._velocity * elapsed) % (2 * length)

        if distance_in_cycle <= length then
            -- going forwards
            t = distance_in_cycle / length
            direction = 1

            local easing_t = self._easing(t)
            local easing_t_dt = self._easing(math.min(t + dt, 1.0))
            easing_derivative = (easing_t_dt - easing_t) / dt
        else
            -- going backwards
            local backward_distance = distance_in_cycle - length
            t = (length - backward_distance) / length
            direction = -1

            -- calculate derivative for backward motion (reversed easing)
            local reversed_t = 1 - t
            local easing_t = self._easing(math.max(reversed_t - dt, 0.0))
            local easing_t_dt = self._easing(reversed_t)
            easing_derivative = (easing_t_dt - easing_t) / dt
        end
    end

    local dx, dy = self._path:get_tangent(t)
    self._body:set_velocity(
        dx * self._velocity * direction * easing_derivative,
        dy * self._velocity * direction * easing_derivative
    )
end

--- @brief
function ow.MovingHitbox:draw()
    if not self._scene:get_is_body_visible(self._body) then return end
    love.graphics.push()
    love.graphics.translate(self._body:get_position())
    love.graphics.rotate(self._body:get_rotation())

    rt.Palette.RED:bind()
    love.graphics.setWireframe(true)
    self._mesh:draw()
    love.graphics.setWireframe(false)

    love.graphics.pop()

    self._body:draw()
end