rt.settings.keybinding_indicator = {
    font = rt.settings.font.default,
    font_size = rt.FontSize.SMALL
}

--- @class rt.KeybindingIndicator
rt.KeybindingIndicator = meta.class("KeybindingIndicator", rt.Widget)

local _Label = function(text, font_size)
    return rt.Label(text, rt.settings.keybinding_indicator.font, font_size or rt.settings.keybinding_indicator.font_size)
end

local _GRAY_3 = rt.Palette.GRAY_4
local _GRAY_4 = rt.Palette.GRAY_5
local _GRAY_5 = rt.Palette.GRAY_6
local _GRAY_6 = rt.Palette.GRAY_7
local _GRAY_7 = rt.Palette.GRAY_8
local _TRUE_WHITE = rt.Palette.TRUE_WHITE
local _WHITE = rt.Palette.WHITE

function rt.KeybindingIndicator:instantiate()
    meta.install(self, {
        _font = nil, -- rt.Font
        _draw = function() end,
        _final_width = 0,
        _initializer = function(self, width)  end
    })
end

local _Rectangle = function(x, y, width, height)  
    return {
        x = x,
        y = y,
        width = width,
        height = height,
        is_outline = false,
        line_width = 2,
        corner_radius = 0,
        color = _WHITE,
        
        draw = function(self)
            if self.is_outline then
                love.graphics.setLineWidth(self.line_width)
            end
            
            self.color:bind()
            love.graphics.rectangle(
                self.is_outline and "line" or "fill",
                self.x, self.y, self.width, self.height,
                self.corner_radius
            )
        end
    }
end

local _Ellipse = function(x, y, x_radius, y_radius)
    return {
        x = x,
        y = y,
        x_radius = x_radius,
        y_radius = y_radius or x_radius,
        is_outline = false,
        line_width = 2,
        color = _WHITE,

        draw = function(self)
            if self.is_outline then
                love.graphics.setLineWidth(self.line_width)
            end

            self.color:bind()
            love.graphics.ellipse(
                self.is_outline and "line" or "fill",
                self.x, self.y, self.x_radius, self.y_radius
            )
        end
    }
end

local _Polygon = function(first, ...)

    return {
        vertices = meta.is_table(first) and first or {first, ...},
        is_outline = false,
        line_width = 2,
        color = _WHITE,

        draw = function(self)
            if self.is_outline then
                love.graphics.setLineWidth(self.line_width)
            end

            self.color:bind()
            love.graphics.polygon(
                self.is_outline and "line" or "fill",
                self.vertices
            )
        end
    }
end

local _Line = function(first, ...)
    return {
        vertices = meta.is_table(first) and first or {first, ...},
        line_width = 2,
        color = _WHITE,

        draw = function(self)
            love.graphics.setLineWidth(self.line_width)
            self.color:bind()
            love.graphics.line(self.vertices)
        end
    }
end

local _color_highlight = _WHITE

--- @brief
local _gamepad_button_to_string = {
    ["y"] = "TOP",
    ["b"] = "RIGHT",
    ["a"] = "BOTTOM",
    ["x"] = "LEFT",
    ["dpup"] = "UP",
    ["dpdown"] = "DOWN",
    ["dpleft"] = "LEFT",
    ["dpright"] = "RIGHT",
    ["leftshoulder"] = "L",
    ["rightshoulder"] = "R",
    ["start"] = "START",
    ["back"] = "SELECT",
    ["home"] = "CENTER",
    ["lstick"] = "RIGHT STICK",
    ["rstick"] = "LEFT STRICK",
    ["paddle1"] = "PADDLE #1",
    ["paddle2"] = "PADDLE #2",
    ["paddle3"] = "PADDLE #3",
    ["paddle4"] = "PADDLE #4"
}

