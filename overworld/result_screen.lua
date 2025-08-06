require "common.timed_animation_sequence"
require "menu.stage_grade_label"
require "common.translation"
require "common.label"

rt.settings.overworld.result_screen = {
    flow_step = 1 / 100, -- fraction
    time_step = 1, -- seconds
    coins_step = 1, -- count
}

--- @class ow.ResultScreen
ow.ResultsScreen = meta.class("ResultScreen", rt.Widget)

local _frame_shader, _mask_shader, _grade_shader

--- @param t Number [0, n-1]
--- @param ... rt.AABB n aabbs
local _lerp_aabbs = function(t, frames)
    local n = #frames
    t = math.clamp(t, 1, n)

    local segment = math.floor(t)
    local local_t = t - segment

    local aabb1 = frames[math.min(segment + 0, n)]
    local aabb2 = frames[math.min(segment + 1, n)]

    local x = math.mix(aabb1.x, aabb2.x, local_t)
    local y = math.mix(aabb1.y, aabb2.y, local_t)
    local width = math.mix(aabb1.width, aabb2.width, local_t)
    local height = math.mix(aabb1.height, aabb2.height, local_t)

    return x, y, width, height
end

local _mix_step = function(lower, upper, fraction, step_size)
    local interpolated = math.mix(lower, upper, fraction)
    return math.ceil(interpolated / step_size) * step_size
end

local _format_flow = function(fraction, start, target)
    local step = rt.settings.overworld.result_screen.flow_step
    local value = math.clamp(
        _mix_step(start, target, fraction, step),
        math.min(start, target),
        math.max(start, target)
    )
    return string.format_percentage(value)
end

local _format_time = function(fraction, start, target)
    local step = rt.settings.overworld.result_screen.time_step
    local value = math.clamp(
        _mix_step(start, target, fraction, step),
        math.min(start, target),
        math.max(start, target)
    )

    return string.format_time(value)
end

local _format_coins = function(fraction, start, target, max)
    local step = rt.settings.overworld.result_screen.coins_step
    local value = math.clamp(
        _mix_step(start, target, fraction, step),
        math.min(start, target),
        math.max(start, target)
    )

    return math.round(value) .. " / " .. math.round(max)
end

local _title_font = rt.Font(
    "assets/fonts/Baloo2/Baloo2-SemiBold.ttf",
    "assets/fonts/Baloo2/Baloo2-Bold.ttf"
)

local _title_prefix, _title_postfix = "<b><o><u>", "</b></o></u>"

