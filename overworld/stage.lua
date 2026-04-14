require "common.player"
require "common.shader"
require "common.noise_texture"
require "overworld.stage_config"
require "overworld.object_wrapper"
require "overworld.pathfinding_graph"
require "overworld.blood_splatter"
require "overworld.mirror"
require "overworld.normal_map"
require "overworld.player_recorder"
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
    visible_area_padding = 4 * rt.settings.player.radius, -- px
}

--- @class ow.Stage
--- @signal initialized (self) -> nil
--- @signal respawn (self, is_first_spawn) -> nil
--- @signal loading_done (self) -> nil
ow.Stage = meta.class("Stage", rt.Drawable)
meta.add_signals(ow.Stage,
    "initialized",
    "post_initialized",
    "respawn",
    "loading_done",
    "reset"
)

--- @brief
function ow.Stage:instantiate(scene, id)
    meta.assert(scene, "OverworldScene", id, "String")

    local config = rt.GameState:stage_get_config(id)

    self._id = id
    meta.install(self, {
        _scene = scene,
        _config = config,
        _is_initialized = false,
        _is_first_spawn = true,
        _is_respawning = false,

        _world = b2.World(),
        _camera_bounds = rt.AABB(-math.huge, -math.huge, math.huge, math.huge),

        _wrapper_id_to_instance = {}, -- Table<Number, Any>
        _instance_to_wrapper = {}, -- Table<Any, Number>
        _wrapper_id_to_wrapper = {}, -- Table<Number, ow.ObjectWrapper>

        -- drawables
        _below_player = meta.make_weak({}),
        _above_player = meta.make_weak({}),
        _bloom_objects = meta.make_weak({}),

        -- updatables
        _to_update = meta.make_weak({}),
        _to_reset = meta.make_weak({}),

        -- stage objects
        _coins = {}, -- cf. add_coin
        _camera_bounds = meta.make_weak({}), -- Table<ow.CameraBounds>
        _checkpoints = meta.make_weak({}), -- Table<ow.Checkpoint, Number>
        _blood_splatter = ow.BloodSplatter(scene),
        _mirror = nil, -- ow.Mirror

        _flow_graph_nodes = {},
        _flow_graph = nil, -- ow.FlowGraph
        _flow_fraction = 0,

        _active_checkpoint = nil,
        _player_spawn_ref = nil,

        _visible_bodies = {},
        _light_sources = {},

        -- npc
        _player_recorder = nil, -- ow.PlayerRecorder
    })

    self._player_recorder = ow.PlayerRecorder(self, self._scene, self._scene:get_player():get_position())

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "r" then
            self._player_recorder:record()
        elseif which == "t" then
            self._player_recorder:play()
        elseif which == "ö" then
            self._player_recorder:export("test.csv")
        end
    end)
    -- TODO

    ow.Hitbox.reinitialize(self._scene, self)
    ow.Sprite.reinitialize(self._scene, self)
    ow.Fireflies.reinitialize(self._scene, self)
    ow.AirDashNode.reinitialize(self._scene, self)

    local get_triangle_callback = function()
        return ow.Hitbox:get_mesh_tris(true, true)
    end

    local draw_mask_callback = function()
        ow.Hitbox:draw_mask(
            rt.settings.overworld.normal_map.mask_sticky,
            rt.settings.overworld.normal_map.mask_slippery
        )
    end

    self._normal_map = ow.NormalMap(
        self:get_id(),
        get_triangle_callback,
        draw_mask_callback
    )
    self._normal_map._debug_draw_enabled = true

    -- static hitbox mirrors

    self._mirror = ow.Mirror(
        scene,
        function() ow.Hitbox:draw_mask(false, true) end,
        function() ow.Hitbox:draw_mask(true, false) end
    )

    -- misc

    self._world:set_use_fixed_timestep(false)

    self._signal_done_emitted = false
    self._normal_map_done = false

    if self._normal_map:get_is_done() then
        self._normal_map_done = true
    else
        self._normal_map:signal_connect("done", function()
            self._normal_map_done = true
            return meta.DISCONNECT_SIGNAL
        end)
    end

    local render_priority_to_entry = {}
    self._below_player = {}
    self._above_player = {}
    self._above_bloom = {}

    -- add hitbox as renderable proxy
    local hitbox_render_priority = rt.settings.overworld.hitbox.render_priority
    render_priority_to_entry[hitbox_render_priority] = {
        priority = hitbox_render_priority,
        objects = { {
            draw = function()
                ow.Hitbox:draw_base()
                self._normal_map:draw_shadow(self._scene:get_camera())
            end
       } }
    }

    -- checkpoint to checkpoint split
    self._checkpoints = meta.make_weak({})
    local n_goals = 0 -- number ow.Goal, for warning

    self._camera_bounds = meta.make_weak({})

    local coins = {}

    -- parse layers
    for layer_i = 1, self._config:get_n_layers() do
        --local spritebatches = self._config:get_layer_sprite_batches(layer_i)
        -- init object instances
        local object_wrappers = self._config:get_layer_object_wrappers(layer_i)
        if table.sizeof(object_wrappers) > 0 then
            for wrapper in values(object_wrappers) do
                if wrapper.class == nil then
                    rt.warning("In ow.Stage.instantiate: object `",  wrapper.id,  "` of stage `",  self._config:get_id(),  "` has no class, assuming `Hitbox`")
                    wrapper.class = "Hitbox"
                end

                local Type = ow[wrapper.class]
                if Type == nil then
                    rt.error("In ow.Stage: unhandled object class `",  tostring(wrapper.class),  "`")
                end

                local instance = Type(wrapper, self, self._scene)

                local wrapper_id = wrapper.id
                self._wrapper_id_to_instance[wrapper_id] = instance
                self._instance_to_wrapper[instance] = wrapper

                -- catch objects relating to permanent state
                if meta.isa(instance, ow.Checkpoint) then
                    self:add_checkpoint(instance)
                elseif meta.isa(instance, ow.Coin) then
                    table.insert(coins, instance)
                elseif meta.isa(instance, ow.Goal) then
                    n_goals = n_goals + 1
                elseif meta.isa(instance, ow.CameraBounds) or meta.isa(instance, ow.CameraFit) then
                    table.insert(self._camera_bounds, instance)
                end

                -- inject id
                instance.get_id = function(self) return wrapper.id end

                -- handle drawables
                if meta.is_function(instance.draw) then
                    local priorities = { 0 }
                    if meta.is_function(instance.get_render_priority) then
                        priorities = { instance:get_render_priority() }
                    end

                    -- render priority override
                    if wrapper:get_number("render_priority", false) ~= nil then
                        priorities[1] = wrapper:get_number("render_priority")
                    end

                    for priority in values(priorities) do
                        if not meta.is_number(priority) then
                            rt.error("In ow.",  wrapper.class,  ".get_render_priority: does not return a number or tuple of numbers")
                        end

                        if priority == math.huge then
                            table.insert(self._above_bloom, instance)
                        else
                            local entry = render_priority_to_entry[priority]
                            if entry == nil then
                                entry = {
                                    priority = priority,
                                    objects = {}
                                }

                                render_priority_to_entry[priority] = entry
                            end

                            table.insert(entry.objects, instance)
                        end
                    end
                end

                if meta.is_function(instance.draw_bloom) then
                    table.insert(self._bloom_objects, instance)
                end

                if meta.is_function(instance.update) then
                    table.insert(self._to_update, instance)
                end

                if meta.is_function(instance.reset) then
                    table.insert(self._to_reset, instance)
                end
            end
        end
    end

    -- add non-object updatables
    table.insert(self._to_update, self._player_recorder)
    for object in range(
        self._mirror,
        self._world,
        self._normal_map
    ) do
        if meta.is_function(object.update) then
            table.insert(self._to_update, object)
        end

        if meta.is_function(object.draw_bloom) then
            table.insert(self._bloom_objects, object)
        end
    end

    -- distribute drawables
    for priority, entry in pairs(render_priority_to_entry) do
        if priority <= 0 then
            table.insert(self._below_player, entry)
        else
            table.insert(self._above_player, entry)
        end
    end

    -- add sprites, batched by priority
    for priority in values(ow.Sprite.list_all_priorites) do
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

        -- no insert, sprites invoked automatically
    end

    -- check for PlayerSpawn
    if self._active_checkpoint == nil then
        rt.warning("In ow.Stage.initialize: no `PlayerSpawn` for stage `",  self._id,  "`")
    end

    local sort = function(t)
        -- sort entries by priority
        table.sort(t, function(a, b)
            return a.priority < b.priority
        end)

        -- group similar objects next to each other for better batching
        for entry in values(t) do
            table.sort(entry.objects, function(a, b)
                return meta.typeof(a) < meta.typeof(b)
            end)
        end
    end

    sort(self._below_player)
    sort(self._above_player)

    self._blood_splatter:create_contour(
        ow.Hitbox:get_collision_tris(true, false), -- sticky
        ow.Hitbox:get_collision_tris(false, true)  -- slippery occluding
    )

    self._mirror:create_contour(
        ow.Hitbox:get_collision_tris(false, true), -- mirror
        ow.Hitbox:get_collision_tris(true, false) -- occluding
    )

    -- create flow graph
    if table.sizeof(self._flow_graph_nodes) < 2 then
        self._flow_graph = nil
    else
        self._flow_graph = ow.FlowGraph(self._flow_graph_nodes)
    end
    self._flow_fraction = 0

    do -- setup coin indexing
        if self._flow_graph ~= nil then
            -- if flow graph present, order along it
            local coin_to_fraction = {}
            for coin in values(coins) do
                coin_to_fraction[coin] = self._flow_graph:get_fraction(coin:get_position())
            end

            table.sort(coins, function(a, b)
                return coin_to_fraction[a] < coin_to_fraction[b]
            end)
        else
            -- else order by x
            table.sort(coins, function(a, b)
                local ax, ay = a:get_position()
                local bx, by = b:get_position()
                if ax == bx then return ay > by else return ax < bx end
            end)
        end

        for i, coin in ipairs(coins) do
            coin:set_index(i)
            self._coins[i] = coin
        end
    end

    do  -- assert checkpoint multiplicity
        local n_spawns = 0
        for checkpoint in keys(self._checkpoints) do
            if checkpoint:get_type() == ow.CheckpointType.PLAYER_SPAWN then
                self._player_spawn_ref = checkpoint
                n_spawns = n_spawns + 1
            end
        end

        if n_goals == 0 then
            rt.warning("In ow.Stage.initialize: no `Goal` object present in stage `",  self._id,  "`")
        else
            rt.warning("In ow.Stage.initialize: more than one `Goal` object present in stage `",  self._id,  "`")
        end

        if n_spawns == 0 then
            rt.warning("In ow.Stage.initialize: no `PlayerSpawn` object present in stage `",  self._id,  "`")
        else
            rt.warning("In ow.Stage.initialize: more than one `PlayerSpawn` object present in stage `",  self._id,  "`")
        end
    end

    self._is_initialized = true

    self:signal_emit("initialized")
    self:signal_emit("post_initialized")

    self._is_first_spawn = true
    self:signal_connect("respawn", function()
        self._is_first_spawn = false
        return meta.DISCONNECT_SIGNAL
    end)

    -- precompile shader
    rt.Shader:precompile_all()
