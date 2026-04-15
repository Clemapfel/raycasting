require "common.font"
require "common.label"
require "common.frame"
require "common.mesh"
require "common.sprite"
require "common.stencil"
require "common.sound_manager"
require "common.dialog"
require "common.animalese"

-- accepted ids for dialog node in config file
rt.settings.overworld.dialog_box = {
    speaker_text_prefix = "",
    speaker_text_postfix = "",
    choice_text_prefix = "<b><color=SELECTION><outline_color=BLACK>",
    choice_text_postfix = "</color></outline_color></b>",

    portrait_resolution_w = 80,
    portrait_resolution_h = 80,
    n_lines = 3,

    scroll_speed_speedup = 2, -- factor

    menu_move_sound_id = "menu_move",
    menu_confirm_sound_id = "menu_confirm",

    config_location = "overworld/dialog",

    advance_button = rt.InputAction.INTERACT,
    n_advance_triggers = 2, -- how often advance has to be pressed to skip to end of current node
}

--- @enum ow.DialogBoxControlState
ow.DialogBoxControlState = {
    ADVANCE = "ADVANCE",    -- non-choice node done
    EXIT = "EXIT",          -- last node done
    SELECT_OPTION = "SELECT_OPTION", -- choice node active
    IDLE = "IDLE"           -- not shown
}
ow.DialogBoxControlState = meta.enum("DialogBoxControlState", ow.DialogBoxControlState)

--- @class ow.DialogBox
--- @signal done (DialogBox) -> nil
--- @signal speaker_changed (DialogBox, current_speaker_id, last_speaker_id) -> nil
ow.DialogBox = meta.class("OverworldDialogBox", rt.Widget)
meta.add_signals(ow.DialogBox,
    --- @signal (ow.DialogBox) -> nil
    "done",

    --- @signal (ow.DialogBox, new_speaker, before_speaker) -> nil
    "speaker_changed",

    --- @signal (ow.DialogBox, is_last_node, state) -> nil
    "advance",

    --- @signal (ow.DialogBox, ow.DialogBoxControlState) -> nil
    "control_state_changed"
)

local _animalese

--- @brief
function ow.DialogBox:instantiate(id)
    meta.assert(id, "String")
    self._id = id
    self._config = rt.Dialog[id]

    if self._config == nil then
        rt.fatal("In ow.DialogBox: no dialog with id `", id, "`")
    end

    meta.install(self, {
        _is_initialized = false,
        _done_emitted = false,

        _id_to_node = {},

        _active_node = nil,
        _active_choice_node = nil,
        _should_emit_advance = false,

        _should_auto_advance = false,
        _is_waiting_for_advance = false,
        _advance_button_is_down = false,
        _is_started = false,

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
    })
end

local _node_type_text = "text"
local _node_type_choice = "choice"

