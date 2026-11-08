graphics_get_size = function()
    return 800, 800
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

graphics_set_color = function(r, g, b, a)
    if r == nil then r = 1 end
    if g == nil then g = 1 end
    if b == nil then b = 1 end
    if a == nil then a = 1 end
    love.graphics.setColor(r, g, b, a)
end

graphics_draw_mesh = love.graphics.draw
graphics_draw_texture = love.graphics.draw

graphics_clear = love.graphics.clear

graphics_set_render_texture = love.graphics.setCanvas

graphics_draw_line = function(...)
    love.graphics.line(...)
end

graphics_draw_rectangle = function(x, y, w, h, ...)
    love.graphics.rectangle("fill", x, y, w, h, ...)
end

graphics_push_state = function()
    love.graphics.push("all")
end

graphics_pop_state = function()
    love.graphics.pop()
end

graphics_reset_state = love.graphics.reset
graphics_reset_transform = love.graphics.origin
graphics_set_translation = love.graphics.translate
graphics_set_scale = function(x, y)
    love.graphics.scale(x, y or x)
end