end

--- @brief
function ow.Stage:draw_below_player()
    for entry in values(self._below_player) do
        for object in values(entry.objects) do
            object:draw(entry.priority)
        end

        ow.Sprite.draw_all(entry.priority)
    end

    self._player_recorder:draw()
    self._blood_splatter:draw()
end

--- @brief
function ow.Stage:draw_above_player()
    self._mirror:draw()

    self._normal_map:draw_light(self._scene:get_camera())
    for entry in values(self._above_player) do
        for object in values(entry.objects) do
            object:draw(entry.priority)
        end

        ow.Sprite.draw_all(entry.priority)
    end

    rt.SceneManager:get_light_map():draw()
end

--- @brief
function ow.Stage:draw_bloom()
    for object in values(self._bloom_objects) do
        object:draw_bloom()
    end
end

--- @brief
function ow.Stage:draw_above_bloom()
    for object in values(self._above_bloom) do
        object:draw()
    end
end

--- @brief
function ow.Stage:update(delta)
    if self._normal_map_done and self._is_initialized and self._signal_done_emitted == false then
        self:signal_emit("loading_done")
        self._signal_done_emitted = true
    end

    if self._normal_map_done then
        -- collect light sources and visibel bodies
        local camera = self._scene:get_camera()
        local bounds = camera:get_world_bounds()

        local padding = rt.settings.overworld.stage.visible_area_padding

        self._visible_bodies = {}
        local light_mask_bodies = {}

        for body in values(self._world:query_aabb(
            bounds.x - padding, bounds.y - padding,
            bounds.width + 2 * padding, bounds.height + 2 * padding
        )) do
            self._visible_bodies[body] = true
            if body:has_tag("use_lighting") then
                table.insert(light_mask_bodies, body)
            end
        end

        local light_map = rt.SceneManager:get_light_map()

        love.graphics.push("all")
        love.graphics.reset()
        light_map:bind_mask()
        love.graphics.setColor(1, 1, 1, 1)
        self._scene:get_camera():bind()
        for body in values(light_mask_bodies) do
            body:draw(true) -- mask only
        end
        self._scene:get_camera():unbind()
        light_map:unbind_mask()
        love.graphics.pop()

        light_map:update(self)
    end

    for object in values(self._to_update) do
        object:update(delta)
    end


    if self._flow_graph ~= nil then
        --self._flow_fraction = self._flow_graph:update_player_position(self._scene:get_player():get_position())
    end
