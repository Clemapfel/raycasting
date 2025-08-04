require "common.label"
require "common.stencil"
require "common.frame"

rt.settings.dialog_handler = {
    speaker_orientation_left = "left",
    speaker_orientation_right = "right",

    -- formatting
    n_lines = 3,
    font_size = rt.FontSize.REGULAR,
    font = rt.settings.font.default,
    portrait_size = 100,

    scroll_speed_speedup = 2, -- fraction
}

-- @brief rt.DialogHandler
rt.DialogHandler = meta.class("CutsceneDialogHandler", rt.Widget)

--- @signal choice (self,
meta.add_signals(rt.DialogHandler, "choice", "done")

--[[
dialog_handler:create_from({
    [1] = { -- node at [1] is required, designates starting node
        speaker : String?
        orientation : < "left" | "right" >?

        [1] = "first line",
        [2] = "second line",

        next = Any? -- id for next node, nil for end of dialog
        next = {    -- or table for choice menu
            { "answer 01", 1 },
            { "answer 02", "other_id" }
        }
    },

    ["other_id"] = {
        "other line"
        -- ...
    }
}
]]--

--- @brief
function rt.DialogHandler:instantiate()
    self._frame = rt.Frame()
    self._speaker_frame = rt.Frame()
    self._portrait_frame = rt.Frame()
    self._choice_frame = rt.Frame()

    self._frame:set_use_shader(true)

    self._text_stencil = rt.AABB()
    self._tree = {}
    
    self._is_waiting_for_advance = false
    self._a_button_is_down = false
    self._b_button_is_down = false

    self._advance_indicator = {} -- love.Polygon
    self._advance_indicator_max_offset = 1
    self._advance_indicator_y_offset = 0
    self._advance_indicator_elapsed = 0

    self._choice_index = 1
    self._choice_indicator = {} -- love.Polygon
    self._choice_indicator_x = 0
    self._choice_indicator_y = 0

    self._entries = {}
    self._active_entry = nil
    self._entry_y_offset = 0

    self._portrait_canvas = nil -- rt.RenderTexture
    self._portrait_x = 0
    self._portrait_y = 0
end

local _orientation_left = true
local _orientation_right = false

local _new_label = function(text)
    return rt.Label(text, rt.settings.dialog_handler.font_size, rt.settings.dialog_handler.font)
end

--- @brief
--- @return Number node_id
function rt.DialogHandler:create_from(tree_id)
    local tree
    if meta.typeof(tree_id) == "Table" then
        tree = tree_id
        tree_id = "local"
    else
        require "common.translation"
        tree = rt.Translation.dialog[tree_id]
    end

    self._tree_id = tree_id
    self._tree = tree

    if tree == nil then
        rt.error("In rt.DialogHandler.push: no dialog tree with id `" .. tree_id .. "` present in common/translation.lua")
    end

    local settings = rt.settings.dialog_handler
    local orientation_left = settings.speaker_orientation_left
    local orientation_right = settings.speaker_orientation_right

    -- validate `next` points to valid node or nil
    local seen_nodes = {}
    local can_be_visited = {}
    for id, _ in pairs(tree) do
        seen_nodes[id] = true
        can_be_visited[id] = id == 1
    end

    local speaker_prefix = "<b>"
    local speaker_postfix = "</b>"

    self._entries = {}

    for id, node in pairs(tree) do
        if node.next ~= nil then
            if meta.is_table(node.next) then
                for pair in values(node.next) do
                    if seen_nodes[pair[2]] == nil then
                        rt.error("In rt.DialogHandler: in tree `" .. tree_id .. "`: node `" .. id .. "` points to id `" .. pair[2] .. "`, but it is not present in tree")
                    end
                end
            else
                if seen_nodes[node.next] == nil then
                    rt.error("In rt.DialogHandler: in tree `" .. tree_id .. "`: node `" .. id .. "` points to id `" .. node.next.. "`, but it is not present in tree")
                end
            end
        end

        if not meta.is_string(node[1]) then
            rt.error("In rt.DialogHandler: in tree `" .. tree_id .. "`: node `" .. id .. "` has no text")
        end

        -- construct nodes
        local entry = {}
        self._entries[id] = entry

        entry.node = node
        entry.id = id

        -- speaker
        local speaker = node.speaker
        local orientation = node.orientation

        entry.has_speaker = speaker ~= nil
        if entry.has_speaker then
            local text = speaker
            if not string.contains(text, "<b>") then
                text = speaker_prefix .. speaker .. speaker_postfix
            end
            entry.speaker_label = _new_label(text)
            entry.speaker_label_w, entry.speaker_label_h = entry.speaker_label:measure()
            entry.speaker_label:realize()
            entry.speaker_label:reformat(0, 0, math.huge, math.huge)

            entry.speaker_frame_aabb = rt.AABB()
            entry.portrait_frame_aabb = rt.AABB()
        end

        if orientation ~= nil then
            if not (orientation == orientation_left or orientation == orientation_right) then
                rt.error("In rt.DialogHandler: in tree `" .. tree_id .. "`: node `" .. id .. "`.orientation` is not `" .. orientation_left .. "` or `" .. orientation_right .. "`")
            end

            if orientation == orientation_left then
                entry.orientation = _orientation_left
            else
                entry.orientation = _orientation_right
            end
        else
            entry.orientation = _orientation_left
        end

        entry.has_choices = meta.is_table(node.next)
        if entry.has_choices then
            entry.choices_frame_aabb = rt.AABB()
            entry.choices = {}

            local choice_i = 1
            for pair in values(node.next) do
                local answer, next = table.unpack(pair)
                if not meta.is_string(answer) then
                    rt.error("In rt.DialogHandler: in tree `" .. tree_id .. "`: node `" .. id .. ".next` is a choice, but answer at `" .. choice_i .. "` is not a table of the form `{ \"answer\", 1 }`")
                end

                -- format, unless formatting already present
                local highlight_answer = answer
                if not string.contains(answer, "<b>") then
                    highlight_answer = "<b>" .. highlight_answer .. "</b>"
                end

                if not string.contains(answer, "<color>") then
                    highlight_answer = "<color=SELECTION>" .. highlight_answer .. "</color>"
                end

                local highlight = _new_label(highlight_answer)
                local no_highlight =  _new_label(answer)

                for label in range(highlight, no_highlight) do
                    label:realize()
                end

                table.insert(entry.choices, {
                    label_no_highlight = no_highlight,
                    label_highlight = highlight,
                    text = answer,
                    next = next -- later replaced
                })

                choice_i = choice_i + 1
            end
        else
            entry.next = node.next -- later replace by proper entry instead of id
        end

        -- labels
        entry.labels = {}

        local text_i = 1
        local text = node[text_i]
        while text ~= nil do
            local label = _new_label(text)
            label:realize()
            label:set_n_visible_characters(0)
            table.insert(entry.labels, label)

            text_i = text_i + 1
            text = node[text_i]
        end
    end

    -- connect nodes
    for entry in values(self._entries) do
        if entry.has_choices then
            local choice_i = 1
            for choice_entry in values(entry.choices) do
                if choice_entry.next ~= nil then
                    local next = self._entries[choice_entry.next]
                    if next == nil then
                        rt.error("In rt.DialogHandler: in tree `" .. tree_id .. "`: node `" .. entry.id .. ".choices[" .. choice_i .. "]` has `" .. choice_entry.next .. "` as next, which does not point to a valid node")
                    end

                    choice_entry.next = next
                    can_be_visited[next.id] = true
                end

                choice_i = choice_i + 1
            end
        else
            if entry.next ~= nil then
                local next = self._entries[entry.next]
                if next == nil then
                    rt.error("In rt.DialogHandler: in tree `" .. tree_id .. "`: node `" .. entry.id .. ".next` has `" .. entry.next .. "`as next, which does not point to a valid node")
                end
                entry.next = next
                can_be_visited[next.id] = true
            end
        end
    end

    for id, b in pairs(can_be_visited) do
        if b == false then
            rt.error("In rt.DialogHandler: in tree `" .. tree_id .. "`: node `" .. id .. "` has no node pointing to it, it cannot be visited")
        end
    end

    self._active_entry = self._entries[1]
    if self._active_entry == nil then
        rt.error("In rt.DialogHandler: in tree `" .. tree_id .. "`: no node with id `1`, unable to determine first node in tree")
    end

    if self:get_is_realized() then
        self:_reformat_entries()
    end
end

--- @brief
function rt.DialogHandler:realize()
    if self:already_realized() then return end

    for widget in range(
        self._frame,
        self._speaker_frame,
        self._portrait_frame
    ) do
        widget:realize()
    end
end

--- @brief
function rt.DialogHandler:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local outer_margin = 2 * m

    local settings = rt.settings.dialog_handler
    local max_n_lines = settings.n_lines
    local line_height = settings.font:get_line_height(settings.font_size)
    
    local frame_w = width - 2 * outer_margin
    local frame_h = max_n_lines * line_height + 2 * m
    local frame_x = x + outer_margin
    local frame_y = y + height - outer_margin - frame_h
    self._frame:reformat(frame_x, frame_y, frame_w, frame_h)

    local area_w = frame_w - 4 * m
    local area_h = frame_h - 2 * m

    local portrait_w = settings.portrait_size * rt.get_pixel_scale()
    local portrait_h = portrait_w

    self._text_stencil = rt.AABB(
        frame_x + 2 * m,
        frame_y + m,
        area_w,
        area_h
    )

    -- indicator
    local advance_indicator_radius = m
    self._advance_indicator_max_offset = advance_indicator_radius
    local advance_indicator_x = frame_x + 0.5 * frame_w
    local advance_indicator_y = frame_y + frame_h
    self._advance_indicator = {}

    local choice_indicator_radius = advance_indicator_radius / math.sqrt(2)
    local choice_indicator_x = choice_indicator_radius
    local choice_indicator_y = choice_indicator_radius
    self._choice_indicator = {}

    local advance_angle_offset = (2 * math.pi) / 4
    local choice_angle_offset = 0
    for angle = 0, 2 * math.pi, (2 * math.pi) / 3 do
        table.insert(self._advance_indicator, advance_indicator_x + math.cos(angle + advance_angle_offset) * advance_indicator_radius)
        table.insert(self._advance_indicator, advance_indicator_y + math.sin(angle + advance_angle_offset) * advance_indicator_radius)

        table.insert(self._choice_indicator, choice_indicator_x + math.cos(angle + choice_angle_offset) * choice_indicator_radius)
        table.insert(self._choice_indicator, choice_indicator_y + math.sin(angle + choice_angle_offset) * choice_indicator_radius)
    end

    self._portrait_canvas = rt.RenderTexture(portrait_w, portrait_h)

    self:_reformat_entries()
end

--- @brief
function rt.DialogHandler:_reformat_entries()
    local x, y, width, height = self:get_bounds():unpack()
    local m = rt.settings.margin_unit
    local outer_margin = 2 * m

    local settings = rt.settings.dialog_handler
    local max_n_lines = settings.n_lines
    local line_height = settings.font:get_line_height(settings.font_size)

    local frame_w = width - 2 * outer_margin
    local frame_h = max_n_lines * line_height + 2 * m
    local frame_x = x + outer_margin
    local frame_y = y + height - outer_margin - frame_h
    self._frame:reformat(frame_x, frame_y, frame_w, frame_h)

    local area_w = frame_w - 4 * m
    local area_h = frame_h - 2 * m

    local portrait_w = settings.portrait_size * rt.get_pixel_scale()
    local portrait_h = portrait_w

    local advance_indicator_radius = m
    local choice_indicator_radius = advance_indicator_radius / math.sqrt(2)

    local thickness = self._speaker_frame:get_thickness()
    for entry in values(self._entries) do
        -- reformat speaker / portrait bounds
        if entry.has_speaker then
            local speaker_w, speaker_h = entry.speaker_label:measure()
            local speaker_frame_w = speaker_w + 3 * m
            local speaker_frame_h = line_height + 2 * 0.5 * m
            local speaker_frame_y = frame_y - 3 * m + thickness

            local speaker_frame_x
            if entry.orientation == _orientation_left then
                speaker_frame_x = frame_x + m
            else
                speaker_frame_x = frame_x + frame_w - m - speaker_frame_w
            end

            entry.speaker_frame_aabb:reformat(
                speaker_frame_x, speaker_frame_y,
                speaker_frame_w, speaker_frame_h
            )

            entry.speaker_label:reformat(
                speaker_frame_x + 0.5 * speaker_frame_w - 0.5 * speaker_w,
                speaker_frame_y + 0.5 * speaker_frame_h - 0.5 * speaker_h,
                math.huge, math.huge
            )

            local portrait_frame_y = frame_y - speaker_frame_h - m - portrait_h
            local portrait_frame_x
            if entry.orientation == _orientation_left then
                portrait_frame_x = frame_x + m
            else
                portrait_frame_x = frame_x + frame_w - m - portrait_w
            end

            entry.portrait_frame_aabb:reformat(
                portrait_frame_x, portrait_frame_y,
                portrait_w, portrait_h
            )
        end

        if entry.has_choices then
            local max_w, max_h = -math.huge, -math.huge
            local total_h = 0
            for choice_entry in values(entry.choices) do
                local highlight_w, highlight_h = choice_entry.label_highlight:measure()
                local no_highlight_w, no_highlight_h = choice_entry.label_no_highlight:measure()
                max_w = math.max(max_w, no_highlight_w, highlight_w)
                max_h = math.max(max_h, no_highlight_h, highlight_h)
                total_h = total_h + math.max(no_highlight_h, highlight_h)
            end

            max_w = max_w + m + 2 * choice_indicator_radius

            local choice_w = max_w + 2 * m
            local choice_h = total_h + 2 * m
            local choice_y = frame_y - m - choice_h
            local choice_x
            if entry.has_speaker and entry.orientation == _orientation_left then
                choice_x = frame_x + frame_w - m - choice_w
            else
                choice_x = frame_x + m
            end

            entry.choices_frame_aabb:reformat(
                choice_x, choice_y,
                choice_w, choice_h
            )

            entry.choices_indicator_offsets = {}

            local choice_label_y = choice_y + m
            local choice_label_x = choice_x + m
            for choice_entry in values(entry.choices) do
                local highlight_w, highlight_h = choice_entry.label_highlight:measure()
                local no_highlight_w, no_highlight_h = choice_entry.label_no_highlight:measure()

                choice_entry.label_highlight:reformat(
                    choice_label_x + 2 * choice_indicator_radius + 0.5 * m,
                    choice_label_y + 0.5 * max_h - 0.5 * highlight_h,
                    math.huge
                )

                choice_entry.label_no_highlight:reformat(
                    choice_label_x + 2 * choice_indicator_radius + 0.5 * m,
                    choice_label_y + 0.5 * max_h - 0.5 * no_highlight_h,
                    math.huge
                )

                table.insert(entry.choices_indicator_offsets, {
                    choice_label_x,
                    choice_label_y + 0.5 * max_h - choice_indicator_radius
                })
                choice_label_y = choice_label_y + max_h
            end
        end

        -- reformat labels
        local label_x = frame_x + 2 * m
        local label_y = frame_y + m
        for label in values(entry.labels) do
            label:reformat(label_x, label_y, area_w, math.huge)
            label_y = label_y + select(2, label:measure())
        end
    end

    self:_set_active_entry(self._active_entry)
end

--- @brief
function rt.DialogHandler:_set_active_entry(entry)
    self._active_entry = entry
    self._choice_index = 1

    if self._active_entry ~= nil then
        for label in values(entry.labels) do
            label:set_n_visible_characters(0)
        end

        if entry.has_speaker then
            local portrait = entry.portrait_frame_aabb
            self._portrait_frame:reformat(portrait)
            self._portrait_x, self._portrait_y = portrait.x, portrait.y
            self._speaker_frame:reformat(entry.speaker_frame_aabb)
        end

        if entry.has_choices then
            self._choice_frame:reformat(entry.choices_frame_aabb)
        end
    end
end

--- @brief
function rt.DialogHandler:draw()
    local entry = self._active_entry
    if entry == nil then return end

    self._frame:draw()
    if entry.has_speaker then
        self._portrait_frame:draw()
        self._portrait_frame:bind_stencil()
        self._portrait_canvas:draw(self._portrait_x, self._portrait_y)
        self._portrait_frame:unbind_stencil()

        self._speaker_frame:draw()
        entry.speaker_label:draw()
    end

    love.graphics.setLineJoin("miter")
    love.graphics.setLineWidth(5 * rt.get_pixel_scale())

    if self._is_waiting_for_advance and entry.has_choices then
        self._choice_frame:draw()
        for i, choice_entry in ipairs(entry.choices) do
            if i == self._choice_index then
                love.graphics.push()
                love.graphics.translate(table.unpack(entry.choices_indicator_offsets[i]))

                rt.Palette.BASE_OUTLINE:bind()
                love.graphics.line(self._choice_indicator)
                rt.Palette.FOREGROUND:bind()
                love.graphics.polygon("fill", self._choice_indicator)

                love.graphics.pop()
                choice_entry.label_highlight:draw()
            else
                choice_entry.label_no_highlight:draw()
            end
        end
    end

    local value = 254
    rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
    love.graphics.rectangle("fill", self._text_stencil:unpack())
    rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

    love.graphics.push()
    love.graphics.translate(0, self._entry_y_offset)
    for label in values(entry.labels) do
        label:draw()
    end
    love.graphics.pop()

    rt.graphics.set_stencil_mode(nil)

    if self._is_waiting_for_advance then
        love.graphics.push()
        love.graphics.translate(0, self._advance_indicator_y_offset)

        rt.Palette.BASE_OUTLINE:bind()
        love.graphics.line(self._advance_indicator)

        rt.Palette.FOREGROUND:bind()
        love.graphics.polygon("fill", self._advance_indicator)

        love.graphics.pop()
    end
end

function rt.DialogHandler:_update_node_offset_from_n_lines_visible(n_lines_visible)
    local settings = rt.settings.dialog_handler
    local max_n_lines = settings.n_lines
    local line_height = settings.font:get_line_height(settings.font_size)
    
    self._entry_y_offset = -1 * math.max( n_lines_visible - max_n_lines, 0) * line_height
end

--- @brief
function rt.DialogHandler:advance()
    if self._active_entry == nil then return end

    -- skip to end of current node
    local n_lines_visible = 0
    for label in values(self._active_entry.labels) do
        label.dialog_box_is_done = true
        label.dialog_box_elapsed = math.huge
        label:set_n_visible_characters(math.huge)
        n_lines_visible = n_lines_visible + label:get_n_lines()
    end
    self:_update_node_offset_from_n_lines_visible(n_lines_visible)

    local before = self._active_entry

    -- go to next node if already fully advanced
    if self._is_waiting_for_advance then
        if self._active_entry.has_choices then
            local index = self._choice_index
            local text = self._active_entry.choices[self._choice_index].text
            self:_set_active_entry(self._active_entry.choices[self._choice_index].next)

            if self._active_entry ~= nil then
                self:signal_emit("choice", index, text)
            end
        else
            self:_set_active_entry(self._active_entry.next)
        end
    end

    if before ~= nil and self._active_entry == nil then
        self:signal_emit("done")
    end

    self._is_waiting_for_advance = false
end

--- @brief
function rt.DialogHandler:update(delta)
    local entry = self._active_entry
    if entry == nil then return end

    if entry.has_speaker then
        entry.speaker_label:update(delta)
    end

    for label in values(entry.labels) do
        label:update(delta)
    end

    -- indicator animation
    if self._is_waiting_for_advance then
        self._advance_indicator_elapsed = self._advance_indicator_elapsed + delta
        local offset = (math.sin(3 * self._advance_indicator_elapsed) + 1) / 2 - 1
        self._advance_indicator_y_offset = offset * self._advance_indicator_max_offset * 0.5
    end
    
    -- text scrolling
    if self._active_entry ~= nil then
        local n_lines_visible = 0
        local at_least_one_label_not_done = false
        for label in values(self._active_entry.labels) do
            -- inject local per-label values
            if label.dialog_handler_elapsed == nil then label.dialog_handler_elapsed = 0 end
            if label.dialog_handler_is_done == nil then label.dialog_handler_is_done = false end

            if label.dialog_handler_is_done == true then
                n_lines_visible = n_lines_visible + label:get_n_lines()
            else
                label.dialog_handler_elapsed = label.dialog_handler_elapsed + delta

                local speed = rt.settings.label.scroll_speed * rt.GameState:get_text_speed()
                if self._a_button_is_down or self._b_button_is_down then
                    speed = speed * rt.settings.dialog_handler.scroll_speed_speedup
                end

                local is_done, new_n_lines, _ = label:update_n_visible_characters_from_elapsed(
                    label.dialog_handler_elapsed, speed
                )

                n_lines_visible = n_lines_visible + new_n_lines
                label.dialog_handler_is_done = is_done
            end

            if label.dialog_handler_is_done == false then
                at_least_one_label_not_done = true
                self._is_waiting_for_advance = false
                break
            end

            self._is_waiting_for_advance = true -- all labels done
            if self._should_auto_advance then
                self:advance()
            end
        end

        self:_update_node_offset_from_n_lines_visible(n_lines_visible)
    end
end

--- @brief
function rt.DialogHandler:handle_button_pressed(button)
    if self._active_entry == nil then return end
    if button == rt.InputAction.CONFIRM then
        if self._is_waiting_for_advance then
            self:advance()
        else
            -- scroll next label
            for label in values(self._active_entry.labels) do
                if label.dialog_handler_is_done ~= true then
                    label.dialog_handler_is_done = true
                    label.dialog_handler_elapsed = math.huge
                    label:set_n_visible_characters(math.huge)
                    break
                end
            end
            self:update(0) -- update y_offset
        end

        self._a_button_is_down = true
    elseif button == rt.InputAction.BACK then
        self._b_button_is_down = true
    elseif button == rt.InputAction.UP then
        if self._active_entry.has_choices and self._choice_index > 1 then
            self._choice_index = self._choice_index - 1
        end
    elseif button == rt.InputAction.DOWN then
        if self._active_entry.has_choices and self._choice_index < #(self._active_entry.choices) then
            self._choice_index = self._choice_index + 1
        end
    end
end

--- @brief
function rt.DialogHandler:handle_button_released(button)
    if self._active_entry == nil then return end
    if button == rt.InputAction.CONFIRM then
        self._a_button_is_down = false
    elseif button == rt.InputAction.BACK then
        self._b_button_is_down = false
    end
end

--- @brief
function rt.DialogHandler:get_portrait_canvas()
    return self._portrait_canvas
end
