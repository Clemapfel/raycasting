require "common.timed_animation_chain"

--- @class ow.ResultScreen
ow.ResultsScreen = meta.class("ResultScreen", rt.Widget)

local _shader

--- @param t Number [0, n-1]
--- @param ... rt.AABB n aabbs
local _lerp_aabbs = function(t, frames)
    local n = #frames
    t = math.clamp(t, 1, n)

    local segment = math.floor(t)
    local local_t = t - segment

    local aabb1 = frames[math.min(segment + 0, n)]
    local aabb2 = frames[math.min(segment + 1, n)]

    local x = math.mix(aabb1.x, aabb2.x, local_t)
    local y = math.mix(aabb1.y, aabb2.y, local_t)
    local width = math.mix(aabb1.width, aabb2.width, local_t)
    local height = math.mix(aabb1.height, aabb2.height, local_t)

    return x, y, width, height
end

--- @brief
function ow.ResultsScreen:instantiate()
    if _shader == nil then
        _shader = rt.Shader("overworld/result_screen.glsl")
        _shader:send("black", { rt.Palette.GRAY:unpack() })
    end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "j" then _shader:recompile() end
        --self._sequence:reset()
    end)

    self._sequence = rt.TimedAnimationChain(
        rt.TimedAnimation( -- upwards
            1,    -- duration
            1, 2, -- aabb lerp t
            rt.InterpolationFunctions.SINUSOID_EASE_OUT
        ),

        rt.TimedAnimation(
            1,
            2, 3,
            rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT
        ),

        rt.TimedAnimation(
            1,
            3, 4,
            rt.InterpolationFunctions.LINEAR
        )
    )

    self._frames = {} -- List<rt.AABB>
end

--- @brief
function ow.ResultsScreen:update(delta)
    if self._sequence:get_animation_index() < 3 then
        self._sequence:update(delta)
    end
    local t = self._sequence:get_value()
    local x, y, w, h = _lerp_aabbs(t, self._frames)
    self._dbg = rt.AABB(x, y, w, h)
    self:_update_mesh(x, y, w, h, self._mesh_m)
end

--- @brief
function ow.ResultsScreen:size_allocate(x, y, width, height)
    local m = 100 * rt.get_pixel_scale()
    local w = (width - 2 * m) / 2
    local h = (height - 2 * m)
    local expand_w = 0.5 * width -- TODO

    self._mesh_m = m
    self._frames = {
        rt.AABB( -- start
            x + 0.5 * width - m,
            y + height,
            2 * m,
            height + 2 * m
        ),

        rt.AABB( -- upwards
            x + 0.5 * width - m,
            y - m,
            2 * m,
            height + 2 * m
        ),

        rt.AABB( -- expand
            x + 0.5 * width - 0.5 * expand_w - m,
            y - m,
            expand_w + 2 * m,
            height + 2 * m
        ),

        rt.AABB( -- fill
            x - m,
            y - m,
            width + 2 * m,
            height + 2 * m
        )
    }

    self:update(0) -- update mesh from current animation
end

--- @brief
function ow.ResultsScreen:draw()
    love.graphics.setColor(1, 1, 1, 1)

    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("black", { rt.Palette.GRAY:unpack() })
    self._mesh:draw()
    _shader:unbind()

    love.graphics.setColor(1, 0, 1, 1)
    if self._dbg ~= nil then
        love.graphics.rectangle("line", self._dbg:unpack())
    end
end

--- @brief
function ow.ResultsScreen:_update_mesh(x, y, w, h, m)
    -- convert overall size to size of inner slice
    w = w - 2 * m
    h = h - 2 * m
    w = w / 2

    local x1, x2, x3, x4, x5
    x1 = x
    x2 = x + m
    x3 = x + m + w
    x4 = x + m + w + w
    x5 = x + m + w + w + m

    local y1, y2, y3, y4
    y1 = y
    y2 = y + m
    y3 = y + m + h
    y4 = y + m + h + m

    local u0, u1, v0, v1 = 0, 1, 0, 1
    local c1 = function() return 1, 1, 1, 1  end
    local c0 = function() return 0, 0, 0, 1  end

    local data = {
        { x1, y1, u1, v1, c1() },
        { x2, y1, u0, v1, c1() },
        { x3, y1, u0, v1, c1() },
        { x4, y1, u0, v1, c1() },
        { x5, y1, u1, v1, c1() },
        { x1, y2, u1, v0, c1() },
        { x2, y2, u0, v0, c0() },
        { x3, y2, u0, v0, c0() },
        { x4, y2, u0, v0, c0() },
        { x5, y2, u1, v0, c1() },
        { x1, y3, u1, v0, c1() },
        { x2, y3, u0, v0, c0() },
        { x3, y3, u0, v0, c0() },
        { x4, y3, u0, v0, c0() },
        { x5, y3, u1, v0, c1() },
        { x1, y4, u1, v1, c1() },
        { x2, y4, u0, v1, c1() },
        { x3, y4, u0, v1, c1() },
        { x4, y4, u0, v1, c1() },
        { x5, y4, u1, v1, c1() },
    }

    if self._mesh == nil then
        local vertex_map = {
            1, 2, 7,
            1, 7, 6,
            2, 3, 8,
            2, 8, 7,
            3, 4, 8,
            4, 8, 9,
            4, 5, 9,
            5, 9, 10,
            6, 7, 11,
            7, 11, 12,
            7, 8, 12,
            8, 12, 13,
            8, 9, 13,
            9, 13, 14,
            9, 10, 14,
            10, 14, 15,
            11, 12, 16,
            12, 16, 17,
            12, 13, 17,
            13, 17, 18,
            13, 14, 19,
            13, 19, 18,
            14, 15, 20,
            14, 20, 19
        }

        self._mesh = rt.Mesh(
            data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STREAM
        )
        self._mesh:set_vertex_map(vertex_map)
    else
        self._mesh:replace_data(data)
    end
end