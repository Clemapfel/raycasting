--- @class ow.ObjectType
ow.ObjectType = meta.enum("ObjectType", {
    SPRITE = "sprite", -- rectangle + gid set
    RECTANGLE = "rectangle",
    ELLIPSE = "ellipse",
    POLYGON = "polygon",
    POINT = "point"
})

--- @class ow.ObjectWrapper
ow.ObjectWrapper = meta.class("ObjectWrapper")

--- @brief
function ow.ObjectWrapper:instantiate(type)
    local class = nil
    if type ~= "" then class = type end
    meta.install(self, {
        class = class,
        type = nil,

        origin_x = 0,
        origin_y = 0,
        rotation = 0,

        offset_x = 0, -- transform properties inherited from sprite
        offset_y = 0,

        flip_horizontally = false,
        flip_vertically = false,
        flip_origin_x = 0,
        flip_origin_y = 0,

        rotation_offset = 0,
        rotation_origin_x = 0,
        rotation_origin_y = 0,

        properties = {},
    })
end

--- @brief
function ow.ObjectWrapper:clone()
    local out = ow.ObjectWrapper()
    for k, v in pairs(self) do
        out[k] = v
    end
    return out
end

--- @brief
function ow.ObjectWrapper:as_sprite(gid, x, y, width, height, origin_x, origin_y, flip_horizontally, flip_vertically, flip_origin_x, flip_origin_y)
    self.type = ow.ObjectType.SPRITE
    return meta.install(self, {
        gid = gid,
        x = x,
        y = y,
        width = width,
        height = height,
        origin_x = origin_x,
        origin_y = origin_y,

        flip_horizontally = flip_horizontally,
        flip_vertically = flip_vertically,
        flip_origin_x = flip_origin_x,
        flip_origin_y = flip_origin_y,

        texture_x = 0, -- set in stage_config once tileset is initialized
        texture_y = 0,
        texture_width = 1,
        texutre_height = 1,
        texture = nil
    })
end

--- @brief
function ow.ObjectWrapper:as_rectangle(x, y, width, height, origin_x, origin_y)
    self.type = ow.ObjectType.RECTANGLE
    return meta.install(self, {
        x = x,
        y = y,
        width = width,
        height = height,
        origin_x = origin_x,
        origin_y = origin_y,
    })
end

--- @brief
function ow.ObjectWrapper:as_ellipse(x, y, center_x, center_y, x_radius, y_radius, origin_x, origin_y)
    self.type = ow.ObjectType.ELLIPSE
    return meta.install(self, {
        x = x,
        y = y,
        center_x = center_x,
        center_y = center_y,
        x_radius = x_radius,
        y_radius = y_radius,
        origin_x = origin_x,
        origin_y = origin_y
    })
end

--- @brief
function ow.ObjectWrapper:as_polygon(vertices, shapes, origin_x, origin_y)
    self.type = ow.ObjectType.POLYGON
    return meta.install(self, {
        vertices = vertices,
        shapes = shapes,
        origin_x = origin_x,
        origin_y = origin_y
    })
end

--- @brief
function ow.ObjectWrapper:as_point(x, y, origin_x, origin_y)
    self.type = ow.ObjectType.POINT
    return meta.install(self, {
        x = x,
        y = y,
        origin_x = origin_x,
        origin_y = origin_y
    })
end

-- safe table access
local _get = function(t, name)
    local out = t[name]
    if out == nil then
        rt.error("In ow._parse_object_group: trying to access property `" .. name .. "` but it does not exist")
    end
    return out
end

-- decompose polygon into 8-gons
local function _decompose_polygon(vertices)
    return slick.polygonize(8, { vertices })
end

-- tiled uses first 4 bits for flipping (3, 4 for non-square tilings)
local function _decode_gid(gid)
    local true_id = bit.band(gid, 0x0FFFFFFF) -- all but first 4 bit
    local flip_x = 0 ~= bit.band(gid, 0x80000000) -- first bit
    local flip_y = 0 ~= bit.band(gid, 0x40000000) -- second bit
    return true_id, flip_x, flip_y
end

