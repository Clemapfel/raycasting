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
        if which == "j" then _frame_shader:recompile(); _mask_shader:recompile(); _grade_shader:recompile() end
        self._sequence:reset()
        self._shader_elapsed = 0
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
    local title_prefix, title_postfix = "<b><o><u>", "</b></o></u>"

    self._title_label = rt.Label(title_prefix .. self._title .. title_postfix, rt.FontSize.LARGER, _title_font)

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

    self._grade_x, self._grade_y, self._grade_r, self._grade_m = 0, 0, 1, 1

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

    local t = self._sequence:get_value()
    local x, y, w, h = _lerp_aabbs(t, self._frames)
    self._dbg = rt.AABB(x, y, w, h)

    local m = self._frame_mesh_m
    self:_update_frame_mesh(x, y, w, h, m)

    self:_update_grade_mesh(self._grade_x, self._grade_y, self._grade_r, self._grade_m)
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

    self._grade_x, self._grade_y, self._grade_r, self._grade_m = grade_x, grade_y, grade_r, grade_m
    self:_update_grade_mesh(grade_x, grade_y, grade_r, grade_m)

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

    self:update(0) -- update mesh from current animation
end

--- @brief
function ow.ResultsScreen:draw()
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
    self._grade_mesh:draw()
    _grade_shader:unbind()


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
--- @brief
function ow.ResultsScreen:_update_grade_mesh(grade_x, grade_y, grade_r, grade_m)
    local animation_i = self._sequence:get_animation_index()

    local t = self._sequence:get_animation(2):get_fraction()
    if animation_i < 2 then t = 0 elseif t >= 2 then t = 1 end

    grade_r = grade_r * t

    -- Grade mesh construction with corrected texture coordinates
    local segments = 32

    if self._grade_mesh_data == nil then
        self._grade_mesh_data = {}

        -- Center vertex - u=0, v=0 (center of radial gradient)
        table.insert(self._grade_mesh_data, { grade_x, grade_y, 0, 0, 1, 1, 1, 1 })

        -- Inner circle vertices (circle edge) - u varies [0,1] around circumference, v=0
        for i = 1, segments do
            local angle = (i - 1) * (2 * math.pi / segments)
            local cx = grade_x + math.cos(angle) * grade_r
            local cy = grade_y + math.sin(angle) * grade_r
            local u = (i - 1) / segments  -- u spans [0, 1) around circumference
            local v = 0  -- v = 0 at inner circle edge
            table.insert(self._grade_mesh_data, { cx, cy, u, v, 1, 1, 1, 1 })
        end

        -- Outer ring vertices - u varies [0,1] around circumference, v=1 at peak of gradient
        for i = 1, segments do
            local angle = (i - 1) * (2 * math.pi / segments)
            local cx = grade_x + math.cos(angle) * (grade_r + grade_m)
            local cy = grade_y + math.sin(angle) * (grade_r + grade_m)
            local u = (i - 1) / segments  -- u spans [0, 1) around circumference
            local v = 1  -- v=1 at outer ring (peak of radial gradient)
            table.insert(self._grade_mesh_data, { cx, cy, u, v, 1, 1, 1, 0 })
        end

        -- Add duplicate vertices for texture coordinate wraparound
        local angle = 0  -- first vertex angle
        local cx_inner = grade_x + math.cos(angle) * grade_r
        local cy_inner = grade_y + math.sin(angle) * grade_r
        local cx_outer = grade_x + math.cos(angle) * (grade_r + grade_m)
        local cy_outer = grade_y + math.sin(angle) * (grade_r + grade_m)

        table.insert(self._grade_mesh_data, { cx_inner, cy_inner, 1, 0, 1, 1, 1, 1 })
        table.insert(self._grade_mesh_data, { cx_outer, cy_outer, 1, 1, 1, 1, 1, 0 })
    else
        local data = self._grade_mesh_data

        -- Update center vertex
        data[1][1], data[1][2] = grade_x, grade_y

        -- Update inner circle vertices
        for i = 1, segments do
            local angle = (i - 1) * (2 * math.pi / segments)
            local cx = grade_x + math.cos(angle) * grade_r
            local cy = grade_y + math.sin(angle) * grade_r
            data[i + 1][1], data[i + 1][2] = cx, cy
        end

        -- Update outer ring vertices
        for i = 1, segments do
            local angle = (i - 1) * (2 * math.pi / segments)
            local cx = grade_x + math.cos(angle) * (grade_r + grade_m)
            local cy = grade_y + math.sin(angle) * (grade_r + grade_m)
            data[i + 1 + segments][1], data[i + 1 + segments][2] = cx, cy
        end

        -- Update duplicate vertices for wraparound
        local angle = 0
        local cx_inner = grade_x + math.cos(angle) * grade_r
        local cy_inner = grade_y + math.sin(angle) * grade_r
        local cx_outer = grade_x + math.cos(angle) * (grade_r + grade_m)
        local cy_outer = grade_y + math.sin(angle) * (grade_r + grade_m)

        data[1 + segments * 2 + 1][1], data[1 + segments * 2 + 1][2] = cx_inner, cy_inner
        data[1 + segments * 2 + 2][1], data[1 + segments * 2 + 2][2] = cx_outer, cy_outer
    end

    if self._grade_mesh == nil then
        -- Create vertex map for triangulation with corrected wraparound
        local grade_vertex_map = {}

        -- Inner circle triangles (center to inner circle edge)
        for i = 1, segments do
            local next_i = (i % segments) + 1

            if i == segments then
                local duplicate_inner = 1 + segments * 2 + 1

                table.insert(grade_vertex_map, 1)           -- center
                table.insert(grade_vertex_map, i + 1)      -- current inner vertex
                table.insert(grade_vertex_map, duplicate_inner) -- duplicate first vertex with u=1
            else
                table.insert(grade_vertex_map, 1)           -- center
                table.insert(grade_vertex_map, i + 1)      -- current inner vertex
                table.insert(grade_vertex_map, next_i + 1) -- next inner vertex
            end
        end

        -- Ring triangles (between inner circle and outer ring)
        for i = 1, segments do
            local next_i = (i % segments) + 1
            local inner_current = i + 1
            local inner_next = next_i + 1
            local outer_current = i + 1 + segments
            local outer_next = next_i + 1 + segments

            if i == segments then
                local duplicate_inner = 1 + segments * 2 + 1
                local duplicate_outer = 1 + segments * 2 + 2

                -- First triangle of quad
                table.insert(grade_vertex_map, inner_current)
                table.insert(grade_vertex_map, outer_current)
                table.insert(grade_vertex_map, duplicate_inner)

                -- Second triangle of quad
                table.insert(grade_vertex_map, duplicate_inner)
                table.insert(grade_vertex_map, outer_current)
                table.insert(grade_vertex_map, duplicate_outer)
            else
                -- First triangle of quad
                table.insert(grade_vertex_map, inner_current)
                table.insert(grade_vertex_map, outer_current)
                table.insert(grade_vertex_map, inner_next)

                -- Second triangle of quad
                table.insert(grade_vertex_map, inner_next)
                table.insert(grade_vertex_map, outer_current)
                table.insert(grade_vertex_map, outer_next)
            end
        end

        self._grade_mesh = rt.Mesh(
            self._grade_mesh_data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STREAM
        )
        self._grade_mesh:set_vertex_map(grade_vertex_map)
    else
        self._grade_mesh:replace_data(self._grade_mesh_data)
    end
end