require "common.smoothed_motion_1d"
require "common.impulse_manager"
require "overworld.movable_object"

rt.settings.overworld.boost_field = {
    acceleration_duration = 0.2, -- seconds to accelerate player from 0 to max
    max_velocity = 1500,
    bloom = 0.4,
    line_width = 3
}

--- @class ow.BoostField
--- @types Polygon, Rectangle, Ellipse
--- @field velocity Number?
--- @field axis ow.BoostFieldAxis! non-optional
ow.BoostField = meta.class("BoostField", ow.MovableObject)

--- @class ow.BoostFieldAxis
--- @types Point
--- @field axis_x Number! in [-1, 1]
--- @field axis_y Number! in [-1, 1]
ow.BoostFieldAxis = meta.class("BoostFieldAxis") -- dummy

local _shader
do
    local defines = {}
    if love.graphics.getSupported().shaderderivatives then
        defines.SHADER_DERIVATIVES_AVAILABLE = 1
    end
    _shader = rt.Shader("overworld/objects/boost_field.glsl", defines)
end

--- @brief
function ow.BoostField:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)
    self._use_exact_testing = table.sizeof(self._body:get_native():getShapes()) > 1

    self._is_active = false
    self._player_influence_motion = rt.SmoothedMotion1D(0, 1)
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

    self._scene = scene
    self._stage = stage
    self._player = self._scene:get_player()

    local factor = object:get_number("velocity", false) or 1
    self._velocity_factor = factor
    dbg(factor)
    self._target_velocity = rt.settings.overworld.boost_field.max_velocity * factor

    local axis_mandatory = false
    local axis = object:get_object("axis", axis_mandatory)
    if axis == nil then
        local axis_x = object:get_number("axis_x", axis_mandatory)
        local axis_y = object:get_number("axis_y", axis_mandatory)
        self._axis_x = axis_x or 0
        self._axis_y = axis_y or -1
    else
        assert(axis:get_type() == ow.ObjectType.POINT, "In ow.BoostField.instantiate: `axis` target is not a point")
        local start_x, start_y = self._body:get_center_of_mass()
        local end_x, end_y = axis.x, axis.y
        self._axis_x, self._axis_y = math.normalize(end_x - start_x, end_y - start_y)
    end

    self._hue = object:get_number("hue", false)
    if self._hue == nil then self._hue = math.angle(self._axis_x, self._axis_y) / (2 * math.pi) end
    self._color = { rt.lcha_to_rgba(0.8, 1, self._hue, 0.8) }

    self._draw_offset_x, self._draw_offset_y = object:get_centroid()
    self._mesh = object:create_mesh()
    self._outline = object:create_contour()
    table.insert(self._outline, self._outline[1])
    table.insert(self._outline, self._outline[2])

    self._impulse = rt.ImpulseSubscriber()
end

--- @brief
function ow.BoostField:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

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

    self._is_active = is_active

    self._player_influence_motion:update(delta)
    self._player_influence_motion:set_target_value(ternary(is_active, 1, 0))
end

--- @brief batched drawing
function ow.BoostField:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push()
    local offset_x, offset_y = self._body:get_position()
    love.graphics.translate(-self._draw_offset_x + offset_x, -self._draw_offset_y + offset_y)

    local player = self._scene:get_player()
    local camera = self._scene:get_camera()
    local px, py = player:get_position()
    px, py = camera:world_xy_to_screen_xy(px, py)

    local transform = self._scene:get_camera():get_transform()
    transform:translate(offset_x, offset_y)
    transform = transform:inverse()

    local player_opacity = ternary(player:get_is_visible(), 1, 0)

    love.graphics.setColor(self._color)
    _shader:bind()
    _shader:send("player_position", { px, py })
    _shader:send("player_color", { rt.lcha_to_rgba(0.8, 1, player:get_hue(), player_opacity) })
    _shader:send("screen_to_world_transform", transform)
    _shader:send("player_influence", self._player_influence_motion:get_value() * math.mix(1, 1.4, self._impulse:get_beat()))
    _shader:send("axis", { self._axis_x, self._axis_y })
    _shader:send("brightness_offset", math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._impulse:get_pulse()))
    _shader:send("elapsed", rt.SceneManager:get_elapsed() * self._velocity_factor)
    love.graphics.draw(self._mesh:get_native())
    _shader:unbind()

    love.graphics.setLineJoin("bevel")
    local line_width = rt.settings.overworld.boost_field.line_width

    local offset = math.mix(1, 1.4, self._impulse:get_pulse())

    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(line_width * offset + 2)
    love.graphics.line(self._outline)

    local r, g, b, a = table.unpack(self._color)
    love.graphics.setColor(r * offset, g * offset, b * offset, a)
    love.graphics.setLineWidth(line_width * offset)
    love.graphics.line(self._outline)

    love.graphics.pop()
end

--- @brief
function ow.BoostField:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.push()
    local offset_x, offset_y = self._body:get_position()
    love.graphics.translate(-self._draw_offset_x + offset_x, -self._draw_offset_y + offset_y)
    love.graphics.translate(self._body:get_position())

    rt.Palette.WHITE:bind()
    love.graphics.setColor(self._color)
    love.graphics.setLineWidth(rt.settings.overworld.boost_field.line_width)
    love.graphics.line(self._outline)

    love.graphics.pop()
end

--- @brief
function ow.BoostField:reset()
    self._is_active = false
end