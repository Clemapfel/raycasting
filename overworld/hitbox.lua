require "overworld.object_group"

--- @class ow.Hitbox
ow.Hitbox = meta.class("OverworldHitbox")

ow.PhysicsShapeType = meta.enum("PhysicsShapeType", {
    CIRCLE = "circle",
    POLYGON = "polygon"
})

local function _process_polygon(vertices, angle, origin_x, origin_y, offset_x, offset_y, flip_horizontally, flip_vertically, flip_origin_x, flip_origin_y)
    if flip_horizontally == nil then flip_horizontally = false end
    if flip_vertically == nil then flip_vertically = false end

    local cos_angle = math.cos(angle)
    local sin_angle = math.sin(angle)

    local out = {}
    for i = 1, #vertices, 2 do
        local x, y = vertices[i], vertices[i + 1]

        if flip_horizontally == true then
            x = 2 * flip_origin_x - x
        end
        if flip_vertically == true then
            y = 2 * flip_origin_y - y
        end

        x = x - origin_x
        y = y - origin_y

        local new_x = x * cos_angle - y * sin_angle
        local new_y = x * sin_angle + y * cos_angle

        new_x = new_x + origin_x
        new_y = new_y + origin_y

        table.insert(out, new_x + offset_x)
        table.insert(out, new_y + offset_y)
    end

    return out
end

--- @brief
function ow.Hitbox:instantiate(object)
    local shape = nil

    if object.type == ow.ObjectType.RECTANGLE then
        local x, y = object.top_left_x, object.top_left_y
        local w, h = object.width, object.height

        shape = {
            type = ow.PhysicsShapeType.POLYGON,
            vertices = _process_polygon({
                x, y,
                x + w, y,
                x + w, y + h,
                x, y + h
            },
                object.rotation,
                object.origin_x,
                object.origin_y,
                object.offset_x,
                object.offset_y,
                object.flip_horizontally,
                object.flip_vertically,
                object.flip_origin_x,
                object.flip_origin_y
            );
        }
    elseif object.type == ow.ObjectType.ELLIPSE then
        local is_circle = math.abs(object.x_radius - object.y_radius) < 1
        if is_circle then
            local vertices = {
                object.center_x,
                object.center_y
            }

            vertices = _process_polygon(
                vertices,
                object.rotation,
                object.origin_x,
                object.origin_y,
                object.offset_x,
                object.offset_y
            )

            if is_sprite then
                vertices = _process_polygon(
                    vertices,
                    rotation_offset,
                    entry.rotation_origin_x,
                    entry.rotation_origin_y,
                    offset_x, offset_y,
                    entry.flip_horizontally,
                    entry.flip_vertically,
                    entry.flip_origin_x,
                    entry.flip_origin_y
                )
            end

            table.insert(shapes, {
                type = ow.PhysicsShapeType.CIRCLE,
                x = vertices[1],
                y = vertices[2],
                radius = math.max(object.x_radius, object.y_radius)
            })
        else
            -- box2d does not support ellipses, so construct one as series of polygons
            local triangles = {}
            local center_x, center_y = object.center_x, object.center_y
            local x_radius, y_radius = object.x_radius, object.y_radius
            local n_outer_vertices = 16

            local angle_step = (2 * math.pi) / n_outer_vertices
            for i = 0, n_outer_vertices - 1 do
                local angle1 = i * angle_step
                local angle2 = (i + 1) * angle_step

                local x1 = center_x + x_radius * math.cos(angle1)
                local y1 = center_y + y_radius * math.sin(angle1)
                local x2 = center_x + x_radius * math.cos(angle2)
                local y2 = center_y + y_radius * math.sin(angle2)

                table.insert(triangles, {
                    x1, y1,
                    x2, y2,
                    center_x, center_y
                })
            end

            for vertices in values(triangles) do
                vertices = _process_polygon(
                    vertices,
                    object.rotation,
                    object.origin_x,
                    object.origin_y,
                    ternary(is_sprite, 0, offset_x),
                    ternary(is_sprite, 0, offset_y)
                )

                if is_sprite then
                    vertices = _process_polygon(
                        vertices,
                        rotation_offset,
                        entry.rotation_origin_x,
                        entry.rotation_origin_y,
                        offset_x, offset_y,
                        entry.flip_horizontally,
                        entry.flip_vertically,
                        entry.flip_origin_x,
                        entry.flip_origin_y
                    )
                end

                table.insert(shapes, {
                    type = ow.PhysicsShapeType.POLYGON,
                    vertices = vertices
                })
            end
        end
    else
        rt.error("In ow.Hitbox: unhandled object type `" .. tostring(object.type) .. "`")
    end
end