end

local _error_no_userdata = function(scope, instance)
    rt.error("In ow.Stage.", scope, " object `",  meta.typeof(instance),  "` is a point light source but, the body does not have a userdata pointing to an instance")
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
function ow.Stage:object_wrapper_to_instance(object)
    meta.assert(object, ow.ObjectWrapper)
    if not self._is_initialized then
        rt.error("In ow.Stage:object_wrapper_id_to_instance: stage is not yet fully initialized")
        return nil
    end

    return self._wrapper_id_to_instance[object:get_id()]
end

--- @brief
function ow.Stage:instance_to_object_wrapper(instance)
    if not self._is_initialized then
        rt.error("In ow.Stage:object_wrapper_id_to_instance: stage is not yet fully initialized")
        return nil
    end

    return self._wrapper_id_to_wrapper[self._instance_to_wrapper[instance]]
end


local _no_timestamp = -1

--- @brief
function ow.Stage:add_checkpoint(checkpoint)
    meta.assert(checkpoint, ow.Checkpoint)
    self._checkpoints[checkpoint] = _no_timestamp

    local type = checkpoint:get_type()
    if type == ow.CheckpointType.PLAYER_SPAWN then
        self._active_checkpoint = checkpoint
    end
end

--- @brief
function ow.Stage:set_active_checkpoint(checkpoint)
    self._active_checkpoint = checkpoint or self._player_spawn_ref
