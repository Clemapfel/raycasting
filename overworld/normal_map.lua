require "common.compute_shader"
require "common.render_texture"

rt.settings.overworld.normal_map = {
    chunk_size = (16 * 16) * 3,
    work_group_size_x = 16,
    work_group_size_y = 16,
    chunk_bounds_padding = 8,

    mask_sticky = true,
    mask_slippery = true,
    max_distance = 16, -- < 256

    point_light_intensity = 1,
    segment_light_intensity = 0.2,

    max_n_point_lights = 64,
    max_n_segment_lights = 32,

    yield_savepoint_fraction = 0.01
}

--- @class ow.NormalMap
ow.NormalMap = meta.class("NormalMap")
meta.add_signal(ow.NormalMap, "done")

local _disable = false -- TODO

local _mask_texture_format = rt.TextureFormat.RGBA8  -- used to store alpha of walls
local _jfa_texture_format = rt.TextureFormat.RGBA32F -- used during JFA
local _normal_map_texture_format = rt.TextureFormat.RGB10A2 -- final normal map texture

local _clear_shader, _init_shader, _step_shader, _export_shader

local _draw_light_shader = rt.Shader("overworld/normal_map_draw_light.glsl", {
    MAX_N_POINT_LIGHTS = rt.settings.overworld.normal_map.max_n_point_lights,
    MAX_N_SEGMENT_LIGHTS = rt.settings.overworld.normal_map.max_n_segment_lights,
})

local _draw_shadow_shader = rt.Shader("overworld/normal_map_draw_shadow.glsl")

local _frame_percentage = 0.6

local _atlas = {}

