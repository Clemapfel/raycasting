require "common.scene"
require "common.input_subscriber"
require "common.fade"
require "common.palette"
require "common.cursor"
require "common.thread_manager"
require "common.bloom"
require "common.hdr"

rt.settings.scene_manager = {
    max_n_steps_per_frame = 8,
    performance_metrics_n_frames = 144,
    fade_duration = 0.2,
    fps_limit = 1000
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

        _bloom = nil, -- initialized on first use
        _hdr = nil, -- ^
        _input = rt.InputSubscriber(),

        _cursor_visible = false,
        _cursor = rt.Cursor(),

        _restart_active = false,

        -- love.run variables
        _ignore_next_step = false,
        _frame_i = 0,
        _elapsed = 0,
        _frame_timestamp = love.timer.getTime(),

        _accumulator = 0,
        _step = 1 / 120,

        _sound_manager_accumulator = 0,
        _sound_manager_step = 1 / 240,

        _is_focused = true,
        _composition_overlay_visible = false
    })

    -- performance metrics
    local n = rt.settings.scene_manager.performance_metrics_n_frames
    self._update_fractions = table.rep(0, n)
    self._update_sum = 0
    self._update_max = 0
    self._draw_fractions = table.rep(0, n)
    self._draw_sum = 0
    self._draw_max = 0
    self._frame_durations = table.rep(1 / 60, n)
    self._frame_sum = (1 / 60) * n
    self._frame_max = 1 / 60

    self._fade:set_duration(rt.settings.scene_manager.fade_duration)
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
    return math.fmod(self._elapsed, 12 * 3600) -- 12h
end

--- @brief
function rt.SceneManager:set_use_fixed_timestep(b)
    self._use_fixed_timestep = b
end

--- @brief
function rt.SceneManager:get_use_fixed_timestep()
    return self._use_fixed_timestep
end

--- @brief
function rt.SceneManager:get_timestep()
    if self._use_fixed_timestep then return 1 / 120 else return 1 / love.timer.getFPS() end
end

--- @brief
function rt.SceneManager:get_frame_interpolation()
    if self._use_fixed_timestep then
        return self._accumulator / self._step
    else
        return 1
    end
end

--- @brief
function rt.SceneManager:_update_performance_metrics(update_duration, draw_duration, frame_duration)
    local update_fraction = update_duration / frame_duration
    local draw_fraction = draw_duration / frame_duration

    local find_max = function(t)
        local max = -math.huge
        for x in values(t) do max = math.max(max, x) end
        return max
    end

    local update_first = self._update_fractions[1]
    table.remove(self._update_fractions, 1)
    table.insert(self._update_fractions, update_fraction)
    self._update_sum = self._update_sum - update_first + update_fraction

    if self._update_max == update_first then
        self._update_max = find_max(self._update_fractions)
    end

    local draw_first = self._draw_fractions[1]
    table.remove(self._draw_fractions, 1)
    table.insert(self._draw_fractions, draw_fraction)
    self._draw_sum = self._draw_sum - draw_first + draw_fraction

    if self._draw_max == draw_first then
        self._draw_max = find_max(self._draw_fractions)
    end

    frame_duration = 1 / frame_duration -- fps
    local frame_first = self._frame_durations[1]
    table.remove(self._frame_durations, 1)
    table.insert(self._frame_durations, frame_duration)
    self._frame_sum = self._frame_sum - frame_first + frame_duration

    if self._frame_max == frame_first then
        self._frame_max = find_max(self._frame_durations)
    end
end

local _default_font = love.graphics.getFont()

