require "common.shader"
require "common.mesh"

rt.settings.overworld.hitbox = {
    collision_group = b2.CollisionGroup.GROUP_10,
    sticky_outline_width = 1,
    slippery_outline_width = 1,
    render_priority = -1
}

--- @class ow.Hitbox
--- @types Polygon, Rectangle, Ellipse
ow.Hitbox = meta.class("Hitbox")

--- @class ow.SlipperyHitbox
--- @types Polygon, Rectangle, Ellipse
ow.SlipperyHitbox = function(object, stage, scene)
    object.properties["slippery"] = true
    return ow.Hitbox(object, stage, scene)
end

--- @class ow.SlipperyHitbox
--- @types Polygon, Rectangle, Ellipse
ow.StickyHitbox = function(object, stage, scene)
    object.properties["slippery"] = false
    return ow.Hitbox(object, stage, scene)
end

-- manually batched, cf. draw_all
ow.Hitbox._slippery_collision_tris = {}
ow.Hitbox._slipper_mesh_tris = {}
ow.Hitbox._slippery_mesh = nil

ow.Hitbox._sticky_mesh_tris = {}
ow.Hitbox._sticky_collision_tris = {}
ow.Hitbox._sticky_mesh = nil

ow.Hitbox._initialized = false

--- @brief
function ow.Hitbox:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())

    for property in range(
        "slippery",
        "sticky",
        "unjumpable",
        "unwalkable"
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
    self._body:set_friction(friction or -1)
    self._body:set_use_continuous_collision(true)

    local _, tris = object:create_mesh()
    local contour = object:create_contour()
    table.insert(contour, contour[1])
    table.insert(contour, contour[2])

    self._contour = contour
    self._stage = stage

    if self._body:has_tag("slippery") then
        for tri in values(tris) do
            table.insert(ow.Hitbox._slippery_mesh_tris, tri)
            table.insert(ow.Hitbox._slippery_collision_tris, tri)
        end

        self._color = rt.Palette.SLIPPERY_OUTLINE
        self._outline_width = rt.settings.overworld.hitbox.slippery_outline_width
        self._render_priority = -3
    else
        for tri in values(tris) do
            table.insert(ow.Hitbox._sticky_mesh_tris, tri)
            table.insert(ow.Hitbox._sticky_collision_tris, tri)
        end

        self._color = rt.Palette.STICKY_OUTLINE
        self._outline_width = rt.settings.overworld.hitbox.sticky_outline_width
        self._render_priority = -2
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
            rt.error("In ow.Hitbox.instantiate: object `" .. object:get_id(),  "` in stage `",  stage:get_id(),  "` property `filter` expects number between 1 and 16")
        end
        self._body:set_collides_with(bit.bnot(group))
    end

    self._body:set_collision_group(rt.settings.overworld.hitbox.collision_group)
end

--- @brief
function ow.Hitbox:reinitialize()
    ow.Hitbox._slippery_mesh_tris = {}
    ow.Hitbox._slippery_collision_tris = {}

    if #ow.Hitbox._slippery_mesh_tris > 0 then
        ow.Hitbox._slippery_mesh:release()
    end
    ow.Hitbox._slippery_mesh = nil

    ow.Hitbox._sticky_mesh_tris = {}
    ow.Hitbox._sticky_collision_tris = {}

    if #ow.Hitbox._sticky_mesh_tris > 0 then
        ow.Hitbox._sticky_mesh:release()
    end
    ow.Hitbox._sticky_mesh = nil

    ow.Hitbox._initialized = false
end

local _initialize = function()
    if ow.Hitbox._initialized ~= true then
        local format = { {location = 0, name = rt.VertexAttribute.POSITION, format = "floatvec2"} }
        local mode, usage = rt.MeshDrawMode.TRIANGLES, rt.GraphicsBufferUsage.STATIC

        if #ow.Hitbox._sticky_mesh_tris > 0 then
            local sticky_data = {}
            for tri in values(ow.Hitbox._sticky_mesh_tris) do
                table.insert(sticky_data, { tri[1], tri[2] })
                table.insert(sticky_data, { tri[3], tri[4] })
                table.insert(sticky_data, { tri[5], tri[6] })
            end
            ow.Hitbox._sticky_mesh = love.graphics.newMesh(format, sticky_data, mode, usage)
        end

        if #ow.Hitbox._slippery_mesh_tris > 0 then
            local slippery_data = {}
            for tri in values(ow.Hitbox._slippery_mesh_tris) do
                table.insert(slippery_data, { tri[1], tri[2] })
                table.insert(slippery_data, { tri[3], tri[4] })
                table.insert(slippery_data, { tri[5], tri[6] })
            end
            ow.Hitbox._slippery_mesh = love.graphics.newMesh(format, slippery_data, mode, usage)
        end

        ow.Hitbox._initialized = #ow.Hitbox._sticky_mesh_tris > 0 or #ow.Hitbox._slippery_mesh_tris > 0
    end

    return ow.Hitbox._initialized
end

--- @brief
function ow.Hitbox:get_render_priority()
    return self._render_priority
end

--- @brief
function ow.Hitbox:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    love.graphics.setLineWidth(self._outline_width)
    love.graphics.setLineJoin("bevel")
    self._color:bind()
    love.graphics.line(self._contour)
end

--- @brief
function ow.Hitbox:draw_stencil()
    self._body:draw()
end

--- @brief
function ow.Hitbox:draw_base()
    if not _initialize() then return end

    if #ow.Hitbox._slippery_mesh_tris > 0 then
        rt.Palette.SLIPPERY:bind()
        love.graphics.draw(ow.Hitbox._slippery_mesh)
    end

    if #ow.Hitbox._sticky_mesh_tris > 0 then
        rt.Palette.STICKY:bind()
        love.graphics.draw(ow.Hitbox._sticky_mesh)
    end
end

--- @brief
function ow.Hitbox:draw_outline()
    if not _initialize() then return end
    -- noop, handled in individual draw
end

--- @brief
function ow.Hitbox:draw_mask(sticky, slippery)
    if sticky == nil then sticky = true end
    if slippery == nil then slippery = true end

    if not _initialize() then return end

    love.graphics.setColor(1, 1, 1, 1)
    if slippery == true and #ow.Hitbox._slippery_mesh_tris > 0 then
        love.graphics.draw(ow.Hitbox._slippery_mesh)
    end

    if sticky == true and #ow.Hitbox._sticky_mesh_tris > 0 then
        love.graphics.draw(ow.Hitbox._sticky_mesh)
    end
end

--- @brief
function ow.Hitbox:get_mesh_tris(sticky, slippery)
    if sticky == nil then sticky = true end
    if slippery == nil then slippery = true end

    local tris = {}

    if sticky == true then
        for tri in values(ow.Hitbox._sticky_mesh_tris) do
            table.insert(tris, tri)
        end
    end

    if slippery == true then
        for tri in values(ow.Hitbox._slippery_mesh_tris) do
            table.insert(tris, tri)
        end
    end

    return tris
end

--- @brief
function ow.Hitbox:get_collision_tris(sticky, slippery)
    if sticky == nil then sticky = true end
    if slippery == nil then slippery = true end

    local tris = {}

    if sticky == true then
        for tri in values(ow.Hitbox._sticky_collision_tris) do
            table.insert(tris, tri)
        end
    end

    if slippery == true then
        for tri in values(ow.Hitbox._slippery_collision_tris) do
            table.insert(tris, tri)
        end
    end

    return tris
end