--- @brief
--- @param id any used for caching
--- @param get_triangles_callback Function () -> Table<Array<Number, 6>
--- @param draw_mask_callback Function () -> nil
function ow.NormalMap:instantiate(id, get_triangles_callback, draw_mask_callback)
    id = tostring(id)
    meta.assert(id, "String", get_triangles_callback, "Function", draw_mask_callback, "Function")

    self._id = id
    self._get_triangles_callback = get_triangles_callback
    self._draw_mask_callback = draw_mask_callback
    self._is_single_chunk = false
    self._offset_x, self._offset_y = 0, 0

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then _draw_light_shader:recompile() end
    end)

    if _atlas[self._id] ~= nil then
        local entry = _atlas[self._id]
        self._chunks = entry.chunks
        self._chunk_size = entry.chunk_size
        self._chunk_padding = entry.chunk_padding
        self._bounds =  entry.bounds
        self._computation_started = true
        self._is_done = true
        self._is_visible = true
        self:signal_emit("done")
        return
    end

    self._chunks = {}
    self._non_empty_chunks = meta.make_weak({})

    self._is_done = false

    local last = love.timer.getTime()
    local savepoint = function()
        -- compute shader dispatch is not blocked, tracking frame time this way is not accurate
        local t = (love.timer.getTime() - last) / rt.SceneManager:get_timestep()
        if t > rt.settings.overworld.normal_map.yield_savepoint_fraction then
            love.graphics.push("all")
            coroutine.yield()
            love.graphics.pop()
            last = love.timer.getTime()
        end
    end

    self._callback = coroutine.create(function()
        if _disable then
            assert(false, "NormalMap was intentionally disabled")
        end

        -- collect tris of shapes to be normal mapped
        local tris = {}

        local input_triangles = self._get_triangles_callback()
        if not meta.typeof(input_triangles, "Table") then
            rt.error("In ow.NormalMap: `get_triangles_callback` does not return a tables of arrays")
        end

        for tri in values(input_triangles) do -- both
            table.insert(tris, tri)
        end

        -- get grid bounds
        local min_x, max_x = math.huge, -math.huge
        local min_y, max_y = math.huge, -math.huge

        for tri in values(tris) do
            min_x = math.min(min_x, tri[1], tri[3], tri[5])
            min_y = math.min(min_y, tri[2], tri[4], tri[6])
            max_x = math.max(max_x, tri[1], tri[3], tri[5])
            max_y = math.max(max_y, tri[2], tri[4], tri[6])
        end

        -- padding for top left most chunk, most necessary for single-chunk
        do
            local padding = rt.settings.overworld.normal_map.chunk_bounds_padding
            min_x = min_x - padding
            min_y = min_y - padding
            max_x = max_x + padding
            max_y = max_y + padding
        end

        local chunk_size = rt.settings.overworld.normal_map.chunk_size
        local chunk_padding = chunk_size / 2

        local is_single_chunk = false
        do
            local size = math.max(max_x - min_x, max_y - min_y)
            if size <= chunk_size then
                is_single_chunk = true
                chunk_size = math.ceil(size / 16) * 16
                chunk_padding = chunk_size / 2
            end
        end

        self._is_single_chunk = is_single_chunk

        self._chunk_size = chunk_size
        self._chunk_padding = chunk_padding
        self._quad = love.graphics.newQuad(
            chunk_padding,
            chunk_padding,
            chunk_size,
            chunk_size,
            chunk_size + 2 * chunk_padding,
            chunk_size + 2 * chunk_padding
        )

        self._bounds = rt.AABB(min_x, min_y, max_x - min_x, max_y - min_y)
        self._non_empty_chunks = {}

        -- for each tri, find cells it overlaps
        local function _triangle_overlaps_cell(x, y, w, h, x1, y1, x2, y2, x3, y3)
            local function _point_in_aabb(px, py)
                return px >= x and px <= (x + w) and py >= y and py <= (y + h)
            end

            local function _segments_intersect(p1x, p1y, p2x, p2y, q1x, q1y, q2x, q2y)
                local function orientation(ax, ay, bx, by, cx, cy)
                    local val = (by - ay) * (cx - bx) - (bx - ax) * (cy - by)
                    if val == 0 then return 0 end -- colinear
                    return (val > 0) and 1 or 2 -- clock or counterclockwise
                end

                local function on_segment(ax, ay, bx, by, rx, ry)
                    return math.min(ax, bx) <= rx and rx <= math.max(ax, bx) and
                        math.min(ay, by) <= ry and ry <= math.max(ay, by)
                end

                local o1 = orientation(p1x, p1y, p2x, p2y, q1x, q1y)
                local o2 = orientation(p1x, p1y, p2x, p2y, q2x, q2y)
                local o3 = orientation(q1x, q1y, q2x, q2y, p1x, p1y)
                local o4 = orientation(q1x, q1y, q2x, q2y, p2x, p2y)

                if o1 ~= o2 and o3 ~= o4 then
                    return true
                end

                if o1 == 0 and on_segment(p1x, p1y, p2x, p2y, q1x, q1y) then return true end
                if o2 == 0 and on_segment(p1x, p1y, p2x, p2y, q2x, q2y) then return true end
                if o3 == 0 and on_segment(q1x, q1y, q2x, q2y, p1x, p1y) then return true end
                if o4 == 0 and on_segment(q1x, q1y, q2x, q2y, p2x, p2y) then return true end

                return false
            end

            local function _point_in_triangle(px, py, x1, y1, x2, y2, x3, y3)
                local v0x, v0y = x3 - x1, y3 - y1
                local v1x, v1y = x2 - x1, y2 - y1
                local v2x, v2y = px - x1, py - y1

                local dot00 = v0x * v0x + v0y * v0y
                local dot01 = v0x * v1x + v0y * v1y
                local dot02 = v0x * v2x + v0y * v2y
                local dot11 = v1x * v1x + v1y * v1y
                local dot12 = v1x * v2x + v1y * v2y

                local denom = dot00 * dot11 - dot01 * dot01
                if denom == 0 then
                    return false -- degenerate
                end

                local u = (dot11 * dot02 - dot01 * dot12) * (1 / denom)
                local v = (dot00 * dot12 - dot01 * dot02) * (1 / denom)

                return (u >= 0) and (v >= 0) and (u + v <= 1)
            end

            if  _point_in_aabb(x1, y1) or
                _point_in_aabb(x2, y2) or
                _point_in_aabb(x3, y3) or

                _segments_intersect(x1, y1, x2, y2, x + 0, y + 0, x + w, y + 0) or
                _segments_intersect(x1, y1, x2, y2, x + w, y + 0, x + w, y + h) or
                _segments_intersect(x1, y1, x2, y2, x + w, y + h, x + 0, y + h) or
                _segments_intersect(x1, y1, x2, y2, x + 0, y + h, x + 0, y + 0) or

                _segments_intersect(x2, y2, x3, y3, x + 0, y + 0, x + w, y + 0) or
                _segments_intersect(x2, y2, x3, y3, x + w, y + 0, x + w, y + h) or
                _segments_intersect(x2, y2, x3, y3, x + w, y + h, x + 0, y + h) or
                _segments_intersect(x2, y2, x3, y3, x + 0, y + h, x + 0, y + 0) or

                _segments_intersect(x3, y3, x1, y1, x + 0, y + 0, x + w, y + 0) or
                _segments_intersect(x3, y3, x1, y1, x + w, y + 0, x + w, y + h) or
                _segments_intersect(x3, y3, x1, y1, x + w, y + h, x + 0, y + h) or
                _segments_intersect(x3, y3, x1, y1, x + 0, y + h, x + 0, y + 0) or

                _point_in_triangle(x + 0, y + 0, x1, y1, x2, y2, x3, y3) or
                _point_in_triangle(x + w, y + 0, x1, y1, x2, y2, x3, y3) or
                _point_in_triangle(x + w, y + h, x1, y1, x2, y2, x3, y3) or
                _point_in_triangle(x + 0, y + h, x1, y1, x2, y2, x3, y3)
            then
                return true
            end

            return false
        end

        for tri in values(tris) do
            local x1, y1, x2, y2, x3, y3 = table.unpack(tri)

            local tri_min_x = math.min(x1, x2, x3)
            local tri_max_x = math.max(x1, x2, x3)
            local tri_min_y = math.min(y1, y2, y3)
            local tri_max_y = math.max(y1, y2, y3)

            local start_xi = math.floor((tri_min_x - min_x) / chunk_size)
            local end_xi = math.floor((tri_max_x - min_x) / chunk_size)
            local start_yi = math.floor((tri_min_y - min_y) / chunk_size)
            local end_yi = math.floor((tri_max_y - min_y) / chunk_size)

            for xi = start_xi, end_xi do
                for yi = start_yi, end_yi do
                    local x = min_x + xi * chunk_size
                    local y = min_y + yi * chunk_size

                    if _triangle_overlaps_cell(
                        x, y, chunk_size, chunk_size,
                        x1, y1, x2, y2, x3, y3
                    ) then
                        if self._chunks[xi] == nil then
                            self._chunks[xi] = {}
                        end

                        local chunk = self._chunks[xi][yi]
                        if chunk == nil then -- chunk seen for the first time
                            chunk = {
                                is_empty = false,
                                is_initialized = false,
                                x = x,
                                y = y,
                                texture = rt.RenderTexture(
                                    chunk_size,
                                    chunk_size, -- no padding, cropped during export
                                    0,
                                    _normal_map_texture_format,
                                    true -- no compute write
                                ),
                                tris = {}
                            }

                            self._chunks[xi][yi] = chunk
                            table.insert(self._non_empty_chunks, chunk)
                        end

                        table.insert(chunk.tris, tri)
                    end
                end
            end
        end

        savepoint()

        self._computation_started = true

        local size_x, size_y = rt.settings.overworld.normal_map.work_group_size_x, rt.settings.overworld.normal_map.work_group_size_y
        if _step_shader == nil then _step_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 1, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _export_shader == nil then _export_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 2, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _clear_shader == nil then _clear_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 3, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end        if _init_shader == nil then _init_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 0, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end

        local padding = chunk_size / 2
        self._chunk_padding = padding
        self._chunk_size = chunk_size

        local mask = rt.RenderTexture(
            chunk_size + 2 * padding, chunk_size + 2 * padding,
            8, _mask_texture_format, true
        ):get_native()

        savepoint()

        local jfa_texture = love.graphics.newTexture(
            chunk_size + 2 * padding, chunk_size + 2 * padding,
            2, -- layer count
            {
                format = _jfa_texture_format,
                type = "array",
                canvas = true,
                computewrite = true
            }
        )

        savepoint()

        local export_texture = rt.RenderTexture(
            chunk_size + 2 * padding, chunk_size + 2 * padding,
            0, _normal_map_texture_format, true
        )

        savepoint()

        local dispatch_size_x, dispatch_size_y = (chunk_size + 2 * padding) / size_x, (chunk_size + 2 * padding) / size_y
        local lg = love.graphics

        for chunk in values(self._non_empty_chunks) do
            local start_time = love.timer.getTime()

            -- fill mask
            lg.setCanvas({ mask, stencil = true })
            lg.clear(0, 0, 0, 0)

            lg.push()
            lg.translate(-chunk.x + padding, -chunk.y + padding)
            self._draw_mask_callback()
            lg.pop()
            lg.setCanvas(nil)

            savepoint()

            -- clear array texture
            _clear_shader:send("jfa_texture_array", jfa_texture)
            _clear_shader:dispatch(dispatch_size_x, dispatch_size_y)

            savepoint()

            -- init (writes to layer 0, boundaries to both layers)
            _init_shader:send("mask_texture", mask)
            _init_shader:send("jfa_texture_array", jfa_texture)
            _init_shader:dispatch(dispatch_size_x, dispatch_size_y)

            savepoint()

            -- jfa ping-pong between layers
            local jump = 0.5 * chunk_size
            local current_layer = 0

            while jump > 0.5 do
                local input_layer = current_layer
                local output_layer = 1 - current_layer

                _step_shader:send("input_layer", input_layer)
                _step_shader:send("output_layer", output_layer)
                _step_shader:send("jfa_texture_array", jfa_texture)
                _step_shader:send("jfa_texture_array_out", jfa_texture) -- Same texture, different binding
                _step_shader:send("jump_distance", math.ceil(jump))
                _step_shader:dispatch(dispatch_size_x, dispatch_size_y)

                current_layer = output_layer
                jump = jump / 2

                savepoint()
            end

            -- export final result
            _export_shader:send("final_layer", current_layer)
            _export_shader:send("mask_texture", mask)
            _export_shader:send("jfa_texture_array", jfa_texture)
            _export_shader:send("output_texture", export_texture)
            _export_shader:send("max_distance", rt.settings.overworld.normal_map.max_distance)
            _export_shader:dispatch(dispatch_size_x, dispatch_size_y)

            savepoint()

            -- crop to save memory
            local offset_x, offset_y = self._quad:getViewport()
            lg.push("all")
            lg.reset()
            lg.setCanvas(chunk.texture:get_native())
            lg.clear(0, 0, 0, 0)
            lg.setColor(1, 1, 1, 1)
            lg.draw(export_texture:get_native(), self._quad)
            lg.pop()

            chunk.is_initialized = true
        end

        jfa_texture:release()
        mask:release()
        export_texture:release()

        self._is_done = true
        self._is_visible = true

        _atlas[self._id] = {
            chunks = self._chunks,
            chunk_size = self._chunk_size,
            chunk_padding = self._chunk_padding,
            bounds = self._bounds
        }

        self:signal_emit("done")
    end)
