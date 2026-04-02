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
    fps_limit = 1000,

    draw_instance_count_interval = 5 -- seconds
}

--- @class SceneManager
rt.SceneManager = meta.class("SceneManager")

--- @brief restart the game
_G.restart = function()
    rt.SceneManager._restart_active = true
    rt.ThreadManager:request_shutdown()
end

_G._exit = _G.exit

--- @brief shutdown runtime
_G.exit = function(status)
    _G._exit(status)
end

--- @brief
function rt.SceneManager:instantiate()
    meta.install(self, {
        _scene_type_to_scene = {},
        _current_scene = nil,
        _current_scene_type = nil,
        _current_scene_varargs = {},
        _schedule_enter = false,

        _scene_stack = {}, -- Stack<SceneType>
        _width = love.graphics.getWidth(),
        _height = love.graphics.getHeight(),
        _fade = rt.Fade(),
        _should_use_fade = false,
        _use_fixed_timestep = false,

        _start_time = love.timer.getTime();

        _bloom = nil, -- initialized on first use
        _hdr = nil, -- ^
        _input = rt.InputSubscriber(),

        _screen_recorder = rt.ScreenRecorder, -- sic, no (), singleton instance

        _cursor_visible = false,
        _cursor = rt.Cursor(),

        _pause_on_focus_lost = true,

        _restart_active = false,

        -- love.run variables
        _ignore_next_step = false,
        _frame_i = 0,
        _frame_timestamp = love.timer.getTime(),

        _update_use_fixed_timestep = true,
        _update_fixed_fps = 120,
        _update_accumulator = 0,

        _draw_use_fixed_timestep = false,
        _draw_fixed_fps = 5,
        _draw_accumulator = 0,

        _n_draws = 0,
        _draw_start = love.timer.getTime(),

        _draw_interpolation_time = 0,

        _sound_manager_use_fixed_timestep = true,
        _sound_manager_fixed_fps = 240,
        _sound_manager_accumulator = 0,

        _is_focused = true,
        _composition_overlay_visible = false
    })

    self:set_use_fixed_timestep(self._update_use_fixed_timestep)
    self:set_use_fixed_fps(self._draw_use_fixed_timestep)

    self._fade:set_duration(rt.settings.scene_manager.fade_duration)

    -- performance
    local n_samples = 1000

    local timestep = 1 / self._update_fixed_fps
    self._update_durations = table.rep(timestep, n_samples)
    self._update_sum = n_samples * timestep

    timestep = 1 / self._draw_fixed_fps
    self._draw_durations = table.rep(timestep, n_samples)
    self._draw_sum = n_samples * timestep

    self._draw_instants = {}
    self._fps_samples = table.rep(self._draw_fixed_fps, n_samples)
    self._fps_sum = n_samples * self._draw_fixed_fps
end

--- @brief
function rt.SceneManager:_reformat_scene(scene)
    -- resize first time or if necessary
    local current_w, current_h = scene._scene_manager_current_width, scene._scene_manager_current_height
    if current_w ~= self._width or current_h ~= self._height then
        scene:reformat(0, 0, self._width, self._height)
        scene._scene_manager_current_width = self._width
        scene._scene_manager_current_height = self._height
        scene:signal_emit("resize", 0, 0, self._width, self._height)
    end
end

--- @brief
function rt.SceneManager:preallocate(scene_type, ...)
    local scene = self._scene_type_to_scene[scene_type]
    if scene == nil then
        scene = scene_type(rt.GameState)
        scene:realize()
        self._scene_type_to_scene[scene_type] = scene
        self:_reformat_scene(scene)
    end
end

