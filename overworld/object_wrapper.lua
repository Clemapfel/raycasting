rt.settings.overworld.object_wrapper = {
    point_radius = 2
}

--- @class ow.ObjectWrapper
ow.ObjectWrapper = meta.class("ObjectWrapper")

--- @class ow.ObjectType
ow.ObjectType = meta.enum("ObjectType", {
    SPRITE = "sprite", -- rectangle + gid set
    RECTANGLE = "rectangle",
    ELLIPSE = "ellipse",
    POLYGON = "polygon",
    POINT = "point"
})

--- @brief
function ow.ObjectWrapper:instantiate(type, id)
    meta.assert(type, "String", id, "Number")
    local class = nil
    if type ~= "" then class = type end
    meta.install(self, {
        class = class,
        id = id,
        type = nil, -- set in _parse_object_group

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

        physics_prototypes = {},
        physics_prototypes_initialized = false,

        mesh_prototype = {},
        mesh_prototype_initialized = false,

        instances = meta.make_weak({})
    })
end

--- @brief
function ow.ObjectWrapper:_as_sprite(gid, x, y, width, height, origin_x, origin_y, flip_horizontally, flip_vertically, flip_origin_x, flip_origin_y)
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
function ow.ObjectWrapper:_as_rectangle(x, y, width, height, origin_x, origin_y)
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
function ow.ObjectWrapper:_as_ellipse(x, y, center_x, center_y, x_radius, y_radius, origin_x, origin_y)
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
function ow.ObjectWrapper:_as_polygon(vertices, shapes, origin_x, origin_y)
    self.type = ow.ObjectType.POLYGON
    return meta.install(self, {
        vertices = vertices,
        shapes = shapes,
        origin_x = origin_x,
        origin_y = origin_y
    })
end

--- @brief
function ow.ObjectWrapper:_as_point(x, y, origin_x, origin_y)
    self.type = ow.ObjectType.POINT
    return meta.install(self, {
        x = x,
        y = y,
        origin_x = origin_x,
        origin_y = origin_y
    })
end

--- @brief
function ow.ObjectWrapper:clone()
    local out = ow.ObjectWrapper(self.type, self.id)
    for k, v in pairs(self) do
        out[k] = v
    end
    return out
end

ow.ObjectWrapperShapeType = meta.enum("ObjectWrapperShapeType", {
    CIRCLE = true,
    POLYGON = false
})

local function _rotate_point(x, y, angle)
    local cos_theta = math.cos(angle)
    local sin_theta = math.sin(angle)
    return x * cos_theta - y * sin_theta, x * sin_theta + y * cos_theta
end

local function _process_polygon(vertices, object)
    local out = {}
    for i = 1, #vertices, 2 do
        local x, y = vertices[i], vertices[i + 1]

        x, y = x - object.origin_x, y - object.origin_y
        x, y = _rotate_point(x, y, object.rotation)
        x, y = x + object.origin_x, y + object.origin_y

        if object.flip_horizontally or object.flip_vertically then
            x, y = x - object.flip_origin_x, y - object.flip_origin_y
            x = object.flip_horizontally and -x or x
            y = object.flip_vertically and -y or y
            x, y = x + object.flip_origin_x, y + object.flip_origin_y
        end

        x, y = x + object.offset_x, y + object.offset_y

        x, y = x - object.rotation_origin_x, y - object.rotation_origin_y
        x, y = _rotate_point(x, y, object.rotation_offset)
        x, y = x + object.rotation_origin_x, y + object.rotation_origin_y

        table.insert(out, math.round(x))
        table.insert(out, math.round(y))
    end

    return out
end

