require "common.scene"
require "common.input_subscriber"
require "common.fade"
require "common.palette"
require "common.cursor"
require "common.thread_manager"
require "common.bloom"
require "common.hdr"
require "common.screen_recorder"

rt.settings.scene_manager = {
    max_n_steps_per_frame = 8,
    performance_metrics_n_frames = 144,
    fade_duration = 0.2,
    fps_limit = 420,
    performance_metrics_interval = 5 -- seconds
}

--- @class SceneManager
rt.SceneManager = meta.class("SceneManager")

--- @brief
function rt.SceneManager:instantiate()
    require "common.game_state"
    self._width, self._height = rt.GameState:get_internal_resolution()

    meta.install(self, {
        _scene_type_to_scene = {},
        _scene_stack = {},
        _scene_stack_queue = {},

        _use_fixed_timestep = false,
        _last_update_timestamp = love.timer.getTime(),

        _start_time = love.timer.getTime(),
        _elapsed = 0,

        _bloom = nil, -- initialized on first use
        _hdr = nil, -- ^
        _input = rt.InputSubscriber(),

        _screen_recorder = rt.ScreenRecorder, -- sic, no (), singleton instance

        _is_cursor_visible = false,
        _cursor = rt.Cursor(),

        _composition_overlay_visible = false,

        _frame_i = 0,
        _frame_timestamp = love.timer.getTime(),

        _update_use_fixed_timestep = true,
        _update_fixed_fps = 120,
        _update_accumulator = 0,

        _draw_use_fixed_timestep = false,
        _draw_fixed_fps = 60,
        _draw_accumulator = 0,
        _draw_interpolation_time = 0,
    })

    self:set_use_fixed_timestep(self._update_use_fixed_timestep)
    self:set_use_fixed_fps(self._draw_use_fixed_timestep)

    self._fade = rt.Fade()
    self._fade:set_duration(rt.settings.scene_manager.fade_duration)
    self._lag_frame_active = true -- prevent lag frames influencing fade duration

    -- register push / pop / set_scene actions to be ran through when fade completes
    self._fade:signal_connect("hidden", function()
        if #self._scene_stack_queue > 0 then
            self:_reset() -- reset light map / bloom because scene changed

            for _, entry in ipairs(self._scene_stack_queue) do
                local f = entry[1]
                local vararg = entry[2]
                if vararg ~= nil then
                    f(table.unpack(vararg))
                else
                    f()
                end
            end

            self._scene_stack_queue = {}
            self._lag_frame_active = true
        end
    end)

    -- init performance metrics
    local n_samples = rt.settings.scene_manager.performance_metrics_n_samples

    self._update_samples = {}
    self._draw_samples = {}
    self._fps_samples = {}

    local now = love.timer.getTime()
    table.insert(self._update_samples, {
        timestamp = now,
        value = 0
    })

    table.insert(self._draw_samples, {
        timestamp = now,
        value = 0
    })

    table.insert(self._fps_samples, {
        timestamp = now,
        value = 60
    })

    self._draw_instants = {}
end

--- @brief
function rt.SceneManager:_reformat_scene(scene)
    -- resize first time or if necessary
    local current_w, current_h = scene._scene_manager_current_width, scene._scene_manager_current_height
    if current_w == nil or current_w ~= self._width or current_h == nil or current_h ~= self._height then
        scene:reformat(0, 0, self._width, self._height)
        scene._scene_manager_current_width = self._width
        scene._scene_manager_current_height = self._height
        scene:signal_emit("resize", 0, 0, self._width, self._height)
    end
end

--- @brief
function rt.SceneManager:preallocate(scene_type)
    meta.assert(scene_type, meta.Type)
    local scene = self._scene_type_to_scene[scene_type]
    if scene == nil then
        scene = scene_type(rt.GameState)

        -- store stashed scene instance, one per type
        self._scene_type_to_scene[scene_type] = scene

        scene:realize()
        self:_reformat_scene(scene)
    end
end

--- @brief
function rt.SceneManager:_get_instance(scene_type)
    local instance = self._scene_type_to_scene[scene_type]
    if instance == nil then
        self:preallocate(scene_type)
        instance = self._scene_type_to_scene[scene_type] -- create by preallocate
    end

    instance:realize()
    self:_reformat_scene(instance)
    return instance
end

--- @brief
function rt.SceneManager:_exit_scene(scene)
    scene:update(0)
    scene:exit()
    scene:signal_emit("exit")
end

