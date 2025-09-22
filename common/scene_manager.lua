require "common.scene"
require "common.scene"
require "common.input_subscriber"
require "common.fade"
require "common.thread_pool"
require "common.palette"
require "common.music_manager"
require "common.music_manager_interface"

rt.settings.scene_manager = {
    max_n_steps_per_frame = 8,
    fade_duration = 0.2,
}

--- @class SceneManager
rt.SceneManager = meta.class("SceneManager")

local _frame_i = 0

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
        _elapsed = 0,
        _frame_timestamp = love.timer.getTime(),

        _bloom = nil, -- initialized on first use
        _input = rt.InputSubscriber(),
    })

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
    assert(scene_type ~= nil, "In rt.SceneManager: scene type cannot be nil")
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

    rt.MusicManager:update(delta)
end

--- @brief
function rt.SceneManager:draw(...)
    if self._current_scene ~= nil then
        self._current_scene:draw(...)
    end

    rt.graphics._stencil_value = 1 -- reset running stencil value

    if self._should_use_fade then
        self._fade:draw()
    end
end

--- @brief
function rt.SceneManager:resize(width, height)
    assert(type(width) == "number" and type(height) == "number")

    self._width = width
    self._height = height
    rt.settings.margin_unit = 10 * rt.get_pixel_scale()

    local scene = self._current_scene
    if scene ~= nil then
        local current_w, current_h = scene._scene_manager_current_width, scene._scene_manager_current_height
        if current_w ~= self._width or current_w ~= self._height then
            scene:reformat(0, 0, self._width, self._height)
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
        self._bloom = rt.Bloom(self._width, self._height)
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

local _n_frames_captured = 120

local _last_update_times = {}
local _update_sum = 0

local _last_draw_times = {}
local _draw_sum = 0

local _last_fps = {}
local _fps_sum = _n_frames_captured * 60

local _last_fps_variance = {}
local _last_fps_variance_sum = 0

local _default_font = love.graphics.getFont()

for i = 1, _n_frames_captured do
    table.insert(_last_update_times, 0)
    table.insert(_last_draw_times, 0)
    table.insert(_last_fps, 60)
    table.insert(_last_fps_variance, 0)
end

--- @brief [internal]
function rt.SceneManager:_draw_performance_metrics()
    local stats = love.graphics.getStats()
    local n_draws = tostring(stats.drawcalls)

    local fps_mean = tostring(love.timer.getFPS()) --math.ceil(_fps_sum / _n_frames_captured))
    local fps_variance = tostring(math.ceil((_last_fps_variance_sum / _n_frames_captured)))
    local gpu_side_memory = tostring(math.ceil(stats.texturememory / 1024 / 1024))
    local update_percentage = tostring(math.ceil(_update_sum / _n_frames_captured * 100))
    local draw_percentage = tostring(math.ceil(_draw_sum / _n_frames_captured * 100))

    while #fps_mean < 3 do
        fps_mean = "0" .. fps_mean
    end

    while #n_draws < 2 do
        n_draws = "0" .. n_draws
    end

    while #update_percentage < 3 do
        update_percentage = "0" .. update_percentage
    end

    while #draw_percentage < 3 do
        draw_percentage = "0" .. draw_percentage
    end

    local str = table.concat({
        fps_mean, " fps \u{00B1} " .. fps_variance .. "% | ",             -- max frame duration
        update_percentage, "% | ",   -- frame usage, how much of a frame was taken up by the game
        draw_percentage, "% | ",
        n_draws, " draws | ",       -- total number of draws
        gpu_side_memory, " mb ",       -- vram usage
    })

    love.graphics.setFont(_default_font)
    local str_width = _default_font:getWidth(str)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(str, love.graphics.getWidth() - str_width - 5, 5, math.huge)
end

--- @brief
function rt.SceneManager:get_frame_index()
    return _frame_i
end

