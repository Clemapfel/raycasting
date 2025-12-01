require "common.font"
require "common.label"
require "common.frame"
require "common.mesh"
require "common.sprite"
require "common.stencil"
require "common.sound_manager"

-- accepted ids for dialog node in config file
rt.settings.overworld.dialog_box = {
    speaker_key = "speaker",
    speaker_orientation_key = "orientation",
    speaker_orientation_left = "left",
    speaker_orientation_right = "right",
    next_key = "next",
    dialog_choice_key = "choices",

    speaker_text_prefix = "",
    speaker_text_postfix = "",
    choice_text_prefix = "<b><color=SELECTION><outline_color=BLACK>",
    choice_text_postfix = "</color></outline_color></b>",

    portrait_resolution_w = 80,
    portrait_resolution_h = 80,
    n_lines = 3,

    menu_move_sound_id = "menu_move",
    menu_confirm_sound_id = "menu_confirm",

    asset_prefix = "assets/text",
}

--- @class ow.DialogBox
--- @signal done (DialogBox) -> nil
--- @signal speaker_changed (DialogBox, current_speaker_id, last_speaker_id) -> nil
ow.DialogBox = meta.class("OverworldDialogBox", rt.Widget)
meta.add_signals(ow.DialogBox,
    "done",
    "speaker_changed"
)

--- @brief
function ow.DialogBox:instantiate(id)
    meta.assert(id, "String")
    self._id = id
    self._path = bd.join_path(rt.settings.overworld.dialog_box.asset_prefix, self._id) .. ".lua"
    self._config = bd.load(self._path, false) -- no sandbox

    meta.install(self, {
        _is_initialized = false,
        _done_emitted = false,

        _id_to_node = {},

        _active_node = nil,
        _active_choice_node = nil,

        _should_auto_advance = false,
        _is_waiting_for_advance = false,

        _frame = rt.Frame(),
        _frame_x = 0,
        _frame_y = 0,
        _node_offset_x = 0,
        _node_offset_y = 0,

        _portrait_frame = rt.Frame(),
        _portrait_left_x = 0,
        _portrait_left_y = 0,
        _portrait_right_x = 0,
        _portrait_right_y = 0,
        _portrait_visible = false,
        _portrait_left_or_right = true,
        _portrait_canvas = nil, -- rt.RenderTexture

        _speaker_id_to_portrait_callback = {}, -- Table<String, Function>

        _speaker_frame = rt.Frame(),
        _speaker_frame_w = 0,
        _speaker_frame_h = 0,
        _speaker_frame_left_x = 0,
        _speaker_frame_left_y = 0,
        _speaker_frame_right_x = 0, -- right alignment, variable width
        _speaker_frame_right_y = 0,
        _speaker_label_left_x = 0,
        _speaker_label_left_y = 0,
        _speaker_label_right_x = 0,
        _speaker_label_right_y = 0,
        _speaker_visible = false,

        _advance_indicator = {},
        _advance_indicator_outline = {},
        _advance_indicator_outline_w = 2,
        _advance_indicator_offset = 0,
        _advance_indicator_elapsed = 0,

        _choice_frame = rt.Frame(),
        _choice_frame_x = 0,
        _choice_frame_y = 0,

        _text_stencil = rt.AABB(0, 0, 1, 1),

        _font = rt.settings.font.default,
        _max_n_lines = rt.settings.overworld.dialog_box.n_lines,

        _is_first_update = true,
        _input_delay = 0
    })
end

local _node_type_text = "text"
local _node_type_choice = "choice"

