require "overworld.stage_config"
require "overworld.object_group"
require "overworld.hitbox"
require "overword.sprite"

--- @class ow.Stage
ow.Stage = meta.class("Stage", rt.Drawable)

local _stage_config_atlas = {}

--- @brief
function ow.Stage:instantiated(id)
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
                local object
                if wrapper.class == "Hitbox" then
                    object = ow.Hitbox(wrapper)
                    table.insert(self._hitboxes, object)
                elseif wrapper.class == "Sprite" then
                    object = ow.Sprite(wrapper)
                    table.insert(self._sprites, object)
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
end

--- @brief
function ow.Stage:draw()
    for f in values(self._to_draw) do
        f()
    end
end