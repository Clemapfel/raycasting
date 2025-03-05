require "common.input_subscriber"

--- @class ow.Camera
ow.Camera = meta.class("Camera")

--- @brief
function ow.Camera:instantiate()
    meta.install(self, {
        _scale = 1,
        _offset_x = 0,
        _offset_y = 0,
        _angle = 0,
        _input = rt.InputSubscriber()
    })

    -- TODO
    self._mouse_active = true
    self._input:signal_connect(rt.InputCallbackID.MOUSE_LEFT_SCREEN, function(_)
        self._mouse_active = false
    end)

    self._input:signal_connect(rt.InputCallbackID.MOUSE_ENTERED_SCREEN, function(_)
        self._mouse_active = true
    end)

    self._input:signal_connect(rt.InputCallbackID.INPUT_BUTTON_PRESSED, function(_, which)
        if which == rt.InputButton.B then
            self:reset()
        end
    end)
end

--- @brief
function ow.Camera:bind()
    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(self._scale, self._scale)
    love.graphics.translate(-0.5 * w, -0.5 * h)
    love.graphics.translate(self._offset_x, self._offset_y)

    local camera_origin_x, camera_origin_y = self._offset_x + 0.5 * w, self._offset_y + 0.5 * h
    love.graphics.translate(camera_origin_x, camera_origin_y)
    love.graphics.rotate(self._angle)
    love.graphics.translate(-camera_origin_x, -camera_origin_y)
end

--- @brief
function ow.Camera:unbind()
    love.graphics.pop()
end

--- @brief
function ow.Camera:update(delta)
    local scroll_margin_factor = 0.1
    local scroll_speed = 300
    local angle_speed = 2 * math.pi / 10
    local scale_speed = 1

    if self._mouse_active then
        local x, y = love.mouse.getPosition()
        local w, h = love.graphics.getDimensions()

        local left_x = scroll_margin_factor * w
        local right_x = (1 - scroll_margin_factor) * w
        local x_width = scroll_margin_factor * w
        if x < left_x then
            self._offset_x = self._offset_x + math.abs(x - left_x) / x_width * scroll_speed * delta
        elseif x > right_x then
            self._offset_x = self._offset_x - math.abs(x - right_x) / x_width * scroll_speed * delta
        end

        local up_y = scroll_margin_factor * h
        local down_y = (1 - scroll_margin_factor) * h
        local y_width = scroll_margin_factor * h
        if y < up_y then
            self._offset_y = self._offset_y + math.abs(y - up_y) / y_width * scroll_speed * delta
        elseif y > down_y then
            self._offset_y = self._offset_y - math.abs(y - down_y) / y_width * scroll_speed * delta
        end
    end

    if love.keyboard.isDown("x") then
        self._scale = self._scale + scale_speed * delta
    elseif love.keyboard.isDown("y") then
        self._scale = self._scale - scale_speed * delta
    end

    if love.keyboard.isDown("m") then
        self._angle = self._angle + angle_speed * delta
    elseif love.keyboard.isDown("n") then
        self._angle = self._angle - angle_speed * delta
    end

    local step = scroll_speed * delta
    if love.keyboard.isDown("up") then
        self._offset_y = self._offset_y - step
    elseif love.keyboard.isDown("right") then
        self._offset_x = self._offset_x - step
    elseif love.keyboard.isDown("down") then
        self._offset_y = self._offset_y + step
    elseif love.keyboard.isDown("left") then
        self._offset_x = self._offset_x + step
    end
end

--- @brief
function ow.Camera:reset()
    self._scale = 1
    self._offset_x = 0
    self._offset_y = 0
    self._angle = 0
end