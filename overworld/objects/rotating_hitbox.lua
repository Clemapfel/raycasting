rt.settings.overworld.rotating_hitbox =  {
    default_velocity = 1 / 3, -- radians per second
}

--- @class ow.RotatingHitbox
ow.RotatingHitbox = meta.class("RotatingHitbox")

--- @class ow.RotatingHitboxTarget
ow.RotatingHitboxTarget = meta.class("RotatingHitboxTarget")

--- @brief
function ow.RotatingHitbox:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._velocity = object:get_number("velocity", false) or rt.settings.overworld.rotating_hitbox.default_velocity

    local target = object:get_object("target", true)
    assert(target:get_type() == ow.ObjectType.POINT, "In ow.RotatingHitbox: `RotatingHitboxTarget` (" .. object:get_id() .. ") is not a point")

    self._x = target.x
    self._y = target.y

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
    self._body:set_collides_with(rt.settings.player.bounce_collision_group)
    self._body:set_collision_group(rt.settings.player.bounce_collision_group)

    -- resets cycle on player spawn
    self._start_timestamp = love.timer.getTime()
    self._stage:signal_connect("respawn", function()
        self._start_timestamp = love.timer.getTime()
    end)

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

--- @brief
function ow.RotatingHitbox:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local elapsed = (love.timer.getTime() - self._start_timestamp)

    local full_rotation = 2 * math.pi
    local distance = self._velocity * elapsed
    local t = (distance / full_rotation) % 1.0

    local dt = 0.0001  -- Small delta for numerical differentiation
    local easing_t = self._easing(t)
    local easing_t_dt = self._easing((t + dt) % 1.0)
    local easing_derivative = (easing_t_dt - easing_t) / dt

    -- Set angular velocity based on easing derivative
    --self._body:set_angular_velocity(self._velocity * easing_derivative)
    self._body:set_rotation(t * 2 * math.pi)
end

--- @brief
function ow.RotatingHitbox:draw(x, y)
    if not self._stage:get_is_body_visible(self._body) then return end
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

--- @brief
function ow.RotatingHitbox:get_render_priority()
    return math.huge
end