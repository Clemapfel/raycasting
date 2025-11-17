rt.settings.cursor = {
    radius = 5
}

--- @class rt.CursorType
rt.CursorType = meta.enum("CursorType", {
    POINTER = "POINTER",
    CAN_CLICK = "CAN_CLICK",
    CANNOT_CLICK = "CANNOT_CLICK"
})

--- @class rt.Cursor
rt.Cursor = meta.class("Cursor")

--- @brief
function rt.Cursor:instantiate()
    self._type = rt.CursorType.POINTER
end

--- @brief
function rt.Cursor:set_type(type)
    meta.assert_enum_value(type, rt.CursorType, 1)
    self._type = type
end

--- @brief
function rt.Cursor:get_type()
    return self._type
end

--- @brief
function rt.Cursor:_get_color()
    local hue = rt.SceneManager:get_elapsed() / 10
    local r, g, b = rt.lcha_to_rgba(0.8, 1, hue, 1)
    local boost = 1.5
    return boost * r, boost * g, boost * b, 1
end

local _height, _width = 6 * 3, 6 * 1

--- @brief
function rt.Cursor:_draw_pointer(x, y, scale)
    local width = _width * scale
    local height = _height * scale

    local outer_angle = math.degrees_to_radians(45)
    local divet_angle = math.degrees_to_radians(180 - 45)

    x = x - 0.5 * width
    y = y - 0.5 * height

    local a_x, a_y = x, y
    local b_x, b_y = x + math.cos(outer_angle) * height, y + math.sin(outer_angle) * height
    local c_x, c_y = x, y + height

    -- mid point between lower points
    local mid_x, mid_y = math.mix2(b_x, b_y, c_x, c_y, 0.5)

    -- move towards tip
    local dx, dy = math.normalize(a_x - mid_x, a_y - mid_y)

    -- height of triangle between outer tips, given angle
    local h = (math.distance(b_x, b_y, c_x, c_y) / 2) / math.tan(divet_angle / 2)
    mid_x, mid_y = mid_x + dx * h, mid_y + dy * h

    rt.Palette.BLACK:bind()
    love.graphics.polygon("fill", {-- Table<Number>
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
    love.graphics.setLineJoin("bevel")

    love.graphics.setLineWidth(line_width + 1)
    love.graphics.line(outline)

    local r, g, b, a = self:_get_color()
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(line_width)
    love.graphics.line(outline)
end

--- @brief
function rt.Cursor:_draw_can_click(x, y, scale)
    local points = {}
    local n_vertices = 16
    local radius = math.mix(_width, _height, 0.5) * 0.6
    local line_width = 0.4 * radius

    for i = 1, n_vertices + 1 do
        local angle = (i - 1) / n_vertices * 2 * math.pi
        table.insert(points, x + math.cos(angle) * radius * scale)
        table.insert(points, y + math.sin(angle) * radius * scale)
    end

    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(line_width * scale + 2)
    love.graphics.line(points)
    
    love.graphics.setColor(self:_get_color())
    love.graphics.setLineWidth(line_width * scale)
    love.graphics.line(points)
end

--- @brief
function rt.Cursor:_draw_cannot_click(x, y, scale)
    local points = {}
    local n_vertices = 16
    local radius = math.mix(_width, _height, 0.5) * 0.6
    local line_width = 0.4 * radius

    for i = 1, n_vertices + 1 do
        local angle = (i - 1) / n_vertices * 2 * math.pi
        table.insert(points, x + math.cos(angle) * radius * scale)
        table.insert(points, y + math.sin(angle) * radius * scale)
    end

    local cross = {
        x - radius + line_width, y + radius - line_width,
        x + radius - line_width, y - radius + line_width
    }

    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(line_width * scale + 2)
    love.graphics.line(points)
    love.graphics.line(cross)

    love.graphics.setColor(self:_get_color())
    love.graphics.setLineWidth(line_width * scale)
    love.graphics.line(points)

    love.graphics.setLineWidth(line_width * scale)
    love.graphics.line(cross)
end

--- @brief
function rt.Cursor:draw()
    love.graphics.push("all")
    love.graphics.reset()

    local x, y = love.mouse.getPosition()
    local scale = love.window.getDPIScale()

    if self._type == rt.CursorType.POINTER then
        self:_draw_pointer(x, y, scale)
    elseif self._type == rt.CursorType.CAN_CLICK then
        self:_draw_can_click(x, y, scale)
    elseif self._type == rt.CursorType.CANNOT_CLICK then
        self:_draw_cannot_click(x, y, scale)
    end


    love.graphics.pop()
end