--- @brief
function rt.SceneManager:_draw_performance_metrics()
    local update_mean = self._update_sum / #self._update_fractions
    local draw_mean = self._draw_sum / #self._draw_fractions
    local fps_mean = math.mean(self._frame_durations)
    local fps_variance = math.sqrt(math.variance(self._frame_durations))

    local update_max = self._update_max
    local draw_max = self._draw_max
    local fps_max = 1 / self._frame_max

    local stats = love.graphics.getStats()
    local n_draws = stats.drawcalls
    local gpu_side_memory = math.ceil(stats.texturememory / 1024 / 1024) -- in mb

    local format = function(value)
        local str = tostring(value)
        while #str < 3 do
            str = "0" .. str
        end
        return str
    end

    local str = table.concat({
        format(math.ceil(love.timer.getFPS())), " fps \u{00B1} " .. format(math.ceil(fps_variance)) .. " | ",
        format(math.ceil(update_mean * 100)), "% | ",
        format(math.ceil(draw_mean * 100)), "% | ",
        n_draws, " draws | ",
        gpu_side_memory, " mb "
    })

    love.graphics.setFont(_default_font)
    local str_width = _default_font:getWidth(str)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(str, love.graphics.getWidth() - str_width - 5, 5, math.huge)
end

--- @brief
function rt.SceneManager:get_is_bloom_enabled()
    return rt.GameState:get_is_bloom_enabled()
end

--- @brief
function rt.SceneManager:_reallocate_bloom()
    require "overworld.stage"
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

-- max uncapped fps
local _fps_limit = 1000

love.run = function()
    love.mouse.setVisible(false)
    love.mouse.setGrabbed(false)

    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    if love.timer then love.timer.step() end

    return function()
        -- performance metrics
        local frame_before, frame_fater, update_before, update_after, draw_before, draw_after

        local state = rt.SceneManager
        local current_scene = rt.SceneManager._current_scene

        -- get events
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "quit" then
                if love.quit then love.quit() end
                return a or 0 -- for restart
            end
            love.handlers[name](a, b, c, d, e, f)
        end

        state._frame_timestamp = love.timer.getTime()
        local delta = love.timer.step()

        update_before = love.timer.getTime()

        -- skip if window unfocused, prevent large delta after becoming active again
        local pause_on_focus_lost = current_scene == nil or current_scene:get_pause_on_focus_lost() == true
        if state._ignore_next_step == true or (not state._is_focused and pause_on_focus_lost) then
            state._ignore_next_step = false
            state._accumulator = 0
            goto skip_update
        end

        state._accumulator = state._accumulator + delta

        if rt.SceneManager._use_fixed_timestep then
            local n_steps = 0
            while state._accumulator >= state._step do
                if love.update then
                    love.update(state._step)
                end

                state._accumulator = state._accumulator - state._step

                n_steps = n_steps + 1
                if n_steps > rt.settings.scene_manager.max_n_steps_per_frame then
                    state._accumulator = 0
                    break -- safeguard against death spiral on lag frame
                end
            end
        else
            if love.update then
                love.update(delta)
            end
        end

        ::skip_update::

        update_after = love.timer.getTime()

        state._sound_manager_accumulator = state._sound_manager_accumulator + delta
        while state._sound_manager_accumulator >= state._sound_manager_step do
            rt.SoundManager:update(state._sound_manager_step)
            state._sound_manager_accumulator = state._sound_manager_accumulator - state._sound_manager_step
        end

        state._elapsed = state._elapsed + delta

        if love.graphics and love.graphics.isActive() then
            love.graphics.reset()
            love.graphics.clear(0, 0, 0, 0)

            draw_before = love.timer.getTime()
            if love.draw ~= nil then love.draw() end
            draw_after = love.timer.getTime()

            if rt.GameState:get_draw_debug_information() then
                love.graphics.push()
                love.graphics.origin()
                rt.SceneManager:_draw_performance_metrics()
                love.graphics.pop()
            end

            love.graphics.present()
        end

        rt.InputManager:_notify_end_of_frame()
        state._frame_i = state._frame_i + 1

        rt.SceneManager:_update_performance_metrics(
            update_after - update_before,
            draw_after - draw_before,
            love.timer.getTime() - state._frame_timestamp
        )

        love.timer.sleep(1 / _fps_limit) -- safeguard if vsync off
    end
