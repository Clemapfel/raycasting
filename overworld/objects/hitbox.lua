require "common.blend_mode"
require "overworld.object_wrapper"

--- @class ow.Hitbox
ow.Hitbox = meta.class("OverworldHitbox")


--- @brief
function ow.Hitbox:instantiate(object, world)
    meta.assert(object, "ObjectWrapper", world, "PhysicsWorld")

    self._world = world
    self._body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0, object:get_physics_shapes())
end

--- @brief
function ow.Hitbox:draw()
    local fill_a = 0
    local line_a = 1
    local value = 1
    local r, g, b = rt.lcha_to_rgba(0.8, 1, ((meta.hash(self) * 1234567) % 256) / 256)
    rt.graphics.set_blend_mode(rt.BlendMode.NORMAL, rt.BlendMode.NORMAL)
    for shape in values(self._shapes) do
        if shape.type == ow.PhysicsShapeType.CIRCLE then
            love.graphics.setColor(r, g, b, fill_a)
            --love.graphics.circle("fill", shape.x, shape.y, shape.radius)
            love.graphics.setColor(r, g, b, line_a)
            love.graphics.circle("line", shape.x, shape.y, shape.radius)
        elseif shape.type == ow.PhysicsShapeType.POLYGON then
            love.graphics.setColor(r, g, b, fill_a)
            --love.graphics.polygon("fill", shape.vertices)
            love.graphics.setColor(r, g, b, line_a)
            love.graphics.polygon("line", shape.vertices)
        else
            rt.error("In ow.Hitbox: unhandled physics object type `" .. tostring(shape.type) .. "`")
        end
    end
    rt.graphics.set_blend_mode()
end
