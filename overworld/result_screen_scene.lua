--- @class ow.ResultScreenScene
ow.ResultScreenScene = meta.class("ResultScreenScene", rt.Scene)

--- @brief
function ow.ResultScreenScene:instantiate(state)
    self._is_paused = false

    local translation = rt.Translation.result_screen_scene

    do -- options
        local unselected_prefix, unselected_postfix = rt.settings.menu.pause_menu.label_prefix, rt.settings.menu.pause_menu.label_postfix
        local selected_prefix, selected_postfix = unselected_prefix .. "<color=SELECTION>", "</color>" .. unselected_postfix
        self._options = {}
        self._option_selection_graph = rt.SelectionGraph()
        self._option_background = rt.Background("menu/pause_menu.glsl", true) -- sic, use same as level pause

        local function add_option(text, function_name)
            local option = {
                unselected_label = rt.Label(
                    unselected_prefix .. text .. unselected_postfix,
                    rt.FontSize.LARGE
                ),
                selected_label = rt.Label(
                    selected_prefix .. text .. selected_postfix,
                    rt.FontSize.LARGE
                ),
                frame = rt.Frame(),
                node = rt.SelectionGraphNode()
            }

            option.frame:set_base_color(1, 1, 1, 0)
            option.frame:set_selection_state(rt.SelectionState.ACTIVE)
            option.frame:set_thickness(rt.settings.menu.pause_menu.selection_frame_thickness)

            option.node:signal_connect(rt.InputAction.A, function(_)
                self[function_name]()
            end)

            option.node:signal_connect(rt.InputAction.B, function(_)
                self:_unpause()
            end)

            table.insert(self._options, option)
        end

        add_option(translation.option_retry_stage, "_on_retry_stage")
        add_option(translation.option_next_stage, "_on_next_stage")
        add_option(translation.option_return_to_main_menu, "_on_return_to_main_menu")

        -- connect nodes
        for i = 1, #self._options, 1 do
            local before = math.wrap(i-1, #self._options)
            local after = math.wrap(i+1, #self._options)

            local element = self._options[i]
            element.node:set_up(self._options[before].node)
            element.node:set_down(self._options[after].node)
        end
    end

    -- player boundaries
    self._entry_x, self._entry_y = 0, 0
    self._player_velocity_x, self._player_velocity_y = 0, 0
    self._player = state:get_player()
    do
        self._world = b2.World()
        -- body and teleport updated in size_allocate

        self._player:move_to_world(self._world)
        self._player:set_is_bubble(true)
    end

    self._input = rt.InputSubscriber()
end

--- @brief
function ow.ResultScreenScene:realize()
    if self:already_realized() then return end

    for widget in range(
        self._option_retry_stage_unselected_label,
        self._option_next_stage_unselected_label,
        self._option_return_to_main_menu_unselected_label,
        self._option_retry_stage_selected_label,
        self._option_next_stage_selected_label,
        self._option_return_to_main_menu_selected_label,
        self._option_background
    ) do
        widget:realize()
    end
end

--- @brief
function ow.ResultScreenScene:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit

    do -- physics world
        local bx, by = 0, 0
        local _, _, w, h = self:get_bounds():unpack()
        if self._body ~= nil then self._body:destroy() end
        self._body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0,
            b2.Segment(bx + 0, by + 0, bx + w, by + 0),
            b2.Segment(bx + w, by + 0, bx + w, by + h),
            b2.Segment(bx + w, by + h, bx + 0, by + h),
            b2.Segment(bx + 0, by + h, bx + 0, by + 0)
        )
        self._body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y)
            local current_vx, current_vy = self._player_velocity_x, self._player_velocity_y
            self._player_velocity_x, self._player_velocity_y = math.reflect(current_vx, current_vy, normal_x, normal_y)
        end)

        self:_teleport_player(self._entry_x, self._entry_y)
    end

    do -- options
        local total_h = 0
        for option in values(self._options) do
            total_h = total_h + math.max(
                select(2, option.unselected_label:measure()),
                select(2, option.selected_label:measure())
            ) + m
        end

        self._option_background:reformat(x, y, width, height)
        local current_y = y + 0.5 * height - 0.5 * total_h
        for option in values(self._options) do
            local selected_w, selected_h = option.selected_label:measure()
            local unselected_w, unselected_h = option.unselected_label:measure()
            local w, h = math.max(selected_w, unselected_w), math.max(selected_h, unselected_h)


            option.frame:reformat(
                x + 0.5 * width - 0.5 * w,
                current_y,
                w, h
            )

            option.selected_label:reformat(
                x + 0.5 * width - 0.5 * selected_w,
                current_y + 0.5 * h - 0.5 * selected_h,
                math.huge, math.huge
            )

            option.unselected_label:reformat(
                x + 0.5 * width - 0.5 * unselected_w,
                current_y + 0.5 * h - 0.5 * selected_h,
                math.huge, math.huge
            )

            current_y = current_y + h
        end
    end
end

--- @brief
function ow.ResultScreenScene:_teleport_player(px, py)
    self._player:disable()

    local x, y, w, h = self._bounds:unpack()
    x, y = 0, 0

    local r = 2 * self._player:get_radius()
    local vx, vy = math.normalize(self._player:get_velocity())
    self._player:teleport_to(
        math.clamp(self._entry_x, x + r, x + w - r),
        math.clamp(self._entry_y, y + r, y + h - r)
    )

    local magnitude = rt.settings.menu_scene.title_screen.player_velocity
    if vx == 0 and vy == 0 then vx, vy = math.normalize(1, 1) end
    self._player_velocity_x, self._player_velocity_y = vx * magnitude, vy * magnitude
end

--- @brief
--- @param player_x Number in screen coordinates
--- @param player_y Number
function ow.ResultScreenScene:enter(player_x, player_y)
    meta.assert(player_x, "Number", player_y, "Number")
    self._entry_x, self._entry_y = player_x, player_y
    self:_teleport_player(self._entry_x, self._entry_y)

    self._option_selection_graph:set_current_node(self._options[1].node)

    self._input:activate()
    self:_unpause()
end

--- @brief
function ow.ResultScreenScene:exit()
    self._input:deactivate()
end

--- @brief
function ow.ResultScreenScene:update(delta)
    for updatable in range(
        self._player,
        self._world
    ) do
        updatable:update(delta)
    end

    self._player:set_velocity(self._player_velocity_x, self._player_velocity_y)
end

--- @brief
function ow.ResultScreenScene:draw()
    if not self:get_is_active() then return end
    self._player:draw()

    if true then -- TODOself._is_paused then
        self._option_background:draw()
        for option in values(self._options) do
            if self._option_selection_graph:get_current_node() == option.node then
                option.frame:draw()
                option.selected_label:draw()
            else
                option.unselected_label:draw()
            end
        end
    end
end

--- @brief
function ow.ResultScreenScene:_on_next_stage()
    if not self._is_paused then return end

end

--- @brief
function ow.ResultScreenScene:_on_retry_stage()
    if not self._is_paused then return end
end

--- @brief
function ow.ResultScreenScene:_on_return_to_main_menu()
    if not self._is_paused then return end
end

--- @brief
function ow.ResultScreenScene:_pause()

end

--- @brief
function ow.ResultScreenScene:_unpause()

end