require "overworld.dialog_box"
require "common.label"
require "common.translation"
require "common.smoothed_motion_1d"
require "common.filesystem"

rt.settings.overworld.dialog_emitter = {
    interact_range_factor = 10, -- * player radius
    interact_opacity_speed = 2, -- fraction
    dialog_interact_sensor_radius = 60 -- x radius, y radius determined by terrain
}

--- @class ow.DialogEmitter
ow.DialogEmitter = meta.class("DialogEmitter")

--- @brief
function ow.DialogEmitter:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.DialogEmitter: object is not a point")
    self._stage = stage
    self._scene = scene
    self._world = self._stage:get_physics_world()

    -- if attached to target, use their position
    local target_maybe = object:get_object("target", false)
    if target_maybe ~= nil then
        self._x, self._y = target_maybe.x, target_maybe.y
    else
        self._x, self._y = object.x, object.y
    end

    self._target_wrapper = target_maybe
    self._target = nil -- instance or nil if target_maybe = nil

    local x_radius, y_radius = rt.settings.overworld.dialog_emitter.dialog_interact_sensor_radius, nil

    -- cast ray down, then construct half circle whose bottom is clipped by
    -- the line orthogonal to the ground, this way it follows the slope of the ground

    local ray_dx, ray_dy = 0, 10e8
    local bottom_x, bottom_y, nx, ny = self._world:query_ray(
        self._x, self._y, ray_dx, ray_dy
    )

    if bottom_x == nil or bottom_y == nil then
        bottom_x, bottom_y = self._x, self._y + x_radius
        y_radius = x_radius
        nx, ny = 0, -1
    else
        y_radius = bottom_y - self._y
    end

    local tx, ty = math.turn_left(nx, ny)

    local vertices = {}
    local n_vertices = 6
    for i = 1, n_vertices do
        local angle = (2 * math.pi) - ((i - 1) / (n_vertices - 1)) * (math.pi)
        local circle_x = math.cos(angle) * x_radius
        local circle_y = math.sin(angle) * y_radius

        local x, y
        if i == 1 or i == n_vertices then
            local offset_along_tangent = circle_x * tx / math.abs(tx)
            x = bottom_x + offset_along_tangent * tx
            y = bottom_y + offset_along_tangent * ty + circle_y
        else
            x, y = bottom_x + circle_x, bottom_y + circle_y
        end

        table.insert(vertices, x)
        table.insert(vertices, y)
    end

    self._dialog_sensor = b2.Body(
        self._world, b2.BodyType.STATIC,
        0, 0, b2.Polygon(vertices)
    )
    self._dialog_sensor:set_is_sensor(true)
    self._dialog_sensor:set_collides_with(rt.settings.player.player_collision_group)

    self._dialog_id = object:get_string("id", true)
    self._dialog_box = ow.DialogBox(self._dialog_id)
    self._dialog_box_active = false

    self._bounds = nil
    self._stage:signal_connect("initialized", function(_)
        self:_reformat_dialog_box()

        if target_maybe ~= nil then
            self._target = stage:object_wrapper_to_instance(target_maybe)
        end

        return meta.DISCONNECT_SIGNAL
    end)

    self._input = rt.InputSubscriber()
    self._interact_allowed = false
    self._input:signal_connect("pressed", function(_, which)
        if self._dialog_box_active then
            self._dialog_box:handle_button(which)
        else
            if self._interact_allowed
                and not self._dialog_box_active
                and which == rt.InputAction.INTERACT
            then
                self:_start_dialog()
            end
        end
    end)

    -- show scene control indicator, delayed automatically
    self._resize_handler = nil
    self._dialog_sensor:signal_connect("collision_start", function(_)
        self._scene:set_control_indicator_type(ow.ControlIndicatorType.INTERACT)
        self._interact_allowed = true
    end)

    self._dialog_sensor:signal_connect("collision_end", function(_)
        self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)
        self._interact_allowed = false
    end)

    self._stage:signal_connect("respawn", function()
        self:_end_dialog()
    end)

    -- portraits
    self._dialog_box:realize()
    self._dialog_box:register_speaker_frame(rt.settings.overworld.dialog_box.player_speaker_id, function(width, height)
        love.graphics.push()
        love.graphics.clear()
        local player = self._scene:get_player()
        love.graphics.origin()
        local px, py = player:get_position()
        love.graphics.translate(-px + 0.5 * width, -py + 0.5 * height)
        player:draw()
        love.graphics.pop()
    end)

    if self._target_wrapper ~= nil then
        self._dialog_box:register_speaker_frame(rt.settings.overworld.dialog_box.npc_speaker_id, function(width, height)
            love.graphics.push()
            love.graphics.clear()
            local target = self._target -- set after initialize
            love.graphics.origin()

            local px, py
            if target.get_position ~= nil then
                px, py = target:get_position()
            else
                px, py = self._target_wrapper:get_centroid()
            end

            love.graphics.translate(-px + 0.5 * width, -py + 0.5 * height)
            target:draw()
            love.graphics.pop()
        end)
    end
end

--- @brief
function ow.DialogEmitter:_start_dialog()
    self:_reformat_dialog_box()
    self._dialog_box_active = true
    self._dialog_box:reset()
    self._scene:set_camera_mode(ow.CameraMode.MANUAL)
    self._scene:get_player():set_movement_disabled(true)
    self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)

    local camera = self._scene:get_camera()
    if self._target ~= nil then
        if self._target.get_position ~= nil then
            camera:move_to(self._target:get_position())
        else
            camera:move_to(self._target_wrapper:get_centroid())
        end
    else
        camera:move_to(self._scene:get_player():get_position())
    end

    self._resize_handler = self._scene:signal_connect("resize", function(_, x, y, width, height)
        if self._dialog_box_active then
            self._dialog_box:reformat(x, y, width, height)
        end
    end)

    self._dialog_box:signal_connect("done", function(_)
        self:_end_dialog()
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.DialogEmitter:_end_dialog()
    if self._dialog_box_active then
        self._dialog_box_active = false
        self._scene:set_camera_mode(ow.CameraMode.AUTO)
        self._scene:get_player():set_movement_disabled(false)
    end

    if self._resize_handler ~= nil then
        self._scene:signal_disconnect("resize", self._resize_handler)
    end
end

--- @brief
function ow.DialogEmitter:_reformat_dialog_box()
    local bounds = self._scene:get_bounds()
    if self._bounds == nil or not bounds:equals(self._bounds) then
        self._bounds = bounds self._dialog_box:reformat(self._bounds)
    end
end

--- @brief
function ow.DialogEmitter:update(delta)
    if self._dialog_box_active then
        self._dialog_box:update(delta)
    end
end

--- @brief
function ow.DialogEmitter:draw()
    self._dialog_sensor:draw()

    if self._dialog_box_active then
        love.graphics.push()
        love.graphics.origin()
        self._dialog_box:draw()
        love.graphics.pop()
    end
end
