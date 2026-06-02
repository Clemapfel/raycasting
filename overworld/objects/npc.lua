require "overworld.npc_body"
require "overworld.dialog_emitter"
require "overworld.dialog_focus_indicator"

rt.settings.overworld.npc = {
    canvas_radius = 200,
    hole_radius = 20,
    interact_radius = 150,

    focus_indicator_active_radius = 300,
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

local schema = {
    dialog_id = ow.String
}

--- @brief
function ow.NPC:instantiate(object, stage, scene)
    object:validate_schema(schema, ow.ShapeType.POINT)

    self._scene = scene
    self._stage = stage
        
    local settings = rt.settings.overworld.npc

    local width = settings.canvas_radius
    local world = self._stage:get_physics_world()

    self._position_x, self._position_y = object.x, object.y

    self._graphics_body_x = object.x - 0.5 * width
    self._graphics_body_y = object.y - 0.5 * width
    self._graphics_body = ow.NPCBody(
        self._graphics_body_x,
        self._graphics_body_y,
        width, width,
        settings.hole_radius
    )

    self._dilation_motion = rt.SmoothedMotion1D(0)

    self._camera_body = b2.Body(world, b2.BodyType.STATIC, object.x, object.y, b2.Circle(0, 0, 0.5 * width))
    self._camera_body:set_collides_with(0x0)
    self._camera_body:set_collision_group(0x0)
    self._camera_body:add_tag("point_light_source")
    self._camera_body:set_user_data(self)
    self.collect_point_lights = function(self, callback)
        local r, g, b, a = self._scene:get_player():get_color():unpack()
        callback(
            self._position_x,
            self._position_y,
            settings.hole_radius * self._dilation_motion:get_value(),
            r, g, b, a
        )
    end

    local px, py = self._scene:get_player():get_position()
    self._focus_indicator = ow.DialogFocusIndicator(
        self._scene,
        object.x, object.y - settings.hole_radius
    )

    local focus_x, focus_y = self._focus_indicator:get_position()
    self._focus_indicator:set_is_active(
        math.distance(focus_x, focus_y, px, py) < settings.focus_indicator_active_radius
    )

    self._sensor_x, self._sensor_y = object.x, object.y
    self._sensor_radius = settings.interact_radius
    self._sensor_active = math.distance(
        self._sensor_x, self._sensor_y,
        px, py
    ) < self._sensor_radius

    -- dialog
    local dialog_id = object:get_string("dialog_id", false)
    if dialog_id then
        self._interact_dialog_emitter = ow.DialogEmitter(
            self._scene,
            dialog_id,
            self -- target
        )

        self._input = rt.InputSubscriber()
        self._input:signal_connect("pressed", function(_, which)
            if self._sensor_active and which == rt.InputAction.INTERACT then
                self._interact_dialog_emitter:present()
            end
        end)
    else
        self._interact_dialog_emitter = nil
    end
end

--- @brief
function ow.NPC:update(delta)
    if not self._stage:get_is_body_visible(self._camera_body) then return end

    local px, py = self._scene:get_player():get_position()
    local focus_x, focus_y = self._focus_indicator:get_position()
    self._focus_indicator:set_is_active(
        math.distance(focus_x, focus_y, px, py) < rt.settings.overworld.npc.focus_indicator_active_radius
    )
    self._focus_indicator:update(delta)

    local sensor_was_active = self._sensor_active
    self._sensor_active = math.distance(
        self._sensor_x, self._sensor_y,
        px, py
    ) < self._sensor_radius

    if self._sensor_active ~= sensor_was_active then
        self._dilation_motion:set_target_value(ternary(self._sensor_active, 1, 0))
    end
    self._dilation_motion:update(delta)
    self._graphics_body:set_dilation(self._dilation_motion:get_value())

    if self._interact_dialog_emitter ~= nil then
        if sensor_was_active == false and self._sensor_active == true then
            self._scene:set_control_indicator_type(ow.ControlIndicatorType.INTERACT)
        elseif sensor_was_active == true and self._sensor_active == false then
            self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)
        end

        self._interact_dialog_emitter:update(delta)
    end
end

do
    local exclude_from_drawing = false

    --- @brief
    function ow.NPC:draw(priority)
        if exclude_from_drawing == true or not self._stage:get_is_body_visible(self._camera_body) then return end

        exclude_from_drawing = true -- prevent loop
        local bounds = self._graphics_body:get_bounds()
        local camera = self._scene:get_camera()
        local screenshot = self._scene:get_screenshot(true) -- draw player
        exclude_from_drawing = false

        if screenshot ~= nil then
            local canvas = self._graphics_body:get_texture()

            love.graphics.push("all")
            love.graphics.reset()
            canvas:bind()
            love.graphics.clear(0, 0, 0, 0)

            local screen_x, screen_y = self._scene:get_camera():world_xy_to_screen_xy(
                self._graphics_body_x, self._graphics_body_y
            )

            local scale = self._scene:get_camera():get_final_scale()

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.scale(1 / scale, 1 / scale)
            love.graphics.translate(-screen_x, -screen_y)

            screenshot:draw()
            canvas:unbind()

            love.graphics.pop()

            rt.Palette.BLACK:bind()
            love.graphics.rectangle("fill", self._graphics_body_x, self._graphics_body_y, canvas:get_size())
            self._graphics_body:draw()
        end

        self._focus_indicator:draw()

        if self._interact_dialog_emitter ~= nil then
            self._interact_dialog_emitter:draw()
        end
    end
end

--- @brief
function ow.NPC:get_position()
    return self._position_x, self._position_y
end

--- @brief
function ow.NPC:get_render_priority()
    return math.huge
end