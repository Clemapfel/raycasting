require "include"
require "common.shader"

local noba = noba or {}
function noba.RoarFX()
    local self = {}
    self._canvas = nil
    self._elapsed = 10e6
    self._shader = rt.Shader("noba_roar.glsl")

    self._duration = 5 -- seconds
    self._ramp_fraction = 0.8 -- [0, 1] how much of the duration is spend during fade-in/out, where 1 = no plateau, 0 = all plateau
    self._max_saturation_loss = 1.0 -- how much saturation is reduced by, where 1 fully monochrome, 0 no change
    self._max_vignette = 0.75 -- [0, 1] how much of the screen is covered up by the vignette, with 1 all black, 0 no vignette

    local function gaussian(x, center)
        return math.exp(-4.4 * math.pi / 3 * ((x - center)^2))
    end

    --- @brief [internal] piece-wise continuous function with gaussian fade in and fade out
    function self._envelope(fraction)
        if fraction > 1 then return 0 end

        local ramp_fraction = self._ramp_fraction / 2a
        local lower, upper = ramp_fraction, 1 - ramp_fraction
        if fraction < lower then -- attack
            return gaussian(fraction / ramp_fraction, 1)
        elseif fraction > upper then -- decay
            return gaussian((fraction - upper) / ramp_fraction, 0)
        else -- sustain
            return 1
        end
    end

    --- @brief
    function self:set_canvas(canvas)
        self._canvas = canvas
    end

    --- @brief
    function self:set_duration(seconds)
        self._duration = seconds
    end

    --- @brief
    function self:set_vignette_strength(fraction)
        self._max_vignette = math.max(0, math.min(fraction, 1))
    end

    --- @brief
    function self:set_saturation_loss_strength(fraction)
        self._max_saturation_loss = math.max(0, math.min(fraction, 1))
    end

    --- @brief
    function self:update(delta)
        self._elapsed = self._elapsed + delta
        self._fraction = self._envelope(self._elapsed / self._duration)
    end

    --- @brief
    function self:draw(...)
        local shader = self._shader:get_native()
        love.graphics.setShader(shader)
        self._shader:send("saturation_fraction", self._fraction * self._max_saturation_loss)
        self._shader:send("vignette_fraction", self._fraction * self._max_vignette)
        self._shader:send("ripple_fraction", self._fraction)
        self._shader:send("elapsed", self._elapsed)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self._canvas, ...)
        love.graphics.setShader(nil)
    end

    --- @brief (re)start the roar animation
    function self:roar()
        self._elapsed = 0
    end

    return self
end

-- ### main

local roar, canvas

love.keypressed = function(key)
    if key == "space" then
        roar._shader:recompile()
        roar:roar()
    end
end

love.load = function()
    roar = noba.RoarFX()
    canvas = love.graphics.newCanvas(love.graphics.getDimensions())
    roar:set_canvas(canvas)

    _initialize_debug_drawing()
end

love.update = function(delta)
    roar:update(delta)

    _update_debug_drawing(delta)
end

love.draw = function()
    love.graphics.setCanvas(canvas)
    love.graphics.clear()

    _debug_draw()

    love.graphics.setCanvas(nil)
    roar:draw()
end

--- ### debug drawing

local circles, n_circles = {}, 128
local center_x, center_y, x_radius, y_radius
local circles_elapsed = 0

_initialize_debug_drawing = function()
    function hsva_to_rgba(h, s, v, a)
        h = h * 360

        local c = v * s
        local h_2 = h / 60.0
        local x = c * (1 - math.abs(math.fmod(h_2, 2) - 1))

        local r, g, b

        if (0 <= h_2 and h_2 < 1) then
            r, g, b = c, x, 0
        elseif (1 <= h_2 and h_2 < 2) then
            r, g, b  = x, c, 0
        elseif (2 <= h_2 and h_2 < 3) then
            r, g, b  = 0, c, x
        elseif (3 <= h_2 and h_2 < 4) then
            r, g, b  = 0, x, c
        elseif (4 <= h_2 and h_2 < 5) then
            r, g, b  = x, 0, c
        else
            r, g, b  = c, 0, x
        end

        local m = v - c

        r = r + m
        g = g + m
        b = b + m

        return r, g, b, a
    end

    local radius, padding = 60, 20

    x_radius, y_radius = love.graphics.getDimensions()
    center_x, center_y = x_radius / 2, y_radius / 2

    x_radius = x_radius / 2 - 2 * radius - padding
    y_radius = y_radius / 2 - 2 * radius - padding

    circles = {}
    local i = 0
    for angle = 0, 2 * math.pi, 2 * math.pi / n_circles do
        table.insert(circles, {
            x = center_x + math.cos(angle) * x_radius,
            y = center_y + math.sin(angle) * y_radius,
            angle = angle,
            radius = radius,
            color = { hsva_to_rgba(i / (n_circles + 1), 1, 1, 1) },
            value = 1,
            undulated_radius = radius,
        })
        i = i + 1
    end
    if table.unpack == nil then table.unpack = unpack end
end

_update_debug_drawing = function(delta)
    local frequency = 0.5
    local radius_amplitude = 10
    local position_amplitude = 15

    circles_elapsed = circles_elapsed + delta
    for i, entry in ipairs(circles) do
        -- phase offset wraps exactly once around the circle
        local phase_offset = (i - 1) / n_circles * 2 * math.pi

        local radius_phase = math.sin(2 * math.pi * frequency * circles_elapsed + phase_offset)
        entry.undulated_radius = entry.radius + radius_amplitude * radius_phase

        local value_phase = math.sin(2 * math.pi * math.sqrt(2) * frequency * circles_elapsed + phase_offset)
        entry.value = (value_phase + 1) / 2 * 0.3 + (1 - 0.3)

        local position_phase = math.sin(2 * math.pi * 2 * frequency * circles_elapsed + phase_offset)
        local position_offset = 2 * position_amplitude * position_phase - position_amplitude

        local angle = math.fmod(entry.angle + circles_elapsed, 2 * math.pi)
        entry.x = center_x + math.cos(angle) * (x_radius + position_offset)
        entry.y = center_y + math.sin(angle) * (y_radius + position_offset)
    end
end

local n_lines = 16

_debug_draw = function()
    love.graphics.push()
    local width, height = love.graphics.getDimensions()
    local gray_a, gray_b = 0.3, 0.8
    love.graphics.setColor(gray_a, gray_a, gray_a, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)

    love.graphics.translate(0.5 * width, 0.5 * height)
    love.graphics.rotate((2 * math.pi) / 8)
    love.graphics.translate(-0.5 * width, -0.5 * height)
    local line_width = love.graphics.getWidth() / (n_lines * 2)

    love.graphics.setColor(gray_b, gray_b, gray_b, 1)
    love.graphics.setColor(gray_b, gray_b, gray_b, 1)
    love.graphics.setLineWidth(line_width)

    local spacing = line_width * 2
    local offset = math.fmod(circles_elapsed * 100, spacing)
    local start_x = -2 * spacing + offset
    for x = start_x, width + 2 * spacing, spacing do
        love.graphics.line(x, -height, x, 2 * height)
    end

    local draw_circle = function(i)
        local circle = circles[i]
        local r, g, b, a = table.unpack(circle.color)
        love.graphics.setColor(r * circle.value, g * circle.value, b * circle.value, a)
        love.graphics.circle("fill", circle.x, circle.y, circle.undulated_radius or circle.radius)
    end
    love.graphics.pop()

    local n = n_circles
    for i = 1, n, 2 do
        draw_circle(i)
    end
end
