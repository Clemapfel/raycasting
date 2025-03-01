rt.settings.overworld.stage_config = {
    config_path = "assets/stages"
}

--- @class ow.LayerType
ow.LayerType = meta.enum("LayerType", {
    TILES = "tilelayer",
    OBJECTS = "objectlayer",
    IMAGE = "imagelayer"
})

ow.ObjectType = meta.new_enum("ObjectType", {
    SPRITE = "sprite", -- rectangle + gid set
    RECTANGLE = "rectangle",
    ELLIPSE = "ellipse",
    POLYGON = "polygon",
    POINT = "point"
})

--- @class ow.StageConfig
ow.StageConfig = meta.class("StageConfig")

function _load_config(path, error_name)
    local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, path)
    if not load_success then
        rt.error("In ow.StageConfig: error when parsing stage at `" .. path .. "`: " .. chunk_or_error)
        return
    end

    if love_error ~= nil then
        rt.error("In ow.StageConfig: error when loading stage at `" .. path .. "`: " .. love_error)
        return
    end

    local chunk_success, config_or_error = pcall(chunk_or_error)
    if not chunk_success then
        rt.error("In ow.StageConfig: error when running stage at `" .. path .. "`: " .. config_or_error)
        return
    end

    return config_or_error
end

local _stage_config_atlas = {}

--- @brief
function ow.StageConfig:instantiate(id)
    self._path = rt.settings.overworld.stage_config.config_path .. "/" .. id .. ".lua"

    local config = _stage_config_atlas[self._path]
    if config == nil then
        config = _load_config(self._path, "ow.StageConfig.instantiate")
        setmetatable(config, {
            __index = function(self, key)
                rt.error("In StageConfig: error when accessing `" .. key .. "` of config at `" .. self._path .. "`: value does not exist")
            end,

            __newindex = function(self, key, _)
                rt.error("In StageConfig: error when modifying `" .. key .. "` of config at `" .. self._path .. "`: config is immutable")
            end
        })

        _stage_config_atlas[self._path] = config
    end

    self._config = config

    -- precompute gid mapping
    self._gid_to_tileset_tile = {}

    for entry in values(self._config.tilesets) do

    end

    self:_init_tilesets()
end

-- tiled uses first 4 bits for flipping (3, 4 for non-square tilings)
local function _decode_gid(gid)
    local true_id = bit.band(gid, 0x0FFFFFFF) -- all but first 4 bit
    local flip_x = 0 ~= bit.band(gid, 0x80000000) -- first bit
    local flip_y = 0 ~= bit.band(gid, 0x40000000) -- second bit
    return true_id, flip_x, flip_y
end

function ow.StageConfig:_parse_object_group(object_group)
    local objects = {} -- ow Objects
    local sprites = {} -- special sprites

    local function _get(x, key)
        local out = x[key]
        if out == nil then
            rt.error("In StageConfig: error when accessing key `" .. key .. "` of object group `" .. object_group.name .. "` of config at `" .. self._path .. "`: value does not exist")
        end
        return out
    end

    local group_offset_x, group_offset_y = _get(object_group, "offsetx"), _get(object_group, "offsety")
    local group_visible = _get(object_group, "visible")

    for object in values(object_group.objects) do
        local wrapper = {
            tiled_id = _get(object, "id"),
            name = _get(object, "name"),
            class = _get(object, "type"),
            type = nil,
            properties = {}
        }

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

            -- TODO: translate gid to local tileset id, get tileset texture

            -- TYPE: sprite
            wrapper.type = ow.ObjectType.SPRITE
            meta.install(wrapper, {
                gid = true_gid,
                top_left_x = x + group_offset_x,
                top_left_y = y - height + group_offset_y, -- tiled uses bottom left
                width = width,
                height = height,
                flip_vertically = flip_vertically,
                flip_horizontally = flip_horizontally,
                origin_x = x, -- bottom left
                origin_y = y,
                flip_origin_x = 0.5 * width,
                flip_origin_y = 0.5 * height
            })
        else
            local shape_type = _get(object, "shape")
            if shape_type == "rectangle" then
                local x, y = _get(object, "x"), _get(object, "y")

                -- TYPE: rectangle
                wrapper.type = ow.ObjectType.RECTANGLE
                meta.install(wrapper, {
                    x = x + group_offset_y, -- top left
                    y = y + group_offset_y,
                    width = _get(object, "width"),
                    height = _get(object, "height"),
                    origin_x = x,
                    origin_y = y
                })

            elseif shape_type == "ellipse" then
                local x = _get(object, "x") + group_offset_x
                local y = _get(object, "y") + group_offset_y
                local width = _get(object, "width")
                local height = _get(object, "height")

                -- TYPE: circle / ellipse
                wrapper.type = ow.ObjectType.ELLIPSE
                meta.install(wrapper, {
                    x = x, -- top left
                    y = y,
                    center_x = x + 0.5 * width,
                    center_y = y + 0.5 * height,
                    x_radius = 0.5 * width,
                    y_radius = 0.5 * height,
                    origin_x = x,
                    origin_y = y
                })

            elseif shape_type == "polygon" then
                local vertices = {}
                local offset_x, offset_y = _get(object, "x"), _get(object, "y")
                for vertex in values(_get(object, "polygon")) do
                    local x, y = _get(vertex, "x"), _get(vertex, "y")
                    table.insert(vertices, x + offset_x + group_offset_x)
                    table.insert(vertices, y + offset_y + group_offset_y)
                end

                -- TYPE: polygon
                wrapper.type = ow.ObjectType.POLYGON
                meta.install(wrapper, {
                    vertices = vertices,
                    shapes = ow.decompose_polygon(vertices),
                    origin_x = offset_x,
                    origin_y = offset_y
                })

            elseif shape_type == "point" then
                local x, y = _get(object, "x"),  _get(object, "y")

                -- TYPE: point
                wrapper.type = ow.ObjectType.POINT
                meta.install(wrapper, {
                    x = x + group_offset_x,
                    y = y + group_offset_y,
                    origin_x = x,
                    origin_y = y
                })

                if object.rotation ~= nil then assert(object.rotation == 0) end
            end
        end

        if wrapper.class == "" or wrapper.class == nil then
            wrapper.class = "DefaultObject"
        end

        local Type = ow[wrapper.class]
        if Type == nil then
            rt.error("In StageConfig: object `" .. wrapper.tiled_id .. "` of of object group `" .. object_group.name .. "` of config at `" .. self._path .. "` has unhandled type `" .. wrapper.class .. "`")
        end

        table.insert(objects, Type(wrapper))
    end