--- @brief
function ow.ResultsScreen:instantiate()
    if _frame_shader == nil then
        _frame_shader = rt.Shader("overworld/result_screen_frame.glsl", { MODE = 0 })
        _frame_shader:send("black", { rt.Palette.GRAY:unpack() })
    end

    if _mask_shader == nil then
        _mask_shader = rt.Shader("overworld/result_screen_frame.glsl", { MODE = 1 })
    end

    if _grade_shader == nil then
        _grade_shader = rt.Shader("overworld/result_screen_grade.glsl", { MODE = 0 })
    end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "j" then self:_reset() end
    end)

    -- state

    self._title = "NO TITLE"
    self._flow_target = 0
    self._flow_start = 0

    self._time_target = 0 -- seconds
    self._time_start = 0

    self._coins_target = 0 -- integer
    self._coins_start = 0
    self._coins_max = 0

    self._flow_grade = rt.StageGrade.NONE
    self._time_grade = rt.StageGrade.NONE
    self._coins_grade = rt.StageGrade.NONE
    self._total_grade = rt.StageGrade.NONE

    -- widgets

    local translation, settings = rt.Translation.result_screen, rt.settings.overworld.result_screen
    self._title_label = rt.Label(_title_prefix .. self._title .. _title_postfix, rt.FontSize.LARGER, _title_font)

    local prefix, postfix = "<b><o>", "</b></o>"
    self._flow_prefix_label = rt.Label(prefix .. translation.flow .. postfix)
    self._time_prefix_label = rt.Label(prefix .. translation.time .. postfix)
    self._coins_prefix_label = rt.Label(prefix .. translation.coins .. postfix)
    self._total_prefix_label = rt.Label(prefix .. translation.total .. postfix)

    local glyph_properties = {
        font_size = rt.FontSize.REGULAR,
        justify_mode = rt.JustifyMode.CENTER,
        style = rt.FontStyle.BOLD,
        is_outlined = true,
        font = _title_font
    }

    self._time_value_label = rt.Glyph(_format_time(0, 0, self._time_start), glyph_properties)
    self._flow_value_label = rt.Glyph(_format_flow(0, 0, self._flow_start), glyph_properties)
    self._coins_value_label = rt.Glyph(_format_coins(0, 0, self._coins_start, 0), glyph_properties)

    self._flow_grade_label = mn.StageGradeLabel(self._flow_grade, rt.FontSize.HUGE)
    self._time_grade_label = mn.StageGradeLabel(self._time_grade, rt.FontSize.HUGE)
    self._coins_grade_label = mn.StageGradeLabel(self._coins_grade, rt.FontSize.HUGE)
    self._total_grade_label = mn.StageGradeLabel(self._total_grade, rt.FontSize.GIGANTIC)

    -- animation

    self._sequence = rt.TimedAnimationSequence(
        rt.TimedAnimation( -- upwards
            1,    -- duration
            1, 2, -- aabb lerp t
            rt.InterpolationFunctions.SINUSOID_EASE_OUT
        ),

        rt.TimedAnimation(
            1,
            2, 3,
            rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT
        ),

        rt.TimedAnimation(
            1,
            3, 4,
            rt.InterpolationFunctions.LINEAR
        )
    )

    self._frames = {} -- List<rt.AABB>
    self._grade_frame_animation = rt.TimedAnimation(
        1,
        0, 1,
        rt.InterpolationFunctions.LINEAR
    )

    self._particle_canvas = nil
    self._particle_texture = nil
    self._particle_canvas_x, self._particle_canvas_y = 0, 0
    self._particles = {}
end

--- @brief
function ow.ResultsScreen:realize()
    for widget in range(
        self._title_label,
        self._flow_prefix_label,
        self._time_prefix_label,
        self._coins_prefix_label,
        self._flow_value_label,
        self._time_value_label,
        self._coins_value_label,
        self._flow_grade_label,
        self._time_grade_label,
        self._coins_grade_label,
        self._total_grade_label
    ) do
        widget:realize()
    end
end

