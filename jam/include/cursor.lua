Cursor_t = "cursor"

--- @enum CursorType
CursorType = {
    DEFAULT = "DEFAULT",
    CAN_CLICK = "CAN_CLICK",
    CANNOT_CLICK = "CANNOT_CLICK"
}

local _height, _width = 6 * 3, 6 * 1
local _instance = object_new(Cursor_t, {
    cursor_type = CursorType.DEFAULT
})

cursor_new = function()
    log_error("In cursor_new: trying to instantiate a cursor, but it is a singleton")
end

cursor_set_type = function(cursor_type)
    local self = _instance -- was a global assignment before
    log_enumcheck(cursor_type, CursorType)
    self.cursor_type = cursor_type
    return self
end

cursor_get_type = function()
    return _instance.cursor_type
end

local _cursor_get_color = function()
    local hue = love.timer.getTime() / 10
    return rgba_lighten(lcha_to_rgba(lcha_new(0.8, 1, hue, 1)), 1.5)
end

local _cursor_build_circle = function(x, y, radius, scale, n_vertices)
    local points = {}
    for i = 1, n_vertices + 1 do
        local angle = (i - 1) / n_vertices * math_tau
        table_push(points, x + math_cos(angle) * radius * scale)
        table_push(points, y + math_sin(angle) * radius * scale)
    end
    return points
end

local _cursor_draw_pointer = function(x, y, scale)
    log_typecheck(x, Number_t, y, Number_t, scale, Number_t)

    local width = _width * scale
    local height = _height * scale

    local outer_angle = math_degrees_to_radians(45)
    local divet_angle = math_degrees_to_radians(180 - 45)

    x = x - 0.5 * width
    y = y - 0.5 * height

    local a_x, a_y = x, y
    local b_x, b_y = x + math_cos(outer_angle) * height, y + math_sin(outer_angle) * height
    local c_x, c_y = x, y + height

    -- midpoint between lower
    local mid_x, mid_y = math_mix2(b_x, b_y, c_x, c_y, 0.5)

    -- move towards tip
    local dx, dy = math_normalize(a_x - mid_x, a_y - mid_y)

    -- height of triangle between outer tips, given angle
    local h = (math_distance(b_x, b_y, c_x, c_y) / 2) / math_tan(divet_angle / 2)
    mid_x, mid_y = mid_x + dx * h, mid_y + dy * h

    rgba_bind(palette_black)
    love.graphics.polygon("fill", {
        a_x, a_y,
        b_x, b_y,
        mid_x, mid_y
    })

    love.graphics.polygon("fill", {
        a_x, a_y,
        mid_x, mid_y,
        c_x, c_y
    })

    local line_width = 2 * scale
    local outline = {
        a_x, a_y,
        b_x, b_y,
        mid_x, mid_y,
        c_x, c_y,
        a_x, a_y
    }

    -- still black
    graphics_set_line_state(line_width + 1)
    graphics_draw_line(outline)

    rgba_bind(_cursor_get_color())
    graphics_set_line_state(line_width)
    graphics_draw_line(outline)
end

local _cursor_draw_can_click = function(x, y, scale)
    log_typecheck(x, Number_t, y, Number_t, scale, Number_t)

    local radius = math_mix(_width, _height, 0.5) * 0.6
    local line_width = 0.4 * radius
    local points = _cursor_build_circle(x, y, radius, scale, 16)

    rgba_bind(palette_black)
    graphics_set_line_state(line_width * scale + 2)
    graphics_draw_line(points)

    rgba_bind(_cursor_get_color())
    graphics_set_line_state(line_width * scale)
    graphics_draw_line(points)
end

local _cursor_draw_cannot_click = function(x, y, scale)
    log_typecheck(x, Number_t, y, Number_t, scale, Number_t)

    local radius = math_mix(_width, _height, 0.5) * 0.6
    local line_width = 0.4 * radius
    local points = _cursor_build_circle(x, y, radius, scale, 16)

    local cross = {
        x - radius + line_width, y + radius - line_width,
        x + radius - line_width, y - radius + line_width
    }

    rgba_bind(palette_black)
    graphics_set_line_state(line_width * scale + 2)
    graphics_draw_line(points)
    graphics_draw_line(cross)

    rgba_bind(_cursor_get_color())
    graphics_set_line_state(line_width * scale)
    graphics_draw_line(points)
    graphics_draw_line(cross)
end

cursor_draw = function()
    local self = _instance

    graphics_push_state()
    graphics_reset_transform()

    local x, y = input_get_cursor_position_raw()
    local scale = love.window.getDPIScale()

    if self.cursor_type == CursorType.DEFAULT then
        _cursor_draw_pointer(x, y, scale)
    elseif self.cursor_type == CursorType.CAN_CLICK then
        _cursor_draw_can_click(x, y, scale)
    elseif self.cursor_type == CursorType.CANNOT_CLICK then
        _cursor_draw_cannot_click(x, y, scale)
    end

    love.graphics.pop()
    return self
end