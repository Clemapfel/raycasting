require "common.coroutine"
require "common.compute_shader"
require "common.render_texture"

rt.settings.overworld.normal_map = {
    chunk_size = 512,
    work_group_size_x = 16,
    work_group_size_y = 8,

    mask_sticky = true,
    mask_slippery = true,
    max_distance = 100
}

--- @class ow.NormalMap
ow.NormalMap = meta.class("NormalMap")
meta.add_signal(ow.NormalMap, "done")

local _mask_texture_format = rt.TextureFormat.RGBA8  -- used to store alpha of walls
local _jfa_texture_format = rt.TextureFormat.RGBA32F -- used during JFA
local _normal_map_texture_format = rt.TextureFormat.RGB10A2 -- final normal map texture

local _init_shader, _step_shader, _post_process_shader, _export_shader, _draw_light_shader, _draw_shadow_shader
local _blur_shader_horizontal, _blur_shader_vertical

local _frame_percentage = 0.6

--- @brief
function ow.NormalMap:instantiate(stage)
    meta.assert(stage, ow.Stage)

    self._stage = stage

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
    self._is_allocated = false
    self._is_done = false

    stage:signal_connect("initialized", function()
        self._is_started = true
        self._start_time = love.timer.getTime()
        return meta.DISCONNECT_SIGNAL
    end)

    self._allocate_callback = rt.Coroutine(function()
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

        self._is_allocated = true
    end)

    self._compute_sdf_callback = rt.Coroutine(function()
        local size_x, size_y = rt.settings.overworld.normal_map.work_group_size_x, rt.settings.overworld.normal_map.work_group_size_y
        if _init_shader == nil then _init_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 0, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _step_shader == nil then _step_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 1, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _post_process_shader == nil then _post_process_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 2, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _export_shader == nil then _export_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 3, WORK_GROUP_SIZE_X = size_x, WORK_GROUP_SIZE_Y = size_y }) end
        if _draw_light_shader == nil then _draw_light_shader = rt.Shader("overworld/normal_map_draw.glsl", { MODE = 0 }) end
        if _draw_shadow_shader == nil then _draw_shadow_shader = rt.Shader("overworld/normal_map_draw.glsl", { MODE = 1 }) end

        if _blur_shader_horizontal == nil then
            _blur_shader_horizontal = rt.Shader("overworld/normal_map_blur.glsl", {
                HORIZONTAL_OR_VERTICAL = 1
            }):get_native()
        end

        if _blur_shader_vertical == nil then
            _blur_shader_horizontal = rt.Shader("overworld/normal_map_blur.glsl", {
                HORIZONTAL_OR_VERTICAL = 0
            }):get_native()
        end

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

            do -- blur
                local shader_a, shader_b = _blur_shader_horizontal, _blur_shader_vertical

                local a, b
                if a_or_b then
                    a, b = texture_a, texture_b
                else
                    a, b = texture_b, texture_a
                end

                lg.push()
                lg.origin()
                for i = 1, 1 do
                    lg.setShader(shader_a)
                    lg.setCanvas(a)
                    lg.draw(b)

                    lg.setShader(shader_b)
                    lg.setCanvas(b)
                    lg.draw(a)
                end

                lg.setCanvas(nil)
                lg.setShader(nil)
                lg.pop()
            end


            -- post process
            if a_or_b then
                _post_process_shader:send("input_texture", texture_a)
                _post_process_shader:send("output_texture", texture_b)
            else
                _post_process_shader:send("input_texture", texture_b)
                _post_process_shader:send("output_texture", texture_a)
            end

            _post_process_shader:send("max_distance", rt.settings.overworld.normal_map.max_distance)
            _post_process_shader:dispatch(dispatch_size_x, dispatch_size_y)

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
            lg.push()
            lg.origin()
            lg.setCanvas(chunk.texture:get_native())
            lg.clear(0, 0, 0, 0)
            lg.setColor(1, 1, 1, 1)
            lg.draw(export_texture:get_native(), self._quad)
            lg.pop()

            chunk.is_initialized = true
        end

        texture_a:release()
        texture_b:release()
        mask:release()
        export_texture:release()

        self._is_done = true
        self._queue_finish = true

        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "p" then
                _draw_light_shader:recompile()
                _draw_shadow_shader:recompile()
            end
        end)
    end)
end

--- @brief
function ow.NormalMap:update(delta)
    if not self._is_started or self._is_done then return end

    -- distribute workload over multiple frames
    if not self._allocate_callback:get_is_done() then
        self._allocate_callback:resume()
    elseif not self._compute_sdf_callback:get_is_done() then
        self._compute_sdf_callback:resume()
    end
end

function ow.NormalMap:_draw(light_or_shadow)
    if not self._is_done then return end

    local padding = self._chunk_padding
    local chunk_size = self._chunk_size

    local x, y, w, h = self._stage:get_scene():get_camera():get_world_bounds()
    local min_chunk_x = math.floor((x - self._bounds.x) / chunk_size)
    local max_chunk_x = math.floor(((x + w - 1) - self._bounds.x) / chunk_size)
    local min_chunk_y = math.floor((y - self._bounds.y) / chunk_size)
    local max_chunk_y = math.floor(((y + h - 1) - self._bounds.y) / chunk_size)

    if light_or_shadow == true then
        local camera = self._stage:get_scene():get_camera()
        local player = self._stage:get_scene():get_player()
        local player_position = { camera:world_xy_to_screen_xy(player:get_position()) }
        _draw_light_shader:bind()
        _draw_light_shader:send("player_position", player_position)
        _draw_light_shader:send("player_color", {rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1)})

        love.graphics.setBlendMode("add", "premultiplied")
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setBlendMode("subtract", "premultiplied")
        local value = 0.2
        love.graphics.setColor(value, value, value, value)
        _draw_shadow_shader:bind()
    end

    for chunk_x = min_chunk_x, max_chunk_x do
        local column = self._chunks[chunk_x]
        for chunk_y = min_chunk_y, max_chunk_y do
            local chunk
            if column ~= nil then
                chunk = column[chunk_y]
            end

            local draw_x = self._bounds.x + chunk_x * chunk_size
            local draw_y = self._bounds.y + chunk_y * chunk_size

            if chunk ~= nil and chunk.is_initialized then
                love.graphics.draw(chunk.texture:get_native(), draw_x, draw_y)
            end
        end
    end

    if light_or_shadow == true then
        _draw_light_shader:unbind()
    else
        _draw_shadow_shader:unbind()
    end

    love.graphics.setBlendMode("alpha")
end

function ow.NormalMap:draw_light()
    self:_draw(true)
end

function ow.NormalMap:draw_shadow()
    self:_draw(false)
end
