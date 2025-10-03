require "common.shader"
require "common.mesh"
require "common.color"
require "common.palette"
require "common.interpolation_functions"

rt.settings.overworld.player_recorder_eyes = {
    aspect_ratio = 1 / 1.5 -- width to height
}

--- @class ow.PlayerRecordEyes
ow.PlayerRecorderEyes = meta.class("PlayerRecorderEyes")

local _base_shader = rt.Shader("common/player_body_core.glsl")

--- @brief
function ow.PlayerRecorderEyes:instantiate(radius, position_x, position_y)
    self._radius = radius
    self._position_x = position_x or 0
    self._position_y = position_y or 0
    self._elapsed = 0
    self:_initialize()
end

--- @brief
function ow.PlayerRecorderEyes:_initialize()
    local radius_to_h = 0.6
    local radius_to_spacing = 0.6

    local ratio = rt.settings.overworld.player_recorder_eyes.aspect_ratio
    local base_y_radius = radius_to_h * self._radius
    local base_x_radius = ratio * base_y_radius

    local center_x, center_y = 0, 0
    local spacing = radius_to_spacing * self._radius
    local left_x = center_x - base_x_radius - 0.5 * spacing
    local right_x = center_x + base_x_radius + 0.5 * spacing

    local left_y, right_y = center_y, center_y

    -- meshes

    local n_vertices = 32
    local easing = rt.InterpolationFunctions.GAUSSIAN_LOWPASS
    local gradient_color = function(y)
        local y_shift = 0.25
        local v = math.clamp(1.1 * easing(y - y_shift), 0, 1)
        return v, v, v, 1
    end

    local position_to_uv = function(x, y)
        local u = (x + base_x_radius) / (2 * base_x_radius)
        local v = (y + base_y_radius) / (2 * base_y_radius)
        return u, v
    end

    do
        local x = 0
        local y = 0
        local u, v = position_to_uv(x, y)

        self._base_left_data = {
            { left_x + x, left_y + y, u, v, gradient_color(0.5) }
        }
        self._base_right_data = {
            { right_x + x, right_y + y, u, v, gradient_color(0.5) }
        }
    end

    self._base_left_outline = {}
    self._base_right_outline = {}

    for i = 1, n_vertices + 1 do
        local angle = (i - 1) / n_vertices * 2 * math.pi
        local x = math.cos(angle) * base_x_radius
        local y = math.sin(angle) * base_y_radius

        local u, v = position_to_uv(x, y)

        local gradient_v = (math.sin(angle) + 1) / 2

        table.insert(self._base_left_data, {
            left_x + x, left_y + y, u, v, gradient_color(gradient_v)
        })

        table.insert(self._base_right_data, {
            right_x + x, right_y + y, u, v, gradient_color(gradient_v)
        })

        table.insert(self._base_left_outline, left_x + x)
        table.insert(self._base_left_outline, left_y + y)
        table.insert(self._base_right_outline, right_x + x)
        table.insert(self._base_right_outline, right_y + y)
    end

    self._base_left = rt.Mesh(self._base_left_data)
    self._base_right = rt.Mesh(self._base_right_data)

    self._outline_width = self._radius / 50
    self._hue = 0.2
    self._outline_color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }

    local highlight_x_radius = 0.45 * base_x_radius
    local highlight_y_radius = 0.3 * base_y_radius
    local highlight_x_offset = 0 * base_x_radius
    local highlight_y_offset = -1 * (base_y_radius - highlight_y_radius - self._outline_width * 4)

    self._left_highlight = {
        left_x + highlight_x_offset,
        left_y + highlight_y_offset,
        highlight_x_radius,
        highlight_y_radius,
        n_vertices
    }

    self._right_highlight = {
        right_x + highlight_x_offset,
        right_y + highlight_y_offset,
        highlight_x_radius,
        highlight_y_radius,
        n_vertices
    }

    do
        local v = 1
        self._highlight_color = { v, v, v, 0.6 }
    end
end

function ow.PlayerRecorderEyes:draw()
    love.graphics.push()
    love.graphics.translate(self._position_x, self._position_y)

    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(self._outline_width + 2)
    love.graphics.line(self._base_left_outline)
    love.graphics.line(self._base_right_outline)

    love.graphics.setColor(1, 1, 1, 1)
    _base_shader:bind()

    love.graphics.setColor(self._outline_color)
    _base_shader:send("hue", self._hue)
    _base_shader:send("elapsed", self._elapsed)
    self._base_left:draw()
    _base_shader:send("elapsed", self._elapsed + math.pi * 100)
    self._base_right:draw()

    _base_shader:unbind()

    love.graphics.setColor(self._highlight_color)
    love.graphics.ellipse("fill", table.unpack(self._left_highlight))
    love.graphics.ellipse("fill", table.unpack(self._right_highlight))

    love.graphics.setColor(self._outline_color)
    love.graphics.setLineWidth(self._outline_width)
    love.graphics.line(self._base_left_outline)
    love.graphics.line(self._base_right_outline)

    love.graphics.pop()
end

--- @brief
function ow.PlayerRecorderEyes:update(delta)
    self._hue = self._hue + delta / 100
    self._elapsed = self._elapsed + delta
    self._outline_color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }
end

--- @brief
function ow.PlayerRecorderEyes:set_radius(radius)
    if self._radius ~= radius then
        self._radius = radius
        self:_initialize()
    end
end

--- @brief
function ow.PlayerRecorderEyes:set_position(position_x, position_y)
    self._position_x, self._position_y = position_x, position_y
end

--- @brief
function ow.PlayerRecorderEyes:get_position()
    return self._position_x, self._position_y
end