end

local _tileset_config_atlas = {}

--- @brief
function ow.StageConfig:_init_tilesets()
    for object in values(self._config.tilesets) do
        local name = object.name
        local tileset_config = _tileset_config_atlas[name]
        if tileset_config == nil then

        end
    end
end

-- ear clipping triangulation
local function _triangulate(vertices)
    local triangles = {}
    local n = #vertices / 2
    local indices = {}
    for i = 1, n do
        indices[i] = i
    end

    local function get_point(index)
        return vertices[2 * index - 1], vertices[2 * index]
    end

    local function sign(px1, py1, px2, py2, px3, py3)
        return (px1 - px3) * (py2 - py3) - (px2 - px3) * (py1 - py3)
    end

    while #indices > 3 do
        local ear_found = false
        for i = 1, #indices do
            local i1 = indices[i]
            local i2 = indices[(i % #indices) + 1]
            local i3 = indices[(i + 1) % #indices + 1]

            local x1, y1 = get_point(i1)
            local x2, y2 = get_point(i2)
            local x3, y3 = get_point(i3)

            local cross_product = (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1)
            if cross_product < 0 then
                local is_ear = true
                for j = 1, #indices do
                    if j ~= i and j ~= (i % #indices) + 1 and j ~= (i + 1) % #indices + 1 then
                        local px, py = get_point(indices[j])

                        local d1 = sign(px, py, x1, y1, x2, y2)
                        local d2 = sign(px, py, x2, y2, x3, y3)
                        local d3 = sign(px, py, x3, y3, x1, y1)

                        local has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
                        local has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)

                        local is_point_in_triangle = not (has_neg and has_pos)

                        if is_point_in_triangle then
                            is_ear = false
                            break
                        end
                    end
                end

                if is_ear then
                    table.insert(triangles, {x1, y1, x2, y2, x3, y3})
                    table.remove(indices, (i % #indices) + 1)
                    ear_found = true
                    break
                end
            end
        end

        if not ear_found then
            rt.error("In ow.TilesetConfig._decompose_polygon: unable to triangulate polygon")
        end
    end

    local x1, y1 = get_point(indices[1])
    local x2, y2 = get_point(indices[2])
    local x3, y3 = get_point(indices[3])
    table.insert(triangles, {x1, y1, x2, y2, x3, y3})
    return triangles
end

-- merge triangles with shared base
local function _merge_triangles_into_trapezoids(triangles)
    local trapezoids = {}
    local used = {}

    for i = 1, #triangles do
        if not used[i] then
            local merged = false
            for j = i + 1, #triangles do
                if not used[j] then
                    local shared_vertices = 0
                    for m = 1, 6, 2 do
                        for n = 1, 6, 2 do
                            if triangles[i][m] == triangles[j][n] and triangles[i][m + 1] == triangles[j][n + 1] then
                                shared_vertices = shared_vertices + 1
                            end
                        end
                    end

                    if shared_vertices == 2 then
                        local trapezoid = {}
                        for m = 1, 6, 2 do
                            table.insert(trapezoid, triangles[i][m])
                            table.insert(trapezoid, triangles[i][m + 1])
                        end
                        for m = 1, 6, 2 do
                            local is_shared = false
                            for n = 1, #trapezoid, 2 do
                                if triangles[j][m] == trapezoid[n] and triangles[j][m + 1] == trapezoid[n + 1] then
                                    is_shared = true
                                    break
                                end
                            end
                            if not is_shared then
                                table.insert(trapezoid, triangles[j][m])
                                table.insert(trapezoid, triangles[j][m + 1])
                            end
                        end

                        assert(#trapezoid <= 8) -- box2d max vertex count
                        table.insert(trapezoids, trapezoid)
                        used[i] = true
                        used[j] = true
                        merged = true
                        break
                    end
                end
            end
            if not merged then
                table.insert(trapezoids, triangles[i])
            end
        end
    end

    return trapezoids
end

function ow.decompose_polygon(vertices)
    return _merge_triangles_into_trapezoids(_triangulate(vertices))
end
