rt.settings.overworld.boost_field = {
    acceleration_duration = 0.2, -- seconds to accelerate player from 0 to max
    max_velocity = 1500,
    bloom = 0.4
}

--- @class ow.BoostField
--- @field axis ow.ObjectWrapper axis from centroid of self to axis point
ow.BoostField = meta.class("BoostField")

--- @class ow.BoostFieldAxis
ow.BoostFieldAxis = meta.class("BoostFieldAxis") -- dummy

local _shader = rt.Shader("overworld/objects/boost_field.glsl")

-- batched outlines
local _initialized = false
local _instances = {}
local _tris = {}
local _lines = {}
local _mesh = nil

--- @brief
function ow.BoostField:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)
    self._use_exact_testing = table.sizeof(self._body:get_native():getShapes()) > 1

    self._body:signal_connect("collision_start", function()
        if not self._use_exact_testing then
            self._is_active = true
        end

        self._player:set_use_wall_friction(false)
    end)

    self._body:signal_connect("collision_end", function()
        if not self._use_exact_testing then
            self._is_active = false
        end

        self._player:set_use_wall_friction(true)
    end)

    self._body:set_user_data(self)

    self._scene = scene
    self._player = self._scene:get_player()

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

    self._color = { rt.lcha_to_rgba(0.8, 1, math.angle(self._axis_x, self._axis_y) / (2 * math.pi), 0.8) }

    -- shader aux
    self._camera_offset_x = 0
    self._camera_offset_y = 0
    self._camera_scale = 1
    self._elapsed = 0

    local aabb = self._body:compute_aabb()
    self._origin_offset_x, self._origin_offset_y = aabb.x, aabb.y

    local tris
    self._mesh, tris = object:create_mesh()

    -- batched drawing
    table.insert(_instances, self)

    for tri in values(tris) do
        table.insert(_tris, tri)
        table.insert(_lines, {
            tri[1], tri[2], tri[3], tri[4], tri[5], tri[6], tri[1], tri[2]
        })
    end
end

--- @brief
function ow.BoostField:update(delta)
    self._elapsed = self._elapsed + delta

    local is_active = self._is_active
    if self._use_exact_testing then
        is_active = self._body:test_point(self._player:get_position())
    end

    if is_active then
        local vx, vy = self._player:get_physics_body():get_velocity() -- use actual velocity

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
function ow.BoostField:reinitialize()
    _initialized = false
    _instances = {}
    _tris = {}
    _lines = {}

    if _mesh ~= nil then
        _mesh:release()
    end
    _mesh = nil
end

--- @brief batched drawing
function ow.BoostField.draw_all()
    if _initialized ~= true and table.sizeof(_tris) > 0 then
        local format = { {location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2"} }
        local mode, usage = rt.MeshDrawMode.TRIANGLES, rt.GraphicsBufferUsage.STATIC

        local data = {}
        for tri in values(_tris) do
            table.insert(data, { tri[1], tri[2] })
            table.insert(data, { tri[3], tri[4] })
            table.insert(data, { tri[5], tri[6] })
        end
        _mesh = love.graphics.newMesh(format, data, mode, usage)
        _initialized = true
    end
    if _mesh == nil then return end

    love.graphics.setBlendMode("alpha")

    -- draw shader surface per instance
    for self in values(_instances) do
        if self._scene:get_is_body_visible(self._body) then
            love.graphics.setColor(self._color)
            _shader:bind()
            _shader:send("elapsed", self._elapsed)
            _shader:send("origin_offset", { self._origin_offset_x, self._origin_offset_y })
            _shader:send("camera_offset", { self._camera_offset_x, self._camera_offset_y })
            _shader:send("camera_scale", self._camera_scale)
            _shader:send("axis", { self._axis_x, self._axis_y })
            love.graphics.draw(self._mesh:get_native())
            _shader:unbind()
        end
    end

    -- draw outlines as giant batch
    love.graphics.setLineJoin("bevel")
    local line_width = 2

    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
    love.graphics.draw(_mesh)

    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(line_width + 2)
    for lines in values(_lines) do
        love.graphics.line(lines)
    end

    rt.Palette.BOOST_OUTLINE:bind()
    love.graphics.setLineWidth(line_width)
    for lines in values(_lines) do
        love.graphics.line(lines)
    end

    rt.graphics.set_stencil_mode(nil)
end

--- @brief
function ow.BoostField:draw_bloom()
    if self._scene:get_is_body_visible(self._body) then
        local r, g, b, a = table.unpack(self._color)
        local bloom = rt.settings.overworld.boost_field.bloom
        love.graphics.setColor(bloom * r, bloom * g, bloom * b, bloom * a)
        love.graphics.draw(self._mesh:get_native())
    end
end