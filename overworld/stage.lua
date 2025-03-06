require "overworld.stage_config"
require "overworld.object_wrapper"
require "overworld.hitbox"
require "overworld.sprite"
require "overworld.player"

require "physics.physics"

rt.settings.overworld.stage = {
    physics_world_buffer_length = 100,
    hitbox_class_name = "Hitbox",
    sprite_class_name = "Sprite",
    player_spawn_class_name = "PlayerSpawn"
}

--- @class ow.Stage
ow.Stage = meta.class("Stage", rt.Drawable)

local _stage_config_atlas = {}

--- @brief
function ow.Stage:instantiate(id)
    local config = _stage_config_atlas[id]
    if config == nil then
        config = ow.StageConfig(id)
        _stage_config_atlas[id] = config
    end

    self._config = config
    self._to_draw = {}  -- Table<Function>
    self._hitboxes = {} -- Table<ow.Hitbox>
    self._sprites = {}  -- Table<ow.Sprite>
    self._objects = {}  -- Table<any>

    self._player_spawn_x, self._player_spawn_y = nil, nil

    local hitbox_class_name = rt.settings.overworld.stage.hitbox_class_name
    local sprite_class_name = rt.settings.overworld.stage.sprite_class_name
    local player_spawn_class_name = rt.settings.overworld.stage.player_spawn_class_name

    for layer_i = 1, self._config:get_n_layers() do
        local spritebatches = self._config:get_layer_sprite_batches(layer_i)
        if table.sizeof(spritebatches) > 0 then
            table.insert(self._to_draw, function()
                for spritebatch in values(spritebatches) do
                    spritebatch:draw()
                end
            end)
        end

        local object_wrappers = self._config:get_layer_object_wrappers(layer_i)
        local drawables = {}
        if table.sizeof(object_wrappers) > 0 then
            for wrapper in values(object_wrappers) do

                if wrapper.properties["print"] == true then dbg(wrapper) end

                local object
                if wrapper.class == hitbox_class_name then
                    object = ow.Hitbox(wrapper)
                    table.insert(self._hitboxes, object)
                elseif wrapper.class == sprite_class_name then
                    object = ow.Sprite(wrapper)
                    table.insert(self._sprites, object)
                elseif wrapper.class == player_spawn_class_name then
                    assert(wrapper.type == ow.ObjectType.POINT, "In ow.Stage: object of class `" .. player_spawn_class_name .. "` is not a point")
                    assert(self._player_spawn_x == nil and self._player_spawn_y == nil, "In ow.Stage: more than one object of type `" .. player_spawn_class_name .. "`")
                    self._player_spawn_x, self._player_spawn_y = wrapper.x, wrapper.y
                elseif wrapper.class == nil then

                else
                    local Type = ow[wrapper.class]
                    if Type == nil then
                        rt.error("In ow.Stage: unhandled object class `" .. tostring(wrapper.class) .. "`")
                    end
                    object = Type(wrapper)
                    table.insert(self._objects, object)
                end

                if meta.isa(object, rt.Drawable) then
                    table.insert(drawables, object)
                end
            end
        end

        table.insert(self._to_draw, function()
            for drawable in values(drawables) do
                drawable:draw()
            end
        end)
    end

    if self._player_spawn_x == nil or self._player_spawn_y == nil then
        rt.error("In ow.Stage: no player spawn in stage `" .. self._config:get_id() .. "`")
    end

    local buffer = rt.settings.overworld.stage.physics_world_buffer_length
    local w, h = self._config:get_size()
    self._physics_world = b2.World(w + 2 * buffer, h + 2 * buffer)

    self._physics_stage_shapes = {}
    self._physics_stage_bodies = {}
    for hitbox in values(self._hitboxes) do
        for shape in values(hitbox:as_physics_shapes(self._physics_stage_body)) do
            table.insert(self._physics_stage_shapes, shape)
            table.insert(self._physics_stage_bodies, b2.Body(
                self._physics_world, b2.BodyType.STATIC,
                0, 0,
                shape
            ))
        end
    end

    --[[
    self._physics_stage_body = b2.Body(
        self._physics_world,
        b2.BodyType.STATIC,
        0, 0,
        self._physics_stage_shapes
    )
    ]]--

    self._player = ow.Player(self)
end

--- @brief
function ow.Stage:draw()
    for f in values(self._to_draw) do
        f()
    end

    self._player:draw()
    self._physics_world:draw()
end

--- @brief
function ow.Stage:update(delta)
    self._physics_world:update(delta)
end

--- @brief
function ow.Stage:get_physics_world()
    return self._physics_world
end

--- @brief
function ow.Stage:get_player_spawn()
    return self._player_spawn_x, self._player_spawn_y
end