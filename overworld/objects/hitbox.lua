require "common.shader"
require "common.mesh"

--- @class ow.Hitbox
ow.Hitbox = meta.class("Hitbox")

ow.SlipperyHitbox = function(object, stage, scene)
    object.properties["slippery"] = true
    return ow.Hitbox(object, stage, scene)
end

-- manually batched, cf. draw_all
local _slippery_tris = {}
local _slippery_lines = {}
local _slippery_mesh = nil
local _slippery_min_x, _slippery_min_y = math.huge, math.huge
local _slippery_max_x, _slippery_max_y = -math.huge, -math.huge

local _sticky_tris = {}
local _sticky_lines = {}
local _sticky_mesh = nil
local _sticky_shader
local _sticky_min_x, _sticky_min_y = math.huge, math.huge
local _sticky_max_x, _sticky_max_y = -math.huge, -math.huge


local _initialized = false

local first = true

--- @brief
function ow.Hitbox:instantiate(object, stage, scene)
    if _sticky_shader == nil then _sticky_shader = rt.Shader("overworld/objects/hitbox.glsl") end

    -- tODO
    if first then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "f" then
                _sticky_shader:recompile()
            end
        end)
        first = false
    end

    self._body = object:create_physics_body(stage:get_physics_world())

    for property in range(
        "slippery",
        "sticky"
    ) do
        if object:get_boolean(property) then
            self._body:add_tag(property)
        end
    end

    if self._body:has_tag("slippery") then
        self._body:add_tag("no_blood")
    end

    self._body:add_tag("hitbox", "stencil")

    local friction = object:get_number("friction")

    if friction == nil then
        if self._body:has_tag("slippery") then
            friction = 0
        else
            friction = 0
        end
    end
    self._body:set_friction(friction or 1)
    self._body:set_use_continuous_collision(true)

    local _, tris = object:create_mesh()

    if self._body:has_tag("slippery") then
        for tri in values(tris) do
            table.insert(_slippery_tris, tri)

            for i = 1, 6, 2 do
                local x, y = tri[i+0], tri[i+1]
                _slippery_min_x = math.min(_slippery_min_x, x)
                _slippery_max_x = math.max(_slippery_max_x, x)
                _slippery_min_y = math.min(_slippery_min_y, y)
                _slippery_max_y = math.max(_slippery_max_y, y)
            end
        end
    else
        for tri in values(tris) do
            table.insert(_sticky_tris, tri)

            for i = 1, 6, 2 do
                local x, y = tri[i+0], tri[i+1]
                _sticky_min_x = math.min(_sticky_min_x, x)
                _sticky_max_x = math.max(_sticky_max_x, x)
                _sticky_min_y = math.min(_sticky_min_y, y)
                _sticky_max_y = math.max(_sticky_max_y, y)
            end
        end
    end

    local id_to_group = {
        [1] = b2.CollisionGroup.GROUP_01,
        [2] = b2.CollisionGroup.GROUP_02,
        [3] = b2.CollisionGroup.GROUP_03,
        [4] = b2.CollisionGroup.GROUP_04,
        [5] = b2.CollisionGroup.GROUP_05,
        [6] = b2.CollisionGroup.GROUP_06,
        [7] = b2.CollisionGroup.GROUP_07,
        [8] = b2.CollisionGroup.GROUP_08,
        [9] = b2.CollisionGroup.GROUP_09,
        [10] = b2.CollisionGroup.GROUP_10,
        [11] = b2.CollisionGroup.GROUP_11,
        [12] = b2.CollisionGroup.GROUP_12,
        [13] = b2.CollisionGroup.GROUP_13,
        [14] = b2.CollisionGroup.GROUP_14,
        [15] = b2.CollisionGroup.GROUP_15,
        [16] = b2.CollisionGroup.GROUP_16
    }

    local filter = object:get_number("filter")
    if filter ~= nil then
        local group = id_to_group[filter]
        if group == nil then
            rt.error("In ow.Hitbox.instantiate: object `" .. object:get_id() .. "` in stage `" .. stage:get_id() .. "` property `filter` expects number between 1 and 16")
        end
        self._body:set_collides_with(bit.bnot(group))
    end
end

--- @brief
function ow.Hitbox:reinitialize()
    _slippery_tris = {}
    _slippery_lines = {}

    if _slippery_mesh ~= nil then
        _slippery_mesh:release()
    end
    _slippery_mesh = nil

    _sticky_tris = {}
    _sticky_lines = {}

    if _sticky_mesh ~= nil then
        _sticky_mesh:release()
    end
    _sticky_mesh = nil

    _slippery_min_x, _slippery_min_y = math.huge, math.huge
    _slippery_max_x, _slippery_max_y = -math.huge, -math.huge
    _sticky_min_x, _sticky_min_y = math.huge, math.huge
    _sticky_max_x, _sticky_max_y = -math.huge, -math.huge

    _initialized = false
end

