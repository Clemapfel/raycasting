require "overworld.stage_config"
require "overworld.object_wrapper"
require "overworld.hitbox"
require "overworld.sprite"

require "physics.physics"

rt.settings.overworld.stage = {
    physics_world_buffer_length = 100
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

   -- self._physics_stage_body = b2.Body(self._physics_world, b2.BodyType.STATIC, 0, 0)


    local buffer = rt.settings.overworld.stage.physics_world_buffer_length
    local w, h = self._config:get_size()
    self._physics_world = b2.World(w + 2 * buffer, h + 2 * buffer, {
        quadTreeX = -buffer,
        quadTreeY = -buffer
    })

    self._physics_stage_shapes = {}
    self._physics_stage_bodies = {}
    for hitbox in values(self._hitboxes) do
        for shape in values(hitbox:as_physics_shapes(self._physics_stage_body)) do
            --dbg(shape)
            table.insert(self._physics_stage_shapes, b2.Body(
                self._physics_world,
                b2.BodyType.STATIC,
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
end

--- @brief
function ow.Stage:draw()
    for f in values(self._to_draw) do
        --f()
    end

    self._physics_world:draw()
end