--- @brief
function rt.SceneManager:get_frame_duration()
    return love.timer.getTime() - self._frame_timestamp
end

--- @brief
function rt.SceneManager:get_elapsed()
    return self._elapsed
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

local _update_elapsed = 0
local _update_step = 1 / 120

--- @brief
function rt.SceneManager:get_frame_interpolation()
    if self._use_fixed_timestep then
        return _update_elapsed / _update_step
    else
        return 1
    end
end

--- @brief
function rt.SceneManager:get_is_bloom_enabled()
    return rt.GameState:get_is_bloom_enabled()
end

--- @brief
function rt.SceneManager:get_bloom()
    if rt.GameState:get_is_bloom_enabled() then
        return self._bloom
    else
        return nil
    end
end

rt.SceneManager = rt.SceneManager() -- static global singleton
local _focused = true

love.focus = function(b)
    _focused = b

    if rt.MusicManager ~= nil then
        if _focused then
            rt.MusicManager:unpause()
        else
            rt.MusicManager:pause()
        end
    end
end

-- override love.run for metrics
function love.run()
    io.stdout:setvbuf("no") -- makes it so love2d error message is printed to console immediately

    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    if love.timer then love.timer.step() end

    local delta = 0
    return function()
        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        return a or 0
                    end
                end
                love.handlers[name](a, b, c, d, e, f)
            end
        end

        if love.timer then delta = love.timer.step() end

        local update_before, update_after, draw_before, draw_after
        update_before = love.timer.getTime()

        _update_elapsed = _update_elapsed + delta
        local before = _update_elapsed
        if _focused then
            if rt.SceneManager._use_fixed_timestep == true then
                local n_steps = 0
                while _update_elapsed >= _update_step do
                    love.update(_update_step)
                    _update_elapsed = _update_elapsed - _update_step

                    n_steps = n_steps + 1
                    if n_steps > rt.settings.scene_manager.max_n_steps_per_frame then
                        _update_elapsed = 0
                        break
                    end
                end
            else
                if love.update ~= nil then love.update(delta) end
                _update_elapsed = _update_elapsed - delta
            end
        end

        rt.SceneManager._elapsed = rt.SceneManager._elapsed + (before - _update_elapsed)
        update_after = love.timer.getTime()

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

            rt.InputManager:_notify_end_of_frame()
            _frame_i = _frame_i + 1
            rt.SceneManager._frame_timestamp = love.timer.getTime()
        end

        local fps = 1 / math.max(love.timer.getDelta(), 1 / 500)
        if fps == 0 then fps = 60 end

        local update_time = (update_after - update_before) / (1 / fps)
        local draw_time = (draw_after - draw_before) / (1 / fps)

        local update_start = _last_update_times[1]
        table.remove(_last_update_times, 1)
        table.insert(_last_update_times, update_time)
        _update_sum = _update_sum - update_start + update_time

        local draw_start = _last_draw_times[1]
        table.remove(_last_draw_times, 1)
        table.insert(_last_draw_times, draw_time)
        _draw_sum = _draw_sum - draw_start + draw_time

        local fps_start = _last_fps[1]
        table.remove(_last_fps, 1)
        table.insert(_last_fps, 1 / love.timer.getDelta())
        _fps_sum = _fps_sum - fps_start + fps

        -- Calculate proper FPS variance (coefficient of variation)
        local variance = 0
        do
            local fps_mean = _fps_sum / _n_frames_captured
            local sum_squared_diff = 0

            for x in values(_last_fps) do
                local diff = x - fps_mean
                sum_squared_diff = sum_squared_diff + (diff * diff)
            end

            local standard_deviation = math.sqrt(sum_squared_diff / _n_frames_captured)
            -- Convert to coefficient of variation (percentage)
            if fps_mean > 0 then
                variance = (standard_deviation / fps_mean) * 100
            end
        end

        local variance_start = _last_fps_variance[1]
        table.remove(_last_fps_variance, 1)
        table.insert(_last_fps_variance, variance)
        _last_fps_variance_sum = _last_fps_variance_sum - variance_start + variance

        meta._benchmark = {}
        collectgarbage("step") -- helps catch gc-related bugs

        --if love.timer then love.timer.sleep(0.001) end -- prevent cpu running at max rate for empty projects
    end