local _initialize = function()
    if _initialized ~= true then
        local format = { {location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2"} }
        local mode, usage = rt.MeshDrawMode.TRIANGLES, rt.GraphicsBufferUsage.STATIC

        if table.sizeof(_sticky_tris) > 0 then
            local sticky_data = {}
            for tri in values(_sticky_tris) do
                table.insert(sticky_data, { tri[1], tri[2] })
                table.insert(sticky_data, { tri[3], tri[4] })
                table.insert(sticky_data, { tri[5], tri[6] })

                table.insert(_sticky_lines, {
                    tri[1], tri[2], tri[3], tri[4], tri[5], tri[6], tri[1], tri[2]
                })
            end
            _sticky_mesh = love.graphics.newMesh(format, sticky_data, mode, usage)
        end

        if table.sizeof(_slippery_tris) > 0 then
            local slippery_data = {}
            for tri in values(_slippery_tris) do
                table.insert(slippery_data, { tri[1], tri[2] })
                table.insert(slippery_data, { tri[3], tri[4] })
                table.insert(slippery_data, { tri[5], tri[6] })

                table.insert(_slippery_lines, {
                    tri[1], tri[2], tri[3], tri[4], tri[5], tri[6], tri[1], tri[2]
                })
            end
            _slippery_mesh = love.graphics.newMesh(format, slippery_data, mode, usage)
        end

        _initialized = true
    end
end

--- @brief
function ow.Hitbox:draw_all()
    _initialize()

    love.graphics.setLineJoin("bevel")

    local slippery, sticky
    if _slippery_mesh ~= nil then
        slippery = {_slippery_mesh, _slippery_lines, nil, rt.Palette.SLIPPERY, rt.Palette.SLIPPERY_OUTLINE, 4}
    end

    if _sticky_mesh ~= nil then
        sticky = {_sticky_mesh, _sticky_lines, nil, rt.Palette.STICKY, rt.Palette.STICKY_OUTLINE, 4}
    end

    for params in range(slippery, sticky) do
        local mesh, outlines, shader, mesh_color, outline_color, line_width = table.unpack(params)

        mesh_color:bind()

        if shader ~= nil then
            shader:bind()
            shader:send("elapsed", rt.SceneManager:get_elapsed())

            local scene = rt.SceneManager:get_current_scene()
            if meta.isa(scene, ow.OverworldScene) then
                local camera = scene:get_camera()
                local player = scene:get_player()
                shader:send("camera_offset", { scene:get_camera():get_offset() })
                shader:send("camera_scale", scene:get_camera():get_scale())
                shader:send("player_position", { camera:world_xy_to_screen_xy(player:get_physics_body():get_position()) })
                shader:send("player_color", { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1)})
                shader:send("player_flow", player:get_flow())
            end
        end

        love.graphics.draw(mesh)

        if shader ~= nil then
            shader:unbind()
        end

        local stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.stencil(stencil_value, function()
            love.graphics.draw(mesh)
        end)
        rt.graphics.set_stencil_compare_mode(rt.StencilCompareMode.NOT_EQUAL, stencil_value)

        rt.Palette.BLACK:bind()
        love.graphics.setLineWidth(line_width + 2.5)
        for lines in values(outlines) do
            --love.graphics.line(lines)
        end

        outline_color:bind()
        love.graphics.setLineWidth(line_width)
        for lines in values(outlines) do
            love.graphics.line(lines)
        end

        rt.graphics.set_stencil_compare_mode(nil)
    end
end

--- @brief
function ow.Hitbox:draw_mask(sticky_or_slippery)
    _initialize()

    love.graphics.setColor(1, 1, 1, 1)
    if sticky_or_slippery == false and _slippery_mesh ~= nil then
        love.graphics.draw(_slippery_mesh)
    elseif sticky_or_slippery == true and _sticky_mesh ~= nil then
        love.graphics.draw(_sticky_mesh)
    else
        if _sticky_mesh ~= nil then
            love.graphics.draw(_sticky_mesh)
        end

        if _slippery_mesh ~= nil then
            love.graphics.draw(_slippery_mesh)
        end
    end
end

--- @brief
function ow.Hitbox:get_tris(sticky_or_slippery)
    local tris = {}

    if sticky_or_slippery == true or sticky_or_slippery == nil then
        for tri in values(_sticky_tris) do
            table.insert(tris, tri)
        end
    end

    if sticky_or_slippery == false or sticky_or_slippery == nil then
        for tri in values(_slippery_tris) do
            table.insert(tris, tri)
        end
    end

    return tris
end

--- @brief
function ow.Hitbox:get_render_priority()
    if self._body:has_tag("slippery") then
        return -1
    else
        return -2
    end
end

--- @brief
function ow.Hitbox:get_global_bounds(sticky_or_slippery)
    if sticky_or_slippery == true then
        return _sticky_min_x, _sticky_min_y, _sticky_max_x, _sticky_max_y
    elseif sticky_or_slippery == false then
        return _slippery_min_x, _slippery_min_y, _slippery_max_x, _slippery_max_y
    else
        return math.min(_sticky_min_x, _slippery_min_x),
            math.min(_sticky_min_y, _slippery_min_y),
            math.max(_sticky_max_x, _slippery_max_x),
            math.max(_sticky_max_y, _slippery_max_y)
    end
end

