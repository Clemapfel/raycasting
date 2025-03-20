require "common.font"
require "common.label"
require "common.frame"
require "common.mesh"
require "common.sprite"
require "common.stencil"

-- accepted ids for dialog node in config file
rt.settings.overworld.dialog_box = {
    portrait_key = "portrait",
    speaker_key = "speaker",
    next_key = "next",
    dialog_choice_key = "choices",

    portrait_resolution_w = 40,
    portrait_resolution_h = 40,
    n_lines = 3,

    menu_move_sound_id = "menu_move",
    menu_confirm_sound_id = "menu_confirm",
}

ow.DialogBox = meta.class("OverworldDialogBox", rt.Widget)
meta.add_signals(ow.DialogBox, "done")

--- @brief
function ow.DialogBox:instantiate(dialog_id)
    meta.install(self, {
        _dialog_id = dialog_id,
        _is_initialized = false,
        _done_emitted = false,

        _id_to_node = {},
        _portrait_id_to_portrait = {},
        _speaker_to_orientation = {},

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
        _advance_indicator_color = rt.Palette.FOREGROUND,
        _advance_indicator_outline_color = rt.Palette.BACKGROUND_OUTLINE,
        _advance_indicator_outline_w = 2,
        _advance_indicator_offset = 0,

        _choice_frame = rt.Frame(),
        _choice_frame_x = 0,
        _choice_frame_y = 0,

        _text_stencil = rt.AABB(0, 0, 1, 1),

        _line_height = select(2, rt.settings.font.default:measure_glyph("|")),
        _max_n_lines = rt.settings.overworld.dialog_box.n_lines
    })
end

local _atlas = require "assets.text.dialog"
local _node_type_text = "text"
local _node_type_choice = "choice"

--- @brief
function ow.DialogBox:realize()
    if self:already_realized() then return end
    if _atlas == nil then _atlas = require("assets.text.dialog") end

    local entry = _atlas[self._dialog_id]
    if entry == nil then
        rt.error("In ow.DialogBox: for dialog `" .. self._dialog_id .. "` does not have an entry in `assets.text.dialog`")
        return
    end

    self._id_to_node = {}
    self._portrait_id_to_portrait = {}

    local settings = rt.settings.overworld.dialog_box
    local portrait_key = settings.portrait_key
    local speaker_key = settings.speaker_key
    local next_key = settings.next_key
    local dialog_choice_key = settings.dialog_choice_key

    local speaker_prefix = ""
    local speaker_postfix = ""

    local selected_answer_prefix = "<b><color=SELECTION><outline_color=BLACK>"
    local selected_answer_postfix = "</color></outline_color></b>"

    local can_be_visited = {}
    local current_x, current_y = 0, 0
    for key, node_entry in pairs(entry) do
        local node = {}
        node.id = key
        node.next_id = node_entry[next_key]

        if node_entry[dialog_choice_key] ~= nil then
            node.type = _node_type_choice
            node.answers = {}
            node.highlighted_answer = 1
            node.n_answers = 0
            node.labels = {}
            node.highlighted_labels = {}
            node.answer_to_next_node = {} -- i to id now, later i to node
            node.width = 0
            node.height = 0
            for i, choice in ipairs(node_entry[dialog_choice_key]) do
                local text = choice[1]
                if not meta.is_string(text) then
                    rt.error("In ow.DialogBox: for dialog `" .. self._dialog_id .. "` multiple choice node `" .. key .. "` does not have answer at position 1")
                end

                local label = rt.Label(text)
                local highlighted = rt.Label(selected_answer_prefix .. text .. selected_answer_postfix)

                label:realize()
                highlighted:realize()

                table.insert(node.labels, label)
                table.insert(node.highlighted_labels, highlighted)

                node.n_answers = node.n_answers + 1
                node.answer_to_next_node[i] = choice.next
            end
        else
            node.type = _node_type_text
            node.labels = {}

            local speaker = node_entry[speaker_key]
            node.speaker = nil
            node.speaker_id = speaker
            node.speaker_width = 0
            if speaker ~= nil then
                node.speaker = rt.Label(speaker_prefix .. speaker .. speaker_postfix)
                node.speaker:realize()
                local label_w, label_h = node.speaker:measure()
                node.speaker_width = label_w + 2 * rt.settings.margin_unit
                node.speaker:set_justify_mode(rt.JustifyMode.CENTER)
                node.speaker:reformat(
                    0,
                    0,
                    node.speaker_width,
                    math.huge
                )
            end

            local portrait_id = node_entry[portrait_key]
            if portrait_id ~= nil then
                local sprite = self._portrait_id_to_portrait[portrait_id]
                if sprite == nil then
                    sprite = rt.Sprite(portrait_id)
                    self._portrait_id_to_portrait[portrait_id] = sprite
                end

                node.portrait = sprite
            end

            if not meta.is_string(node_entry[1]) then
                rt.error("In ow.DialogBox: for dialog `" .. self._dialog_id .. "`: node `" .. node.id .. "` does not have any dialog text")
            end

            do
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
        end

        can_be_visited[node] = false
        self._id_to_node[key] = node
    end

    local first_node = self._id_to_node[1]
    if first_node == nil then
        rt.warning("In ow.DialogBox: for dialog `" .. self._dialog_id .. "`, no node with id `1`")
        first_node = table.first(self._id_to_node)
    end

    can_be_visited[first_node] = true
    for node in values(self._id_to_node) do
        if node.type == _node_type_text then
            node.next = self._id_to_node[node.next_id]
            if node.next ~= nil then
                can_be_visited[node.next] = true
            end
        elseif node.type == _node_type_choice then
            for key, next_id in pairs(node.answer_to_next_node) do
                local next = self._id_to_node[next_id]
                node.answer_to_next_node[key] = next
                if next ~= nil then
                    can_be_visited[next] = true
                end
            end
        end
    end

    for node, visited in pairs(can_be_visited) do
        if visited == false then
            rt.warning("In ow.DialogBox: for dialog `" .. self._dialog_id .. "`: node `" .. node.id .. "` has node pointing to it, it cannot be visited" )
        end
    end

    self._is_initialized = true
    self:_set_active_node(first_node)
