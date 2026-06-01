require "overworld.player_recorder_body"
require "overworld.objects.coin" -- Ensure coin settings are loaded
require "overworld.dialog_focus_indicator"

rt.settings.overworld.time_attack_trigger_npc = {
    hover_height = 3 * rt.settings.player.radius,
    enter_dialog_id = "time_attack_trigger_npc_enter",
    exit_dialog_id = "time_attack_trigger_npc_exit",

    noise_frequency = 0.2,
    noise_max_offset_radius_factor = 0.75,

    yes_choice_answer_i = 1 -- cf. Dialog `choices`
}

--- @class ow.TimeAttackTriggerNPC
ow.TimeAttackTriggerNPC = meta.class("TimeAttackTriggerNPC")

--- @brief
function ow.TimeAttackTriggerNPC:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.POINT, "In ow.TimeAttackNPC: object `", object:get_id(), "` is not a a point")

    self._scene = scene
    self._stage = stage

    self._is_hidden = false
    if rt.GameState:stage_get_is_time_attack_mode_allowed(stage:get_id()) ~= true then
        self._is_hidden = true
        return
    end

    local x, y = object.x, object.y

    local world = self._stage:get_physics_world()
    local magnitude = rt.settings.overworld.time_attack_trigger_npc.hover_height
    local mask = rt.settings.overworld.hitbox.collision_group

    local top_x, top_y, _ = world:query_ray(x, y, magnitude * -1, 0, mask)
    if top_x == nil and top_y == nil then
        top_x = x
        top_y = x - magnitude
    end

    local bottom_x, bottom_y, _ = world:query_ray(x, y, magnitude * 1, 0, mask)
    if bottom_x == nil and bottom_y == nil then
        bottom_x = x
        bottom_y = y
    end

    self._position_x = x
    self._position_y = math.min(top_y, bottom_y - magnitude)

    self._graphics_body = ow.PlayerRecorderBody(self._scene, self._stage)
    self._graphics_body:initialize(
        self._position_x, self._position_y,
        b2.BodyType.KINEMATIC,
        true
    )
    self._graphics_body:set_is_bubble(true)

    self._noise_x, self._noise_y = 0, 0
    self._noise_dx, self._noise_dy =
        math.cos(rt.random.number(0, 2 * math.pi)),
        math.sin(rt.random.number(0, 2 * math.pi))

    self._focus_indicator = ow.DialogFocusIndicator(
        self._scene,
        self._position_x,
        self._position_y
    )

    self._focus_indicator_offset_x = 0
    self._focus_indicator_offset_y = -1 * (rt.settings.player.radius + 0.5 * self._focus_indicator:get_radius())

    local px, py = self._scene:get_player():get_position()
    local focus_x, focus_y = self._focus_indicator:get_position()
    self._focus_indicator:set_is_active(
        math.distance(focus_x, focus_y, px, py) < rt.settings.overworld.npc.focus_indicator_active_radius -- sic
    )

    self._enter_dialog_emitter = ow.DialogEmitter(
        self._scene,
        rt.settings.overworld.time_attack_trigger_npc.enter_dialog_id,
        self
    )

    self._exit_dialog_emitter = ow.DialogEmitter(
        self._scene,
        rt.settings.overworld.time_attack_trigger_npc.exit_dialog_id,
        self
    )

    self._hide_dialog_emitter = false -- to hide during message dialog of overworld scene

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.INTERACT
            and self._focus_indicator:get_is_active() -- uses same sensor range
        then
            if self._scene:get_is_time_attack_mode_active() then
                self._exit_dialog_emitter:signal_connect("choice", function(_, node_id, choice_i, text)
                    self._hide_dialog_emitter = true
                    if choice_i == rt.settings.overworld.time_attack_trigger_npc.yes_choice_answer_i then
                        self._scene:set_is_time_attack_mode_active(false)
                    end

                    self._exit_dialog_emitter:close()
                    self._hide_dialog_emitter = false
                    return meta.DISCONNECT_SIGNAL
                end)

                self._exit_dialog_emitter:present()
            else
                self._enter_dialog_emitter:signal_connect("choice", function(_, node_id, choice_i, text)
                    self._hide_dialog_emitter = true
                    if choice_i == rt.settings.overworld.time_attack_trigger_npc.yes_choice_answer_i then
                        self._scene:set_is_time_attack_mode_active(true)
                    end

                    self._enter_dialog_emitter:close()
                    self._hide_dialog_emitter = true
                    return meta.DISCONNECT_SIGNAL
                end)

                self._enter_dialog_emitter:present()
            end
        end
    end)
