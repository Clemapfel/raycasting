require "overworld.label"

--- @class ow.TextBox
ow.TextBox = meta.class("OverworldTextBox", rt.Widget)

--- @brief
function ow.TextBox:instantiate(dialog_id)
    meta.install(self, {
        _dialog_id = dialog_id,

        _portrait_frame = rt.Frame(),
        _portrait = nil,

        _frame = rt.Frame(),
        _lines = {}, -- rt.Label

        _is_waiting_for_advance = false,

        _advance_indicator = {},
        _advance_indicator_outline = {}
    })
end

local _atlas = require "assets.text.dialog.lua"

--- @brief
function ow.TextBox:realize()
    if _atlas == nil then _atlas = require("assets.text.dialog") end

end

--- @brief
function ow.TextBox:size_allocate(x, y, width, height)
    self._frame:fit_into()
end