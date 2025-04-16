require "common.widget"

rt.settings.sprite = {
    default_fps = 12
}

--- @class Sprite
rt.Sprite = meta.class("Sprite", rt.Widget)

rt.Sprite._path_to_spritesheet = {} -- spritsheet atlas

--- @brief construct sprite from uniform grid
--- @param path string path to spritesheet
--- @param n_columns number? number of sprite columns
--- @param n_rows number? number of sprite rows
--- @param border_x number? horizontal border, applied to both ends
--- @param border_y number? vertical border, applied to both ends
function rt.Sprite:instantiate(path, n_columns, n_rows, border_x, border_y)
    if n_columns == nil then n_columns = 1 end
    if n_rows == nil then n_rows = 1 end

    if border_x == nil then border_x = 0 end
    if border_y == nil then border_y = border_x end

    meta.assert(
        path, "String",
        n_columns, "Number",
        n_rows, "Number",
        border_x, "Number",
        border_y, "Number"
    )

    local image = rt.Sprite._path_to_spritesheet[path]
    if image == nil then
        image = love.graphics.newImage(path)
        image:setFilter("nearest", "nearest")
        rt.Sprite._path_to_spritesheet[path] = image
    end

    local image_w, image_h = image:getDimensions()
    meta.install(self, {
        _image = image, -- love.Image
        _n_rows = n_rows,
        _n_columns = n_columns,

        _frame_width = image_w / n_columns,
        _frame_height = image_h / n_rows,
        _border_x = border_x,
        _border_y = border_y,

        _x = 0, -- xy position
        _y = 0,

        _scale = rt.settings.sprite_scale, -- scale around origin

        _is_animated = false,   -- whether `update` should loop through frames
        _elapsed = 0, -- elapsed time, does not flow linearly

        _should_loop = true, -- should animation loop
        _reverse_on_final_frame_reached = false, -- should animation ping pong when reaching end of loop
        _frame_start_linear_i = 1, -- first frame
        _frame_end_linear_i = n_rows * n_columns, -- last frame

        _flip_horizontally = false,
        _flip_vertically = false,
        _is_reversed = false, -- whether time flows forwards or backwards

        _current_frame = 1, -- current frame linear index
        _fps = rt.settings.sprite.default_fps,

        _frame_data = {}, -- data that holds position of each frame
        _use_custom_frame_data = false
    })

    -- construct default layout, assumes uniform grid
    local frame_data = {}
    for row_i = 1, n_rows do
        for column_i = 1, n_columns do
            local x = (column_i - 1) * self._frame_width + border_x
            local y = (row_i - 1) * self._frame_height + border_y
            table.insert(frame_data, {
                x = x,
                y = y,
                width = self._frame_width,
                height = self._frame_width,
                border_x = border_x,
                border_y = border_y,
                quad = love.graphics.newQuad(
                    x, y,
                    self._frame_width - 2 * border_x, self._frame_height - 2 * border_y,
                    image_w, image_h
                )
            })
        end
    end

    self._frame_data = frame_data
end

--- @brief draw sprite at offset with scaling
function rt.Sprite:draw(x, y, angle, scale_x, scale_y, origin_x, origin_y)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if angle == nil then angle = 0 end
    if scale_x == nil then scale_x = 1 end
    if scale_y == nil then scale_y = 1 end
    -- origin can be nil

    love.graphics.push()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.translate(self._x, self._y)

    local quad = self._frame_data[self._current_frame].quad

    local frame_w, frame_h = self._frame_width * self._scale, self._frame_height * self._scale

    -- flip around center
    if self._flip_horizontally == true or self._flip_vertically == true then
        local quad_width = frame_w - 2 * self._border_x * self._scale
        local quad_height = frame_h - 2 * self._border_y * self._scale
        local center_x = x + quad_width / 2
        local center_y = y + quad_height / 2

        love.graphics.translate(center_x, center_y)
        if self._flip_horizontally then
            love.graphics.scale(-1, 1)
        end
        if self._flip_vertically then
            love.graphics.scale(1, -1)
        end
        love.graphics.translate(-center_x, -center_y)
    end

    love.graphics.draw(self._image, quad, x, y, angle, self._scale * scale_x, self._scale * scale_y, origin_x, origin_y)
    love.graphics.pop()
end

