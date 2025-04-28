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

local _sticky_tris = {}
local _sticky_lines = {}
local _sticky_mesh = nil

local _initialized = false

--- @brief
function ow.Hitbox:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())

    for property in range(
        "slippery",
        "sticky"
    ) do
        if object:get_boolean(property) then
            self._body:add_tag(property)
        end
    end

    self._body:set_friction(object:get_number("friction") or 1)

    local _, tris = object:create_mesh()

    if self._body:has_tag("slippery") then
        for tri in values(tris) do
            table.insert(_slippery_tris, tri)
        end
    else
        for tri in values(tris) do
            table.insert(_sticky_tris, tri)
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

    _initialized = false
end

--- @brief
function ow.Hitbox:draw_all()
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

    love.graphics.setLineJoin("bevel")

    local slippery, sticky
    if _slippery_mesh ~= nil then
        slippery = {_slippery_mesh, _slippery_lines, rt.Palette.SLIPPERY, rt.Palette.SLIPPERY_OUTLINE, 4}
    end

    if _sticky_mesh ~= nil then
        sticky = {_sticky_mesh, _sticky_lines, rt.Palette.STICKY, rt.Palette.STICKY_OUTLINE, 2.5}
    end

    for params in range(slippery, sticky) do
        local mesh, outlines, mesh_color, outline_color, line_width = table.unpack(params)

        mesh_color:bind()
        love.graphics.draw(mesh)

        local stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.stencil(stencil_value, function()
            love.graphics.draw(mesh)
        end)
        rt.graphics.set_stencil_test(rt.StencilCompareMode.NOT_EQUAL, stencil_value)

        rt.Palette.BLACK:bind()
        love.graphics.setLineWidth(line_width + 2)
        for lines in values(outlines) do
            love.graphics.line(lines)
        end

        outline_color:bind()
        love.graphics.setLineWidth(line_width)
        for lines in values(outlines) do
            love.graphics.line(lines)
        end

        rt.graphics.set_stencil_test(nil)
    end
end

--- @brief
function ow.Hitbox:get_all_segments()
    local segments = {}
    for tri in values(_sticky_tris) do
        for segment in range(
            {tri[1], tri[2], tri[3], tri[4]},
            {tri[3], tri[4], tri[5], tri[6]},
            {tri[1], tri[2], tri[5], tri[6]}
        ) do
            table.insert(segments, segment)
        end
    end

    for tri in values(_slippery_tris) do
        for segment in range(
            {tri[1], tri[2], tri[3], tri[4]},
            {tri[3], tri[4], tri[5], tri[6]},
            {tri[1], tri[2], tri[5], tri[6]}
        ) do
            table.insert(segments, segment)
        end
    end

    return segments
end