--- @brief
function ow.DialogBox:realize()
    if self:already_realized() then return end
    local entry = self._config

    self._id_to_node = {}

    local settings = rt.settings.overworld.dialog_box
    local speaker_key = settings.speaker_key
    local next_key = settings.next_key
    local dialog_choice_key = settings.dialog_choice_key
    local orientation_key = settings.speaker_orientation_key
    local orientation_left = settings.speaker_orientation_left
    local orientation_right = settings.speaker_orientation_right

    local speaker_prefix = settings.speaker_text_prefix
    local speaker_postfix = settings.speaker_text_postfix

    local selected_answer_prefix = settings.choice_text_prefix
    local selected_answer_postfix = settings.choice_text_postfix

    local can_be_visited = {}
    for key, node_entry in pairs(entry) do
        local node = {}
        node.id = key

        if node_entry[dialog_choice_key] ~= nil then
            node.type = _node_type_choice

            node.n_answers = 0
            node.highlighted_answer_i = 1

            node.labels = {} -- Table<rt.Label>
            node.highlighted_labels = {} -- Table<rt.Label>

            node.answer_i_to_next_node_id = {}
            node.answer_i_to_next_node = {}
            node.width = 0
            node.height = 0
            for i, choice in ipairs(node_entry[dialog_choice_key]) do
                local text = choice[1]
                if not meta.is_string(text) then
                    rt.error("In ow.DialogBox: for dialog `",  self._id,  "` multiple choice node `",  key,  "` does not have answer at position 1")
                end

                local label = rt.Label(text)
                local highlighted_label = rt.Label(selected_answer_prefix .. text .. selected_answer_postfix)

                label:realize()
                highlighted_label:realize()

                table.insert(node.labels, label)
                table.insert(node.highlighted_labels, highlighted_label)

                node.n_answers = node.n_answers + 1
                node.answer_i_to_next_node_id[i] = choice.next
            end
        else
            node.type = _node_type_text
            node.labels = {}
            node.next_id = node_entry[next_key]


            local speaker_id = node_entry[speaker_key]
            local orientation = node_entry[orientation_key]
            if orientation == nil or orientation == orientation_left then
                node.speaker_orientation = true
            elseif orientation == orientation_right then
                node.speaker_orientation = false
            else
                rt.error("In ow.DialogBox: for dialog `",  self._id,  "` node `",  key,  "` has invalid value for `orientation` field, expected `",  orientation_left,  "` or `",  orientation_right,  "`, got: `",  orientation)
                node.speaker_orientation = true
            end

            node.speaker = nil -- rt.Label
            node.speaker_id = speaker_id
            if speaker_id ~= nil then
                node.speaker = rt.Label(speaker_prefix .. speaker_id .. speaker_postfix)
                node.speaker:realize()

                local label_w, label_h = node.speaker:measure()
                node.speaker:set_justify_mode(rt.JustifyMode.CENTER)
                node.speaker:reformat(
                    0,
                    0,
                    label_w + 2 * rt.settings.margin_unit,
                    math.huge
                )
            end

            if not meta.is_string(node_entry[1]) then
                rt.error("In ow.DialogBox: for dialog `",  self._id,  "`: node `",  node.id,  "` does not have any dialog text")
            end

            local i = 1
            local text = node_entry[i]
            while text ~= nil do
                local label = rt.Label(text)
                label:realize()
                label:set_n_visible_characters(0)
                table.insert(node.labels, label)
                i = i + 1
                text = node_entry[i]
            end
        end

        can_be_visited[node] = false
        self._id_to_node[node.id] = node
    end

    local first_node = self._id_to_node[1]
    if first_node == nil then
        rt.warning("In ow.DialogBox: for dialog `",  self._id,  "`, no node with id `1`")
        first_node = table.first(self._id_to_node)
    end
    can_be_visited[first_node] = true

    for node in values(self._id_to_node) do
        if node.type == _node_type_choice then
            for i, next_id in pairs(node.answer_i_to_next_node_id) do
                local next = self._id_to_node[next_id]
                node.answer_i_to_next_node[i] = next
                if next ~= nil then
                    can_be_visited[next] = true
                end
            end
        elseif node.type == _node_type_text then
            node.next = self._id_to_node[node.next_id]
            if node.next ~= nil then
                can_be_visited[node.next] = true
            end
        end
    end

    for node, visited in pairs(can_be_visited) do
        if visited == false then
            rt.warning("In ow.DialogBox: for dialog `",  self._id,  "`: node `",  node.id,  "` has node pointing to it, it cannot be visited" )
        end
    end

    self._active_node = first_node -- do not use _set_active_node, called in first resize
end

