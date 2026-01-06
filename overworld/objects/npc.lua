require "overworld.npc_body"
require "overworld.npc_eyes"
require "overworld.dialog_emitter"

rt.settings.overworld.npc = {
    canvas_radius = 200,
    hole_radius = 20,
    eye_radius = 25,
    interact_radius = 150,

    ghost_translation_frequency = 1 / 4,
    ghost_translation_offset = 8, -- px
    ghost_core_offset_magnitude = 4 -- px
}

ow.NPCType = meta.enum("NPCType", {
    EYES = "eyes",
    GHOST = "ghost"
})

--- @class ow.NPC
ow.NPC = meta.class("NPC")

--- @class ow.NPCInteractSensor
ow.NPCInteractSensor = meta.class("NPCInteractSensor", ow.MovableObject) -- proxy

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

    local type = object:get_string("type") or ow.NPCType.EYES
    meta.assert_enum_value(type, ow.NPCType)
    self._type = type

    if self._type == ow.NPCType.EYES then
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
    elseif self._type == ow.NPCType.GHOST then
        self._graphics_body = ow.PlayerRecorderBody(self._stage, self._scene)
        self._graphics_body:initialize(
            self._graphics_body_x + 0.5 * width,
            self._graphics_body_y + 0.5 * height,
            b2.BodyType.KINEMATIC,
            true -- collidable
        )
        self._graphics_body:set_is_bubble(true)
        self._graphics_body:relax()

        self._ghost_bounce_animation = rt.TimedAnimation(0.25, 0, 1, rt.InterpolationFunctions.GAUSSIAN)
        self._bounce_offset_dx = 0
        self._bounce_offset_dy = 0

        local body = self._graphics_body:get_physics_body()
        body:signal_connect("collision_start", function(_, other_body, nx, ny, cx, cy)
            if not other_body:has_tag("player") then return end
            local player = self._scene:get_player()
            local px, py = player:get_position()
            local dx, dy = math.normalize(px - self._x, py - self._y)
            player:bounce(math.multiply(0.5, 0.5, dx, dy))

            -- bounce reaction animation
            self._ghost_bounce_animation:reset()
            self._bounce_offset_dx, self._bounce_offset_dy = math.flip(dx, dy)
        end)

        body:set_collision_group(rt.settings.player.bounce_collision_group)
        body:set_collides_with(rt.settings.player.bounce_collision_group)

        self._noise_x, self._noise_y = 0, 0
        self._noise_dx, self._noise_dy = math.cos(rt.random.number(0, 2 * math.pi)), math.sin(rt.random.number(0, 2 * math.pi))
        self._noise_origin_x = self._graphics_body_x + 0.5 * width
        self._noise_origin_y = self._graphics_body_y + 0.5 * height
        self._noise_amplitude = 1
        self._elapsed = 0
    end

    local interact_id = object:get_string("dialog_id", false) or object:get_string("interact_dialog_id", false)
    self._has_interact_dialog = interact_id ~= nil
    self._interact_allowed = false

    if self._has_interact_dialog then
        self._interact_dialog_emitter = ow.DialogEmitter(
            scene,
            interact_id,
            self
        )
        self._interact_dialog_emitter:realize()
    end

    local enter_id = object:get_string("enter_dialog_id", false)
    self._has_enter_dialog = enter_id ~= nil
    if self._has_enter_dialog then
        local should_lock = object:get_string("enter_should_lock", false)
        if should_lock == nil then should_lock = false end
        self._enter_dialog_emitter = ow.DialogEmitter(
            scene,
            enter_id,
            self,
            should_lock -- should_lock
        )
        self._enter_dialog_emitter:realize()
    end
    
    local exit_id = object:get_string("exit_dialog_id", false)
    self._has_exit_dialog = exit_id ~= nil
    if self._has_exit_dialog then
        local should_lock = object:get_string("exit_should_lock", false)
        if should_lock == nil then should_lock = false end
        self._exit_dialog_emitter = ow.DialogEmitter(
            scene,
            exit_id,
            self,
            should_lock
        )
        self._exit_dialog_emitter:realize()
    end

    local should_focus = object:get_boolean("should_focus", false)
    if should_focus == nil then should_focus = true end

    local should_lock = object:get_boolean("should_lock", false)
    if should_lock == nil then should_lock = true end

    self._should_focus = should_focus
    for emitter in range(
        self._enter_dialog_emitter,
        self._interact_dialog_emitter,
        self._exit_dialog_emitter
    ) do
        emitter:set_should_focus(should_focus)
        emitter:set_should_lock(should_lock)
    end

    -- override with local
    for tuple in range(
        { self._enter_dialog_emitter, "enter" },
        { self._exit_dialog_emitter, "exit" },
        { self._interact_dialog_emitter, "interact" }
    ) do
        local emitter, prefix = table.unpack(tuple)
        if emitter ~= nil then
            local should_lock = object:get_boolean(prefix .. "_should_lock")
            if should_lock ~= nil then
                emitter:set_should_lock(should_lock)
            end

            local should_focus = object:get_boolean(prefix .. "_should_focus")
            if should_focus ~= nil then
                should_focus:set_should_focus(should_focus)
            end
        end
    end

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

    if self._type == ow.NPCType.EYES then
        self._dilation_motion:set_target_value(ternary(self._sensor_active, 1, 0))
    end

    if self._has_interact_dialog then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("pressed", function(_, which)
            if which == rt.InputAction.INTERACT then
                if self._interact_allowed and self._interact_dialog_emitter:get_is_active() == false then
                    self._interact_dialog_emitter:present()
                    self:_set_is_interactable(false)
                end
            end
        end)
    end
