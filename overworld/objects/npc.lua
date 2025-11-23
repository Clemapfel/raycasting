require "overworld.npc_body"

rt.settings.overworld.npc = {
    canvas_radius = 150,
    hole_radius_factor = 0.15
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

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
    self._graphics_body = ow.NPCBody(
        self._graphics_body_x,
        self._graphics_body_y,
        width, height,
        rt.settings.overworld.npc.hole_radius_factor * width
    )
    self._camera_body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.STATIC,
        0, 0,
        b2.Rectangle(self._x, self._y, width, height)
    )
    self._camera_body:set_collides_with(0x0)
    self._camera_body:set_collision_group(0x0)

    self._dilation_motion = rt.SmoothedMotion1D(0)

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "l" then
            self._dilation_motion:set_target_value(ternary(self._dilation_motion:get_target_value() == 1, 0, 1))
        end
    end)
end

--- @brief
--- @brief
function ow.NPC:update(delta)
    if not self._stage:get_is_body_visible(self._camera_body) then return end
    self._dilation_motion:update(delta)
    self._graphics_body:set_dilation(self._dilation_motion:get_value())
end

local exclude_from_drawing = false

--- @brief
function ow.NPC:draw()
    if exclude_from_drawing == true or not self._stage:get_is_body_visible(self._camera_body) then return end

    exclude_from_drawing = true -- prevent loop
    local screenshot = self._scene:get_screenshot()
    exclude_from_drawing = false

    if screenshot == nil then return end

    local small = self._graphics_body:get_texture()

    love.graphics.push("all")
    love.graphics.reset()
    small:bind()
    love.graphics.clear(0, 0, 0, 0)

    local screen_x, screen_y = self._scene:get_camera():world_xy_to_screen_xy(
        self._graphics_body_x, self._graphics_body_y
    )

    local scale = self._scene:get_camera():get_final_scale()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.scale(1 / scale, 1 / scale)
    love.graphics.translate(-screen_x, -screen_y)

    screenshot:draw()
    small:unbind()

    love.graphics.pop()

    self._graphics_body:draw()
end

function ow.NPC:draw_bloom()
end

--- @brief
function ow.NPC:get_render_priority()
    return -1 -- below player
end