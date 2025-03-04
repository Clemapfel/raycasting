require "common.render_texture"
require "common.drawable"
require "overworld.object_wrapper"

rt.settings.overworld.tileset = {
    config_path = "assets/tilesets",
    is_solid_property_name = "is_solid"
}

--- @class ow.Tileset
ow.Tileset = meta.class("Tileset", rt.Drawable)

--- @brief
function ow.Tileset:instantiate(tileset_name)
    self._id = tileset_name

    local config_path_prefix = rt.settings.overworld.tileset.config_path .. "/"
    local path = config_path_prefix .. self._id .. ".lua"

    local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, path)
    if not load_success then
        rt.error("In ow.Tileset: error when parsing tileset at `" .. path .. "`: " .. chunk_or_error)
        return
    end

    if love_error ~= nil then
        rt.error("In ow.Tileset: error when loading tileset at `" .. path .. "`: " .. love_error)
        return
    end

    local chunk_success, config_or_error = pcall(chunk_or_error)
    if not chunk_success then
        rt.error("In ow.Tileset: error when running tileset at `" .. path .. "`: " .. config_or_error)
        return
    end

    local config = config_or_error

    local _get = function(t, name)
        local out = t[name]
        if out == nil then
            rt.error("In ow.Tileset: trying to access property `" .. name .. "` of tileset at `" .. path .. "`, but it does not exist")
        end
        return out
    end

    if table.sizeof(_get(config, "properties")) > 0 then
        rt.error("In ow.Tileset: unhandled global tileset property")
    end

    -- import tiles

    local tiles_sorted = {}
    local widths = {}

    self._n_tiles = _get(config, "tilecount")
    self._tile_ids = {} -- list of valid tile ids
    self._tiles = {}

    local is_solid_property_name = rt.settings.overworld.tileset_config.is_solid_property_name
    local total_area = 0
    for tile in values(_get(config, "tiles")) do
        local id = _get(tile, "id")
        table.insert(self._tile_ids, id)

        local tile_path = config_path_prefix .. _get(tile, "image")
        local to_push = {
            id = id,
            path = tile_path,
            width = _get(tile, "width"),
            height = _get(tile, "height"),

            texture = love.graphics.newImage(tile_path),
            texture_x = 0,
            texture_y = 0,
            texture_width = 0,
            texture_height = 0,

            objects = {},
            properties = {}
        }
        self._tiles[to_push.id] = to_push

        table.insert(tiles_sorted, to_push.id)
        table.insert(widths, to_push.width)

        if tile.properties ~= nil then
            for key, value in pairs(_get(tile, "properties")) do
                to_push.properties[key] = value
            end
        end

        total_area = total_area + to_push.width * to_push.height

        if tile.objectGroup ~= nil then
            to_push.objects = ow._parse_object_group(_get(tile, "objectGroup"))

            -- remove trivial hitboxes and replace with is_solid property
            local to_remove = {}
            for object_i, object in ipairs(to_push.objects) do
                if object.type == ow.ObjectType.RECTANGLE
                    and object.width * object.height >= to_push.width * to_push.height - 1
                    and object.properties[is_solid_property_name] == nil
                then
                    to_push.properties[is_solid_property_name] = true
                    table.insert(to_remove, object_i)
                end
            end

            table.sort(to_remove, function(a, b) return a > b end)
            for i in values(to_remove) do
                table.remove(to_push.objects, i)
            end
        end
    end

    -- construct texture atlas

    table.sort(tiles_sorted, function(a, b)
        return self._tiles[b].height < self._tiles[b].height
    end)

    table.sort(tiles_sorted, function(a, b)
        return self._tiles[a].width < self._tiles[b].width
    end)

    table.sort(widths, function(a, b)
        return a > b
    end)

    local atlas_width = widths[1]
    if self._n_tiles > 1 then
        atlas_width = atlas_width + widths[2]
    end
    atlas_width = math.max(atlas_width, math.ceil(math.sqrt(total_area)))

    local atlas_height = 0
    do
        local current_x, current_y = 0, 0
        local row_width = 0
        local shelf_height = 0

        for id in values(tiles_sorted) do
            local tile = self._tiles[id]
            if current_x + tile.width > atlas_width then
                current_y = current_y + shelf_height
                atlas_height = atlas_height + shelf_height
                current_x = 0
                shelf_height = 0
                row_width = 0
            end

            tile.texture_x = current_x
            tile.texture_y = current_y
            tile.texture_width = tile.width
            tile.texture_height = tile.height

            current_x = current_x + tile.width
            row_width = row_width + tile.width
            shelf_height = math.max(shelf_height, tile.height)
        end

        atlas_height = atlas_height + shelf_height
    end

    self._texture_atlas = rt.RenderTexture(atlas_width, atlas_height, 0)

    local space_usage = total_area / (atlas_width * atlas_height)
    if space_usage < 0.7 then
        rt.warning("In ow.Tileset: texture atlas of tileset `" .. self._id .. "` only uses `" .. math.floor(space_usage * 1000) / 1000 * 100 .. "%` of allocated space")
    end

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setCanvas(self._texture_atlas._native)
    love.graphics.setColor(1, 1, 1, 1)
    for tile in values(self._tiles) do
        love.graphics.draw(tile.texture, tile.texture_x, tile.texture_y)

        -- compute float texture coordinates
        tile.texture:release()
        tile.texture = nil
        tile.texture_x = tile.texture_x / atlas_width
        tile.texture_y = tile.texture_y / atlas_height
        tile.texture_width = tile.texture_width / atlas_width
        tile.texture_height = tile.texture_height / atlas_height
    end
    love.graphics.setCanvas(nil)
