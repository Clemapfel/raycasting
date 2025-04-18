rt.settings.keybinding_indicator = {
    font = rt.settings.font.default_small,
    font_small = rt.settings.font.default_tiny,
}

--- @class rt.KeybindingIndicator
rt.KeybindingIndicator = meta.class("KeybindingIndicator", rt.Widget)

function rt.KeybindingIndicator:instantiate()
    return meta.new(rt.KeybindingIndicator, {
        _font = nil, -- rt.Font
        _draw = function() end,
        _final_width = 0,
        _initializer = function(self, width)  end
    })
end


--- @override
function rt.KeybindingIndicator:realize()
    if self:already_realized() then return end
end

--- @brief
function rt.KeybindingIndicator:size_allocate(x, y, width, height)
    self._final_width = -1
    self._initializer(self, width)
    if self._final_width == -1 then
        self._final_width = width
    end
end

--- @override
function rt.KeybindingIndicator:draw()
    love.graphics.translate(self._bounds.x, self._bounds.y)
    self._draw()
    love.graphics.translate(-self._bounds.x, -self._bounds.y)
end

--- @brief
function rt.KeybindingIndicator:set_opacity(opacity)
    self._opacity = opacity
end

--- @brief
function rt.KeybindingIndicator:create_as_button(top_selected, right_selected, bottom_selected, left_selected)
    self._initializer = function(self, width)
        local total_w = width
        local button_outer_m = 0.23 * width
        local button_inner_m = button_outer_m
        local button_r = (width - 2 * button_outer_m - button_inner_m) / 2.1

        local x, y = 0, 0
        local height = width

        local outline_outline_width = 3
        local center_offset_x = 0.35 * button_inner_m + button_r
        local center_offset_y = center_offset_x
        local center_x, center_y = x + 0.5 * width, y + 0.5 * height - outline_outline_width
        local top_x, top_y = center_x, center_y - center_offset_y
        local right_x, right_y = center_x + center_offset_x, center_y
        local bottom_x, bottom_y = center_x, center_y + center_offset_y
        local left_x, left_y = center_x - center_offset_x, center_y

        local n_outer_vertices = 32

        local top_base, top_outline = rt.Circle(top_x, top_y, button_r), rt.Circle(top_x, top_y, button_r)
        local right_base, right_outline = rt.Circle(right_x, right_y, button_r), rt.Circle(right_x, right_y, button_r)
        local bottom_base, bottom_outline = rt.Circle(bottom_x, bottom_y, button_r), rt.Circle(bottom_x, bottom_y, button_r)
        local left_base, left_outline = rt.Circle(left_x, left_y, button_r), rt.Circle(left_x, left_y, button_r)

        local back_x_offset, back_y_offset = 3, 3
        local top_back, top_back_outline = rt.Circle(top_x + back_x_offset, top_y + back_y_offset, button_r), rt.Circle(top_x + back_x_offset, top_y + back_y_offset, button_r)
        local right_back, right_back_outline = rt.Circle(right_x + back_x_offset, right_y + back_y_offset, button_r), rt.Circle(right_x + back_x_offset, right_y + back_y_offset, button_r)
        local bottom_back, bottom_back_outline = rt.Circle(bottom_x + back_x_offset, bottom_y + back_y_offset, button_r), rt.Circle(bottom_x + back_x_offset, bottom_y + back_y_offset, button_r)
        local left_back, left_back_outline = rt.Circle(left_x + back_x_offset, left_y + back_y_offset, button_r), rt.Circle(left_x + back_x_offset, left_y + back_y_offset, button_r)

        local top_outline_outline = rt.Circle(top_x, top_y, button_r + outline_outline_width)
        local right_outline_outline = rt.Circle(right_x, right_y, button_r + outline_outline_width)
        local bottom_outline_outline = rt.Circle(bottom_x, bottom_y, button_r + outline_outline_width)
        local left_outline_outline = rt.Circle(left_x, left_y, button_r + outline_outline_width)

        local top_back_outline_outline = rt.Circle(top_x + back_x_offset, top_y + back_y_offset, button_r + outline_outline_width)
        local right_back_outline_outline = rt.Circle(right_x + back_x_offset, right_y + back_y_offset, button_r + outline_outline_width)
        local bottom_back_outline_outline = rt.Circle(bottom_x + back_x_offset, bottom_y + back_y_offset, button_r + outline_outline_width)
        local left_back_outline_outline = rt.Circle(left_x + back_x_offset, left_y + back_y_offset, button_r + outline_outline_width)

        local outline_width = 2
        local selection_inlay_radius = button_r --(button_r - outline_width) * 0.85
        local top_selection = rt.Circle(top_x, top_y, selection_inlay_radius)
        local right_selection = rt.Circle(right_x, right_y, selection_inlay_radius)
        local bottom_selection = rt.Circle(bottom_x, bottom_y, selection_inlay_radius)
        local left_selection = rt.Circle(left_x, left_y, selection_inlay_radius)

        for base in range(top_base, right_base, bottom_base, left_base) do
            base:set_color(rt.Palette.GRAY_3)
        end

        for back in range(top_back, right_back, bottom_back, left_back) do
            back:set_color(rt.Palette.GRAY_5)
        end

        for outline_outline in range(top_outline_outline, right_outline_outline, bottom_outline_outline, left_outline_outline, top_back_outline_outline, right_back_outline_outline, bottom_back_outline_outline, left_back_outline_outline) do
            outline_outline:set_color(rt.Palette.TRUE_WHITE)
        end

        for selection in range(top_selection, right_selection, bottom_selection, left_selection) do
            selection:set_color(rt.Palette.WHITE)
        end

        for outline in range(top_outline, right_outline, bottom_outline, left_outline, top_back_outline, right_back_outline, bottom_back_outline, left_back_outline) do
            outline:set_color(rt.Palette.GRAY_7)
            outline:set_is_outline(true)
            outline:set_line_width(outline_width)
            outline:set_n_outer_vertices(n_outer_vertices)
        end

        local selection_inlay
        if top_selected then selection_inlay = top_selection end
        if right_selected then selection_inlay = right_selection end
        if bottom_selected then selection_inlay = bottom_selection end
        if left_selected then selection_inlay = left_selection end

        self._content = {
            top_outline_outline,
            right_outline_outline,
            bottom_outline_outline,
            left_outline_outline,
            top_back_outline_outline,
            right_back_outline_outline,
            bottom_back_outline_outline,
            left_back_outline_outline,
            top_back,
            right_back,
            bottom_back,
            left_back,
            top_back_outline,
            right_back_outline,
            bottom_back_outline,
            left_back_outline,
            top_base,
            right_base,
            bottom_base,
            left_base,
            selection_inlay,
            top_outline,
            right_outline,
            bottom_outline,
            left_outline,
        }

        self._draw = function()
            for drawable in values(self._content) do
                drawable:draw()
            end
        end
    end

    if self._is_realized then self:reformat() end