end

--- @brief
function ow.DialogBox:size_allocate(x, y, width, height)
    if self._is_initialized == false then return end

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

    local speaker_frame_w = 0.3 * frame_w -- resize depending on speaker label
    local speaker_frame_h = self._line_height + m
    self._speaker_frame_w = speaker_frame_w
    self._speaker_frame_h = speaker_frame_h
    self._speaker_frame_left_x = frame_x + m
    self._speaker_frame_left_y = frame_y - 3 * m - thickness
    self._speaker_frame_right_x = frame_x + frame_w - m
    self._speaker_frame_right_y = self._speaker_frame_left_y
    self._speaker_frame:reformat(0, 0, speaker_frame_w, speaker_frame_h)

    local sprite_scale = rt.settings.sprite_scale
    local portrait_w = rt.settings.overworld.dialog_box.portrait_resolution_w * sprite_scale
    local portrait_h = rt.settings.overworld.dialog_box.portrait_resolution_h * sprite_scale

    self._portrait_left_x = frame_x + m
    self._portrait_left_y = frame_y - speaker_frame_h - m - portrait_h
    self._portrait_right_x = frame_x + frame_w - m - portrait_w
    self._portrait_right_y = self._portrait_left_y
    self._portrait_frame:reformat(0, 0, portrait_w, portrait_h)

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
        if node.type == _node_type_text then
            local current_x, current_y = outer_margin, m
            for label in values(node.labels) do
                label:reformat(current_x, current_y, area_w)
                local label_w, label_h = label:measure()
                current_y = current_y + label_h
            end
        elseif node.type == _node_type_choice then
            local max_w = -math.huge
            local total_h = 0
            local n_labels = 0
            for label in values(node.highlighted_labels) do
                local label_w, label_h = label:measure()
                max_w = math.max(max_w, label_w)
                total_h = total_h + label_h
                n_labels = n_labels + 1
            end

            local current_x, current_y = outer_margin, m
            node.width = math.min(choice_w, max_w)
            node.height = total_h
            for i = 1, n_labels do
                node.labels[i]:reformat(current_x, current_y, math.huge)
                node.highlighted_labels[i]:reformat(current_x, current_y, math.huge)
                current_y = current_y + select(2, node.highlighted_labels[i]:measure())
            end
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