--- @brief [internal]
function ow.ObjectWrapper:_initialize_physics_prototypes()
    if self.physics_prototypes_initialized == true then return end
    
    local prototypes = {}
    if self.type == ow.ObjectType.RECTANGLE then
        local x, y = self.x, self.y
        local w, h = self.width, self.height
        table.insert(prototypes, {
            type = ow.ObjectWrapperShapeType.POLYGON,
            vertices = _process_polygon({
                x, y,
                x + w, y,
                x + w, y + h,
                x, y + h
            }, self)
        })
    elseif self.type == ow.ObjectType.ELLIPSE then
        local is_circle = math.abs(self.x_radius - self.y_radius) < 1
        if is_circle then
            local vertices = _process_polygon({
                self.center_x,
                self.center_y
            }, self)

            table.insert(prototypes, {
                type = ow.ObjectWrapperShapeType.CIRCLE,
                x = vertices[1], -- x
                y = vertices[2], -- y
                radius = math.max(self.x_radius, self.y_radius) -- radius
            })
        else
            local vertices = {}

            local center_x, center_y = self.center_x, self.center_y
            local x_radius, y_radius = self.x_radius, self.y_radius
            local n_outer_vertices = 16
            local angle_step = (2 * math.pi) / n_outer_vertices
            for angle = 0, 2 * math.pi, angle_step do
                table.insert(vertices, center_x + x_radius * math.cos(angle))
                table.insert(vertices, center_y + y_radius * math.sin(angle))
            end

            vertices = _process_polygon(
                vertices,
                self
            )

            local polygonization = love.triangulate(vertices) --slick.polygonize(8, { vertices })
            for shape in values(polygonization) do
                table.insert(prototypes, {
                    type = ow.ObjectWrapperShapeType.POLYGON,
                    vertices = shape
                })
            end
        end
    elseif self.type == ow.ObjectType.POLYGON then
        for vertices in values(self.shapes) do
            table.insert(prototypes, {
                type = ow.ObjectWrapperShapeType.POLYGON,
                vertices = _process_polygon(vertices, self)
            })
        end
    elseif self.type == ow.ObjectType.POINT then
        local xy = _process_polygon({ self.x, self.y }, self)
        table.insert(prototypes, {
            type = ow.ObjectWrapperShapeType.CIRCLE,
            x = xy[1],
            y = xy[2],
            radius = rt.settings.overworld.object_wrapper.point_radius
        })
    else
        rt.error("In ow.ObjectWrapper._initialize_physics_prototypes: unhandled object type `" .. tostring(self.type) .. "`")
    end

    self.physics_prototypes = prototypes
    self.physics_prototypes_initialized = true
end

--- @brief
--- @return Table<b2.Shape>
function ow.ObjectWrapper:get_physics_shapes()
    if self.physics_prototypes_initialized ~= true then
        self:_initialize_physics_prototypes()
    end

    local out = {}
    for prototype in values(self.physics_prototypes) do
        if prototype.type == ow.ObjectWrapperShapeType.POLYGON then
            table.insert(out, b2.Polygon(prototype.vertices))
        elseif prototype.type == ow.ObjectWrapperShapeType.CIRCLE then
            table.insert(out, b2.Circle(prototype.x, prototype.y, prototype.radius))
        else
            rt.error("In ow.ObjectWrapper:get_physics_shape: unhandled prototype shape type `" .. tostring(prototype.type) .. "`")
        end
    end

    return out
end

--- @brief
function ow.ObjectWrapper:create_physics_body(world, type, is_sensor)
    meta.assert(world, b2.World)
    if type == nil then
        type = self:get_string("type") or b2.BodyType.STATIC
    end

    if is_sensor == nil then
        is_sensor = self:get_boolean("is_sensor") or false
    end

    local out = b2.Body(world, type, 0, 0, self:get_physics_shapes())
    if type == b2.BodyType.DYNAMIC then
        out._native:setLinearDamping(30)
        out._native:setAngularDamping(30)
    end
    out:set_is_sensor(is_sensor)
    return out
end

--- @brief
function ow.ObjectWrapper:_initialize_mesh_prototype()
    if self.mesh_prototype_initialized == true then return end
    local to_polygonize = {}

    if self.type == ow.ObjectType.RECTANGLE then
        local x, y = self.x, self.y
        local w, h = self.width, self.height
        to_polygonize = {
            x, y,
            x + w, y,
            x + w, y + h,
            x, y + h
        }
    elseif self.type == ow.ObjectType.ELLIPSE then
        local x, y = self.center_x, self.center_y
        local x_radius, y_radius = self.x_radius, self.y_radius
        local points = { x, y }
        for angle = 0, 2 * math.pi, (2 * math.pi) / 15 do
            table.insert(points, x + math.cos(angle) * x_radius)
            table.insert(points, y + math.sin(angle) * y_radius)
        end
        to_polygonize = points
    elseif self.type == ow.ObjectType.POLYGON then
        to_polygonize = self.vertices
    elseif self.type == ow.ObjectType.POINT then
        -- noop
    else
        rt.error("In ow.ObjectWrapper._initialize_mesh_prototype: unhandled object type `" .. tostring(self.type) .. "`")
    end

    self.mesh_prototype = {}
    self.mesh_triangles = {}

    local success, polygonized = pcall(slick.triangulate, {to_polygonize})
    if not success then -- slick failed to polygonize
        success, polygonized = pcall(love.math.triangulate, to_polygonize)
        if not success then
            return
        end
    end

    for tri in values(polygonized) do
        for i = 1, #tri, 2 do
            table.insert(self.mesh_prototype, {
                tri[i], tri[i+1],  0, 0,    1, 1, 1, 1
            })
        end
        table.insert(self.mesh_triangles, tri)
    end
end