end

--- @brief
function rt.KeybindingIndicator:create_as_dpad(up_selected, right_selected, down_selected, left_selected)
    self._initializer = function(self, width)
        local x, y = 0, 0
        local height = width
        local translate = rt.translate_point_by_angle
        local center_x, center_y = x + 0.5 * width, y + 0.5 * height

        local r = 0.5 * width - 5
        local m = 0.3 * width
        local bottom_left_x, bottom_left_y = center_x - m / 2, center_y + r
        local bottom_right_x, bottom_right_y = center_x + m / 2, center_y + r
        local center_bottom_right_x, center_bottom_right_y = center_x + m / 2, center_y + m / 2
        local right_bottom_x, right_bottom_y = center_x + r, center_y + m / 2
        local right_top_x, right_top_y = center_x + r, center_y - m / 2
        local center_top_right_x, center_top_right_y = center_x + m / 2, center_y - m / 2
        local top_right_x, top_right_y = center_x + m / 2, center_y - r
        local top_left_x, top_left_y = center_x - m / 2, center_y - r
        local center_top_left_x, center_top_left_y = center_x - m / 2, center_y - m / 2
        local left_top_x, left_top_y = center_x - r, center_y - m / 2
        local left_bottom_x, left_bottom_y = center_x - r, center_y + m / 2
        local center_bottom_left_x, center_bottom_left_y = center_x - m / 2, center_y + m / 2

        local center_offset = 0.175 * m
        local frame_offset = 0.18 * m
        local top = {
            top_left_x + frame_offset, top_left_y + frame_offset,
            top_right_x - frame_offset, top_right_y + frame_offset,
            center_top_right_x - frame_offset, center_top_right_y + frame_offset - center_offset,
            center_x, center_y - center_offset,
            center_top_left_x + frame_offset, center_top_left_y + frame_offset - center_offset,
            top_left_x + frame_offset, top_left_y + frame_offset
        }

        local right = {
            right_top_x - frame_offset, right_top_y + frame_offset,
            right_bottom_x - frame_offset, right_bottom_y - frame_offset,
            center_bottom_right_x - frame_offset + center_offset, center_bottom_right_y - frame_offset,
            center_x + center_offset, center_y,
            center_top_right_x - frame_offset + center_offset, center_top_right_y + frame_offset,
            right_top_x - frame_offset, right_top_y + frame_offset
        }

        local bottom = {
            bottom_right_x - frame_offset, bottom_right_y - frame_offset,
            bottom_left_x + frame_offset, bottom_left_y - frame_offset,
            center_bottom_left_x + frame_offset, center_bottom_left_y - frame_offset + center_offset,
            center_x, center_y + center_offset,
            center_bottom_right_x - frame_offset, center_bottom_right_y - frame_offset + center_offset,
            bottom_right_x - frame_offset, bottom_right_y - frame_offset
        }

        local left = {
            left_top_x + frame_offset, left_top_y + frame_offset,
            center_top_left_x + frame_offset - center_offset, center_top_left_y + frame_offset,
            center_x - center_offset, center_y,
            center_bottom_left_x + frame_offset - center_offset, center_bottom_left_y - frame_offset,
            left_bottom_x + frame_offset, left_bottom_y - frame_offset,
            left_top_x + frame_offset, left_top_y + frame_offset
        }

        local top_base, top_outline = rt.Polygon(top), rt.Polygon(top)
        local right_base, right_outline = rt.Polygon(right), rt.Polygon(right)
        local bottom_base, bottom_outline = rt.Polygon(bottom), rt.Polygon(bottom)
        local left_base, left_outline = rt.Polygon(left), rt.Polygon(left)

        for base in range(top_base, right_base, bottom_base, left_base) do
            base:set_color(rt.Palette.GRAY_3)
        end

        local selected_color = rt.Palette.WHITE
        if up_selected then top_base:set_color(selected_color) end
        if right_selected then right_base:set_color(selected_color) end
        if down_selected then bottom_base:set_color(selected_color) end
        if left_selected then left_base:set_color(selected_color) end

        for outline in range(top_outline, right_outline, bottom_outline, left_outline) do
            outline:set_color(rt.Palette.GRAY_7)
            outline:set_is_outline(true)
        end

        local corner_radius = 5

        local backlay_vertical = rt.Rectangle(top_left_x, top_left_y, m, 2 * r)
        local backlay_horizontal = rt.Rectangle(left_top_x, left_top_y, 2 * r, m)

        for backlay in range(backlay_horizontal, backlay_vertical) do
            backlay:set_color(rt.Palette.GRAY_5)
            backlay:set_corner_radius(corner_radius)
        end

        local whole = {
            top_left_x, top_left_y,
            top_right_x, top_right_y,
            center_top_right_x, center_top_right_y,
            right_top_x, right_top_y,
            right_bottom_x, right_bottom_y,
            center_bottom_right_x, center_bottom_right_y,
            bottom_right_x, bottom_right_y,
            bottom_left_x, bottom_left_y,
            center_bottom_left_x, center_bottom_left_y,
            left_bottom_x, left_bottom_y,
            left_top_x, left_top_y,
            center_top_left_x, center_top_left_y,
            top_left_x, top_left_y
        }

        local backlay_outline_vertical = rt.Rectangle(top_left_x, top_left_y, m, 2 * r)
        local backlay_outline_horizontal = rt.Rectangle(left_top_x, left_top_y, 2 * r, m)

        local backlay_outline_outline_vertical = rt.Rectangle(top_left_x, top_left_y, m, 2 * r)
        local backlay_outline_outline_horizontal = rt.Rectangle(left_top_x, left_top_y, 2 * r, m)

        for backlay_outline in range(backlay_outline_vertical, backlay_outline_horizontal) do
            backlay_outline:set_color(rt.Palette.GRAY_7)
            backlay_outline:set_is_outline(true)
            backlay_outline:set_line_width(5)
            backlay_outline:set_corner_radius(corner_radius)
        end

        for outline_outline in range(backlay_outline_outline_vertical, backlay_outline_outline_horizontal) do
            outline_outline:set_color(rt.Palette.TRUE_WHITE)
            outline_outline:set_line_width(8)
            outline_outline:set_corner_radius(corner_radius)
            outline_outline:set_is_outline(true)
        end

        self._content = {
            backlay_outline_outline_horizontal,
            backlay_outline_outline_vertical,

            backlay_outline_vertical,
            backlay_outline_horizontal,
            backlay_horizontal,
            backlay_vertical,
            top_base,
            right_base,
            bottom_base,
            left_base,

            --[[
            top_outline,
            right_outline,
            bottom_outline,
            left_outline
            ]]--
        }

        self._draw = function()
            for drawable in values(self._content) do
                drawable:draw()
            end
        end
    end

    if self._is_realized then self:reformat() end
