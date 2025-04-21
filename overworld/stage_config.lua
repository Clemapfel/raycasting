require "common.matrix"
require "common.sprite_batch"
require "overworld.object_wrapper"
require "overworld.tileset"

rt.settings.overworld.stage_config = {
    config_path = "assets/stages",
}

--- @class ow.LayerType
ow.LayerType = meta.enum("LayerType", {
    TILES = "tilelayer",
    OBJECTS = "objectlayer",
    IMAGE = "imagelayer"
})

--- @class ow.StageConfig
ow.StageConfig = meta.class("StageConfig")
local _get = function(x, key)
    local out = x[key]
    if out == nil then
        rt.error("In StageConfig: error when accessing key `" .. key .. "` : value does not exist")
    end
    return out
end

ow.StageConfig._tileset_atlas = {}
local _dummy_hitbox_id = -1

--- @brief
function ow.StageConfig:instantiate(stage_id)
    self._path = rt.settings.overworld.stage_config.config_path .. "/" .. stage_id .. ".lua"
    self._id = stage_id

    local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, self._path)
    if not load_success then
        rt.error("In ow.StageConfig: error when parsing file at `" .. self._path .. "`: " .. chunk_or_error)
        return
    end

    if love_error ~= nil then
        rt.error("In ow.StageConfig: error when loading file at `" .. self._path .. "`: " .. love_error)
        return
    end

    local chunk_success, config_or_error = pcall(chunk_or_error)
    if not chunk_success then
        rt.error("In ow.StageConfig: error when running file at `" .. self._path .. "`: " .. config_or_error)
        return
    end

    self._config = config_or_error

    -- init tilesets

    self._tilesets = {}
    self._gid_to_tileset_id = {}

    for entry in values(_get(self._config, "tilesets")) do
        local name = _get(entry, "name")
        local tileset = ow.StageConfig._tileset_atlas[name]
        if tileset == nil then
            tileset = ow.Tileset(name)
            ow.StageConfig._tileset_atlas[name] = tileset
        end

        local id_offset = _get(entry, "firstgid")
        table.insert(self._tilesets, {
            id_offset = id_offset,
            tileset = tileset
        })

        for id in values(tileset:get_ids()) do
            self._gid_to_tileset_id[id + id_offset] = {
                id = id,
                tileset = tileset
            }
        end
    end

    -- parse layers

    local tile_min_x, tile_min_y, tile_max_x, tile_max_y = math.huge, math.huge, -math.huge, -math.huge

    self._n_columns = _get(self._config, "width")
    self._n_rows = _get(self._config, "height")
    self._tile_width = _get(self._config, "tilewidth")
    self._tile_height = _get(self._config, "tileheight")

    local is_solid_property_name = rt.settings.overworld.tileset_config.is_solid_property_name
    self._layer_i_to_layer = {}

    local layer_i = 1
    local n_layers = 0
    for layer_entry in values(_get(self._config, "layers")) do
        local layer_type = _get(layer_entry, "type")
        local layer_class = _get(layer_entry, "class")
        local to_add = {
            type = nil,
            class = layer_class,
            is_visible = _get(layer_entry, "visible"),
            x_offset = _get(layer_entry, "offsetx"),
            y_offset = _get(layer_entry, "offsety"),
            spritebatches = {},
            objects = {}
        }

        self._layer_i_to_layer[layer_i] = to_add

        if layer_entry.properties ~= nil then
            for key, value in pairs(_get(layer_entry, "properties")) do
                to_add.properties[key] = value
            end
        end

        if layer_type == "objectgroup" then
            to_add.type = ow.LayerType.OBJECTS
            for object in values(ow._parse_object_group(layer_entry, stage_id .. " Layer #" .. layer_i)) do
                assert(meta.typeof(object) == "ObjectWrapper")
                table.insert(to_add.objects, object)

                if object.type == ow.ObjectType.SPRITE then
                    local sprite = object

                    -- if sprite, set texture
                    local tile_entry = self._gid_to_tileset_id[sprite.gid]
                    sprite.texture = tile_entry.tileset:get_texture()
                    local tx, ty, tw, th = tile_entry.tileset:get_tile_texture_bounds(tile_entry.id)
                    sprite.texture_x, sprite.texture_y, sprite.texture_width, sprite.texture_height = tx, ty, tw, th

                    -- also collect objects of sprite tile, inherit sprite transform
                    for sprite_object in values(tile_entry.tileset:get_tile_objects(tile_entry.id)) do
                        sprite_object.offset_x = sprite.x
                        sprite_object.offset_y = sprite.y
                        sprite_object.rotation_origin_x = sprite.origin_x
                        sprite_object.rotation_origin_y = sprite.origin_y
                        sprite_object.flip_horizontally = sprite.flip_horizontally
                        sprite_object.flip_vertically = sprite.flip_vertically
                        sprite_object.flip_origin_x = sprite.flip_origin_x
                        sprite_object.flip_origin_y = sprite.flip_origin_y
                        sprite_object.rotation_offset = sprite.rotation

                        table.insert(to_add.objects, sprite_object)
                    end
                end
            end
        elseif layer_type == "imagelayer" then
            -- noop
        elseif layer_type == "tilelayer" then
            to_add.type = ow.LayerType.TILES

            local gid_matrix = rt.Matrix()
            local is_solid_matrix = rt.Matrix()

            local chunks = _get(layer_entry, "chunks")
            for chunk in values(chunks) do
                local x_offset = _get(chunk, "x")
                local y_offset = _get(chunk, "y")
                local width = _get(chunk, "width")
                local height = _get(chunk, "height")
                local data = _get(chunk, "data")

                tile_min_x = math.min(tile_min_x, x_offset)
                tile_min_y = math.min(tile_min_y, y_offset)
                tile_max_x = math.max(tile_max_x, x_offset + width)
                tile_max_y = math.max(tile_max_y, y_offset + height)

                for y = 1, height do
                    for x = 1, width do
                        local gid = data[(y - 1) * width + x]
                        if gid ~= 0 and gid ~= nil then -- empty tile
                            assert(gid_matrix:get(x + x_offset, y + y_offset) == nil)
                            gid_matrix:set(x + x_offset, y + y_offset, gid)

                            local tile_entry = self._gid_to_tileset_id[gid]
                            local is_solid = tile_entry.tileset:get_tile_property(tile_entry.id, is_solid_property_name) == true
                            if is_solid then
                                is_solid_matrix:set(x + x_offset, y + y_offset, true)
                            end

                            -- collect per-tile objects
                            local tile_w, tile_h = tile_entry.tileset:get_tile_size(tile_entry.id)
                            for object in values(tile_entry.tileset:get_tile_objects(tile_entry.id)) do
                                object.offset_x = ((x - 1) + x_offset) * self._tile_width
                                object.offset_y = ((y - 1) + y_offset) * self._tile_height-- tiled uses bottom left origin
                                table.insert(to_add.objects, object)
                            end
                        end
                    end
                end
            end

            -- construct tile spritebatches

            local tileset_to_spritebatch = {}

            for row_i = tile_min_y, tile_max_y do
                for col_i = tile_min_x, tile_max_x do
                    local gid = gid_matrix:get(col_i, row_i)
                    if gid ~= nil then
                        local tile_entry = self._gid_to_tileset_id[gid]
                        assert(tile_entry ~= nil)

                        local tileset = tile_entry.tileset
                        local spritebatch = tileset_to_spritebatch[tileset]
                        if spritebatch == nil then
                            spritebatch = rt.SpriteBatch(tileset:get_texture())
                            table.insert(to_add.spritebatches, spritebatch)
                            tileset_to_spritebatch[tileset] = spritebatch
                        end

                        local local_id = tile_entry.id
                        local texture_x, texture_y, texture_w, texture_h = tileset:get_tile_texture_bounds(local_id)
                        local tile_w, tile_h = tileset:get_tile_size(local_id)
                        spritebatch:add(
                            (col_i - 1) * self._tile_width,
                            (row_i - 1) * self._tile_height, -- tiled uses bottom left
                            tile_w,
                            tile_h,
                            texture_x, texture_y, texture_w, texture_h,
                            false, false, 0
                        )
                    end
                end
            end

            -- construct trivial hitboxes

            do
                local min_x, min_y, max_x, max_y = is_solid_matrix:get_index_range()

                local visited = {}
                local function is_visited(x, y)
                    return visited[y] and visited[y][x]
                end

                local function find_rectangle(x, y)
                    local width, height = 0, 1

                    -- expand right as much as possible
                    while is_solid_matrix:get(x + width, y) do
                        width = width + 1
                    end

                    -- if not possible, try downwards
                    if width == 1 then
                        -- expand down as much as possible
                        while is_solid_matrix:get(x, y + height) do
                            height = height + 1
                        end

                        while true do
                            for col_offset = 0, height do
                                local current_x, current_y = x + width, y + col_offset
                                if is_solid_matrix:get(current_x, current_y) ~= true then
                                    goto done
                                end
                            end
                            width = width + 1
                        end
                        ::done::
                    else
                        while true do
                            for row_offset = 0, width do
                                local current_x, current_y = x + row_offset, y + height
                                if is_solid_matrix:get(current_x, current_y) ~= true then
                                    goto done
                                end
                            end
                            height = height + 1
                        end
                        ::done::
                    end

                    for i = 0, height - 1 do
                        for j = 0, width - 1 do
                            if not visited[y + i] then
                                visited[y + i] = {}
                            end
                            visited[y + i][x + j] = true
                        end
                    end

                    return x, y, width, height
                end

                for y = min_y, max_y do
                    for x = min_x, max_x do
                        if is_solid_matrix:get(x, y) and not is_visited(x, y) then
                            local x, y, w, h = find_rectangle(x, y)
                            x = (x - 1) * self._tile_width
                            y = (y - 1) * self._tile_height
                            w = w * self._tile_width
                            h = h * self._tile_height

                            local wrapper = ow.ObjectWrapper("Hitbox", _dummy_hitbox_id):_as_rectangle(x, y, w, h)
                            _dummy_hitbox_id = _dummy_hitbox_id - 1
                            table.insert(to_add.objects, wrapper)
                        end
                    end
                end
            end
        end

        layer_i = layer_i + 1
        n_layers = n_layers + 1
    end

    self._width = (tile_max_x - tile_min_x) * self._tile_width
    self._height = (tile_max_y - tile_min_y) * self._tile_height
    self._n_layers = n_layers
