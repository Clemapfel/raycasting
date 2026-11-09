graphics_get_size = function()
    return 800, 800
end

graphics_get_window_size = function()
    return love.graphics.getPixelDimensions()
end

graphics_get_window_width = function()
    return love.graphics.getWidth()
end

graphics_get_window_height = function()
    return love.graphics.getHeight()
end

graphics_get_aspect_ratio = function()
    local a, b = graphics_get_size()
    return a  / b
end

graphics_get_width = function()
    return select(1, graphics_get_size())
end

graphics_get_height = function()
    return select(2, graphics_get_size())
end

graphics_get_dpi_scale = love.graphics.getDPIScale

graphics_set_line_state = function(width, style)
    if style == nil then style = "smooth" end
    love.graphics.setLineWidth(width)
    love.graphics.setLineStyle("smooth")
end

graphics_set_color = function(r_or_rgba, g, b, a)
    if object_isa(r_or_rgba, RGBA_t) then
        rgba_bind(r_or_rgba)
    else
        if r_or_rgba == nil then r_or_rgba = 1 end
        if g == nil then g = 1 end
        if b == nil then b = 1 end
        if a == nil then a = 1 end
        love.graphics.setColor(r_or_rgba, g, b, a)
    end
end

graphics_get_color = function()
    return rgba_new(love.graphics.getColor())
end

graphics_clear = love.graphics.clear

graphics_set_render_texture = love.graphics.setCanvas

graphics_draw_line = function(...)
    love.graphics.line(...)
end

graphics_draw_rectangle = function(x, y, w, h, ...)
    love.graphics.rectangle("fill", x, y, w, h, ...)
end

graphics_draw_rectangle_outline = function(x, y, w, h)
    graphics_draw_line(
        x, y,
        x + w, y,
        x + w, y + h,
        x, y + h,
        x, y
    )
end

graphics_draw_ellipse = function(x, y, x_radius, y_radius)
    if y_radius == nil then y_radius = x_radius end
    love.graphics.ellipse("fill", x, y, x_radius, y_radius)
end

do
    local function _radius_to_n_vertices(rx, ry)
        -- cf. https://github.com/love2d/love/blob/5670df13b6980afd025cd7e7d442a24499bf86a7/src/modules/graphics/Graphics.cpp#L2419C1-L2423C2
        if ry == nil then ry = rx end
        return math.max(8, math.floor(math.sqrt(((rx + ry) / 2) * 20.0)))
    end

    graphics_draw_ellipse_outline = function(x, y, x_radius, y_radius)
        if y_radius == nil then y_radius = x_radius end
        local n_vertices = _radius_to_n_vertices(x_radius, y_radius)
        local vertices = {}
        for i = 1, n_vertices + 1 do
            local angle = (i - 1) / n_vertices * math_tau
            table_push(vertices, x + math_cos(angle) * x_radius)
            table_push(vertices, y + math_sin(angle) * y_radius)
        end

        graphics_draw_line(vertices)
    end
end

graphics_push_state = function()
    love.graphics.push("all")
end

graphics_pop_state = function()
    love.graphics.pop()
end

graphics_push_transform = function()
    love.graphics.push()
end

graphics_pop_transform = function()
    love.graphics.pop()
end

graphics_reset_state = love.graphics.reset
graphics_reset_transform = love.graphics.origin
graphics_set_translation = love.graphics.translate
graphics_set_scale = function(x, y)
    love.graphics.scale(x, y or x)
end

local _frame_index = 1
graphics_notify_end_of_frame = function()
    _frame_index = _frame_index + 1
end

graphics_notify_start_of_frame = function()
    -- noop
end

graphics_get_frame_index = function()
    return _frame_index
end