--- @brief
function ow.DialogBox:_set_active_node(node)
    local m = rt.settings.margin_unit
    local before = self._active_node

    if node == nil then
        if self._done_emitted == false then
            self._done_emitted = true
            self:signal_emit("done")
        end
    elseif node.type == _node_type_choice then
        self._active_choice_node = node
        self._portrait_visible = false
        self._speaker_visible = false

        local frame_w, frame_h = node.width + 4 * m, node.height + 2 * m
        self._choice_frame:reformat(0, 0, frame_w, frame_h)
        self._choice_frame_x = self._frame_x + m
        self._choice_frame_y = self._frame_y - m - frame_h
    elseif node.type == _node_type_text then
        self._active_choice_node = nil
        self._active_node = node

        self._portrait_visible = self._speaker_id_to_portrait_callback[node.speaker_id] ~= nil
        self._node_offset_x, self._node_offset_y = 0, 0

        self._portrait_left_or_right = node.speaker_orientation

        local speaker_label = node.speaker
        self._speaker_visible = speaker_label ~= nil
        if speaker_label ~= nil then
            local label_w, label_h = node.speaker:measure()
            self._speaker_frame_w = label_w + 2 * m
            self._speaker_frame_h = label_h + m
            self._speaker_label_left_x = self._speaker_frame_left_x
            self._speaker_label_left_y = self._speaker_frame_left_y + 0.5 * self._speaker_frame_h - 0.5 * label_h
            self._speaker_label_right_x = self._speaker_frame_right_x
            self._speaker_label_right_y = self._speaker_label_left_y
            node.speaker:reformat(0, 0, self._speaker_frame_w, math.huge)
            self._speaker_frame:reformat(0, 0, self._speaker_frame_w, self._speaker_frame_h)
        end

        for label in values(node.labels) do
            label.dialog_box_elapsed = nil
            label.dialog_box_is_done = nil
            label:set_n_visible_characters(0)
        end
    else
        assert(false)
    end

    if before == nil or (node ~= nil and (before.speaker_id ~= node.speaker_id)) then
        if before == nil then
            self:signal_emit("speaker_changed", node.speaker_id, nil)
        else
            self:signal_emit("speaker_changed", node.speaker_id, before.speaker_id)
        end
    end
end

--- @brief
function ow.DialogBox:size_allocate(x, y, width, height)
    local line_height = self._font:get_line_height(rt.FontSize.REGULAR)
    self._line_height = line_height

    local m = rt.settings.margin_unit
    local outer_margin = 2 * m

    local frame_w = width - 2 * outer_margin
    local frame_h = self._max_n_lines * self._line_height + 2 * m
    local frame_x = x + outer_margin
    local frame_y = y + height - outer_margin - frame_h

    self._frame_x = frame_x
    self._frame_y = frame_y
    self._frame:reformat(frame_x, frame_y, frame_w, frame_h)

    local thickness = self._speaker_frame:get_thickness()

    local speaker_frame_w = 0 -- size-dependent values set in _set_active_node
    local speaker_frame_h = self._line_height + m
    self._speaker_frame_w = speaker_frame_w
    self._speaker_frame_h = speaker_frame_h
    self._speaker_frame_left_x = frame_x + m
    self._speaker_frame_left_y = frame_y - 3 * m - thickness
    self._speaker_frame_right_x = frame_x + frame_w - m
    self._speaker_frame_right_y = self._speaker_frame_left_y
    self._speaker_frame:reformat(0, 0, speaker_frame_w, speaker_frame_h)

    local sprite_scale = rt.get_pixel_scale()
    local portrait_w = rt.settings.overworld.dialog_box.portrait_resolution_w * sprite_scale + 2 * thickness
    local portrait_h = rt.settings.overworld.dialog_box.portrait_resolution_h * sprite_scale + 2 * thickness

    self._portrait_left_x = frame_x + m
    self._portrait_left_y = frame_y - speaker_frame_h - m - portrait_h
    self._portrait_right_x = frame_x + frame_w - m - portrait_w
    self._portrait_right_y = self._portrait_left_y
    self._portrait_frame:reformat(
        0, 0,
        portrait_w,
        portrait_h
    )

    if self._portrait_canvas == nil
        or self._portrait_canvas:get_width() ~= portrait_w
        or self._portrait_canvas:get_height() ~= portrait_h
    then
        self._portrait_canvas = rt.RenderTexture(portrait_w, portrait_h, rt.GameState:get_msaa_quality())
    end

    do
        local advance_radius = m
        self._advance_indicator_radius = advance_radius
        local center_x = frame_x + 0.5 * frame_w
        local center_y = frame_y + frame_h
        self._advance_indicator = {}
        local angle_offset = (2 * math.pi) / 4
        for angle = 0, 2 * math.pi, (2 * math.pi) / 3 do
            table.insert(self._advance_indicator, center_x + math.cos(angle + angle_offset) * advance_radius)
            table.insert(self._advance_indicator, center_y + math.sin(angle + angle_offset) * advance_radius)
        end

        self._advance_indicator_outline = self._advance_indicator
    end

    local area_w = frame_w - 4 * m
    local area_h = frame_h - 2 * m
    local choice_w = area_w - portrait_w - 2 * m
    for node in values(self._id_to_node) do
        local current_x, current_y = outer_margin, m
        if node.type == _node_type_text then
            for label in values(node.labels) do
                label:reformat(current_x, current_y, area_w)
                current_y = current_y + select(2, label:measure())
            end
        elseif node.type == _node_type_choice then
            -- measure all labels
            node.width = choice_w
            node.height = 0
            for i = 1, node.n_answers do
                node.labels[i]:reformat(current_x, current_y, math.huge) -- answer labels should only be one line
                node.highlighted_labels[i]:reformat(current_x, current_y, math.huge)

                local label_w, label_h = node.highlighted_labels[i]:measure()
                node.width = math.max(node.width, label_w)
                node.height = node.height + label_h
                current_y = current_y + label_h
            end
        else
            assert(false)
        end
    end

    self._text_stencil = rt.AABB(
        frame_x + 2 * m,
        frame_y + m,
        area_w,
        area_h
    )

    self:_set_active_node(self._active_node)
