require "common.compute_shader"
require "common.render_texture"
require "common.impulse_manager"

rt.settings.overworld.normal_map = {
    chunk_size = 1024,
    work_group_size_x = 16,
    work_group_size_y = 16,
    chunk_bounds_padding = 8,

    mask_sticky = true,
    mask_slippery = true,
    max_distance = 32, -- < 256

    shadow_strength = 0.15,

    yield_savepoint_fraction = 0.004,
    n_post_process_passes = 2
}

ow.NormalMap = meta.class("NormalMap")
meta.add_signal(ow.NormalMap, "done")

local _is_disabled = true -- TODO

local _mask_texture_format = rt.TextureFormat.R8  -- used to store alpha of walls
local _jfa_texture_format = rt.TextureFormat.RGBA32F -- used during JFA
local _normal_map_texture_format = rt.TextureFormat.RGB10A2 -- final normal map texture
local _init_shader, _jump_shader, _export_shader, _post_process_shader

local _draw_light_shader = rt.Shader("overworld/normal_map_draw_light.glsl", {
    MAX_N_POINT_LIGHTS = rt.settings.overworld.normal_map.max_n_point_lights,
    MAX_N_SEGMENT_LIGHTS = rt.settings.overworld.normal_map.max_n_segment_lights,
})

local _draw_shadow_shader = rt.Shader("overworld/normal_map_draw_shadow.glsl")
local _atlas = {}

