require "common.player"
require "overworld.stage_config"
require "overworld.object_wrapper"
require "overworld.pathfinding_graph"
require "overworld.blood_splatter"
require "overworld.mirror"
require "overworld.normal_map"
require "physics.physics"

-- include all overworld classes
for file in values(love.filesystem.getDirectoryItems("overworld/objects")) do
    if love.filesystem.getInfo("overworld/objects/" .. file).type == "file" then
        local match = string.match(file, "^(.-)%.lua$")
        if match and (string.match(file, "^~") == nil) then
            require("overworld.objects." .. match)
        end
    end
end

rt.settings.overworld.stage = {
    physics_world_buffer_length = 0
}

--- @class ow.Stage
--- @signal initialized (self) -> nil
ow.Stage = meta.class("Stage", rt.Drawable)
meta.add_signals(ow.Stage, "initialized", "respawn", "loading_done")

ow.Stage._config_atlas = {}

local all_types = {}

--- @brief
function ow.Stage:instantiate(scene, id)
    meta.assert(scene, "OverworldScene", id, "String")

    local config = ow.Stage._config_atlas[id]
    if config == nil then
        config = ow.StageConfig(id)
        ow.Stage._config_atlas[id] = config
    end

    meta.install(self, {
        _scene = scene,
        _id = id,
        _config = config,
        _is_initialized = false,
        _is_first_spawn = true,

        _world = b2.World(),
        _camera_bounds = rt.AABB(-math.huge, -math.huge, math.huge, math.huge),

        _objects = {},
        _wrapper_id_to_object = {}, -- Table<Number, Any>

        -- drawables
        _below_player = meta.make_weak({}),
        _above_player = meta.make_weak({}),
        _bloom_objects = meta.make_weak({}),

        -- updatables
        _to_update = meta.make_weak({}),

        -- stage objects
        _coins = {}, -- cf. add_coin
        _checkpoints = {}, -- cf. add_checkpoint
        _blood_splatter = ow.BloodSplatter(scene),
        _mirror = ow.Mirror(scene),

        _flow_graph_nodes = {},
        _flow_graph = nil, -- ow.FlowGraph
        _flow_fraction = 0,

        _normal_map = ow.NormalMap(self),

        _goals = {}, -- Set
        _active_checkpoint = nil,
    })
    self._world:set_use_fixed_timestep(false)

    self._signal_done_emitted = false
    self._normal_map_done = false
    self._normal_map:signal_connect("done", function()
        self._normal_map_done = true
        return meta.DISCONNECT_SIGNAL
    end)

    local render_priority_to_entry = {}
    self._below_player = {}
    self._above_player = {}

    -- batched draws
    ow.Hitbox:reinitialize()
    ow.BoostField:reinitialize()

    -- parse layers
    for layer_i = 1, self._config:get_n_layers() do
        --local spritebatches = self._config:get_layer_sprite_batches(layer_i)
        -- TODO: handle sprite batches
        -- init object instances
        local object_wrappers = self._config:get_layer_object_wrappers(layer_i)
        if table.sizeof(object_wrappers) > 0 then
            for wrapper in values(object_wrappers) do
                if wrapper.class == nil then
                    rt.warning("In ow.Stage.instantiate: object `" .. wrapper.id .. "` of stage `" .. self._config:get_id() .. "` has no class, assuming `Hitbox`")
                    wrapper.class = "Hitbox"
                end

                local Type = ow[wrapper.class]
                if Type == nil then
                    rt.error("In ow.Stage: unhandled object class `" .. tostring(wrapper.class) .. "`")
                end

                local object = Type(wrapper, self, self._scene)
                table.insert(self._objects, object)
                self._wrapper_id_to_object[wrapper.id] = object

                if object.draw ~= nil then
                    local priorities = { 0 }
                    if object.get_render_priority ~= nil then
                        priorities = { object:get_render_priority() }
                    end

                    for priority in values(priorities) do
                        if not meta.is_number(priority) then
                            rt.error("In ow." .. wrapper.class .. ".get_render_priority: does not return a number or tuple of numbers")
                        end

                        local entry = render_priority_to_entry[priority]
                        if entry == nil then
                            entry = {
                                priority = priority,
                                objects = {}
                            }

                            render_priority_to_entry[priority] = entry
                            if priority <= 0 then
                                table.insert(self._below_player, entry)
                            else
                                table.insert(self._above_player, entry)
                            end
                        end

                        table.insert(entry.objects, object)
                    end
                end

                if object.draw_bloom ~= nil then
                    table.insert(self._bloom_objects, object)
                end

                if object.update ~= nil then
                    table.insert(self._to_update, object)
                end
            end
        end
    end

    -- check for PlayerSpawn
    if self._active_checkpoint == nil then
        rt.warning("In ow.Stage.initialize: not `PlayerSpawn` for stage `" .. self._id .. "`")
    end

    -- sort by render priority
    table.sort(self._below_player, function(a, b)
        return a.priority < b.priority
    end)

    table.sort(self._above_player, function(a, b)
        return a.priority < b.priority
    end)

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

    -- contour effects
    self._blood_splatter:create_contour()
    self._mirror:create_contour()

    -- create flow graph
    if table.sizeof(self._flow_graph_nodes) < 2 then
        self._flow_graph = nil
    else
        self._flow_graph = ow.FlowGraph(self._flow_graph_nodes)
    end
    self._flow_fraction = 0

    local n_goals = 0
    for goal in keys(self._goals) do
        n_goals = n_goals + 1
    end

    if n_goals == 0 then
        rt.warning("In ow.Stage.initialize: no `Goal` object present in stage `" .. self._id .. "`")
    else
        rt.warning("In ow.Stage.initialize: more than one `Goal` object present in stage `" .. self._id .. "`")
    end

    self._is_initialized = true
    self:signal_emit("initialized")

    self._is_first_spawn = true
    self:signal_connect("respawn", function()
        self._is_first_spawn = false
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.Stage:draw_below_player()
    ow.BoostField:draw_all()
    ow.Hitbox:draw_base()
    self._normal_map:draw_shadow()
    ow.Hitbox:draw_outline()

    for entry in values(self._below_player) do
        for object in values(entry.objects) do
            object:draw(entry.priority)
        end
    end

    self._blood_splatter:draw()
end

--- @brief
function ow.Stage:draw_above_player()
    self._mirror:draw()
    self._normal_map:draw_light()

    for entry in values(self._above_player) do
        for object in values(entry.objects) do
            object:draw(entry.priority)
        end
    end
end

--- @brief
function ow.Stage:draw_bloom()
    for object in values(self._bloom_objects) do
        object:draw_bloom()
    end

    self._blood_splatter:draw()

    if rt.GameState:get_is_performance_mode_enabled() ~= true then
        self._mirror:draw()
    end
end

local _data = {}

local _add_entry = function(type, t)
    local entry = _data[type]
    if entry == nil then
        entry = {
            n = 0,
            sum = 0
        }
        _data[type] = entry
    end

    entry.n = entry.n + 1
    entry.sum = entry.sum + t
end

--- @brief
function ow.Stage:update(delta)
    if self._normal_map_done and self._is_initialized and self._signal_done_emitted == false then
        self:signal_emit("loading_done")
        self._signal_done_emitted = true
    end

    for object in values(self._to_update) do
        local a = love.timer.getTime()
        object:update(delta)
        local b = love.timer.getTime()

        _add_entry(meta.typeof(object), b - a)
    end

    if self._flow_graph ~= nil then
        self._flow_fraction = self._flow_graph:update_player_position(self._scene:get_player():get_position())
    end

    if rt.GameState:get_is_performance_mode_enabled() ~= true then
        local a = love.timer.getTime()
        self._mirror:update(delta)
        local b = love.timer.getTime()
        _add_entry("mirror", b - a)
    end

    do
        local a = love.timer.getTime()
        self._world:update(delta)
        local b = love.timer.getTime()
        _add_entry("world", b - a)
    end

    local times = {}
    for type, entry in pairs(_data) do
        table.insert(times, { type, (entry.sum / entry.n) / (1 / 60) })
    end
    table.sort(times, function(a, b)
        return a[2] > b[2]
    end)

    self._normal_map:update(delta) -- update last for yielding
end

--- @brief
function ow.Stage:get_flow_fraction()
    return self._flow_fraction
end

--- @brief
function ow.Stage:get_physics_world()
    return self._world
end

--- @brief
function ow.Stage:get_id()
    return self._id
end

--- @brief
function ow.Stage:get_object_instance(object)
    meta.assert(object, ow.ObjectWrapper)
    if not self._is_initialized then
        rt.error("In ow.Stage:get_object_instance: stage is not yet fully initialized")
        return
    end

    return self._wrapper_id_to_object[object.id]
end

--- @brief
function ow.Stage:add_checkpoint(checkpoint, id, type)
    meta.assert(checkpoint, ow.Checkpoint, id, "Number")
    self._checkpoints[id] = {
        checkpoint = checkpoint,
        timestamp = nil
    }

    if type == ow.CheckpointType.PLAYER_SPAWN then
        self._player_spawn = checkpoint
        self._active_checkpoint = self._player_spawn
    elseif type == ow.CheckpointType.PLAYER_GOAL then
        self._goals[checkpoint] = true
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
        is_collected = coin:get_is_collected()
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

--- @brief
function ow.Stage:get_blood_splatter()
    return self._blood_splatter
end
--- @brief
function ow.Stage:destroy()
    local native = self._world:get_native()
    for body in values(native:getBodies()) do
        local instance = body:getUserData()
        instance:signal_disconnect_all()
        body:destroy()
    end
    native:destroy()
    native:release()

    self._blood_splatter:destroy()
    self._mirror:destroy()
end

--- @brief
function ow.Stage:_notify_flow_graph_node_added(node)
    table.insert(self._flow_graph_nodes, node)
end

--- @brief
function ow.Stage:finish_stage()
    rt.warning("In ow.Stage.finish_stage: TODO")
end

--- @brief
function ow.Stage:get_scene()
    return self._scene
end

--- @brief
function ow.Stage:get_is_first_spawn()
    return self._is_first_spawn
end