--- @brief
function ow.ResultsScreen:update(delta)
    if self._sequence:get_animation_index() < 3 then
        self._sequence:update(delta)
    end

    if self._sequence:get_animation_index() > 1 then
        self._grade_frame_animation:update(delta)
    end

    local t = self._sequence:get_value()
    local x, y, w, h = _lerp_aabbs(t, self._frames)
    self._dbg = rt.AABB(x, y, w, h)

    local m = self._frame_mesh_m
    self:_update_frame_mesh(x, y, w, h, m)

    -- particles
    -- Replace the particle update section in the update method (around line 200-210)

    -- Replace the particle update section in the update method (around line 200-210)

    -- particles
    local circle_x = self._particle_canvas_x + 0.5 * self._particle_canvas:get_width()
    local circle_y = self._particle_canvas_y + 0.5 * self._particle_canvas:get_height()
    local circle_r = 0.5 * math.max(self._particle_canvas:get_size())
    local particle_r = 0.5 * math.max(self._particle_texture:get_size())

    local particle_speed = 50 * rt.get_pixel_scale() -- constant speed in pixels per second
    local noise_strength = 0.05 -- how much the noise affects movement
    local noise_frequency = 0.01 -- how fast the noise changes over time

    for particle in values(self._particles) do
        local cx, cy, r = particle.x, particle.y, particle.scale * particle_r
        local vx, vy = particle.velocity_x, particle.velocity_y

        -- normalize velocity to unit vector
        local velocity_magnitude = math.sqrt(vx * vx + vy * vy)
        if velocity_magnitude > 0 then
            vx = vx / velocity_magnitude
            vy = vy / velocity_magnitude
        end

        -- add noise perturbation to velocity
        local time_offset = rt.SceneManager:get_elapsed() * noise_frequency
        local noise_x = (rt.random.noise(cx * 0.01 + time_offset, cy * 0.01) * 2) - 1
        local noise_y = (rt.random.noise(cx * 0.01 + time_offset + 100, cy * 0.01 + 100) * 2) - 1 -- offset to get different noise

        -- apply noise as perpendicular force to current velocity
        local perp_x = -vy -- perpendicular to velocity
        local perp_y = vx

        --vx = vx + noise_x * noise_strength * perp_x
        --vy = vy + noise_y * noise_strength * perp_y

        -- renormalize to maintain constant speed
        local new_magnitude = math.sqrt(vx * vx + vy * vy)
        if new_magnitude > 0 then
            vx = vx / new_magnitude
            vy = vy / new_magnitude
        end

        -- move particle at constant speed
        local new_x = cx + vx * particle_speed * particle.velocity_magnitude * delta
        local new_y = cy + vy * particle_speed * particle.velocity_magnitude * delta

        -- check collision with circular boundary
        local center_x = 0.5 * self._particle_canvas:get_width()
        local center_y = 0.5 * self._particle_canvas:get_height()
        local boundary_radius = 0.5 * math.min(self._particle_canvas:get_width(), self._particle_canvas:get_height()) - 10 -- padding

        -- distance from particle center to circle center
        local dx = new_x - center_x
        local dy = new_y - center_y
        local distance_to_center = math.sqrt(dx * dx + dy * dy)

        -- check if particle (with its radius) would collide with boundary
        if distance_to_center + r >= boundary_radius then
            -- collision detected, reflect velocity using normal

            -- calculate normal vector (from circle center to particle center)
            local normal_x = dx / distance_to_center
            local normal_y = dy / distance_to_center

            -- reflect velocity: v' = v - 2(v·n)n
            local dot_product = vx * normal_x + vy * normal_y
            particle.velocity_x = vx - 2 * dot_product * normal_x
            particle.velocity_y = vy - 2 * dot_product * normal_y

            -- position particle exactly at boundary to prevent overlap
            local corrected_distance = boundary_radius - r
            particle.x = center_x + normal_x * corrected_distance
            particle.y = center_y + normal_y * corrected_distance

            self._particle_canvas_needs_update = true
        else
            -- no collision, update position normally
            particle.x = new_x
            particle.y = new_y

            -- store the perturbed velocity for next frame
            particle.velocity_x = vx
            particle.velocity_y = vy

            self._particle_canvas_needs_update = true
        end
    end
end