--- @brief update animation, unless `setIsAnimated` is false
function rt.Sprite:update(delta)
    assert(type(delta) == "number")

    ::restart::
    if self._is_reversed then delta = -1 * delta end

    local before = self._elapsed
    self._elapsed = self._elapsed + delta

    local frame_duration = 1 / self._fps
    local start = self._frame_start_linear_i
    local n_frames = self._frame_end_linear_i - self._frame_start_linear_i
    if n_frames <= 0 then n_frames = 1 end

    local offset = math.round(self._elapsed / frame_duration)

    if self._should_loop == true then
        if self._reverse_on_final_frame_reached then
            if self._is_reversed then
                if start + offset < self._frame_start_linear_i then
                    self._is_reversed = not self._is_reversed
                    return
                end
            else
                if start + offset > self._frame_end_linear_i then
                    self._is_reversed = not self._is_reversed
                    return
                end
            end
        else
            offset = offset % (n_frames + 1)
        end
    end

    self._current_frame = start + offset
    if self._should_loop == false then
        if self._current_frame < self._frame_start_linear_i then
            self._current_frame = self._frame_start_linear_i
            self._elapsed = before
        end

        if self._current_frame > math.max(self._frame_start_linear_i, self._frame_end_linear_i) then
            self._current_frame = math.max(self._frame_start_linear_i, self._frame_end_linear_i)
            self._elapsed = before
        end
    end
end

--- @brief set sprite top left
function rt.Sprite:set_position(x, y)
    assert(type(x) == "number" and type(y) == "number")
    self._x = math.floor(x)
    self._y = math.floor(y)
end

--- @brief get sprite top left
function rt.Sprite:get_position()
    return self._x, self._y
end

--- @brief set fps for entire spritesheet
function rt.Sprite:set_fps(fps)
    assert(type(fps) == "number")
    self._fps = fps
end

--- @brief get fps for entire spritesheet
function rt.Sprite:get_fps()
    return self._fps
end

--- @brief set first frame of animation
--- @param column_i number column index of spritesheet
--- @param row_i number row index
--- @param reset boolean? whether the current frame should jumpt to new first frame
function rt.Sprite:set_first_frame(linear_i_or_column_i, row_i, reset)
    if reset == nil then reset = false end

    if self._use_custom_frame_data == true then
        assert(row_i == nil, "In rt.Sprite:setFirstFrame: expected only 1 linear index, because `overrideFrameData` replaced the column-row-indexing")
    end

    assert(type(linear_i_or_column_i) == "number")
    if row_i == nil then
        local linear_i = linear_i_or_column_i
        assert(linear_i >= 1 and linear_i <= (self._n_rows * self._n_columns))
        self._frame_start_linear_i = linear_i
    else
        -- assert indices are in bounds
        local column_i = linear_i_or_column_i
        assert(type(row_i) == "number")
        assert(column_i >= 1 and column_i <= self._n_columns)
        assert(row_i >= 1 and row_i <= self._n_rows)
        self._frame_start_linear_i = (row_i - 1) * self._n_columns + linear_i_or_column_i -- convert 2d to linear index
    end

    self._current_frame = math.clamp(self._current_frame, self._frame_start_linear_i, self._frame_end_linear_i)
    if reset then self._current_frame = self._frame_start_linear_i end
end

--- @brief get first frame
--- @return number, number column_i, row_i
function rt.Sprite:get_first_frame()
    if self._use_custom_frame_data == true then return self._frame_start_linear_i end

    local column = (self._frame_start_linear_i % self._n_columns) + 1
    local row = math.floor(self._frame_start_linear_i / self._n_columns) + 1
    return column, row
end

--- @brief set last frame of animation
--- @param column_i number column index of spritesheet
--- @param row_i number row index
function rt.Sprite:set_last_frame(linear_i_or_column_i, row_i)
    if self._use_custom_frame_data == true then
        assert(row_i == nil, "In rt.Sprite:setFirstFrame: expected only 1 linear index, because `overrideFrameData` replaced the column-row-indexing")
    end

    assert(type(linear_i_or_column_i) == "number")
    if row_i == nil then
        local linear_i = linear_i_or_column_i
        assert(linear_i >= 1 and linear_i <= (self._n_rows * self._n_columns))
        self._frame_end_linear_i = linear_i
    else
        -- assert indices are in bounds
        local column_i = linear_i_or_column_i
        assert(type(row_i) == "number")
        assert(column_i >= 1 and column_i <= self._n_columns)
        assert(row_i >= 1 and row_i <= self._n_rows)
        self._frame_end_linear_i = (row_i - 1) * self._n_columns + linear_i_or_column_i -- convert 2d to linear index
    end

    if self._frame_end_linear_i < self._frame_start_linear_i then
        local log = require "log"
        log.warning("In rt.Sprite:setLastFrame: last frame index `" .. self._frame_end_linear_i .. "` is now smaller than first frame index `" .. self._frame_start_linear_i .. "`")
        self._frame_end_linear_i = self._frame_start_linear_i
    end

    self._current_frame = math.clamp(self._current_frame, self._frame_start_linear_i, self._frame_end_linear_i)