--- @brief
function rt.SceneManager:_set_scene(add_to_stack, scene_type, ...)
    local use_fade = self._should_use_fade
    self:preallocate(scene_type, ...)

    local varargs = { ... }
    local on_scene_changed = function()
        local scene = self._scene_type_to_scene[scene_type]
        if add_to_stack == true and self._current_scene ~= nil then
            table.insert(self._scene_stack, 1, {
                self._current_scene_type,
                table.unpack(self._current_scene_varargs)
            })
        end

        local previous_scene = self._current_scene

        self._current_scene = scene
        self._current_scene_type = scene_type
        self._current_scene_varargs = varargs

        if previous_scene ~= nil then
            previous_scene:exit()
            previous_scene._is_active = false
            previous_scene:signal_emit("exit")

            if rt.GameState:get_is_bloom_enabled() then
                local bloom = self:get_bloom()
                bloom:bind()
                love.graphics.clear(0, 0, 0, 0)
                bloom:unbind()
            end
        end

        self:_reformat_scene(self._current_scene)
        self._schedule_enter = true -- delay enter until next frame to avoid same-frame inputs
    end

    if self._current_scene == nil or use_fade == false then -- don't fade at start of game
        on_scene_changed()
    else
        self._fade:signal_connect("hidden", function()
            on_scene_changed()
            return meta.DISCONNECT_SIGNAL
        end)
        self._fade:start()
    end
end

--- @brief
function rt.SceneManager:push(scene_type, ...)
    rt.assert(scene_type ~= nil, "In rt.SceneManager: scene type cannot be nil")
    if self._current_scene_type ~= scene_type then
        self:_set_scene(true, scene_type, ...)
    else
        self:_set_scene(false, scene_type, ...)
    end
end

--- @brief
function rt.SceneManager:pop(...)
    local last = self._scene_stack[1]
    if last ~= nil then
        table.remove(self._scene_stack, 1)
        self:_set_scene(false, last[1], ...) --table.unpack(last))
    end
end

--- @brief
function rt.SceneManager:set_scene(scene_type, ...)
    self:_set_scene(false, scene_type, ...)
end

--- @brief
function rt.SceneManager:set_use_fade(b)
    self._should_use_fade = b
end

--- @brief
function rt.SceneManager:update(delta)
    if self._restart_active == true then
        if rt.ThreadManager:get_is_shutdown() then
            self._restart_active = false
            love.event.restart()
            return
        end
    end

    rt.GameState:update(delta)
    rt.InputManager:update(delta)

    self._fade:update(delta)
    if self._current_scene ~= nil then
        if self._schedule_enter then
            self._schedule_enter = false
            self._current_scene:enter(table.unpack(self._current_scene_varargs))
            self._current_scene._is_active = true
            self._current_scene:signal_emit("enter")
        end
        self._current_scene:update(delta)
        self._current_scene:signal_emit("update", delta)
    end
end

--- @brief
function rt.SceneManager:draw(...)
    local use_hdr = rt.GameState:get_is_hdr_enabled()
    
    if use_hdr then
        if self._hdr == nil then self._hdr = rt.HDR() end
        self._hdr:bind()
        love.graphics.clear(0, 0, 0, 0)
    end

    if self._current_scene ~= nil then
        self._current_scene:draw(...)
    end

    if self._composition_overlay_visible then
        local width = love.graphics.getWidth()
        local height = love.graphics.getHeight()
        local m = 2 * rt.settings.margin_unit

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

    if self._should_use_fade then
        self._fade:draw()
    end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    if use_hdr then
        self._hdr:unbind()
        self._hdr:draw()

        --[[
        if self._current_scene ~= nil then
            self._current_scene:draw(...)
        end

        local value = 243
        rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
        love.graphics.rectangle("fill", 0, 0, 0.5 * love.graphics.getWidth(), love.graphics.getHeight())
        rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)
        self._hdr:draw()
        rt.graphics.set_stencil_mode(nil)
        ]]
    end

    if self._cursor_visible then
        self._cursor:draw()
    end
end

