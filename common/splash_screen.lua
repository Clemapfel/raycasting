-- display splash screen while loading
if love.graphics then
    local screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 1)
    local label = "loading..."
    local font = love.graphics.newFont(0.15 * love.graphics.getHeight())
    local label_w, label_h = font:getWidth(label), font:getHeight(label)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)

    local value = 0.3
    love.graphics.setColor(value, value, value, 1)
    love.graphics.print(label, font,
        math.floor(0.5 * screen_w - 0.5 * label_w),
        math.floor(0.5 * screen_h - 0.5 * label_h)
    )
    love.graphics.present()
end
