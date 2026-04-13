-- display splash screen while loading
return function(text)
    if love.graphics then
        local screen_width, screen_height = love.graphics.getWidth(), love.graphics.getHeight()

        local font_size = math.ceil(0.15 * love.graphics.getHeight())
        local font

        repeat
            font = love.graphics.newFont(font_size)
            font_size = font_size - 1
            if font_size < 12 then break end
        until font:getWidth(text) < screen_width and font:getHeight() < screen_height

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, screen_width, screen_height)

        local value = 0.3
        love.graphics.setColor(value, value, value, 1)
        love.graphics.print(text, font,
            math.floor(0.5 * screen_width - 0.5 * font:getWidth(text)),
            math.floor(0.5 * screen_height - 0.5 * font:getHeight())
        )
        love.graphics.present()
    end
end
