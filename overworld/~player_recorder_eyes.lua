require "common.shader"
require "common.mesh"
require "common.color"
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

    self._look_at_x = self._position_x
    self._look_at_y = self._position_y

    self._current_look_x = 0
    self._current_look_y = 0

    self:_initialize()
end

--- @brief
function ow.PlayerRecorderEyes:_initialize()
    local radius_to_h = 0.8
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

    -- Store original eye positions for reference
    self._left_eye_center_x = left_x
    self._left_eye_center_y = left_y
    self._right_eye_center_x = right_x
    self._right_eye_center_y = right_y
end


function ow.PlayerRecorderEyes:_calculate_eye_transform(eye_side)
    -- Calculate direction from eye position to look-at point
    local dx = self._look_at_x - self._position_x
    local dy = self._look_at_y - self._position_y

    local distance = math.magnitude(dx, dy)
    if distance == 0 then
        return 0, 0, 1, 1, 0
    end

    dx, dy = math.normalize(dx, dy)

    local max_displacement = 0.5 * self._radius
    local angle_factor = math.min(1, distance / max_displacement)
    local yaw = math.atan2(dx, 1)
    local pitch = math.atan2(dy, 1)

    -- perspective scaling
    local base_scale_x = math.cos(yaw * angle_factor * 0.6)
    local base_scale_y = math.cos(pitch * angle_factor * 0.45)

    -- Factors
    local y_scale_factor = 0.95
    local scale_x = math.min(base_scale_x, 1)
    local scale_y = base_scale_y

    -- Smooth easing factor for side deformation
    local easing = rt.InterpolationFunctions.LINEAR(
        math.abs((self._look_at_x - self._position_x) / max_displacement)
    )
    easing = math.clamp(easing, 0, 1)

    -- Vertical squash/stretch
    local y_delta = easing * scale_x * (1 - y_scale_factor)

    if eye_side == "left" then
        scale_x = 1 + (1 - base_scale_x) * math.sign(dx)
        if dx < 0 then
            scale_y = scale_y - y_delta
        end
    elseif eye_side == "right" then
        scale_x = 1 - (1 - base_scale_x) * math.sign(dx)
        if dx > 0 then
            scale_y = scale_y - y_delta
        end
    end

    local translate_x = math.sin(yaw * angle_factor) * max_displacement
    local translate_y = math.sin(pitch * angle_factor) * max_displacement

    local shear_strength = 0.25

    local shear_x = 0
    local shear_y = 0

    if eye_side == "left" then
        shear_y = shear_strength * dy
    elseif eye_side == "right" then
        shear_x = shear_strength * dy
    end

    return translate_x, translate_y, scale_x, scale_y, shear_x, shear_y
end


--- @brief
function ow.PlayerRecorderEyes:_calculate_highlight_transform()
    local dx = self._look_at_x - self._position_x
    local dy = self._look_at_y - self._position_y

    local nx = math.clamp(dx / self._radius, -1, 1)
    local ny = math.clamp(dy / self._radius, -1, 1)

    local tx = math.min(nx, 0) * (self._radius * 0.15)
    local ty = 0

    local sx = 1.0
    local sy = 1.0 - ternary(ny > 0, ny * 0.2, ny * 0.2)

    return tx, ty, sx, sy
end

--- @brief
--- @brief
function ow.PlayerRecorderEyes:draw()
    love.graphics.push()
    love.graphics.translate(self._position_x, self._position_y)

    -- Smooth the movement for more realistic eye motion
    local tx, ty = self:_calculate_eye_transform("center") -- just for motion smoothing
    self._current_look_x = self._current_look_x + (tx - self._current_look_x)
    self._current_look_y = self._current_look_y + (ty - self._current_look_y)

    -- Background circle (eye socket)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.circle("fill", 0, 0, 1.5 * self._radius)

    -- Local helper to draw one eye
    local function draw_eye(side)
        local etx, ety, esx, esy, eshear_x, eshear_y = self:_calculate_eye_transform(side)

        love.graphics.push()
        love.graphics.translate(self._current_look_x + etx, self._current_look_y + ety)
        love.graphics.scale(esx, esy)
        love.graphics.shear(eshear_x, eshear_y)

        -- Draw eye outline (thick black border behind)
        rt.Palette.BLACK:bind()
        love.graphics.setLineWidth(self._outline_width + 2)
        if side == "left" then
            love.graphics.line(self._base_left_outline)
        else
            love.graphics.line(self._base_right_outline)
        end

        -- Draw eye base (white with shader)
        love.graphics.setColor(1, 1, 1, 1)
        --_base_shader:bind()
        love.graphics.setColor(self._outline_color)
        _base_shader:send("hue", self._hue)
        _base_shader:send("elapsed", rt.SceneManager:get_elapsed())
        if side == "left" then
            self._base_left:draw()
        else
            self._base_right:draw()
        end
        _base_shader:unbind()

        -- Adjust highlight opacity based on viewing angle (dimmer when looking away)
        local highlight_alpha = self._highlight_color[4] * (0.7 + 0.3 * esx)
        love.graphics.setColor(self._highlight_color[1], self._highlight_color[2],
            self._highlight_color[3], highlight_alpha)

        -- Highlight transform
        local htx, hty, hsx, hsy = self:_calculate_highlight_transform()

        love.graphics.push()
        if side == "left" then
            love.graphics.translate(self._left_highlight[1] + htx, self._left_highlight[2] + hty)
            love.graphics.scale(hsx, hsy)
            love.graphics.ellipse("fill", 0, 0,
                self._left_highlight[3], self._left_highlight[4], self._left_highlight[5])
        else
            love.graphics.translate(self._right_highlight[1] + htx, self._right_highlight[2] + hty)
            love.graphics.scale(hsx, hsy)
            love.graphics.ellipse("fill", 0, 0,
                self._right_highlight[3], self._right_highlight[4], self._right_highlight[5])
        end
        love.graphics.pop()

        -- Final colored outline
        love.graphics.setColor(self._outline_color)
        love.graphics.setLineWidth(self._outline_width)
        if side == "left" then
            love.graphics.line(self._base_left_outline)
        else
            love.graphics.line(self._base_right_outline)
        end

        love.graphics.pop()
    end

    -- Draw both eyes
    draw_eye("left")
    draw_eye("right")

    love.graphics.pop()
end


--- @brief
function ow.PlayerRecorderEyes:update(delta)
    -- Smooth eye movement happens in draw function for frame-perfect animation
    self._hue = self._hue + delta / 10
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

--- @brief
--- @param px Number
--- @param py Number
function ow.PlayerRecorderEyes:look_at(px, py)
    self._look_at_x, self._look_at_y = px, py  -- Fixed: was incorrectly using py twice
end