require "common.shader"
require "common.mesh"
require "common.color"
require "common.palette"
require "common.interpolation_functions"
require "common.smoothed_motion_1d"

rt.settings.overworld.player_recorder_eyes = {
    blink_duration = 0.2,
    blink_time_between_min = 1.0,
    blink_time_between_max = 5.0,

    aspect_ratio = 1 / 1.35, -- width / height
    spacing_factor = 0.5, -- factor
    highlight_intensity = 0.6, -- fraction
    highlight_x_factor = 0.55,
    highlight_y_factor = 0.35,

    surprised_x_scaling_factor = 0.15,
    surprised_y_scaling_factor = 0.2,
    angry_slope = 0.35
}

ow.PlayerRecorderEyes = meta.class("PlayerRecorderEyes")

local _base_shader = rt.Shader("common/player_body_core.glsl")

local _STATE_IDLE = "idle"
local _STATE_BLINKING = "blinking"

function ow.PlayerRecorderEyes:instantiate(radius, position_x, position_y)
    self._radius = radius
    self._position_x = position_x or 0
    self._position_y = position_y or 0
    self._elapsed = 0
    self._state = _STATE_IDLE

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        local set = function(motion)
            if motion:get_target_value() == 0 then motion:set_target_value(1) else motion:set_target_value(0) end
            dbg(motion:get_target_value())
        end

        if which == "1" then
            set(self._happy)
        elseif which == "2" then
            set(self._angry)
        elseif which == "3" then
            set(self._sleepy)
        elseif which == "4" then
            set(self._surprised)
        end
    end)

    -- emotion parameters 0..1
    local speed = 1
    self._happy = rt.SmoothedMotion1D(0, speed)      -- raises bottom eyelid (smiling eyes)
    self._angry = rt.SmoothedMotion1D(0, speed)       -- slants top towards inner corner (angry eyes)
    self._sleepy = rt.SmoothedMotion1D(0, speed)      -- lowers top eyelid (squinting)
    self._surprised = rt.SmoothedMotion1D(0, speed)   -- scales eyes larger (wide eyes)

    self._blink_timer = 0

    local settings = rt.settings.overworld.player_recorder_eyes
    self._blink_duration = settings.blink_duration
    self._blink_time_between_min = settings.blink_time_between_min
    self._blink_time_between_max = settings.blink_time_between_max
    self._next_blink_time = math.mix(
        self._blink_time_between_min,
        self._blink_time_between_max,
        rt.random.number(0, 1)
    )
    self._blink_progress = 0

    self:_initialize()
end