--- @brief
function ow.DialogBox:_set_active_node(node)
    if node == nil then
        if self._done_emitted == false then
            self:signal_emit("done")
            self._done_emitted = true
        end
        return -- hang on last message
    end

    if node.type == _node_type_text then
        self._active_choice_node = nil
        self._active_node = node
        self._portrait_visible = node.portrait ~= nil
        self._node_offset_x = 0
        self._node_offset_y = 0

        local left_or_right = self._speaker_to_orientation[node.speaker_id]
        self._portrait_left_or_right = left_or_right or true
        if self._portrait_visible then
            node.portrait:set_flip_horizontally(not self._portrait_left_or_right) -- all portraits look to the right
        end

        local speaker_label = node.speaker
        self._speaker_visible = speaker_label ~= nil
        if speaker_label ~= nil then
            self._speaker_frame_w = node.speaker_width
            local _, label_h = node.speaker:measure()
            self._speaker_label_left_x = self._speaker_frame_left_x
            self._speaker_label_left_y = self._speaker_frame_left_y + 0.5 * self._speaker_frame_h - 0.5 * label_h
            self._speaker_label_right_x = self._speaker_frame_right_x
            self._speaker_label_right_y = self._speaker_label_left_y
            self._speaker_frame:reformat(0, 0, self._speaker_frame_w, self._speaker_frame_h)
        end

        -- reset if reselecting
        for label in values(node.label) do
            label.dialog_box_elapsed = nil
            label.dialog_box_is_done = nil
            label:update_n_visible_characters_from_elapsed(0)
        end
    elseif node.type == _node_type_choice then
        self._portrait_visible = false
        self._speaker_visible = false
        self._active_choice_node = node

        local m = rt.settings.margin_unit
        local frame_w, frame_h = node.width + 4 * m, node.height + 2 * m
        self._choice_frame:reformat(0, 0, frame_w, frame_h)
        self._choice_frame_x = self._frame_x
        self._choice_frame_y = self._frame_y - m - frame_h
    else
        assert(false)
    end
end

--- @brief
function ow.DialogBox:set_should_auto_advance(b)
    self._should_auto_advance = b
end

--- @brief [internal]
function ow.DialogBox:_update_node_offset_from_n_lines_visible(n_lines_visible)
    self._node_offset_y = -1 * math.max( n_lines_visible - self._max_n_lines, 0) * self._line_height
end

local _advance_indicator_elapsed = 0

--- @brief
function ow.DialogBox:update(delta)
    if self._active_node == nil then return end

    if self._active_choice_node ~= nil then
        local node = self._active_choice_node
        for i = 1, node.n_answers do
            node.labels[i]:update(delta)
            node.highlighted_labels[i]:update(delta)
        end
    elseif self._active_node ~= nil then
        _advance_indicator_elapsed = _advance_indicator_elapsed + delta
        local offset = (math.sin(3 * _advance_indicator_elapsed) + 1) / 2 - 1
        self._advance_indicator_offset = offset * self._advance_indicator_radius * 0.5

        if self._active_node == nil then return end
        local skip_rest = false
        local n_lines_visible = 0
        for label in values(self._active_node.labels) do
            label:update(delta)

            if not skip_rest then
                if label.dialog_box_elapsed == nil then
                    -- inject per-label properties
                    label.dialog_box_elapsed = 0
                    label.dialog_box_is_done = false
                end

                if label.dialog_box_is_done == true then
                    n_lines_visible = n_lines_visible + label:get_n_lines()
                    label.dialog_box_is_done = true
                else
                    label.dialog_box_elapsed = label.dialog_box_elapsed + delta
                    local is_done, n_lines, n_characters = label:update_n_visible_characters_from_elapsed(label.dialog_box_elapsed)
                    n_lines_visible = n_lines_visible + n_lines
                    label.dialog_box_is_done = is_done
                end

                if not label.dialog_box_is_done then
                    skip_rest = true
                end
            end
        end

        self:_update_node_offset_from_n_lines_visible(n_lines_visible)

        if skip_rest == false then
            self._is_waiting_for_advance = true
            if self._should_auto_advance then self:_advance() end
        end
    end
end