end

--- @brief
function ow.Tileset:get_ids()
    return { table.unpack(self._tile_ids) }
end

--- @brief
function ow.Tileset:get_tile_property(id, property_name)
    local tile = self._tiles[id]
    if tile == nil then
        rt.error("In ow.Tileset.get_tile_property: no tiled with id `" .. id .. "` in tileset `" .. self._name .. "`")
        return nil
    end

    return tile.properties[property_name]
end

--- @brief
function ow.Tileset:get_tile_texture_bounds(id)
    local tile = self._tiles[id]
    if tile == nil then
        rt.error("In ow.Tileset.get_tile_texture_bounds: no tiled with id `" .. id .. "` in tileset `" .. self._name .. "`")
        return nil
    end

    return tile.texture_x, tile.texture_y, tile.texture_width, tile.texture_height
end

--- @brief
function ow.Tileset:get_tile_size(id)
    local tile = self._tiles[id]
    if tile == nil then
        rt.error("In ow.Tileset.get_tile_size: no tiled with id `" .. id .. "` in tileset `" .. self._name .. "`")
        return nil
    end

    return tile.width, tile.height
end

--- @brief
function ow.Tileset:get_tile_objects(id)
    local tile = self._tiles[id]
    if tile == nil then
        rt.error("In ow.Tileset.get_tile_objects: no tiled with id `" .. id .. "` in tileset `" .. self._name .. "`")
        return nil
    end

    local out = {}
    for object in values(tile.objects) do
        table.insert(out, object:clone())
    end
    return out
end

--- @brief
function ow.Tileset:get_texture()
    return self._texture_atlas
end

--- @brief
function ow.Tileset:draw(x, y)
    if x == nil then x = 0 end
    if y == nil then y = 0 end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._texture_atlas._native, x, y)
    local atlas_w, atlas_h = self._texture_atlas._native:getDimensions()

    love.graphics.setColor(1, 0, 1, 1)
    love.graphics.rectangle("line", x, y, atlas_w, atlas_h)

    love.graphics.setPointSize(4)
    love.graphics.setLineWidth(1)
    love.graphics.setLineJoin("miter")

    for tile in values(self._tiles) do
        local tx, ty, tw, th = tile.texture_x * atlas_w, tile.texture_y * atlas_h, tile.texture_width * atlas_w, tile.texture_height * atlas_h
        love.graphics.setColor(1, 0, 1, 1)
        love.graphics.rectangle("line", tx, ty, tw, th)

        love.graphics.push()
        love.graphics.translate(tx, ty)
        for object in values(tile.objects) do
            ow._draw_object(object)
        end
        love.graphics.pop()
    end
end