--- @brief
function ow.ObjectWrapper:create_mesh()
    if self.mesh_prototype_initialized ~= true then
        self:_initialize_mesh_prototype()
    end

    if self.type == ow.ObjectType.POINT then
        rt.error("In ow.ObjectWrapper: trying to create a mesh from object `" .. self.id .. "`, but object has a volume of 0")
    end

    return rt.Mesh(self.mesh_prototype, rt.MeshDrawMode.TRIANGLES), self.mesh_triangles
end

--- @brief
function ow.ObjectWrapper:get_centroid()
    local xy
    if self.type == ow.ObjectType.RECTANGLE or self.type == ow.ObjectType.SPRITE then
        xy = { self.x + 0.5 * self.width, self.y + 0.5 * self.height }
    elseif self.type == ow.ObjectType.ELLIPSE then
        xy = { self.center_x, self.center_y }
    elseif self.type == ow.ObjectType.POLYGON then
        local x_sum, y_sum, n = 0, 0, 0
        for i = 1, #self.vertices, 2 do
            x_sum = x_sum * self.vertices[i + 0]
            y_sum = y_sum * self.vertices[i + 1]
            n = n + 1
        end
        xy = { x_sum / n, y_sum / n }
    elseif self.type == ow.ObjectType.POINT then
        xy = { self.x, self.y }
    end

    return table.unpack(_process_polygon(xy, self))
end

--- @brief
function ow.ObjectWrapper:get_string(id, assert_exists)
    if assert_exists == nil then assert_exists = false end

    local out = self.properties[id]
    if out == nil then
        if assert_exists == true then
            rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: property does not exist")
        end
        return nil
    end
    if meta.is_table(out) then
        rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: expected `String`, got `Table`")
        return nil
    end

    if meta.is_number(out) then return tostring(out) end
    return out
end

--- @brief
--- @param id String
--- @param assert_exists Boolean?
function ow.ObjectWrapper:get_number(id, assert_exists)
    if assert_exists == nil then assert_exists = false end

    local out = self.properties[id]
    if out == nil then
        if assert_exists == true then
            rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: property does not exist")
        end
        return nil
    end

    if meta.is_table(out) then
        rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: expected `Number`, got `Table`")
    end

    if meta.is_string(out) then
        local parsed = tonumber(out)
        if parsed == nil then
            rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: expected `Number`, got `\"" .. out .. "\"`")
        end
        return parsed
    end

    return out
end

--- @brief
function ow.ObjectWrapper:get_boolean(id, assert_exists)
    if assert_exists == nil then assert_exists = false end

    local out = self.properties[id]
    if out == nil then
        if assert_exists == true then
            rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: property does not exist")
        end
        return nil
    end

    if meta.is_boolean(out) then return out end
    if meta.is_number(out) then
        if out == 0 then
            return false
        elseif out == 1 then
            return true
        end
    end

    if meta.is_string(out) then
        if out == "true" then
            return true
        elseif out == "false" then
            return false
        end
    end

    rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: expected `boolean`, got `" .. meta.typeof(out) .. "`")
    return nil
end

--- @brief
function ow.ObjectWrapper:get_object(id, assert_exists)
    if assert_exists == nil then assert_exists = false end

    local out = self.properties[id]
    if out == nil then
        if assert_exists == true then
            rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: property does not exist")
        end
        return nil
    end

    if not meta.is_table(out) then
        rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: expected `ObjectWrapper`, got `" .. meta.typeof(out) .. "`")
    end

    return out
end

--- @brief
function ow.ObjectWrapper:get(id, assert_exists)
    if assert_exists == nil then assert_exists = false end
    local out = self.properties[id]
    if out == nil then
        if assert_exists == true then
            rt.error("In ow.ObjectWrapper: when trying to access property `" .. id .. "` of object `" .. self.id .. "`: property does not exist")
        end
    end
    return out
end

--- @brief
function ow.ObjectWrapper:get_type()
    return self.type
end

