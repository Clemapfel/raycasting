require "common.scene"
require "common.background"
require "common.selection_graph"
require "common.translation"
require "common.font"
require "common.input_subscriber"
require "menu.message_dialog"

rt.settings.menu.pause_menu_scene = {
    label_prefix = "<b><o>",
    label_postfix = "</b></o>",
    selection_frame_thickness = 2
}

--- @class mn.PauseMenuScene
mn.PauseMenuScene = meta.class("PauseMenuScene", rt.Scene)

--- @brief
function mn.PauseMenuScene:instantiate()
    meta.install(self, {
        _elements = {},
        _background = rt.Background("menu/pause_menu_scene.glsl", true),
        _input = rt.InputSubscriber(false),

        _selection_graph = rt.SelectionGraph(),
        _confirm_exit_dialog = mn.MessageDialog(
            rt.Translation.pause_menu_scene.confirm_exit_message,
            rt.Translation.pause_menu_scene.confirm_exit_submessage,
            mn.MessageDialogOption.ACCEPT,
            mn.MessageDialogOption.CANCEL
        )
    })

    self._input:signal_connect("pressed", function(_, which)
        if self._is_active then
            self._selection_graph:handle_button(which)
        end
    end)

    self._background:realize()
    self._confirm_exit_dialog:realize()
    self._confirm_exit_dialog:signal_connect("selection", function(self, which)
        if which == mn.MessageDialogOption.ACCEPT then
            exit(0)
        elseif which == mn.MessageDialogOption.CANCEL then
            self:close()
        end
    end)

    self._elements = {}
    self._first_node = nil

    local n_elements = 0
    local prefix, postfix = rt.settings.menu.pause_menu_scene.label_prefix, rt.settings.menu.pause_menu_scene.label_postfix
    for name in range(
        "resume",
        "retry",
        "controls",
        "settings",
        "exit"
    ) do
        local element = {
            unselected_label = rt.Label(
                prefix .. rt.Translation.pause_menu_scene[name] .. postfix,
                rt.FontSize.LARGE
            ),

            selected_label = rt.Label(
                prefix .. "<color=SELECTION>" .. rt.Translation.pause_menu_scene[name] .. "</color>" .. postfix,
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
        element.frame:set_thickness(rt.settings.menu.pause_menu_scene.selection_frame_thickness)
        element.frame:set_selection_state(rt.SelectionState.ACTIVE)
        element.frame:realize()

        element.node:signal_connect(rt.InputButton.A, function(_)
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
function mn.PauseMenuScene:size_allocate(x, y, width, height)
    self._background:reformat(x, y, width, height)

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
            label:reformat(element.x, element.y, element.width, element.height)
        end
        element.node:set_bounds(element.frame:get_bounds())

        current_y = current_y + element.height + m
    end

    self._confirm_exit_dialog:reformat(0, 0, width, height)
end

--- @brief
function mn.PauseMenuScene:update(delta)
    if not self._is_active then return end

    local current_node = self._selection_graph:get_current_node()
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
end

--- @brief
function mn.PauseMenuScene:draw()
    if not self._is_active then return end

    local current_node = self._selection_graph:get_current_node()

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
    end
end

--- @brief
function mn.PauseMenuScene:_on_resume()
    rt.SceneManager:unpause()
end

--- @brief
function mn.PauseMenuScene:_on_retry()
    rt.SceneManager:get_current_scene():respawn()
    rt.SceneManager:unpause()
end

--- @brief
function mn.PauseMenuScene:_on_settings()

end

--- @brief
function mn.PauseMenuScene:_on_controls()

end

--- @brief
function mn.PauseMenuScene:_on_exit()
    self._confirm_exit_dialog:present()
end

--- @brief
function mn.PauseMenuScene:enter()
    self._selection_graph:set_current_node(self._first_node)
    self._input:activate()
end

--- @brief
function mn.PauseMenuScene:exit()
    self._input:deactivate()
end