end

--- @brief [internal]
function ow.DialogBox:_update_node_offset_from_n_lines_visible(n_lines_visible)
    self._node_offset_y = -1 * math.max( n_lines_visible - self._max_n_lines, 0) * self._line_height
end

--- @brief
function ow.DialogBox:update(delta)
    -- update animations
    if self._active_choice_node ~= nil then
        local node = self._active_choice_node
        for i = 1, node.n_answers do
            node.labels[i]:update(delta)
            node.highlighted_labels[i]:update(delta)
        end
    end

    if self._active_node ~= nil then
        for label in values(self._active_node.labels) do
            label:update(delta)
        end

        if self._is_first_update then
            self:signal_emit("speaker_changed", self._active_node.speaker_id)
            self._is_first_update = false
        end
    end

    if self._is_waiting_for_advance then
        self._advance_indicator_elapsed = self._advance_indicator_elapsed + delta
        local offset = (math.sin(3 * self._advance_indicator_elapsed) + 1) / 2 - 1
        self._advance_indicator_offset = offset * self._advance_indicator_radius * 0.5
    end

    -- scrolling logic
    if self._active_node ~= nil then
        local n_lines_visible = 0
        local at_least_one_label_not_done = false
        for label in values(self._active_node.labels) do
            -- inject local per-label values
            if label.dialog_box_elapsed == nil then label.dialog_box_elapsed = 0 end
            if label.dialog_box_is_done == nil then label.dialog_box_is_done = false end

            if label.dialog_box_is_done == true then
                n_lines_visible = n_lines_visible + label:get_n_lines()
            else
                label.dialog_box_elapsed = label.dialog_box_elapsed + delta
                local is_done, new_n_lines, _ = label:update_n_visible_characters_from_elapsed(label.dialog_box_elapsed)
                n_lines_visible = n_lines_visible + new_n_lines
                label.dialog_box_is_done = is_done
            end

            if label.dialog_box_is_done == false then
                at_least_one_label_not_done = true
                break
            end
        end

        self:_update_node_offset_from_n_lines_visible(n_lines_visible)

        self._is_waiting_for_advance = not at_least_one_label_not_done
        if self._is_waiting_for_advance and self._should_auto_advance then
            self:_advance()
        end
    end
end

--- @brief [internal]
function ow.DialogBox:_advance()
    if self._active_node == nil or self._active_node.type ~= _node_type_text then return false end

    local sound_id = rt.settings.overworld.dialog_box.menu_confirm_sound_id

    -- skip to end of current node
    local n_lines_visible = 0
    for label in values(self._active_node.labels) do
        label.dialog_box_is_done = true
        label.dialog_box_elapsed = math.huge
        label:set_n_visible_characters(math.huge)
        n_lines_visible = n_lines_visible + label:get_n_lines()
    end
    self:_update_node_offset_from_n_lines_visible(n_lines_visible)

    -- go to next node if already fully advanced
    if self._is_waiting_for_advance then
        local before = self._active_node
        self:_set_active_node(self._active_node.next)
        if self._active_node ~= before then
            rt.SoundManager:play(sound_id)
        end
    end

    return true
end

--- @brief
function ow.DialogBox:handle_button(which)
    if which == rt.InputAction.INTERACT then
        self:_set_active_node(nil)
    end

    if self._active_choice_node ~= nil then
        local move_sound_id = rt.settings.overworld.dialog_box.menu_move_sound_id
        local confirm_sound_id = rt.settings.overwold.dialog_box.menu_confirm_sound_id
        local node = self._active_choice_node
        if which == rt.InputAction.UP then
            if node.highlighted_answer_i > 1 then
                node.highlighted_answer_i = node.highlighted_answer_i - 1
                rt.SoundManager:play(move_sound_id)
            end
        elseif which == rt.InputAction.DOWN then
            if node.highlighted_answer_i < node.n_answers then
                node.highlighted_answer_i = node.highlighted_answer_i + 1
                rt.SoundManager:play(move_sound_id)
            end
        elseif which == rt.InputAction.A then
            self:_set_active_node(node.answer_i_to_next_node[node.highlighted_answer_i])
        end
    elseif self._active_node ~= nil then
        if which == rt.InputAction.A then
            self:_advance()
        end
    end