end

--- @brief
function ow.Stage:get_active_checkpoint()
    return self._active_checkpoint
end

--- @brief
function ow.Stage:set_checkpoint_split(checkpoint)
    local current = self._checkpoints[checkpoint]
    if current == nil then
        rt.error("In ow.Stage:set_checkpoint_split: checkpoint is not present in stage")
    end

    if current ~= _no_timestamp then
        rt.error("In ow.Stage:set_checkpoint_split: updating splits of checkpoint `",  self._instance_to_wrapper[checkpoint],  "`, but time was already updated")
    end

    self._checkpoints[checkpoint] = self._scene:get_timer()
end

--- @brief
function ow.Stage:get_checkpoint_splits()
    local times = {}

    local at_least_one_not_done = false
    for checkpoint, time in pairs(self._checkpoints) do
        if time ~= _no_timestamp then
            table.insert(times, time)
        else
            at_least_one_not_done = true
        end
    end

    table.sort(times)

    -- add current split time unless player already passed goal
    if at_least_one_not_done then
        table.insert(times, self._scene:get_timer())
    end

    return times
end

--- @brief
function ow.Stage:get_is_body_visible(body)
    meta.assert(body, b2.Body)
    return self._visible_bodies[body] == true
end

--- @brief
function ow.Stage:set_coin_is_collected(id, is_collected)
    local entry = self._coins[id]
    if entry == nil then
        rt.warning("In ow.Staget.set_coin_collected: no coin with id `",  id,  "`")
        return
    end

    entry.is_collected = is_collected