end

function love.errorhandler(message)
    local traceback
    traceback = string.gsub(
        debug.traceback("Error in " .. tostring(message), 3),
        "\n[^\n]+$", ""
    )

    traceback = string.gsub(traceback, "stack traceback:", "Traceback:")

    io.stdout:write(traceback)
    io.stdout:flush()

    local sanitized = {}
    for char in string.gmatch(traceback, utf8.charpattern) do
        table.insert(sanitized, char)
    end
    traceback = table.concat(sanitized, "")

    traceback = string.gsub(traceback, "\t", "    ")
    traceback = string.gsub(traceback, "\027%[[%d;]*m", "") -- strip control characters

    local throw_inner_error = function(...)
        io.stdout:write("\n")
        io.stdout:write("In love.errorhandler: " .. table.concat({ ... }, ""))
        io.stdout:write("\n")
        io.stdout:flush()
    end

    local safe_call = function(f, ...)
        local success, error_or_result = pcall(f, ...)
        if not success then
            throw_inner_error(error_or_result)
        else
            return error_or_result
        end
    end

    -- reset state
    love.mouse.setVisible(true)
    love.mouse.setGrabbed(false)
    love.mouse.setRelativeMode(false)
    if love.mouse.isCursorSupported() then
        love.mouse.setCursor()
    end

    for joystick in values(love.joystick.getJoysticks()) do
        joystick:setVibration(nil)
    end

    love.audio.stop()
    love.graphics.reset()

    safe_call(rt.InputManager.reset, rt.InputManager)

    -- set default font
    love.graphics.setFont(love.graphics.newFont(15))

    local SHOULD_QUIT = true
    local SHOULD_NOT_QUIT = false

    local restart = function()
        safe_call(rt.ThreadManager.request_shutdown, rt.ThreadManager)
        love.event.restart()
        return SHOULD_NOT_QUIT
    end

    local function show_messages()
        if rt.Translation == nil then return end
        local entry = rt.Translation.error_handler
        if entry == nil then return end

        local buttons
        if love.system.getOS() == "windows" then
            buttons = { entry.open_log, entry.restart, entry.exit }
        else
            buttons = { entry.exit, entry.restart, entry.open_log }
        end

        local result = love.window.showMessageBox(
            entry.title,
            entry.message,
            buttons,
            "error",
            false
        )

        if buttons[result] == entry.restart then
            restart()
            return SHOULD_NOT_QUIT
        elseif buttons[result] == entry.exit then
            return SHOULD_QUIT
        end
    end

    return function()
        love.event.pump()

        -- check for events
        for event, a, b, c, d, e, f in love.event.poll() do
            if event == "quit" then
                return a or 1, b
            elseif event == "keypressed" then
                local key = b
                if key == "space" or key == "return" then
                    restart()
                elseif key == "escape" then
                    return 0 -- quit
                else
                    if show_messages() == SHOULD_QUIT then
                        return 0
                    end
                end
            elseif event == "touchpressed"
                or event == "mousepressed"
                or event == "gamepadpressed"
            then
                if show_messages() == SHOULD_QUIT then
                    return 0
                end
            end
        end

        -- draw
        if love.graphics.isActive() then
            if rt and rt.Palette and rt.Palette.RED_5 then
                love.graphics.clear(rt.Palette.RED_5:unpack())
            else
                love.graphics.clear(1, 0, 0.2, 1)
            end

            local margin = 70
            love.graphics.printf(
                traceback,
                margin, margin,
                love.graphics.getWidth() - 2 * margin
            )
            love.graphics.present()
        end

        -- connect debugger after error is shown on screen
        if not debugger_connected and DEBUG and debugger ~= nil then
            pcall(debugger.connect)
            if debugger.get_is_active() then
                debugger.break_here()
            end
        end

        love.timer.sleep(1 / _fps_limit)
    end
end

return rt.SceneManager