--- @brief
function ow.DialogBox:realize()
    if self:already_realized() then return end
    local entry = self._config

    self._id_to_node = {}

    local settings = rt.settings.dialog
    local speaker_key = settings.speaker_key
    local next_key = settings.next_key
    local dialog_choice_key = settings.dialog_choice_key
    local state_key = settings.state_key
    local gender_key = settings.gender_key
    local orientation_key = settings.speaker_orientation_key
    local orientation_left = rt.DialogSpeakerOrientation.LEFT
    local orientation_right = rt.DialogSpeakerOrientation.RIGHT

    settings = rt.settings.overworld.dialog_box
    local speaker_prefix = settings.speaker_text_prefix
    local speaker_postfix = settings.speaker_text_postfix

    local selected_answer_prefix = settings.choice_text_prefix
    local selected_answer_postfix = settings.choice_text_postfix

    local can_be_visited = {}
    for key, node_entry in pairs(entry) do
        local node = {}
        node.id = key
        node.type = ternary(node_entry[dialog_choice_key] ~= nil, _node_type_choice, _node_type_text)
        node.labels = {}
        node.next_id = node_entry[next_key]
        node.state = node_entry[state_key] or {}
        node.n_advance_triggers = 0

        local speaker_id = node_entry[speaker_key]
        local orientation = node_entry[orientation_key]

        if orientation ~= nil then
            rt.assert(meta.is_enum_value(orientation, rt.DialogSpeakerOrientation), "In rt.Dialog: for dialog `", self._id, "`: node `", key, "`: assigned value `", orientation, "` of `", orientation_key, "` is not an value of enum `rt.SpeakerOrientation`")
        end

        if orientation == orientation_left then
            node.speaker_orientation = true
        elseif orientation == orientation_right then
            node.speaker_orientation = false
        else
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

        node.gender = node_entry[gender_key]
        meta.assert_enum_value(node.gender, rt.AnimaleseGender)

        local event_maps = {}

        local i = 1
        local text = node_entry[i]
        while text ~= nil do
            local label = rt.Label(text)
            label:realize()
            label:set_n_visible_characters(0)

            table.insert(node.labels, label)
            table.insert(event_maps, label:get_scroll_event_map())
            i = i + 1

            text = node_entry[i]
        end

        -- compute overall event map
        node.event_map = {}
        node.elapsed = 0
        node.duration = 0
        do
            local elapsed = 0
            for map in values(event_maps) do
                for event in values(map) do
                    table.insert(node.event_map, {
                        time = elapsed,
                        duration = event.duration,
                        glyph = event.glyph,
                        is_beat = event.is_beat,
                        emotion = event.emotion,
                        gender = node.gender,
                        animalese = rt.Animalese:translate(event.glyph),
                        played = false,
                        id = nil, -- result of rt.Animalese:queue
                    })
                    elapsed = elapsed + event.duration
                end
            end
            node.duration = elapsed
        end

        if node_entry[dialog_choice_key] ~= nil then
            node.next = nil
            rt.assert(node_entry[next_key] == nil, "In ow.DialogBox: for dialog `", self._id, "`: multiple choice node `", key, "` has toplevel `next` set, it should be nil")

            node.n_answers = 0
            node.highlighted_answer_i = 1

            node.choice_labels = {} -- Table<rt.Label>
            node.highlighted_choice_labels = {} -- Table<rt.Label>

            node.answer_i_to_next_node_id = {}
            node.answer_i_to_next_node = {}
            node.width = 0
            node.height = 0
            for j, choice in ipairs(node_entry[dialog_choice_key]) do
                local choice_text = choice[1]
                rt.assert(meta.is_string(choice[1]), "In ow.DialogBox: for dialog `", self._id, "` multiple choice node `", key, "` does not have answer at position `1`")

                local label = rt.Label(choice_text)
                local highlighted_label = rt.Label(selected_answer_prefix .. choice_text .. selected_answer_postfix)

                label:realize()
                highlighted_label:realize()

                table.insert(node.choice_labels, label)
                table.insert(node.highlighted_choice_labels, highlighted_label)

                node.n_answers = node.n_answers + 1
                node.answer_i_to_next_node_id[j] = choice.next
            end
        end

        node.is_done = false

        can_be_visited[node] = false
        self._id_to_node[node.id] = node
    end

    local first_node = self._id_to_node[1]
    rt.assert(first_node ~= nil, "In ow.DialogBox: for dialog `", self._id, "`, no node with id `1`")
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
    self._should_emit_advance = true
end

--- @brief
function ow.DialogBox:get_control_state()
    if self._active_node == nil then
        return ow.DialogBoxControlState.IDLE
    else
        local active = self._active_node

        if self._active_choice_node ~= nil and active.is_done then
            return ow.DialogBoxControlState.SELECT_OPTION
        else
            if active.is_done and active.next == nil then
                return ow.DialogBoxControlState.EXIT
            else
                return ow.DialogBoxControlState.ADVANCE
            end
        end
    end
end