end

--- @brief
function ow.StageConfig:draw()
    for i = 1, self._n_layers do
        for batch in values(self:get_layer_sprite_batches(i)) do
            batch:draw()
        end

        for object in values(self:get_layer_object_wrappers(i)) do
            ow._draw_object(object)
        end
    end
end

--- @brief
function ow.StageConfig:get_n_layers()
    return self._n_layers
end

--- @brief
function ow.StageConfig:get_layer_sprite_batches(layer_i)
    local layer = self._layer_i_to_layer[layer_i]
    if layer == nil then
        rt.error("In ow.StageConfig.get_layer_sprite_batches: no layer with id `" .. tostring(layer_i) .. "`")
    end

    return { table.unpack(layer.spritebatches) }
end

--- @brief
function ow.StageConfig:get_layer_object_wrappers(layer_i)
    local layer = self._layer_i_to_layer[layer_i]
    if layer == nil then
        rt.error("In ow.StageConfig.get_layeget_layer_object_wrappersr_sprite_batches: no layer with id `" .. tostring(layer_i) .. "`")
    end

    local out = {}
    for object in values(layer.objects) do
        table.insert(out, object:clone())
    end
    return out
end

--- @brief
function ow.StageConfig:get_layer_class(layer_i)
    local layer = self._layer_i_to_layer[layer_i]
    if layer == nil then
        rt.error("In ow.StageConfig.get_layeget_layer_object_wrappersr_sprite_batches: no layer with id `" .. tostring(layer_i) .. "`")
    end

    return layer.class
end

--- @brief
function ow.StageConfig:get_size()
    return self._width, self._height
end

--- @brief
function ow.StageConfig:get_id()
    return self._id
end