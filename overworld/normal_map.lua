require "common.compute_shader"
require "common.render_texture"

rt.settings.overworld.normal_map = {
    chunk_size = 512,
    work_group_size_x = 16,
    work_group_size_y = 8,

    mask_sticky = true,
    mask_slippery = true,
    max_distance = 16, -- < 256

    point_light_intensity = 1,
    segment_light_intensity = 0.2,

    max_n_point_lights = 32,
    max_n_segment_lights = 16
}

--- @class ow.NormalMap
ow.NormalMap = meta.class("NormalMap")
meta.add_signal(ow.NormalMap, "done")

local _mask_texture_format = rt.TextureFormat.RGBA8  -- used to store alpha of walls
local _jfa_texture_format = rt.TextureFormat.RGBA32F -- used during JFA
local _normal_map_texture_format = rt.TextureFormat.RGB10A2 -- final normal map texture

local _init_shader, _step_shader, _pre_process_shader, _post_process_shader, _export_shader

local _draw_light_shader = rt.Shader("overworld/normal_map_draw_light.glsl", {
    MAX_N_POINT_LIGHTS = rt.settings.overworld.normal_map.max_n_point_lights,
    MAX_N_SEGMENT_LIGHTS = rt.settings.overworld.normal_map.max_n_segment_lights,
})

local _draw_shadow_shader = rt.Shader("overworld/normal_map_draw_shadow.glsl")

local _frame_percentage = 0.6

local _atlas = {}