--- @return Table
function ow._parse_object_group(object_group)
    local objects = {}
    local group_offset_x, group_offset_y = _get(object_group, "offsetx"), _get(object_group, "offsety")
    local group_visible = _get(object_group, "visible")

    for object in values(object_group.objects) do
        local wrapper = ow.ObjectWrapper(_get(object, "type"))
        for key, value in values(_get(object, "properties")) do
            if meta.is_table(value) then -- object property
                rt.error("In ow.StageConfig._parse_object: unhandled object property of object `" .. wrapper.tiled_id .. "`")
            else
                wrapper.properties[key] = value
            end
        end

        wrapper.rotation = math.rad(_get(object, "rotation"))

        if object.gid ~= nil then
            assert(object.shape == "rectangle", "In ow.parse_tiled_object: object has gid, but is not a rectangle")

            local true_gid, flip_horizontally, flip_vertically = _decode_gid(object.gid)
            local x, y = _get(object, "x"), _get(object, "y")
            local width, height = _get(object, "width"), _get(object, "height")

            wrapper:as_sprite(
                true_gid,
                x + group_offset_x,
                y - height + group_offset_y, -- position
                width, height, -- size
                x, y, -- origin
                flip_horizontally, flip_vertically, -- flip
                0.5 * width, 0.5 * height -- flip origin
            )

            if wrapper.class == nil then wrapper.class = "Sprite" end
        else
            local shape_type = _get(object, "shape")
            if shape_type == "rectangle" then
                local x, y = _get(object, "x"), _get(object, "y")
                local width, height = _get(object, "width"), _get(object, "height")

                wrapper:as_rectangle(
                    x + group_offset_x, y + group_offset_y, -- top left
                    width, height, -- size
                    x, y -- origin
                )

            elseif shape_type == "ellipse" then
                local x = _get(object, "x") + group_offset_x
                local y = _get(object, "y") + group_offset_y
                local width = _get(object, "width")
                local height = _get(object, "height")

                wrapper:as_ellipse(
                    x, -- top left
                    y,
                    x + 0.5 * width,    -- center
                    y + 0.5 * height,
                    0.5 * width, -- radii
                    0.5 * height,
                    x, -- origin
                    y
                )

            elseif shape_type == "polygon" then
                local vertices = {}
                local offset_x, offset_y = _get(object, "x"), _get(object, "y")
                for vertex in values(_get(object, "polygon")) do
                    local x, y = _get(vertex, "x"), _get(vertex, "y")
                    table.insert(vertices, x + offset_x + group_offset_x)
                    table.insert(vertices, y + offset_y + group_offset_y)
                end

                wrapper:as_polygon(
                    vertices,
                    _decompose_polygon(vertices),
                    offset_x,
                    offset_y
                )

            elseif shape_type == "point" then
                local x, y = _get(object, "x"),  _get(object, "y")

                wrapper:as_point(
                    x + group_offset_x,
                    y + group_offset_y,
                    x,
                    y
                )

                if object.rotation ~= nil then assert(object.rotation == 0) end
            end

            if wrapper.class == nil then wrapper.class = "Hitbox" end
        end

        table.insert(objects, wrapper)
    end

    return objects
end

--- @brief
function ow._draw_object(object)
    love.graphics.setPointSize(4)
    love.graphics.setLineWidth(1)
    love.graphics.setLineJoin("miter")

    local r, g, b = 0, 1, 1
    local fill_a, line_a = 0.2, 0.8

    love.graphics.push()

    love.graphics.translate(object.rotation_origin_x, object.rotation_origin_y)
    love.graphics.rotate(object.rotation_offset)
    love.graphics.translate(-object.rotation_origin_x, -object.rotation_origin_y)

    love.graphics.translate(object.offset_x, object.offset_y)

    if object.type ~= ow.ObjectType.SPRITE and (object.flip_horizontally or object.flip_vertically) then
        love.graphics.translate(object.flip_origin_x, object.flip_origin_y)
        love.graphics.scale(
            object.flip_horizontally and -1 or 1,
            object.flip_vertically and -1 or 1
        )
        love.graphics.translate(-object.flip_origin_x, -object.flip_origin_y)
    end

    love.graphics.translate(object.origin_x, object.origin_y)
    love.graphics.rotate(object.rotation)
    love.graphics.translate(-object.origin_x, -object.origin_y)

    if object.type == ow.ObjectType.POINT then
        love.graphics.setColor(r, g, b, line_a)
        love.graphics.points(object.x, object.y)
    elseif object.type == ow.ObjectType.RECTANGLE then
        love.graphics.setColor(r, g, b, fill_a)
        love.graphics.rectangle("fill", object.x, object.y, object.width, object.height)
        love.graphics.setColor(r, g, b, line_a)
        love.graphics.rectangle("line", object.x, object.y, object.width, object.height)
    elseif object.type == ow.ObjectType.ELLIPSE then
        love.graphics.setColor(r, g, b, fill_a)
        love.graphics.ellipse("fill", object.center_x, object.center_y, object.x_radius, object.y_radius)
        love.graphics.setColor(r, g, b, line_a)
        love.graphics.ellipse("line", object.center_x, object.center_y, object.x_radius, object.y_radius)
    elseif object.type == ow.ObjectType.POLYGON then
        for d in values(object.shapes) do
            love.graphics.setColor(r, g, b, fill_a)
            love.graphics.polygon("fill", d)
            love.graphics.setColor(r, g, b, line_a)
            love.graphics.polygon("line", d)
        end
    elseif object.type == ow.ObjectType.SPRITE then
        love.graphics.setColor(r, g, b, fill_a)
        love.graphics.rectangle("fill", object.x, object.y, object.width, object.height)
        love.graphics.setColor(r, g, b, line_a)
        love.graphics.rectangle("line", object.x, object.y, object.width, object.height)
    else
        rt.error("In ow.Tileset._debug_draw: unhandled shape type `" .. object.type .. "`")
    end

    love.graphics.pop()
end