--- @brief
function rt.SceneManager:resize(width, height)
    rt.assert(type(width) == "number" and type(height) == "number")

    self._width = width
    self._height = height

    if rt.GameState:get_is_hdr_enabled() then
        if self._hdr == nil then
            self._hdr = rt.HDR()
        end
        self._hdr:reinitialize(width, height)
    end

    rt.settings.margin_unit = 10 * rt.get_pixel_scale()

    local scene = self._current_scene
    if scene ~= nil then
        local current_w, current_h = scene._scene_manager_current_width, scene._scene_manager_current_height
        if current_w ~= self._width or current_w ~= self._height then
            self:_reformat_scene(scene)
            scene._scene_manager_current_width = self._width
            scene._scene_manager_current_height = self._height
        end
    end

    local reallocate_bloom = false
    if self._bloom == nil then
        reallocate_bloom = true
    else
        local w, h = self._bloom:get_size()
        if w ~= self._width or h ~= self._height then
            reallocate_bloom = true
        end
    end

    if reallocate_bloom then
        self:_reallocate_bloom()
    end

    local reallocate_light_map = false
    if self._light_map == nil then
        reallocate_light_map = true
    else
        local w, h = self._light_map:get_size()
        if w ~= self._width or h ~= self._height then
            reallocate_light_map = true
        end
    end

    if reallocate_light_map then
        self:_reallocate_light_map()
    end
end

--- @brief
function rt.SceneManager:get_previous_scene()
    return self._previous_scene_type
end

--- @brief
function rt.SceneManager:get_current_scene()
    return self._current_scene
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
    return math.fmod(love.timer.getTime() - self._start_time, 12 * 3600) -- 12h
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
function rt.SceneManager:set_pause_on_focus_lost(b)
    self._pause_on_focus_lost = b
end

--- @brief
function rt.SceneManager:get_pause_on_focus_lost()
    return self._pause_on_focus_lost
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
function rt.SceneManager:_notify_update_duration(duration)
    local first, last = self._update_durations[1], duration
    self._update_sum = self._update_sum - first + last
    table.remove(self._update_durations, 1)
    table.insert(self._update_durations, duration)
end

--- @brief
function rt.SceneManager:_notify_draw_duration(duration)
    local first, last = self._draw_durations[1], duration
    self._draw_sum = self._draw_sum - first + last

    table.remove(self._draw_durations, 1)
    table.insert(self._draw_durations, duration)
    table.insert(self._draw_instants, love.timer.getTime())
end

local _default_font = love.graphics.getFont()

--- @brief
function rt.SceneManager:_draw_performance_metrics()
    local update_mean = self._update_sum / #self._update_durations
    local draw_mean = self._draw_sum / #self._draw_durations

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

    do
        local draw_instant_interval = rt.settings.scene_manager.draw_instance_count_interval
        local cutoff = love.timer.getTime() - draw_instant_interval
        local first_valid = 1
        for i = 1, #self._draw_instants do
            if self._draw_instants[i] >= cutoff then
                for j = 1, i - 1 do
                    table.remove(self._draw_instants, 1)
                end
                break
            end
        end

        local fps = #self._draw_instants / draw_instant_interval
        local first, last = self._fps_samples[1], fps
        self._fps_sum = self._fps_sum - first + last
        table.remove(self._fps_samples, 1)
        table.insert(self._fps_samples, fps)
    end

    local fps_mean = self._fps_sum / #self._fps_samples

    local fps_variance = 0
    for _, value in ipairs(self._fps_samples) do
        fps_variance = fps_variance + (value - fps_mean)^2
    end
    fps_variance = fps_variance / #self._fps_samples

    local str = table.concat({
        format(math.ceil(fps_mean)), " fps \u{00B1} " .. format(math.ceil(fps_variance)) .. " | ",
        format(math.ceil(to_percent(update_mean))), "% | ",
        format(math.ceil(to_percent(draw_mean))), "% | ",
        n_draws, " draws | ",
        gpu_side_memory, " mb "
    })

    love.graphics.setFont(_default_font)
    local str_width = _default_font:getWidth(str)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(str, love.graphics.getWidth() - str_width - 5, 5, math.huge)
