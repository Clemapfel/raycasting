require "overworld.stage_config"
require "overworld.object_wrapper"
require "overworld.player"
require "overworld.pathfinding_graph"
require "overworld.blood_splatter"

require "physics.physics"

-- include all overworld classes
for file in values(love.filesystem.getDirectoryItems("overworld/objects")) do
    if love.filesystem.getInfo("overworld/objects/" .. file).type == "file" then
        require("overworld.objects." .. string.match(file, "^(.-)%.lua$"))
    end
end

rt.settings.overworld.stage = {
    physics_world_buffer_length = 0,
    player_spawn_class_name = "PlayerSpawn",
    camera_bounds_class_name = "CameraBounds",
    wall_class_name = "Wall",
    floor_class_name = "Floor",
}

--- @class ow.Stage
--- @signal initialized (self) -> nil
ow.Stage = meta.class("Stage", rt.Drawable)
meta.add_signals(ow.Stage, "initialized")

ow.Stage._config_atlas = {}

--- @brief
function ow.Stage:instantiate(scene, id)
    meta.assert(scene, "OverworldScene", id, "String")
    self._scene = scene
    self._is_initialized = false

    local config = ow.Stage._config_atlas[id]
    if config == nil then
        config = ow.StageConfig(id)
        ow.Stage._config_atlas[id] = config
    end

    self._config = config
    self._to_update = {} -- Table<Any>
    self._objects = {}  -- Table<any>
    self._pathfinding_graph = ow.PathfindingGraph()
    self._blood_splatter = ow.BloodSplatter(self)

    self._player_spawn_x, self._player_spawn_y = nil, nil
    self._camera_bounds = rt.AABB(-math.huge, -math.huge, math.huge, math.huge)
    local camera_bounds_seen = false

    local buffer = rt.settings.overworld.stage.physics_world_buffer_length
    local w, h = self._config:get_size()
    self._world = b2.World(w + 2 * buffer, h + 2 * buffer)

    local player_spawn_class_name = rt.settings.overworld.stage.player_spawn_class_name
    local camera_bounds_class_name = rt.settings.overworld.stage.camera_bounds_class_name
    local floor_class_name = rt.settings.overworld.stage.floor_class_name
    local wall_class_name = rt.settings.overworld.stage.wall_class_name

    self._floor_to_draw = {}
    self._other_to_draw = {}
    self._walls_to_draw = {}
    self._object_id_to_instance = meta.make_weak({})

    for layer_i = 1, self._config:get_n_layers() do
        local to_draw = self._other_to_draw
        local layer_class = self._config:get_layer_class(layer_i)
        if layer_class == wall_class_name then
            to_draw = self._walls_to_draw
        elseif layer_class == floor_class_name then
            to_draw = self._floor_to_draw
        end

        local spritebatches = self._config:get_layer_sprite_batches(layer_i)
        if table.sizeof(spritebatches) > 0 then
            table.insert(to_draw, function()
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
                    wrapper.class = "Hitbox"
                end

                local object
                if wrapper.class == player_spawn_class_name then
                    assert(wrapper.type == ow.ObjectType.POINT, "In ow.Stage: object of class `" .. player_spawn_class_name .. "` is not a point")
                    assert(self._player_spawn_x == nil and self._player_spawn_y == nil, "In ow.Stage: more than one object of type `" .. player_spawn_class_name .. "`")
                    self._player_spawn_x, self._player_spawn_y = wrapper.x, wrapper.y
                elseif wrapper.class == camera_bounds_class_name then
                    assert(wrapper.type == ow.ObjectType.RECTANGLE and wrapper.rotation == 0, "In ow.Stage: object of class `" .. camera_bounds_class_name .. "` is not an axis-aligned rectangle")
                    assert(camera_bounds_seen == false, "In ow.Stage: more than one object of type `" .. camera_bounds_class_name .. "`")
                    self._camera_bounds = rt.AABB(
                        wrapper.x,
                        wrapper.y,
                        wrapper.width,
                        wrapper.height
                    )
                    camera_bounds_seen = true
                else
                    local Type = ow[wrapper.class]
                    if Type == nil then
                        rt.error("In ow.Stage: unhandled object class `" .. tostring(wrapper.class) .. "`")
                    end
                    object = Type(wrapper, self, self._scene)
                    table.insert(self._objects, object)
                    self._object_id_to_instance[wrapper.id] = object

                    if meta.isa(object, rt.Drawable) then
                        table.insert(drawables, object)
                    end

                    if object.update ~= nil then
                        table.insert(self._to_update, object)
                    end
                end
            end
        end

        table.insert(to_draw, function()
            for drawable in values(drawables) do
                drawable:draw()
            end
        end)
    end

    local w, h = self._config:get_size()
    if self._player_spawn_x == nil then self._player_spawn_x = 0.5 * w end
    if self._player_spawn_y == nil then self._player_spawn_y = 0.5 * h end

    self._bounds = rt.AABB(0, 0, w, h)
    self._is_initialized = true
    self:signal_emit("initialized")
end

--- @brief
function ow.Stage:draw_floors()
    for f in values(self._floor_to_draw) do
        f()
    end
end

--- @brief
function ow.Stage:draw_objects()
    for f in values(self._other_to_draw) do
        f()
    end
end

--- @brief
function ow.Stage:draw_walls()
    for f in values(self._walls_to_draw) do
        f()
    end
    self._blood_splatter:draw()
end

--- @brief
function ow.Stage:draw()
    self:draw_floors()
    self:draw_objects()
    self:draw_walls()
    self._pathfinding_graph:draw()
end

--- @brief
function ow.Stage:update(delta)
    self._world:update(delta)

    for updatable in values(self._to_update) do
        updatable:update(delta)
    end
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
function ow.Stage:get_camera_bounds()
    return self._camera_bounds
end

--- @brief
function ow.Stage:get_size()
    local buffer = rt.settings.overworld.stage.physics_world_buffer_length
    local w, h = self._config:get_size()
    return w + 2 * buffer, h * 2 + buffer
end

--- @brief
function ow.Stage:get_id()
    return self._config:get_id()
end

--- @brief
function ow.Stage:get_object_instance(object)
    meta.assert(object, ow.ObjectWrapper)
    if not self._is_initialized then
        rt.error("In ow.Stage:get_object_instance: stage is not yet fully initialized")
        return
    end

    return self._object_id_to_instance[object.id]
end

--- @brief
function ow.Stage:get_pathfinding_graph()
    return self._pathfinding_graph
end

--- @brief
function ow.Stage:add_blood_splatter(x1, y1, x2, y2)
    meta.assert(x1, "Number", y1, "Number", x2, "Number", y2, "Number")
    self._blood_splatter:add(x1, y1, x2, y2)
end