function ow.PlayerRecorderEyes:_initialize()
    local ratio = rt.settings.overworld.player_recorder_eyes.aspect_ratio
    local spacing_factor = rt.settings.overworld.player_recorder_eyes.spacing_factor

    -- Calculate base dimensions
    local base_y_radius = ratio * self._radius
    local base_x_radius = ratio * base_y_radius
    local base_spacing = spacing_factor * self._radius

    -- Calculate total width required for both eyes
    local total_width = 2 * base_x_radius + base_spacing

    -- Scale down if needed to fit within radius
    local scale_factor = self._radius / total_width

    -- Apply scaling while maintaining ratios
    local eye_x_radius = base_x_radius * scale_factor
    local eye_y_radius = base_y_radius * scale_factor
    local spacing = base_spacing * scale_factor

    local center_x, center_y = 0, 0
    local left_x = center_x - eye_x_radius - 0.5 * spacing
    local right_x = center_x + eye_x_radius + 0.5 * spacing

    local left_y, right_y = center_y, center_y

    self._eye_center_y = center_y
    self._eye_y_radius = eye_y_radius
    self._eye_x_radius = eye_x_radius
    self._eye_spacing = spacing

    local n_vertices = 32
    self._n_vertices = n_vertices

    local easing = rt.InterpolationFunctions.GAUSSIAN_LOWPASS
    local gradient_color = function(y)
        local y_shift = 0.25
        local v = math.clamp(1.1 * easing(y - y_shift), 0, 1)
        return v, v, v, 1
    end

    local position_to_uv = function(x, y)
        local u = (x + eye_x_radius) / (2 * eye_x_radius)
        local v = (y + eye_y_radius) / (2 * eye_y_radius)
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
        local x = math.cos(angle) * eye_x_radius
        local y = math.sin(angle) * eye_y_radius

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

    self._outline_width = self._radius / 40
    self._hue = 0.2
    self._outline_color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }

    local highlight_x_radius = rt.settings.overworld.player_recorder_eyes.highlight_x_factor * eye_x_radius
    local highlight_y_radius = rt.settings.overworld.player_recorder_eyes.highlight_y_factor * eye_y_radius
    local highlight_x_offset = -0.05 * eye_x_radius
    local highlight_y_offset = -1 * (eye_y_radius - highlight_y_radius) + 0.15 * eye_y_radius

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

    self._highlight_mesh = rt.MeshCircle(0, 0, highlight_x_radius, highlight_y_radius)
    self._highlight_left_x = left_x + highlight_x_offset
    self._highlight_left_y = left_y + highlight_y_offset
    self._highlight_right_x = right_x + highlight_x_offset
    self._highlight_right_y = right_y + highlight_y_offset

    for i = 1, self._highlight_mesh:get_n_vertices() do
        if i == 1 then
            self._highlight_mesh:set_vertex_color(i, 1, 1, 1, 1)
            self._highlight_mesh:set_vertex_position(i, -0.25 * highlight_x_radius, -0.25 * highlight_y_radius)
        else
            self._highlight_mesh:set_vertex_color(i, 1, 1, 1, 0)
        end
    end

    do
        local v = 1
        self._highlight_color = { v, v, v, rt.settings.overworld.player_recorder_eyes.highlight_intensity }
    end

    -- init current outline buffers
    self._current_left_outline = { table.unpack(self._base_left_outline) }
    self._current_right_outline = { table.unpack(self._base_right_outline) }
end

-- compute eye centers based on current geom (without deformation)
function ow.PlayerRecorderEyes:_get_eye_centers()
    local left_x = -self._eye_x_radius - 0.5 * self._eye_spacing
    local right_x = self._eye_x_radius + 0.5 * self._eye_spacing
    local cy = self._eye_center_y
    return left_x, cy, right_x, cy
end

-- local deformation for a single point in local eye space (center at origin)
function ow.PlayerRecorderEyes:_deform_point(local_x, local_y, is_left)
    local xr = self._eye_x_radius
    local yr = self._eye_y_radius

    -- surprised: uniform scale out from center
    local sx = 1 + rt.settings.overworld.player_recorder_eyes.surprised_x_scaling_factor * self._surprised:get_value()
    local sy = 1 + rt.settings.overworld.player_recorder_eyes.surprised_y_scaling_factor * self._surprised:get_value()

    local x = local_x * sx
    local y = local_y * sy

    local nx = 0
    local ny = 0

    -- helper normalized coords after scale
    local x_norm = x / (xr * sx)
    local y_norm = y / (yr * sy)

    local happy = self._happy:get_value()
    local sleepy = self._sleepy:get_value()
    local angry = self._angry:get_value()

    -- happy: raise bottom eyelid, strongest at center and near bottom
    if y > 0 then
        local midness = math.max(0, 1 - (x_norm * x_norm)) -- 1 at center, 0 at horizontal extremes
        local bottomness = math.max(0, y_norm)             -- 0 at center, 1 at bottom
        local lift = happy * 0.5 * yr * midness * bottomness
        ny = ny - lift
    end

    -- sleepy: lower top eyelid, strongest at center and near top
    if y < 0 then
        local midness = math.max(0, 1 - (x_norm * x_norm))
        local topness = math.max(0, -y_norm)
        local drop = sleepy * 0.5 * yr * midness * topness
        ny = ny + drop
    end

    -- angry: slant the top towards inner corner, stronger near top
    do
        local topness = math.max(0, -y_norm) -- only affect top half
        local inner_dir = is_left and 1 or -1 -- inner side is +x for left eye, -x for right eye
        local innerness = math.max(0, x_norm * inner_dir) -- 0 on outer, 1 on inner
        local slope = angry * rt.settings.overworld.player_recorder_eyes.angry_slope * yr * innerness * topness
        ny = ny + slope
    end

    return x + nx, y + ny
