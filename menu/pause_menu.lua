require "common.scene"
require "common.background"
require "common.selection_graph"
require "common.translation"
require "common.font"
require "common.input_subscriber"
require "common.control_indicator"
require "menu.message_dialog"

rt.settings.menu.pause_menu = {
    label_prefix = "<b><o>",
    label_postfix = "</b></o>",
    selection_frame_thickness = 2
}

--- @class mn.PauseMenu
mn.PauseMenu = meta.class("PauseMenu", rt.Widget)

--- @brief
function mn.PauseMenu:instantiate(scene)
    if not meta.isa(scene, rt.Scene) then
        rt.error("In mn.PauseMenu.enter: expected `Scene`, got `" .. meta.typeof(scene) .. "`")
    end

    meta.install(self, {
        _elements = {},
        _background = rt.Background("menu/pause_menu.glsl", true),
        _underlying_scene = scene, -- scene below menu
        _input = rt.InputSubscriber(false),
        _schedule_activate = true,
        _is_active = false,

        _selection_graph = rt.SelectionGraph(),
        _confirm_exit_dialog = mn.MessageDialog(
            rt.Translation.pause_menu.confirm_exit_message,
            rt.Translation.pause_menu.confirm_exit_submessage,
            mn.MessageDialogOption.ACCEPT,
            mn.MessageDialogOption.CANCEL
        ),

        _confirm_restart_dialog = mn.MessageDialog(
            rt.Translation.pause_menu.confirm_restart_message,
            rt.Translation.pause_menu.confirm_restart_submessage,
            mn.MessageDialogOption.ACCEPT,
            mn.MessageDialogOption.CANCEL
        )
    })

    local translation = rt.Translation.pause_menu
    self._control_indicator = rt.ControlIndicator(
        rt.ControlIndicatorButton.A, translation.control_indicator_select,
        rt.ControlIndicatorButton.UP_DOWN, translation.control_indicator_move
        --rt.ControlIndicatorButton.START, translation.control_indicator_unpause
    )
    self._control_indicator:set_has_frame(false)

    self._input:signal_connect("pressed", function(_, which)
        if not self._underlying_scene:get_is_active() then return end

        if which == rt.InputAction.BACK then
            if self._confirm_exit_dialog:get_is_active() then
                self._confirm_exit_dialog:close()
            elseif self._confirm_restart_dialog:get_is_active() then
                self._confirm_restart_dialog:close()
            end
        elseif  which == rt.InputAction.PAUSE then
            self._underlying_scene:unpause()
        else
            self._selection_graph:handle_button(which)
        end
    end)

    self._background:realize()
    self._control_indicator:realize()

    self._confirm_exit_dialog:realize()
    self._confirm_exit_dialog:signal_connect("selection", function(_, which)
        if which == mn.MessageDialogOption.ACCEPT then
            require "menu.menu_scene"
            rt.SceneManager:push(mn.MenuScene)
            self._underlying_scene:unpause()
        elseif which == mn.MessageDialogOption.CANCEL then
            self._confirm_exit_dialog:close()
        end
    end)

    self._confirm_restart_dialog:realize()
    self._confirm_restart_dialog:signal_connect("selection", function(_, which)
        if which == mn.MessageDialogOption.ACCEPT then
            self._underlying_scene:reload()
            self._underlying_scene:unpause()
        elseif which == mn.MessageDialogOption.CANCEL then
            self._confirm_restart_dialog:close()
        end
    end)

    self._elements = {}
    self._first_node = nil

    local n_elements = 0
    local prefix, postfix = rt.settings.menu.pause_menu.label_prefix, rt.settings.menu.pause_menu.label_postfix
    for name in range(
        "resume",
        "restart",
        "retry",
        "controls",
        "settings",
        "exit"
    ) do
        local element = {
            unselected_label = rt.Label(
                prefix .. rt.Translation.pause_menu[name] .. postfix,
                rt.FontSize.LARGE
            ),

            selected_label = rt.Label(
                prefix .. "<color=SELECTION>" .. rt.Translation.pause_menu[name] .. "</color>" .. postfix,
                rt.FontSize.LARGE
            ),

            node = rt.SelectionGraphNode(),
            frame = rt.Frame(),
            x = 0,
            y = 0,
            width = 0,
            height = 0,
        }

        element.unselected_label:realize()
        element.selected_label:realize()

        element.frame:set_base_color(1, 1, 1, 0)
        element.frame:set_thickness(rt.settings.menu.pause_menu.selection_frame_thickness)
        element.frame:set_selection_state(rt.SelectionState.ACTIVE)
        element.frame:realize()

        element.node:signal_connect(rt.InputAction.A, function(_)
            if not self._is_active then return end
            self["_on_" .. name](self) -- _on_resume, _on_settings, etc
        end)

        if name == "resume" then self._first_node = element.node end
        table.insert(self._elements, element)
        n_elements = n_elements + 1
    end

    for i = 1, n_elements - 1 do
        local a = self._elements[i+0]
        local b = self._elements[i+1]

        a.node:set_down(b.node)
        b.node:set_up(a.node)
    end

    self._elements[1].node:set_up(self._elements[n_elements].node)
    self._elements[n_elements].node:set_down(self._elements[1].node)