end

local base_priority = 0

--- @brief
function ow.TimeAttackTriggerNPC:get_render_priority()
    if self._is_hidden then return nil end

    local priorities = { self._enter_dialog_emitter:get_render_priority() }
    table.insert(priorities, base_priority)
    return table.unpack(priorities)
end

--- @brief
function ow.TimeAttackTriggerNPC:draw(priority)
    if self._is_hidden then return end

    if self._stage:get_is_body_visible(self._graphics_body:get_physics_body()) then
        if priority == base_priority then
            if self._stage:get_is_body_visible(self._graphics_body:get_physics_body()) then
                self._graphics_body:draw()
                self._focus_indicator:draw()
            end
        end
    end

    if self._hide_dialog_emitter ~= true then
        if self._enter_dialog_emitter:get_is_active() then
            self._enter_dialog_emitter:draw(priority) -- draws text on to of bloom
        elseif self._exit_dialog_emitter:get_is_active() then
            self._exit_dialog_emitter:draw(priority)
        end
    end
end

--- @brief
function ow.TimeAttackTriggerNPC:draw_bloom()
    if self._is_hidden then return end

    if self._stage:get_is_body_visible(self._graphics_body:get_physics_body()) then
        self._focus_indicator:draw_bloom()
        self._graphics_body:draw_bloom()
    end
end

--- @brief
function ow.TimeAttackTriggerNPC:update(delta)
    if self._is_hidden then return end

    if self._stage:get_is_body_visible(self._graphics_body:get_physics_body()) then
        self._graphics_body:update(delta)
        
        local frequency = rt.settings.overworld.time_attack_trigger_npc.noise_frequency
        local offset = rt.settings.overworld.time_attack_trigger_npc.noise_max_offset_radius_factor * self._graphics_body:get_radius()

        local elapsed = rt.SceneManager:get_elapsed()
        self._noise_x = (rt.random.noise( self._noise_dx * elapsed * frequency, self._noise_dy * elapsed * frequency) * 2 - 1) * offset
        self._noise_y = (rt.random.noise(-self._noise_dx * elapsed * frequency, -self._noise_dy * elapsed * frequency) * 2 - 1) * offset

        local body_x, body_y = self._position_x + self._noise_x,
            self._position_y + self._noise_y

        self._graphics_body:set_position(body_x, body_y)

        local px, py = self._scene:get_player():get_position()
        local focus_x, focus_y = self._focus_indicator:get_position()

        local was_active = self._focus_indicator:get_is_active()
        self._focus_indicator:set_is_active(
            math.distance(focus_x, focus_y, px, py) < rt.settings.overworld.npc.focus_indicator_active_radius -- sic
        )

        self._focus_indicator:set_position(
            body_x + self._focus_indicator_offset_x,
            body_y + self._focus_indicator_offset_y
        )

        self._focus_indicator:update(delta)

        local is_active = self._focus_indicator:get_is_active()
        if self._interact_enter_dialog_emitter ~= nil then
            if was_active == false and is_active == true then
                self._scene:set_control_indicator_type(ow.ControlIndicatorType.INTERACT)
            elseif was_active == true and is_active == false then
                self._scene:set_control_indicator_type(ow.ControlIndicatorType.NONE)
            end

            self._interact_enter_dialog_emitter:update(delta)
        end
    end

    if self._enter_dialog_emitter:get_is_active() then
        self._enter_dialog_emitter:update(delta)
    end
end

--- @brief
function ow.TimeAttackTriggerNPC:get_position()
    return self._position_x, self._position_y
end

--- @brief
function ow.TimeAttackTriggerNPC:reset()
    self._is_hidden = self._scene:get_is_time_attack_mode_active()
end