--- @brief
function rt.SceneManager:_enter_scene(add_to_stack, scene, scene_type, ...)
    meta.assert(add_to_stack, mt.Boolean)

    scene:enter(...)
    scene:signal_emit("enter")

    -- delay push to after enter, so `get_is_active` returns correct value
    if add_to_stack == true then
        table.insert(self._scene_stack, 1, {
            scene = scene,
            type = scene_type,
            vararg = { ... }
        })
    end

    scene:update(0)
end

--- @brief
function rt.SceneManager:_reset()
    for object in range(
        self:get_bloom(),
        self:get_light_map()
    ) do
        if meta.is_function(object.reset) then
            object:reset()
        end
    end

    rt.InputManager:flush() -- prevent input from this frame leaking into new scene
end

--- @brief
function rt.SceneManager:set_scene(scene_type, ...)
    rt.assert(meta.isa(scene_type, meta.Type)
        and meta.is_subtype(scene_type, rt.Scene),
        "In rt.SceneManager.set_scene: object `", scene_type, "` is not a meta.Type or does not inherit from rt.Scene"
    )

    table.insert(self._scene_stack_queue, { function(...)
        -- replace the top node
        local current_node = self._scene_stack[1]
        if current_node ~= nil then
            self:_exit_scene(current_node.scene)
            table.remove(self._scene_stack, 1)
        end

        local instance = self:_get_instance(scene_type)
        self:_enter_scene(true, instance, scene_type, ...)
    end, { ... }})

    self._fade:start()
end

--- @brief
function rt.SceneManager:push(scene_type, ...)
    rt.assert(meta.isa(scene_type, meta.Type)
        and meta.is_subtype(scene_type, rt.Scene),
        "In rt.SceneManager.push: object `", scene_type, "` is not a meta.Type or does not inherit from rt.Scene"
    )

    table.insert(self._scene_stack_queue, { function(...)
        -- keep top node, but exit
        local current_node = self._scene_stack[1]
        if current_node ~= nil then
            self:_exit_scene(current_node.scene)
        end

        -- add new top node
        local instance = self:_get_instance(scene_type)
        self:_enter_scene(true, instance, scene_type, ...)
    end, { ... } }) -- capture varag

    self._fade:start()
end

--- @brief
function rt.SceneManager:pop()
    if #self._scene_stack == 0 then return end

    table.insert(self._scene_stack_queue, { function(...)
        local current_node = self._scene_stack[1]
        if current_node ~= nil then
            self:_exit_scene(current_node.scene)
            table.remove(self._scene_stack, 1)
        end

        local next_node = self._scene_stack[1]
        if next_node ~= nil then
            self:_enter_scene(false,
                next_node.scene,
                next_node.type,
                table.unpack(next_node.vararg)
            )
        end
    end, {}})

    self._fade:start()
end

do
    local _last_frame_time = love.timer.getTime()

    --- @brief
    function rt.SceneManager:update(delta)
        -- check if resize is necessary
        local width, height = rt.GameState:get_internal_resolution()
        if self._width ~= width or self._height ~= height then
            self:resize()
        end

        local current_scene = self:get_current_scene()
        if current_scene ~= nil then
            current_scene:update(delta)
        end

        self._elapsed = self._elapsed + delta

        rt.RoutineManager:step()
        rt.GameState:update(delta)
        rt.InputManager:update(delta)

        -- use stable fps to avoid lag frames skipping fade animation
        local now = love.timer.getTime()
        self._fade:update(now - _last_frame_time)
        _last_frame_time = now
    end
end

--- @brief
function rt.SceneManager:draw(...)
    local use_upscaler = rt.GameState:get_is_hdr_enabled()
        or rt.GameState:get_internal_resolution_scaling() ~= rt.InternalResolutionScaling.NONE

    if use_upscaler then
        self._hdr:bind()
    end

    love.graphics.clear(true, true, true)

    local current_scene = self:get_current_scene()
    if current_scene ~= nil then
        current_scene:draw(...)
    end

    self._fade:draw()

    if self._composition_overlay_visible then
        local width = love.graphics.getWidth()
        local height = love.graphics.getHeight()
        local m = 2 * rt.SceneManager:get_margin_unit()

        -- thirds
        love.graphics.setColor(1, 1, 1, 0.75)
        for i = 1, 2 do
            local x = width * (i / 3)
            love.graphics.line(x, 0, x, height)

            local y = height * (i / 3)
            love.graphics.line(0, y, width, y)
        end

        -- halves
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.line(0.5 * width, 0, 0.5 * width, height)
        love.graphics.line(0, 0.5 * height, width, 0.5 * height)

        -- margin
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.line(m, 0, m, height)
        love.graphics.line(width - m, 0, width - m, height)
        love.graphics.line(0, m, width, m)
        love.graphics.line(0, height - m, width, height - m)
    end

    rt.graphics._stencil_value = 1 -- reset running stencil value

    if self._lag_frame_active == true then
        love.graphics.clear(true, false, false)
    end

    if use_upscaler then
        self._hdr:unbind()
        self._hdr:draw()
    end

    if self._is_cursor_visible then
        self._cursor:draw()
    end
