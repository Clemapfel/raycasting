require "overworld.stage_config"
require "overworld.object_wrapper"
require "common.player"
require "overworld.pathfinding_graph"
require "overworld.blood_splatter"

require "physics.physics"

-- include all overworld classes
for file in values(love.filesystem.getDirectoryItems("overworld/objects")) do
    if love.filesystem.getInfo("overworld/objects/" .. file).type == "file" then
        local match = string.match(file, "^(.-)%.lua$")
        if match then
            require("overworld.objects." .. match)
        end
    end
end

rt.settings.overworld.stage = {
    physics_world_buffer_length = 0,
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
    self._id = id

    self._coins = {} -- cf. add_coin
    self._checkpoints = {} -- cf. add_checkpoint
    self._active_checkpoint = nil

    local config = ow.Stage._config_atlas[id]
    if config == nil then
        config = ow.StageConfig(id)
        ow.Stage._config_atlas[id] = config
    end

    self._config = config
    self._to_update = {} -- Table<Any>
    self._objects = {}  -- Table<any>
    self._objects_to_render_priority = {} --  Table<Any, Number>, where 0: player, +n behind player, -n in front of player
    self._render_priority_to_objects = {} --  Table<Number, Any>
    self._render_priorities = {} -- Set<Number>

    self._pathfinding_graph = ow.PathfindingGraph()
    self._blood_splatter = ow.BloodSplatter(self)

    self._camera_bounds = rt.AABB(-math.huge, -math.huge, math.huge, math.huge)
    local camera_bounds_seen = false

    local buffer = rt.settings.overworld.stage.physics_world_buffer_length
    local w, h = self._config:get_size()
    self._world = b2.World(w + 2 * buffer, h + 2 * buffer)

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
                if wrapper.class == camera_bounds_class_name then
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

                    if object.draw ~= nil then
                        table.insert(drawables, object)
                    end

                    if object.update ~= nil then
                        table.insert(self._to_update, object)
                    end
                end
            end
        end

        table.sort(drawables, function(a, b)
            local a_priority = self._objects_to_render_priority[a]
            if a_priority == nil then a_priority = 0 end

            local b_priority = self._objects_to_render_priority[b]
            if b_priority == nil then b_priority = 0 end

            return a_priority < b_priority
        end)

        table.insert(to_draw, function()
            for drawable in values(drawables) do
                drawable:draw()
            end
        end)
    end

    local w, h = self._config:get_size()

    self._bounds = rt.AABB(0, 0, w, h)
    self._is_initialized = true
    self:signal_emit("initialized")

    if self._active_checkpoint == nil then
        rt.warning("In ow.Stage.initialize: not `PlayerSpawn` for stage `" .. self._id .. "`")
    end

    -- setup coins so colors don't repeat
    local in_order = {}
    for entry in values(self._coins) do
        table.insert(in_order, entry.coin)
    end
    table.sort(in_order, function(a, b)
        local ax, ay = a:get_position()
        local bx, by = b:get_position()
        return ax < bx
    end)

    local color_i = 1
    local color_n = table.sizeof(rt.Palette.COIN_COLORS)
    for coin in values(in_order) do
        coin:set_color(rt.Palette.COIN_COLORS[color_i])
        color_i = (color_i + 1) % color_n + 1
    end
end

--- @brief
function ow.Stage:draw_blood_splatter()
    self._blood_splatter:draw()
end

--- @brief
function ow.Stage:set_render_priority(object, number)
    if number ~= nil then meta.assert(number, "Number") end
    self._objects_to_render_priority[object] = number

    local entry = self._render_priority_to_objects[number]
    if entry == nil then
        entry = {}
        self._render_priority_to_objects[number] = entry
    end

    table.insert(entry, object)

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

--- @brief
function ow.Stage:add_checkpoint(checkpoint, id, is_spawn)
    meta.assert(checkpoint, ow.Checkpoint, id, "Number")
    self._checkpoints[id] = {
        checkpoint = checkpoint,
        timestamp = nil
    }
    if is_spawn then
        self._active_checkpoint = checkpoint
    end
end

--- @brief
function ow.Stage:set_active_checkpoint(checkpoint)
    self._active_checkpoint = checkpoint
end

--- @brief
function ow.Stage:get_active_checkpoint()
    return self._active_checkpoint
end

--- @brief
function ow.Stage:add_coin(coin, id)
    meta.assert(coin, ow.Coin, id, "Number")
    self._coins[id] = {
        coin = coin,
        is_collected = coin:get_is_collected(),
        color = nil
    }
end

--- @brief
function ow.Stage:set_coin_is_collected(id, is_collected)
    local entry = self._coins[id]
    if entry == nil then
        rt.warning("In ow.Staget.set_coin_collected: no coin with id `" .. id .. "`")
        return
    end

    entry.is_collected = is_collected
end

--- @brief
function ow.Stage:get_coin_is_collected(id)
    local entry = self._coins[id]
    if entry == nil then
        rt.warning("In ow.Staget.get_coin_is_collected: no coin with id `" .. id .. "`")
        return false
    end

    return entry.is_collected
end

--- @brief
function ow.Stage:get_n_coins()
    return table.sizeof(self._coins)
end

--- @brief
function ow.Stage:reset_coins()
    for id, entry in pairs(self._coins) do
        entry.is_collected = false
        entry.coin:set_is_collected(false)
    end
end

--- @brief
function ow.Stage:get_n_coins_collected()
    local n, n_collected = 0, 0
    for entry in values(self._coins) do
        n = n + 1
        if entry.is_collected then
            n_collected = n_collected + 1
        end
    end

    return n_collected, n
end

--- @brief
function ow.Stage:get_coins()
    local out = {}
    for entry in values(self._coins) do
        table.insert(out, entry.coin)
    end
    return out
end