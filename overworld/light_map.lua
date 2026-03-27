require "common.matrix"

rt.settings.overworld.light_map = {
    max_n_point_lights = 256,
    max_n_segment_lights = 128,
    max_n_element_per_tile = 32 + 16,
    tile_size = 256,
    work_group_size = 8,
    light_range = 64, -- px
    light_z_height = 512 + 128, -- px, smaller values = more dramatic normal falloff
    intensity = 0.25,
    intensity_texture_format = rt.TextureFormat.RGBA8,
    direction_texture_format = rt.TextureFormat.RG16F,
    mask_texture_format = rt.TextureFormat.R8
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

    self._work_group_size = settings.work_group_size
    self._dispatch_x = math.ceil(width / self._work_group_size)
    self._dispatch_y = math.ceil(height / self._work_group_size)

    local to_glsl = rt.graphics.texture_format_to_glsl_identifier
    self._shader = rt.ComputeShader("overworld/light_map_compute.glsl", {
        LIGHT_INTENSITY_TEXTURE_FORMAT = to_glsl(settings.intensity_texture_format),
        LIGHT_DIRECTION_TEXTURE_FORMAT = to_glsl(settings.direction_texture_format),
        MASK_TEXTURE_FORMAT = to_glsl(settings.mask_texture_format),
        TILE_SIZE = self._tile_size,
        LIGHT_RANGE = settings.light_range,
        INTENSITY = settings.intensity,
        LIGHT_Z_HEIGHT = settings.light_z_height,
        MAX_N_POINT_LIGHTS = settings.max_n_point_lights,
        MAX_N_SEGMENT_LIGHTS = settings.max_n_segment_lights,
        WORK_GROUP_SIZE_X = self._work_group_size,
        WORK_GROUP_SIZE_Y = self._work_group_size,
        WORK_GROUP_SIZE_Z = 1
    })

    self._point_light_buffer = rt.GraphicsBuffer(
        self._shader:get_buffer_format("point_light_source_buffer"),
        settings.max_n_point_lights,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    self._current_n_point_lights = 0
    self._point_light_buffer_data = {}
    for i = 1, settings.max_n_segment_lights do
        table.insert(self._point_light_buffer_data, {
            0, 0,      -- position
            0,         -- radius
            0, 0, 0, 0 -- color
        })
    end

    self._segment_light_buffer = rt.GraphicsBuffer(
        self._shader:get_buffer_format("segment_light_sources_buffer"),
        settings.max_n_segment_lights,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    self._current_n_segment_lights = 0
    self._segment_light_buffer_data = {}
    for i = 1, settings.max_n_segment_lights do
        table.insert(self._segment_light_buffer_data, {
            0, 0, 0, 0, -- segment
            0, 0, 0, 0  -- color
        })
    end

    self._n_tiles = math.ceil(width / self._tile_size) * math.ceil(height / self._tile_size)

    self._tile_data_buffer_data = {}
    for i = 1, self._n_tiles do
        table.insert(self._tile_data_buffer_data, 0) -- point light count
        for _ = 1, settings.max_n_point_lights do
            table.insert(self._tile_data_buffer_data, -1) -- point light index
        end

        table.insert(self._tile_data_buffer_data, 0) -- segment light count
        for _ = 1, settings.max_n_segment_lights do
            table.insert(self._tile_data_buffer_data, -1) -- segment light index
        end
    end

    self._tile_data_buffer = rt.GraphicsBuffer(
        self._shader:get_buffer_format("tile_data_buffer"),
        self._tile_data_buffer_data,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    --- layout: inline [n_point_lights, MAX_N_POINT_LIGHTS * int, n_segment_lights, MAX_N_SEGMENT_LIGHTS * int]
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

--- @brief
function ow.LightMap:update(stage)
    if rt.GameState:get_is_dynamic_lighting_enabled() == false then return end

    local settings = rt.settings.overworld.light_map
    local tile_size = self._tile_size
    local max_n_point_lights, max_n_segment_lights = settings.max_n_point_lights, settings.max_n_segment_lights
    local width, height = self._light_intensity_texture:get_size()
    local tile_data_stride = 2 + settings.max_n_point_lights + settings.max_n_segment_lights
    local tile_data = self._tile_data_buffer_data
    local point_light_data = self._point_light_buffer_data
    local segment_light_data = self._segment_light_buffer_data

    local function xy_to_tile_index(x, y)
        local tile_x = math.floor(x / tile_size)
        local tile_y = math.floor(y / tile_size)

        local n_tiles_per_row = math.ceil(width / tile_size)
        local tile_index = tile_y * n_tiles_per_row + tile_x

        return tile_index + 1 -- lua is 1-based
    end

    local function tile_index_to_data_offset(tile_index)
        return (tile_index - 1) * tile_data_stride + 1
    end

    local function set_n_point_lights(tile_index, count)
        local tile_offset = tile_index_to_data_offset(tile_index)
        tile_data[tile_offset] = count
    end

    local function get_n_point_lights(tile_index)
        local tile_offset = tile_index_to_data_offset(tile_index)
        return tile_data[tile_offset]
    end

    local function set_n_segment_lights(tile_index, count)
        local tile_offset = tile_index_to_data_offset(tile_index)
        tile_data[tile_offset + 1 + settings.max_n_point_lights] = count
    end

    local function get_n_segment_lights(tile_index)
        local tile_offset = tile_index_to_data_offset(tile_index)
        return tile_data[tile_offset + 1 + settings.max_n_point_lights]
    end

    local max_n_per_tile = settings.max_n_element_per_tile

    local function get_total_tile_count(tile_index)
        local tile_offset = tile_index_to_data_offset(tile_index)
        local out = tile_data[tile_offset] + tile_data[tile_offset + 1 + max_n_point_lights]
        return out
    end

    local function add_point_light_to_tile(tile_index, light_source_index)
        local tile_offset = tile_index_to_data_offset(tile_index)
        local count = tile_data[tile_offset]
        if get_total_tile_count(tile_index) >= max_n_per_tile or
           get_n_point_lights(tile_index) >= max_n_point_lights
        then return end

        tile_data[tile_offset + 1 + count] = light_source_index - 1 -- glsl is 0-based
        tile_data[tile_offset] = count + 1
    end

    local function add_segment_light_to_tile(tile_index, light_source_index)
        local tile_offset = tile_index_to_data_offset(tile_index)
        local count = tile_data[tile_offset + 1 + max_n_point_lights]
        if get_total_tile_count(tile_index) >= max_n_per_tile or
           get_n_segment_lights(tile_index) >= max_n_segment_lights
        then return end

        tile_data[tile_offset + 1 + max_n_point_lights + 1 + count] = light_source_index - 1 -- 0 based
        tile_data[tile_offset + 1 + max_n_point_lights] = count + 1
    end

    local function closest_point_on_segment(x, y, x1, y1, x2, y2)
        local abx = x2 - x1
        local aby = y2 - y1

        local apx = x - x1
        local apy = y - y1

        local ab_dot_ab = math.dot(abx, aby, abx, aby)

        if ab_dot_ab == 0 then
            return x1, y1
        end

        local t = math.clamp(
            math.dot(apx, apy, abx, aby) / ab_dot_ab,
            0.0,
            1.0
        )

        return x1 + t * abx, y1 + t * aby
    end

    local camera = stage:get_scene():get_camera()
    local world_to_screen_transform = camera:get_transform()
    local final_scale = camera:get_final_scale()

    local point_light_i = 1
    local add_point_light = function(x, y, radius, color_r, color_g, color_b, color_a)
        meta.assert(x, "Number", y, "Number", radius, "Number", color_r, "Number", color_g, "Number", color_b, "Number", color_a, "Number")
        if point_light_i > max_n_point_lights
            or point_light_i > #point_light_data then
            return
        end

        radius = math.max(radius, 1) * final_scale
        x, y = world_to_screen_transform:transform_point(x, y)

        local data = point_light_data[point_light_i]
        data[1], data[2], data[3] = x, y, radius
        data[4], data[5], data[6], data[7] = color_r, color_g, color_b, color_a

        point_light_i = point_light_i + 1
    end

    local segment_light_i = 1
    local add_segment_light = function(x1, y1, x2, y2, color_r, color_g, color_b, color_a)
        meta.assert(x1, "Number", y1, "Number", x2, "Number", y2, "Number", color_r, "Number", color_g, "Number", color_b, "Number", color_a, "Number")

        if segment_light_i > max_n_segment_lights
            or segment_light_i > #segment_light_data then
            return
        end

        x1, y1 = world_to_screen_transform:transform_point(x1, y1)
        x2, y2 = world_to_screen_transform:transform_point(x2, y2)

        local data = segment_light_data[segment_light_i]
        data[1], data[2], data[3], data[4] = x1, y1, x2, y2
        data[5], data[6], data[7], data[8] = color_r, color_g, color_b, color_a

        segment_light_i = segment_light_i + 1
    end

    -- collect light sources

    stage:collect_point_lights(add_point_light)
    stage:collect_segment_lights(add_segment_light)

    local n_segment_lights = segment_light_i - 1
    local n_point_lights = point_light_i - 1

    self._current_n_point_lights = n_point_lights
    self._point_light_buffer:replace_data(
        self._point_light_buffer_data
    )

    self._current_n_segment_lights = n_segment_lights
    self._segment_light_buffer:replace_data(
        self._segment_light_buffer_data
    )

    -- setup tile data

    for tile_i = 1, self._n_tiles do
        -- reset tile counts, rest of each buffer does not need to be reset
        set_n_point_lights(tile_i, 0)
        set_n_segment_lights(tile_i, 0)
    end

    local n_rows = math.ceil(width / tile_size)
    local n_columns = math.ceil(height / tile_size)
    local max_range = 2 * self._tile_size
    max_range = max_range^2 -- using squared distance for performance

    local function square_point_distance(square_x, square_y, square_size, px, py)
        local closest_x = math.clamp(px, square_x, square_x + square_size)
        local closest_y = math.clamp(py, square_y, square_y + square_size)
        return math.squared_distance(closest_x, closest_y, px, py)
    end

    local sample_length = math.sqrt(tile_size)
    local function square_segment_distance(square_x, square_y, square_size, x1, y1, x2, y2)
        local segment_length = math.distance(x1, y1, x2, y2)
        local n_samples = math.min(2, math.floor(segment_length / sample_length))

        local max_distance = -math.huge
        for i = 1, n_samples do
            local t = (i - 1) / n_samples
            local dist = square_point_distance(
                square_x, square_y, square_size,
                math.mix2(x1, y1, x2, y2, t)
            )

            max_distance = math.max(max_distance, dist)
        end

        return max_distance
    end

    for row_i = 1, n_rows do
        for column_i = 1, n_columns do
            local tile_x = (row_i - 1) * tile_size
            local tile_y = (column_i - 1) * tile_size
            local tile_i = xy_to_tile_index(tile_x + 0.5 * tile_size, tile_y + 0.5 * tile_size)

            -- iterate all point lights, check if they are in range, if yes add to tile
            for point_i = 1, n_point_lights do
                local data = point_light_data[point_i]
                local x, y, radius = data[1], data[2], data[3]

                if square_point_distance(tile_x, tile_y, tile_size, x, y) < max_range + radius then
                    add_point_light_to_tile(tile_i, point_i)
                end

                add_point_light_to_tile(tile_i, point_i)
            end

            -- iterate all segment lights, check if in range
            for segment_i = 1, n_segment_lights do
                local data = segment_light_data[segment_i]
                local x1, y1, x2, y2 = data[1], data[2], data[3], data[4]

                local x, y = tile_x + 0.5 * tile_size, tile_y + 0.5 * tile_size
                if square_segment_distance(tile_x, tile_y, tile_size, x1, y1, x2, y2) < max_range then
                    add_segment_light_to_tile(tile_i, segment_i)
                end

                add_segment_light_to_tile(tile_i, segment_i)
            end
        end
    end

    self._tile_data_buffer:replace_data(tile_data)

    local shader = self._shader
    shader:send("point_light_source_buffer", self._point_light_buffer)
    shader:send("segment_light_sources_buffer", self._segment_light_buffer)
    shader:send("tile_data_buffer", self._tile_data_buffer)
    shader:send("light_intensity_texture", self._light_intensity_texture)
    shader:send("light_direction_texture", self._light_direction_texture)
    shader:send("mask_texture", self._mask_texture)
    shader:dispatch(self._dispatch_x, self._dispatch_y)
end

--- @brief
function ow.LightMap:draw()
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
    --self._light_intensity_texture:draw()
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