end

--- @brief
function rt.SceneManager:resize(_)
    meta.assert(_, mt.Nil)

    self._width, self._height = rt.GameState:get_internal_resolution()

    if self._bloom == nil
        or self._bloom:get_width() ~= self._width
        or self._bloom:get_height() ~= self._height
    then
        require "overworld.stage"
        self._bloom = rt.Bloom(
            self._width,
            self._height,
            rt.settings.overworld.stage.visible_area_padding
        )
    end

    if self._light_map == nil
        or self._light_map:get_width() ~= self._width
        or self._light_map:get_height() ~= self._height
    then
        require "overworld.light_map"
        self._light_map = ow.LightMap(
            self._width,
            self._height
        )
    end

    if self._hdr == nil
        or self._hdr:get_width() ~= self._width
        or self._hdr:get_height() ~= self._height
        or self._hdr:get_msaa() ~= rt.GameState:get_msaa()
    then
        if self._hdr == nil then
            self._hdr = rt.HDR(self._width, self._height)
        else
            self._hdr:reinitialize(self._width, self._height)
        end
    end

    local current_scene = self:get_current_scene()
    if current_scene ~= nil then
        self:_reformat_scene(current_scene)
    end
end

--- @brief
function rt.SceneManager:get_previous_scene()
    local entry = self._scene_stack[2]
    if entry ~= nil then
        return entry.scene
    end
end

--- @brief
function rt.SceneManager:get_current_scene()
    local node = self._scene_stack[1]
    if node == nil then return nil end
    return node.scene
end

--- @brief
function rt.SceneManager:get_frame_index()
    return self._frame_i
end

--- @brief
function rt.SceneManager:get_frame_duration()
    return love.timer.getTime() - self._frame_timestamp
end

--- @brief
function rt.SceneManager:get_elapsed()
    return self._elapsed --math.fmod(love.timer.getTime() - self._start_time, 12 * 3600) -- 12h
end

--- @brief
function rt.SceneManager:set_use_fixed_timestep(b, target)
    self._update_use_fixed_timestep = b
    if target ~= nil then self._update_fixed_fps = target end
end

--- @brief
function rt.SceneManager:get_use_fixed_timestep()
    return self._update_use_fixed_timestep
end

--- @brief
function rt.SceneManager:set_use_fixed_fps(b, target)
    self._draw_use_fixed_timestep = b
    if target ~= nil then self._draw_fixed_fps = target end
end

--- @brief
function rt.SceneManager:get_use_fixed_fps()
    return self._draw_use_fixed_timestep
end

--- @brief
function rt.SceneManager:get_timestep()
    if self._update_use_fixed_timestep then return 1 / self._update_fixed_fps else return 1 / love.timer.getFPS() end
end

--- @brief
function rt.SceneManager:get_frame_interpolation()
    if self._use_fixed_timestep then
        return self._update_accumulator / (1 / self._update_fixed_fps)
    else
        return 1
    end
end

--- @brief
function rt.SceneManager:get_width()
    return self._width
end

--- @brief
function rt.SceneManager:get_height()
    return self._height
end

--- @brief
function rt.SceneManager:get_size()
    return self._width, self._height
end

--- @brief
function rt.SceneManager:get_pixel_scale()
    return love.graphics.getHeight() / rt.settings.native_height
end

--- @brief
function rt.SceneManager:get_margin_unit()
    return 10  / self:get_downscaling_factor()
end

--- @brief
function rt.SceneManager:get_downscaling_factor()
    return love.graphics.getHeight() / self._height
end

--- @brief
function rt.SceneManager:_notify_update_duration(duration)
    table.insert(self._update_samples, {
        timestamp = love.timer.getTime(),
        value = duration
    })
end