end

--- @brief
function ow.NormalMap:update(delta)
    -- distribute workload over multiple frames
    if not self._is_done and coroutine.status(self._callback) ~= "dead" then
        local success, error_maybe = coroutine.resume(self._callback)
        if error_maybe ~= nil then
            rt.critical("In ow.NormalMap: ", error_maybe)
            self._is_done = true
            self:signal_emit("done")
        end
    end
end

function ow.NormalMap:draw_light(
    camera,
    point_light_sources, -- in world coords
    point_light_colors,
    segment_light_sources, -- in world coords
    segment_light_colors
)
    if _disable then return end

    meta.assert(
        camera, rt.Camera,
        point_light_sources, "Table",
        point_light_colors, "Table",
        segment_light_colors, "Table",
        segment_light_colors, "Table"
    )

    if self._is_visible == false or not self._computation_started then return end

    local chunk_size = self._chunk_size
    local bounds = self._bounds

    local x, y, w, h = camera:get_world_bounds():unpack()

    x = x + self._offset_x
    y = y + self._offset_y

    local min_chunk_x = math.floor((x - bounds.x) / chunk_size)
    local max_chunk_x = math.floor(((x + w - 1) - bounds.x) / chunk_size)
    local min_chunk_y = math.floor((y - bounds.y) / chunk_size)
    local max_chunk_y = math.floor(((y + h - 1) - bounds.y) / chunk_size)

    local cell = rt.AABB()
    local padding = 0.5 * chunk_size
    local shader_bound = false

    local max_n_point_lights = rt.settings.overworld.normal_map.max_n_point_lights
    local max_n_segment_lights = rt.settings.overworld.normal_map.max_n_segment_lights

    for chunk_x = min_chunk_x, max_chunk_x do
        local column = self._chunks[chunk_x]
        if column ~= nil then
            for chunk_y = min_chunk_y, max_chunk_y do
                local chunk = column[chunk_y]
                if chunk ~= nil and chunk.is_initialized then
                    cell:reformat(
                        bounds.x + chunk_x * chunk_size - padding,
                        bounds.y + chunk_y * chunk_size - padding,
                        chunk_size + 2 * padding,
                        chunk_size + 2 * padding
                    )


                    -- filter point lights in cell, translate to screen coords
                    local point_lights_local = {}
                    local point_colors = {}
                    local n_point_lights = 0
                    for i, point in ipairs(point_light_sources) do
                        local world_x, world_y = table.unpack(point)

                        if cell:contains(world_x + self._offset_x, world_y + self._offset_y) then
                            table.insert(point_lights_local, { camera:world_xy_to_screen_xy(world_x, world_y) })
                            table.insert(point_colors, point_light_colors[i])
                            n_point_lights = n_point_lights + 1
                            if n_point_lights >= max_n_point_lights then break end
                        end
                    end


                    -- file segment lights in cell, translate to screen cords
                    local segment_lights_local = {}
                    local segment_colors = {}
                    local n_segment_lights = 0

                    for i, segment in ipairs(segment_light_sources) do
                        local world_x1, world_y1, world_x2, world_y2 = table.unpack(segment)
                        if cell:intersects(
                            world_x1 + self._offset_x,
                            world_y1 + self._offset_y,
                            world_x2 + self._offset_x,
                            world_y2 + self._offset_y
                        ) then
                            local local_x1, local_y1 = camera:world_xy_to_screen_xy(world_x1, world_y1)
                            local local_x2, local_y2 = camera:world_xy_to_screen_xy(world_x2, world_y2)
                            table.insert(segment_lights_local, { local_x1, local_y1, local_x2, local_y2 })
                            table.insert(segment_colors, segment_light_colors[i])
                            n_segment_lights = n_segment_lights + 1
                            if n_segment_lights >= max_n_segment_lights then break end
                        end
                    end

                    if n_point_lights + n_segment_lights > 0 then
                        if n_point_lights > 0 then
                            _draw_light_shader:send("point_lights", table.unpack(point_lights_local))
                            _draw_light_shader:send("point_colors", table.unpack(point_colors))
                        end

                        if n_segment_lights > 0 then
                            _draw_light_shader:send("segment_lights", table.unpack(segment_lights_local))
                            _draw_light_shader:send("segment_colors", table.unpack(segment_colors))
                        end

                        _draw_light_shader:send("n_point_lights", n_point_lights)
                        _draw_light_shader:send("n_segment_lights", n_segment_lights)

                        if shader_bound == false then
                            love.graphics.push("all")
                            _draw_light_shader:send("camera_scale", camera:get_scale())
                            _draw_light_shader:bind()
                            love.graphics.setBlendMode("add", "premultiplied")
                            local r, g, b, a = love.graphics.getColor() -- premultiply alpha
                            love.graphics.setColor(r * a, g * a, b * a, a)
                            shader_bound = true
                        end

                        love.graphics.draw(chunk.texture:get_native(), cell.x + padding, cell.y + padding)
                    end
                end
            end
        end
    end

    if shader_bound == true then
        _draw_light_shader:unbind()
        love.graphics.pop()
    end

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    if self._dbg ~= nil then
        for pos in values(self._dbg) do
            local x, y = table.unpack(pos)
            love.graphics.circle("fill", x, y, 15)
        end
    end
    love.graphics.pop()