end

--- @brief
function ow.NPC:update(delta)
    if not self._stage:get_is_body_visible(self._sensor) then return end

    local is_active = self._sensor:test_point(self._scene:get_player():get_position())
    local was_active = self._sensor_active
    self._sensor_active = is_active

    local already_active = (self._has_interact_dialog and self._interact_dialog_emitter:get_is_active())
        or (self._has_enter_dialog and self._enter_dialog_emitter:get_is_active())
        or (self._has_exit_dialog and self._exit_dialog_emitter:get_is_active())

    if not already_active then
        if self._has_enter_dialog and was_active == false and is_active == true then
            self._enter_dialog_emitter:present()
        elseif self._has_exit_dialog and was_active == true and is_active == false then
            self._exit_dialog_emitter:present()
        elseif was_active == false and is_active == true then
            self:_set_is_interactable(self._has_interact_dialog
                or self._has_enter_dialog
                or self._has_exit_dialog
            )
        elseif was_active == true and is_active == false then
            self:_set_is_interactable(false)
        end
    else
        -- leaving while enter dialog is active
        if self._has_enter_dialog and self._enter_dialog_emitter:get_is_active()
            and was_active == true and is_active == false
        then
            self._enter_dialog_emitter:close()
        end
    end

    if self._has_interact_dialog then
        self._interact_dialog_emitter:update(delta)
    end

    if self._has_enter_dialog then
        self._enter_dialog_emitter:update(delta)
    end

    if self._has_exit_dialog then
        self._exit_dialog_emitter:update(delta)
    end

    if self._type == ow.NPCType.EYES then
        if is_active ~= was_active then
            self._dilation_motion:set_target_value(ternary(self._sensor_active, 1, 0))
        end

        self._dilation_motion:update(delta)
        self._graphics_body:set_dilation(self._dilation_motion:get_value())
        self._eyes:update(delta)
        self._eyes:set_target(self._scene:get_player():get_position())
    elseif self._type == ow.NPCType.GHOST then

        local frequency = rt.settings.overworld.npc.ghost_translation_frequency
        local offset = rt.settings.overworld.npc.ghost_translation_offset
        self._elapsed = self._elapsed + delta
        self._noise_x = (rt.random.noise(self._noise_dx * self._elapsed * frequency, self._noise_dy * self._elapsed * frequency) * 2 - 1) * offset
        self._noise_y = (rt.random.noise(-self._noise_dx * self._elapsed * frequency, -self._noise_dy * self._elapsed * frequency) * 2 - 1) * offset

        self._graphics_body:set_position(
            self._noise_origin_x + self._noise_x,
            self._noise_origin_y + self._noise_y
        )
        self._graphics_body:update(delta)

        -- orient recorder core to look towards player
        self._ghost_bounce_animation:update(delta)

        local max_r = rt.settings.overworld.npc.ghost_core_offset_magnitude
        local bounce_offset = max_r * self._ghost_bounce_animation:get_value()

        local px, py = self._scene:get_player():get_position()
        local gx, gy = self._graphics_body:get_physics_body():get_position()

        local dx, dy = math.normalize(px - gx, py - gy)
        local distance_t = math.min(1, math.distance(px, py, gx, gy) /  rt.settings.overworld.npc.interact_radius)
        local r = rt.InterpolationFunctions.LINEAR(distance_t) * max_r
        self._graphics_body:set_core_offset(
            dx * r + self._bounce_offset_dx * bounce_offset,
            dy * r + self._bounce_offset_dy * bounce_offset
        )
    end
end

local exclude_from_drawing = false

--- @brief
function ow.NPC:draw(priority)
    if self._type == ow.NPCType.EYES then
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
    elseif self._type == ow.NPCType.GHOST then
        self._graphics_body:draw()
    end

    if self._has_interact_dialog then
        self._interact_dialog_emitter:draw(priority)
    elseif self._has_exit_dialog then
        self._exit_dialog_emitter:draw(priority)
    elseif self._has_enter_dialog then
        self._enter_dialog_emitter:draw(priority)
    end
end

function ow.NPC:get_position()
    return self._sensor:get_position()
end

function ow.NPC:draw_bloom()
    if self._type == ow.NPCType.EYES then
        --self._eyes:draw_bloom()
    elseif self._type == ow.NPCType.GHOST then
        self._graphics_body:draw_bloom()
    end
end

--- @brief
function ow.NPC:get_render_priority()
    return 1
end

--- @brief
function ow.NPC:_set_is_interactable(b)
    if b == true then
        self._scene:set_control_indicator_type(ow.ControlIndicatorType.INTERACT)

        if self._should_focus then
            self._scene:set_camera_mode(ow.CameraMode.MANUAL)
            self._scene:get_camera():move_to(self._x, self._y)
        end

        self._interact_allowed = true
    elseif b == false then
        self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)

        if self._should_focus then
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
        end

        self._interact_allowed = false
    end
end