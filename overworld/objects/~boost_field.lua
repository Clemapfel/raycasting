rt.settings.overworld.boost_field = {
    acceleration_duration = 0.2, -- seconds to accelerate player from 0 to max
    max_velocity = 1500
}

--- @class ow.BoostField
--- @field axis ow.ObjectWrapper axis from centroid of self to axis point
ow.BoostField = meta.class("BoostField")

--- @class ow.BoostFieldAxis
ow.BoostFieldAxis = meta.class("BoostFieldAxis") -- dummy

local _shader = nil

--- @brief
function ow.BoostField:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)

    self._use_exact_testing = table.sizeof(self._body:get_native():getShapes()) > 1

    if not self._use_exact_testing then
        self._body:signal_connect("collision_start", function()
            self._is_active = true
        end)

        self._body:signal_connect("collision_end", function()
            self._is_active = false
        end)
    end

    self._target = object
    self._elapsed = 0
    self._scene = scene

    local factor = object:get_number("velocity") or 1
    self._target_velocity = rt.settings.overworld.boost_field.max_velocity * factor
    local axis = object:get_object("axis")
    if axis == nil then
        local axis_x = object:get_number("axis_x")
        local axis_y = object:get_number("axis_y")
        self._axis_x = axis_x or 0
        self._axis_y = axis_y or -1
    else
        assert(axis:get_type() == ow.ObjectType.POINT, "In ow.BoostField.instantiate: `axis` target is not a point")
        local start_x, start_y = self._body:get_center_of_mass()
        local end_x, end_y = axis.x, axis.y
        self._axis_x, self._axis_y = math.normalize(end_x - start_x, end_y - start_y)
    end

    self._player = self._scene:get_player()

    self._mesh, self._tris = object:create_mesh()

    for tri in values(self._tris) do -- close for line loop
        table.insert(tri, tri[1])
        table.insert(tri, tri[2])
    end
    self._mesh = self._mesh:get_native()

    -- shader aux
    self._camera_offset_x = 0
    self._camera_offset_y = 0
    self._camera_scale = 1
    self._elapsed = 0

    self._color_r, self._color_g, self._color_b, self._color_a = rt.Palette.BOOST:unpack()

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "^" then
            _shader:recompile()
        end
    end)

    local aabb = self._body:compute_aabb()
    self._aabb = aabb -- TODO
    self._origin_offset_x, self._origin_offset_y = aabb.x, aabb.y
end

--- @brief
function ow.BoostField:update(delta)
    self._elapsed = self._elapsed + delta

    local is_active = self._is_active
    if self._use_exact_testing then
        is_active = self._body:test_point(self._player:get_position())
    end

    if is_active then
        local vx, vy = self._player:get_physics_body():get_velocity() -- sic, use actual velocity

        local target = self._target_velocity
        local target_vx, target_vy = self._axis_x * target, self._axis_y * target

        target_vy = target_vy - rt.settings.player.gravity * delta

        local duration = rt.settings.overworld.boost_field.acceleration_duration

        local dx = target_vx - vx
        local dy = target_vy - vy

        -- prevent decreasing velocity if already above target
        if (dx > 0 and target_vx < 0) or (dx < 0 and target_vx > 0) then
            dx = 0
        end

        if (dy > 0 and target_vy < 0) or (dy < 0 and target_vy > 0) then
            dy = 0
        end

        local new_vx = vx + dx * (1 / duration) * delta
        local new_vy = vy + dy * (1 / duration) * delta

        self._player:get_physics_body():set_velocity(new_vx, new_vy)
    end

    local camera = self._scene:get_camera()
    self._camera_offset_x, self._camera_offset_y = camera:get_offset()
    self._camera_scale = camera:get_scale()
end

--- @brief
function ow.BoostField:draw()
    if _shader == nil then _shader = rt.Shader("overworld/objects/boost_field.glsl") end

    love.graphics.setColor(self._color_r, self._color_g, self._color_b, 0.4)
    love.graphics.draw(self._mesh)

    love.graphics.setColor(self._color_r, self._color_g, self._color_b, self._color_a)
    _shader:bind()
    _shader:send("elapsed", self._elapsed)
    _shader:send("origin_offset", { self._origin_offset_x, self._origin_offset_y })
    _shader:send("camera_offset", { self._camera_offset_x, self._camera_offset_y })
    _shader:send("camera_scale", self._camera_scale)
    _shader:send("axis", { self._axis_x, self._axis_y })
    love.graphics.draw(self._mesh)
    _shader:unbind()

    -- outline
    --[[
    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.stencil(stencil_value, function()
        love.graphics.draw(self._mesh)
    end)
    rt.graphics.set_stencil_compare_mode(rt.StencilCompareMode.NOT_EQUAL, stencil_value)

    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(2)
    for tri in values(self._tris) do
        love.graphics.line(tri)
    end
    ]]--

    rt.graphics.set_stencil_compare_mode(nil)
end
