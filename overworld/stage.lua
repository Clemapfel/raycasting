require "overworld.stage_config"
require "overworld.object_wrapper"
require "overworld.player"

require "physics.physics"

-- include all overworld classes
for file in values(love.filesystem.getDirectoryItems("overworld/objects")) do
    require("overworld.objects." .. string.match(file, "^(.-)%.lua$"))
end

rt.settings.overworld.stage = {
    physics_world_buffer_length = 0,
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
    self._sprites = {}  -- Table<ow.Sprite>
    self._objects = {}  -- Table<any>

    self._player_spawn_x, self._player_spawn_y = nil, nil

    local buffer = rt.settings.overworld.stage.physics_world_buffer_length
    local w, h = self._config:get_size()
    self._world = b2.World(w + 2 * buffer, h + 2 * buffer)

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
                if wrapper.class == nil then
                    rt.warning("In ow.Stage.instantiate: object `" .. wrapper.id .. "` of stage `" .. self._config:get_id() .. "` has no class, assuming `Hitbox`")
                    wrapper.class = hitbox_class_name
                end

                local object
                if wrapper.class == player_spawn_class_name then
                    assert(wrapper.type == ow.ObjectType.POINT, "In ow.Stage: object of class `" .. player_spawn_class_name .. "` is not a point")
                    assert(self._player_spawn_x == nil and self._player_spawn_y == nil, "In ow.Stage: more than one object of type `" .. player_spawn_class_name .. "`")
                    self._player_spawn_x, self._player_spawn_y = wrapper.x, wrapper.y
                elseif wrapper.class == nil then

                else
                    local Type = ow[wrapper.class]
                    if Type == nil then
                        rt.error("In ow.Stage: unhandled object class `" .. tostring(wrapper.class) .. "`")
                    end
                    object = Type(wrapper, self._world)
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
    
    self._bounds = rt.AABB(0, 0, w, h)
end

--- @brief
function ow.Stage:draw()
    love.graphics.rectangle("line", self._bounds.x, self._bounds.y, self._bounds.width, self._bounds.height)
    love.graphics.circle("fill", 0, 0, 10)
    for f in values(self._to_draw) do
        f()
    end

    self._world:draw()
end

--- @brief
function ow.Stage:update(delta)
    self._world:update(delta)
end

--- @brief
function ow.Stage:get_physics_world()
    return self._world
end

--- @brief
function ow.Stage:get_player_spawn()
    return self._player_spawn_x, self._player_spawn_y
end

--- @brief
function ow.Stage:get_size()
    local buffer = rt.settings.overworld.stage.physics_world_buffer_length
    local w, h = self._config:get_size()
    return w + 2 * buffer, h * 2 + buffer
end