--- @brief
function ow.DialogBox:_set_active_node(node)
    local m = rt.settings.margin_unit
    local before = self._active_node

    if node == nil then
        if self._active_node ~= nil then
            if self._done_emitted == false then
                self._done_emitted = true
                self:signal_emit("done")
                self:signal_emit("control_state_changed", ow.DialogBoxControlState.IDLE)
            end
        end
    else
        if node.type == _node_type_choice then
            self._active_choice_node = node

            local frame_w, frame_h = node.width + 4 * m, node.height + 2 * m
            self._choice_frame:reformat(0, 0, frame_w, frame_h)
            self._choice_frame_x = self._frame_x + m
            self._choice_frame_y = self._frame_y - m - frame_h
        else
            node.n_advance_triggers = 0
        end

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

        self._should_emit_advance = true
    end

    if (before == nil and node ~= nil) or (node ~= nil and (before.speaker_id ~= node.speaker_id)) then
        if before == nil then
            self:signal_emit("speaker_changed", node.speaker_id, nil)
        else
            self:signal_emit("speaker_changed", node.speaker_id, before.speaker_id)
        end
    end

    local node_before = self._active_node
    self._active_node = node
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
        local current_x = outer_margin

        do
            local current_y = m
            for label in values(node.labels) do
                label:reformat(current_x, current_y, area_w)
                current_y = current_y + select(2, label:measure())
            end
        end

        if node.type == _node_type_choice then
            -- measure all labels
            node.width = 0
            node.height = 0
            local current_y = m
            for i = 1, node.n_answers do
                node.choice_labels[i]:reformat(current_x, current_y, math.huge) -- answer labels should only be one line
                node.highlighted_choice_labels[i]:reformat(current_x, current_y, math.huge)

                local label_w, label_h = node.highlighted_choice_labels[i]:measure()
                node.width = math.max(node.width, label_w)
                node.height = node.height + label_h
                current_y = current_y + label_h
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

--- @brief [internal]
function ow.DialogBox:_update_node_offset_from_n_lines_visible(n_lines_visible)
    self._node_offset_y = -1 * math.max( n_lines_visible - self._max_n_lines, 0) * self._line_height
end

--- @brief
function ow.DialogBox:_update_animalese(node, delta)
    node.elapsed = node.elapsed + delta
    for _, event in ipairs(node.event_map) do
        if event.time < node.elapsed and event.was_played == false then
            if event.is_beat then
                event.id = rt.Animalese:queue_beat(event.duration)
            else
                event.id = rt.Animalese:queue(event.animalese, node.gender, event.emotion)
            end
            event.was_played = true
        end
    end
end

--- @brief
function ow.DialogBox:update(delta)
    if not self._is_started then return end

    local control_state_before = self:get_control_state()

    if self._active_node ~= nil then
        for labels in range(
            self._active_node.labels,
            self._active_node.choice_labels,  -- nil for non choice
            self._active_node.highlighted_choice_labels
        ) do
            for label in values(labels) do
                label:update(delta)
            end
        end

        if self._is_first_update then
            self:signal_emit("speaker_changed", self._active_node.speaker_id)
            self:signal_emit("control_state_changed", ow.DialogBoxControlState.ADVANCE)
            self._is_first_update = false
        end

        self:_update_animalese(self._active_node, delta)
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

        local node = self._active_node
        node.elapsed = math.min(node.elapsed + delta, node.duration)

        local init_label = function(label)
            if label.dialog_box_elapsed == nil then label.dialog_box_elapsed = 0 end
            if label.dialog_box_is_done == nil then label.dialog_box_is_done = false end
        end

        for label in values(node.labels) do
            -- inject local per-label values
            init_label(label)

            if label.dialog_box_is_done == true then
                n_lines_visible = n_lines_visible + label:get_n_lines()
            else
                label.dialog_box_elapsed = label.dialog_box_elapsed + delta
                local is_done, new_n_lines, _ = label:update_n_visible_characters_from_elapsed(
                    label.dialog_box_elapsed
                )
                n_lines_visible = n_lines_visible + new_n_lines
                label.dialog_box_is_done = is_done
            end

            if label.dialog_box_is_done == false then
                at_least_one_label_not_done = true
                break
            end
        end

        node.is_done = (node.elapsed / node.duration) >= 1
        if node.is_done and node.type == _node_type_choice then
            for labels in range(node.choice_labels, node.highlighted_choice_labels) do
                for label in values(labels) do
                    init_label(label)
                    label.dialog_box_elapsed = label.dialog_box_elapsed + delta
                    label:update_n_visible_characters_from_elapsed(label.dialog_box_elapsed)
                end
            end
        end

        self:_update_node_offset_from_n_lines_visible(n_lines_visible)

        if self._should_emit_advance == true then
            self:signal_emit("advance")
            self._should_emit_advance = false
        end

        self._is_waiting_for_advance = not at_least_one_label_not_done
        if self._is_waiting_for_advance and self._should_auto_advance then
            self:_advance()
        end
    end

    local control_state_after = self:get_control_state()
    if control_state_before ~= control_state_after then
        self:signal_emit("control_state_changed", control_state_after)
    end