--- @brief
function ow.ResultsScreen:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit
    local max_expand_w = 0.5 * width -- TODO

    -- widgets

    local current_y = y + 2 * m
    self._title_label:reformat(0, 0, width) -- wrap title
    local title_w, title_h = self._title_label:measure()
    self._title_label:reformat(x + 0.5 * width - 0.5 * title_w, y, width)

    local reformat = function(prefix, value, grade)
        local prefix_w, prefix_h = prefix:measure()
        local value_w, value_h = value:measure()
        local grade_w, grade_h = grade:measure()
        local max_h = math.max(value_h, grade_h)

        prefix:reformat(
            x + 0.5 * width - 0.5 * prefix_w,
            current_y + 0.5 * max_h - 0.5 * prefix_h,
            math.huge, math.huge
        )

        current_y = current_y + prefix_h

        value:reformat(
            x + 0.5 * width - 0.5 * value_w,
            current_y + 0.5 * max_h - 0.5 * prefix_h,
            math.huge, math.huge
        )

        current_y = current_y + value_h

        grade:reformat(
            x + 0.5 * width - 0.5 * grade_w,
            current_y + 0.5 * max_h - 0.5 * grade_h,
            grade_w, grade_h
        )

        current_y = current_y + grade_h
    end

    reformat(self._time_prefix_label, self._time_value_label, self._time_grade_label)
    reformat(self._flow_prefix_label, self._flow_value_label, self._flow_grade_label)
    reformat(self._coins_prefix_label, self._coins_value_label, self._coins_grade_label)

    local total_prefix_w, total_prefix_h = self._total_prefix_label:measure()
    local total_grade_w, total_grade_h = self._total_grade_label:measure()

    local total_grade_x, total_grade_y = x + 0.5 * width - 0.5 * total_grade_w, current_y
    self._total_grade_label:reformat(
        total_grade_x, total_grade_y, total_grade_w, total_grade_h
    )

    self._total_prefix_label:reformat(
        x + 0.5 * width - 0.5 * total_grade_w - m - total_prefix_w,
        current_y,
        math.huge, math.huge
    )

    local grade_x, grade_y = total_grade_x + 0.5 * total_grade_w, total_grade_y + 0.5 * total_grade_h
    local grade_r = math.max(total_grade_w, total_grade_h) / 2 + 2 * m
    local grade_m = 30 * rt.get_pixel_scale()

    -- frame

    local mesh_m = 100 * rt.get_pixel_scale()
    local mesh_w = (width - 2 * mesh_m) / 2
    local mesh_h = (height - 2 * mesh_m)

    local expand_w = max_expand_w

    self._frame_mesh_m = mesh_m
    self._frames = {
        rt.AABB( -- start
            x + 0.5 * width - mesh_m,
            y + height,
            2 * mesh_m,
            height + 2 * mesh_m
        ),

        rt.AABB( -- upwards
            x + 0.5 * width - mesh_m,
            y - mesh_m,
            2 * mesh_m,
            height + 2 * mesh_m
        ),

        rt.AABB( -- expand
            x + 0.5 * width - 0.5 * expand_w - mesh_m,
            y - mesh_m,
            expand_w + 2 * mesh_m,
            height + 2 * mesh_m
        ),

        rt.AABB( -- fill
            x - mesh_m,
            y - mesh_m - height,
            width + 2 * mesh_m,
            height + 2 * mesh_m
        )
    }

    -- particle

    local particle_r = 10 * rt.get_pixel_scale()
    self._particle_texture = rt.RenderTexture(2 * particle_r, 2 * particle_r)

    local padding = 10
    self._particle_canvas = rt.RenderTexture(2 * (grade_r + padding), 2 * (grade_r + padding))

    local mesh = rt.MeshCircle(0.5 * self._particle_texture:get_width(), 0.5 * self._particle_texture:get_height(), particle_r)
    mesh:set_vertex_color(1, 1, 1, 1, 1)
    for i = 2, mesh:get_n_vertices() do
        mesh:set_vertex_color(i, 0, 0, 0, 1)
    end

    love.graphics.push("all")
    love.graphics.origin()
    self._particle_texture:bind()
    mesh:draw()
    self._particle_texture:unbind()
    love.graphics.pop()

    self._particles = {}
    local min_scale, max_scale = 1, 3
    local particle_x, particle_y = 0.5 * self._particle_canvas:get_width(), 0.5 *  self._particle_canvas:get_height()
    local n_particles = 128
    for i = 1, n_particles, 1 do
        local angle = (i - 1) / n_particles * 2 * math.pi --rt.random.number(0, 2 * math.pi)
        local particle = {
            x = particle_x,
            y = particle_y,
            scale = rt.random.number(min_scale, max_scale),
            velocity_x = math.cos(angle),
            velocity_y = math.sin(angle),
            velocity_magnitude = rt.random.number(0.1, 1)
        }
        
        table.insert(self._particles, particle)
    end

    self._particle_canvas_x = total_grade_x + 0.5 * total_grade_w - 0.5 * self._particle_canvas:get_width()
    self._particle_canvas_y = total_grade_y + 0.5 * total_grade_h - 0.5 * self._particle_texture:get_height()
    self._particle_canvas_needs_update = true
    
    self:update(0) -- update mesh from current animation
