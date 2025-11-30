require "overworld.npc_body"
require "overworld.npc_eyes"
require "overworld.objects.dialog_emitter"

rt.settings.overworld.npc = {
    canvas_radius = 200,
    hole_radius = 20,
    eye_radius = 25,
    interact_radius = 150
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

--- @class ow.NPCInteractSensor
ow.NPCInteractSensor = meta.class("NPCInteractSensor") -- proxy

--- @brief
function ow.NPC:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()

    assert(object:get_type() == ow.ObjectType.POINT, "NPC should be Point")
    self._x = object.x
    self._y = object.y

    local width = rt.settings.overworld.npc.canvas_radius
    local height = width

    self._graphics_body_x = self._x - 0.5 * width
    self._graphics_body_y = self._y - 0.5 * height

    local hole_radius = rt.settings.overworld.npc.hole_radius
    self._graphics_body = ow.NPCBody(
        self._graphics_body_x,
        self._graphics_body_y,
        width, height,
        hole_radius
    )

    local eye_radius = rt.settings.overworld.npc.eye_radius
    self._eyes = ow.NPCEyes(
        self._graphics_body_x + 0.5 * width, -- center of eyes
        self._graphics_body_y + 0.5 * height,
        eye_radius
    )

    self._dilation_motion = rt.SmoothedMotion1D(0)
    self._dialog_emitter = ow.DialogEmitter(object, stage, scene)
    self._dialog_emitter:set_target(self)

    local target = object:get_object("target", false)
    if target == nil then
        self._sensor = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            self._x, self._y,
            b2.Circle(0, 0, rt.settings.overworld.npc.interact_radius)
        )
    else
        self._sensor = target:create_physics_body(
            stage:get_physics_world(),
            b2.BodyType.STATIC
        )
    end

    self._sensor:set_collision_group(rt.settings.player.bounce_collision_group)
    self._sensor:set_collides_with(rt.settings.player.bounce_collision_group)
    self._sensor:set_is_sensor(true)
    self._sensor_active = self._sensor:test_point(self._scene:get_player():get_position())
    self._dilation_motion:set_target_value(ternary(self._sensor_active, 1, 0))
end

--- @brief
function ow.NPC:update(delta)
    if not self._stage:get_is_body_visible(self._sensor) then return end

    local is_active = self._sensor:test_point(self._scene:get_player():get_position())
    if is_active ~= self._sensor_active then
        self._sensor_active = is_active
        self._dilation_motion:set_target_value(ternary(self._sensor_active, 1, 0))
    end

    self._dialog_emitter:update(delta)
    self._dilation_motion:update(delta)
    self._graphics_body:set_dilation(self._dilation_motion:get_value())
    self._eyes:update(delta)
    self._eyes:set_target(self._scene:get_player():get_position())
end

local exclude_from_drawing = false

--- @brief
function ow.NPC:draw(priority)
    if exclude_from_drawing == true or not self._stage:get_is_body_visible(self._sensor) then return end

    exclude_from_drawing = true -- prevent loop
    local screenshot = self._scene:get_screenshot(true) -- draw player
    exclude_from_drawing = false

    if screenshot == nil then return end

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

    -- draw backing, eyes, then overlay which opens on dilation
    rt.Palette.BLACK:bind()
    love.graphics.rectangle("fill", self._graphics_body_x, self._graphics_body_y, canvas:get_size())
    self._eyes:draw()
    self._graphics_body:draw()

    self._dialog_emitter:draw(priority)
end

function ow.NPC:get_position()
    return self._x, self._y
end

function ow.NPC:draw_bloom()
end

--- @brief
function ow.NPC:get_render_priority()
    return 1
end