end

--- @brief
function rt.KeybindingIndicator:create_as_start_or_select(start_or_select)
    self._initializer = function(self, width)
        local x, y = 0, 0
        local height = width

        local w = 0.9 * width / 1.2
        local h = 0.4 * height / 1.2

        local center_x, center_y = x + 0.5 * width, y + 0.5 * height
        local base = rt.Rectangle(center_x - 0.5 * w, center_y - 0.5 * h, w, h)
        local base_outline = rt.Rectangle(center_x - 0.5 * w, center_y - 0.5 * h, w, h)
        local base_outline_outline = rt.Rectangle(center_x - 0.5 * w, center_y - 0.5 * h, w, h)

        for rectangle in range(base, base_outline, base_outline_outline) do
            rectangle:set_corner_radius(h / 2)
        end

        base:set_color(rt.Palette.GRAY_3)
        base_outline:set_color(rt.Palette.GRAY_7)
        base_outline:set_is_outline(true)
        base_outline:set_line_width(2)

        base_outline_outline:set_color(rt.Palette.TRUE_WHITE)
        base_outline_outline:set_is_outline(true)
        base_outline_outline:set_line_width(5)

        local r = 0.5 * h * 0.8
        local right_triangle, right_triangle_outline

        do
            local angle1 = 0
            local angle2 = 2 * math.pi / 3
            local angle3 = 4 * math.pi / 3

            local vertices = {
                center_x + r * math.cos(angle1), center_y + r * math.sin(angle1),
                center_x + r * math.cos(angle2), center_y + r * math.sin(angle2),
                center_x + r * math.cos(angle3), center_y + r * math.sin(angle3)
            }

            right_triangle = rt.Polygon(vertices)
            right_triangle_outline = rt.Polygon(vertices)
        end

        local left_triangle, left_triangle_outline
        do
            local angle1 = math.pi
            local angle2 = math.pi + 2 * math.pi / 3
            local angle3 = math.pi + 4 * math.pi / 3

            local vertices = {
                center_x + r * math.cos(angle1), center_y + r * math.sin(angle1),
                center_x + r * math.cos(angle2), center_y + r * math.sin(angle2),
                center_x + r * math.cos(angle3), center_y + r * math.sin(angle3)
            }

            left_triangle = rt.Polygon(vertices)
            left_triangle_outline = rt.Polygon(vertices)
        end

        for triangle in range(left_triangle, right_triangle) do
            triangle:set_color(rt.Palette.TRUE_WHITE)
        end

        for triangle_outline in range(left_triangle_outline, right_triangle_outline) do
            triangle_outline:set_color(rt.Palette.GRAY_7)
            triangle_outline:set_is_outline(true)
        end

        local triangle, triangle_outline
        if start_or_select == true then
            triangle = right_triangle
            triangle_outline = right_triangle_outline
        else
            triangle = left_triangle
            triangle_outline = left_triangle_outline
        end

        self._content = {
            base_outline_outline,
            base,
            base_outline,
            triangle,
            triangle_outline
        }

        self._draw = function()
            for drawable in values(self._content) do
                drawable:draw()
            end
        end
    end

    if self._is_realized then self:reformat() end
end

