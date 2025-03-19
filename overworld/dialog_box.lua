require "common.font"
require "common.label"
require "common.frame"
require "common.mesh"

-- accepted ids for dialog node in config file
rt.settings.overworld.dialog_box = {
    portrait_key = "portrait",
    speaker_key = "speaker",
    next_key = "next",
    dialog_choice_key = "choices",

    portrait_resolution_w = 40,
    portrait_resolution_h = 40,
    n_lines = 3
}

--- @class ow.DialogBox
ow.DialogBox = meta.class("OverworldDialogBox", rt.Widget)

--- @brief
function ow.DialogBox:instantiate(dialog_id)
    meta.install(self, {
        _dialog_id = dialog_id,
        _is_initialized = false,
        _is_done = false,

        _id_to_node = {},
        _portrait_id_to_portrait = {},
        _speaker_to_orientation = {},
        _active_node = nil,

        _is_waiting_for_advance = false,

        _portrait_frame = rt.Frame(),
        _portrait_left_x = 0,
        _portrait_left_y = 0,
        _portrait_right_x = 0,
        _portrait_right_y = 0,
        _portrait_mesh = rt.MeshRectangle(),
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

        _frame = rt.Frame(),

        _advance_indicator = {},
        _advance_indicator_outline = {},
        _advance_indicator_color = rt.Palette.FOREGROUND,
        _advance_indicator_outline_color = rt.Palette.BACKGROUND_OUTLINE,
        _advance_indicator_outline_w = 2,
        _advance_indicator_offset = 0
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

    local can_be_visited = {}
    local current_x, current_y = 0, 0
    for key, node_entry in pairs(entry) do
        local node = {}
        node.id = key
        node.next_id = node_entry[next_key]

        if node_entry[dialog_choice_key] ~= nil then
            node.type = _node_type_choice
            rt.warning("In ow.DialogBox: TODO CHOICE")
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
                local texture = self._portrait_id_to_portrait[portrait_id]
                if texture == nil then
                    texture = rt.Texture(portrait_id)
                    self._portrait_id_to_portrait[portrait_id] = texture
                end

                node.portrait = texture
            end

            if not meta.is_string(node_entry[1]) then
                rt.error("In ow.DialogBox: for dialog `" .. self._dialog_id .. "`: node `" .. node.id .. "` does not have any dialog text")
            end

            do
                local i = 1
                local text = node[i]
                while text ~= nil do
                    local label = rt.Label(text)
                    label:realize()
                    table.insert(node.labels, label)

                    i = i + 1
                end
            end
        end

        can_be_visited[node] = false
        self._id_to_node[key] = node
    end

    for node, visited in pairs(can_be_visited) do
        if visited == false then
            rt.warning("In ow.DialogBox: for dialog `" .. self._dialog_id .. "`: node `" .. node.id .. "` has no other pointing to it, it cannot be visited" )
        end
    end

    local first_node = self._id_to_node[1]
    if first_node == nil then
        rt.warning("In ow.DialogBox: for dialog `" .. self._dialog_id .. "`, no node with id `1`")
        first_node = table.first(self._id_to_node)
    end

    self._is_initialized = true
    self:_set_active_node(first_node)
end

--- @brief
function ow.DialogBox:size_allocate(x, y, width, height)
    if self._is_initialized == false then return end

    local m = rt.settings.margin_unit
    local outer_margin = 2 * m

    local _, line_height = rt.settings.font.default:measure_glyph("|")

    local frame_w = width - 2 * outer_margin
    local frame_h = rt.settings.overworld.dialog_box.n_lines * line_height + 2 * m
    local frame_x = x + outer_margin
    local frame_y = y + height - outer_margin - frame_h

    self._frame:reformat(frame_x, frame_y, frame_w, frame_h)

    local speaker_frame_w = 0.3 * frame_w -- resize depending on speaker label
    local speaker_frame_h = line_height + m
    self._speaker_frame_w = speaker_frame_w
    self._speaker_frame_h = speaker_frame_h
    self._speaker_frame_left_x = frame_x + m
    self._speaker_frame_left_y = frame_y - 3 * m
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
    self._portrait_mesh = rt.MeshRectangle(0, 0, portrait_w, portrait_h)

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
    for node in values(self._id_to_node) do
        if node.type == _node_type_text then
            local current_x, current_y = 0, 0
            for label in values(node.labels) do
                label:reformat(current_x, current_y, area_w)
                local label_w, label_h = label:measure()
                current_y = current_y + label_h
            end
        end
    end

    self:_set_active_node(self._active_node)
end

--- @brief
function ow.DialogBox:_set_active_node(node)
    self._active_node = node
    if self._active_node == nil then
        self._is_done = true
        return
    end

    if self._active_node.type == _node_type_text then
        self._portrait_mesh:set_texture(node.portrait)
        self._portrait_visible = node.portrait ~= nil
        local left_or_right = self._speaker_to_orientation[node.speaker_id]
        self._portrait_left_or_right = false-- TODO left_or_right or true

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
    end
end

local _advance_indicator_elapsed = 0

--- @brief
function ow.DialogBox:update(delta)
    if self._is_done then return end
    _advance_indicator_elapsed = _advance_indicator_elapsed + delta
    local offset = (math.sin(3 * _advance_indicator_elapsed) + 1) / 2 - 1
    self._advance_indicator_offset = offset * self._advance_indicator_radius * 0.5
end

--- @brief
function ow.DialogBox:set_speaker_orientation(portrait_id, left_or_right)
    self._speaker_to_orientation = left_or_right
end

--- @brief
function ow.DialogBox:draw()
    if self._is_initialized == false or self._is_done then return end

    self._frame:draw()

    love.graphics.push()
    if self._portrait_left_or_right then
        love.graphics.translate(self._portrait_left_x, self._portrait_left_y)
    else
        love.graphics.translate(self._portrait_right_x, self._portrait_right_y)
    end
    self._portrait_frame:draw()
    self._portrait_frame:bind_stencil()
    self._portrait_mesh:draw()
    self._portrait_frame:unbind_stencil()
    love.graphics.pop()

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

    love.graphics.pop()
end