end

--- @brief
function ow.ResultsScreen:draw()
    if self._particle_canvas_needs_update == true then
        love.graphics.push("all")
        love.graphics.setBlendMode("add", "premultiplied")
        self._particle_canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)
        for particle in values(self._particles) do
            love.graphics.draw(
                self._particle_texture:get_native(), 
                particle.x, particle.y, 0, 
                particle.scale, particle.scale,
                0.5 * self._particle_texture:get_width(), 0.5 * self._particle_texture:get_height()
            )
        end

        self._particle_canvas:unbind()
        love.graphics.setBlendMode("alpha")
        love.graphics.pop("all")
        self._particle_canvas_needs_update = nil
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    local elapsed = rt.SceneManager:get_elapsed()

    _frame_shader:bind()
    _frame_shader:send("elapsed", elapsed)
    _frame_shader:send("black", { rt.Palette.BACKGROUND:unpack() })
    self._frame_mesh:draw()
    _frame_shader:unbind()

    local value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)

    _mask_shader:bind()
    _mask_shader:send("elapsed", elapsed)
    self._frame_mesh:draw()
    _mask_shader:unbind()

    rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

    _grade_shader:bind()
    _grade_shader:send("elapsed", elapsed)
    love.graphics.setColor(1, 1, 1, 1)
    self._particle_canvas:draw(self._particle_canvas_x, self._particle_canvas_y)
    _grade_shader:unbind()

    local draw_label = function(label)
        local x, y, w, h = label:get_bounds():unpack()
        rt.Palette.GRAY_1:bind()
        love.graphics.rectangle("fill", x, y, w, h, 0.25 * h)
        label:draw()
    end

    for widget in range(
        self._title_label,
        self._flow_prefix_label,
        self._time_prefix_label,
        self._coins_prefix_label,
        self._flow_value_label,
        self._time_value_label,
        self._coins_value_label,
        self._flow_grade_label,
        self._time_grade_label,
        self._coins_grade_label,
        self._total_prefix_label,
        self._total_grade_label
    ) do
        widget:draw()
    end

    rt.graphics.set_stencil_mode(nil)

    love.graphics.setColor(1, 0, 1, 1)
    if self._dbg ~= nil then
        love.graphics.rectangle("line", self._dbg:unpack())
    end

    self._total_grade_label:draw_bounds()
end