end

--- @brief [internal]
function ow.DialogBox:_advance()
    if self._active_node == nil or self._active_node.type ~= _node_type_text then return false end

    local sound_id = rt.settings.overworld.dialog_box.menu_confirm_sound_id

    -- skip to end of current node
    self._active_node.n_advance_triggers = self._active_node.n_advance_triggers + 1
    local target_n_advance =  rt.settings.overworld.dialog_box.n_advance_triggers
    if self._active_node.n_advance_triggers >= target_n_advance then
        local n_lines_visible = 0
        for label in values(self._active_node.labels) do
            label.dialog_box_is_done = true
            label.dialog_box_elapsed = math.huge
            label:set_n_visible_characters(math.huge)
            n_lines_visible = n_lines_visible + label:get_n_lines()
        end
        self:_update_node_offset_from_n_lines_visible(n_lines_visible)
    end

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
function ow.DialogBox:handle_button_pressed(which)
    local advance_button = rt.settings.overworld.dialog_box.advance_button

    if self._active_choice_node ~= nil and self._active_node.is_done == true then
        local move_sound_id = rt.settings.overworld.dialog_box.menu_move_sound_id
        local confirm_sound_id = rt.settings.overworld.dialog_box.menu_confirm_sound_id
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
        elseif which == rt.InputAction.INTERACT then
            self:_set_active_node(node.answer_i_to_next_node[node.highlighted_answer_i])
        end
    elseif self._active_node ~= nil then
        if which == advance_button then
            if self._active_node.next == nil and self._active_node.is_done == true then
                self:_set_active_node(nil) -- exit dialog
            else
                self:_advance()
            end
        end
    end

    if which == advance_button then
        self._advance_button_is_down = true
    end
end

--- @brief
function ow.DialogBox:handle_button_released(which)
    if which == rt.settings.dialog_box.advance_button then
        self._advance_button_is_down = false
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

    if self._is_waiting_for_advance and self._active_node ~= nil then
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

    if self._active_choice_node ~= nil and self._active_node.is_done then
        local node = self._active_choice_node
        love.graphics.push()
        love.graphics.translate(self._choice_frame_x, self._choice_frame_y)
        self._choice_frame:draw()
        for i = 1, node.n_answers do
            if i == node.highlighted_answer_i then
                node.highlighted_choice_labels[i]:draw()
            else
                node.choice_labels[i]:draw()
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
        for labels in range(
            node.labels,
            node.choice_labels,
            node.highlighted_choice_labels
        ) do
            for label in values(labels) do
                label.dialog_box_elapsed = nil
                label.dialog_box_is_done = nil
                label:set_n_visible_characters(0)
            end

            node.is_done = false
        end

        for event in values(node.event_map) do
            rt.Animalese:remove(event.id)
            event.was_played = false
        end

        node.n_advance_triggers = 0
    end
    self:signal_emit("control_state_changed", ow.DialogBoxControlState.IDLE)
    self._is_started = false
end

--- @brief
function ow.DialogBox:start()
    self:_set_active_node(self._id_to_node[1])
    self._done_emitted = false
    self._is_first_update = true
    self:signal_emit("control_state_changed", ow.DialogBoxControlState.ADVANCE)
    self._is_started = true
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

--- @brief
function ow.DialogBox:get_is_last_node()
    return self._active_node == nil or self._active_node.next == nil
end