end

-- recompute mesh vertex positions and outlines according to current emotions
function ow.PlayerRecorderEyes:_update_deformed_geometry()
    local left_cx, cy, right_cx, _ = self:_get_eye_centers()

    -- update left mesh + outline
    local left_outline = {}
    for i, v in ipairs(self._base_left_data) do
        local base_x, base_y = v[1], v[2]
        local lx = base_x - left_cx
        local ly = base_y - cy

        local dx, dy = self:_deform_point(lx, ly, true)
        local gx = left_cx + dx
        local gy = cy + dy

        self._base_left:set_vertex_position(i, gx, gy)

        if i > 1 then -- ring vertices for outline
            table.insert(left_outline, gx)
            table.insert(left_outline, gy)
        end
    end
    self._current_left_outline = left_outline

    -- update right mesh + outline
    local right_outline = {}
    for i, v in ipairs(self._base_right_data) do
        local base_x, base_y = v[1], v[2]
        local lx = base_x - right_cx
        local ly = base_y - cy

        local dx, dy = self:_deform_point(lx, ly, false)
        local gx = right_cx + dx
        local gy = cy + dy

        self._base_right:set_vertex_position(i, gx, gy)

        if i > 1 then
            table.insert(right_outline, gx)
            table.insert(right_outline, gy)
        end
    end
    self._current_right_outline = right_outline
end

function ow.PlayerRecorderEyes:draw()
    love.graphics.push()
    love.graphics.translate(self._position_x, self._position_y)

    -- apply current deformation before drawing
    self:_update_deformed_geometry()

    local stencil_active = self._blink_progress > 0
    local stencil_value

    if stencil_active then
        stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.push_stencil()
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW, rt.StencilReplaceMode.REPLACE)

        local visible_fraction = 1 - self._blink_progress

        -- widen/tall with surprise in stencil as well
        local s = 1 + 0.35 * self._surprised:get_value()
        local visible_height = self._eye_y_radius * s * visible_fraction

        local left_x = -self._eye_x_radius - 0.5 * self._eye_spacing
        local right_x = self._eye_x_radius + 0.5 * self._eye_spacing

        love.graphics.ellipse("fill", left_x, self._eye_center_y, self._eye_x_radius * s, visible_height)
        love.graphics.ellipse("fill", right_x, self._eye_center_y, self._eye_x_radius * s, visible_height)

        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)
    end

    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(self._outline_width + 2)
    love.graphics.line(self._current_left_outline)
    love.graphics.line(self._current_right_outline)

    love.graphics.setColor(1, 1, 1, 1)
    _base_shader:bind()

    love.graphics.setColor(self._outline_color)
    _base_shader:send("hue", self._hue)
    _base_shader:send("elapsed", self._elapsed)
    self._base_left:draw()
    _base_shader:send("elapsed", self._elapsed + math.pi * 100)
    self._base_right:draw()

    _base_shader:unbind()

    -- scale highlight position with surprise so it stays visually in place
    local s = 1 - 0.2 * (math.max(self._surprised:get_value(), self._sleepy:get_value()) or 0)
    local left_cx, cy, right_cx, _ = self:_get_eye_centers()
    local hl_lx = left_cx + (self._highlight_left_x - left_cx) * s
    local hl_ly = cy      + (self._highlight_left_y - cy) * s
    local hl_rx = right_cx + (self._highlight_right_x - right_cx) * s
    local hl_ry = cy       + (self._highlight_right_y - cy) * s

    love.graphics.setColor(self._highlight_color)
    self._highlight_mesh:draw(hl_lx, hl_ly)
    self._highlight_mesh:draw(hl_rx, hl_ry)

    love.graphics.setColor(self._outline_color)
    love.graphics.setLineWidth(self._outline_width)
    love.graphics.line(self._current_left_outline)
    love.graphics.line(self._current_right_outline)

    if stencil_active then
        rt.graphics.pop_stencil()
    end

    love.graphics.pop()