--- @brief
function rt.KeybindingIndicator:create_as_l_or_r(l_or_r)
    self._initializer = function(self, width)
        local x, y, height = 0, 0, width
        local label
        if l_or_r == true then
            label = rt.Label("<o>L</o>", rt.settings.keybinding_indicator.font)
        else
            label = rt.Label("<o>R</o>", rt.settings.keybinding_indicator.font)
        end

        label:realize()
        label:set_justify_mode(rt.JustifyMode.CENTER)
        local label_w, label_h = label:measure()
        label:fit_into(0, y + 0.5 * height - 0.5 * label_h, width, height)

        local center_x, center_y = x + 0.55 * width , y + 0.5 * height
        local rect_w, rect_h = 0.75 * width, 0.45 * width
        local rect_base_x, rect_base_y = center_x - 0.5 * rect_w, center_y - 0.5 * rect_h
        local rectangle_base = rt.Rectangle(rect_base_x, rect_base_y, rect_w, rect_h)
        local rectangle_base_outline = rt.Rectangle(rect_base_x, rect_base_y, rect_w, rect_h)
        local rectangle_base_outline_outline = rt.Rectangle(rect_base_x, rect_base_y, rect_w, rect_h)

        local outline_width = 2
        rectangle_base:set_color(rt.Palette.GRAY_4)
        rectangle_base_outline:set_color(rt.Palette.GRAY_7)
        rectangle_base_outline:set_line_width(outline_width)
        rectangle_base_outline_outline:set_color(rt.Palette.TRUE_WHITE)
        rectangle_base_outline_outline:set_line_width(outline_width + 4)

        for outline in range(rectangle_base_outline, rectangle_base_outline_outline) do
            outline:set_is_outline(true)
        end

        local corner_radius = 0.2 * rect_h
        for rect in range(rectangle_base, rectangle_base_outline, rectangle_base_outline_outline) do
            rect:set_corner_radius(corner_radius)
        end

        local polygon_last_y_offset = 0.02 * height
        local bezier = love.math.newBezierCurve(
            rect_base_x + corner_radius + polygon_last_y_offset, rect_base_y,
            rect_base_x + rect_w, rect_base_y,
            rect_base_x + rect_w, rect_base_y + rect_h - corner_radius
        )


        local stencil_padding = corner_radius + outline_width
        local stencil = rt.Triangle(
            rect_base_x + corner_radius - stencil_padding, rect_base_y - stencil_padding,
            rect_base_x + rect_w + stencil_padding, rect_base_y - stencil_padding,
            rect_base_x + rect_w + stencil_padding, rect_base_y + rect_h - corner_radius
        )

        local polygon_points = {}

        for p in values(bezier:render()) do
            table.insert(polygon_points, p)
        end

        local first_x, first_y = polygon_points[1], polygon_points[2]
        first_x = first_x - polygon_last_y_offset
        table.insert(polygon_points, 1, first_y)
        table.insert(polygon_points,  2, first_x)

        local last_x, last_y = polygon_points[#polygon_points-1], polygon_points[#polygon_points]
        last_y = last_y + polygon_last_y_offset
        table.insert(polygon_points, last_x)
        table.insert(polygon_points, last_y)


        local curve_outline = rt.Line(polygon_points)
        local curve_outline_outline = rt.Line(polygon_points)

        curve_outline:set_line_width(outline_width)
        curve_outline_outline:set_line_width(outline_width + 4)
        curve_outline:set_color(rt.Palette.GRAY_7)
        curve_outline_outline:set_color(rt.Palette.TRUE_WHITE)

        local polygon = rt.Polygon({
            rect_base_x + corner_radius - 2 * polygon_last_y_offset, rect_base_y + rect_h - corner_radius + polygon_last_y_offset,
            table.unpack(polygon_points)
        })
        polygon:set_color(rt.Palette.GRAY_4)

        local flip_x = 0.5 * width
        self._draw = function()
            if l_or_r == true then
                rt.graphics.push()
                rt.graphics.translate(flip_x, 0)
                rt.graphics.scale(-1, 1)
                rt.graphics.translate(-flip_x, 0)
            end

            curve_outline_outline:draw()
            polygon:draw()

            rt.graphics.stencil(123, stencil)
            rt.graphics.set_stencil_test(rt.StencilCompareMode.NOT_EQUAL, 123)
            rectangle_base_outline_outline:draw()
            rectangle_base:draw()
            rectangle_base_outline:draw()
            rt.graphics.set_stencil_test()


            curve_outline:draw()

            if l_or_r == true then
                rt.graphics.pop()
            end

            label:draw()

            --stencil:draw()
        end
    end

    if self._is_realized then self:reformat() end
end

--- @brief
function rt.KeybindingIndicator:_as_joystick(left_or_right, width)
    local radius = 0.8 * width / 2
    local x, y, height = 0, 0, width
    local center_x, center_y = x + 0.5 * width, y + 0.5 * height

    local base_x, base_y, base_radius = center_x, center_y, radius * 0.7
    local base = rt.Circle(base_x, base_y, base_radius)
    local base_outline = rt.Circle(base_x, base_y, base_radius)
    local base_outline_outline = rt.Circle(base_x, base_y, base_radius)

    base_outline:set_is_outline(true)
    base_outline_outline:set_is_outline(true)

    local outline_width = 2

    base:set_color(rt.Palette.GRAY_5)
    base_outline:set_color(rt.Palette.GRAY_7)
    base_outline:set_line_width(outline_width)
    base_outline_outline:set_color(rt.Palette.TRUE_WHITE)
    base_outline_outline:set_line_width(outline_width + 3)

    local neck_center_x, neck_center_y, neck_width, neck_height = center_x, center_y, 0.25 * width, 0.25 * height
    local neck_base = rt.Rectangle(neck_center_x - 0.5 * neck_width, neck_center_y - neck_height, neck_width, neck_height)
    local neck_outline_left = rt.Line(neck_center_x - 0.5 * neck_width, neck_center_y, neck_center_x - 0.5 * neck_width, neck_center_y - neck_height)
    local neck_outline_right = rt.Line(neck_center_x + 0.5 * neck_width, neck_center_y, neck_center_x + 0.5 * neck_width, neck_center_y - neck_height)
    local neck_outline_outline_left = rt.Line(neck_center_x - 0.5 * neck_width, neck_center_y, neck_center_x - 0.5 * neck_width, neck_center_y - neck_height)
    local neck_outline_outline_right = rt.Line(neck_center_x + 0.5 * neck_width, neck_center_y, neck_center_x + 0.5 * neck_width, neck_center_y - neck_height)
    local neck_foot = rt.Circle(neck_center_x, neck_center_y, neck_width * 0.5)
    local neck_foot_outline = rt.Circle(neck_center_x, neck_center_y, neck_width * 0.5)

    local head_x, head_y, head_x_radius, head_y_radius = center_x, center_y - neck_height, base_radius * 1.15, base_radius * 1.15 * 0.75
    local head_base = rt.Ellipse(head_x, head_y, head_x_radius, head_y_radius)
    local head_outline = rt.Ellipse(head_x, head_y, head_x_radius, head_y_radius)
    local head_outline_outline = rt.Ellipse(head_x, head_y, head_x_radius, head_y_radius)

    local inlay_ratio = 0.7
    local head_inlay = rt.Ellipse(head_x, head_y - 0.075 * head_y_radius, head_x_radius * inlay_ratio, head_y_radius * inlay_ratio)

    local label
    if left_or_right == true then
        label = rt.Label("<o>L</o>", rt.settings.keybinding_indicator.font)
    else
        label = rt.Label("<o>R</o>", rt.settings.keybinding_indicator.font)
    end

    label:realize()
    label:set_justify_mode(rt.JustifyMode.CENTER)
    local label_w, label_h = label:measure()
    label:fit_into(0, y + 0.5 * height - 0.5 * label_h - head_y, width, height)

    local indicator_w = 0.175 * width
    local indicator_y = y + 0.5 * height - 0.5 * label_h - head_y + label_h

    local indicator_vertices = {
        x + 0.5 * width - 0.5 * indicator_w,
        indicator_y,
        x + 0.5 * width + 0.5 * indicator_w,
        indicator_y,
        x + 0.5 * width,
        indicator_y + 0.5 * indicator_w
    }
    local down_indicator = rt.Polygon(indicator_vertices)
    local down_indicator_outline = rt.Polygon(indicator_vertices)
    down_indicator_outline:set_is_outline(true)

    head_base:set_color(rt.Palette.GRAY_3)
    head_outline:set_color(rt.Palette.GRAY_7)
    head_outline:set_is_outline(true)
    head_outline_outline:set_is_outline(true)
    head_outline:set_line_width(outline_width)
    head_outline_outline:set_line_width(outline_width + 3)
    head_inlay:set_color(rt.Palette.GRAY_5)

    for neck in range(neck_base, neck_foot) do
        neck:set_color(rt.color_darken(rt.Palette.GRAY_5, 0.1))
    end

    for outline in range(neck_outline_left, neck_outline_right, neck_foot_outline, down_indicator_outline) do
        outline:set_color(rt.Palette.GRAY_7)
        outline:set_line_width(outline_width)
    end

    neck_foot_outline:set_is_outline(true)

    for outline in range(neck_outline_outline_left, neck_outline_outline_right, head_outline_outline) do
        outline:set_color(rt.Palette.TRUE_WHITE)
        outline:set_line_width(outline_width + 3)
    end

    self._content = {
        base_outline_outline,
        head_outline_outline,
        base,
        base_outline,

        --neck_outline_outline_left,
        --neck_outline_outline_right,
        neck_foot,
        neck_foot_outline,
        neck_base,
        neck_outline_left,
        neck_outline_right,

        head_base,
        head_outline,
        head_inlay,

        label,
        down_indicator_outline,
        down_indicator
    }

    self._draw = function()
        for drawable in values(self._content) do
            drawable:draw()
        end
    end
end

--- @brief
function rt.KeybindingIndicator:create_as_joystick(left_or_right)
    self._initializer = function(self, width)
        local radius = 0.8 * width / 2
        local x, y, height = 0, 0, width
        local y_offset = 0.05 * height
        local center_x, center_y = x + 0.5 * width, y + 0.5 * height + y_offset

        local base_x, base_y, base_radius = center_x, center_y, radius * 0.7
        local base = rt.Circle(base_x, base_y, base_radius)
        local base_outline = rt.Circle(base_x, base_y, base_radius)
        local base_outline_outline = rt.Circle(base_x, base_y, base_radius)

        base_outline:set_is_outline(true)
        base_outline_outline:set_is_outline(true)

        local outline_width = 2

        base:set_color(rt.Palette.GRAY_4)
        base_outline:set_color(rt.Palette.GRAY_7)
        base_outline:set_line_width(outline_width)
        base_outline_outline:set_color(rt.Palette.TRUE_WHITE)
        base_outline_outline:set_line_width(outline_width + 3)

        local neck_center_x, neck_center_y, neck_width, neck_height = center_x, center_y, 0.25 * width, 0.25 * height
        local neck_base = rt.Rectangle(neck_center_x - 0.5 * neck_width, neck_center_y - neck_height, neck_width, neck_height)
        local neck_outline_left = rt.Line(neck_center_x - 0.5 * neck_width, neck_center_y, neck_center_x - 0.5 * neck_width, neck_center_y - neck_height)
        local neck_outline_right = rt.Line(neck_center_x + 0.5 * neck_width, neck_center_y, neck_center_x + 0.5 * neck_width, neck_center_y - neck_height)
        local neck_outline_outline_left = rt.Line(neck_center_x - 0.5 * neck_width, neck_center_y, neck_center_x - 0.5 * neck_width, neck_center_y - neck_height)
        local neck_outline_outline_right = rt.Line(neck_center_x + 0.5 * neck_width, neck_center_y, neck_center_x + 0.5 * neck_width, neck_center_y - neck_height)
        local neck_foot = rt.Circle(neck_center_x, neck_center_y, neck_width * 0.5)
        local neck_foot_outline = rt.Circle(neck_center_x, neck_center_y, neck_width * 0.5)

        local head_x, head_y, head_x_radius, head_y_radius = center_x, center_y - neck_height, base_radius * 1.15, base_radius * 1.15 * 0.75
        local head_base = rt.Ellipse(head_x, head_y, head_x_radius, head_y_radius)
        local head_outline = rt.Ellipse(head_x, head_y, head_x_radius, head_y_radius)
        local head_outline_outline = rt.Ellipse(head_x, head_y, head_x_radius, head_y_radius)

        local inlay_ratio = 0.7
        local head_inlay = rt.Ellipse(head_x, head_y - 0.075 * head_y_radius, head_x_radius * inlay_ratio, head_y_radius * inlay_ratio)

        local label
        if left_or_right == true then
            label = rt.Label("<o>L</o>", rt.settings.keybinding_indicator.font)
        else
            label = rt.Label("<o>R</o>", rt.settings.keybinding_indicator.font)
        end

        label:realize()
        label:set_justify_mode(rt.JustifyMode.CENTER)
        local label_w, label_h = label:measure()
        label:fit_into(0, y + 0.5 * height - 0.5 * label_h - head_y + y_offset, width, height)

        local indicator_w = 0.175 * width
        local indicator_y = y + 0.5 * height - 0.5 * label_h - head_y + label_h + y_offset

        local indicator_vertices = {
            x + 0.5 * width - 0.5 * indicator_w,
            indicator_y,
            x + 0.5 * width + 0.5 * indicator_w,
            indicator_y,
            x + 0.5 * width,
            indicator_y + 0.5 * indicator_w
        }
        local down_indicator = rt.Polygon(indicator_vertices)
        local down_indicator_outline = rt.Polygon(indicator_vertices)
        down_indicator_outline:set_is_outline(true)

        head_base:set_color(rt.Palette.GRAY_3)
        head_outline:set_color(rt.Palette.GRAY_7)
        head_outline:set_is_outline(true)
        head_outline_outline:set_is_outline(true)
        head_outline:set_line_width(outline_width)
        head_outline_outline:set_line_width(outline_width + 3)
        head_inlay:set_color(rt.Palette.GRAY_4)

        for neck in range(neck_base, neck_foot) do
            neck:set_color(rt.color_darken(rt.Palette.GRAY_5, 0.1))
        end

        for outline in range(neck_outline_left, neck_outline_right, neck_foot_outline, down_indicator_outline) do
            outline:set_color(rt.Palette.GRAY_7)
            outline:set_line_width(outline_width)
        end

        neck_foot_outline:set_is_outline(true)

        for outline in range(neck_outline_outline_left, neck_outline_outline_right, head_outline_outline) do
            outline:set_color(rt.Palette.TRUE_WHITE)
            outline:set_line_width(outline_width + 3)
        end

        self._content = {
            base_outline_outline,
            head_outline_outline,
            base,
            base_outline,

            --neck_outline_outline_left,
            --neck_outline_outline_right,
            neck_foot,
            neck_foot_outline,
            neck_base,
            neck_outline_left,
            neck_outline_right,

            head_base,
            head_outline,
            head_inlay,

            label,
            down_indicator_outline,
            down_indicator
        }

        self._draw = function()
            for drawable in values(self._content) do
                drawable:draw()
            end
        end
    end

    if self._is_realized then self:reformat() end
end

--- @brief
function rt.KeybindingIndicator:create_as_key(text, is_space)
    if is_space == nil then is_space = false end
    self._initializer = function(self, width)
        local outer_m = 0.2 * width
        local outer_w = width - 2 * outer_m
        local outer_h = outer_w

        if is_space then
            outer_w = 0.9 * width
            outer_h = 0.4 * outer_w
        end

        local trapezoid_w = 0.1 * outer_w
        local left_trapezoid_w = trapezoid_w
        local right_trapezoid_w = trapezoid_w
        local y_offset = 0.05 * outer_h
        local bottom_trapezoid_h = trapezoid_w + y_offset
        local top_trapezoid_h = trapezoid_w - y_offset

        if is_space then
            local trapezoid_factor = 0.3
            left_trapezoid_w = trapezoid_factor * left_trapezoid_w
            right_trapezoid_w = trapezoid_factor * right_trapezoid_w
            top_trapezoid_h = trapezoid_factor * top_trapezoid_h
            bottom_trapezoid_h = trapezoid_factor * bottom_trapezoid_h
        end

        local inner_w, inner_h = outer_w - left_trapezoid_w - right_trapezoid_w, outer_h - top_trapezoid_h - bottom_trapezoid_h

        local x, y, height = 0, 0, width
        local outer_x, outer_y = x + 0.5 * width - 0.5 * outer_w, y + 0.5 * height - 0.5 * outer_h

        local outer = rt.Rectangle(outer_x, outer_y, outer_w, outer_h)
        local outer_outline = rt.Rectangle(outer_x - 1, outer_y - 1, outer_w + 2, outer_h + 2)

        local inner_x, inner_y = outer_x + left_trapezoid_w, outer_y + top_trapezoid_h
        local inner_padding = 0.005 * outer_w
        local inner = rt.Rectangle(inner_x - inner_padding, inner_y - inner_padding, inner_w + 2 * inner_padding, inner_h + 2 * inner_padding)
        local inner_outline = rt.Rectangle(inner_x - inner_padding, inner_y - inner_padding, inner_w + 2 * inner_padding, inner_h + 2 * inner_padding)

        for rectangle in range(outer, inner, outer_outline, inner_outline) do
            rectangle:set_corner_radius(4)
        end

        outer:set_color(rt.Palette.GRAY_5)
        inner:set_color(rt.Palette.GRAY_3)

        local top_trapezoid = rt.Polygon(
            outer_x, outer_y,
            outer_x + outer_w, outer_y,
            inner_x + inner_w, inner_y,
            inner_x, inner_y
        )

        local top_outline = rt.Polygon(
            outer_x, outer_y,
            outer_x + outer_w, outer_y,
            inner_x + inner_w, inner_y,
            inner_x, inner_y
        )

        local right_trapezoid = rt.Polygon(
            outer_x + outer_w, outer_y,
            outer_x + outer_w, outer_y + outer_h,
            inner_x + inner_w, inner_y + inner_h,
            inner_x + inner_w, inner_y
        )

        local right_outline = rt.Polygon(
            outer_x + outer_w, outer_y,
            outer_x + outer_w, outer_y + outer_h,
            inner_x + inner_w, inner_y + inner_h,
            inner_x + inner_w, inner_y
        )

        local bottom_trapezoid = rt.Polygon(
            inner_x, inner_y + inner_h,
            inner_x + inner_w, inner_y + inner_h,
            outer_x + outer_w, outer_y + outer_h,
            outer_x, outer_y + outer_h
        )

        local bottom_outline = rt.Polygon(
            inner_x, inner_y + inner_h,
            inner_x + inner_w, inner_y + inner_h,
            outer_x + outer_w, outer_y + outer_h,
            outer_x, outer_y + outer_h
        )

        local left_trapezoid = rt.Polygon(
            outer_x, outer_y,
            inner_x, inner_y,
            inner_x, inner_y + inner_h,
            outer_x, outer_y + outer_h
        )

        local left_outline = rt.Polygon(
            outer_x, outer_y,
            inner_x, inner_y,
            inner_x, inner_y + inner_h,
            outer_x, outer_y + outer_h
        )

        outer_outline:set_is_outline(true)
        outer_outline:set_line_width(1)
        outer_outline:set_color(rt.Palette.TRUE_WHITE)

        inner_outline:set_is_outline(true)
        inner_outline:set_line_width(2)
        inner_outline:set_is_outline(true)
        inner_outline:set_color(rt.Palette.GRAY_6)

        top_trapezoid:set_color(rt.Palette.GRAY_4)
        bottom_trapezoid:set_color(rt.color_mix(rt.Palette.GRAY_5, rt.Palette.GRAY_6, 0.5))
        left_trapezoid:set_color(rt.Palette.GRAY_5)
        right_trapezoid:set_color(rt.Palette.GRAY_5)

        for outline in range(top_outline, right_outline, bottom_outline, left_outline) do
            outline:set_color(rt.Palette.GRAY_7)
            outline:set_is_outline(true)
            outline:set_line_width(1)
        end

        local font = nil
        if is_space then font = rt.settings.keybinding_indicator.font_small end
        local label = rt.Label("<o>" .. text .. "</o>", font)
        label:set_justify_mode(rt.JustifyMode.CENTER)
        label:realize()
        local label_w, label_h = label:measure()
        label:fit_into(0, y + 0.5 * height - 0.5 * label_h - y_offset, width, label_h)

        self._content = {
            outer,
            top_trapezoid,
            right_trapezoid,
            bottom_trapezoid,
            left_trapezoid,
            top_outline,
            right_outline,
            bottom_outline,
            left_outline,
            inner,
            inner_outline,
            outer_outline,
            label
        }

        self._draw = function()
            for drawable in values(self._content) do
                drawable:draw()
            end
        end

        self._final_width = math.max(width, label_w)
    end
    if self._is_realized then self:reformat() end
end

--- @brief
function rt.KeybindingIndicator:create_as_two_horizontal_keys(left_text, right_text)
    self._initializer = function(self, width)
        local x, y, height = 0, 0, width
        local radius = 0.5 * width / 2

        local right_label = rt.Label("<o>" .. right_text .. "</o>", rt.settings.keybinding_indicator.font_small)
        local left_label = rt.Label("<o>" .. left_text .. "</o>", rt.settings.keybinding_indicator.font_small)

        for label in range(right_label, left_label) do
            label:realize()
            label:set_justify_mode(rt.JustifyMode.CENTER)
        end

        local line_width = 2
        local center_x, center_y = 0.5 * width, 0.5 * height
        local rect_r = (0.6 * width - 4 * line_width) / 2
        local spacer = 0

        local right_center_x, right_center_y = center_x + rect_r + spacer, center_y
        local left_center_x, left_center_y = center_x - rect_r - spacer, center_y

        local right_base = rt.Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_outline = rt.Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_outline_outline = rt.Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_label_w, right_label_h = right_label:measure()
        right_label:fit_into(right_center_x - rect_r, right_center_y - 0.5 * right_label_h, 2 * rect_r, 2 * rect_r)

        local left_base = rt.Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_outline = rt.Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_outline_outline = rt.Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_label_w, left_label_h = left_label:measure()
        left_label:fit_into(left_center_x - rect_r, left_center_y - 0.5 * left_label_h, 2 * rect_r, 2 * rect_r)

        local corner_radius = 0.05 * width
        for base in range(right_base, left_base) do
            base:set_color(rt.Palette.GRAY_3)
            base:set_corner_radius(corner_radius)
        end

        for outline in range(right_outline, left_outline) do
            outline:set_is_outline(true)
            outline:set_color(rt.Palette.GRAY_7)
            outline:set_corner_radius(corner_radius)
            outline:set_line_width(line_width)
        end

        for outline_outline in range(right_outline_outline, left_outline_outline) do
            outline_outline:set_is_outline(true)
            outline_outline:set_color(rt.Palette.TRUE_WHITE)
            outline_outline:set_line_width(line_width + 3)
            outline_outline:set_corner_radius(corner_radius)
        end

        local outline_outline = rt.Rectangle(0, 0, width, width)
        outline_outline:set_color(rt.Palette.TRUE_WHITE)

        self._content = {
            right_outline_outline,
            left_outline_outline,

            right_base,
            right_outline,

            left_base,
            left_outline,

            right_label,
            left_label
        }

        self._draw = function()
            for drawable in values(self._content) do
                drawable:draw()
            end
        end
    end
end

--- @brief
function rt.KeybindingIndicator:create_as_two_vertical_keys(top_text, bottom_text)
    self:create_as_two_horizontal_keys(top_text, bottom_text)
end

--- @brief
function rt.KeybindingIndicator:create_as_four_keys(up_text, right_text, bottom_text, left_text)
    self._initializer = function(self, width)
        local x, y, height = 0, 0, width
        local radius = 0.5 * width / 2

        local top_label = rt.Label("<o>" .. up_text .. "</o>", rt.settings.keybinding_indicator.font_small)
        local right_label = rt.Label("<o>" .. right_text .. "</o>", rt.settings.keybinding_indicator.font_small)
        local bottom_label = rt.Label("<o>" .. bottom_text .. "</o>", rt.settings.keybinding_indicator.font_small)
        local left_label = rt.Label("<o>" .. left_text .. "</o>", rt.settings.keybinding_indicator.font_small)

        for label in range(top_label, right_label, bottom_label, left_label) do
            label:realize()
            label:set_justify_mode(rt.JustifyMode.CENTER)
        end

        local line_width = 2
        local rect_r = ((width / 3) - line_width) / 2
        local center_x, center_y = 0.5 * width, 0.5 * height + rect_r
        local top_center_x, top_center_y = center_x, center_y - 2 * rect_r
        local right_center_x, right_center_y = center_x + 2 * rect_r, center_y
        local bottom_center_x, bottom_center_y = center_x, center_y
        local left_center_x, left_center_y = center_x - 2 * rect_r, center_y

        local top_base = rt.Rectangle(top_center_x - rect_r, top_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local top_outline = rt.Rectangle(top_center_x - rect_r, top_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local top_outline_outline = rt.Rectangle(top_center_x - rect_r, top_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local top_label_w, top_label_h = top_label:measure()
        top_label:fit_into(top_center_x - rect_r, top_center_y - 0.5 * top_label_h, 2 * rect_r, 2 * rect_r)

        local right_base = rt.Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_outline = rt.Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_outline_outline = rt.Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_label_w, right_label_h = right_label:measure()
        right_label:fit_into(right_center_x - rect_r, right_center_y - 0.5 * right_label_h, 2 * rect_r, 2 * rect_r)

        local bottom_base = rt.Rectangle(bottom_center_x - rect_r, bottom_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local bottom_outline = rt.Rectangle(bottom_center_x - rect_r, bottom_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local bottom_outline_outline = rt.Rectangle(bottom_center_x - rect_r, bottom_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local bottom_label_w, bottom_label_h = bottom_label:measure()
        bottom_label:fit_into(bottom_center_x - rect_r, bottom_center_y - 0.5 * bottom_label_h, 2 * rect_r, 2 * rect_r)

        local left_base = rt.Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_outline = rt.Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_outline_outline = rt.Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_label_w, left_label_h = left_label:measure()
        left_label:fit_into(left_center_x - rect_r, left_center_y - 0.5 * left_label_h, 2 * rect_r, 2 * rect_r)

        local corner_radius = 0.05 * width
        for base in range(top_base, right_base, bottom_base, left_base) do
            base:set_color(rt.Palette.GRAY_3)
            base:set_corner_radius(corner_radius)
        end

        for outline in range(top_outline, right_outline, bottom_outline, left_outline) do
            outline:set_is_outline(true)
            outline:set_color(rt.Palette.GRAY_7)
            outline:set_corner_radius(corner_radius)
            outline:set_line_width(line_width)
        end

        for outline_outline in range(top_outline_outline, right_outline_outline, bottom_outline_outline, left_outline_outline) do
            outline_outline:set_is_outline(true)
            outline_outline:set_color(rt.Palette.TRUE_WHITE)
            outline_outline:set_line_width(line_width + 3)
            outline_outline:set_corner_radius(corner_radius)
        end

        local outline_outline = rt.Rectangle(0, 0, width, width)
        outline_outline:set_color(rt.Palette.TRUE_WHITE)

        self._content = {
            top_outline_outline,
            right_outline_outline,
            bottom_outline_outline,
            left_outline_outline,

            top_base,
            top_outline,

            right_base,
            right_outline,

            bottom_base,
            bottom_outline,

            left_base,
            left_outline,

            top_label,
            right_label,
            bottom_label,
            left_label
        }

        self._draw = function()
            for drawable in values(self._content) do
                drawable:draw()
            end
        end
    end
end

--- @brief
function rt.KeybindingIndicator:create_from_keyboard_key(keyboard_key)
    meta.assert_enum_value(keyboard_key, rt.KeyboardKey)
    self:create_as_key(rt.keyboard_key_to_string(keyboard_key), keyboard_key == rt.KeyboardKey.SPACE)
end

--- @brief
function rt.KeybindingIndicator:create_from_gamepad_button(button)
    meta.assert_enum_value(button, rt.GamepadButton)
    if button == rt.GamepadButton.TOP then
        self:create_as_button(true, false, false, false)
    elseif button == rt.GamepadButton.RIGHT then
        self:create_as_button(false, true, false, false)
    elseif button == rt.GamepadButton.BOTTOM then
        self:create_as_button(false, false, true, false)
    elseif button == rt.GamepadButton.LEFT then
        self:create_as_button(false, false, false, true)
    elseif button == rt.GamepadButton.DPAD_UP then
        self:create_as_dpad(true, false, false, false)
    elseif button == rt.GamepadButton.DPAD_RIGHT then
        self:create_as_dpad(false, true, false, false)
    elseif button == rt.GamepadButton.DPAD_DOWN then
        self:create_as_dpad(false, false, true, false)
    elseif button == rt.GamepadButton.DPAD_LEFT then
        self:create_as_dpad(false, false, false, true)
    elseif button == rt.GamepadButton.LEFT_SHOULDER then
        self:create_as_l_or_r(true)
    elseif button == rt.GamepadButton.RIGHT_SHOULDER then
        self:create_as_l_or_r(false)
    elseif button == rt.GamepadButton.START then
        self:create_as_start_or_select(true)
    elseif button == rt.GamepadButton.SELECT then
        self:create_as_start_or_select(false)
    elseif button == rt.GamepadButton.LEFT_STICK then
        self:create_as_joystick(true)
    elseif button == rt.GamepadButton.RIGHT_STICK then
        self:create_as_joystick(false)
    else
        rt.warning("In rt.KeybindingIndicator:create_from_gamepad_button: Unhandled button `" .. button .. "`")
        self:create_as_button(false, false, false, false)
    end
end