--- @brief
function ow.NormalMap:instantiate(stage)
    meta.assert(stage, ow.Stage)

    self._stage = stage
    if _atlas[self._stage:get_id()] ~= nil then
        local entry = _atlas[self._stage:get_id()]
        self._chunks, self._chunk_size, self._chunk_padding, self._bounds = entry.chunks, entry.chunk_size, entry.chunk_padding, entry.bounds
        self._computation_started = true
        self._is_started = true
        self._is_done = true
        self._is_visible = true
        self:signal_emit("done")
        return
    end

    self._chunks = {}
    self._non_empty_chunks = meta.make_weak({})

    local chunk_size = rt.settings.overworld.normal_map.chunk_size
    local chunk_padding = chunk_size / 2

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

    self._is_started = false
    self._is_done = false

    stage:signal_connect("initialized", function()
        self._is_started = true
        self._start_time = love.timer.getTime()
        return meta.DISCONNECT_SIGNAL
    end)

    local savepoint = function()
        -- always yield, one step per frame
        love.graphics.push("all")
        coroutine.yield()
        love.graphics.pop()
    end

    self._callback = coroutine.create(function()
        -- collect tris of shapes to be normal mapped
        local tris = {}
        for tri in values(ow.Hitbox:get_tris(true, true)) do -- both
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

        -- align to nearest tilesize
        local tile_size = 16
        min_x = math.floor(min_x / tile_size) * tile_size
        min_x = math.floor(min_y / tile_size) * tile_size

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
        if _init_shader == nil then _init_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 0, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _step_shader == nil then _step_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 1, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _pre_process_shader == nil then _pre_process_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 2, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _post_process_shader == nil then _post_process_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 3, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _export_shader == nil then _export_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 4, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end

        local padding = chunk_size / 2
        self._chunk_padding = padding
        self._chunk_size = chunk_size

        local mask = rt.RenderTexture(
            chunk_size + 2 * padding, chunk_size + 2 * padding,
            8, _mask_texture_format, true
        ):get_native()

        local texture_a = rt.RenderTexture(
            chunk_size + 2 * padding, chunk_size + 2 * padding,
            0, _jfa_texture_format, true
        ):get_native()

        local texture_b = rt.RenderTexture(
            chunk_size + 2 * padding, chunk_size + 2 * padding,
            0, _jfa_texture_format, true
        ):get_native()

        local export_texture = rt.RenderTexture(
            chunk_size + 2 * padding, chunk_size + 2 * padding,
            0, _normal_map_texture_format, true
        )

        local dispatch_size_x, dispatch_size_y = (chunk_size + 2 * padding) / size_x, (chunk_size + 2 * padding) / size_y
        local lg = love.graphics

        local camera = self._stage:get_scene():get_camera()

        for chunk in values(self._non_empty_chunks) do
            local start_time = love.timer.getTime()

            -- fill mask
            lg.setCanvas({ mask, stencil = true })
            lg.clear(0, 0, 0, 0)

            lg.push()
            lg.translate(-chunk.x + padding, -chunk.y + padding)
            ow.Hitbox:draw_mask(
                rt.settings.overworld.normal_map.mask_sticky,
                rt.settings.overworld.normal_map.mask_slippery
            )
            lg.pop()
            lg.setCanvas(nil)

            for to_clear in range(texture_a, texture_b) do
                lg.setCanvas(to_clear)
                lg.clear(0, 0, 0, 0)
                lg.setCanvas(nil)
            end

            -- init
            _init_shader:send("mask_texture", mask)
            _init_shader:send("input_texture", texture_a)
            _init_shader:send("output_texture", texture_b)
            _init_shader:dispatch(dispatch_size_x, dispatch_size_y)

            savepoint()

            -- jfa
            local jump = 0.5 * chunk_size
            local a_or_b = true
            while jump > 0.5 do
                if a_or_b then
                    _step_shader:send("input_texture", texture_a)
                    _step_shader:send("output_texture", texture_b)
                else
                    _step_shader:send("input_texture", texture_b)
                    _step_shader:send("output_texture", texture_a)
                end

                _step_shader:send("jump_distance", math.ceil(jump))
                _step_shader:dispatch(dispatch_size_x, dispatch_size_y)

                a_or_b = not a_or_b
                jump = jump / 2
            end

            savepoint()

            -- compute gradient, export to RG8
            if a_or_b then
                _export_shader:send("input_texture", texture_a)
            else
                _export_shader:send("input_texture", texture_b)
            end

            _export_shader:send("mask_texture", mask)
            _export_shader:send("output_texture", export_texture)
            _export_shader:send("max_distance", rt.settings.overworld.normal_map.max_distance)
            _export_shader:dispatch(dispatch_size_x, dispatch_size_y)

            -- crop to save memory
            local offset_x, offset_y = self._quad:getViewport()
            lg.push("all")
            lg.origin()
            lg.setCanvas(chunk.texture:get_native())
            lg.clear(0, 0, 0, 0)
            lg.setColor(1, 1, 1, 1)
            lg.draw(export_texture:get_native(), self._quad)
            lg.pop()

            chunk.is_initialized = true

            savepoint()
        end

        texture_a:release()
        texture_b:release()
        mask:release()
        export_texture:release()

        self._is_done = true
        self._is_visible = true

        _atlas[self._stage:get_id()] = {
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
            rt.critical("In ow.NormalMap: " .. error_maybe)
            self._is_done = true
        end
    end
end

function ow.NormalMap:draw_light()
    if self._is_visible == false or not self._computation_started then return end

    local chunk_size = self._chunk_size
    local bounds = self._bounds
    local x, y, w, h = self._stage:get_scene():get_camera():get_world_bounds():unpack()
    local min_chunk_x = math.floor((x - bounds.x) / chunk_size)
    local max_chunk_x = math.floor(((x + w - 1) - bounds.x) / chunk_size)
    local min_chunk_y = math.floor((y - bounds.y) / chunk_size)
    local max_chunk_y = math.floor(((y + h - 1) - bounds.y) / chunk_size)

    local scene, camera, player = self._stage:get_scene(), self._stage:get_scene():get_camera(), self._stage:get_scene():get_player()
    local blood_splatter = self._stage:get_blood_splatter()

    local shader_bound = false

    -- collect all point lights
    local all_point_positions, all_point_colors = self._stage:get_scene():get_point_light_sources()
    table.insert(all_point_positions, { player:get_position() })
    table.insert(all_point_colors, { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) })

    -- convert to screen coords
    local point_light_world_positions = {}
    for position in values(all_point_positions) do
        table.insert(point_light_world_positions, table.deepcopy(position))
        position[1], position[2] = camera:world_xy_to_screen_xy(table.unpack(position))
    end

    local segment_lights, segment_colors = self._stage:get_scene():get_segment_light_sources()
    local n_segment_lights = #segment_lights

    -- translate to screen coords
    for segment in values(segment_lights) do
        segment[1], segment[2] = camera:world_xy_to_screen_xy(segment[1], segment[2])
        segment[3], segment[4] = camera:world_xy_to_screen_xy(segment[3], segment[4])
    end

    local cell = rt.AABB()
    local padding = 0.5 * chunk_size

    local r, g, b, a = love.graphics.getColor()

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

                    -- filter point lights in cell
                    local point_lights = {}
                    local point_colors = {}
                    local n_point_lights = 0
                    for i, point in ipairs(all_point_positions) do
                        local world_x, world_y = table.unpack(point_light_world_positions[i])
                        if cell:contains(world_x, world_y) then
                            table.insert(point_lights, point)
                            table.insert(point_colors, all_point_colors[i])
                            n_point_lights = n_point_lights + 1
                        end
                    end

                    if n_point_lights + n_segment_lights > 0 then
                        if n_point_lights > 0 then
                            _draw_light_shader:send("point_lights", table.unpack(point_lights))
                            _draw_light_shader:send("point_colors", table.unpack(point_colors))
                        end

                        if n_segment_lights > 0 then
                            _draw_light_shader:send("segment_lights", table.unpack(segment_lights))
                            _draw_light_shader:send("segment_colors", table.unpack(segment_colors))
                        end

                        _draw_light_shader:send("n_point_lights", math.min(n_point_lights, rt.settings.overworld.normal_map.max_n_point_lights))
                        _draw_light_shader:send("n_segment_lights", math.min(n_segment_lights, rt.settings.overworld.normal_map.max_n_segment_lights))

                        if shader_bound == false then
                            love.graphics.push("all")
                            _draw_light_shader:send("camera_offset", { camera:get_offset() })
                            _draw_light_shader:send("camera_scale", camera:get_final_scale())
                            _draw_light_shader:bind()
                            love.graphics.setBlendMode("add", "premultiplied")
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
end

function ow.NormalMap:draw_shadow()
    if self._is_visible == false or not self._computation_started then return end

    local chunk_size = self._chunk_size
    local bounds = self._bounds
    local x, y, w, h = self._stage:get_scene():get_camera():get_world_bounds():unpack()
    local min_chunk_x = math.floor((x - bounds.x) / chunk_size)
    local max_chunk_x = math.floor(((x + w - 1) - bounds.x) / chunk_size)
    local min_chunk_y = math.floor((y - bounds.y) / chunk_size)
    local max_chunk_y = math.floor(((y + h - 1) - bounds.y) / chunk_size)

    local shader_bound = false
    for chunk_x = min_chunk_x, max_chunk_x do
        local column = self._chunks[chunk_x]
        if column ~= nil then
            for chunk_y = min_chunk_y, max_chunk_y do
                local chunk = column[chunk_y]
                if chunk ~= nil and chunk.is_initialized then
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