end

--- @brief get last frame
--- @return number, number column_i, row_i
function rt.Sprite:get_last_frame()
    if self._use_custom_frame_data == true then return self._frame_end_linear_i end

    local column = (self._frame_end_linear_i % self._n_columns) + 1
    local row = math.floor(self._frame_end_linear_i / self._n_columns) + 1
    return column, row
end

--- @brief get number of rows in spritesheet
function rt.Sprite:get_row_count()
    return self._n_rows
end

--- @brief get number of columns in spritesheet
function rt.Sprite:get_column_count()
    return self._n_columns
end

--- @brief set whether animation should loop
function rt.Sprite:set_should_loop(b)
    assert(type(b) == "boolean")
    self._should_loop = b
end

--- @brief get whether animation should loop
function rt.Sprite:get_should_loop()
    return self._should_loop
end

--- @brief set whether animation should run backwards
function rt.Sprite:set_is_reversed(b)
    assert(type(b) == "boolean")
    self._is_reversed = b
end

--- @brief get whether animation should run backwards
function rt.Sprite:get_is_reversed()
    return self._is_reversed
end

--- @brief set whether animation should reverse when it reaches the first / last frame
function rt.Sprite:set_reverse_on_final_frame_reached(b)
    assert(type(b) == "boolean")
    self._reverse_on_final_frame_reached = b
end

--- @brief get whether animation should reverse when it reaches the first / last frame
function rt.Sprite:get_reverse_on_final_frame_reached()
    return self._reverse_on_final_frame_reached
end

--- @brief set whether update should advance the current frame
function rt.Sprite:set_is_animated(b)
    assert(type(b) == "boolean")
    self._is_animated = b
end

--- @brief get whether update should advance the current frame
function rt.Sprite:get_is_animated()
    return self._is_animated
end

--- @brief set whether sprite should be flipped along the x-axis when rendering
function rt.Sprite:set_flip_horizontally(b)
    assert(type(b) == "boolean")
    self._flip_horizontally = b
end

--- @brief get whether sprite should be flipped along the x-axis when rendering
function rt.Sprite:get_flip_horizontally()
    return self._flip_horizontally
end

--- @brief set whether sprite should be flipped along the x-axis when rendering
function rt.Sprite:set_flip_vertically(b)
    assert(type(b) == "boolean")
    self._flip_vertically = b
end

--- @brief get whether sprite should be flipped along the x-axis when rendering
function rt.Sprite:get_flip_vertically()
    return self._flip_vertically
end

--- @brief get frame dimension, in px
function rt.Sprite:get_size()
    return self._frame_width * self._scale, self._frame_height * self._scale
end

local _scale_warning_printed = false

--- @brief set scale, increases sprite size around the origin
function rt.Sprite:set_scale(scale)
    assert(type(scale) == "number")
    if _scale_warning_printed == false and math.fmod(scale, 1) ~= 0 then
        local log = require "log"
        log.warning("In rt.Sprite:setScale: provided scale is not an integer, pixelation artifacts may occur")
        _scale_warning_printed = true
    end

    self._scale = scale
end

--- @brief replace frame positions with custom values
--- @param data table
function rt.Sprite:override_frame_data(data)
    assert(type(data) == "table")
    --[[
    -- example usage, manually set bounds of 1 frames from spritesheet
    sprite:override_frame_data({
        {
            x = 10,
            y = 10,
            width = 30,
            height = 10,
            border_x = 5,
            border_y = 4
        },
        {
            x = 10,
            y = 40,
            width = 10,
            height = 10,
            border_x = 0,
            border_y = 0
        }
    })
    ]]--

    self._frame_data = data
    local image_w, image_h = self._image:getDimensions()
    local n_frames = 0
    for entry in values(self._frame_data) do
        if entry.border_x == nil then entry.border_x = 0 end
        if entry.border_y == nil then entry.border_y = 0 end

        assert(
            type(entry.x) == "number" and
                type(entry.y) == "number" and
                type(entry.width) == "number" and
                type(entry.height) == "number" and
                type(entry.border_x) == "number" and
                type(entry.border_y) == "number"
        )

        entry.quad = love.graphics.newQuad(
            entry.x, entry.y,
            self._frame_width - 2 * entry.border_x, self._frame_height - 2 * entry.border_y,
            image_w, image_h
        )

        n_frames = n_frames + 1
    end

    self._n_columns = n_frames
    self._n_rows = 1

    self._frame_start_linear_i = math.clamp(self._frame_start_linear_i, 1, n_frames)
    self._frame_end_linear_i = math.clamp(self._frame_end_linear_i, 1, n_frames)

    self._use_custom_frame_data = true
end