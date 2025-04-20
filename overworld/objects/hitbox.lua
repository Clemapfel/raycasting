require "common.shader"
require "common.mesh"

--- @class ow.Hitbox
ow.Hitbox = meta.class("Hitbox")

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

    self._body:set_friction(object:get_number("friction") or 0)

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
end

--- @brief
function ow.Hitbox:reinitialize()
    _slippery_tris = {}
    _slippery_lines = {}
    _slippery_mesh = nil

    _sticky_tris = {}
    _sticky_lines = {}
    _sticky_mesh = nil
    _initialized = false
end

--- @brief
function ow.Hitbox:draw_all()
    if _initialized ~= true then
        local format = { {location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2"} }
        local mode, usage = rt.MeshDrawMode.TRIANGLES, rt.GraphicsBufferUsage.STATIC

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

        _initialized = true
    end

    love.graphics.setLineJoin("bevel")

    for params in range(
        {_slippery_mesh, _slippery_lines, rt.Palette.SLIPPERY, rt.Palette.SLIPPERY_OUTLINE, 4},
        {_sticky_mesh, _sticky_lines, rt.Palette.STICKY, rt.Palette.STICKY_OUTLINE, 2.5}
    ) do
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