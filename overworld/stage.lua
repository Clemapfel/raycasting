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
meta.add_signals(ow.Stage, "initialized", "respawn")

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

        _world = b2.World(),
        _camera_bounds = rt.AABB(-math.huge, -math.huge, math.huge, math.huge),

        _objects = {},
        _wrapper_id_to_object = {}, -- Table<Number, Any>

        -- drawables
        _below_player = meta.make_weak({}),
        _above_player = meta.make_weak({}),
        _masks = meta.make_weak({}),

        -- updatables
        _to_update = meta.make_weak({}),

        -- stage objects
        _coins = {}, -- cf. add_coin
        _checkpoints = {}, -- cf. add_checkpoint
        _blood_splatter = ow.BloodSplatter(),
        _flow_graph_nodes = {},
        _flow_graph = nil, -- ow.FlowGraph
        _flow_fraction = 0,

        _goals = {}, -- Set
        _active_checkpoint = nil,
    })
    self._world:set_use_fixed_timestep(false)

    local render_priorities = {}
    local render_priority_to_object = {}
    local _get_default_render_priority = function()
        return -1
    end

    -- batched draws
    ow.Hitbox:reinitialize()
    ow.BoostField:reinitialize()
    ow.AcceleratorSurface:reinitialize()

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
                    -- inject render priority
                    local priority = -1
                    if object.get_render_priority == nil then
                        object.get_render_priority = _get_default_render_priority
                    end
                    priority = object:get_render_priority()

                    local priority_entry = render_priority_to_object[priority]
                    if priority_entry == nil then
                        priority_entry = {}
                        render_priority_to_object[priority] = priority_entry
                    end
                    table.insert(priority_entry, object)
                    render_priorities[priority] = true
                end

                if object.draw_mask ~= nil then
                    table.insert(self._masks, object)
                end

                if object.update ~= nil then
                    table.insert(self._to_update, object)
                end
            end
        end
    end

    local render_priorities_in_order = {}
    for priority in keys(render_priorities) do
        table.insert(render_priorities_in_order, priority)
    end
    table.sort(render_priorities_in_order)

    for priority in values(render_priorities_in_order) do
        local entry = render_priority_to_object[priority]
        if priority <= 0 then
            for object in values(entry) do
                table.insert(self._below_player, object)
            end
        else
            for object in values(entry) do
                table.insert(self._above_player, object)
            end
        end
    end

    self._is_initialized = true
    self:signal_emit("initialized")

    -- check for PlayerSpawn
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

    -- create contour
    self._blood_splatter:create_contour()

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
end

--- @brief
function ow.Stage:draw_below_player()
    ow.BoostField:draw_all()
    ow.Hitbox:draw_all()

    for object in values(self._below_player) do
        object:draw()
    end

    self._blood_splatter:draw()
end

--- @brief
function ow.Stage:draw_above_player()
    ow.AcceleratorSurface:draw_all()

    for object in values(self._above_player) do
        object:draw()
    end
end

--- @brief
function ow.Stage:draw_mask()
    for object in values(self._masks) do
        object:draw_mask()
    end
end

--- @brief
function ow.Stage:update(delta)
    for object in values(self._to_update) do
        object:update(delta)
    end

    if self._flow_graph ~= nil then
        self._flow_fraction = self._flow_graph:update_player_position(self._scene:get_player():get_position())
    end

    self._world:update(delta)
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
        self._active_checkpoint = checkpoint
    elseif type == ow.CheckpointType.GOAL then
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
end

--- @brief
function ow.Stage:_notify_flow_graph_node_added(node)
    table.insert(self._flow_graph_nodes, node)
end

--- @brief
function ow.Stage:finish_stage()
    rt.warning("In ow.Stage.finish_stage: TODO")
end