--- @brief [orientation]
function ow.DialogBox:_advance()
    if self._active_node == nil or self._active_node.type ~= _node_type_text then return end

    local sound_id = rt.settings.overworld.dialog_box.menu_confirm_sound_id

    local n_lines_visible = 0
    local should_break = false
    if not self._is_waiting_for_advance then
        for label in values(self._active_node.labels) do
            if label.dialog_box_is_done ~= true then
                label.dialog_box_is_done = true
                label:set_n_visible_characters(math.huge)
                rt.SoundManager:play(sound_id)
                should_break = true
            end

            n_lines_visible = n_lines_visible + label:get_n_lines()
            if should_break then break end
        end

        self:_update_node_offset_from_n_lines_visible(n_lines_visible)
        return
    else
        local before = self._active_node
        self:_set_active_node(self._active_node.next)
        if self._active_node ~= before then
            rt.SoundManager:play(sound_id)
        end
    end
end

--- @brief
function ow.DialogBox:handle_button(which)
    if self._active_choice_node ~= nil then
        local move_sound_id = rt.settings.overworld.dialog_box.menu_move_sound_id
        local confirm_sound_id = rt.settings.overwold.dialog_box.menu_confirm_sound_id
        local node = self._active_choice_node
        if which == rt.InputButton.UP then
            if node.highlighted_answer > 1 then
                node.highlighted_answer = node.highlighted_answer - 1
                rt.SoundManager:play(move_sound_id)
            end
        elseif which == rt.InputButton.DOWN then
            if node.highlighted_answer < node.n_answers then
                node.highlighted_answer = node.highlighted_answer + 1
                rt.SoundManager:play(move_sound_id)
            end
        elseif which == rt.InputButton.A then
            self:_set_active_node(node.answer_to_next_node[node.highlighted_answer])
        end
    elseif self._active_node ~= nil then
        if which == rt.InputButton.A then
            self:_advance()
        end
    end
end

--- @brief
function ow.DialogBox:set_speaker_orientation(portrait_id, left_or_right)
    self._speaker_to_orientation = left_or_right
end

--- @brief
function ow.DialogBox:draw()
    if self._is_initialized == false or self._done_emitted == true then return end

    self._frame:draw()

    if self._portrait_visible then
        love.graphics.push()
        if self._portrait_left_or_right then
            love.graphics.translate(self._portrait_left_x, self._portrait_left_y)
        else
            love.graphics.translate(self._portrait_right_x, self._portrait_right_y)
        end
        self._portrait_frame:draw()
        self._portrait_frame:bind_stencil()
        self._active_node.portrait:draw()
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

    love.graphics.push()

    if self._is_waiting_for_advance then
        rt.Palette.BACKGROUND:bind()
        love.graphics.translate(0, self._advance_indicator_offset)
        love.graphics.polygon("fill", self._advance_indicator)

        love.graphics.setLineStyle("smooth")
        love.graphics.setLineJoin("miter")

        self._advance_indicator_outline_color:bind()
        love.graphics.setLineWidth(self._advance_indicator_outline_w + 1)
        love.graphics.line(self._advance_indicator_outline)

        self._advance_indicator_color:bind()
        love.graphics.setLineWidth(self._advance_indicator_outline_w)
        love.graphics.line(self._advance_indicator_outline)
    end
    love.graphics.pop()

    love.graphics.push()
    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.stencil(stencil_value, function()
        love.graphics.rectangle("fill", self._text_stencil:unpack())
    end)
    rt.graphics.set_stencil_test(rt.StencilCompareMode.EQUAL, stencil_value)

    love.graphics.translate(self._node_offset_x + self._frame_x, self._node_offset_y + self._frame_y)
    for label in values(self._active_node.labels) do
        label:draw()
    end

    rt.graphics.set_stencil_test()
    love.graphics.pop()

    if self._active_choice_node ~= nil then
        local node = self._active_choice_node
        assert(node.type == _node_type_choice)
        love.graphics.push()
        love.graphics.translate(self._choice_frame_x, self._choice_frame_y)
        self._choice_frame:draw()
        for i = 1, node.n_answers do
            if i == node.highlighted_answer then
                node.highlighted_labels[i]:draw()
            else
                node.labels[i]:draw()
            end
        end
        love.graphics.pop()
    end
end