--- @brief
--- @brief
function rt.SceneManager:_notify_draw_duration(duration)
    local now = love.timer.getTime()

    table.insert(self._draw_samples, {
        timestamp = now,
        value = duration
    })

    table.insert(self._draw_instants, now)

    local threshold = now - 1 -- last second
    local stale_count = 0

    for i = 1, #self._draw_instants do
        if self._draw_instants[i] >= threshold then
            stale_count = i - 1
            break
        end
    end

    if stale_count > 0 then
        local valid_count = #self._draw_instants - stale_count

        for i = 1, valid_count do
            self._draw_instants[i] = self._draw_instants[i + stale_count]
        end

        for i = valid_count + 1, #self._draw_instants do
            self._draw_instants[i] = nil
        end
    end

    table.insert(self._fps_samples, {
        timestamp = now,
        value = #self._draw_instants
    })
end

local _default_font = love.graphics.getFont()

--- @brief
function rt.SceneManager:draw_debug_information(draw)
    local threshold = love.timer.getTime() - rt.settings.scene_manager.performance_metrics_interval

    local update_samples = function(t)
        local max = -math.huge
        local sum = 0
        local to_remove = {}
        for i, entry in ipairs(t) do
            if entry.timestamp < threshold then
                table.insert(to_remove, 1, i)
            else
                max = math.max(max, entry.value)
                sum = sum + entry.value
            end
        end

        for i in values(to_remove) do
            table.remove(t, i)
        end

        return #t > 0 and sum / #t or 0, max
    end

    local update_mean, update_max
    local draw_mean, draw_max
    local fps_mean, _ = update_samples(self._fps_samples)

    if #self._update_samples == 0 then
        update_mean, update_max = 0, 0
    else
        update_mean, update_max = update_samples(self._update_samples)
    end

    if #self._draw_samples == 0 then
        draw_mean, draw_max = 0, 0
    else
        draw_mean, draw_max = update_samples(self._draw_samples)
    end

    if rt.GameState:get_draw_debug_information() then
        love.graphics.reset()

        local fps_variance = 0
        for entry in values(self._fps_samples) do
            fps_variance = fps_variance + (entry.value - fps_mean)^2
        end
        fps_variance = math.sqrt(fps_variance / #self._fps_samples)

        local stats = love.graphics.getStats()
        local n_draws = tostring(stats.drawcalls)
        while #n_draws < 3 do n_draws = "0" .. n_draws end

        local gpu_side_memory = math.ceil(stats.texturememory / 1024 / 1024) -- in mb

        local to_percent = function(seconds)
            return math.ceil(seconds / (1 / 60) * 100)
        end

        local format = function(value)
            local str = tostring(value)
            while #str < 3 do
                str = "0" .. str
            end
            return str
        end

        local right = table.concat({
            format(math.round(fps_mean)), " fps \u{00B1} " .. format(math.round(fps_variance)) .. " | ",
            format(to_percent(update_mean)), " (", format(to_percent(update_max)), ") % | ",
            format(to_percent(draw_mean)), " (", format(to_percent(draw_max)), ") % | ",
            n_draws, " draws | ",
            gpu_side_memory, " mb "
        })

        love.graphics.setFont(_default_font)
        local str_width = _default_font:getWidth(right)

        local margin = 5
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(right, love.graphics.getWidth() - str_width - margin, margin, math.huge)

        local current_scene = self:get_current_scene()
        if current_scene ~= nil then
            local left = current_scene:get_debug_information() or ""
            love.graphics.printf(left, margin * 2, margin, math.huge)
        end
    end
end

--- @brief
function rt.SceneManager:get_bloom()
    if rt.GameState:get_is_bloom_enabled() then
        if self._bloom == nil then
            require "overworld.stage"
            self._bloom = rt.Bloom(
                self._width,
                self._height,
                rt.settings.overworld.stage.visible_area_padding
            )
        end
        return self._bloom
    else
        return nil
    end
end

--- @brief
function rt.SceneManager:get_light_map()
    if self._light_map == nil then
        require "overworld.light_map"
        self._light_map = ow.LightMap(
            self._width,
            self._height
        )
    end
    return self._light_map
end

--- @brief
function rt.SceneManager:get_hdr()
    if self._hdr == nil then
        self._hdr = rt.HDR(self._width, self._height)
    end
    return self._hdr
end

--- @brief
function rt.SceneManager:get_screen_recorder()
    return self._screen_recorder
end

--- @brief
function rt.SceneManager:set_is_cursor_visible(b)
    self._is_cursor_visible = b
end

--- @brief
function rt.SceneManager:get_is_cursor_visible()
    return self._is_cursor_visible
end

--- @brief
function rt.SceneManager:set_cursor_type(type)
    self._cursor:set_type(type)
end

--- @brief
function rt.SceneManager:get_cursor_type()
    return self._cursor:get_type()
end

--- @brief check whether scene is on scene stack
function rt.SceneManager:scene_get_is_active(scene)
    for _, entry in ipairs(self._scene_stack) do
        if entry.scene == scene then
            return true
        end
    end

    return false
end

rt.SceneManager = meta.as_singleton(rt.SceneManager)

love.quit = function()
    local temp = bd.get_temp_directory_name()
    if bd.is_directory(temp) then
        -- make sure temp is in appdata, not mounted
        pcall(bd.unmount_path, temp)

        -- try delete
        local success, error = pcall(bd.remove_directory, temp)

        local path = bd.get_temp_directory()
        if success then
            rt.log("In love.quit: succesfully deleted folder at `", path, "`")
        else
            rt.critical("In love.quit: unable to delete folder at `", path, "`: ", error)
        end
    end
end

local _should_draw = true

love.run = function()
    love.mouse.setVisible(false)
    love.mouse.setGrabbed(false)

    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    arg = nil

    if love.timer then love.timer.step() end

    local was_active = love.graphics.isActive() and love.window.hasFocus()
    return function()
        if PROFILE then profiler.push("love.run") end

        -- performance metrics
        local state = rt.SceneManager

        -- get events
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "quit" then
                if love.quit then love.quit() end
                return a or 0 -- for restart
            end
            love.handlers[name](a, b, c, d, e, f)
        end

        -- frame timestamp for total frame time measurement
        state._frame_timestamp = love.timer.getTime()

        local delta = love.timer.step()

        local is_active = love.graphics.isActive() and love.window.hasFocus()

        -- ### UPDATE ###

        if PROFILE then
            profiler.push("love.update")
        end

        local skip_update = false
        if was_active == false and is_active == true then
            state._update_accumulator = 0
            skip_update = true
            -- skip on window gaining focus, since `delta` can be very large in that case
        end

        if not skip_update then
            state._update_accumulator = state._update_accumulator + delta

            if state._update_use_fixed_timestep then
                local n_steps = 0
                local step = 1 / state._update_fixed_fps

                local before = love.timer.getTime() -- sic, time whole while loop
                while state._update_accumulator >= step do

                    if love.update then
                        love.update(step)
                        _should_draw = true
                    end

                    state._update_accumulator = state._update_accumulator - step
                    n_steps = n_steps + 1
                    if n_steps > rt.settings.scene_manager.max_n_steps_per_frame then
                        state._update_accumulator = 0
                        break
                    end
                end
                state:_notify_update_duration(love.timer.getTime() - before)
            else
                local before = love.timer.getTime()
                if love.update then
                    love.update(delta)
                    _should_draw = true
                end
                state:_notify_update_duration(love.timer.getTime() - before)
            end

            rt.InputManager:_notify_end_of_frame()

            state._last_update_timestamp = love.timer.getTime()
        end

        if PROFILE then profiler.pop("love.update") end

        -- ### SOUND ###

        rt.SoundManager:update(delta)
        rt.MusicManager:update(delta)

        was_active = is_active

        -- ### DRAW ###

        state._draw_accumulator = state._draw_accumulator + delta
        state._draw_interpolation_time = love.timer.getTime() - state._last_update_timestamp

        local drawn = false

        local draw = function()
            local before = love.timer.getTime()

            if PROFILE then profiler.push("love.draw") end
            if love.draw ~= nil then love.draw() end
            if PROFILE then profiler.pop("love.draw") end

            state:_notify_draw_duration(love.timer.getTime() - before)
        end

        if state._draw_use_fixed_timestep then
            local n_steps = 0
            local step = 1 / state._draw_fixed_fps
            while state._draw_accumulator >= step do
                state._screen_recorder:bind()
                draw()
                drawn = true
                state._screen_recorder:unbind()
                state._screen_recorder:notify_end_of_frame()

                state._draw_accumulator = state._draw_accumulator - step

                n_steps = n_steps + 1
                if n_steps > rt.settings.scene_manager.max_n_steps_per_frame then
                    state._draw_accumulator = 0
                    break
                end
            end

            if drawn then
                state._screen_recorder:draw() -- update main framebuffer
            end
        elseif _should_draw then
            draw()
            drawn = true
        end

        rt.SceneManager:draw_debug_information() -- automatically checks for draw_debug_information flag

        if drawn then
            love.graphics.present()
            state._frame_i = state._frame_i + 1
            state._lag_frame_active = false
            _should_draw = false
        end

        -- safeguard when vsync is off to avoid burning 100% CPU
        love.timer.sleep(1 / rt.settings.scene_manager.fps_limit)

        if PROFILE then profiler.pop("love.run") end
    end
end

return rt.SceneManager