--- @brief
--- @param id any used for caching
--- @param get_triangles_callback Function () -> Table<Array<Number, 6>
--- @param draw_mask_callback Function () -> nil
function ow.NormalMap:instantiate(id, get_triangles_callback, draw_mask_callback)
    id = tostring(id)
    meta.assert(id, "String", get_triangles_callback, "Function", draw_mask_callback, "Function")

    self._start_time = love.timer.getTime()

    self._id = id
    self._impulse = rt.ImpulseSubscriber()

    self._get_triangles_callback = get_triangles_callback
    self._draw_mask_callback = draw_mask_callback
    self._is_single_chunk = false
    self._offset_x, self._offset_y = 0, 0

    if _atlas[self._id] ~= nil then
        local entry = _atlas[self._id]
        self._chunks = entry.chunks
        self._chunk_size = entry.chunk_size
        self._chunk_padding = entry.chunk_padding
        self._texture_atlas = entry.texture_atlas
        self._bounds = entry.bounds
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
        if (love.timer.getTime() - last) / (1 / 60) > 0.01 then
            coroutine.yield()
            last = love.timer.getTime()
        end
    end

    self._callback = coroutine.create(function()
        if _is_disabled then
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
        local function _point_in_aabb(px, py, x, y, w, h)
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

        local function _triangle_overlaps_cell(x, y, w, h, x1, y1, x2, y2, x3, y3)
            if  _point_in_aabb(x1, y1, x, y, w, h) or
                _point_in_aabb(x2, y2, x, y, w, h) or
                _point_in_aabb(x3, y3, x, y, w, h) or

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

            do -- expand search range slightly to account for float precision on chunk boundary
                local epsilon = 1
                if (tri_min_x - min_x) % chunk_size < epsilon then
                    start_xi = start_xi - 1
                end
                if (tri_min_y - min_y) % chunk_size < epsilon then
                    start_yi = start_yi - 1
                end

                local x_mod = (tri_max_x - min_x) % chunk_size
                if x_mod < epsilon or x_mod > chunk_size - epsilon then
                    end_xi = end_xi + 1
                end

                local y_mod = (tri_max_y - min_y) % chunk_size
                if y_mod < epsilon or y_mod > chunk_size - epsilon then
                    end_yi = end_yi + 1
                end
            end

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
                                is_initialized = false,
                                x = x,
                                y = y,
                                quad = nil, -- love.Quad, cf. texture atlas below
                            }

                            self._chunks[xi][yi] = chunk
                            table.insert(self._non_empty_chunks, chunk)
                        end
                    end
                end
            end
        end

        self._computation_started = true

        local size_x, size_y = rt.settings.overworld.normal_map.work_group_size_x, rt.settings.overworld.normal_map.work_group_size_y

        local defines = function(mode)
            return {
                MODE = mode,
                WORK_GROUP_SIZE_X = size_x,
                WORK_GROUP_SIZE_Y = size_y,
                MASK_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(_mask_texture_format),
                JFA_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(_jfa_texture_format),
                NORMAL_MAP_TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(_normal_map_texture_format)
            }
        end

        if _init_shader == nil then _init_shader = rt.ComputeShader("overworld/normal_map_compute.glsl",
            defines(0)
        ) end

        if _jump_shader == nil then _jump_shader = rt.ComputeShader("overworld/normal_map_compute.glsl",
            defines(1)
        ) end

        if _export_shader == nil then _export_shader = rt.ComputeShader("overworld/normal_map_compute.glsl",
            defines(2)
        ) end

        if _post_process_shader == nil then _post_process_shader = rt.ComputeShader("overworld/normal_map_compute.glsl",
            defines(3)
        ) end

        local padding = chunk_size / 2
        self._chunk_padding = padding
        self._chunk_size = chunk_size

        local mask = rt.RenderTexture(
            chunk_size + 2 * padding, chunk_size + 2 * padding,
            0, -- msaa
            _mask_texture_format,
            true -- computewrite
        )

        local jfa_texture = rt.RenderTextureArray(
            chunk_size + 2 * padding, chunk_size + 2 * padding,
            2, -- n layers
            0, -- msaa
            _jfa_texture_format,
            true -- computewrite
        )

        -- allocate texture atlas
        local n_chunks = #self._non_empty_chunks
        local render_atlas_n_rows = math.ceil(math.sqrt(n_chunks))
        local render_atlas_n_columns = math.ceil(math.sqrt(n_chunks))

        self._texture_atlas = rt.RenderTexture(
            render_atlas_n_rows * chunk_size,
            render_atlas_n_columns * chunk_size,
            0,
            _normal_map_texture_format,
            true
        )

        for i, chunk in ipairs(self._non_empty_chunks) do
            local col = (i - 1) % render_atlas_n_columns
            local row = math.floor((i - 1) / render_atlas_n_columns)
            local x = col * chunk_size
            local y = row * chunk_size

            chunk.quad = { x, y, chunk_size, chunk_size }
        end

        local dispatch_size_x, dispatch_size_y = math.ceil(chunk_size + 2 * padding) / size_x,
            math.ceil(chunk_size + 2 * padding) / size_y

        local mask_native = {
            mask:get_native(),
            stencil = true
        }

        for chunk in values(self._non_empty_chunks) do
            -- fill mask
            love.graphics.setCanvas(mask_native)
            love.graphics.clear(true, false, false)

            love.graphics.push()
            love.graphics.translate(-chunk.x + padding, -chunk.y + padding)
            self._draw_mask_callback()
            love.graphics.pop()

            love.graphics.setCanvas(nil)

            -- init (writes to layer 0, boundaries to both layers)
            _init_shader:send("mask_texture", mask)
            _init_shader:send("jfa_texture_array", jfa_texture)
            _init_shader:dispatch(dispatch_size_x, dispatch_size_y)

            savepoint()

            -- jfa flip flop between layers
            local jump = 0.5 * chunk_size
            local current_layer = 0

            while jump > 0.5 do -- jfa+1, necessary
                local input_layer = current_layer
                local output_layer = 1 - current_layer

                _jump_shader:send("input_layer", input_layer)
                _jump_shader:send("output_layer", output_layer)
                _jump_shader:send("jfa_texture_array", jfa_texture)
                _jump_shader:send("jump_distance", math.ceil(jump))
                _jump_shader:dispatch(dispatch_size_x, dispatch_size_y)

                current_layer = output_layer
                jump = jump / 2

                savepoint()
            end

            -- export final result
            _export_shader:send("final_layer", current_layer)
            _export_shader:send("mask_texture", mask)
            _export_shader:send("jfa_texture_array", jfa_texture)
            _export_shader:send("export_texture", self._texture_atlas)
            _export_shader:send("export_texture_quad", { self._quad:getViewport() })
            _export_shader:send("texture_atlas_quad", chunk.quad)
            _export_shader:send("max_distance", rt.settings.overworld.normal_map.max_distance)
            _export_shader:dispatch(dispatch_size_x, dispatch_size_y)

            chunk.is_initialized = true

            savepoint()
        end

        jfa_texture:release()
        mask:release()

        self._is_done = true
        self._is_visible = true

        _atlas[self._id] = {
            chunks = self._chunks,
            chunk_size = self._chunk_size,
            chunk_padding = self._chunk_padding,
            bounds = self._bounds,
            texture_atlas = self._texture_atlas
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
            if _is_disabled then
                rt.critical("In ow.NormalMap: ", error_maybe)
            else
                rt.error("In ow.NormalMap: ", error_maybe)
            end

            self._is_done = true
            self:signal_emit("done")
        end
    end
end

local _chunk_eps = function(chunk)
    return chunk / 32
end

function ow.NormalMap:draw_light(
    camera
)
    if rt.GameState:get_is_dynamic_lighting_enabled() == false or _is_disabled then return end

    meta.assert(
        camera, rt.Camera
    )

    if self._is_visible == false or not self._computation_started then return end

    local chunk_size = self._chunk_size
    local bounds = self._bounds

    local x, y, w, h = camera:get_world_bounds():unpack()

    local eps = _chunk_eps(chunk_size)
    local camera_left = x - bounds.x - eps
    local camera_right = x + w - bounds.x + eps
    local camera_top = y - bounds.y - eps
    local camera_bottom = y + h - bounds.y + eps

    local min_chunk_x = math.floor(camera_left / chunk_size)
    local max_chunk_x = math.floor(camera_right / chunk_size)
    local min_chunk_y = math.floor(camera_top / chunk_size)
    local max_chunk_y = math.floor(camera_bottom / chunk_size)

    love.graphics.push("all")

    local light_map = rt.SceneManager:get_light_map()
    _draw_light_shader:send("light_intensity", light_map:get_light_intensity())
    _draw_light_shader:send("light_direction", light_map:get_light_direction())
    _draw_light_shader:bind()

    love.graphics.setBlendMode("add", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)

    local native = self._texture_atlas:get_native()

    for chunk_x = min_chunk_x, max_chunk_x do
        local column = self._chunks[chunk_x]
        if column ~= nil then
            for chunk_y = min_chunk_y, max_chunk_y do
                local chunk = column[chunk_y]
                if chunk ~= nil and chunk.is_initialized then
                    if chunk.draw_quad == nil then
                        chunk.draw_quad = love.graphics.newQuad(
                            chunk.quad[1], chunk.quad[2], chunk.quad[3], chunk.quad[4],
                            self._texture_atlas:get_size()
                        )
                    end

                    local cell_x = bounds.x + chunk_x * chunk_size
                    local cell_y = bounds.y + chunk_y * chunk_size
                    love.graphics.draw(native, chunk.draw_quad, cell_x, cell_y)
                end
            end
        end
    end

    _draw_light_shader:unbind()
    love.graphics.pop()
end

function ow.NormalMap:draw_shadow(camera)
    if _is_disabled then return end

    meta.assert(camera, rt.Camera)

    if self._is_visible == false or not self._computation_started then return end

    local shader_bound = false
    local chunk_size = self._chunk_size
    local bounds = self._bounds

    local draw_chunk = function(chunk, chunk_x, chunk_y)
        if shader_bound == false then
            rt.graphics.set_blend_mode(rt.BlendMode.SUBTRACT, rt.BlendMode.NORMAL)
            local value = rt.settings.overworld.normal_map.shadow_strength
            love.graphics.setColor(value, value, value, value)
            _draw_shadow_shader:bind()
            shader_bound = true
        end

        if chunk.draw_quad == nil then
            chunk.draw_quad = love.graphics.newQuad(
                chunk.quad[1], chunk.quad[2], chunk.quad[3], chunk.quad[4],
                self._texture_atlas:get_size()
            )
        end

        love.graphics.draw(self._texture_atlas:get_native(), chunk.draw_quad,
            bounds.x + chunk_x * chunk_size,
            bounds.y + chunk_y * chunk_size
        )
    end

    local x, y, w, h = camera:get_world_bounds():unpack()

    x = x + self._offset_x
    y = y + self._offset_y

    local eps = _chunk_eps(chunk_size)
    local camera_left = x - bounds.x - eps
    local camera_right = x + w - bounds.x + eps
    local camera_top = y - bounds.y - eps
    local camera_bottom = y + h - bounds.y + eps

    local min_chunk_x = math.floor(camera_left / chunk_size)
    local max_chunk_x = math.floor(camera_right / chunk_size)
    local min_chunk_y = math.floor(camera_top / chunk_size)
    local max_chunk_y = math.floor(camera_bottom / chunk_size)

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
    _atlas = {}
end

--- @brief
function ow.NormalMap:get_is_done()
    return self._is_done or _is_disabled
end

--- @brief
function ow.NormalMap:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.NormalMap:get_offset()
    return self._offset_x, self._offset_y
end