end

local utf8 = require("utf8")
local function error_printer(msg, layer)
    print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

local _log_prefix = "/log"
function love.errorhandler(msg)
    msg = tostring(msg)

    error_printer(msg, 2)

    if not love.window or not love.graphics or not love.event then
        return
    end

    if not love.graphics.isCreated() or not love.window.isOpen() then
        local success, status = pcall(love.window.setMode, 800, 600)
        if not success or not status then
            return
        end
    end

    -- Reset state.
    if love.mouse then
        love.mouse.setVisible(true)
        love.mouse.setGrabbed(false)
        love.mouse.setRelativeMode(false)
        if love.mouse.isCursorSupported() then
            love.mouse.setCursor()
        end
    end
    if love.joystick then
        -- Stop all joystick vibrations.
        for i,v in ipairs(love.joystick.getJoysticks()) do
            v:setVibration()
        end
    end
    if love.audio then love.audio.stop() end

    love.graphics.reset()
    love.graphics.setFont(love.graphics.newFont(15))

    love.graphics.setColor(1, 1, 1)

    local trace = debug.traceback()

    love.graphics.origin()

    local sanitizedmsg = {}
    for char in msg:gmatch(utf8.charpattern) do
        table.insert(sanitizedmsg, char)
    end
    sanitizedmsg = table.concat(sanitizedmsg)

    local err = {}

    table.insert(err, "Error\n")
    table.insert(err, sanitizedmsg)

    if #sanitizedmsg ~= #msg then
        table.insert(err, "Invalid UTF-8 string in error message.")
    end

    table.insert(err, "\n")

    for l in trace:gmatch("(.-)\n") do
        if not l:match("boot.lua") then
            l = l:gsub("stack traceback:", "Traceback\n")
            table.insert(err, l)
        end
    end

    local p = table.concat(err, "\n")

    p = p:gsub("\t", "")
    p = p:gsub("%[string \"(.-)\"%]", "%1")

    local function draw()
        if not love.graphics.isActive() then return end
        local pos = 70
        love.graphics.clear(rt.Palette.RED_5:unpack())
        love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos)
        love.graphics.present()
    end

    local fullErrorText = p
    local function copyToClipboard()
        if not love.system then return end
        love.system.setClipboardText(fullErrorText)
        p = p .. "\nCopied to clipboard!"
    end

    if love.system then
        p = p .. "\n\nPress Ctrl+C or tap to copy this error"
    end

    if debugger.get_is_active() then
        debugger.break_here()
    end

    -- write to log folder
    if love.filesystem.getDirectory(_log_prefix) then
        pcall(love.filesystem.createDirectory, _log_prefix)
    end

    love.filesystem.write("")

    return function()
        love.event.pump(0.1)

        for e, a, b, c in love.event.poll() do
            if e == "quit" then
                return 1
            elseif e == "keypressed" and a == "escape" then
                return 1
            elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
                copyToClipboard()
            elseif e == "touchpressed" then
                local name = love.window.getTitle()
                if #name == 0 or name == "Untitled" then name = "Game" end
                local buttons = {"OK", "Cancel"}
                if love.system then
                    buttons[3] = "Copy to clipboard"
                end
                local pressed = love.window.showMessageBox("Quit "..name.."?", "", buttons)
                if pressed == 1 then
                    return 1
                elseif pressed == 3 then
                    copyToClipboard()
                end
            end
        end

        draw()

        if love.timer then
            love.timer.sleep(0.001)
        end
    end
end

return rt.SceneManager