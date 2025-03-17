require "common.sound_manager"

rt.settings.overworld.ray_receiver = {
    fill_duration = 5, -- seconds
    fill_sound_id = "ray_receiver_fill",
    fill_complete_sound_id = "ray_receiver_fill_complete"
}

--- @class ow.RayReceiver
ow.RayReceiver = meta.class("RayReceiver", rt.Drawable)
meta.add_signals(ow.RayReceiver, "ray_collision_start", "ray_collision_end", "activate")

--- @brief
function ow.RayReceiver:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper", stage, "Stage", scene, "OverworldScene")
    self._world = stage:get_physics_world()
    self._body = object:create_physics_body(self._world)
    self._body:set_user_data(self)

    local group = 0x0
    group = bit.bor(group, ow.RayMaterial.ABSORPTIVE)
    group = bit.bor(group, ow.RayMaterial.RECEIVER)
    self._body:set_collision_group(group)

    self:signal_connect("ray_collision_start", function(self, x, y, nx, ny)
        self._is_active = true
    end)

    self:signal_connect("ray_collision_end", function(self)
        self._is_active = false
    end)

    assert(object.type == ow.ObjectType.ELLIPSE, "In ow.RayReceiver: expected objcet type `ELLIPSE`, got `" .. object.type .. "`")
    self._x = object.center_x
    self._y = object.center_y
    self._x_radius = object.x_radius
    self._y_radius = object.y_radius
    self._fraction_vertices = {}

    self._fraction = 0
    self._signal_emitted = false
end

--- @brief
function ow.RayReceiver:draw()
    love.graphics.push()
    love.graphics.translate(self._body:get_position())

    love.graphics.setColor(rt.color_unpack(rt.Palette.BLACK))
    love.graphics.setLineWidth(4)
    love.graphics.ellipse("line", self._x, self._y, self._x_radius, self._y_radius)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.ellipse("line", self._x, self._y, self._x_radius, self._y_radius)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.ellipse("fill", self._x, self._y, self._x_radius, self._y_radius)

    if self._fraction > 0 and #self._fraction_vertices >= 6 then
        local r, g, b = rt.color_unpack(rt.settings.overworld.raycast.laser_color)
        love.graphics.setColor(r, g, b, 0.8)
        love.graphics.polygon("fill", self._fraction_vertices)
        love.graphics.setColor(r - 0.2, g - 0.2, b - 0.2, 1)
        love.graphics.polygon("line", self._fraction_vertices)
    end

    love.graphics.pop()
end

--- @brief
function ow.RayReceiver:update(delta)
    local before = self._fraction

    if self._is_active then
        self._fraction = self._fraction + delta * 1 / rt.settings.overworld.ray_receiver.fill_duration
    else
        self._fraction = self._fraction - delta * 1 / rt.settings.overworld.ray_receiver.fill_duration
    end

    self._fraction = math.clamp(self._fraction, 0, 1)
    if before ~= self._fraction then
        self:_update_fraction()

        local fraction_delta = self._fraction - before
        local x, y = self._body:get_position()
        rt.SoundManager:play(rt.settings.overworld.ray_receiver.fill_sound_id, x, y, self._fraction) -- pitch

        if self._fraction == 1 and not self._signal_emitted then
            self:signal_emit("activate")
            rt.SoundManager:player(rt.settings.overworld.ray_receiver.fill_complete_sound_id, x, y)
            self._signal_emitted = true
        elseif self._fraction < 1 then
            self._signal_emitted = false
        end
    end
end

--- @brief
function ow.RayReceiver:_update_fraction()
    local x, y, x_radius, y_radius = self._x, self._y, self._x_radius, self._y_radius

    local height = 2 * y_radius
    self._fraction_vertices = {}

    local x1, y1 = x - x_radius, y - y_radius + (1 - math.clamp(self._fraction, 0, 1)) * (2 * y_radius)
    local x2, y2 = x + x_radius, y1

    local step = (2 * math.pi) / 128
    for angle = 0, 2 * math.pi + step, step do
        local cy = y + math.sin(angle) * y_radius
        if cy >= y1 then
            local cx = x + math.cos(angle) * x_radius
            table.insert(self._fraction_vertices, cx)
            table.insert(self._fraction_vertices, cy)
        end
    end
end