end

function ow.PlayerRecorderEyes:draw_bloom()
    love.graphics.push()
    love.graphics.translate(self._position_x, self._position_y)

    -- apply current deformation before drawing (keep bloom in sync)
    self:_update_deformed_geometry()

    local stencil_active = self._blink_progress > 0
    local stencil_value

    if stencil_active then
        stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.push_stencil()
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW, rt.StencilReplaceMode.REPLACE)

        local visible_fraction = 1 - self._blink_progress
        local s = 1 + 0.35 * self._surprised:get_value()
        local visible_height = self._eye_y_radius * s * visible_fraction

        local left_x = -self._eye_x_radius - 0.5 * self._eye_spacing
        local right_x = self._eye_x_radius + 0.5 * self._eye_spacing

        love.graphics.ellipse("fill", left_x, self._eye_center_y, self._eye_x_radius * s, visible_height)
        love.graphics.ellipse("fill", right_x, self._eye_center_y, self._eye_x_radius * s, visible_height)

        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)
    end

    love.graphics.setColor(self._outline_color)
    self._base_left:draw()
    self._base_right:draw()
    love.graphics.setLineWidth(2 * self._outline_width)
    -- love.graphics.line(self._current_left_outline)
    -- love.graphics.line(self._current_right_outline)

    if stencil_active then
        rt.graphics.pop_stencil()
    end

    love.graphics.pop()
end

function ow.PlayerRecorderEyes:update(delta)
    self._hue = self._hue + delta / 100
    self._elapsed = self._elapsed + delta
    self._outline_color = { rt.lcha_to_rgba(0.8, 1, self._hue, 1) }

    if self._state == _STATE_IDLE then
        self._blink_timer = self._blink_timer + delta

        if self._blink_timer >= self._next_blink_time then
            self._state = _STATE_BLINKING
            self._blink_timer = 0
            self._blink_progress = 0
        end
    elseif self._state == _STATE_BLINKING then
        self._blink_timer = self._blink_timer + delta

        local t = self._blink_timer / self._blink_duration

        if t >= 1 then
            self._state = _STATE_IDLE
            self._blink_timer = 0
            self._blink_progress = 0
            self._next_blink_time = math.mix(
                self._blink_time_between_min,
                self._blink_time_between_max,
                rt.random.number(0, 1)
            )
        else
            self._blink_progress = rt.InterpolationFunctions.BUTTERWORTH(t)
        end
    end

    for motion in range(
        self._sleepy,
        self._happy,
        self._angry,
        self._surprised
    ) do
        motion:update(delta)
    end
end

function ow.PlayerRecorderEyes:set_radius(radius)
    if self._radius ~= radius then
        self._radius = radius
        self:_initialize()
    end
end

function ow.PlayerRecorderEyes:set_position(position_x, position_y)
    self._position_x, self._position_y = position_x, position_y
end

function ow.PlayerRecorderEyes:get_position()
    return self._position_x, self._position_y
end

function ow.PlayerRecorderEyes:get_radius()
    return self._radius
end

function ow.PlayerRecorderEyes:get_color()
    return self._outline_color
end

-- emotion API (values clamped to [0,1])
function ow.PlayerRecorderEyes:set_happy(v)
    self._happy:set_target_value(math.clamp(v or 0, 0, 1))
end

function ow.PlayerRecorderEyes:set_angry(v)
    self._angry:set_target_value(math.clamp(v or 0, 0, 1))
end

function ow.PlayerRecorderEyes:set_sleepy(v)
    self._sleepy:set_target_value(math.clamp(v or 0, 0, 1))
end

function ow.PlayerRecorderEyes:set_surprised(v)
    self._surprised:set_target_value(math.clamp(v or 0, 0, 1))
end

-- optional batch setter
function ow.PlayerRecorderEyes:set_emotions(happy, angry, sleepy, surprised)
    if happy ~= nil then self:set_happy(happy) end
    if angry ~= nil then self:set_angry(angry) end
    if sleepy ~= nil then self:set_sleepy(sleepy) end
    if surprised ~= nil then self:set_surprised(surprised) end
end