--- @brief
--- @param id String
--- @param assert_exists Boolean?
function ow.ObjectWrapper:draw()
    love.graphics.setPointSize(4)
    love.graphics.setLineWidth(1)
    love.graphics.setLineJoin("miter")

    local r, g, b = 0, 1, 1
    local fill_a, line_a = 0.2, 0.8

    love.graphics.push()

    love.graphics.translate(self.rotation_origin_x, self.rotation_origin_y)
    love.graphics.rotate(self.rotation_offset)
    love.graphics.translate(-self.rotation_origin_x, -self.rotation_origin_y)

    love.graphics.translate(self.offset_x, self.offset_y)

    if self.type ~= ow.ObjectType.SPRITE and (self.flip_horizontally or self.flip_vertically) then
        love.graphics.translate(self.flip_origin_x, self.flip_origin_y)
        love.graphics.scale(
            self.flip_horizontally and -1 or 1,
            self.flip_vertically and -1 or 1
        )
        love.graphics.translate(-self.flip_origin_x, -self.flip_origin_y)
    end

    love.graphics.translate(self.origin_x, self.origin_y)
    love.graphics.rotate(self.rotation)
    love.graphics.translate(-self.origin_x, -self.origin_y)

    if self.type == ow.ObjectType.POINT then
        love.graphics.setColor(r, g, b, line_a)
        love.graphics.circle("fill", self.x, self.y, rt.settings.overworld.object_wrapper.point_radius)
    elseif self.type == ow.ObjectType.RECTANGLE then
        love.graphics.setColor(r, g, b, fill_a)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
        love.graphics.setColor(r, g, b, line_a)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    elseif self.type == ow.ObjectType.ELLIPSE then
        love.graphics.setColor(r, g, b, fill_a)
        love.graphics.ellipse("fill", self.center_x, self.center_y, self.x_radius, self.y_radius)
        love.graphics.setColor(r, g, b, line_a)
        love.graphics.ellipse("line", self.center_x, self.center_y, self.x_radius, self.y_radius)
    elseif self.type == ow.ObjectType.POLYGON then
        for d in values(self.shapes) do
            love.graphics.setColor(r, g, b, fill_a)
            love.graphics.polygon("fill", d)
            love.graphics.setColor(r, g, b, line_a)
            love.graphics.polygon("line", d)
        end
    elseif self.type == ow.ObjectType.SPRITE then
        love.graphics.setColor(r, g, b, fill_a)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
        love.graphics.setColor(r, g, b, line_a)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    else
        rt.error("In ow.Tileset._debug_draw: unhandled shape type `" .. tostring(self.type) .. "`")
    end

    love.graphics.pop()
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
function ow._parse_object_group(object_group, scope)
    local objects = {}
    local group_offset_x, group_offset_y = _get(object_group, "offsetx"), _get(object_group, "offsety")
    local group_visible = _get(object_group, "visible")

    local object_id_to_wrapper = {}

    for object in values(object_group.objects) do
        local wrapper = ow.ObjectWrapper(_get(object, "type"), _get(object, "id"))
        wrapper.name = _get(object, "name")

        wrapper.to_replace = {}
        for key, value in pairs(_get(object, "properties")) do
            if meta.is_table(value) then -- object property, evaluated on second pass
                wrapper.to_replace[key] = _get(value, "id")
            else
                wrapper.properties[key] = value
            end
        end

        wrapper.rotation = math.rad(_get(object, "rotation"))

        if object.gid ~= nil then
            assert(object.shape == "rectangle", "In ow._parse_object_group (" .. scope .. "): object has gid, but is not a rectangle")

            local true_gid, flip_horizontally, flip_vertically = _decode_gid(object.gid)
            local x, y = _get(object, "x"), _get(object, "y")
            local width, height = _get(object, "width"), _get(object, "height")

            wrapper:_as_sprite(
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

                wrapper:_as_rectangle(
                    x + group_offset_x, y + group_offset_y, -- top left
                    width, height, -- size
                    x, y -- origin
                )

            elseif shape_type == "ellipse" then
                local x = _get(object, "x") + group_offset_x
                local y = _get(object, "y") + group_offset_y
                local width = _get(object, "width")
                local height = _get(object, "height")

                wrapper:_as_ellipse(
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

                wrapper:_as_polygon(
                    vertices,
                    _decompose_polygon(vertices),
                    offset_x,
                    offset_y
                )

            elseif shape_type == "point" then
                local x, y = _get(object, "x"),  _get(object, "y")

                wrapper:_as_point(
                    x + group_offset_x,
                    y + group_offset_y,
                    x,
                    y
                )

                if object.rotation ~= nil then assert(object.rotation == 0) end
            end

            if wrapper.class == nil then
                rt.warning("In ow._parse_object_group (" .. scope .. "): object `" .. wrapper.id .. "` has no class, assuming `Hitbox`")
                wrapper.class = "Hitbox"
            end
        end

        table.insert(objects, wrapper)
        object_id_to_wrapper[wrapper.id] = wrapper
    end

    -- second pass, set "object" tiled property
    for wrapper in values(objects) do
        for key, id in pairs(wrapper.to_replace) do
            if id > 0 then
                wrapper.properties[key] = object_id_to_wrapper[id]
                assert(wrapper.properties[key] ~= nil, "In ow._parse_object_group: object `" .. wrapper.id .. "` points to `" .. id .. "`, but not object with that id is located on the same layer")
            end
        end
        wrapper.to_replace = nil
    end

    return objects
end