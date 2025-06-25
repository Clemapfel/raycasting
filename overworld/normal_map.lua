require "common.coroutine"
require "common.compute_shader"
require "common.render_texture"

rt.settings.overworld.normal_map = {
    chunk_size = 512
}

--- @class ow.NormalMap
ow.NormalMap = meta.class("NormalMap")
meta.add_signal(ow.NormalMap, "done")

local _mask_texture_format = rt.TextureFormat.RGBA8  -- used to store alpha of walls
local _jfa_texture_format = rt.TextureFormat.RGBA32F -- used during JFA
local _normal_map_texture_format = rt.TextureFormat.RG8 -- final normal map texture

local _init_shader, _step_shader, _post_process_shader, _convert_shader

--- @brief
function ow.NormalMap:instantiate(stage)
    meta.assert(stage, ow.Stage)

    self._stage = stage

    self._chunks = {}
    self._chunks_in_order = meta.make_weak({})

    local chunk_size = rt.settings.overworld.normal_map.chunk_size

    self._chunk_size = chunk_size
    self._is_started = false
    self._is_allocated = false
    self._is_done = false

    stage:signal_connect("initialized", function()
        self._is_started = true

        local top_left_x, top_left_y, bottom_right_x, bottom_right_y = ow.Hitbox:get_global_bounds(true) -- sticky
        top_left_x = math.floor(top_left_x / chunk_size) * chunk_size
        bottom_right_x = math.ceil(bottom_right_x / chunk_size) * chunk_size
        top_left_y = math.floor(top_left_y / chunk_size) * chunk_size
        bottom_right_y = math.ceil(bottom_right_y / chunk_size) * chunk_size

        self._top_left_x, self._top_left_y, self._bottom_right_x, self._bottom_right_y = top_left_x, top_left_y, bottom_right_x, bottom_right_y
        self._bounds = rt.AABB(top_left_x, top_left_y, bottom_right_x - top_left_x, bottom_right_y - top_left_y)

        self._is_started = true
        return meta.DISCONNECT_SIGNAL
    end)

    self._allocate_callback = rt.Coroutine(function()
        if not self._is_started then rt.savepoint() end

        local world = stage:get_physics_world()

        local min_x, max_x = self._top_left_x, self._bottom_right_x
        local min_y, max_y = self._top_left_y, self._bottom_right_y

        local before = love.timer.getTime()
        for x = min_x, max_x - 1, chunk_size do
            local chunk_x = math.floor(x / chunk_size)
            if self._chunks[chunk_x] == nil then
                self._chunks[chunk_x] = {}
            end

            for y = min_x, max_y - 1, chunk_size do
                local chunk_y = math.floor(y / chunk_size)

                local all_bodies = world:query_aabb(x, y, chunk_size, chunk_size)
                local bodies = meta.make_weak({})

                local is_empty = true
                for body in values(all_bodies) do
                    if body:has_tag("hitbox") then
                        is_empty = false
                        table.insert(bodies, body)
                    end
                end

                local chunk  = {
                    x = chunk_x,
                    y = chunk_y,
                    is_empty = is_empty
                }

                if not is_empty then
                    meta.make_weak(bodies)
                    chunk.bodies = bodies
                    chunk.texture = rt.RenderTexture(chunk_size, chunk_size, 0, _normal_map_texture_format, true)
                    chunk.initialized = false
                    table.insert(self._chunks_in_order, chunk)
                end

                self._chunks[chunk_x][chunk_y] = chunk

                local now = love.timer.getTime()
                if now - before > 0.2 * (1 / 60) then
                    rt.savepoint()
                end
                before = now
            end
        end

        self._is_allocated = true
    end)

    self._compute_sdf_callback = rt.Coroutine(function()
        if not self._is_allocated then rt.savepoint() end

        if _init_shader == nil then _init_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 0 }) end
        if _step_shader == nil then _step_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 1 }) end
        if _post_process_shader == nil then _post_process_shader = rt.ComputeShader("overworld/normal_map_compute.glsl", { MODE = 2 }) end

        local mask_texture = rt.RenderTexture(chunk_size, chunk_size, 4, _mask_texture_format, true):get_native()
        local texture_a = rt.RenderTexture(chunk_size, chunk_size, 0, _jfa_texture_format, true):get_native()
        local texture_b = rt.RenderTexture(chunk_size, chunk_size, 0, _jfa_texture_format, true):get_native()
        local dispatch_size = chunk_size / 32
        local lg = love.graphics

        local camera = self._stage:get_scene():get_camera()

        for chunk in values(self._chunks_in_order) do
            -- draw mask
            lg.setCanvas({ mask_texture, stencil = true })
            lg.clear(0, 0, 0, 0)

            camera:bind()
            local drawn = false
            for body in values(chunk.bodies) do
                if body.draw_mask ~= nil then
                    body:draw_mask()
                else
                    body:draw()
                end
            end
            camera:unbind()
            lg.setCanvas(nil)

            for to_clear in range(texture_a, texture_b) do
                lg.setCanvas(to_clear)
                lg.clear(0, 0, 0, 0)
                lg.setCanvas(nil)
            end

            -- init
            _init_shader:send("mask_texture", mask_texture)
            _init_shader:send("input_texture", texture_a)
            _init_shader:send("output_texture", texture_b)
            _init_shader:dispatch(dispatch_size, dispatch_size)

            -- jfa
            local jump = 0.5 * chunk_size
            local a_or_b = true
            while jump > 1 do
                if a_or_b then
                    _step_shader:send("input_texture", texture_a)
                    _step_shader:send("output_texture", texture_b)
                else
                    _step_shader:send("input_texture", texture_b)
                    _step_shader:send("output_texture", texture_a)
                end

                _step_shader:send("jump_distance", math.ceil(jump))
                _step_shader:dispatch(dispatch_size, dispatch_size)

                a_or_b = not a_or_b
                jump = jump / 2
            end

            -- draw to final texture
            chunk.texture:bind()


            chunk.initialized = true
        end

        self._is_done = true
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

function ow.NormalMap:draw()
    local x, y, w, h = self._stage:get_scene():get_camera():get_world_bounds()
    local chunk_size = self._chunk_size

    local min_chunk_x = math.floor((x - self._bounds.x) / chunk_size)
    local max_chunk_x = math.floor(((x + w - 1) - self._bounds.x) / chunk_size)
    local min_chunk_y = math.floor((y - self._bounds.y) / chunk_size)
    local max_chunk_y = math.floor(((y + h - 1) - self._bounds.y) / chunk_size)

    for chunk_x = min_chunk_x, max_chunk_x do
        local column = self._chunks[chunk_x]
        if column then
            for chunk_y = min_chunk_y, max_chunk_y do
                local chunk = column[chunk_y]
                if chunk and not chunk.is_empty and chunk.initialized then
                    local draw_x = self._bounds.x + chunk_x * chunk_size
                    local draw_y = self._bounds.y + chunk_y * chunk_size
                    chunk.texture:draw(draw_x, draw_y)
                    love.graphics.rectangle(draw_x, draw_y, chunk_size, chunk_size)
                end
            end
        end
    end
end