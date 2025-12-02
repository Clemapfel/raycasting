require "common.player"
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
    physics_world_buffer_length = 0
}

--- @class ow.Stage
--- @signal initialized (self) -> nil
ow.Stage = meta.class("Stage", rt.Drawable)
meta.add_signals(ow.Stage, "initialized", "respawn", "loading_done")

local _config_atlas = {}

--- @brief
function ow.Stage:instantiate(scene, id)
    meta.assert(scene, "OverworldScene", id, "String")

    local config = _config_atlas[id]
    if config == nil then
        config = ow.StageConfig(id)
        _config_atlas[id] = config
    end

    self._id = id
    meta.install(self, {
        _scene = scene,
        _config = config,
        _is_initialized = false,
        _is_first_spawn = true,

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
        _checkpoints = meta.make_weak({}), -- Table<ow.Checkpoint, Number>
        _blood_splatter = ow.BloodSplatter(scene),
        _mirror = nil, -- ow.Mirror

        _flow_graph_nodes = {},
        _flow_graph = nil, -- ow.FlowGraph
        _flow_fraction = 0,

        _segment_light_sources = {},
        _segment_light_colors = {},
        _segment_light_sources_need_update = true,

        _point_light_sources = {},
        _point_light_colors = {},
        _point_light_sources_need_update = true,

        _active_checkpoint = nil,
        _player_spawn_ref = nil,

        _visible_bodies = {},
        _light_sources = {},

        -- npc
        _player_recorder = nil, -- ow.PlayerRecorder

        -- goal fade to black
        _fade_to_black = 0
    })

    self._player_recorder = ow.PlayerRecorder(self, self._scene)

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "r" then
            self._player_recorder:record()
        elseif which == "t" then
            self._player_recorder:play()
        end
    end)
    -- TODO

    ow.Hitbox:reinitialize()
    ow.Wall:reinitialize()
    ow.Sprite:reinitialize()
    ow.AirDashNode:reinitialize()

    -- static hitbox normal_map

    local get_triangle_callback = function()
        return ow.Hitbox:get_tris(true, true)
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

    -- checkpoint to checkpoint split
    self._checkpoints = meta.make_weak({})
    local n_goals = 0 -- number ow.Goal, for warning

    local coins = {}

    -- parse layers
    for layer_i = 1, self._config:get_n_layers() do
        --local spritebatches = self._config:get_layer_sprite_batches(layer_i)
        -- TODO: handle sprite batches
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
                end

                -- inject id
                instance.get_id = function(self) return wrapper.id  end

                -- handle drawables
                if instance.draw ~= nil then
                    local priorities = { 0 }
                    if instance.get_render_priority ~= nil then
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

                        table.insert(entry.objects, instance)
                    end
                end

                if instance.draw_bloom ~= nil then
                    table.insert(self._bloom_objects, instance)
                end

                if instance.update ~= nil then
                    table.insert(self._to_update, instance)
                end

                if instance.reset ~= nil then
                    table.insert(self._to_reset, instance)
                end
            end
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

    -- sort by render priority
    table.sort(self._below_player, function(a, b)
        return a.priority < b.priority
    end)

    table.sort(self._above_player, function(a, b)
        return a.priority < b.priority
    end)

    self._blood_splatter:create_contour(
        ow.Hitbox:get_tris(true, true)
    )

    self._mirror:create_contour(
        ow.Hitbox:get_tris(false, true), -- mirror
        ow.Hitbox:get_tris(true, false) -- occluding
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
    local point_lights, point_colors = self:get_point_light_sources()
    local segment_lights, segment_colors = self:get_segment_light_sources()
    ow.Wall:draw_all(
        self._scene:get_camera(),
        point_lights,
        point_colors,
        segment_lights,
        segment_colors
    )

    ow.Hitbox:draw_base()
    self._normal_map:draw_shadow(self._scene:get_camera())
    ow.Hitbox:draw_outline()

    for entry in values(self._below_player) do
        for object in values(entry.objects) do
            object:draw(entry.priority)
        end

        ow.Sprite.draw_all(entry.priority)
    end

    self._world:draw() -- TODO

    self._player_recorder:draw()
    self._blood_splatter:draw()
end

--- @brief
function ow.Stage:draw_above_player()
    self._mirror:draw()

    local point_lights, point_colors = self:get_point_light_sources()
    local segment_lights, segment_colors = self:get_segment_light_sources()
    self._normal_map:draw_light(
        self._scene:get_camera(),
        point_lights,
        point_colors,
        segment_lights,
        segment_colors
    )

    for entry in values(self._above_player) do
        for object in values(entry.objects) do
            object:draw(entry.priority)
        end

        ow.Sprite.draw_all(entry.priority)
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
            sum = 0,
            mean = 0,
            max = -math.huge
        }
        _data[type] = entry
    end

    entry.type = type
    entry.n = entry.n + 1
    entry.sum = entry.sum + t
    entry.max = math.max(entry.max, t / (1 / 60))
    entry.mean = (entry.sum / entry.n) / (1 / 60)
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
        local top_left_x, top_left_y = camera:screen_xy_to_world_xy(0, 0)
        local bottom_right_x, bottom_right_y = camera:screen_xy_to_world_xy(love.graphics.getDimensions())

        local padding = 8 * rt.settings.player.radius
        top_left_x, top_left_y = math.subtract(top_left_x, top_left_y, padding, padding)
        bottom_right_x, bottom_right_y = math.add(bottom_right_x, bottom_right_y, padding, padding)

        self._visible_bodies = {}
        self._light_sources = {}
        self._world:get_native():queryShapesInArea(top_left_x, top_left_y, bottom_right_x, bottom_right_y, function(shape)
            local body = shape:getBody():getUserData()
            self._visible_bodies[body] = true

            if body ~= nil and body:has_tag("light_source") then
                table.insert(self._light_sources, body)
            end

            return true
        end)
        self._segment_light_sources_need_update = true
        self._point_light_sources_need_update = true
    end

    self._player_recorder:update(delta)

    for object in values(self._to_update) do
        object:update(delta)
    end

    if self._flow_graph ~= nil then
        self._flow_fraction = self._flow_graph:update_player_position(self._scene:get_player():get_position())
    end

    self._mirror:update(delta)
    self._world:update(delta)
    self._normal_map:update(delta)
