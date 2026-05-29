--- @class ow.DialogFocusIndicator
ow.DialogFocusIndicator = meta.class("DialogFocusIndicator")

--- @brief
function ow.DialogFocusIndicator:instantiate(
    scene, x, y
)
    self._scene = scene
    self._x, self._y = x, y
    self._opacity_motion = rt.SmoothedMotion1D(0, 2)

    self._is_active = false
end

--- @brief
function ow.DialogFocusIndicator:update(delta)
    self._opacity_motion:update(delta)
end

do
    local angle_offset = math.pi / 2
    local squish = 1 / 12 * math.pi / 2
    local _focus_indicator_bottom_x = math.cos(angle_offset)
    local _focus_indicator_bottom_y = math.sin(angle_offset)

    local _focus_indicator_top_left_x = math.cos(angle_offset + 2 * math.pi / 3 + squish)
    local _focus_indicator_top_left_y = math.sin(angle_offset + 2 * math.pi / 3 + squish)

    local _focus_indicator_top_right_x = math.cos(angle_offset + 4 * math.pi / 3 - squish)
    local _focus_indicator_top_right_y = math.sin(angle_offset + 4 * math.pi / 3 - squish)

    --- @brief
    function ow.DialogFocusIndicator:_draw(is_bloom, x, y)
        require "common.cursor"
        local radius = self:get_radius()
        y = y - rt.settings.margin_unit - 0.5 * radius

        local top_left_x = x + radius * _focus_indicator_top_left_x
        local top_left_y = y + radius * _focus_indicator_top_left_y

        local top_right_x = x + radius * _focus_indicator_top_right_x
        local top_right_y = y + radius * _focus_indicator_top_right_y

        local bottom_x = x + radius * _focus_indicator_bottom_x
        local bottom_y = y + radius * _focus_indicator_bottom_y

        local top_x = x
        local top_y = y + 0.5 * radius * _focus_indicator_top_left_y

        local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
        local r, g, b = self._scene:get_player():get_color():unpack()
        local a = self._opacity_motion:get_value()

        if not is_bloom then
            love.graphics.setColor(black_r, black_g, black_b, a)
            love.graphics.polygon("fill",
                top_left_x, top_left_y,
                top_right_x, top_right_y,
                bottom_x, bottom_y
            )
        end

        local line_width = 2
        love.graphics.setLineJoin("bevel")
        love.graphics.setLineStyle("smooth")

        if not is_bloom then
            love.graphics.setLineWidth(line_width + 1.5)
            love.graphics.line( -- outline
                top_left_x, top_left_y,
                top_x, top_y,
                top_right_x, top_right_y,
                bottom_x, bottom_y,
                top_left_x, top_left_y
            )
        end

        love.graphics.setColor(r, g, b, a)
        love.graphics.setLineWidth(line_width)
        love.graphics.line(
            top_left_x, top_left_y,
            top_x, top_y,
            top_right_x, top_right_y,
            bottom_x, bottom_y,
            top_left_x, top_left_y
        )
    end
end

--- @brief
function ow.DialogFocusIndicator:draw()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    local x, y = self._scene:get_camera():world_xy_to_screen_xy(
        self._x,
        self._y
    )

    love.graphics.setColor(1, 1, 1, 1)
    self:_draw(false, x, y)
    love.graphics.pop()
end

--- @brief
function ow.DialogFocusIndicator:draw_bloom()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    local x, y = self._scene:get_camera():world_xy_to_screen_xy(
        self._x,
        self._y
    )

    love.graphics.setColor(1, 1, 1, 1)
    self:_draw(true, x, y)
    love.graphics.pop()
end

--- @brief
function ow.DialogFocusIndicator:set_is_active(b)
    self._is_active = b
    if b == true then
        self._opacity_motion:set_target_value(1)
    else
        self._opacity_motion:set_target_value(0)
    end
end

--- @brief
function ow.DialogFocusIndicator:get_is_active()
    return self._is_active
end

--- @brief
function ow.DialogFocusIndicator:set_position(x, y)
    self._x, self._y = x, y
end

--- @brief
function ow.DialogFocusIndicator:get_position()
    return self._x, self._y
end

--- @brief
function ow.DialogFocusIndicator:get_radius()
    require "common.cursor"
    return rt.settings.cursor.radius * 2
end