--- @brief
function ow.ResultsScreen:_update_frame_mesh(x, y, w, h, m)
    -- convert overall size to size of inner slice
    w = w - 2 * m
    h = h - 2 * m
    w = w / 2

    local x1, x2, x3, x4, x5
    x1 = x
    x2 = x + m
    x3 = x + m + w
    x4 = x + m + w + w
    x5 = x + m + w + w + m

    local y1, y2, y3, y4
    y1 = y
    y2 = y + m
    y3 = y + m + h
    y4 = y + m + h + m

    local u0, u1, v0, v1 = 0, 1, 0, 1
    local c1 = function() return 1, 1, 1, 0  end
    local c0 = function() return 1, 1, 1, 1  end

    if self._frame_mesh_data == nil then
        self._frame_mesh_data = {
            { x1, y1, u1, v1, c1() },
            { x2, y1, u0, v1, c1() },
            { x3, y1, u0, v1, c1() },
            { x4, y1, u0, v1, c1() },
            { x5, y1, u1, v1, c1() },
            { x1, y2, u1, v0, c1() },
            { x2, y2, u0, v0, c0() },
            { x3, y2, u0, v0, c0() },
            { x4, y2, u0, v0, c0() },
            { x5, y2, u1, v0, c1() },
            { x1, y3, u1, v0, c1() },
            { x2, y3, u0, v0, c0() },
            { x3, y3, u0, v0, c0() },
            { x4, y3, u0, v0, c0() },
            { x5, y3, u1, v0, c1() },
            { x1, y4, u1, v1, c1() },
            { x2, y4, u0, v1, c1() },
            { x3, y4, u0, v1, c1() },
            { x4, y4, u0, v1, c1() },
            { x5, y4, u1, v1, c1() },
        }
    else
        local data = self._frame_mesh_data
        data[1][1], data[1][2] = x1, y1
        data[2][1], data[2][2] = x2, y1
        data[3][1], data[3][2] = x3, y1
        data[4][1], data[4][2] = x4, y1
        data[5][1], data[5][2] = x5, y1
        data[6][1], data[6][2] = x1, y2
        data[7][1], data[7][2] = x2, y2
        data[8][1], data[8][2] = x3, y2
        data[9][1], data[9][2] = x4, y2
        data[10][1], data[10][2] = x5, y2
        data[11][1], data[11][2] = x1, y3
        data[12][1], data[12][2] = x2, y3
        data[13][1], data[13][2] = x3, y3
        data[14][1], data[14][2] = x4, y3
        data[15][1], data[15][2] = x5, y3
        data[16][1], data[16][2] = x1, y4
        data[17][1], data[17][2] = x2, y4
        data[18][1], data[18][2] = x3, y4
        data[19][1], data[19][2] = x4, y4
        data[20][1], data[20][2] = x5, y4
    end

    if self._frame_mesh == nil then
        local vertex_map = {
            1, 2, 7,
            1, 7, 6,
            2, 3, 8,
            2, 8, 7,
            3, 4, 8,
            4, 8, 9,
            4, 5, 9,
            5, 9, 10,
            6, 7, 11,
            7, 11, 12,
            7, 8, 12,
            8, 12, 13,
            8, 9, 13,
            9, 13, 14,
            9, 10, 14,
            10, 14, 15,
            11, 12, 16,
            12, 16, 17,
            12, 13, 17,
            13, 17, 18,
            13, 14, 19,
            13, 19, 18,
            14, 15, 20,
            14, 20, 19
        }

        self._frame_mesh = rt.Mesh(
            self._frame_mesh_data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STREAM
        )
        self._frame_mesh:set_vertex_map(vertex_map)
    else
        self._frame_mesh:replace_data(self._frame_mesh_data)
    end
end

--- @brief
--- @param title String stage title
--- @param flow_percentage Number in [0, 100]
--- @param flow_grade rt.StageGrade
--- @param time Number seconds
--- @param time_grade rt.StageGrade
--- @param coins Number integer
--- @param coins_grade rt.StageGrade
--- @param total_grade rt.StageGrade
function ow.ResultsScreen:present(title, time, time_grade, flow, flow_grade, n_coins, max_n_coins, coins_grade, total_grade)
    meta.assert(
        title, "String",
        time, "Number",
        time_grade, "Number",
        flow, "Number",
        flow_grade, "Number",
        n_coins, "Number",
        max_n_coins, "Number",
        coins_grade, "Number",
        total_grade, "Number"
    )

    self._title = title
    self._title_label:set_text(_title_prefix .. title .. _title_postfix)
    self._total_grade = total_grade

    self._time_target = time
    self._time_start = 0
    self._time_grade_label:set_grade(time_grade)

    self._flow_target = flow
    self._flow_start = 0
    self._flow_grade_label:set_grade(flow_grade)

    self._coins_max = max_n_coins
    self._coins_target = n_coins
    self._coins_start = 0
    self._coins_grade_label:set_grade(time_grade)

    self._total_grade_label:set_grade(total_grade)

    self:_reset()
end

--- @brief
function ow.ResultsScreen:_reset()
    _frame_shader:recompile()
    _mask_shader:recompile()
    _grade_shader:recompile()
    --self._sequence:reset()
    --self._grade_frame_animation:reset()
end