end

--- @brief
function ow.Stage:get_point_light_sources()
    if self._point_light_sources_need_update == true then
        local positions = {}
        local colors = {}

        -- sort to have consistent order if number of body exceeds
        -- normal map point light limit
        table.sort(self._light_sources, function(a, b)
            return meta.hash(a) < meta.hash(b)
        end)

        local camera = self._scene:get_camera()

        table.insert(positions, { camera:world_xy_to_screen_xy(self._scene:get_player():get_position()) })
        table.insert(colors, { rt.lcha_to_rgba(0.8, 1, self._scene:get_player():get_hue(), 1)})

        for body in values(self._light_sources) do
            local class = body:get_user_data()
            if class ~= nil and class.get_color then
                local color = class:get_color()
                if not meta.isa(color, rt.RGBA) then
                    rt.error("In ow.Stage: object `",  meta.typeof(class),  "` has a get_color function that does not return an object of type `rt.RGBA`")
                end

                if color.a == 0 then goto skip end
                table.insert(colors, { class:get_color():unpack() })

                local cx, cy = body:get_center_of_mass()
                table.insert(positions, { camera:world_xy_to_screen_xy(cx, cy) })
            end
            ::skip::
        end

        self._point_light_sources, self._point_light_colors = positions, colors
        self._point_light_sources_need_update = false
    end

    return self._point_light_sources, self._point_light_colors
end

--- @brief
function ow.Stage:get_segment_light_sources()
    if self._segment_light_sources_need_update == true then
        local segments, colors = self._blood_splatter:get_visible_segments(self._scene:get_camera():get_world_bounds())
        local camera = self._scene:get_camera()

        for body in keys(self._visible_bodies) do
            if body:has_tag("segment_light_source") then
                local instance = body:get_user_data()
                assert(instance ~= nil, "In ow.Stage:get_segment_light_sources: body has `segment_light_source` tag but userdata instance is not set")
                assert(instance.get_segment_light_sources, "In ow.Stage:get_segment_light_sources: body has `segment_light_source` tag, but instance `",  meta.typeof(instance),  "` does not have `get_segment_light_sources` defined")
                local current_segments, current_colors = instance:get_segment_light_sources()

                for segment in values(current_segments) do
                    table.insert(segments, segment)
                end

                for color in values(current_colors) do
                    table.insert(colors, color)
                end
            end
        end

        for segment in values(segments) do
            segment[1], segment[2] = camera:world_xy_to_screen_xy(segment[1], segment[2])
            segment[3], segment[4] = camera:world_xy_to_screen_xy(segment[3], segment[4])
        end

        self._segment_light_sources, self._segment_light_colors = segments, colors
        self._segment_light_sources_need_update = false
    end

    return self._segment_light_sources, self._segment_light_colors
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

    return entry.is_collected or rt.GameState:get_stage_is_coin_collected(self._id, coin_i)
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
    local native = self._world:get_native()
    for body in values(native:getBodies()) do
        local instance = body:getUserData()
        instance:signal_disconnect_all()
        body:destroy()
    end
    native:destroy()

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

--- @brief
function ow.Stage:clear_cache()
    _config_atlas = {}
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
    for instance in values(self._to_reset) do
        instance:reset()
    end

    self._fade_to_black = 0
end

--- @brief
function ow.Stage:set_fade_to_black(t)
    self._fade_to_black = t
end
