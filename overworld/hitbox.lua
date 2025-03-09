require "common.blend_mode"
require "overworld.object_wrapper"

--- @class ow.Hitbox
ow.Hitbox = meta.class("OverworldHitbox")

ow.PhysicsShapeType = meta.enum("PhysicsShapeType", {
    CIRCLE = "circle",
    POLYGON = "polygon"
})

local function _process_polygon(vertices, object)

    local function rotate_point(x, y, angle)
        local cos_theta = math.cos(angle)
        local sin_theta = math.sin(angle)
        return x * cos_theta - y * sin_theta, x * sin_theta + y * cos_theta
    end

    local out = {}
    for i = 1, #vertices, 2 do
        local x, y = vertices[i], vertices[i + 1]

        x, y = x - object.origin_x, y - object.origin_y
        x, y = rotate_point(x, y, object.rotation)
        x, y = x + object.origin_x, y + object.origin_y

        if object.flip_horizontally or object.flip_vertically then
            x, y = x - object.flip_origin_x, y - object.flip_origin_y
            x = object.flip_horizontally and -x or x
            y = object.flip_vertically and -y or y
            x, y = x + object.flip_origin_x, y + object.flip_origin_y
        end

        x, y = x + object.offset_x, y + object.offset_y

        x, y = x - object.rotation_origin_x, y - object.rotation_origin_y
        x, y = rotate_point(x, y, object.rotation_offset)
        x, y = x + object.rotation_origin_x, y + object.rotation_origin_y

        table.insert(out, x)
        table.insert(out, y)
    end

    return out
end

--- @brief
function ow.Hitbox:instantiate(...)
    self._shapes = {}
    local print = false
    for i = 1, select("#", ...) do
        local object = select(i, ...)
        print = print or object.properties["print"]
        meta.assert_typeof(object, "ObjectWrapper", i)

        if object.type == ow.ObjectType.RECTANGLE then
            local x, y = object.x, object.y
            local w, h = object.width, object.height

            table.insert(self._shapes, {
                type = ow.PhysicsShapeType.POLYGON,
                vertices = _process_polygon({
                    x, y,
                    x + w, y,
                    x + w, y + h,
                    x, y + h
                },
                    object
                );
            })
        elseif object.type == ow.ObjectType.ELLIPSE then
            local is_circle = math.abs(object.x_radius - object.y_radius) < 1
            if is_circle then
                local vertices = _process_polygon({
                    object.center_x,
                    object.center_y
                },
                    object
                )

                table.insert(self._shapes, {
                    type = ow.PhysicsShapeType.CIRCLE,
                    x = vertices[1],
                    y = vertices[2],
                    radius = math.max(object.x_radius, object.y_radius)
                })
            else
                local vertices = {}

                local center_x, center_y = object.center_x, object.center_y
                local x_radius, y_radius = object.x_radius, object.y_radius
                local n_outer_vertices = 16
                local angle_step = (2 * math.pi) / n_outer_vertices
                for angle = 0, 2 * math.pi, angle_step do
                    table.insert(vertices, center_x + x_radius * math.cos(angle))
                    table.insert(vertices, center_y + y_radius * math.sin(angle))
                end

                vertices = _process_polygon(
                    vertices,
                    object
                )

                local polygonization = slick.polygonize(8, { vertices })

                for shape in values(polygonization) do
                    table.insert(self._shapes, {
                        type = ow.PhysicsShapeType.POLYGON,
                        vertices = shape
                    })
                end
            end
        elseif object.type == ow.ObjectType.POLYGON then
            for vertices in values(object.shapes) do
                table.insert(self._shapes, {
                    type = ow.PhysicsShapeType.POLYGON,
                    vertices = _process_polygon(
                        vertices,
                        object
                    )
                })
            end
        else
            rt.error("In ow.Hitbox: unhandled object type `" .. tostring(object.type) .. "`")
        end
    end
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

--- @brief
function ow.Hitbox:as_physics_shapes()
    local out = {}
    for shape in values(self._shapes) do
        if shape.type == ow.PhysicsShapeType.CIRCLE then
            table.insert(out, b2.Circle(shape.x, shape.y, shape.radius))
        elseif shape.type == ow.PhysicsShapeType.POLYGON then
            table.insert(out, b2.Polygon(shape.vertices))
        else
            rt.error("In ow.Hitbox:as_physics_shape: unhandled shape type `" .. tostring(shape.type) .. "`")
        end
    end

    return out
end