require "common.matrix"
require "common.byte_data"

rt.settings.overworld.light_map = {
    max_n_point_lights = 1024,
    max_n_segment_lights = 512,
    n_point_lights_per_tile = 32,
    n_segment_lights_per_tile = 16,
    tile_size = 64,
    work_group_size_x = 32,
    work_group_size_y = 32,
    light_range = 64, -- px
    light_range_threshold = 256,
    light_z_height = 512 + 128, -- px, smaller values = more dramatic normal falloff
    intensity = 1,
    intensity_texture_format = rt.TextureFormat.RGBA8,
    direction_texture_format = rt.TextureFormat.RG16F,
    mask_texture_format = rt.TextureFormat.R8,
    should_sort_by_distance = true, -- choose closest light source deterministically if too many per tile
    use_byte_data = true
}

--- @class ow.LightMap
ow.LightMap = meta.class("LightMap")

--- @brief
function ow.LightMap:instantiate(width, height)
    local settings = rt.settings.overworld.light_map
    self._tile_size = settings.tile_size

    self._light_intensity_texture = rt.RenderTexture(
        width, height,
        0, -- msaa
        settings.intensity_texture_format,
        true -- compute write
    )

    self._light_direction_texture = rt.RenderTexture(
        width, height,
        0,
        settings.direction_texture_format,
        true
    )

    self._mask_texture = rt.RenderTexture(
        width, height,
        0,
        settings.mask_texture_format,
        true
    )

    self._work_group_size_x = settings.work_group_size_x
    self._work_group_size_y = settings.work_group_size_y

    self._dispatch_x = math.ceil(width / self._work_group_size_x)
    self._dispatch_y = math.ceil(height / self._work_group_size_y)

    local to_glsl = rt.graphics.texture_format_to_glsl_identifier
    self._shader = rt.ComputeShader("overworld/light_map_compute.glsl", {
        LIGHT_INTENSITY_TEXTURE_FORMAT = to_glsl(settings.intensity_texture_format),
        LIGHT_DIRECTION_TEXTURE_FORMAT = to_glsl(settings.direction_texture_format),
        MASK_TEXTURE_FORMAT = to_glsl(settings.mask_texture_format),
        TILE_SIZE = self._tile_size,
        LIGHT_RANGE = settings.light_range,
        INTENSITY = settings.intensity,
        LIGHT_Z_HEIGHT = settings.light_z_height,
        N_POINT_LIGHTS_PER_TILE = settings.n_point_lights_per_tile,
        N_SEGMENT_LIGHTS_PER_TILE = settings.n_segment_lights_per_tile,
        MAX_N_POINT_LIGHTS = settings.max_n_point_lights,
        MAX_N_SEGMENT_LIGHTS = settings.max_n_segment_lights,
        WORK_GROUP_SIZE_X = self._work_group_size_x,
        WORK_GROUP_SIZE_Y = self._work_group_size_y,
        WORK_GROUP_SIZE_Z = 1
    })

    self._current_n_point_lights = 0
    self._point_light_buffer = rt.GraphicsBuffer(
        self._shader:get_buffer_format("point_light_source_buffer"),
        settings.max_n_point_lights,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    if settings.use_byte_data then
        self._point_light_buffer_data = self._point_light_buffer:get_byte_data():get_native()
    else
        self._point_light_buffer_data = self._point_light_buffer:get_data()
    end

    self._current_n_segment_lights = 0
    self._segment_light_buffer = rt.GraphicsBuffer(
        self._shader:get_buffer_format("segment_light_sources_buffer"),
        settings.max_n_segment_lights,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    if settings.use_byte_data then
        self._segment_light_buffer_data = self._segment_light_buffer:get_byte_data():get_native()
    else
        self._segment_light_buffer_data = self._segment_light_buffer:get_data()
    end

    self._n_tiles = math.ceil(width / self._tile_size) * math.ceil(height / self._tile_size)

    local buffer_n_elements = (1 + settings.n_point_lights_per_tile + 1 + settings.n_segment_lights_per_tile) * self._n_tiles

    self._tile_data_buffer = rt.GraphicsBuffer(
        self._shader:get_buffer_format("tile_data_buffer"),
        buffer_n_elements,
        rt.GraphicsBufferUsage.STREAM
    )

    -- tile data is inline ints, use byte data so upload is cheaper
    if ffi == nil then
        self._tile_data_buffer_data = self._tile_data_buffer:get_byte_data():cast("int32_t")
    else
        self._tile_data_buffer_data = ffi.cast("int32_t*", self._tile_data_buffer:get_byte_data():get_native():getFFIPointer())
    end

    --- layout: inline [n_point_lights, N_POINT_LIGHTS_PER_TILE * int, n_segment_lights, N_SEGMENT_LIGHTS_PER_TILE * int]
end

--- @brief
function ow.LightMap:bind_mask()
    self._mask_texture:bind()
    love.graphics.clear(0, 0, 0, 0)
end

--- @brief
function ow.LightMap:unbind_mask()
    self._mask_texture:unbind()
end

do
    local max, min = math.max, math.min

    local function distance_between_square_and_point(x, y, square_size, px, py)
        local clamped_x = max(x, min(px, x + square_size))
        local clamped_y = max(y, min(py, y + square_size))
        return (px - clamped_x) * (px - clamped_x) + (py - clamped_y) * (py - clamped_y)
    end

    local function distance_between_point_and_segment(px, py, x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        local segment_length_squared = dx * dx + dy * dy
        if segment_length_squared == 0 then
            return (px - x1) * (px - x1) + (py - y1) * (py - y1)
        end
        local t = max(0, min(1, ((px - x1) * dx + (py - y1) * dy) / segment_length_squared))
        local closest_x = x1 + t * dx
        local closest_y = y1 + t * dy
        return (px - closest_x) * (px - closest_x) + (py - closest_y) * (py - closest_y)
    end

    local function segments_intersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
        local denom = (ax2 - ax1) * (by2 - by1) - (ay2 - ay1) * (bx2 - bx1)
        if denom == 0 then return false end
        local t = ((bx1 - ax1) * (by2 - by1) - (by1 - ay1) * (bx2 - bx1)) / denom
        local u = ((bx1 - ax1) * (ay2 - ay1) - (by1 - ay1) * (ax2 - ax1)) / denom
        return t >= 0 and t <= 1 and u >= 0 and u <= 1
    end

    local function distance_between_square_and_segment(x, y, square_size, x1, y1, x2, y2)
        if (x1 >= x and x1 <= x + square_size and y1 >= y and y1 <= y + square_size)
            or (x2 >= x and x2 <= x + square_size and y2 >= y and y2 <= y + square_size)
            or segments_intersect(x1, y1, x2, y2, x,              y,              x + square_size, y             )
            or segments_intersect(x1, y1, x2, y2, x + square_size, y,              x + square_size, y + square_size)
            or segments_intersect(x1, y1, x2, y2, x + square_size, y + square_size, x,              y + square_size)
            or segments_intersect(x1, y1, x2, y2, x,              y + square_size, x,              y             )
        then
            return 0
        end

        return math.min(
            distance_between_point_and_segment(x,              y,              x1, y1, x2, y2),
            distance_between_point_and_segment(x + square_size, y,              x1, y1, x2, y2),
            distance_between_point_and_segment(x + square_size, y + square_size, x1, y1, x2, y2),
            distance_between_point_and_segment(x,              y + square_size, x1, y1, x2, y2),
            distance_between_square_and_point(x, y, square_size, x1, y1),
            distance_between_square_and_point(x, y, square_size, x2, y2)
        )
    end

    local function xy_to_tile_index(width, tile_size, x, y)
        local tile_x = math.floor(x / tile_size)
        local tile_y = math.floor(y / tile_size)
        local n_tiles_per_row = math.ceil(width / tile_size)
        local tile_index = tile_y * n_tiles_per_row + tile_x
        return tile_index + 1
    end

    local set, get
    if ffi == nil then
        set = function(data, i, value) -- 1-based
            data:set(i, value)
        end

        get = function(data, i) -- 1-based
            return data:get(i)
        end
    else
        set = function(data, i, value)
            data[i - 1] = value
        end

        get = function(data, i)
            return data[i - 1]
        end
    end

    local function tile_index_to_data_offset(tile_data_stride, tile_index)
        return (tile_index - 1) * tile_data_stride + 1
    end

    local function set_n_point_lights(tile_data, tile_data_stride, tile_index, count)
        local tile_offset = tile_index_to_data_offset(tile_data_stride, tile_index)
        set(tile_data, tile_offset + 0, count)
    end

    local function get_n_point_lights(tile_data, tile_data_stride, _, tile_index)
        -- unused arg for consistent signature with get_n_segment_lights
        local tile_offset = tile_index_to_data_offset(tile_data_stride, tile_index)
        return get(tile_data, tile_offset + 0)
    end

    local function set_n_segment_lights(tile_data, tile_data_stride, n_point_lights_per_tile, tile_index, count)
        local tile_offset = tile_index_to_data_offset(tile_data_stride, tile_index)
        set(tile_data, tile_offset + 1 + n_point_lights_per_tile, count)
    end

    local function get_n_segment_lights(tile_data, tile_data_stride, n_point_lights_per_tile, tile_index)
        local tile_offset = tile_index_to_data_offset(tile_data_stride, tile_index)
        return get(tile_data, tile_offset + 1 + n_point_lights_per_tile)
    end

    local function add_point_light_to_tile(tile_data, tile_data_stride, n_point_lights_per_tile, tile_index, light_source_index)
        local tile_offset = tile_index_to_data_offset(tile_data_stride, tile_index)
        local count = get(tile_data, tile_offset)
        if get_n_point_lights(tile_data, tile_data_stride, n_point_lights_per_tile, tile_index) >= n_point_lights_per_tile then
            return
        end

        set(tile_data, tile_offset + 1 + count, light_source_index - 1)
        set(tile_data, tile_offset, count + 1)
    end

    local function add_segment_light_to_tile(tile_data, tile_data_stride, n_point_lights_per_tile, n_segment_lights_per_tile, tile_index, light_source_index)
        local tile_offset = tile_index_to_data_offset(tile_data_stride, tile_index)
        local count = get(tile_data, tile_offset + 1 + n_point_lights_per_tile)
        if get_n_segment_lights(tile_data, tile_data_stride, n_point_lights_per_tile, tile_index) >= n_segment_lights_per_tile then
            return
        end

        set(tile_data, tile_offset + 1 + n_point_lights_per_tile + 1 + count, light_source_index - 1)
        set(tile_data, tile_offset + 1 + n_point_lights_per_tile, count + 1)
    end

    local add_point_light = function(point_light_data, max_n_point_lights, point_light_i, world_to_screen_transform, final_scale, x, y, radius, color_r, color_g, color_b, color_a)
        if point_light_i > max_n_point_lights then
            return point_light_i
        end

        radius = math.max(radius, 1) * final_scale
        x, y = world_to_screen_transform:transform_point(x, y)

        local data = point_light_data[point_light_i]
        data[1], data[2], data[3] = x, y, radius
        data[4], data[5], data[6], data[7] = color_r, color_g, color_b, color_a

        return point_light_i + 1
    end

    local get_point_light = function(point_light_data, point_light_i)
        return table.unpack(point_light_data[point_light_i])
    end

    local upload_point_light_data = function(point_light_buffer, point_light_buffer_data, ...)
        point_light_buffer:replace_data(point_light_buffer_data, ...)
    end

    local add_segment_light = function(segment_light_data, max_n_segment_lights, segment_light_i, world_to_screen_transform, x1, y1, x2, y2, color_r, color_g, color_b, color_a)
        if segment_light_i > max_n_segment_lights then
            return segment_light_i
        end

        x1, y1 = world_to_screen_transform:transform_point(x1, y1)
        x2, y2 = world_to_screen_transform:transform_point(x2, y2)

        local data = segment_light_data[segment_light_i]
        data[1], data[2], data[3], data[4] = x1, y1, x2, y2
        data[5], data[6], data[7], data[8] = color_r, color_g, color_b, color_a

        return segment_light_i + 1
    end

    local get_segment_light = function(segment_light_data, segment_light_i)
        return table.unpack(segment_light_data[segment_light_i])
    end

    local upload_segment_light_data = function(segment_light_buffer, segment_light_buffer_data, ...)
        segment_light_buffer:replace_data(segment_light_buffer_data, ...)
    end
    
    local byte_data_functions_overridden = false

    --- @brief
    function ow.LightMap:update(stage)
        if rt.GameState:get_is_dynamic_lighting_enabled() == false then return end

        if byte_data_functions_overridden ~= true then
            -- delay init because we need buffer offsets
            do
                local buffer = self._point_light_buffer
                local stride = buffer:get_element_stride()
                local x_offset = buffer:get_byte_offset("position", 1)
                local y_offset = buffer:get_byte_offset("position", 2)
                local radius_offset = buffer:get_byte_offset("radius")
                local r_offset = buffer:get_byte_offset("color", 1)
                local g_offset = buffer:get_byte_offset("color", 2)
                local b_offset = buffer:get_byte_offset("color", 3)
                local a_offset = buffer:get_byte_offset("color", 4)

                add_point_light = function(point_light_data, max_n_point_lights, point_light_i, world_to_screen_transform, final_scale, x, y, radius, color_r, color_g, color_b, color_a)
                    if point_light_i > max_n_point_lights then
                        return point_light_i
                    end

                    radius = math.max(radius, 1) * final_scale
                    x, y = world_to_screen_transform:transform_point(x, y)

                    local offset = (point_light_i - 1) * stride
                    point_light_data:setFloat(offset + x_offset, x)
                    point_light_data:setFloat(offset + y_offset, y)
                    point_light_data:setFloat(offset + radius_offset, radius)
                    point_light_data:setFloat(offset + r_offset, color_r)
                    point_light_data:setFloat(offset + g_offset, color_g)
                    point_light_data:setFloat(offset + b_offset, color_b)
                    point_light_data:setFloat(offset + a_offset, color_a)

                    return point_light_i + 1
                end

                get_point_light = function(point_light_data, point_light_i)
                    local offset = (point_light_i - 1) * stride
                    return point_light_data:getFloat(offset + x_offset),
                    point_light_data:getFloat(offset + y_offset),
                    point_light_data:getFloat(offset + radius_offset),
                    point_light_data:getFloat(offset + r_offset),
                    point_light_data:getFloat(offset + g_offset),
                    point_light_data:getFloat(offset + b_offset),
                    point_light_data:getFloat(offset + a_offset)
                end

                upload_point_light_data = function(point_light_buffer, _, ...)
                    point_light_buffer:flush(...)
                end
            end

            do
                local buffer = self._segment_light_buffer
                local stride = buffer:get_element_stride()
                local x1_offset = buffer:get_byte_offset("segment", 1)
                local y1_offset = buffer:get_byte_offset("segment", 2)
                local x2_offset = buffer:get_byte_offset("segment", 3)
                local y2_offset = buffer:get_byte_offset("segment", 4)
                local r_offset = buffer:get_byte_offset("color", 1)
                local g_offset = buffer:get_byte_offset("color", 2)
                local b_offset = buffer:get_byte_offset("color", 3)
                local a_offset = buffer:get_byte_offset("color", 4)

                add_segment_light = function(segment_light_data, max_n_segment_lights, segment_light_i, world_to_screen_transform, x1, y1, x2, y2, color_r, color_g, color_b, color_a)
                    if segment_light_i > max_n_segment_lights then
                        return segment_light_i
                    end

                    x1, y1 = world_to_screen_transform:transform_point(x1, y1)
                    x2, y2 = world_to_screen_transform:transform_point(x2, y2)

                    local offset = (segment_light_i - 1) * stride
                    segment_light_data:setFloat(offset + x1_offset, x1)
                    segment_light_data:setFloat(offset + y1_offset, y1)
                    segment_light_data:setFloat(offset + x2_offset, x2)
                    segment_light_data:setFloat(offset + y2_offset, y2)
                    segment_light_data:setFloat(offset + r_offset, color_r)
                    segment_light_data:setFloat(offset + g_offset, color_g)
                    segment_light_data:setFloat(offset + b_offset, color_b)
                    segment_light_data:setFloat(offset + a_offset, color_a)

                    return segment_light_i + 1
                end

                get_segment_light = function(segment_light_data, segment_light_i)
                    local offset = (segment_light_i - 1) * stride
                    return segment_light_data:getFloat(offset + x1_offset),
                    segment_light_data:getFloat(offset + y1_offset),
                    segment_light_data:getFloat(offset + x2_offset),
                    segment_light_data:getFloat(offset + y2_offset),
                    segment_light_data:getFloat(offset + r_offset),
                    segment_light_data:getFloat(offset + g_offset),
                    segment_light_data:getFloat(offset + b_offset),
                    segment_light_data:getFloat(offset + a_offset)
                end

                upload_segment_light_data = function(segment_light_buffer, _, ...)
                    segment_light_buffer:flush(...)
                end
            end

            byte_data_functions_overridden = true
        end

        local settings = rt.settings.overworld.light_map
        local tile_size = self._tile_size
        local max_n_point_lights, max_n_segment_lights = settings.max_n_point_lights, settings.max_n_segment_lights
        local n_point_lights_per_tile, n_segment_lights_per_tile = settings.n_point_lights_per_tile, settings.n_segment_lights_per_tile
        local width, height = self._light_intensity_texture:get_size()
        local tile_data_stride = 1 + settings.n_point_lights_per_tile + 1 + settings.n_segment_lights_per_tile

        local tile_data = self._tile_data_buffer_data
        local point_light_data = self._point_light_buffer_data
        local segment_light_data = self._segment_light_buffer_data

        local camera = stage:get_scene():get_camera()
        local world_to_screen_transform = camera:get_transform()
        local final_scale = camera:get_final_scale()

        local point_light_i = 1
        local segment_light_i = 1

        local point_spatial_hash = {}
        local segment_spatial_hash = {}

        debugger.push("collect")

        if DEBUG then
            stage:collect_point_lights(function(x, y, radius, color_r, color_g, color_b, color_a)
                meta.assert(x, "Number", y, "Number", radius, "Number", color_r, "Number", color_g, "Number", color_b, "Number", color_a, "Number")
                if color_a > 0 then
                    point_light_i = add_point_light(point_light_data, max_n_point_lights, point_light_i, world_to_screen_transform, final_scale, x, y, radius, color_r, color_g, color_b, color_a)
                end
            end)

            stage:collect_segment_lights(function(x1, y1, x2, y2, color_r, color_g, color_b, color_a)
                meta.assert(x1, "Number", y1, "Number", x2, "Number", y2, "Number", color_r, "Number", color_g, "Number", color_b, "Number", color_a, "Number")
                if color_a > 0 then
                    segment_light_i = add_segment_light(segment_light_data, max_n_segment_lights, segment_light_i, world_to_screen_transform, x1, y1, x2, y2, color_r, color_g, color_b, color_a)
                end
            end)
        else
            stage:collect_point_lights(function(x, y, radius, color_r, color_g, color_b, color_a)
                if color_a > 0 then
                    point_light_i = add_point_light(point_light_data, max_n_point_lights, point_light_i, world_to_screen_transform, final_scale, x, y, radius, color_r, color_g, color_b, color_a)
                end
            end)

            stage:collect_segment_lights(function(x1, y1, x2, y2, color_r, color_g, color_b, color_a)
                if color_a > 0 then
                    segment_light_i = add_segment_light(segment_light_data, max_n_segment_lights, segment_light_i, world_to_screen_transform, x1, y1, x2, y2, color_r, color_g, color_b, color_a)
                end
            end)
        end

        debugger.pop("collect")

        local n_segment_lights = segment_light_i - 1
        local n_point_lights = point_light_i - 1

        debugger.push("source_buffer")

        if n_point_lights > 0 then
            upload_point_light_data(self._point_light_buffer, point_light_data,
                1, -- source index
                1, -- destination index
                n_point_lights -- count
            )
        end

        if n_segment_lights > 0 then
            upload_segment_light_data(self._segment_light_buffer, segment_light_data,
                1,
                1,
                n_segment_lights
            )
        end

        debugger.pop("source_buffer")

        debugger.push("tile_buffer")

        self._current_n_point_lights = n_point_lights
        self._current_n_segment_lights = n_segment_lights

        for tile_i = 1, self._n_tiles do
            set_n_point_lights(tile_data, tile_data_stride, tile_i, 0)
            set_n_segment_lights(tile_data, tile_data_stride, n_point_lights_per_tile, tile_i, 0)
        end

        local n_rows = math.ceil(width / tile_size)
        local n_columns = math.ceil(height / tile_size)
        local max_range = settings.light_range_threshold
        max_range = (max_range * camera:get_final_scale())^2

        local range_threshold = (settings.light_range_threshold * camera:get_final_scale())^2

        if settings.should_sort_by_distance then
            -- prioritize lights closer to the player by using squared distance as heuristic
            local player_x, player_y = world_to_screen_transform:transform_point(stage:get_scene():get_player():get_position())

            if self._tile_light_count == nil then
                self._tile_light_count = {}
            else
                table.clear(self._tile_light_count)
            end

            if self._light_order == nil then
                self._light_order = {}
            else
                table.clear(self._light_order)
            end

            if self._light_i_to_distance == nil then
                self._light_i_to_distance = {}
            else
                table.clear(self._light_i_to_distance)
            end

            local tile_light_count = self._tile_light_count
            local light_order = self._light_order
            local light_i_to_distance = self._light_i_to_distance

            for i = 1, n_point_lights do
                light_order[i] = i
                local x, y = get_point_light(point_light_data, i)
                local dx = x - player_x
                local dy = y - player_y
                light_i_to_distance[i] = math.squared_distance(x, y, player_x, player_y)
            end

            table.sort(light_order, function(a, b)
                return light_i_to_distance[a] < light_i_to_distance[b]
            end)

            for order_i = 1, n_point_lights do
                local point_i = light_order[order_i]
                local x, y, radius, _, _, _, opacity = get_point_light(point_light_data, point_i)

                -- only check cells in aabb of disk
                local effective_radius = math.sqrt(range_threshold + radius * radius)
                local first_row = math.max(1, math.floor((x - effective_radius) / tile_size) + 1)
                local last_row = math.min(n_rows, math.floor((x + effective_radius) / tile_size) + 1)
                local first_column = math.max(1, math.floor((y - effective_radius) / tile_size) + 1)
                local last_column = math.min(n_columns, math.floor((y + effective_radius) / tile_size) + 1)

                for row_i = first_row, last_row do
                    for column_i = first_column, last_column do
                        local tile_x = (row_i - 1) * tile_size
                        local tile_y = (column_i - 1) * tile_size

                        if distance_between_square_and_point(tile_x, tile_y, tile_size, x, y) < range_threshold + radius * radius then
                            local tile_index = xy_to_tile_index(width, tile_size, tile_x, tile_y)
                            local tile_count = tile_light_count[tile_index] or 0
                            if tile_count < n_point_lights_per_tile then
                                tile_light_count[tile_index] = tile_count + 1
                                add_point_light_to_tile(tile_data, tile_data_stride, n_point_lights_per_tile, tile_index, point_i)
                            end
                        end
                    end
                end
            end

            for tile_index = 1, self._n_tiles do
                tile_light_count[tile_index] = 0
            end
        else
            for point_i = 1, n_point_lights do
                local x, y, radius, _, _, _, opacity = get_point_light(point_light_data, point_i)

                local effective_radius = math.sqrt(range_threshold + radius^2)
                local first_row = math.max(1, math.floor((x - effective_radius) / tile_size) + 1)
                local last_row = math.min(n_rows, math.floor((x + effective_radius) / tile_size) + 1)
                local first_column = math.max(1, math.floor((y - effective_radius) / tile_size) + 1)
                local last_column = math.min(n_columns, math.floor((y + effective_radius) / tile_size) + 1)

                for row_i = first_row, last_row do
                    for column_i = first_column, last_column do
                        local tile_x = (row_i - 1) * tile_size
                        local tile_y = (column_i - 1) * tile_size

                        local distance = distance_between_square_and_point(tile_x, tile_y, tile_size, x, y)
                        if distance < range_threshold + radius^2 then
                            local tile_i = xy_to_tile_index(width, tile_size, tile_x, tile_y)
                            add_point_light_to_tile(tile_data, tile_data_stride, n_point_lights_per_tile, tile_i, point_i)
                        end
                    end
                end
            end
        end -- should_sort_by_distance

        for segment_i = 1, n_segment_lights do
            local data = segment_light_data[segment_i]
            local x1, y1, x2, y2, _, _, _, opacity = get_segment_light(segment_light_data, segment_i)

            -- only check cells in aabb of segment
            local effective_radius = math.sqrt(range_threshold)
            local first_row = math.max(1, math.floor((math.min(x1, x2) - effective_radius) / tile_size) + 1)
            local last_row = math.min(n_rows, math.floor((math.max(x1, x2) + effective_radius) / tile_size) + 1)
            local first_column = math.max(1, math.floor((math.min(y1, y2) - effective_radius) / tile_size) + 1)
            local last_column = math.min(n_columns, math.floor((math.max(y1, y2) + effective_radius) / tile_size) + 1)

            for row_i = first_row, last_row do
                for column_i = first_column, last_column do
                    local tile_x = (row_i - 1) * tile_size
                    local tile_y = (column_i - 1) * tile_size

                    local distance = distance_between_square_and_segment(tile_x, tile_y, tile_size, x1, y1, x2, y2)
                    if distance < range_threshold then
                        local tile_i = xy_to_tile_index(width, tile_size, tile_x, tile_y)
                        add_segment_light_to_tile(tile_data, tile_data_stride, n_point_lights_per_tile, n_segment_lights_per_tile, tile_i, segment_i)
                    end
                end
            end
        end

        debugger.pop("tile_buffer")
        debugger.push("tile_buffer_upload")

        self._tile_data_buffer:flush()

        debugger.pop("tile_buffer_upload")

        debugger.push("dispatch")

        local shader = self._shader
        shader:send("point_light_source_buffer", self._point_light_buffer)
        shader:send("segment_light_sources_buffer", self._segment_light_buffer)
        shader:send("tile_data_buffer", self._tile_data_buffer)
        shader:send("light_intensity_texture", self._light_intensity_texture)
        shader:send("light_direction_texture", self._light_direction_texture)
        shader:send("mask_texture", self._mask_texture)
        shader:dispatch(self._dispatch_x, self._dispatch_y)

        debugger.pop("dispatch")

        if love.keyboard.isDown("P") then
            debugger.report()
        end

        if DEBUG then
            if self._measured_max_n_segments == nil then self._measured_max_n_segments = -math.huge end
            if self._measured_max_n_points == nil then self._measured_max_n_points = -math.huge end
            local before_n_points, before_n_segments = self._measured_max_n_points, self._measured_max_n_segments

            for tile_i = 1, self._n_tiles do
                self._measured_max_n_points = math.max(self._measured_max_n_points, get_n_point_lights(tile_data, tile_data_stride, n_point_lights_per_tile, tile_i))
                self._measured_max_n_segments = math.max(self._measured_max_n_segments, get_n_segment_lights(tile_data, tile_data_stride, n_point_lights_per_tile, tile_i))
            end

            if self._measured_max_n_points > max_n_point_lights and before_n_points < self._measured_max_n_points then
                rt.critical("In ow.LightMap.update: number of point lights for at least one tile are `", self._measured_max_n_points, "`, but the maximum allowed number is `", max_n_point_lights, "`")
            end

            if self._measured_max_n_segments > max_n_segment_lights and before_n_segments < self._measured_max_n_segments then
                rt.critical("In ow.LightMap.update: number of segments lights for at least one tile are `", self._measured_max_n_segments, "`, but the maximum allowed number is `", max_n_segment_lights, "`")
            end
        end

    end
end

--- @brief
function ow.LightMap:draw()
    if true then return end
    if rt.GameState:get_is_dynamic_lighting_enabled() == false then return end

    for i = 1, self._current_n_point_lights do
        local data = self._point_light_buffer_data[i]
        love.graphics.setColor(data[4], data[5], data[6], data[7])
        love.graphics.circle("fill",
            data[1], data[2], data[3]
        )
    end

    for i = 1, self._current_n_segment_lights do
        local data = self._segment_light_buffer_data[i]
        love.graphics.setColor(data[5], data[6], data[7], data[8])
        love.graphics.line(
            data[1], data[2], data[3], data[4]
        )
    end

    --love.graphics.clear(0, 0, 0, 0)

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    self._light_intensity_texture:draw()
    --self._light_direction_texture:draw()
    --self._mask_texture:draw()
    local width, height = self._light_intensity_texture:get_size()
    local tile_size = self._tile_size
    local n_rows = math.ceil(width / tile_size)
    local n_columns = math.ceil(height / tile_size)
    love.graphics.setLineWidth(1)
    for row_i = 1, n_rows do
        for column_i = 1, n_columns do
            local tile_x = (row_i - 1) * tile_size
            local tile_y = (column_i - 1) * tile_size
            love.graphics.rectangle("line", tile_x, tile_y, tile_size, tile_size)
        end
    end
    love.graphics.pop()
end

--- @brief
function ow.LightMap:get_light_intensity()
    return self._light_intensity_texture
end

--- @brief
function ow.LightMap:get_light_direction()
    return self._light_direction_texture
end

--- @brief
function ow.LightMap:get_size()
    return self._light_intensity_texture:get_size()
end

--- @brief
function ow.LightMap:clear()
    self._light_intensity_texture:bind()
    love.graphics.clear(0, 0, 0, 0)
    self._light_intensity_texture:unbind()

    self._light_direction_texture:bind()
    love.graphics.clear(0, 0, 0,  0)
    self._light_direction_texture:unbind()
end