end

--- @brief
function ow.Stage:get_coin_is_collected(coin_i)
    local entry = self._coins[coin_i]
    if entry == nil then
        rt.warning("In ow.Staget.get_coin_is_collected: no coin with id `",  coin_i,  "`")
        return false
    end

    return entry.is_collected
end

--- @brief
function ow.Stage:get_n_coins()
    return table.sizeof(self._coins)
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
    if self._world ~= nil then
        self._world:destroy()
    end

    self._player_recorder:destroy()
    self._mirror:destroy()
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

--- @brief
function ow.Stage:get_scene()
    return self._scene
end

--- @brief
function ow.Stage:get_is_first_spawn()
    return self._is_first_spawn
end

--- @brief
function ow.Stage:clear_cache()
end

--- @brief
function ow.Stage:get_is_initialized()
    return self._is_initialized
end

--- @brief
function ow.Stage:get_is_loading_done()
    return self._signal_done_emitted
end

--- @brief
function ow.Stage:reset()
    local body_to_is_enabled = {}
    for body in values(self._world:get_bodies()) do
        body_to_is_enabled[body] = body:get_is_enabled()
        body:set_is_enabled(false)
    end

    for instance in values(self._to_reset) do
        instance:reset()
    end

    for body in values(self._world:get_bodies()) do
        body:set_is_enabled(body_to_is_enabled[body])
    end

    rt.SceneManager:get_light_map():clear()

    self:signal_emit("reset")
end

--- @brief
function ow.Stage:apply_camera_bounds(x, y, should_snap)
    meta.assert(x, "Number", y, "Number")
    local camera = self._scene:get_camera()
    camera:clear_bounds()

    for bounds in values(self._camera_bounds) do
        bounds:try_bind(x, y)
    end

    if should_snap == true then
        camera:snap_to_bounds()
    end
end

local _instance_sort_function = function(a, b)
    return meta.hash(a) < meta.hash(b)
end

--- @brief
function ow.Stage:collect_point_lights(callback)
    local player = self._scene:get_player()
    player:collect_point_lights(callback)

    local instances = {}
    for body in keys(self._visible_bodies) do
        if body:has_tag("point_light_source") then
            local instance = body:get_user_data()
            if instance == nil then
                rt.error("In ow.Stage.collect_point_lights: body `", meta.hash(body), "` is marked as point light source, but body userdata is not set")
            end

            table.insert(instances, instance)
        end
    end

    table.sort(instances, _instance_sort_function)

    for instance in values(instances) do
        if not meta.is_function(instance.collect_point_lights) then
            rt.error("In ow.Stage.collect_point_lights: instance of type `", meta.typeof(instance), "` is marked as point light source, but does not implement `collect_point_lights`")
        end
        instance:collect_point_lights(callback)
    end

    ow.Fireflies.get_manager(self):collect_point_lights(
        callback
    )
end

--- @brief
function ow.Stage:collect_segment_lights(callback)
    local instances = {}
    for body in keys(self._visible_bodies) do
        if body:has_tag("segment_light_source") then
            local instance = body:get_user_data()
            if instance == nil then
                rt.error("In ow.Stage.collect_segment_lights: body `", meta.hash(body), "` is marked as segment light source, but body userdata is not set")
            end

            table.insert(instances, instance)
        end
    end

    table.sort(instances, _instance_sort_function)

    instance_to_counts = {}
    for instance in values(instances) do
        if not meta.is_function(instance.collect_segment_lights) then
            rt.error("In ow.Stage.collect_segment_lights: instance of type `", meta.typeof(instance), "` is marked as segment light source, but does not implement `collect_segment_lights`")
        end

        local count = function(_)
            local type = meta.typeof(instance)
            local value = instance_to_counts[type] or 0
            instance_to_counts[type] = value + 1
        end
        instance:collect_segment_lights(callback)
        instance:collect_segment_lights(count)
    end

    self._blood_splatter:collect_segment_lights(
        self._scene:get_camera():get_world_bounds(),
        callback
    )
end

--- @brief
function ow.Stage:set_is_frozen(b)
    self._world:set_is_frozen(b)
end

--- @brief
function ow.Stage:get_is_frozen()
    return self._world:get_is_frozen()
end