function rt.gamepad_button_to_string(gamepad_button)
    local raw = string.sub(gamepad_button, #rt.GamepadButtonPrefix + 1, #gamepad_button)
    local out = _gamepad_button_to_string[raw]
    if out == nil then return "UNKNOWN" else return out end
end

function rt.keyboard_key_to_string(keyboard_key)
    local res = keyboard_key
    
    local up_arrow = "\u{2191}"
    local down_arrow = "\u{2193}"
    local left_arrow = "\u{2190}"
    local right_arrow = "\u{2192}"
    local space_bar = "\u{2423}"
    local enter = "\u{21B5}"
    local backspace = "\u{232B}"

    if res == "ä" then return "Ä"
    elseif res == "ö" then return "Ö"
    elseif res == "ü" then return "Ü"
    elseif res == "up" then return up_arrow
    elseif res == "right" then return right_arrow
    elseif res == "down" then return down_arrow
    elseif res == "left" then return left_arrow
    elseif res == "space" then return space_bar
    elseif res == "return" then return enter
    elseif res == "backspace" then return backspace
    else
        return string.upper(res)
    end
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
        local button_r = (width - 2 * button_outer_m - button_inner_m) / 2.6

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

        local top_base, top_outline = _Ellipse(top_x, top_y, button_r), _Ellipse(top_x, top_y, button_r)
        local right_base, right_outline = _Ellipse(right_x, right_y, button_r), _Ellipse(right_x, right_y, button_r)
        local bottom_base, bottom_outline = _Ellipse(bottom_x, bottom_y, button_r), _Ellipse(bottom_x, bottom_y, button_r)
        local left_base, left_outline = _Ellipse(left_x, left_y, button_r), _Ellipse(left_x, left_y, button_r)

        local back_x_offset, back_y_offset = 3, 3
        local top_back, top_back_outline = _Ellipse(top_x + back_x_offset, top_y + back_y_offset, button_r), _Ellipse(top_x + back_x_offset, top_y + back_y_offset, button_r)
        local right_back, right_back_outline = _Ellipse(right_x + back_x_offset, right_y + back_y_offset, button_r), _Ellipse(right_x + back_x_offset, right_y + back_y_offset, button_r)
        local bottom_back, bottom_back_outline = _Ellipse(bottom_x + back_x_offset, bottom_y + back_y_offset, button_r), _Ellipse(bottom_x + back_x_offset, bottom_y + back_y_offset, button_r)
        local left_back, left_back_outline = _Ellipse(left_x + back_x_offset, left_y + back_y_offset, button_r), _Ellipse(left_x + back_x_offset, left_y + back_y_offset, button_r)

        local top_outline_outline = _Ellipse(top_x, top_y, button_r + outline_outline_width)
        local right_outline_outline = _Ellipse(right_x, right_y, button_r + outline_outline_width)
        local bottom_outline_outline = _Ellipse(bottom_x, bottom_y, button_r + outline_outline_width)
        local left_outline_outline = _Ellipse(left_x, left_y, button_r + outline_outline_width)

        local top_back_outline_outline = _Ellipse(top_x + back_x_offset, top_y + back_y_offset, button_r + outline_outline_width)
        local right_back_outline_outline = _Ellipse(right_x + back_x_offset, right_y + back_y_offset, button_r + outline_outline_width)
        local bottom_back_outline_outline = _Ellipse(bottom_x + back_x_offset, bottom_y + back_y_offset, button_r + outline_outline_width)
        local left_back_outline_outline = _Ellipse(left_x + back_x_offset, left_y + back_y_offset, button_r + outline_outline_width)

        local outline_width = 2
        local selection_inlay_radius = button_r --(button_r - outline_width) * 0.85
        local top_selection = _Ellipse(top_x, top_y, selection_inlay_radius)
        local right_selection = _Ellipse(right_x, right_y, selection_inlay_radius)
        local bottom_selection = _Ellipse(bottom_x, bottom_y, selection_inlay_radius)
        local left_selection = _Ellipse(left_x, left_y, selection_inlay_radius)

        for base in range(top_base, right_base, bottom_base, left_base) do
            base.color = _GRAY_3
        end

        for back in range(top_back, right_back, bottom_back, left_back) do
            back.color = _GRAY_5
        end

        for outline_outline in range(top_outline_outline, right_outline_outline, bottom_outline_outline, left_outline_outline, top_back_outline_outline, right_back_outline_outline, bottom_back_outline_outline, left_back_outline_outline) do
            outline_outline.color = _TRUE_WHITE
        end

        for selection in range(top_selection, right_selection, bottom_selection, left_selection) do
            selection.color = _WHITE
        end

        for outline in range(top_outline, right_outline, bottom_outline, left_outline, top_back_outline, right_back_outline, bottom_back_outline, left_back_outline) do
            outline.color = _GRAY_7
            outline.is_outline = true
            outline.line_width = outline_width
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
    return self
end

--- @brief
function rt.KeybindingIndicator:create_as_dpad(up_selected, right_selected, down_selected, left_selected)
    self._initializer = function(self, width)
        local x, y = 0, 0
        local height = width * 0.85
        local translate = rt.translate_point_by_angle
        local center_x, center_y = x + 0.5 * width, y + 0.5 * width

        local r = 0.5 * height - 5
        local m = 0.3 * height
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

        local top_base, top_outline = _Polygon(top), _Polygon(top)
        local right_base, right_outline = _Polygon(right), _Polygon(right)
        local bottom_base, bottom_outline = _Polygon(bottom), _Polygon(bottom)
        local left_base, left_outline = _Polygon(left), _Polygon(left)

        for base in range(top_base, right_base, bottom_base, left_base) do
            base.color = _GRAY_3
        end

        local selected_color = _WHITE
        if up_selected then top_base.color = selected_color end
        if right_selected then right_base.color = selected_color end
        if down_selected then bottom_base.color = selected_color end
        if left_selected then left_base.color = selected_color end

        for outline in range(top_outline, right_outline, bottom_outline, left_outline) do
            outline.color = _GRAY_7
            outline.is_outline = true
        end

        local corner_radius = 5

        local backlay_vertical = _Rectangle(top_left_x, top_left_y, m, 2 * r)
        local backlay_horizontal = _Rectangle(left_top_x, left_top_y, 2 * r, m)

        for backlay in range(backlay_horizontal, backlay_vertical) do
            backlay.color = _GRAY_5
            backlay.corner_radius = corner_radius
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

        local backlay_outline_vertical = _Rectangle(top_left_x, top_left_y, m, 2 * r)
        local backlay_outline_horizontal = _Rectangle(left_top_x, left_top_y, 2 * r, m)

        local backlay_outline_outline_vertical = _Rectangle(top_left_x, top_left_y, m, 2 * r)
        local backlay_outline_outline_horizontal = _Rectangle(left_top_x, left_top_y, 2 * r, m)

        for backlay_outline in range(backlay_outline_vertical, backlay_outline_horizontal) do
            backlay_outline.color = _GRAY_7
            backlay_outline.is_outline = true
            backlay_outline.line_width = 5
            backlay_outline.corner_radius = corner_radius
        end

        for outline_outline in range(backlay_outline_outline_vertical, backlay_outline_outline_horizontal) do
            outline_outline.color = _TRUE_WHITE
            outline_outline.line_width = 8
            outline_outline.corner_radius = corner_radius
            outline_outline.is_outline = true
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
    return self
end

--- @brief
function rt.KeybindingIndicator:create_as_start_or_select(start_or_select)
    self._initializer = function(self, width)
        local x, y = 0, 0
        local height = width

        local w = 0.9 * width / 1.2
        local h = 0.4 * height / 1.2

        local center_x, center_y = x + 0.5 * width, y + 0.5 * height
        local base = _Rectangle(center_x - 0.5 * w, center_y - 0.5 * h, w, h)
        local base_outline = _Rectangle(center_x - 0.5 * w, center_y - 0.5 * h, w, h)
        local base_outline_outline = _Rectangle(center_x - 0.5 * w, center_y - 0.5 * h, w, h)

        for rectangle in range(base, base_outline, base_outline_outline) do
            rectangle.corner_radius = h / 2
        end

        base.color = _GRAY_3
        base_outline.color = _GRAY_7
        base_outline.is_outline = true
        base_outline.line_width = 2

        base_outline_outline.color = _TRUE_WHITE
        base_outline_outline.is_outline = true
        base_outline_outline.line_width = 5

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

            right_triangle = _Polygon(vertices)
            right_triangle_outline = _Polygon(vertices)
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

            left_triangle = _Polygon(vertices)
            left_triangle_outline = _Polygon(vertices)
        end

        for triangle in range(left_triangle, right_triangle) do
            triangle.color = _TRUE_WHITE
        end

        for triangle_outline in range(left_triangle_outline, right_triangle_outline) do
            triangle_outline.color = _GRAY_7
            triangle_outline.is_outline = true
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
    return self
end

--- @brief
function rt.KeybindingIndicator:create_as_l_or_r(l_or_r)
    self._initializer = function(self, width)
        local x, y, height = 0, 0, width
        local label
        if l_or_r == true then
            label = _Label("<o>L</o>")
        else
            label = _Label("<o>R</o>")
        end

        label:realize()
        label:set_justify_mode(rt.JustifyMode.CENTER)
        local label_w, label_h = label:measure()
        label:reformat(0, y + 0.5 * height - 0.5 * label_h, width, height)

        local center_x, center_y = x + 0.55 * width , y + 0.5 * height
        local rect_w, rect_h = 0.75 * width, 0.45 * width
        local rect_base_x, rect_base_y = center_x - 0.5 * rect_w, center_y - 0.5 * rect_h
        local rectangle_base = _Rectangle(rect_base_x, rect_base_y, rect_w, rect_h)
        local rectangle_base_outline = _Rectangle(rect_base_x, rect_base_y, rect_w, rect_h)
        local rectangle_base_outline_outline = _Rectangle(rect_base_x, rect_base_y, rect_w, rect_h)

        local outline_width = 2
        rectangle_base.color = _GRAY_4
        rectangle_base_outline.color = _GRAY_7
        rectangle_base_outline.line_width = outline_width
        rectangle_base_outline_outline.color = _TRUE_WHITE
        rectangle_base_outline_outline.line_width = outline_width + 4

        for outline in range(rectangle_base_outline, rectangle_base_outline_outline) do
            outline.is_outline = true
        end

        local corner_radius = 0.2 * rect_h
        for rect in range(rectangle_base, rectangle_base_outline, rectangle_base_outline_outline) do
            rect.corner_radius = corner_radius
        end

        local polygon_last_y_offset = 0.02 * height
        local bezier = love.math.newBezierCurve(
            rect_base_x + corner_radius + polygon_last_y_offset, rect_base_y,
            rect_base_x + rect_w, rect_base_y,
            rect_base_x + rect_w, rect_base_y + rect_h - corner_radius
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

        local curve_outline = _Line(polygon_points)
        local curve_outline_outline = _Line(polygon_points)

        curve_outline.line_width = outline_width
        curve_outline_outline.line_width = outline_width + 4
        curve_outline.color = _GRAY_7
        curve_outline_outline.color = _TRUE_WHITE

        local polygon = _Polygon({
            rect_base_x + corner_radius - 2 * polygon_last_y_offset, rect_base_y + rect_h - corner_radius + polygon_last_y_offset,
            table.unpack(polygon_points)
        })
        polygon.color = _GRAY_4

        local stencil_padding = corner_radius + outline_width
        local stencil_points = { table.unpack(polygon_points) }

        for p in range(rect_base_y - 2 * outline_width, polygon_points[1] + 2 * outline_width) do
            table.insert(stencil_points, 1, p)
        end

        stencil_points[#stencil_points - 1] = stencil_points[#stencil_points - 1] + 4 * outline_width
        for p in range(
            polygon_points[#polygon_points - 1] + 4 * outline_width, rect_base_y - 2 * outline_width,
            rect_base_x + 4 * outline_width, rect_base_y - 2 * outline_width
        ) do
            table.insert(stencil_points, p)
        end


        local stencil = slick.triangulate({ stencil_points })

        local flip_x = 0.5 * width
        self._draw = function()
            if l_or_r == true then
                love.graphics.push()
                love.graphics.translate(flip_x, 0)
                love.graphics.scale(-1, 1)
                love.graphics.translate(-flip_x, 0)
            end

            polygon:draw()
            curve_outline_outline:draw()

            local value = rt.graphics.get_stencil_value()
            rt.graphics.stencil(value, function()
            love.graphics.setColor(1, 1, 1, 1)
                for tri in values(stencil) do
                    love.graphics.polygon("fill", tri)
                end
            end)
            rt.graphics.set_stencil_test(rt.StencilCompareMode.NOT_EQUAL, value)
            rectangle_base_outline_outline:draw()
            rectangle_base:draw()
            rectangle_base_outline:draw()
            rt.graphics.set_stencil_test(nil)

            curve_outline:draw()

            if l_or_r == true then
                love.graphics.pop()
            end

            label:draw()

            for tri in values(stencil) do
                --love.graphics.polygon("fill", tri)
            end
        end
    end

    if self._is_realized then self:reformat() end
    return self
end

--- @brief
function rt.KeybindingIndicator:_as_joystick(left_or_right, width)
    local radius = 0.8 * width / 2
    local x, y, height = 0, 0, width
    local center_x, center_y = x + 0.5 * width, y + 0.5 * height

    local base_x, base_y, base_radius = center_x, center_y, radius * 0.7
    local base = _Ellipse(base_x, base_y, base_radius)
    local base_outline = _Ellipse(base_x, base_y, base_radius)
    local base_outline_outline = _Ellipse(base_x, base_y, base_radius)

    base_outline.is_outline = true
    base_outline_outline.is_outline = true

    local outline_width = 2

    base.color = _GRAY_5
    base_outline.color = _GRAY_7
    base_outline.line_width = outline_width
    base_outline_outline.color = _TRUE_WHITE
    base_outline_outline.line_width = outline_width + 3

    local neck_center_x, neck_center_y, neck_width, neck_height = center_x, center_y, 0.25 * width, 0.25 * height
    local neck_base = _Rectangle(neck_center_x - 0.5 * neck_width, neck_center_y - neck_height, neck_width, neck_height)
    local neck_outline_left = _Line(neck_center_x - 0.5 * neck_width, neck_center_y, neck_center_x - 0.5 * neck_width, neck_center_y - neck_height)
    local neck_outline_right = _Line(neck_center_x + 0.5 * neck_width, neck_center_y, neck_center_x + 0.5 * neck_width, neck_center_y - neck_height)
    local neck_outline_outline_left = _Line(neck_center_x - 0.5 * neck_width, neck_center_y, neck_center_x - 0.5 * neck_width, neck_center_y - neck_height)
    local neck_outline_outline_right = _Line(neck_center_x + 0.5 * neck_width, neck_center_y, neck_center_x + 0.5 * neck_width, neck_center_y - neck_height)
    local neck_foot = _Ellipse(neck_center_x, neck_center_y, neck_width * 0.5)
    local neck_foot_outline = _Ellipse(neck_center_x, neck_center_y, neck_width * 0.5)

    local head_x, head_y, head_x_radius, head_y_radius = center_x, center_y - neck_height, base_radius * 1.15, base_radius * 1.15 * 0.75
    local head_base = _Ellipse(head_x, head_y, head_x_radius, head_y_radius)
    local head_outline = _Ellipse(head_x, head_y, head_x_radius, head_y_radius)
    local head_outline_outline = _Ellipse(head_x, head_y, head_x_radius, head_y_radius)

    local inlay_ratio = 0.7
    local head_inlay = _Ellipse(head_x, head_y - 0.075 * head_y_radius, head_x_radius * inlay_ratio, head_y_radius * inlay_ratio)

    local label
    if left_or_right == true then
        label = _Label("<o>L</o>")
    else
        label = _Label("<o>R</o>")
    end

    label:realize()
    label:set_justify_mode(rt.JustifyMode.CENTER)
    local label_w, label_h = label:measure()
    label:reformat(0, y + 0.5 * height - 0.5 * label_h - head_y, width, height)

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
    local down_indicator = _Polygon(indicator_vertices)
    local down_indicator_outline = _Polygon(indicator_vertices)
    down_indicator_outline.is_outline = true

    head_base.color = _GRAY_3
    head_outline.color = _GRAY_7
    head_outline.is_outline = true
    head_outline_outline.is_outline = true
    head_outline.line_width = outline_width
    head_outline_outline.line_width = outline_width + 3
    head_inlay.color = _GRAY_5

    for neck in range(neck_base, neck_foot) do
        neck.color = _GRAY_5:clone()
        local darken = -0.1
        neck.color.r = neck.color.r - darken
        neck.color.g = neck.color.g - darken
        neck.color.b = neck.color.b - darken
    end

    for outline in range(neck_outline_left, neck_outline_right, neck_foot_outline, down_indicator_outline) do
        outline.color = _GRAY_7
        outline.line_width = outline_width
    end

    neck_foot_outline.is_outline = true

    for outline in range(neck_outline_outline_left, neck_outline_outline_right, head_outline_outline) do
        outline.color = _TRUE_WHITE
        outline.line_width = outline_width + 3
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
        local base = _Ellipse(base_x, base_y, base_radius)
        local base_outline = _Ellipse(base_x, base_y, base_radius)
        local base_outline_outline = _Ellipse(base_x, base_y, base_radius)

        base_outline.is_outline = true
        base_outline_outline.is_outline = true

        local outline_width = 2

        base.color = _GRAY_4
        base_outline.color = _GRAY_7
        base_outline.line_width = outline_width
        base_outline_outline.color = _TRUE_WHITE
        base_outline_outline.line_width = outline_width + 3

        local neck_center_x, neck_center_y, neck_width, neck_height = center_x, center_y, 0.25 * width, 0.25 * height
        local neck_base = _Rectangle(neck_center_x - 0.5 * neck_width, neck_center_y - neck_height, neck_width, neck_height)
        local neck_outline_left = _Line(neck_center_x - 0.5 * neck_width, neck_center_y, neck_center_x - 0.5 * neck_width, neck_center_y - neck_height)
        local neck_outline_right = _Line(neck_center_x + 0.5 * neck_width, neck_center_y, neck_center_x + 0.5 * neck_width, neck_center_y - neck_height)
        local neck_outline_outline_left = _Line(neck_center_x - 0.5 * neck_width, neck_center_y, neck_center_x - 0.5 * neck_width, neck_center_y - neck_height)
        local neck_outline_outline_right = _Line(neck_center_x + 0.5 * neck_width, neck_center_y, neck_center_x + 0.5 * neck_width, neck_center_y - neck_height)
        local neck_foot = _Ellipse(neck_center_x, neck_center_y, neck_width * 0.5)
        local neck_foot_outline = _Ellipse(neck_center_x, neck_center_y, neck_width * 0.5)

        local head_x, head_y, head_x_radius, head_y_radius = center_x, center_y - neck_height, base_radius * 1.15, base_radius * 1.15 * 0.75
        local head_base = _Ellipse(head_x, head_y, head_x_radius, head_y_radius)
        local head_outline = _Ellipse(head_x, head_y, head_x_radius, head_y_radius)
        local head_outline_outline = _Ellipse(head_x, head_y, head_x_radius, head_y_radius)

        local inlay_ratio = 0.7
        local head_inlay = _Ellipse(head_x, head_y - 0.075 * head_y_radius, head_x_radius * inlay_ratio, head_y_radius * inlay_ratio)

        local label
        if left_or_right == true then
            label = _Label("<o>L</o>")
        else
            label = _Label("<o>R</o>")
        end

        label:realize()
        label:set_justify_mode(rt.JustifyMode.CENTER)
        local label_w, label_h = label:measure()
        label:reformat(0, y + 0.5 * height - 0.5 * label_h - head_y + y_offset, width, height)

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
        local down_indicator = _Polygon(indicator_vertices)
        local down_indicator_outline = _Polygon(indicator_vertices)
        down_indicator_outline.is_outline = true

        head_base.color = _GRAY_3
        head_outline.color = _GRAY_7
        head_outline.is_outline = true
        head_outline_outline.is_outline = true
        head_outline.line_width = outline_width
        head_outline_outline.line_width = outline_width + 3
        head_inlay.color = _GRAY_4

        for neck in range(neck_base, neck_foot) do
            neck.color = neck.color:clone()
            local darken = 0.1
            neck.color.r = neck.color.r - darken
            neck.color.g = neck.color.g - darken
            neck.color.b = neck.color.b - darken
        end

        for outline in range(neck_outline_left, neck_outline_right, neck_foot_outline, down_indicator_outline) do
            outline.color = _GRAY_7
            outline.line_width = outline_width
        end

        neck_foot_outline.is_outline = true

        for outline in range(neck_outline_outline_left, neck_outline_outline_right, head_outline_outline) do
            outline.color = _TRUE_WHITE
            outline.line_width = outline_width + 3
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
    return self
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

        local outer = _Rectangle(outer_x, outer_y, outer_w, outer_h)
        local outer_outline = _Rectangle(outer_x - 1, outer_y - 1, outer_w + 2, outer_h + 2)

        local inner_x, inner_y = outer_x + left_trapezoid_w, outer_y + top_trapezoid_h
        local inner_padding = 0.005 * outer_w
        local inner = _Rectangle(inner_x - inner_padding, inner_y - inner_padding, inner_w + 2 * inner_padding, inner_h + 2 * inner_padding)
        local inner_outline = _Rectangle(inner_x - inner_padding, inner_y - inner_padding, inner_w + 2 * inner_padding, inner_h + 2 * inner_padding)

        for rectangle in range(outer, inner, outer_outline, inner_outline) do
            rectangle.corner_radius = 4
        end

        outer.color = _GRAY_5
        inner.color = _GRAY_3

        local top_trapezoid = _Polygon(
            outer_x, outer_y,
            outer_x + outer_w, outer_y,
            inner_x + inner_w, inner_y,
            inner_x, inner_y
        )

        local top_outline = _Polygon(
            outer_x, outer_y,
            outer_x + outer_w, outer_y,
            inner_x + inner_w, inner_y,
            inner_x, inner_y
        )

        local right_trapezoid = _Polygon(
            outer_x + outer_w, outer_y,
            outer_x + outer_w, outer_y + outer_h,
            inner_x + inner_w, inner_y + inner_h,
            inner_x + inner_w, inner_y
        )

        local right_outline = _Polygon(
            outer_x + outer_w, outer_y,
            outer_x + outer_w, outer_y + outer_h,
            inner_x + inner_w, inner_y + inner_h,
            inner_x + inner_w, inner_y
        )

        local bottom_trapezoid = _Polygon(
            inner_x, inner_y + inner_h,
            inner_x + inner_w, inner_y + inner_h,
            outer_x + outer_w, outer_y + outer_h,
            outer_x, outer_y + outer_h
        )

        local bottom_outline = _Polygon(
            inner_x, inner_y + inner_h,
            inner_x + inner_w, inner_y + inner_h,
            outer_x + outer_w, outer_y + outer_h,
            outer_x, outer_y + outer_h
        )

        local left_trapezoid = _Polygon(
            outer_x, outer_y,
            inner_x, inner_y,
            inner_x, inner_y + inner_h,
            outer_x, outer_y + outer_h
        )

        local left_outline = _Polygon(
            outer_x, outer_y,
            inner_x, inner_y,
            inner_x, inner_y + inner_h,
            outer_x, outer_y + outer_h
        )

        outer_outline.is_outline = true
        outer_outline.line_width = 1
        outer_outline.color = _TRUE_WHITE

        inner_outline.is_outline = true
        inner_outline.line_width = 2
        inner_outline.is_outline = true
        inner_outline.color = _GRAY_6

        top_trapezoid.color = _GRAY_5
        local r1, g1, b1, a1 = _GRAY_5:unpack()
        local r2, g2, b2, a2 = _GRAY_6:unpack()
        bottom_trapezoid.color = rt.RGBA(math.mix4(r1, g1, b1, a1, r2, g2, b2, a2, 0.5))
        left_trapezoid.color = _GRAY_5
        right_trapezoid.color = _GRAY_5

        for outline in range(top_outline, right_outline, bottom_outline, left_outline) do
            outline.color = _GRAY_7
            outline.is_outline = true
            outline.line_width = 2
        end

        local font = nil
        local label = _Label("<o>" .. text .. "</o>")
        label:set_justify_mode(rt.JustifyMode.CENTER)
        label:realize()
        local label_w, label_h = label:measure()
        label:reformat(0, y + 0.5 * height - 0.5 * label_h - y_offset, width, label_h)

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
    return self
end

--- @brief
function rt.KeybindingIndicator:create_as_two_horizontal_keys(left_text, right_text)
    self._initializer = function(self, width)
        local x, y, height = 0, 0, width
        local radius = 0.5 * width / 2

        local right_label = _Label("<o>" .. right_text .. "</o>", rt.FontSize.SMALL)
        local left_label = _Label("<o>" .. left_text .. "</o>", rt.FontSize.SMALL)

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

        local right_base = _Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_outline = _Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_outline_outline = _Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_label_w, right_label_h = right_label:measure()
        right_label:reformat(right_center_x - rect_r, right_center_y - 0.5 * right_label_h, 2 * rect_r, 2 * rect_r)

        local left_base = _Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_outline = _Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_outline_outline = _Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_label_w, left_label_h = left_label:measure()
        left_label:reformat(left_center_x - rect_r, left_center_y - 0.5 * left_label_h, 2 * rect_r, 2 * rect_r)

        local corner_radius = 0.05 * width
        for base in range(right_base, left_base) do
            base.color = _GRAY_3
            base.corner_radius = corner_radius
        end

        for outline in range(right_outline, left_outline) do
            outline.is_outline = true
            outline.color = _GRAY_7
            outline.corner_radius = corner_radius
            outline.line_width = line_width
        end

        for outline_outline in range(right_outline_outline, left_outline_outline) do
            outline_outline.is_outline = true
            outline_outline.color = _TRUE_WHITE
            outline_outline.line_width = line_width + 3
            outline_outline.corner_radius = corner_radius
        end

        local outline_outline = _Rectangle(0, 0, width, width)
        outline_outline.color = _TRUE_WHITE

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

        local top_label = _Label("<o>" .. up_text .. "</o>", rt.FontSize.SMALL)
        local right_label = _Label("<o>" .. right_text .. "</o>", rt.FontSize.SMALL)
        local bottom_label = _Label("<o>" .. bottom_text .. "</o>", rt.FontSize.SMALL)
        local left_label = _Label("<o>" .. left_text .. "</o>", rt.FontSize.SMALL)

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

        local top_base = _Rectangle(top_center_x - rect_r, top_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local top_outline = _Rectangle(top_center_x - rect_r, top_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local top_outline_outline = _Rectangle(top_center_x - rect_r, top_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local top_label_w, top_label_h = top_label:measure()
        top_label:reformat(top_center_x - rect_r, top_center_y - 0.5 * top_label_h, 2 * rect_r, 2 * rect_r)

        local right_base = _Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_outline = _Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_outline_outline = _Rectangle(right_center_x - rect_r, right_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local right_label_w, right_label_h = right_label:measure()
        right_label:reformat(right_center_x - rect_r, right_center_y - 0.5 * right_label_h, 2 * rect_r, 2 * rect_r)

        local bottom_base = _Rectangle(bottom_center_x - rect_r, bottom_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local bottom_outline = _Rectangle(bottom_center_x - rect_r, bottom_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local bottom_outline_outline = _Rectangle(bottom_center_x - rect_r, bottom_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local bottom_label_w, bottom_label_h = bottom_label:measure()
        bottom_label:reformat(bottom_center_x - rect_r, bottom_center_y - 0.5 * bottom_label_h, 2 * rect_r, 2 * rect_r)

        local left_base = _Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_outline = _Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_outline_outline = _Rectangle(left_center_x - rect_r, left_center_y - rect_r, 2 * rect_r, 2 * rect_r)
        local left_label_w, left_label_h = left_label:measure()
        left_label:reformat(left_center_x - rect_r, left_center_y - 0.5 * left_label_h, 2 * rect_r, 2 * rect_r)

        local corner_radius = 0.05 * width
        for base in range(top_base, right_base, bottom_base, left_base) do
            base.color = _GRAY_3
            base.corner_radius = corner_radius
        end

        for outline in range(top_outline, right_outline, bottom_outline, left_outline) do
            outline.is_outline = true
            outline.color = _GRAY_7
            outline.corner_radius = corner_radius
            outline.line_width = line_width
        end

        for outline_outline in range(top_outline_outline, right_outline_outline, bottom_outline_outline, left_outline_outline) do
            outline_outline.is_outline = true
            outline_outline.color = _TRUE_WHITE
            outline_outline.line_width = line_width + 3
            outline_outline.corner_radius = corner_radius
        end

        local outline_outline = _Rectangle(0, 0, width, width)
        outline_outline.color = _TRUE_WHITE

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
    return self:create_as_key(rt.keyboard_key_to_string(keyboard_key), keyboard_key == "space")
end

--- @brief
function rt.KeybindingIndicator:create_from_gamepad_button(button)
    if button == rt.GamepadButton.TOP then
        return self:create_as_button(true, false, false, false)
    elseif button == rt.GamepadButton.RIGHT then
        return self:create_as_button(false, true, false, false)
    elseif button == rt.GamepadButton.BOTTOM then
        return self:create_as_button(false, false, true, false)
    elseif button == rt.GamepadButton.LEFT then
        return self:create_as_button(false, false, false, true)
    elseif button == rt.GamepadButton.DPAD_UP then
        return self:create_as_dpad(true, false, false, false)
    elseif button == rt.GamepadButton.DPAD_RIGHT then
        return self:create_as_dpad(false, true, false, false)
    elseif button == rt.GamepadButton.DPAD_DOWN then
        return self:create_as_dpad(false, false, true, false)
    elseif button == rt.GamepadButton.DPAD_LEFT then
        return self:create_as_dpad(false, false, false, true)
    elseif button == rt.GamepadButton.LEFT_SHOULDER then
        return self:create_as_l_or_r(true)
    elseif button == rt.GamepadButton.RIGHT_SHOULDER then
        return self:create_as_l_or_r(false)
    elseif button == rt.GamepadButton.START then
        return self:create_as_start_or_select(true)
    elseif button == rt.GamepadButton.SELECT then
        return self:create_as_start_or_select(false)
    elseif button == rt.GamepadButton.LEFT_STICK then
        return self:create_as_joystick(true)
    elseif button == rt.GamepadButton.RIGHT_STICK then
        return self:create_as_joystick(false)
    else
        return self:create_as_button(false, false, false, false)
    end
end