end

function ow.NormalMap:draw_shadow(camera)
    if _disable then return end

    meta.assert(camera, rt.Camera)

    if self._is_visible == false or not self._computation_started then return end

    local shader_bound = false
    local chunk_size = self._chunk_size
    local bounds = self._bounds

    local draw_chunk = function(chunk, chunk_x, chunk_y)
        if shader_bound == false then
            love.graphics.setBlendMode("subtract", "premultiplied")
            local value = 0.1
            love.graphics.setColor(value, value, value, value)
            _draw_shadow_shader:bind()
            shader_bound = true
        end

        love.graphics.draw(chunk.texture:get_native(),
            bounds.x + chunk_x * chunk_size,
            bounds.y + chunk_y * chunk_size
        )
    end


    local x, y, w, h = camera:get_world_bounds():unpack()

    x = x + self._offset_x
    y = y + self._offset_y

    local min_chunk_x = math.floor((x - bounds.x) / chunk_size)
    local max_chunk_x = math.floor(((x + w - 1) - bounds.x) / chunk_size)
    local min_chunk_y = math.floor((y - bounds.y) / chunk_size)
    local max_chunk_y = math.floor(((y + h - 1) - bounds.y) / chunk_size)

    for chunk_x = min_chunk_x, max_chunk_x do
        local column = self._chunks[chunk_x]
        if column ~= nil then
            for chunk_y = min_chunk_y, max_chunk_y do
                local chunk = column[chunk_y]
                if chunk ~= nil and chunk.is_initialized then
                   draw_chunk(chunk, chunk_x, chunk_y)
                end
            end
        end
    end

    if shader_bound then
        _draw_shadow_shader:unbind()
        love.graphics.setBlendMode("alpha")
    end
end

--- @brief
function ow.NormalMap:clear_cache()
    for cache in values(_atlas) do
        for chunk in values(cache.chunks) do
            if chunk.texture ~= nil then
                chunk.texture:destroy()
            end
        end
    end

    _atlas = {}
end

--- @brief
function ow.NormalMap:get_is_done()
    return self._is_done
end

--- @brief
function ow.NormalMap:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.NormalMap:get_offset()
    return self._offset_x, self._offset_y
end