end

--- @brief
function mn.PauseMenu:size_allocate(x, y, width, height)
    self._background:reformat(x, y, width, height)

    local outer_margin = 0 --rt.settings.margin_unit
    local control_w, control_h = self._control_indicator:measure()
    self._control_indicator:reformat(
        x + width - outer_margin - control_w,
        y + height - outer_margin - control_h,
        control_w, control_h
    )

    local m = rt.settings.margin_unit
    local max_w, max_h, height_sum = -math.huge, -math.huge, 0
    for element in values(self._elements) do
        element.width, element.height = element.selected_label:measure()

        max_w = math.max(max_w, element.width)
        max_h = math.max(max_h, element.height)
        height_sum = height_sum + element.height + m
    end

    local current_x, current_y = x + 0.5 * width, y + 0.5 * height - 0.5 * height_sum
    local label_xm, label_ym = 2 * m, 0.5 * m
    for element in values(self._elements) do
        element.x = current_x - 0.5 * element.width
        element.y = current_y
        element.frame:reformat(
            element.x - label_xm,
            element.y - label_ym,
            element.width + 2 * label_xm,
            element.height + 2 * label_ym
        )

        for label in range(element.selected_label, element.unselected_label) do
            label:reformat(element.x, element.y, math.huge, element.height)
        end
        element.node:set_bounds(element.frame:get_bounds())

        current_y = current_y + element.height + m
    end

    self._confirm_exit_dialog:reformat(0, 0, width, height)
    self._confirm_restart_dialog:reformat(0, 0, width, height)
end

--- @brief
function mn.PauseMenu:update(delta)
    if not self._is_active then return end

    if self._schedule_activate == true then
        self._input:activate()
        self._schedule_activate = false
    end

    local current_node = self._selection_graph:get_selected_node()
    self._background:update(delta)
    for element in values(self._elements) do
        if element.node == current_node then
            element.selected_label:update(delta)
        else
            element.unselected_label:update(delta)
        end
    end

    if self._confirm_exit_dialog:get_is_active() then
        self._confirm_exit_dialog:update(delta)
    end

    if self._confirm_restart_dialog:get_is_active() then
        self._confirm_restart_dialog:update(delta)
    end
end

--- @brief
function mn.PauseMenu:draw()
    if not self._is_active then return end

    local current_node = self._selection_graph:get_selected_node()

    self._background:draw()

    for element in values(self._elements) do
        love.graphics.push()
        if element.node == current_node then
            element.selected_label:draw()
            element.frame:draw()
        else
            element.unselected_label:draw()
        end
        love.graphics.pop()
    end

    if self._confirm_exit_dialog:get_is_active() then
        self._confirm_exit_dialog:draw()
    elseif self._confirm_restart_dialog:get_is_active() then
        self._confirm_restart_dialog:draw()
    else
        self._control_indicator:draw()
    end
end

--- @brief
function mn.PauseMenu:_on_resume()
    self._underlying_scene:unpause()
end

--- @brief
function mn.PauseMenu:_on_retry()
    rt.SceneManager:get_current_scene():respawn()
    self._underlying_scene:unpause()
end

--- @brief
function mn.PauseMenu:_on_settings()
    require "menu.settings_scene"
    rt.SceneManager:push(mn.SettingsScene) -- unpauses automatically
end

--- @brief
function mn.PauseMenu:_on_controls()
    require "menu.keybinding_scene"
    rt.SceneManager:push(mn.KeybindingScene) -- unpauses automatically
end

--- @brief
function mn.PauseMenu:_on_restart()
    self._confirm_restart_dialog:present()
end

--- @brief
function mn.PauseMenu:_on_exit()
    self._confirm_exit_dialog:present()
end

--- @brief
function mn.PauseMenu:present()
    if self._selection_graph:get_selected_node() == nil then
        self._selection_graph:set_selected_node(self._first_node)
    end

    self._is_active = true
    self._schedule_activate = true
    -- delay input:activate to next frame
end

--- @brief
function mn.PauseMenu:close()
    self._confirm_restart_dialog:close()
    self._confirm_exit_dialog:close()
    self._is_active = false
    self._input:deactivate()
end