end

--- @brief
function ow.DialogBox:draw()
    if not self:get_is_realized() or self._done_emitted == true then return end

    self._frame:draw()

    if self._portrait_visible then

        love.graphics.push("all")
        self._portrait_canvas:bind()
        local callback = self._speaker_id_to_portrait_callback[self._active_node.speaker_id]
        if meta.is_function(callback) then callback(self._portrait_canvas:get_size()) end
        self._portrait_canvas:unbind()
        love.graphics.pop()

        love.graphics.push()
        if self._portrait_left_or_right then
            love.graphics.translate(self._portrait_left_x, self._portrait_left_y)
        else
            love.graphics.translate(self._portrait_right_x, self._portrait_right_y)
        end
        self._portrait_frame:draw()
        self._portrait_frame:bind_stencil()
        self._portrait_canvas:draw()
        self._portrait_frame:unbind_stencil()
        love.graphics.pop()
    end

    if self._speaker_visible then
        love.graphics.push()
        if self._portrait_left_or_right then
            love.graphics.translate(self._speaker_frame_left_x, self._speaker_frame_left_y)
        else
            love.graphics.translate(self._speaker_frame_right_x - self._speaker_frame_w, self._speaker_frame_right_y)
        end
        self._speaker_frame:draw()
        love.graphics.pop()

        love.graphics.push()
        if self._portrait_left_or_right then
            love.graphics.translate(self._speaker_label_left_x, self._speaker_label_left_y)
        else
            love.graphics.translate(self._speaker_label_right_x - self._speaker_frame_w, self._speaker_label_right_y)
        end
        self._active_node.speaker:draw()
        love.graphics.pop()
    end

    if self._is_waiting_for_advance then
        love.graphics.push()
        rt.Palette.BASE:bind()
        love.graphics.translate(0, self._advance_indicator_offset)
        love.graphics.polygon("fill", self._advance_indicator)

        love.graphics.setLineStyle("smooth")
        love.graphics.setLineJoin("miter")

        rt.Palette.BASE_OUTLINE:bind()
        love.graphics.setLineWidth(self._advance_indicator_outline_w + 1)
        love.graphics.line(self._advance_indicator_outline)

        rt.Palette.FOREGROUND:bind()
        love.graphics.setLineWidth(self._advance_indicator_outline_w)
        love.graphics.line(self._advance_indicator_outline)
        love.graphics.pop()
    end

    if self._active_node ~= nil then
        love.graphics.push()
        local stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
        love.graphics.rectangle("fill", self._text_stencil:unpack())
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST)

        love.graphics.translate(self._node_offset_x + self._frame_x, self._node_offset_y + self._frame_y)
        for label in values(self._active_node.labels) do
            label:draw()
        end
        rt.graphics.set_stencil_mode(nil)
        love.graphics.pop()
    end

    if self._active_choice_node ~= nil then
        local node = self._active_choice_node
        love.graphics.push()
        love.graphics.translate(self._choice_frame_x, self._choice_frame_y)
        self._choice_frame:draw()
        for i = 1, node.n_answers do
            if i == node.highlighted_answer_i then
                node.highlighted_labels[i]:draw()
            else
                node.labels[i]:draw()
            end
        end
        love.graphics.pop()
    end
end

--- @brief
function ow.DialogBox:set_should_auto_advance(b)
    self._should_auto_advance = b
end

--- @brief
function ow.DialogBox:reset()
    for node in values(self._id_to_node) do
        if node.type == _node_type_text then
            for label in values(node.labels) do
                label.dialog_box_elapsed = nil
                label.dialog_box_is_done = nil
                label:set_n_visible_characters(0)
            end
        end
    end

    self:_set_active_node(self._id_to_node[1])
    self._done_emitted = false
    self._is_first_update = true
end

--- @brief
function ow.DialogBox:get_speakers()
    local out = {}
    for node in values(self._id_to_node) do
        table.insert(out, node.speaker_id)
    end
    return out
end

--- @brief
--- @param render_callback Function (width, height) -> nil
function ow.DialogBox:register_speaker_frame(speaker_id, render_callback)
    meta.assert(speaker_id, "String", render_callback, "Function")

    local seen = false
    for node in values(self._id_to_node) do
        if node.speaker_id == speaker_id then
            seen = true
            break
        end
    end

    if not seen then return end

    self._speaker_id_to_portrait_callback[speaker_id] = render_callback
end

--- @brief
function ow.DialogBox:close()
    self:_set_active_node(nil)
end