end

--- @brief
function rt.SceneManager:_reallocate_bloom()
    require "common.bloom"
    self._bloom = rt.Bloom(
        self._width,
        self._height,
        rt.settings.overworld.stage.visible_area_padding
    )
end

--- @brief
function rt.SceneManager:get_bloom()
    if rt.GameState:get_is_bloom_enabled() then
        if self._bloom == nil then
            self:_reallocate_bloom()
        end
        return self._bloom
    else
        return nil
    end
end

--- @brief
function rt.SceneManager:_reallocate_light_map()
    require "overworld.light_map"
    self._light_map = ow.LightMap(
        self._width,
        self._height
    )
end

--- @brief
function rt.SceneManager:get_light_map()
    if self._light_map == nil then
        self:_reallocate_light_map()
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
    self._cursor_visible = b
end

--- @brief
function rt.SceneManager:get_is_cursor_visible()
    return self._cursor_visible
end

--- @brief
function rt.SceneManager:set_cursor_type(type)
    self._cursor:set_type(type)
end

--- @brief
function rt.SceneManager:get_cursor_type()
    return self._cursor:get_type()
end

rt.SceneManager = rt.SceneManager() -- static global singleton

love.focus = function(b)
    if rt.SceneManager._is_focused == false and b == true then
        rt.SceneManager._ignore_next_step = true
    end

    rt.SceneManager._is_focused = b
end

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

love.run = function()
    love.mouse.setVisible(false)
    love.mouse.setGrabbed(false)

    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    arg = nil

    if love.timer then love.timer.step() end

    return function()
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

        -- ### UPDATE ###

        state._update_accumulator = state._update_accumulator + delta

        if state._update_use_fixed_timestep then
            local n_steps = 0
            local step = 1 / state._update_fixed_fps

            local before = love.timer.getTime() -- sic, time whole while loop
            while state._update_accumulator >= step do

                if love.update then love.update(step) end

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
            if love.update then love.update(delta) end
            state:_notify_update_duration(love.timer.getTime() - before)
        end

        state._last_update_timestamp = love.timer.getTime()

        -- ### SOUND ###

        state._sound_manager_accumulator = state._sound_manager_accumulator + delta

        if state._sound_manager_use_fixed_timestep then
            local step = 1 / state._sound_manager_fixed_fps
            while state._sound_manager_accumulator >= step do
                rt.SoundManager:update(step)
                state._sound_manager_accumulator = state._sound_manager_accumulator - step
            end
        else
            rt.SoundManager:update(delta)
        end

        -- ### DRAW ###

        state._draw_accumulator = state._draw_accumulator + delta
        state._draw_interpolation_time = love.timer.getTime() - state._last_update_timestamp

        local drawn = false

        local draw = function()
            local before = love.timer.getTime()
            if love.draw ~= nil then love.draw() end
            state:_notify_draw_duration(love.timer.getTime() - before)
        end

        if love.keyboard.isDown("space") then --state._draw_use_fixed_timestep then
            local step = 1 / state._draw_fixed_fps
            while state._draw_accumulator >= step do
                state._screen_recorder:bind()
                draw()
                drawn = true
                state._screen_recorder:unbind()
                state._screen_recorder:notify_end_of_frame()

                state._draw_accumulator = state._draw_accumulator - step
            end

            if drawn then
                state._screen_recorder:draw()
            end
        else
            draw()
            drawn = true
        end

        if rt.GameState:get_draw_debug_information() then
            love.graphics.origin()
            rt.SceneManager:_draw_performance_metrics()
        end

        if drawn then
            love.graphics.present()
        end

        state._frame_i = state._frame_i + 1

        -- safeguard when vsync is off to avoid burning 100% CPU
        love.timer.sleep(1 / 1000)
    end
end

require "common.error_handler"

return rt.SceneManager